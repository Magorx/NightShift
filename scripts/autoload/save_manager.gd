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
		var state: Dictionary = {}
		if building.logic:
			state = building.logic.serialize_state()
		result.append({
			"type": str(building.building_id),
			"grid_x": building.grid_pos.x,
			"grid_y": building.grid_pos.y,
			"rotation": building.rotation_index,
			"state": state,
		})
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
		if building.logic and not state.is_empty():
			building.logic.deserialize_state(state)

	# Deferred pass: link tunnel pairs using saved partner positions
	_link_tunnels_deferred(building_list)

	# Deferred pass: restore energy node connections
	_link_energy_nodes_deferred(building_list)

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

## Re-link energy node connections after all buildings are deserialized.
func _link_energy_nodes_deferred(building_list: Array) -> void:
	if not GameManager.energy_system:
		return
	for entry in building_list:
		var state: Dictionary = entry.get("state", {})
		if not state.has("energy_node"):
			continue
		var en_data: Dictionary = state["energy_node"]
		if not en_data.has("connections"):
			continue
		var grid_pos := Vector2i(int(entry["grid_x"]), int(entry["grid_y"]))
		var building = GameManager.buildings.get(grid_pos)
		if not building or not building.logic:
			continue
		var enode = building.logic.get_energy_node()
		if not enode:
			continue
		var conn_list: Array = en_data["connections"]
		for conn in conn_list:
			var target_pos := Vector2i(int(conn["x"]), int(conn["y"]))
			var target_building = GameManager.buildings.get(target_pos)
			if not target_building or not target_building.logic:
				continue
			var target_node = target_building.logic.get_energy_node()
			if not target_node:
				continue
			# Only connect if not already connected (avoid duplicates from both sides)
			if not enode.is_connected_to(target_node):
				enode.connect_to(target_node)
	# Mark networks dirty so they rebuild with restored connections
	GameManager.energy_system.mark_dirty()

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
