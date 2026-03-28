class_name ConverterLogic
extends BuildingLogic



## Building rotation index (0=right, 1=down, 2=left, 3=up).
var rotation: int = 0
## Converter type string for recipe matching (e.g. "smelter").
var converter_type: String = "smelter"

## Input IO points: Array of {cell: Vector2i, mask: Array} — world-space offsets.
var input_points: Array = []
## Output IO points: same format.
var output_points: Array = []

## All recipes this converter can use (filtered by converter_type).
var recipes: Array = []:
	set(value):
		recipes = value
		_build_capacities()

## Inventories for input ingredients and craft outputs.
var input_inv: Inventory = Inventory.new()
var output_inv: Inventory = Inventory.new()

## Current crafting state.
var _active_recipe = null # RecipeDef or null
var _last_recipe = null # last completed recipe (for popup display)
var _craft_timer: float = 0.0
var _input_rr: RoundRobin = RoundRobin.new()
var _code_anim: Node2D

## Energy configuration per converter type.
## capacity, base_demand — set in configure based on building type.
const ENERGY_CONFIG := {
	"smelter": {capacity = 100.0, demand = 0.0},
	"assembler": {capacity = 50.0, demand = 5.0},
	"chemical_plant": {capacity = 80.0, demand = 8.0},
	"advanced_factory": {capacity = 120.0, demand = 15.0},
}

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)
	rotation = p_rotation
	converter_type = str(def.id)
	input_points = def.get_rotated_inputs(p_rotation)
	output_points = def.get_rotated_outputs(p_rotation)
	recipes = GameManager.recipes_by_type.get(converter_type, [])
	_code_anim = get_parent().get_node_or_null("Rotatable/CodeAnim")
	# Set up energy for converters that participate in the energy grid
	if ENERGY_CONFIG.has(converter_type):
		var cfg = ENERGY_CONFIG[converter_type]
		energy = BuildingEnergy.new(cfg.capacity, cfg.demand, 0.0)

func _build_capacities() -> void:
	input_inv = Inventory.new()
	output_inv = Inventory.new()
	for recipe in recipes:
		for inp in recipe.inputs:
			var cur = input_inv.get_capacity(inp.item.id)
			if inp.quantity * 3 > cur:
				input_inv.set_capacity(inp.item.id, inp.quantity * 3)
		for out in recipe.outputs:
			var cur = output_inv.get_capacity(out.item.id)
			if out.quantity * 5 > cur:
				output_inv.set_capacity(out.item.id, out.quantity * 5)

func _physics_process(delta: float) -> void:
	# Always signal energy demand so redistribution delivers energy proactively
	_update_energy_demand()

	# If building requires power and is unpowered, stop all processing
	if energy and energy.base_energy_demand > 0.0 and not energy.is_powered:
		return

	_try_pull_inputs()

	if _active_recipe:
		_craft_timer = minf(_craft_timer + delta, _active_recipe.craft_time)
		if _craft_timer >= _active_recipe.craft_time:
			_try_finish_craft()
	else:
		_try_start_craft()

	_update_building_sprites(_active_recipe != null, delta)
	if _code_anim and _code_anim.has_method("set_active"):
		_code_anim.set_active(_active_recipe != null)

func _try_pull_inputs() -> void:
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
			if peek_id == &"":
				continue
			if input_inv.has_space(peek_id):
				GameManager.pull_item(world_cell, dir_idx)
				input_inv.add(peek_id)

func _update_energy_demand() -> void:
	if not energy:
		return
	energy.energy_demand = get_max_affordable_recipe_cost()

func _try_start_craft() -> void:
	# Sort candidates by total output quantity (highest first) — prefer most productive recipe
	var candidates: Array = []
	for recipe in recipes:
		if _can_craft(recipe):
			candidates.append(recipe)
	candidates.sort_custom(_compare_recipes_by_output)

	for recipe in candidates:
		if recipe.energy_cost > 0.0:
			if not energy or energy.energy_stored < recipe.energy_cost:
				continue
		_start_craft(recipe)
		return

## Compare recipes by total output quantity (descending).
static func _compare_recipes_by_output(a, b) -> bool:
	var a_total := 0
	for out in a.outputs:
		a_total += out.quantity
	var b_total := 0
	for out in b.outputs:
		b_total += out.quantity
	return a_total > b_total

func _can_craft(recipe) -> bool:
	for inp in recipe.inputs:
		if not input_inv.has(inp.item.id, inp.quantity):
			return false
	for out in recipe.outputs:
		if not output_inv.has_space(out.item.id, out.quantity):
			return false
	return true

func get_max_affordable_recipe_cost() -> float:
	var max_cost := 0.0
	for recipe in recipes:
		if recipe.energy_cost > max_cost and _can_craft(recipe):
			max_cost = recipe.energy_cost
	return max_cost

func _start_craft(recipe) -> void:
	# Consume energy cost locally
	if recipe.energy_cost > 0.0 and energy:
		energy.energy_stored = maxf(energy.energy_stored - recipe.energy_cost, 0.0)
	for inp in recipe.inputs:
		input_inv.remove(inp.item.id, inp.quantity)
	_active_recipe = recipe
	_craft_timer = 0.0

