class_name ConverterLogic
extends BuildingLogic
## Physics-based converter (smelter). Input zones detect PhysicsItems,
## consume them when a recipe can be fulfilled, and spawn output items
## at the output zone.

var rotation: int = 0
var converter_type: String = "smelter"

## Night mode: when true, crafting is paused and turret fires instead.
var night_mode: bool = false
var turret: TurretBehavior = null

var recipes: Array = []:
	set(value):
		recipes = value
		_build_recipe_configs()

var recipe_configs: Array = []
var _sorted_configs: Array = []
var _configs_dirty: bool = true

## Internal counts of consumed items (not yet crafted).
var _input_counts: Dictionary = {}
## Max items to buffer per type (3 batches of largest recipe requirement).
var _input_caps: Dictionary = {}

var _active_recipe = null
var _last_recipe = null
var _craft_timer: float = 0.0
var _cached_input_zones: Array[InputZone] = []

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)
	rotation = p_rotation
	converter_type = str(def.id)
	recipes = BuildingRegistry.recipes_by_type.get(converter_type, [])
	_build_input_caps()
	_cache_input_zones.call_deferred()

func _cache_input_zones() -> void:
	_cached_input_zones.clear()
	var inputs_node: Node = get_parent().get_node_or_null("Inputs")
	if not inputs_node:
		return
	for child in inputs_node.get_children():
		if child is InputZone:
			_cached_input_zones.append(child)

func _build_recipe_configs(default_enabled: bool = true) -> void:
	recipe_configs.clear()
	for i in range(recipes.size()):
		var config := RecipeConfig.new(recipes[i], i + 1)
		config.enabled = default_enabled
		recipe_configs.append(config)
	_configs_dirty = true

func _build_input_caps() -> void:
	_input_caps.clear()
	for recipe in recipes:
		for inp in recipe.inputs:
			var cap: int = _input_caps.get(inp.item.id, 0)
			var need: int = inp.quantity * 3
			if need > cap:
				_input_caps[inp.item.id] = need

func _physics_process(delta: float) -> void:
	if night_mode:
		# Turret handles its own _physics_process; skip crafting.
		_update_building_sprites(turret != null and turret.active, delta)
		return

	_try_consume_inputs()

	if _active_recipe:
		_craft_timer = minf(_craft_timer + delta, _active_recipe.craft_time)
		if _craft_timer >= _active_recipe.craft_time:
			_try_finish_craft()
	else:
		_try_start_craft()

	_update_building_sprites(_active_recipe != null, delta)

func _try_consume_inputs() -> void:
	for zone in _cached_input_zones:
		for item in zone.get_items():
			if not is_instance_valid(item):
				continue
			var id: StringName = item.item_id
			var have: int = _input_counts.get(id, 0)
			var cap: int = _input_caps.get(id, 0)
			if cap > 0 and have < cap:
				if zone.consume_item(id):
					_input_counts[id] = have + 1

func _try_start_craft() -> void:
	if _configs_dirty:
		_sorted_configs = recipe_configs.duplicate()
		_sorted_configs.sort_custom(func(a, b): return a.priority < b.priority)
		_configs_dirty = false
	for config in _sorted_configs:
		if not config.enabled:
			continue
		if _can_craft(config.recipe):
			_start_craft(config.recipe)
			return

func _can_craft(recipe) -> bool:
	for inp in recipe.inputs:
		if _input_counts.get(inp.item.id, 0) < inp.quantity:
			return false
	return true

func _start_craft(recipe) -> void:
	for inp in recipe.inputs:
		_input_counts[inp.item.id] = _input_counts.get(inp.item.id, 0) - inp.quantity
	_active_recipe = recipe
	_craft_timer = 0.0

func _try_finish_craft() -> void:
	var output_zone: OutputZone = get_first_output_zone()
	if not output_zone:
		return
	for out in _active_recipe.outputs:
		for i in out.quantity:
			output_zone.spawn_item(out.item.id)
	_last_recipe = _active_recipe
	_active_recipe = null
	_craft_timer = 0.0


