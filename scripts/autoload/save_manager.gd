extends Node

signal save_completed
signal load_completed(success: bool)

const SAVE_VERSION := 1

## Set to true when "Continue" is clicked; game_world reads and clears this in _ready.
var pending_load: bool = false

## When false, save_run() is a no-op. Disabled during simulations/tests.
var autosave_enabled: bool = true

## Save the current run state to the active account slot.
func save_run() -> void:
	if not autosave_enabled:
		return
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

	# Update meta last_played and hotkeys
	var meta := AccountManager.load_meta(AccountManager.active_slot)
	meta["last_played"] = Time.get_datetime_string_from_system(true)
	var hotkeys := {}
	for keycode in GameManager.building_hotkeys:
		hotkeys[str(keycode)] = str(GameManager.building_hotkeys[keycode])
	meta["building_hotkeys"] = hotkeys
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
		"items_delivered": _serialize_items_delivered(),
		"time_speed": _serialize_time_speed(),
	}
	return data

func _serialize_items_delivered() -> Dictionary:
	var result := {}
	for item_id in GameManager.items_delivered:
		result[str(item_id)] = GameManager.items_delivered[item_id]
	return result

func _serialize_time_speed() -> Dictionary:
	var hud = _get_hud()
	if hud:
		return {"speed_index": hud.speed_index, "paused": hud.paused}
	return {"speed_index": 2, "paused": false}

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
	for building in GameManager.unique_buildings:
		if not is_instance_valid(building):
			continue
		result.append({
			"type": str(building.building_id),
			"grid_x": building.grid_pos.x,
			"grid_y": building.grid_pos.y,
			"rotation": building.rotation_index,
			"state": _serialize_building_state(building),
		})
	return result

func _serialize_building_state(building: Node2D) -> Dictionary:
	var state := {}
	var logic: Node = building.logic
	if not logic:
		return state

	if logic is ConveyorBelt:
		var items_data: Array = []
		for item in logic.buffer.items:
			items_data.append({
				"id": str(item.id),
				"progress": item.progress,
				"entry_from_x": item.entry_from.x,
				"entry_from_y": item.entry_from.y,
			})
		state["items"] = items_data

	elif logic is ExtractorLogic:
		state["timer"] = logic._timer
		state["inventory"] = _serialize_inventory(logic.inventory)

	elif logic is ConverterLogic:
		state["craft_timer"] = logic._craft_timer
		state["active_recipe_id"] = str(logic._active_recipe.id) if logic._active_recipe else ""
		state["input_inv"] = _serialize_inventory(logic.input_inv)
		state["output_inv"] = _serialize_inventory(logic.output_inv)

	elif logic is ItemSink:
		state["items_consumed"] = logic.items_consumed

	elif logic is ItemSource:
		state["timer"] = logic._timer

	elif logic is SplitterLogic:
		var buffer_data: Array = []
		for item in logic.buffer.items:
			buffer_data.append({
				"id": str(item.id),
				"from_dir_idx": item.from_dir_idx,
				"output_dir_idx": item.output_dir_idx,
				"progress": item.progress,
			})
		state["buffer"] = buffer_data

	elif logic is JunctionLogic:
		var axes_data: Array = []
		for axis in 2:
			var buffer_data: Array = []
			for item in logic.buffers[axis].items:
				buffer_data.append({
					"id": str(item.id),
					"from_dir_idx": item.from_dir_idx,
					"output_dir_idx": item.output_dir_idx,
					"progress": item.progress,
				})
			axes_data.append(buffer_data)
		state["junction_buffers"] = axes_data

	elif logic is TunnelLogic:
		state["tunnel_is_input"] = logic.is_input
		state["tunnel_direction"] = logic.direction
		state["tunnel_length"] = logic.tunnel_length
		if logic.partner:
			state["tunnel_partner_x"] = logic.partner.grid_pos.x
			state["tunnel_partner_y"] = logic.partner.grid_pos.y
		if logic.is_input:
			var buffer_data: Array = []
			for item in logic.buffer.items:
				buffer_data.append({
					"id": str(item.id),
					"progress": item.progress,
				})
			state["tunnel_buffer"] = buffer_data

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

	# Deferred pass: link tunnel pairs using saved partner positions
	_link_tunnels_deferred(building_list)

	# Restore items delivered
	var delivered: Dictionary = data.get("items_delivered", {})
	GameManager.items_delivered.clear()
	for item_id_str in delivered:
		GameManager.items_delivered[StringName(item_id_str)] = int(delivered[item_id_str])

	# Migrate old run-level hotkeys to account meta if present
	if data.has("building_hotkeys") and not data["building_hotkeys"].is_empty():
		var meta := AccountManager.load_meta(AccountManager.active_slot)
		if not meta.has("building_hotkeys"):
			meta["building_hotkeys"] = data["building_hotkeys"]
			AccountManager.save_meta(AccountManager.active_slot, meta)

	# Load hotkeys from account meta (not from run save)
	AccountManager.load_hotkeys()

	# Restore time speed (deferred so HUD is ready)
	var time_data: Dictionary = data.get("time_speed", {})
	if not time_data.is_empty():
		call_deferred("_restore_time_speed", time_data)

	# Restore camera (deferred so game world is ready)
	var cam_data: Dictionary = data.get("camera", {})
	if not cam_data.is_empty():
		call_deferred("_restore_camera", cam_data)

