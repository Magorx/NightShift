extends Node

signal save_completed
signal load_completed(success: bool)

const SAVE_VERSION := 2

## Set to true when "Continue" is clicked; game_world reads and clears this in _ready.
var pending_load: bool = false

## When false, save_run() is a no-op. Disabled during simulations/tests.
var autosave_enabled: bool = true

var _saved_max_physics_steps: int = 8

func _get_slot_dir() -> String:
	return AccountManager.get_slot_dir(AccountManager.active_slot)

## Save the current run state to the active account slot.
func save_run() -> void:
	if not autosave_enabled:
		return
	var slot_dir := _get_slot_dir()
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
	var slot_dir := _get_slot_dir()
	var autosave_path := slot_dir + "run_autosave.json"
	var backup_path := slot_dir + "run_backup.json"

	var data := _read_json(autosave_path)
	if data.is_empty():
		GameLogger.warn("Autosave corrupt or missing for slot %d, trying backup" % AccountManager.active_slot)
		data = _read_json(backup_path)
	if data.is_empty():
		GameLogger.err("No valid save found for slot %d" % AccountManager.active_slot)
		load_completed.emit(false)
		return false

	_deserialize_run(data)
	load_completed.emit(true)
	GameLogger.info("Save loaded from slot %d" % AccountManager.active_slot)
	return true

## Peek at save data without doing a full load (used for world seed on startup).
func peek_save_data() -> Dictionary:
	var slot_dir := _get_slot_dir()
	var data := _read_json(slot_dir + "run_autosave.json")
	if data.is_empty():
		data = _read_json(slot_dir + "run_backup.json")
	return data

## Check if a run save exists for the active slot.
func has_run_save() -> bool:
	return AccountManager.has_run_save()

## Delete run save for the active slot.
func delete_run_save() -> void:
	var slot_dir := _get_slot_dir()
	for filename: String in ["run_autosave.json", "run_backup.json"]:
		var path: String = slot_dir + filename
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

# ── Serialization ────────────────────────────────────────────────────────────

func _serialize_run() -> Dictionary:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"world_seed": GameManager.world_seed,
		"map_size": GameManager.map_size,
		"camera": _serialize_camera(),
		"currency": GameManager.total_currency,
		"buildings": _serialize_buildings(),
		"items_delivered": _serialize_items_delivered(),
		"creative_mode": GameManager.creative_mode,
		"deposit_stocks": _serialize_deposit_stocks(),
	}
	var gw := _get_game_world()
	if gw:
		data["terrain"] = gw.serialize_terrain()
		# Save terrain visual variants (fg + misc per cell)
		if GameManager.terrain_variants.size() > 0:
			data["terrain_variants"] = Marshalls.raw_to_base64(GameManager.terrain_variants)
		# Save terrain heights
		if GameManager.terrain_heights.size() > 0:
			data["terrain_heights"] = Marshalls.raw_to_base64(GameManager.terrain_heights.to_byte_array())
	if GameManager.player and is_instance_valid(GameManager.player):
		data["player"] = GameManager.player.serialize()
	data["physics_items"] = _serialize_physics_items()
	return data

func _serialize_physics_items() -> Array:
	var result: Array = []
	var gw := _get_game_world()
	if not gw:
		return result
	for item in gw.get_tree().get_nodes_in_group("physics_items"):
		if is_instance_valid(item) and item is PhysicsItem:
			result.append({
				"item_id": str(item.item_id),
				"x": item.position.x,
				"y": item.position.y,
				"z": item.position.z,
				"vx": item.linear_velocity.x,
				"vy": item.linear_velocity.y,
				"vz": item.linear_velocity.z,
			})
	return result

func _serialize_deposit_stocks() -> Dictionary:
	var result := {}
	for pos: Vector2i in GameManager.deposit_stocks:
		var stock: int = GameManager.deposit_stocks[pos]
		if stock != -1:  # Only save finite stocks to keep save small
			result["%d,%d" % [pos.x, pos.y]] = stock
	return result

func _serialize_items_delivered() -> Dictionary:
	var result := {}
	for item_id in GameManager.items_delivered:
		result[str(item_id)] = GameManager.items_delivered[item_id]
	return result

