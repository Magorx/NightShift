class_name EnergyNetwork
extends RefCounted

## A connected component of buildings that can exchange energy.
## Rebuilt by EnergySystem when the network topology changes.
##
## Tick algorithm (4 phases, shared throughput budget per edge per tick):
## 1. Generate — add energy to each generator (capped at capacity)
## 2. Demand redistribution — fulfill base_energy_demand orders, then consume + set is_powered
## 3. Recipe redistribution — fulfill recipe energy orders for converters with resources
## 4. Equalization — balance fill ratios across the network
##
## Redistribution rules:
## - Energy flows through edges, each with a per-tick throughput budget
## - A building never releases energy below its floor:
##   floor = base_energy_demand * DEMAND_BUFFER_SECONDS + max affordable recipe cost
## - Budget is shared across all 4 phases (sum of transfers per edge per tick <= budget)

var buildings: Array = []       # Array[BuildingLogic] — all energy-capable buildings
var generators: Array = []      # subset where energy.generation_rate > 0
var consumers: Array = []       # subset where energy.base_energy_demand > 0
var edges: Array = []           # Array[{a: BuildingLogic, b: BuildingLogic, throughput: float}]
var total_capacity: float = 0.0
var total_stored: float = 0.0   # cached, updated each tick

## Tuning constants
const DEMAND_BUFFER_SECONDS := 5.0   # how many seconds of demand a building protects
const RELAXATION_PASSES := 2         # iterations per redistribution phase

## Per-tick edge budgets (parallel array to edges, reset each tick)
var _edge_budgets: Array = []   # Array[float]
var _floor_cache: Dictionary = {}  # instance_id -> float, cleared each tick

func tick(delta: float) -> void:
	if buildings.is_empty():
		return

	# Initialize per-tick throughput budgets and clear caches
	_floor_cache.clear()
	_init_edge_budgets(delta)

	# Phase 1: Generate
	_phase_generate(delta)
	# Phase 2: Demand redistribution
	_phase_demand(delta)
	# Phase 3: Recipe redistribution
	_phase_recipe()
	# Phase 4: Equalization
	_phase_equalize()
	# Finalize
	_step_finalize()

# ── Phase 1: Generation ─────────────────────────────────────────────────────

func _phase_generate(delta: float) -> void:
	# Single pass: compute totals, set grid_full, and generate
	total_stored = 0.0
	total_capacity = 0.0
	for building in buildings:
		total_stored += building.energy.energy_stored
		total_capacity += building.energy.energy_capacity
	var is_full := total_capacity > 0.0 and total_stored >= total_capacity

	for building in buildings:
		building.energy.grid_full = is_full
		if not is_full and building.energy.generation_rate > 0.0:
			var gen: float = building.energy.generation_rate * delta
			building.energy.energy_stored = minf(
				building.energy.energy_stored + gen,
				building.energy.energy_capacity
			)

# ── Phase 2: Demand redistribution ──────────────────────────────────────────

func _phase_demand(delta: float) -> void:
	# Collect demand orders: each consumer needs base_energy_demand * delta
	var orders: Dictionary = {}  # building instance_id -> amount needed
	var order_buildings: Array = []  # buildings that placed orders
	for building in consumers:
		var need: float = building.energy.base_energy_demand * delta
		if need <= 0.0:
			building.energy.is_powered = true
			continue
		# Building needs this much. If it already has enough, no order needed,
		# but we still consume after redistribution.
		var deficit: float = need - building.energy.energy_stored
		if deficit > 0.0:
			orders[building.get_instance_id()] = deficit
			order_buildings.append(building)

	# Redistribute to fill demand deficits
	if not orders.is_empty():
		_redistribute(orders)

	# Consume demand and set powered state
	for building in consumers:
		var need: float = building.energy.base_energy_demand * delta
		if need <= 0.0:
			building.energy.is_powered = true
			continue
		if building.energy.energy_stored >= need:
			building.energy.energy_stored -= need
			building.energy.is_powered = true
		else:
			# Consume whatever is left
			building.energy.energy_stored = 0.0
			building.energy.is_powered = false

# ── Phase 3: Recipe redistribution ──────────────────────────────────────────

func _phase_recipe() -> void:
	# Collect recipe orders: converters that want energy for a powered recipe
	var orders: Dictionary = {}
	for building in buildings:
		var demand: float = building.energy.energy_demand
		if demand <= 0.0:
			continue
		var deficit: float = demand - building.energy.energy_stored
		if deficit > 0.0:
			orders[building.get_instance_id()] = deficit

	if not orders.is_empty():
		_redistribute(orders)

# ── Phase 4: Equalization ───────────────────────────────────────────────────