func _deserialize_building_state(building: Node2D, state: Dictionary) -> void:
	var logic: Node = building.logic
	if not logic:
		return

	if logic is ConveyorBelt and state.has("items"):
		for item_data in state["items"]:
			var item_id := StringName(item_data["id"])
			var entry_from := Vector2i(int(item_data["entry_from_x"]), int(item_data["entry_from_y"]))
			if logic.place_item(item_id, entry_from):
				var placed_item = logic.buffer.items[logic.buffer.size() - 1]
				placed_item.progress = item_data["progress"]
				logic._position_item(placed_item)

	elif logic is ExtractorLogic:
		if state.has("timer"):
			logic._timer = state["timer"]
		if state.has("inventory"):
			_deserialize_inventory(logic.inventory, state["inventory"])

	elif logic is ConverterLogic:
		if state.has("craft_timer"):
			logic._craft_timer = state["craft_timer"]
		if state.has("input_inv"):
			_deserialize_inventory(logic.input_inv, state["input_inv"])
		if state.has("output_inv"):
			_deserialize_inventory(logic.output_inv, state["output_inv"])
		if state.has("active_recipe_id") and state["active_recipe_id"] != "":
			var recipe_id := StringName(state["active_recipe_id"])
			for recipe in logic.recipes:
				if recipe.id == recipe_id:
					logic._active_recipe = recipe
					break

	elif logic is ItemSink and state.has("items_consumed"):
		logic.items_consumed = int(state["items_consumed"])

	elif logic is ItemSource and state.has("timer"):
		logic._timer = state["timer"]

	elif logic is SplitterLogic and state.has("buffer"):
		for item_data in state["buffer"]:
			var item: Dictionary = logic.buffer.add_item(StringName(item_data["id"]), {
				from_dir_idx = int(item_data["from_dir_idx"]),
				output_dir_idx = int(item_data.get("output_dir_idx", -1)),
			})
			item.progress = float(item_data.get("progress", 0.0))
			logic._position_item(item)

	elif logic is JunctionLogic and state.has("junction_buffers"):
		var axes_data: Array = state["junction_buffers"]
		for axis in mini(axes_data.size(), 2):
			for item_data in axes_data[axis]:
				var item: Dictionary = logic.buffers[axis].add_item(StringName(item_data["id"]), {
					from_dir_idx = int(item_data["from_dir_idx"]),
					output_dir_idx = int(item_data["output_dir_idx"]),
				})
				item.progress = float(item_data.get("progress", 0.0))
				logic._position_item(item)

	elif logic is TunnelLogic and state.has("tunnel_buffer"):
		for item_data in state["tunnel_buffer"]:
			var item: Dictionary = {
				id = StringName(item_data["id"]),
				progress = float(item_data.get("progress", 0.0)),
			}
			logic.buffer.items.append(item)

## Re-link tunnel input/output pairs after all buildings are deserialized.
func _link_tunnels_deferred(building_list: Array) -> void:
	for entry in building_list:
		var state: Dictionary = entry.get("state", {})
		if not state.has("tunnel_partner_x"):
			continue
		if not state.get("tunnel_is_input", false):
			continue
		var grid_pos := Vector2i(int(entry["grid_x"]), int(entry["grid_y"]))
		var partner_pos := Vector2i(int(state["tunnel_partner_x"]), int(state["tunnel_partner_y"]))
		var in_building = GameManager.buildings.get(grid_pos)
		var out_building = GameManager.buildings.get(partner_pos)
		if not in_building or not out_building:
			continue
		if not in_building.logic is TunnelLogic or not out_building.logic is TunnelLogic:
			continue
		var length: int = int(state.get("tunnel_length", 1))
		in_building.logic.setup_pair(out_building.logic, length)
		out_building.logic.setup_pair(in_building.logic, length)
		in_building.logic.restore_visuals()

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

func _restore_time_speed(data: Dictionary) -> void:
	var hud = _get_hud()
	if hud:
		hud.speed_index = int(data.get("speed_index", 2))
		var was_paused: bool = data.get("paused", false)
		if was_paused:
			hud.paused = false # Ensure toggle works
			hud._toggle_pause()
		else:
			Engine.time_scale = hud.SPEED_STEPS[hud.speed_index]
			hud.speed_label.text = hud.SPEED_LABELS[hud.speed_index]
			hud._update_speed_buttons()

func _get_game_world() -> Node:
	var root := get_tree().root
	for child in root.get_children():
		if child.name == "GameWorld":
			return child
	return null

func _get_hud() -> Control:
	var gw := _get_game_world()
	if not gw:
		return null
	var ui = gw.find_child("UI", false, false)
	if not ui:
		return null
	return ui.find_child("HUD", false, false)
