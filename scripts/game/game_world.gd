class_name GameWorld
extends Node2D

const TILE_SIZE := 32
const ZOOM_SPEED := 0.1
const MIN_ZOOM := 0.25
const MAX_ZOOM := 3.0
const AUTOSAVE_INTERVAL := 60.0
const CAMERA_FOLLOW_SPEED := 8.0

@onready var camera: Camera2D = $Camera2D
@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var grid_overlay: Node2D = $GridOverlay
@onready var build_system: Node2D = $BuildSystem
@onready var hud: Control = $UI/HUD

var player  # Player (CharacterBody2D)
var building_collision  # BuildingCollision (StaticBody2D)

var _autosave_timer: float = 0.0
var _pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
var _popup_scene: PackedScene = preload("res://scenes/ui/building_popup.tscn")
var _world_gen_script = preload("res://scripts/game/world_generator.gd")
var _stress_gen_script = preload("res://scripts/game/stress_test_generator.gd")
var _visual_mgr_script = preload("res://scripts/game/item_visual_manager.gd")
var _tick_system_script = preload("res://scripts/game/building_tick_system.gd")
var _conv_visual_mgr_script = preload("res://scripts/game/conveyor_visual_manager.gd")
var _player_scene: PackedScene = preload("res://player/player.tscn")
var _building_collision_script = preload("res://scripts/game/building_collision.gd")
var _popup: PanelContainer
var _last_time_usec: int = 0

func _ready() -> void:
	GameManager.building_layer = $BuildingLayer
	GameManager.item_layer = $ItemLayer
	GameManager.conveyor_system = $ConveyorSystem
	GameManager.energy_system = $EnergySystem
	# Initialize MultiMesh item visual system
	GameManager.item_visual_manager = _visual_mgr_script.new()
	GameManager.item_visual_manager.attach_to($ItemLayer)
	# Initialize batched building tick system
	var tick_system = _tick_system_script.new()
	tick_system.name = "BuildingTickSystem"
	add_child(tick_system)
	GameManager.building_tick_system = tick_system
	# Initialize MultiMesh conveyor visual system
	GameManager.conveyor_visual_manager = _conv_visual_mgr_script.new()
	GameManager.conveyor_visual_manager.attach_to($BuildingLayer)
	GameManager.clear_all()
	GameManager.deposits.clear()
	GameManager.walls.clear()

	# Create building collision body (must exist before placing buildings)
	building_collision = _building_collision_script.new()
	building_collision.name = "BuildingCollision"
	add_child(building_collision)
	GameManager.building_collision = building_collision

	# Determine world seed: use saved seed when loading, random for new game
	var has_saved_terrain := false
	if SaveManager.pending_load:
		var save_data: Dictionary = SaveManager.peek_save_data()
		GameManager.world_seed = int(save_data.get("world_seed", randi()))
		GameManager.map_size = int(save_data.get("map_size", 64))
		has_saved_terrain = save_data.has("terrain")
	elif GameManager.world_seed == 0:
		GameManager.world_seed = randi()

	_setup_tileset()
	# Skip world generation if terrain will be restored from save
	if not has_saved_terrain:
		var gen = _world_gen_script.new()
		gen.generate(tile_map, GameManager.map_size, GameManager.world_seed)

	# Run stress test generator if requested
	if GameManager.stress_test_pending:
		GameManager.stress_test_pending = false
		var stress_gen = _stress_gen_script.new()
		stress_gen.generate(tile_map, GameManager.map_size)

	# Wire HUD signals
	hud.building_selected.connect(_on_building_selected)
	hud.set_camera(camera)

	# Wire build system signals
	build_system.building_clicked.connect(_on_building_clicked)

	# Add building popup to UI layer
	_popup = _popup_scene.instantiate()
	$UI.add_child(_popup)

	# If continuing from a save, load the run now that the world is ready
	if SaveManager.pending_load:
		SaveManager.pending_load = false
		SaveManager.load_run()

	# Create player (after save load so collision tiles are set up)
	_spawn_player()

func _on_building_selected(id: StringName) -> void:
	build_system.select_building(id)
	# Dismiss popup when entering build mode
	if _popup:
		_popup.hide_popup()
		build_system.clear_select_highlight()

func _on_building_clicked(building: Node2D) -> void:
	if _popup:
		if building:
			_popup.show_building(building, camera)
		else:
			_popup.hide_popup()

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := (now - _last_time_usec) / 1_000_000.0 if _last_time_usec > 0 else delta
	_last_time_usec = now
	real_delta = minf(real_delta, 0.1) # cap to avoid jumps
	_follow_camera(real_delta)
	# Advance conveyor MultiMesh animation frame
	if GameManager.conveyor_visual_manager:
		GameManager.conveyor_visual_manager.update_animation()
	# Autosave
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		SaveManager.save_run()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		_handle_zoom(event)
	elif event is InputEventPanGesture:
		_zoom_toward_mouse(camera.zoom.x - event.delta.y * ZOOM_SPEED)
	elif event.is_action_pressed("toggle_buildings_panel"):
		hud.toggle_buildings_panel()
	elif event.is_action_pressed("ui_cancel"):
		# ESC cascade: link mode → buildings panel → info panel → building mode → destroy mode → pause menu
		if build_system.energy_link_mode:
			build_system._exit_energy_link_mode()
		elif hud.is_buildings_panel_open():
			hud.close_buildings_panel()
		elif _popup and _popup.visible:
			_popup.hide_popup()
			build_system.clear_select_highlight()
		elif build_system.building_mode:
			build_system.exit_building_mode()
		elif build_system.destroy_mode:
			build_system.exit_destroy_mode()
		else:
			_open_pause_menu()

