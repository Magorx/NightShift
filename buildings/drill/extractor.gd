class_name ExtractorLogic
extends BuildingLogic
## Drill extractor: spawns PhysicsItem at the output zone on a timer.
## If no conveyor carries items away, they pile up at the output.

func get_placement_error(p_grid_pos: Vector2i, _rotation: int) -> String:
	if not MapManager.deposits.has(p_grid_pos):
		return "No resource deposit"
	return ""

var direction: int = 0
var item_id: StringName = &"pyromite"
var produce_interval: float = 2.0
var _timer: float = 0.0

func configure(def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(def, p_grid_pos, rotation)
	direction = rotation
	item_id = MapManager.deposits.get(grid_pos, &"pyromite")
	if str(def.id) == "drill_mk2":
		produce_interval = 1.0

func _physics_process(delta: float) -> void:
	_timer += delta
	var produced := false
	if _timer >= produce_interval:
		_spawn_item()
		_timer = 0.0
		produced = true
	_update_building_sprites(produced or _timer > 0.0, delta)

func _spawn_item() -> void:
	var output: OutputZone = get_first_output_zone()
	if output:
		output.spawn_item(item_id)

func get_last_resource() -> StringName:
	return item_id

# ── Night transform ──────────────────────────────────────────────────────────

const NIGHT_MODEL: PackedScene = preload("res://buildings/drill/models/turret.glb")
var turret: TurretBehavior = null

func set_night_mode(enabled: bool) -> void:
	is_night_mode = enabled
	if enabled:
		set_physics_process(false)
		if not turret:
			turret = TurretBehavior.new()
			turret.name = "TurretBehavior"
			add_child(turret)
		turret.activate(get_last_resource())
		_swap_to_night_model()
	else:
		set_physics_process(true)
		if turret:
			turret.deactivate()
		_swap_to_day_model()

func _swap_to_night_model() -> void:
	var building := get_parent()
	var old_model := building.get_node_or_null("Model")
	if old_model:
		building.remove_child(old_model)
		old_model.queue_free()
	var new_model: Node3D = NIGHT_MODEL.instantiate()
	new_model.name = "Model"
	building.add_child(new_model)

func _swap_to_day_model() -> void:
	var building := get_parent()
	var old_model := building.get_node_or_null("Model")
	if old_model:
		building.remove_child(old_model)
		old_model.queue_free()
	# Re-instantiate the day model from the building def
	var def = BuildingRegistry.get_building_def(building.building_id)
	if def:
		var day_scene: Node3D = def.scene.instantiate()
		var model := day_scene.get_node_or_null("Model")
		if model:
			model.owner = null
			day_scene.remove_child(model)
			building.add_child(model)
		day_scene.queue_free()

func get_progress() -> float:
	return clampf(_timer / produce_interval, 0.0, 1.0)

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	return {"timer": _timer}

func deserialize_state(state: Dictionary) -> void:
	if state.has("timer"):
		_timer = state["timer"]

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	return [
		{type = "stat", text = "Extracting: %s" % str(item_id).capitalize().replace("_", " ")},
		{type = "progress", value = get_progress()},
	]
