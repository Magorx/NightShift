class_name ItemSource
extends BuildingLogic
## Debug building: spawns PhysicsItems on a timer, round-robining through
## the enabled_items list.

var direction: int = 0
var item_id: StringName = &"pyromite"
var produce_interval: float = 1.0
var _timer: float = 0.0

var enabled_items: Array = [&"pyromite"]
var _round_robin: RoundRobin = RoundRobin.new()

var _source_item_menu_scene: PackedScene = preload("res://scenes/ui/source_item_menu.tscn")

func configure(def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(def, p_grid_pos, rotation)
	direction = rotation
	item_id = &"pyromite"

func _physics_process(delta: float) -> void:
	if enabled_items.is_empty():
		_update_building_sprites(false, delta)
		return
	_timer += delta
	if _timer >= produce_interval:
		_timer = 0.0
		var idx: int = _round_robin.next(enabled_items.size())
		item_id = enabled_items[idx]
		_spawn_item()
	_update_building_sprites(true, delta)

func _spawn_item() -> void:
	var output: OutputZone = get_first_output_zone()
	if output:
		output.spawn_item(item_id)

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
	var is_default: bool = enabled_items.size() == 1 and enabled_items[0] == &"pyromite"
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
	if not enabled_items.is_empty():
		item_id = enabled_items[0]

func get_info_stats() -> Array:
	var names: Array = []
	for eid in enabled_items:
		names.append(str(eid).capitalize().replace("_", " "))
	return [
		{type = "stat", text = "Producing: %s" % ", ".join(names)},
		{type = "stat", text = "Rate: 1/%.1fs" % produce_interval},
	]
