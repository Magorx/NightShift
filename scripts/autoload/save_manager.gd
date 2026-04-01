extends Node

signal save_completed
signal load_completed(success: bool)

const SAVE_VERSION := 1

## Set to true when "Continue" is clicked; game_world reads and clears this in _ready.
var pending_load: bool = false

## When false, save_run() is a no-op. Disabled during simulations/tests.
var autosave_enabled: bool = true

var _saved_max_physics_steps: int = 8

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
	var slot_dir := AccountManager.get_slot_dir(AccountManager.active_slot)
	var data := _read_json(slot_dir + "run_autosave.json")
	if data.is_empty():
		data = _read_json(slot_dir + "run_backup.json")
	return data

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
		"world_seed": GameManager.world_seed,
		"map_size": GameManager.map_size,
		"camera": _serialize_camera(),
		"currency": GameManager.total_currency,
		"buildings": _serialize_buildings(),
		"items_delivered": _serialize_items_delivered(),
		"time_speed": _serialize_time_speed(),
		"hud_state": _serialize_hud_state(),
		"research": ResearchManager.serialize(),
		"contracts": ContractManager.serialize(),
		"creative_mode": GameManager.creative_mode,
		"deposit_stocks": _serialize_deposit_stocks(),
		"ui_panels": _serialize_ui_panels(),
	}
	var gw := _get_game_world()
	if gw:
		data["terrain"] = gw.serialize_terrain()
		# Save terrain visual variants (fg + misc per cell)
		if GameManager.terrain_variants.size() > 0:
			data["terrain_variants"] = Marshalls.raw_to_base64(GameManager.terrain_variants)
	if GameManager.player and is_instance_valid(GameManager.player):
		data["player"] = GameManager.player.serialize()
	data["ground_items"] = _serialize_ground_items()
	return data

func _serialize_ground_items() -> Array:
	var result: Array = []
	var gw := _get_game_world()
	if not gw:
		return result
	for item in gw.get_tree().get_nodes_in_group("ground_items"):
		if is_instance_valid(item) and item.has_method("serialize"):
			result.append(item.serialize())
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

func _serialize_time_speed() -> Dictionary:
	var hud = _get_hud()
	if hud:
		return {"speed_index": hud.speed_index, "paused": hud.paused}
	return {"speed_index": 2, "paused": false}

func _serialize_hud_state() -> Dictionary:
	var hud = _get_hud()
	if hud:
		return {
			"contracts_collapsed": hud._contracts_collapsed,
			"menu_expanded": hud._menu_expanded,
		}
	return {}

func _serialize_ui_panels() -> Dictionary:
	var hud = _get_hud()
	if hud and hud.has_method("serialize_ui_panels"):
		return hud.serialize_ui_panels()
	return {}

func _serialize_camera() -> Dictionary:
	var gw := _get_game_world()
	if not gw:
		return {"zoom": 1.0}
	var cam: Camera2D = gw.find_child("Camera2D", false, false)
	if not cam:
		return {"zoom": 1.0}
	# Only save zoom — camera position follows the player on load
	return {"zoom": cam.zoom.x}

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

	# Suppress energy auto-linking while placing saved buildings
	if GameManager.energy_system:
		GameManager.energy_system.begin_batch_load()

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

	if GameManager.energy_system:
		GameManager.energy_system.end_batch_load()

	# Deferred pass: link tunnel pairs using saved partner positions
	_link_tunnels_deferred(building_list)

	# Deferred pass: link biomass extractor pairs
	_link_biomass_extractors_deferred(building_list)

	# Deferred pass: restore energy node connections
	_link_energy_nodes_deferred(building_list)

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

	# Migrate old run-level hotkeys to account meta if present
	if data.has("building_hotkeys") and not data["building_hotkeys"].is_empty():
		var meta := AccountManager.load_meta(AccountManager.active_slot)
		if not meta.has("building_hotkeys"):
			meta["building_hotkeys"] = data["building_hotkeys"]
			AccountManager.save_meta(AccountManager.active_slot, meta)

	# Restore research state
	var research_data: Dictionary = data.get("research", {})
	if not research_data.is_empty():
		ResearchManager.deserialize(research_data)

	# Restore contract state
	var contract_data: Dictionary = data.get("contracts", {})
	if not contract_data.is_empty():
		ContractManager.deserialize(contract_data)

	# Load hotkeys from account meta (not from run save)
	AccountManager.load_hotkeys()

	# Prevent physics catch-up: loading takes real time, so Godot would run
	# multiple physics ticks on the first frame, making items jump forward.
	# Limit to 1 tick, then restore on the next frame.
	_saved_max_physics_steps = Engine.max_physics_steps_per_frame
	Engine.max_physics_steps_per_frame = 1
	call_deferred("_reset_max_physics_steps")

	# Restore time speed (deferred so HUD is ready)
	var time_data: Dictionary = data.get("time_speed", {})
	if not time_data.is_empty():
		call_deferred("_restore_time_speed", time_data)

	# Restore HUD collapse states (deferred so HUD is ready)
	var hud_state: Dictionary = data.get("hud_state", {})
	if not hud_state.is_empty():
		call_deferred("_restore_hud_state", hud_state)

	# Restore UI panel states (deferred so panels are ready)
	var ui_panels: Dictionary = data.get("ui_panels", {})
	if not ui_panels.is_empty():
		call_deferred("_restore_ui_panels", ui_panels)

	# Restore player state
	var player_data: Dictionary = data.get("player", {})
	if not player_data.is_empty() and GameManager.player:
		GameManager.player.deserialize(player_data)

	# Restore ground items
	var ground_items_data: Array = data.get("ground_items", [])
	_deserialize_ground_items(ground_items_data)

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
		if not in_building.logic is UndergroundTransportLogic or not out_building.logic is UndergroundTransportLogic:
			continue
		var length: int = int(state.get("tunnel_length", 1))
		in_building.logic.setup_pair(out_building.logic, length)
		out_building.logic.setup_pair(in_building.logic, length)
		in_building.logic.restore_visuals()

