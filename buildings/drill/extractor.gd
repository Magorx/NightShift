class_name ExtractorLogic
extends BuildingLogic
## Drill extractor: spawns PhysicsItem at the output zone on a timer.
## If no conveyor carries items away, they pile up at the output.

func get_placement_error(p_grid_pos: Vector2i, _rotation: int) -> String:
	if not GameManager.deposits.has(p_grid_pos):
		return "No resource deposit"
	return ""

var direction: int = 0
var item_id: StringName = &"pyromite"
var produce_interval: float = 2.0
var _timer: float = 0.0

func configure(def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(def, p_grid_pos, rotation)
	direction = rotation
	item_id = GameManager.deposits.get(grid_pos, &"pyromite")
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
	var output: OutputZone = _get_output_zone()
	if output:
		output.spawn_item(item_id)

func _get_output_zone() -> OutputZone:
	var outputs := get_parent().get_node_or_null("Outputs")
	if outputs and outputs.get_child_count() > 0:
		return outputs.get_child(0) as OutputZone
	return null

func get_progress() -> float:
	return clampf(_timer / produce_interval, 0.0, 1.0)

# ── Pull interface stubs (old system compat) ──────────────────────────────────

func has_output_toward(target_pos: Vector2i) -> bool:
	return target_pos == grid_pos + DIRECTION_VECTORS[direction]

func can_provide_to(_target_pos: Vector2i) -> bool:
	return false

func peek_output_for(_target_pos: Vector2i) -> StringName:
	return &""

func take_item_for(_target_pos: Vector2i) -> StringName:
	return &""

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return false

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

func get_inventory_items() -> Array:
	return []

func remove_inventory_item(_item_id: StringName, _count: int) -> int:
	return 0
