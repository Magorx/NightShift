class_name ItemSource
extends BuildingLogic

var direction: int = 0
var item_id: StringName = &"iron_ore"
var produce_interval: float = 1.0
var _timer: float = 0.0
var _has_ready_item: bool = false

## Items this source produces — round-robins through them.
var enabled_items: Array = [&"iron_ore"]
var _round_robin: RoundRobin = RoundRobin.new()

var _source_item_menu_scene: PackedScene = preload("res://scenes/ui/source_item_menu.tscn")

func configure(_def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(_def, p_grid_pos, rotation)
	direction = rotation
	item_id = &"iron_ore"

func _physics_process(delta: float) -> void:
	if enabled_items.is_empty():
		_has_ready_item = false
		return
	if not _has_ready_item:
		_timer += delta
		if _timer >= produce_interval:
			_has_ready_item = true
			_timer = 0.0
			var idx: int = _round_robin.next(enabled_items.size())
			item_id = enabled_items[idx]

func get_output_cell() -> Vector2i:
	return grid_pos + DIRECTION_VECTORS[direction]

func can_provide_to(target_pos: Vector2i) -> bool:
	return _has_ready_item and target_pos == get_output_cell()

func take_item() -> StringName:
	_has_ready_item = false
	return item_id

# ── Pull interface ─────────────────────────────────────────────────────────────

func has_output_toward(target_pos: Vector2i) -> bool:
	return target_pos == get_output_cell()

func peek_output_for(target_pos: Vector2i) -> StringName:
	if can_provide_to(target_pos):
		return item_id
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	if can_provide_to(target_pos):
		return take_item()
	return &""

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return false

# ── Popup interface ────────────────────────────────────────────────────────────

func has_custom_popup_row() -> bool:
	return true

func get_custom_row_items() -> Array:
	var items: Array = []
	for eid in enabled_items:
		items.append({id = eid})
	return items

func create_side_menu() -> Control:
	var menu = _source_item_menu_scene.instantiate()
	menu.populate(self)
	return menu

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {"timer": _timer}
	var is_default: bool = enabled_items.size() == 1 and enabled_items[0] == &"iron_ore"
	if not is_default:
		var items_arr: Array = []
		for eid in enabled_items:
			items_arr.append(str(eid))
		state["enabled_items"] = items_arr
		state["rr_index"] = _round_robin.index
	return state

func deserialize_state(state: Dictionary) -> void:
	if state.has("timer"):
		_timer = state["timer"]
	if state.has("enabled_items"):
		enabled_items.clear()
		for eid in state["enabled_items"]:
			enabled_items.append(StringName(eid))
	if state.has("rr_index"):
		_round_robin.index = state["rr_index"]
	# Set initial item_id from first enabled item
	if not enabled_items.is_empty():
		item_id = enabled_items[0]

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var names: Array = []
	for eid in enabled_items:
		names.append(str(eid).capitalize().replace("_", " "))
	return [
		{type = "stat", text = "Producing: %s" % ", ".join(names)},
		{type = "stat", text = "Rate: 1/%.1fs" % produce_interval},
	]