## Restore finite deposit stocks from saved data.
func _deserialize_deposit_stocks(data: Dictionary) -> void:
	# First, set all existing deposits to their default stock
	# (world gen already set stocks for new games; for loaded games we override)
	for pos: Vector2i in GameManager.deposits:
		if not GameManager.deposit_stocks.has(pos):
			# Biomass deposits without saved stock data get default 5
			if GameManager.deposits[pos] == &"biomass":
				GameManager.deposit_stocks[pos] = 5
			else:
				GameManager.deposit_stocks[pos] = -1
	# Override with saved finite stocks
	for key: String in data:
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		var pos := Vector2i(int(parts[0]), int(parts[1]))
		GameManager.deposit_stocks[pos] = int(data[key])

## Re-link biomass extractor pairs after all buildings are deserialized.
func _link_biomass_extractors_deferred(building_list: Array) -> void:
	for entry in building_list:
		var state: Dictionary = entry.get("state", {})
		if not state.has("output_x"):
			continue
		var grid_pos := Vector2i(int(entry["grid_x"]), int(entry["grid_y"]))
		var output_pos := Vector2i(int(state["output_x"]), int(state["output_y"]))
		var ext_building = GameManager.buildings.get(grid_pos)
		var out_building = GameManager.buildings.get(output_pos)
		if not ext_building or not out_building:
			continue
		if not ext_building.logic is BiomassExtractorLogic:
			continue
		if not out_building.logic is BiomassExtractorOutputLogic:
			continue
		ext_building.logic.output_device = out_building.logic
		out_building.logic.extractor = ext_building.logic
	# Initialize cluster drain manager
	if not GameManager.cluster_drain_manager:
		var CDM = load("res://scripts/game/cluster_drain_manager.gd")
		GameManager.cluster_drain_manager = CDM.new()
	GameManager.cluster_drain_manager.invalidate_cache()

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

func _deserialize_ground_items(items_data: Array) -> void:
	var gw := _get_game_world()
	if not gw:
		return
	var ground_item_scene := preload("res://player/ground_item.tscn")
	for entry in items_data:
		var iid := StringName(entry.get("item_id", ""))
		if not GameManager.is_valid_item_id(iid):
			GameLogger.warn("Ground item: skipped invalid item '%s'" % iid)
			continue
		var item = ground_item_scene.instantiate()
		item.item_id = iid
		item.quantity = int(entry.get("quantity", 1))
		item.position = Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
		item.despawn_timer = float(entry.get("despawn", 120))
		gw.add_child(item)

func _reset_max_physics_steps() -> void:
	Engine.max_physics_steps_per_frame = _saved_max_physics_steps

func _restore_camera(cam_data: Dictionary) -> void:
	var gw := _get_game_world()
	if not gw:
		return
	var cam: Camera2D = gw.find_child("Camera2D", false, false)
	if cam:
		# Position follows the player; only restore zoom
		var z: float = cam_data.get("zoom", 1.0)
		cam.zoom = Vector2(z, z)
		if cam.has_method("set_target_zoom"):
			cam.set_target_zoom(z)
		# Snap camera to player position if available
		if GameManager.player and is_instance_valid(GameManager.player):
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

func _restore_ui_panels(data: Dictionary) -> void:
	var hud = _get_hud()
	if hud and hud.has_method("deserialize_ui_panels"):
		hud.deserialize_ui_panels(data)

func _restore_hud_state(data: Dictionary) -> void:
	var hud = _get_hud()
	if not hud:
		return
	if data.get("contracts_collapsed", false) and not hud._contracts_collapsed:
		hud._on_collapse_pressed()
	if data.get("menu_expanded", false) and not hud._menu_expanded:
		hud._on_menu_toggle_pressed()

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

func _get_hud() -> Control:
	var gw := _get_game_world()
	if not gw:
		return null
	var ui = gw.find_child("UI", false, false)
	if not ui:
		return null
	return ui.find_child("HUD", false, false)
