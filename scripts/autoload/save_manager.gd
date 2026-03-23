extends Node

signal save_completed
signal load_completed(success: bool)

const SAVE_VERSION := 1

## Set to true when "Continue" is clicked; game_world reads and clears this in _ready.
var pending_load: bool = false

## Save the current run state to the active account slot.
func save_run() -> void:
	var slot_dir := AccountManager.get_slot_dir(AccountManager.active_slot)
	var data := _serialize_run()

	# Rotate: current autosave becomes backup
	var autosave_path := slot_dir + "run_autosave.json"
	var backup_path := slot_dir + "run_backup.json"
	if FileAccess.file_exists(autosave_path):
		var old := FileAccess.open(autosave_path, FileAccess.READ)
		if old:
			var content := old.get_as_text()
			old = null
			var backup := FileAccess.open(backup_path, FileAccess.WRITE)
			if backup:
				backup.store_string(content)

	# Write new autosave
	var f := FileAccess.open(autosave_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))

	# Update meta last_played
	var meta := AccountManager.load_meta(AccountManager.active_slot)
	meta["last_played"] = Time.get_datetime_string_from_system(true)
	AccountManager.save_meta(AccountManager.active_slot, meta)

	save_completed.emit()
	print("[SaveManager] Run saved to slot %d" % AccountManager.active_slot)

## Load a run from the active account slot. Returns true on success.
func load_run() -> bool:
	var slot_dir := AccountManager.get_slot_dir(AccountManager.active_slot)
	var autosave_path := slot_dir + "run_autosave.json"
	var backup_path := slot_dir + "run_backup.json"

	var data := _read_json(autosave_path)
	if data.is_empty():
		print("[SaveManager] Autosave corrupt or missing, trying backup...")
		data = _read_json(backup_path)
	if data.is_empty():
		printerr("[SaveManager] No valid save found for slot %d" % AccountManager.active_slot)
		load_completed.emit(false)
		return false

	_deserialize_run(data)
	load_completed.emit(true)
	print("[SaveManager] Run loaded from slot %d" % AccountManager.active_slot)
	return true

## Check if a run save exists for the active slot.
func has_run_save() -> bool:
	return AccountManager.has_run_save()

## Delete run save for the active slot.
func delete_run_save() -> void:
	var slot_dir := AccountManager.get_slot_dir(AccountManager.active_slot)
	for filename: String in ["run_autosave.json", "run_backup.json"]:
		var path: String = slot_dir + filename
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

# ── Serialization ────────────────────────────────────────────────────────────

func _serialize_run() -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"camera": _serialize_camera(),
		"currency": GameManager.total_currency,
		"buildings": _serialize_buildings(),
	}
	return data

func _serialize_camera() -> Dictionary:
	var gw := _get_game_world()
	if not gw:
		return {"x": 640, "y": 360, "zoom": 1.0}
	var cam: Camera2D = gw.find_child("Camera2D", false, false)
	if not cam:
		return {"x": 640, "y": 360, "zoom": 1.0}
	return {"x": cam.position.x, "y": cam.position.y, "zoom": cam.zoom.x}

func _serialize_buildings() -> Array:
	var result: Array = []
	var serialized_nodes: Dictionary = {} # node instance_id -> true (avoid duplicates for multi-cell buildings)
	for pos in GameManager.buildings:
		var building = GameManager.buildings[pos]
		if not is_instance_valid(building):
			continue
		var nid: int = building.get_instance_id()
		if serialized_nodes.has(nid):
			continue
		serialized_nodes[nid] = true

		var entry := {
			"type": str(building.building_id),
			"grid_x": building.grid_pos.x,
			"grid_y": building.grid_pos.y,
			"rotation": building.rotation_index,
			"state": _serialize_building_state(building),
		}
		result.append(entry)
	return result

func _serialize_building_state(building: Node2D) -> Dictionary:
	var state := {}
	# Conveyor: serialize items on belt
	if building.has_meta("conveyor"):
		var conv: ConveyorBelt = building.get_meta("conveyor")
		var items_data: Array = []
		for item in conv.items:
			items_data.append({
				"id": str(item.id),
				"progress": item.progress,
				"entry_from_x": item.entry_from.x,
				"entry_from_y": item.entry_from.y,
			})
		state["items"] = items_data

	# Extractor: serialize timer and inventory
	if building.has_meta("extractor"):
		var ext: ExtractorLogic = building.get_meta("extractor")
		state["timer"] = ext._timer
		state["inventory"] = _serialize_inventory(ext.inventory)

	# Converter: serialize craft state and inventories
	if building.has_meta("converter"):
		var conv_logic: ConverterLogic = building.get_meta("converter")
		state["craft_timer"] = conv_logic._craft_timer
		state["active_recipe_id"] = str(conv_logic._active_recipe.id) if conv_logic._active_recipe else ""
		state["input_inv"] = _serialize_inventory(conv_logic.input_inv)
		state["output_inv"] = _serialize_inventory(conv_logic.output_inv)

	# Sink: serialize items consumed
	if building.has_meta("sink"):
		var snk: ItemSink = building.get_meta("sink")
		state["items_consumed"] = snk.items_consumed

	# Source: serialize timer
	if building.has_meta("source"):
		var src: ItemSource = building.get_meta("source")
		state["timer"] = src._timer

	return state