func _open_pause_menu() -> void:
	# Don't open if already paused
	if get_tree().paused:
		return
	var pause_menu := _pause_menu_scene.instantiate()
	$UI.add_child(pause_menu)

func _spawn_player() -> void:
	player = _player_scene.instantiate()
	# Spawn at map center
	var center := Vector2(GameManager.map_size * TILE_SIZE, GameManager.map_size * TILE_SIZE) * 0.5
	player.position = center
	player.spawn_position = center
	add_child(player)
	GameManager.player = player
	# Snap camera to player immediately
	camera.position = player.position

func _follow_camera(real_delta: float) -> void:
	if player and is_instance_valid(player):
		var target: Vector2 = player.position
		# Clamp to world bounds
		var bounds := _get_camera_bounds()
		target.x = clampf(target.x, bounds.position.x, bounds.end.x)
		target.y = clampf(target.y, bounds.position.y, bounds.end.y)
		camera.position = camera.position.lerp(target, 1.0 - exp(-CAMERA_FOLLOW_SPEED * real_delta))

func _handle_zoom(event: InputEventMouseButton) -> void:
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT]:
		_zoom_toward_mouse(camera.zoom.x + ZOOM_SPEED)
	elif event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]:
		_zoom_toward_mouse(camera.zoom.x - ZOOM_SPEED)

func _zoom_toward_mouse(new_zoom: float) -> void:
	var clamped := clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(clamped, camera.zoom.x):
		return
	var mouse_screen := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size
	var offset := mouse_screen - viewport_size / 2.0
	var world_before := camera.position + offset / camera.zoom.x
	camera.zoom = Vector2(clamped, clamped)
	var world_after := camera.position + offset / camera.zoom.x
	camera.position += world_before - world_after

# Tile source IDs
const TILE_GROUND := 0
const TILE_IRON := 1
const TILE_COPPER := 2
const TILE_COAL := 3
const TILE_WALL := 4
const TILE_GROUND_DARK := 5
const TILE_GROUND_LIGHT := 6

# Deposit colors
const DEPOSIT_COLORS := {
	TILE_IRON: Color(0.45, 0.42, 0.44),   # dark gray — iron deposit
	TILE_COPPER: Color(0.72, 0.45, 0.2),   # orange-brown — copper deposit
	TILE_COAL: Color(0.18, 0.18, 0.2),     # near-black — coal seam
}

# Map from tile source ID to the item it produces
const DEPOSIT_ITEMS := {
	TILE_IRON: &"iron_ore",
	TILE_COPPER: &"copper_ore",
	TILE_COAL: &"coal",
}

func _create_tile_source(tile_set: TileSet, source_id: int, color: Color) -> void:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.create_tile(Vector2i(0, 0))
	tile_set.add_source(source, source_id)

func _setup_tileset() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	_create_tile_source(tile_set, TILE_GROUND, Color(0.28, 0.36, 0.24))
	for id in DEPOSIT_COLORS:
		_create_tile_source(tile_set, id, DEPOSIT_COLORS[id])
	_create_tile_source(tile_set, TILE_WALL, Color(0.38, 0.34, 0.30))
	_create_tile_source(tile_set, TILE_GROUND_DARK, Color(0.24, 0.30, 0.20))
	_create_tile_source(tile_set, TILE_GROUND_LIGHT, Color(0.32, 0.40, 0.28))
	tile_map.tile_set = tile_set

func _get_camera_bounds() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var half_view := viewport_size / (2.0 * camera.zoom.x)
	var world_size := float(GameManager.map_size * TILE_SIZE)
	var min_pos := half_view
	var max_pos := Vector2(world_size, world_size) - half_view
	if min_pos.x > max_pos.x:
		min_pos.x = world_size / 2.0
		max_pos.x = world_size / 2.0
	if min_pos.y > max_pos.y:
		min_pos.y = world_size / 2.0
		max_pos.y = world_size / 2.0
	return Rect2(min_pos, max_pos - min_pos)


# ── Terrain Serialization ────────────────────────────────────────────────────

## Pack all tile map cells into a base64 string (nibble-packed: 2 cells per byte).
func serialize_terrain() -> String:
	var map_size := GameManager.map_size
	var cell_count := map_size * map_size
	var byte_count := (cell_count + 1) / 2
	var bytes := PackedByteArray()
	bytes.resize(byte_count)
	bytes.fill(0)
	for y in range(map_size):
		for x in range(map_size):
			var idx := y * map_size + x
			var source_id := tile_map.get_cell_source_id(Vector2i(x, y))
			if source_id < 0:
				source_id = TILE_GROUND
			if idx % 2 == 0:
				bytes[idx / 2] = source_id
			else:
				bytes[idx / 2] = bytes[idx / 2] | (source_id << 4)
	return Marshalls.raw_to_base64(bytes)

## Restore tile map and GameManager.deposits/walls from base64 terrain data.
func deserialize_terrain(data: String) -> void:
	var bytes := Marshalls.base64_to_raw(data)
	var map_size := GameManager.map_size
	GameManager.deposits.clear()
	GameManager.walls.clear()
	for y in range(map_size):
		for x in range(map_size):
			var idx := y * map_size + x
			var source_id: int
			if idx % 2 == 0:
				source_id = bytes[idx / 2] & 0x0F
			else:
				source_id = (bytes[idx / 2] >> 4) & 0x0F
			var pos := Vector2i(x, y)
			tile_map.set_cell(pos, source_id, Vector2i(0, 0))
			if source_id == TILE_WALL:
				GameManager.walls[pos] = true
			elif DEPOSIT_ITEMS.has(source_id):
				GameManager.deposits[pos] = DEPOSIT_ITEMS[source_id]