func _phase_equalize() -> void:
	# Flow energy from higher fill-ratio buildings to lower, respecting floors
	for _pass in range(RELAXATION_PASSES):
		for i in range(edges.size()):
			if _edge_budgets[i] <= 0.001:
				continue
			var edge = edges[i]
			var a = edge.a
			var b = edge.b
			if not is_instance_valid(a) or not is_instance_valid(b):
				continue
			var a_e = a.energy
			var b_e = b.energy
			if not a_e or not b_e:
				continue
			if a_e.energy_capacity <= 0.0 or b_e.energy_capacity <= 0.0:
				continue

			var a_fill: float = a_e.energy_stored / a_e.energy_capacity
			var b_fill: float = b_e.energy_stored / b_e.energy_capacity
			var diff: float = a_fill - b_fill
			if absf(diff) < 0.001:
				continue

			var a_floor := _get_floor(a)
			var b_floor := _get_floor(b)

			# Flow from higher fill to lower fill
			if diff > 0.0:
				# a -> b
				var a_surplus := maxf(a_e.energy_stored - a_floor, 0.0)
				var b_space := maxf(b_e.energy_capacity - b_e.energy_stored, 0.0)
				# Target: equalize fill ratios. Transfer half the difference in energy terms.
				var target_transfer := diff * 0.5 * minf(a_e.energy_capacity, b_e.energy_capacity)
				var transfer := minf(target_transfer, minf(a_surplus, minf(b_space, _edge_budgets[i])))
				if transfer > 0.001:
					a_e.energy_stored -= transfer
					b_e.energy_stored += transfer
					_edge_budgets[i] -= transfer
					edges[i].net_flow += transfer
			else:
				# b -> a
				var b_surplus := maxf(b_e.energy_stored - b_floor, 0.0)
				var a_space := maxf(a_e.energy_capacity - a_e.energy_stored, 0.0)
				var target_transfer := -diff * 0.5 * minf(a_e.energy_capacity, b_e.energy_capacity)
				var transfer := minf(target_transfer, minf(b_surplus, minf(a_space, _edge_budgets[i])))
				if transfer > 0.001:
					b_e.energy_stored -= transfer
					a_e.energy_stored += transfer
					_edge_budgets[i] -= transfer
					edges[i].net_flow -= transfer

# ── Core redistribution ─────────────────────────────────────────────────────

## Iterative edge relaxation: try to fulfill orders by flowing energy through edges.
## Each pass, for each edge, if one side has an order deficit and the other has surplus
## above its floor, transfer energy (clamped by edge budget).
func _redistribute(orders: Dictionary) -> void:
	for _pass in range(RELAXATION_PASSES):
		for i in range(edges.size()):
			if _edge_budgets[i] <= 0.001:
				continue
			var edge = edges[i]
			var a = edge.a
			var b = edge.b
			if not is_instance_valid(a) or not is_instance_valid(b):
				continue
			var a_e = a.energy
			var b_e = b.energy
			if not a_e or not b_e:
				continue

			var a_id: int = a.get_instance_id()
			var b_id: int = b.get_instance_id()
			var a_want: float = orders.get(a_id, 0.0)
			var b_want: float = orders.get(b_id, 0.0)

			# Determine flow direction: from the side without (or less) want to the side with want
			var flow := 0.0  # positive = a->b, negative = b->a
			if b_want > 0.0 and a_want <= 0.0:
				# b needs energy, a can supply
				var a_floor := _get_floor(a)
				var a_surplus := maxf(a_e.energy_stored - a_floor, 0.0)
				var b_space := maxf(b_e.energy_capacity - b_e.energy_stored, 0.0)
				flow = minf(b_want, minf(a_surplus, minf(b_space, _edge_budgets[i])))
			elif a_want > 0.0 and b_want <= 0.0:
				# a needs energy, b can supply
				var b_floor := _get_floor(b)
				var b_surplus := maxf(b_e.energy_stored - b_floor, 0.0)
				var a_space := maxf(a_e.energy_capacity - a_e.energy_stored, 0.0)
				flow = -minf(a_want, minf(b_surplus, minf(a_space, _edge_budgets[i])))
			elif a_want > 0.0 and b_want > 0.0:
				# Both need energy — don't transfer between starving buildings
				continue

			if absf(flow) < 0.001:
				continue

			if flow > 0.0:
				a_e.energy_stored -= flow
				b_e.energy_stored += flow
				_edge_budgets[i] -= flow
				edges[i].net_flow += flow
				orders[b_id] = maxf(b_want - flow, 0.0)
			else:
				var abs_flow := -flow
				b_e.energy_stored -= abs_flow
				a_e.energy_stored += abs_flow
				_edge_budgets[i] -= abs_flow
				edges[i].net_flow -= abs_flow
				orders[a_id] = maxf(a_want - abs_flow, 0.0)

# ── Finalize ────────────────────────────────────────────────────────────────

func _step_finalize() -> void:
	total_stored = 0.0
	total_capacity = 0.0
	for building in buildings:
		var e = building.energy
		e.energy_stored = clampf(e.energy_stored, 0.0, e.energy_capacity)
		total_stored += e.energy_stored
		total_capacity += e.energy_capacity

# ── Helpers ─────────────────────────────────────────────────────────────────

func _init_edge_budgets(delta: float) -> void:
	_edge_budgets.resize(edges.size())
	for i in range(edges.size()):
		_edge_budgets[i] = edges[i].throughput * delta
		edges[i].net_flow = 0.0

## Compute the energy floor for a building: the minimum energy it will not
## voluntarily release during redistribution.
## floor = base_energy_demand * DEMAND_BUFFER_SECONDS + max affordable recipe cost
func _get_floor(logic) -> float:
	var id = logic.get_instance_id()
	if _floor_cache.has(id):
		return _floor_cache[id]
	var e = logic.energy
	var demand_floor: float = e.base_energy_demand * DEMAND_BUFFER_SECONDS
	var recipe_floor: float = logic.get_max_affordable_recipe_cost()
	var result := minf(demand_floor + recipe_floor, e.energy_capacity)
	_floor_cache[id] = result
	return result