func _serialize_inventory(inv) -> Dictionary:
	var result := {}
	for item_id in inv.get_item_ids():
		result[str(item_id)] = inv.get_count(item_id)
	return result

# ── Deserialization ──────────────────────────────────────────────────────────

func _deserialize_run(data: Dictionary) -> void:
	# Clear existing state
	GameManager.clear_all()

	# Restore currency
	GameManager.total_currency = data.get("currency", 0)

	# Restore buildings
	var building_list: Array = data.get("buildings", [])
	for entry in building_list:
		var building_id := StringName(entry["type"])
		var grid_pos := Vector2i(int(entry["grid_x"]), int(entry["grid_y"]))
		var rot: int = int(entry["rotation"])

		var building := GameManager.place_building(building_id, grid_pos, rot)
		if not building:
			printerr("[SaveManager] Failed to place %s at %s" % [building_id, str(grid_pos)])
			continue

		var state: Dictionary = entry.get("state", {})
		_deserialize_building_state(building, state)

	# Restore camera (deferred so game world is ready)
	var cam_data: Dictionary = data.get("camera", {})
	if not cam_data.is_empty():
		call_deferred("_restore_camera", cam_data)

func _deserialize_building_state(building: Node2D, state: Dictionary) -> void:
	# Conveyor items
	if building.has_meta("conveyor") and state.has("items"):
		var conv: ConveyorBelt = building.get_meta("conveyor")
		for item_data in state["items"]:
			var item_id := StringName(item_data["id"])
			var entry_from := Vector2i(int(item_data["entry_from_x"]), int(item_data["entry_from_y"]))
			if conv.place_item(item_id, entry_from):
				# Restore exact progress
				var placed_item = conv.items[conv.items.size() - 1]
				placed_item.progress = item_data["progress"]
				conv._position_item(placed_item)

	# Extractor state
	if building.has_meta("extractor") and state.has("timer"):
		var ext: ExtractorLogic = building.get_meta("extractor")
		ext._timer = state["timer"]
		if state.has("inventory"):
			_deserialize_inventory(ext.inventory, state["inventory"])

	# Converter state
	if building.has_meta("converter"):
		var conv_logic: ConverterLogic = building.get_meta("converter")
		if state.has("craft_timer"):
			conv_logic._craft_timer = state["craft_timer"]
		if state.has("input_inv"):
			_deserialize_inventory(conv_logic.input_inv, state["input_inv"])
		if state.has("output_inv"):
			_deserialize_inventory(conv_logic.output_inv, state["output_inv"])
		if state.has("active_recipe_id") and state["active_recipe_id"] != "":
			var recipe_id := StringName(state["active_recipe_id"])
			for recipe in conv_logic.recipes:
				if recipe.id == recipe_id:
					conv_logic._active_recipe = recipe
					break

	# Sink state
	if building.has_meta("sink") and state.has("items_consumed"):
		var snk: ItemSink = building.get_meta("sink")
		snk.items_consumed = int(state["items_consumed"])

	# Source state
	if building.has_meta("source") and state.has("timer"):
		var src: ItemSource = building.get_meta("source")
		src._timer = state["timer"]

func _deserialize_inventory(inv, data: Dictionary) -> void:
	for item_id_str in data:
		var item_id := StringName(item_id_str)
		var count: int = int(data[item_id_str])
		# Ensure capacity exists before adding
		if inv.get_capacity(item_id) == 0:
			inv.set_capacity(item_id, count + 10)
		for i in count:
			inv.add(item_id)

func _restore_camera(cam_data: Dictionary) -> void:
	var gw := _get_game_world()
	if not gw:
		return
	var cam: Camera2D = gw.find_child("Camera2D", false, false)
	if cam:
		cam.position = Vector2(cam_data.get("x", 640), cam_data.get("y", 360))
		var z: float = cam_data.get("zoom", 1.0)
		cam.zoom = Vector2(z, z)

# ── Helpers ──────────────────────────────────────────────────────────────────

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}

func _get_game_world() -> Node:
	var root := get_tree().root
	for child in root.get_children():
		if child.name == "GameWorld":
			return child
	return null