func _serialize_camera() -> Dictionary:
	var gw := _get_game_world()
	if not gw:
		return {"zoom": 1.0}
	var cam = gw.find_child("Camera3D", false, false)
	if cam and cam is Camera3D:
		return {"zoom": cam.size}
	return {"zoom": 1.0}

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
	var version: int = data.get("version", 0)
	if version > SAVE_VERSION:
		GameLogger.err("Save version %d is newer than supported %d — skipping load" % [version, SAVE_VERSION])
		return

	# Clear existing state
	GameManager.clear_all()

	# Restore map size and currency
	GameManager.map_size = int(data.get("map_size", 64))
	GameManager.total_currency = data.get("currency", 0)
	GameManager.creative_mode = data.get("creative_mode", false)

	# Restore terrain (deposits, walls, grass variants) from packed data
	var terrain_data: String = data.get("terrain", "")
	if not terrain_data.is_empty():
		var gw := _get_game_world()
		if gw:
			gw.deserialize_terrain(terrain_data)
			# Restore terrain visual variants
			var variant_data: String = data.get("terrain_variants", "")
			if not variant_data.is_empty():
				GameManager.terrain_variants = Marshalls.base64_to_raw(variant_data)
			else:
				# Legacy save without variants: generate them fresh
				_regenerate_terrain_variants()
			# Restore terrain heights
			var height_data: String = data.get("terrain_heights", "")
			if not height_data.is_empty():
				var height_bytes := Marshalls.base64_to_raw(height_data)
				GameManager.terrain_heights = height_bytes.to_float32_array()
			else:
				# Legacy save without heights: flat terrain
				GameManager.terrain_heights = PackedFloat32Array()
				GameManager.terrain_heights.resize(GameManager.map_size * GameManager.map_size)
				GameManager.terrain_heights.fill(0.0)

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

	# Restore deposit stocks (finite stocks only; infinite are default)
	var stocks_data: Dictionary = data.get("deposit_stocks", {})
	_deserialize_deposit_stocks(stocks_data)

	# Restore items delivered
	var delivered: Dictionary = data.get("items_delivered", {})
	GameManager.items_delivered.clear()
	for item_id_str in delivered:
		var iid := StringName(item_id_str)
		if GameManager.is_valid_item_id(iid):
			GameManager.items_delivered[iid] = int(delivered[item_id_str])
		else:
			GameLogger.warn("Items delivered: skipped invalid item '%s'" % iid)

	# Prevent physics catch-up: loading takes real time, so Godot would run
	# multiple physics ticks on the first frame, making items jump forward.
	# Limit to 1 tick, then restore on the next frame.
	_saved_max_physics_steps = Engine.max_physics_steps_per_frame
	Engine.max_physics_steps_per_frame = 1
	call_deferred("_reset_max_physics_steps")

	# Restore player state
	var player_data: Dictionary = data.get("player", {})
	if not player_data.is_empty() and GameManager.player:
		GameManager.player.deserialize(player_data)

	# Restore ground items
	# Restore physics items (items on conveyors / in transit)
	var physics_items_data: Array = data.get("physics_items", [])

	# Migrate legacy ground_items to physics_items format
	var ground_items_data: Array = data.get("ground_items", [])
	for entry in ground_items_data:
		var iid := StringName(entry.get("item_id", ""))
		if not GameManager.is_valid_item_id(iid):
			continue
		var qty: int = int(entry.get("quantity", 1))
		var px: float = float(entry.get("x", 0))
		var pz: float = float(entry.get("y", 0))
		for i in qty:
			physics_items_data.append({"item_id": str(iid), "x": px + randf_range(-0.1, 0.1), "y": 0.3, "z": pz + randf_range(-0.1, 0.1), "vx": 0, "vy": 0, "vz": 0})

	_deserialize_physics_items(physics_items_data)

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
		var length: int = int(state.get("tunnel_length", 1))
		GameManager.link_tunnel_pair(grid_pos, partner_pos, length)

## Restore finite deposit stocks from saved data.
func _deserialize_deposit_stocks(data: Dictionary) -> void:
	for key: String in data:
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		var pos := Vector2i(int(parts[0]), int(parts[1]))
		GameManager.deposit_stocks[pos] = int(data[key])

func _deserialize_physics_items(items_data: Array) -> void:
	if items_data.is_empty():
		return
	for entry in items_data:
		var iid := StringName(entry.get("item_id", ""))
		if not GameManager.is_valid_item_id(iid):
			GameLogger.warn("Physics item: skipped invalid item '%s'" % iid)
			continue
		var pos := Vector3(
			float(entry.get("x", 0)),
			float(entry.get("y", 0.2)),
			float(entry.get("z", 0)),
		)
		var vel := Vector3(
			float(entry.get("vx", 0)),
			float(entry.get("vy", 0)),
			float(entry.get("vz", 0)),
		)
		var item := PhysicsItem.spawn(iid, pos)
		if item:
			item.linear_velocity = vel

func _reset_max_physics_steps() -> void:
	Engine.max_physics_steps_per_frame = _saved_max_physics_steps

func _restore_camera(cam_data: Dictionary) -> void:
	var gw := _get_game_world()
	if not gw:
		return
	var cam = gw.find_child("Camera3D", false, false)
	if not cam:
		cam = gw.find_child("Camera2D", false, false)
	if cam:
		# Position follows the player; only restore zoom
		var z: float = cam_data.get("zoom", 1.0)
		if cam is Camera3D:
			# Legacy saves stored zoom as 0.5-3.0; new saves store ortho size directly
			var ortho_size: float = z if z > 5.0 else z * 40.0
			cam.size = ortho_size
			if cam.has_method("set_target_zoom"):
				cam.set_target_zoom(ortho_size)
		else:
			cam.zoom = Vector2(z, z)
			if cam.has_method("set_target_zoom"):
				cam.set_target_zoom(z)
		# Snap camera to player position if available
		if GameManager.player and is_instance_valid(GameManager.player):
			if cam.has_method("snap_to"):
				cam.snap_to(GameManager.player.position)
			else:
				cam.position = GameManager.player.position

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

## Generate terrain variants for legacy saves that don't have them.
func _regenerate_terrain_variants() -> void:
	var map_size := GameManager.map_size
	var count := map_size * map_size
	var variants := PackedByteArray()
	variants.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.world_seed + 777
	for i in range(count):
		var tile_type: int = GameManager.terrain_tile_types[i] if i < GameManager.terrain_tile_types.size() else 0
		var fg_count := 6 if tile_type <= 6 and tile_type != 4 else 3  # grass types = 0,5,6
		var misc_count := fg_count
		variants[i] = (rng.randi() % fg_count) | ((rng.randi() % misc_count) << 4)
	GameManager.terrain_variants = variants

func _get_game_world() -> Node:
	var root := get_tree().root
	for child in root.get_children():
		if child.name == "GameWorld":
			return child
	return null
