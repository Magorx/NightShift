class_name EnergyNetwork
extends RefCounted

## A connected component of buildings that can exchange energy.
## Rebuilt by EnergySystem when the network topology changes.
##
## Tick algorithm:
## 1. Collect generation into a pool (generated_now) — NOT added to individual buildings
## 2. Fulfill base demand from generated_now first, then grid storage
## 3. Distribute remaining generated_now instantly + equalize existing storage via lerp
##    (combined step: targets computed from total energy, generation portion is instant)

const EQUALIZE_SPEED := 2.0  # convergence rate for stored-energy equalization

var buildings: Array = []       # Array[BuildingLogic] — all energy-capable buildings
var generators: Array = []      # subset where energy.generation_rate > 0 (at build time)
var consumers: Array = []       # subset where energy.base_energy_demand > 0
var node_edges: Array = []      # Array[{from_node, to_node}]
var total_capacity: float = 0.0
var total_stored: float = 0.0   # cached, updated each tick

func tick(delta: float) -> void:
	if buildings.is_empty():
		return
	# Step 1: Collect generation into a pool (not added to individual buildings)
	var generated_now := _step_generate(delta)
	# Step 2: Fulfill base demand from generated_now first, then grid storage
	generated_now = _step_consume_demand(delta, generated_now)
	# Step 3+4: Distribute remaining generation instantly + equalize grid storage
	_step_distribute_and_equalize(delta, generated_now)

## Collect total generation this tick. Energy stays in the pool, not in buildings.
## Checks all buildings (not just generators list) because generation_rate can change
## dynamically (e.g. coal burner starts/stops burning).
func _step_generate(delta: float) -> float:
	var total := 0.0
	for building in buildings:
		if building.energy.generation_rate > 0.0:
			total += building.energy.generation_rate * delta
	return total

## Fulfill base energy demand. Uses generated_now first, then grid storage.
## Returns remaining generated_now after demand fulfillment.
func _step_consume_demand(delta: float, generated_now: float) -> float:
	var total_demand := 0.0
	for building in consumers:
		total_demand += building.energy.base_energy_demand * delta

	if total_demand <= 0.0:
		for building in consumers:
			building.energy.is_powered = true
		return generated_now

	# Fulfill from generation first
	var from_gen := minf(generated_now, total_demand)
	generated_now -= from_gen
	var deficit := total_demand - from_gen

	if deficit <= 0.0:
		for building in consumers:
			building.energy.is_powered = true
		return generated_now

	# Draw deficit from grid storage (proportionally from all buildings)
	var grid_stored := 0.0
	for building in buildings:
		grid_stored += building.energy.energy_stored

	if grid_stored >= deficit:
		var ratio := deficit / grid_stored
		for building in buildings:
			building.energy.energy_stored *= (1.0 - ratio)
		for building in consumers:
			building.energy.is_powered = true
	else:
		# Not enough — drain all storage, mark unpowered
		for building in buildings:
			building.energy.energy_stored = 0.0
		for building in consumers:
			building.energy.is_powered = false

	return generated_now

## Distribute remaining generation instantly + equalize existing storage via lerp.
## Generated energy flows immediately to where there's space; existing stored energy
## lerps toward equal absolute levels across buildings.
func _step_distribute_and_equalize(delta: float, generated_now: float) -> void:
	total_stored = 0.0
	total_capacity = 0.0
	for building in buildings:
		total_stored += building.energy.energy_stored
		total_capacity += building.energy.energy_capacity

	if total_capacity <= 0.0:
		return

	var total_energy := total_stored + generated_now

	# Compute equalization targets for total energy (existing + generation)
	var final_targets := _compute_targets(total_energy)
	# Compute equalization targets for existing storage only
	var existing_targets := _compute_targets(total_stored)

	var lerp_factor := clampf(EQUALIZE_SPEED * delta, 0.0, 1.0)

	for i in buildings.size():
		var e = buildings[i].energy
		# Lerp existing storage toward equalized target (smooth convergence)
		var equalized := lerpf(e.energy_stored, existing_targets[i], lerp_factor)
		# Add generation share instantly (not lerped — fresh energy flows immediately)
		var gen_share := maxf(final_targets[i] - existing_targets[i], 0.0)
		e.energy_stored = equalized + gen_share

	# Node connection throughput constraints
	for edge in node_edges:
		var from_node = edge.from_node
		var to_node = edge.to_node
		if not is_instance_valid(from_node) or not is_instance_valid(to_node):
			continue
		if not from_node.owner_logic or not to_node.owner_logic:
			continue
		var from_e = from_node.owner_logic.energy
		var to_e = to_node.owner_logic.energy
		if not from_e or not to_e:
			continue
		var min_throughput: float = minf(from_node.throughput, to_node.throughput)
		var max_transfer: float = min_throughput * delta
		var diff: float = from_e.energy_stored - to_e.energy_stored
		if absf(diff) < 0.5:
			continue
		var desired: float = diff * 0.5
		var actual: float = clampf(desired, -max_transfer, max_transfer)
		if actual > 0.0:
			actual = minf(actual, maxf(to_e.energy_capacity - to_e.energy_stored, 0.0))
			actual = minf(actual, from_e.energy_stored)
		elif actual < 0.0:
			actual = maxf(actual, -maxf(from_e.energy_capacity - from_e.energy_stored, 0.0))
			actual = maxf(actual, -to_e.energy_stored)
		from_e.energy_stored -= actual
		to_e.energy_stored += actual

	# Final clamp — safety net for floating-point drift
	for building in buildings:
		var e = building.energy
		e.energy_stored = clampf(e.energy_stored, 0.0, e.energy_capacity)

## Compute equal-distribution targets for a given total energy amount.
## Handles capacity caps: full buildings get their cap, remainder redistributed to others.
func _compute_targets(total_energy: float) -> Array:
	var count := buildings.size()
	var targets: Array = []
	targets.resize(count)
	var settled: Array = []
	settled.resize(count)
	for i in count:
		settled[i] = false
	var remaining := total_energy
	var unsettled_count := count

	while unsettled_count > 0:
		var share: float = remaining / float(unsettled_count)
		var any_capped := false
		for i in count:
			if settled[i]:
				continue
			var cap: float = buildings[i].energy.energy_capacity
			if cap < share:
				targets[i] = cap
				remaining -= cap
				settled[i] = true
				unsettled_count -= 1
				any_capped = true
		if not any_capped:
			for i in count:
				if not settled[i]:
					targets[i] = share
			break

	return targets