func _try_finish_craft() -> void:
	for out in _active_recipe.outputs:
		if not output_inv.has_space(out.item.id, out.quantity):
			return # Hold craft until output has room
	for out in _active_recipe.outputs:
		output_inv.add(out.item.id, out.quantity)
	_last_recipe = _active_recipe
	_active_recipe = null
	_craft_timer = 0.0

# ── Pull interface ─────────────────────────────────────────────────────────────

func has_output_toward(target_pos: Vector2i) -> bool:
	for outp in output_points:
		if grid_pos + outp.cell == target_pos:
			return true
	return false

func has_input_from(cell: Vector2i, from_dir_idx: int) -> bool:
	for inp in input_points:
		if grid_pos + inp.cell == cell and inp.mask[from_dir_idx]:
			return true
	return false

func can_provide_to(target_pos: Vector2i) -> bool:
	if output_inv.is_empty():
		return false
	for outp in output_points:
		if grid_pos + outp.cell == target_pos:
			return true
	return false

func peek_output_for(target_pos: Vector2i) -> StringName:
	if output_inv.is_empty():
		return &""
	for outp in output_points:
		if grid_pos + outp.cell == target_pos:
			for iid in output_inv.get_item_ids():
				if output_inv.has(iid):
					return iid
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	for outp in output_points:
		if grid_pos + outp.cell == target_pos:
			for iid in output_inv.get_item_ids():
				if output_inv.has(iid):
					output_inv.remove(iid)
					return iid
	return &""

func cleanup_visuals() -> void:
	pass

## Returns craft progress as 0.0–1.0 for progress bar display.
func get_progress() -> float:
	if _active_recipe:
		return clampf(_craft_timer / _active_recipe.craft_time, 0.0, 1.0)
	if not output_inv.is_empty():
		return 1.0 # Waiting to push output
	return 0.0

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {}
	state["craft_timer"] = _craft_timer
	state["active_recipe_id"] = str(_active_recipe.id) if _active_recipe else ""
	state["last_recipe_id"] = str(_last_recipe.id) if _last_recipe else ""
	state["input_inv"] = _serialize_inventory(input_inv)
	state["output_inv"] = _serialize_inventory(output_inv)
	if energy:
		state["energy"] = energy.serialize()
	return state

func deserialize_state(state: Dictionary) -> void:
	if state.has("craft_timer"):
		_craft_timer = state["craft_timer"]
	if state.has("input_inv"):
		_deserialize_inventory(input_inv, state["input_inv"])
	if state.has("output_inv"):
		_deserialize_inventory(output_inv, state["output_inv"])
	if state.has("active_recipe_id") and state["active_recipe_id"] != "":
		var recipe_id := StringName(state["active_recipe_id"])
		for recipe in recipes:
			if recipe.id == recipe_id:
				_active_recipe = recipe
				break
	if state.has("last_recipe_id") and state["last_recipe_id"] != "":
		var recipe_id := StringName(state["last_recipe_id"])
		for recipe in recipes:
			if recipe.id == recipe_id:
				_last_recipe = recipe
				break
	if state.has("energy") and energy:
		energy.deserialize(state["energy"])

func _serialize_inventory(inv: Inventory) -> Dictionary:
	var result := {}
	for iid in inv.get_item_ids():
		result[str(iid)] = inv.get_count(iid)
	return result

func _deserialize_inventory(inv: Inventory, data: Dictionary) -> void:
	for item_id_str in data:
		var iid := StringName(item_id_str)
		var count: int = int(data[item_id_str])
		if inv.get_capacity(iid) == 0:
			inv.set_capacity(iid, count + 10)
		for i in count:
			inv.add(iid)

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var stats: Array = []

	# Recipe display
	var display_recipe = _active_recipe if _active_recipe else (recipes[0] if recipes.size() > 0 else null)
	if display_recipe:
		stats.append({type = "recipe", recipe = display_recipe, active = _active_recipe != null})
		if _active_recipe:
			stats.append({type = "stat", text = "Craft progress:"})
			stats.append({type = "progress", value = get_progress()})

	# Input buffer
	var input_items: Array = []
	for iid in input_inv.get_item_ids():
		var count := input_inv.get_count(iid)
		if count > 0:
			input_items.append({id = iid, count = count})
	if not input_items.is_empty():
		stats.append({type = "inventory", label = "Input", items = input_items})

	# Output buffer
	var output_items: Array = []
	for iid in output_inv.get_item_ids():
		var count := output_inv.get_count(iid)
		if count > 0:
			output_items.append({id = iid, count = count})
	if not output_items.is_empty():
		stats.append({type = "inventory", label = "Output", items = output_items})

	return stats

func get_popup_recipe():
	if _active_recipe:
		return _active_recipe
	if _last_recipe:
		return _last_recipe
	if recipes.size() > 0:
		return recipes[0]
	return null

func get_inventory_items() -> Array:
	var counts := {}
	for iid in input_inv.get_item_ids():
		var c := input_inv.get_count(iid)
		if c > 0:
			counts[iid] = counts.get(iid, 0) + c
	for iid in output_inv.get_item_ids():
		var c := output_inv.get_count(iid)
		if c > 0:
			counts[iid] = counts.get(iid, 0) + c
	var result: Array = []
	for id in counts:
		result.append({id = id, count = counts[id]})
	return result