func try_insert_item(item_id: StringName, quantity: int = 1) -> int:
	var remaining := quantity
	var cap: int = _input_caps.get(item_id, 0)
	while remaining > 0 and _input_counts.get(item_id, 0) < cap:
		_input_counts[item_id] = _input_counts.get(item_id, 0) + 1
		remaining -= 1
	return remaining

func get_progress() -> float:
	if _active_recipe:
		return clampf(_craft_timer / _active_recipe.craft_time, 0.0, 1.0)
	return 0.0

## Return the item id of the last produced resource (for element detection).
func get_last_resource() -> StringName:
	if _last_recipe and _last_recipe.outputs.size() > 0:
		return _last_recipe.outputs[0].item.id
	return &""

const NIGHT_MODEL: PackedScene = preload("res://buildings/smelter/models/rocket_turret.glb")
var _day_model_transform: Transform3D

## Toggle night mode. When enabled, crafting pauses and turret fires.
func set_night_mode(enabled: bool) -> void:
	is_night_mode = enabled
	night_mode = enabled
	if enabled:
		if not turret:
			turret = TurretBehavior.new()
			turret.name = "TurretBehavior"
			add_child(turret)
		turret.activate(get_last_resource())
		_swap_to_night_model()
	else:
		if turret:
			turret.deactivate()
		_swap_to_day_model()

func _swap_to_night_model() -> void:
	var building := get_parent()
	var old_model := building.get_node_or_null("Model")
	if old_model:
		_day_model_transform = old_model.transform
		building.remove_child(old_model)
		old_model.queue_free()
	var new_model: Node3D = NIGHT_MODEL.instantiate()
	new_model.name = "Model"
	new_model.transform = _day_model_transform
	building.add_child(new_model)

func _swap_to_day_model() -> void:
	var building := get_parent()
	var old_model := building.get_node_or_null("Model")
	if old_model:
		building.remove_child(old_model)
		old_model.queue_free()
	var def = BuildingRegistry.get_building_def(building.building_id)
	if def:
		var day_scene: Node3D = def.scene.instantiate()
		var model := day_scene.get_node_or_null("Model")
		if model:
			model.owner = null
			day_scene.remove_child(model)
			building.add_child(model)
		day_scene.queue_free()

func mark_configs_dirty() -> void:
	_configs_dirty = true

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {}
	state["craft_timer"] = _craft_timer
	state["active_recipe_id"] = str(_active_recipe.id) if _active_recipe else ""
	state["last_recipe_id"] = str(_last_recipe.id) if _last_recipe else ""
	state["input_counts"] = _input_counts.duplicate()
	state["night_mode"] = night_mode
	var configs_data: Array = []
	for config in recipe_configs:
		configs_data.append(config.serialize())
	state["recipe_configs"] = configs_data
	return state

func deserialize_state(state: Dictionary) -> void:
	if state.has("craft_timer"):
		_craft_timer = state["craft_timer"]
	if state.has("input_counts"):
		_input_counts = state["input_counts"].duplicate()
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
	if state.get("night_mode", false):
		set_night_mode.call_deferred(true)

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var stats: Array = []
	var display_recipe = _active_recipe if _active_recipe else (recipes[0] if recipes.size() > 0 else null)
	if display_recipe:
		stats.append({type = "recipe", recipe = display_recipe, active = _active_recipe != null})
		if _active_recipe:
			stats.append({type = "stat", text = "Craft progress:"})
			stats.append({type = "progress", value = get_progress()})
	var input_items: Array = []
	for id in _input_counts:
		if _input_counts[id] > 0:
			input_items.append({id = id, count = _input_counts[id]})
	if not input_items.is_empty():
		stats.append({type = "inventory", label = "Input buffer", items = input_items})
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
	var result: Array = []
	for id in _input_counts:
		if _input_counts[id] > 0:
			result.append({id = id, count = _input_counts[id]})
	return result

func remove_inventory_item(p_item_id: StringName, count: int) -> int:
	var have: int = _input_counts.get(p_item_id, 0)
	var take: int = mini(count, have)
	if take > 0:
		_input_counts[p_item_id] = have - take
	return take
