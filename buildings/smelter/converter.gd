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
		_build_recipe_configs()

## Per-recipe configuration (priority + enabled). One RecipeConfig per recipe.
var recipe_configs: Array = []
var _sorted_configs: Array = []
var _configs_dirty: bool = true

## Inventories for input ingredients and craft outputs.
var input_inv: Inventory = Inventory.new()
var output_inv: Inventory = Inventory.new()

## Current crafting state.
var _active_recipe = null # RecipeDef or null
var _last_recipe = null # last completed recipe (for popup display)
var _craft_timer: float = 0.0
var _input_rr: RoundRobin = RoundRobin.new()
var _code_anim: Node2D
var _code_anims: Array = []

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)
	rotation = p_rotation
	converter_type = str(def.id)
	input_points = def.get_rotated_inputs(p_rotation)
	output_points = def.get_rotated_outputs(p_rotation)
	recipes = GameManager.recipes_by_type.get(converter_type, [])
	# Find all CodeAnim* nodes for procedural animation
	_code_anims = []
	var rotatable = get_parent().get_node_or_null("Rotatable")
	if rotatable:
		for child in rotatable.get_children():
			if child is Node2D and String(child.name).begins_with("CodeAnim"):
				_code_anims.append(child)
		if not _code_anims.is_empty():
			_code_anim = _code_anims[0]

func _build_recipe_configs(default_enabled: bool = true) -> void:
	recipe_configs.clear()
	for i in range(recipes.size()):
		var config := RecipeConfig.new(recipes[i], i + 1)
		config.enabled = default_enabled
		recipe_configs.append(config)
	_configs_dirty = true

const INPUT_CAPACITY_MULTIPLIER := 3   # Buffer 3 batches of each input
const OUTPUT_CAPACITY_MULTIPLIER := 5  # Buffer 5 batches of each output

func _build_capacities() -> void:
	input_inv = Inventory.new()
	output_inv = Inventory.new()
	for recipe in recipes:
		for inp in recipe.inputs:
			var cur = input_inv.get_capacity(inp.item.id)
			if inp.quantity * INPUT_CAPACITY_MULTIPLIER > cur:
				input_inv.set_capacity(inp.item.id, inp.quantity * INPUT_CAPACITY_MULTIPLIER)
		for out in recipe.outputs:
			var cur = output_inv.get_capacity(out.item.id)
			if out.quantity * OUTPUT_CAPACITY_MULTIPLIER > cur:
				output_inv.set_capacity(out.item.id, out.quantity * OUTPUT_CAPACITY_MULTIPLIER)

func _physics_process(delta: float) -> void:
	_try_pull_inputs()

	if _active_recipe:
		_craft_timer = minf(_craft_timer + delta, _active_recipe.craft_time)
		if _craft_timer >= _active_recipe.craft_time:
			_try_finish_craft()
	else:
		_try_start_craft()

	_update_building_sprites(_active_recipe != null, delta)
	for anim in _code_anims:
		if anim and anim.has_method("set_active"):
			anim.set_active(_active_recipe != null)

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

func mark_configs_dirty() -> void:
	_configs_dirty = true

func _try_start_craft() -> void:
	if _configs_dirty:
		_sorted_configs = recipe_configs.duplicate()
		_sorted_configs.sort_custom(func(a, b): return a.priority < b.priority)
		_configs_dirty = false
	for config in _sorted_configs:
		if not config.enabled:
			continue
		if not _can_craft(config.recipe):
			continue
		_start_craft(config.recipe)
		return

func _can_craft(recipe) -> bool:
	for inp in recipe.inputs:
		if not input_inv.has(inp.item.id, inp.quantity):
			return false
	for out in recipe.outputs:
		if not output_inv.has_space(out.item.id, out.quantity):
			return false
	return true

func _start_craft(recipe) -> void:
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


func try_insert_item(item_id: StringName, quantity: int = 1) -> int:
	var remaining := quantity
	while remaining > 0 and input_inv.has_space(item_id):
		input_inv.add(item_id)
		remaining -= 1
	return remaining

# ── Pull interface ─────────────────────────────────────────────────────────────

func _output_reaches(outp: Dictionary, target_pos: Vector2i) -> bool:
	## Check if an output point can reach target_pos.
	## Two modes:
	## 1. Output cell IS target_pos (gap-style, like smelter) — always matches
	## 2. Output cell is adjacent to target_pos AND mask allows that direction
	var out_world: Vector2i = grid_pos + outp.cell
	if out_world == target_pos:
		return true
	var diff: Vector2i = target_pos - out_world
	for dir_idx in 4:
		if DIRECTION_VECTORS[dir_idx] == diff and outp.mask[dir_idx]:
			return true
	return false

func has_output_toward(target_pos: Vector2i) -> bool:
	for outp in output_points:
		if _output_reaches(outp, target_pos):
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
		if _output_reaches(outp, target_pos):
			return true
	return false

func peek_output_for(target_pos: Vector2i) -> StringName:
	if output_inv.is_empty():
		return &""
	for outp in output_points:
		if _output_reaches(outp, target_pos):
			for iid in output_inv.get_item_ids():
				if output_inv.has(iid):
					return iid
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	for outp in output_points:
		if _output_reaches(outp, target_pos):
			for iid in output_inv.get_item_ids():
				if output_inv.has(iid):
					output_inv.remove(iid)
				
					return iid
	return &""

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
	state["input_inv"] = input_inv.serialize()
	state["output_inv"] = output_inv.serialize()
	var configs_data: Array = []
	for config in recipe_configs:
		configs_data.append(config.serialize())
	state["recipe_configs"] = configs_data
	return state

func deserialize_state(state: Dictionary) -> void:
	if state.has("craft_timer"):
		_craft_timer = state["craft_timer"]
	if state.has("input_inv"):
		input_inv.deserialize(state["input_inv"])
	if state.has("output_inv"):
		output_inv.deserialize(state["output_inv"])
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
	if state.has("recipe_configs"):
		RecipeConfig.deserialize_into(recipe_configs, state["recipe_configs"])
		_configs_dirty = true


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

func get_recipe_configs() -> Array:
	return recipe_configs

func get_popup_recipe():
	if _active_recipe:
		return _active_recipe
	if _last_recipe:
		return _last_recipe
	if recipes.size() > 0:
		return recipes[0]
	return null

func get_popup_progress() -> float:
	return get_progress()

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

func remove_inventory_item(item_id: StringName, count: int) -> int:
	var removed := 0
	# Remove from output first, then input
	var out_count := output_inv.get_count(item_id)
	var out_take := mini(count, out_count)
	if out_take > 0 and output_inv.remove(item_id, out_take):
		removed += out_take
	var remaining := count - removed
	if remaining > 0:
		var in_count := input_inv.get_count(item_id)
		var in_take := mini(remaining, in_count)
		if in_take > 0 and input_inv.remove(item_id, in_take):
			removed += in_take
	return removed
