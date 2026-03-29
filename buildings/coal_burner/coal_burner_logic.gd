class_name CoalBurnerLogic
extends BuildingLogic

## Coal Burner: 1x2 generator. Pulls coal from adjacent conveyor, burns it for energy.
## 1 coal / 4s = 100 energy per coal = 25 energy/s while fueled.

const BURN_TIME := 4.0        # seconds to burn 1 coal
const ENERGY_PER_COAL := 100.0
const FUEL_ID := &"coal"

var rotation: int = 0
var input_points: Array = []

var fuel_inv: Inventory = Inventory.new()
var _burn_timer: float = 0.0
var _is_burning: bool = false
var _input_rr: RoundRobin = RoundRobin.new()

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)
	rotation = p_rotation
	input_points = def.get_rotated_inputs(p_rotation)
	fuel_inv.set_capacity(FUEL_ID, 5)
	# Set up energy component: capacity 200, no base demand, 25 energy/s generation
	energy = BuildingEnergy.new(200.0, 0.0, 0.0)
	# generation_rate is dynamic — set when burning

func _physics_process(delta: float) -> void:
	_try_pull_fuel()

	# Pause burning when the energy grid is at capacity — don't waste fuel
	if energy.grid_full:
		energy.generation_rate = 0.0
		return

	if _is_burning:
		_burn_timer += delta
		# Signal generation rate — network handles energy distribution
		energy.generation_rate = ENERGY_PER_COAL / BURN_TIME

		if _burn_timer >= BURN_TIME:
			_burn_timer -= BURN_TIME
			# Immediately start next coal if available
			if fuel_inv.has(FUEL_ID):
				fuel_inv.remove(FUEL_ID)
			else:
				_is_burning = false
				_burn_timer = 0.0
	else:
		energy.generation_rate = 0.0
		# Try to start burning
		if fuel_inv.has(FUEL_ID):
			fuel_inv.remove(FUEL_ID)
			_is_burning = true
			_burn_timer = 0.0

	_update_building_sprites(_is_burning, delta)

func _try_pull_fuel() -> void:
	if not fuel_inv.has_space(FUEL_ID):
		return
	var count: int = input_points.size()
	var start: int = _input_rr.next(count)
	for i in range(count):
		var idx: int = (start + i) % count
		var inp = input_points[idx]
		var world_cell: Vector2i = grid_pos + inp.cell
		for dir_idx in range(4):
			if not inp.mask[dir_idx]:
				continue
			var peek_id = GameManager.peek_output_item(world_cell, dir_idx)
			if peek_id == FUEL_ID:
				if fuel_inv.has_space(FUEL_ID):
					GameManager.pull_item(world_cell, dir_idx)
					fuel_inv.add(FUEL_ID)

func try_insert_item(item_id: StringName, quantity: int = 1) -> int:
	if item_id != FUEL_ID:
		return quantity
	var remaining := quantity
	while remaining > 0 and fuel_inv.has_space(FUEL_ID):
		fuel_inv.add(FUEL_ID)
		remaining -= 1
	return remaining

# ── Pull interface (no item output) ─────────────────────────────────────────

func has_output_toward(_target_pos: Vector2i) -> bool:
	return false

func has_input_from(cell: Vector2i, from_dir_idx: int) -> bool:
	for inp in input_points:
		if grid_pos + inp.cell == cell and inp.mask[from_dir_idx]:
			return true
	return false

func cleanup_visuals() -> void:
	pass

# ── Serialization ────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {}
	state["burn_timer"] = _burn_timer
	state["is_burning"] = _is_burning
	var inv_data := {}
	for iid in fuel_inv.get_item_ids():
		inv_data[str(iid)] = fuel_inv.get_count(iid)
	state["fuel_inv"] = inv_data
	if energy:
		state["energy"] = energy.serialize()
	return state

func deserialize_state(state: Dictionary) -> void:
	if state.has("burn_timer"):
		_burn_timer = state["burn_timer"]
	if state.has("is_burning"):
		_is_burning = state["is_burning"]
	if state.has("fuel_inv"):
		for item_id_str in state["fuel_inv"]:
			var iid := StringName(item_id_str)
			var count: int = int(state["fuel_inv"][item_id_str])
			if fuel_inv.get_capacity(iid) == 0:
				fuel_inv.set_capacity(iid, count + 10)
			for i in count:
				fuel_inv.add(iid)
	if state.has("energy") and energy:
		energy.deserialize(state["energy"])

# ── Info panel ───────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var stats: Array = []
	stats.append({type = "stat", text = "Coal Burner (25 energy/s)"})
	if energy.grid_full:
		stats.append({type = "stat", text = "Status: Grid Full"})
	elif _is_burning:
		stats.append({type = "stat", text = "Status: Burning"})
		stats.append({type = "progress", value = _burn_timer / BURN_TIME})
	else:
		stats.append({type = "stat", text = "Status: Idle"})
	stats.append({type = "stat", text = "Fuel: %d/5 coal" % fuel_inv.get_count(FUEL_ID)})
	if energy:
		stats.append({type = "stat", text = "Energy: %.0f/%.0f" % [energy.energy_stored, energy.energy_capacity]})
	return stats

func get_popup_recipe():
	var coal_def = GameManager.get_item_def(FUEL_ID)
	var coal_color: Color = coal_def.color if coal_def else Color.DIM_GRAY
	var energy_color := Color(0.95, 0.85, 0.2) # yellow for energy
	return {
		inputs = [{quantity = 1, color = coal_color}],
		outputs = [{quantity = int(ENERGY_PER_COAL), color = energy_color}],
	}

func get_popup_progress() -> float:
	if _is_burning:
		return clampf(_burn_timer / BURN_TIME, 0.0, 1.0)
	return 0.0

func get_inventory_items() -> Array:
	var result: Array = []
	for iid in fuel_inv.get_item_ids():
		var count := fuel_inv.get_count(iid)
		if count > 0:
			result.append({id = iid, count = count})
	return result
