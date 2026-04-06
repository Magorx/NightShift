class_name GameWorld
extends Node3D

const AUTOSAVE_INTERVAL := 60.0

@onready var camera: GameCamera = $Camera3D
@onready var build_system = $BuildSystem
@onready var hud: Control = $UI/HUD

var player  # Player (CharacterBody3D)
var building_collision  # BuildingCollision (StaticBody3D)

var _autosave_timer: float = 0.0
var _pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")
var _popup_scene: PackedScene = preload("res://scenes/ui/building_popup.tscn")
var _world_gen_script = preload("res://scripts/game/world_generator.gd")
var _stress_gen_script = preload("res://scripts/game/stress_test_generator.gd")
var _visual_mgr_script = preload("res://scripts/game/item_visual_manager.gd")
var _tick_system_script = preload("res://scripts/game/building_tick_system.gd")
var _terrain_visual_mgr_script = preload("res://scripts/game/terrain_visual_manager.gd")
var _player_scene: PackedScene = preload("res://player/player.tscn")
var _building_collision_script = preload("res://scripts/game/building_collision.gd")
var _rock_scene: PackedScene = preload("res://terrain/models/rock.glb")
var _chasm_scene: PackedScene = preload("res://terrain/models/chasm.glb")
var _rubble_scene: PackedScene = preload("res://terrain/models/rubble.glb")
var _deposit_scenes: Dictionary = {
	&"pyromite": preload("res://resources/deposits/models/pyromite.glb"),
	&"crystalline": preload("res://resources/deposits/models/crystalline.glb"),
	&"biovine": preload("res://resources/deposits/models/biovine.glb"),
}
var _day_night_script = preload("res://scripts/game/day_night_visual.gd")
var _day_night: Node
var _pixel_art_rect: ColorRect
var _popup: PanelContainer
var _ground_tooltip: PanelContainer
var _ground_tooltip_timer: float = 0.0
var _ground_tooltip_grid: Vector2i = Vector2i.ZERO  # world grid pos for repositioning
var _last_time_usec: int = 0

func _ready() -> void:
	GameManager.building_layer = $ObjectLayer/BuildingLayer
	GameManager.item_layer = $ObjectLayer/ItemLayer
	# Initialize MultiMesh item visual system
	GameManager.item_visual_manager = _visual_mgr_script.new()
	GameManager.item_visual_manager.attach_to($ObjectLayer/ItemLayer)
	# Initialize batched building tick system
	var tick_system = _tick_system_script.new()
	tick_system.name = "BuildingTickSystem"
	add_child(tick_system)
	GameManager.building_tick_system = tick_system
	GameManager.clear_all()
	GameManager.deposits.clear()
	GameManager.walls.clear()

	# Create building collision body (must exist before placing buildings)
	building_collision = _building_collision_script.new()
	building_collision.name = "BuildingCollision"
	add_child(building_collision)
	GameManager.building_collision = building_collision

	# Create ground collision plane for CharacterBody3D floor detection
	# Ground is on layer 3 (bit 4) — separate from player (layer 1) so items
	# can rest on the ground without physically interacting with the player.
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollision"
	ground_body.collision_layer = 4  # layer 3 (bit 4) — ground
	ground_body.collision_mask = 0
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = WorldBoundaryShape3D.new()  # infinite Y=0 plane
	ground_body.add_child(ground_shape)
	add_child(ground_body)

	# Determine world seed: use saved seed when loading, random for new game
	var has_saved_terrain := false
	if SaveManager.pending_load:
		var save_data: Dictionary = SaveManager.peek_save_data()
		GameManager.world_seed = int(save_data.get("world_seed", randi()))
		GameManager.map_size = int(save_data.get("map_size", 128))
		has_saved_terrain = save_data.has("terrain")
	elif GameManager.world_seed == 0:
		GameManager.world_seed = randi()

	# Initialize MultiMesh terrain visual system
	GameManager.terrain_visual_manager = _terrain_visual_mgr_script.new()
	GameManager.terrain_visual_manager.attach_to(self, -1)  # z_index below buildings

	# Skip world generation if terrain will be restored from save
	if not has_saved_terrain:
		var gen = _world_gen_script.new()
		var result: Array = gen.generate(null, GameManager.map_size, GameManager.world_seed)
		GameManager.terrain_tile_types = result[0]
		GameManager.terrain_variants = result[1]
		GameManager.terrain_heights = result[2]

	# Run stress test generator if requested
	if GameManager.stress_test_pending:
		GameManager.stress_test_pending = false
		var stress_gen = _stress_gen_script.new()
		stress_gen.generate(null, GameManager.map_size)

	# Wire HUD signals
	hud.building_selected.connect(_on_building_selected)
	hud.set_camera(camera)

	# Wire build system signals
	build_system._ghost_layer = $GhostLayer
	build_system.building_clicked.connect(_on_building_clicked)
	build_system.ground_inspected.connect(_on_ground_inspected)

	# Add building popup to UI layer
	_popup = _popup_scene.instantiate()
	_popup.dismissed.connect(_on_popup_dismissed)
	$UI.add_child(_popup)

	# Create ground tooltip (hidden by default)
	_ground_tooltip = _create_ground_tooltip()
	$UI.add_child(_ground_tooltip)

	# Create player before loading save so deserialize can restore position/inventory
	_spawn_player()

	# If continuing from a save, load the run now that the world is ready
	if SaveManager.pending_load:
		SaveManager.pending_load = false
		SaveManager.load_run()

	# Build terrain visuals (tile_types + variants + heights are set by gen or deserialize)
	if GameManager.terrain_tile_types.size() > 0:
		GameManager.terrain_visual_manager.build(
			GameManager.map_size,
			GameManager.terrain_tile_types,
			GameManager.terrain_variants,
			GameManager.terrain_heights
		)

	# Replace infinite ground plane with terrain collision mesh
	_setup_terrain_collision()

	# Scale ground plane to match map size (sits below terrain as fallback floor)
	var ground_plane: MeshInstance3D = $GroundPlane
	if ground_plane:
		var map_sz := float(GameManager.map_size)
		ground_plane.position = Vector3(map_sz / 2.0, -0.05, map_sz / 2.0)
		var mesh: PlaneMesh = ground_plane.mesh
		if mesh:
			mesh.size = Vector2(map_sz, map_sz)

	# Scatter 3D terrain decorations on wall/stone tiles
	_spawn_terrain_decorations()

	# Place 3D deposit models on deposit tiles
	_spawn_deposit_models()

	# Wire pixel art post-process toggle
	_pixel_art_rect = $PostProcessLayer/PixelArtRect
	_pixel_art_rect.visible = SettingsManager.pixel_art_enabled
	SettingsManager.pixel_art_changed.connect(func(enabled: bool): _pixel_art_rect.visible = enabled)

	camera.target_node = player

	# Day/night visual transitions
	_day_night = _day_night_script.new()
	_day_night.name = "DayNightVisual"
	add_child(_day_night)
	_day_night.setup($WorldEnvironment.environment, $DirectionalLight3D)

	# Wire RoundManager phase changes
	RoundManager.phase_changed.connect(_on_phase_changed)
	# Auto-start run when game world loads
	RoundManager.start_run()

func _on_building_selected(id: StringName) -> void:
	build_system.select_building(id)
	# Dismiss popup when entering build mode
	if _popup:
		_popup.hide_popup()
		build_system.clear_select_highlight()

func _on_popup_dismissed() -> void:
	build_system.clear_select_highlight()

func _on_building_clicked(building: Node) -> void:
	_hide_ground_tooltip()
	if _popup:
		if building:
			_popup.show_building(building, camera)
		else:
			_popup.hide_popup()

func _on_ground_inspected(grid_pos: Vector2i) -> void:
	if _popup:
		_popup.hide_popup()
		build_system.clear_select_highlight()
	_show_ground_tooltip(grid_pos)

func _create_ground_tooltip() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	style.border_color = Color(0.4, 0.4, 0.45, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	return panel

func _show_ground_tooltip(grid_pos: Vector2i) -> void:
	var vbox: VBoxContainer = _ground_tooltip.get_node("Content")
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()

	# Tile name
	var tile_name := "Ground"
	if GameManager.walls.has(grid_pos):
		var wall_tile: int = GameManager.walls[grid_pos]
		tile_name = WALL_NAMES.get(wall_tile, "Wall")

	# Deposit info
	var deposit_id: StringName = GameManager.deposits.get(grid_pos, &"")
	if deposit_id != &"":
		var item_def = GameManager.get_item_def(deposit_id)
		tile_name = "%s Deposit" % (item_def.display_name if item_def else str(deposit_id))

		# Title with icon
		var title_row := HBoxContainer.new()
		title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(ItemIcon.create(deposit_id, Vector2(16, 16)))
		var title_label := Label.new()
		title_label.text = "  " + tile_name
		title_label.add_theme_font_size_override("font_size", 12)
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_child(title_label)
		vbox.add_child(title_row)

		# Hint — only for hand-mineable deposits
		if deposit_id in Player.HAND_MINEABLE:
			var hint := Label.new()
			hint.text = "LMB hold to hand-mine"
			hint.add_theme_font_size_override("font_size", 10)
			hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(hint)
	else:
		var title_label := Label.new()
		title_label.text = tile_name
		title_label.add_theme_font_size_override("font_size", 12)
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(title_label)

	# Position above the tile
	_ground_tooltip.visible = true
	_ground_tooltip_timer = 3.0
	_ground_tooltip_grid = grid_pos

func _hide_ground_tooltip() -> void:
	if _ground_tooltip:
		_ground_tooltip.visible = false

func _process(delta: float) -> void:
	# Ground tooltip: auto-hide + reposition to stick to tile
	if _ground_tooltip and _ground_tooltip.visible:
		_ground_tooltip_timer -= delta
		if _ground_tooltip_timer <= 0:
			_hide_ground_tooltip()
		elif camera:
			var tile_world := GridUtils.grid_to_world(_ground_tooltip_grid)
			var screen_pos := camera.unproject_position(tile_world)
			var popup_size := _ground_tooltip.size
			_ground_tooltip.position = Vector2(
				clampf(screen_pos.x - popup_size.x * 0.5, 4, get_viewport().get_visible_rect().size.x - popup_size.x - 4),
				screen_pos.y - popup_size.y - 4
			)

	var now := Time.get_ticks_usec()
	var real_delta := (now - _last_time_usec) / 1_000_000.0 if _last_time_usec > 0 else delta
	_last_time_usec = now
	real_delta = minf(real_delta, 0.1) # cap to avoid jumps
	camera.update_camera(real_delta)
	# Autosave
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		SaveManager.save_run()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		camera.handle_zoom_input(event)
	elif event is InputEventPanGesture:
		camera.handle_zoom_input(event)
	elif event.is_action("camera_rotate") or (event is InputEventMouseMotion and camera._is_rotating):
		camera.handle_rotate_input(event)
	elif event.is_action_pressed("toggle_buildings_panel"):
		hud.toggle_buildings_panel()
	elif event.is_action_pressed("toggle_inventory"):
		hud.toggle_inventory_panel()
	elif event.is_action_pressed("debug_action"):
		_debug_action()
	elif event.is_action_pressed("ui_cancel"):
		# ESC cascade: buildings panel → info panel → building mode → destroy mode → pause menu
		if hud.is_buildings_panel_open():
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

# ── Phase Transitions ────────────────────────────────────────────────────

func _on_phase_changed(phase: StringName) -> void:
	match phase:
		&"build":
			build_system.set_enabled(true)
			GameManager.building_tick_system.set_physics_process(true)
			print("[WORLD] Build phase — factory running, placement enabled")
		&"fight":
			build_system.set_enabled(false)
			GameManager.building_tick_system.set_physics_process(false)
			print("[WORLD] Fight phase — factory frozen, placement disabled")

func _debug_action() -> void:
	var count := 0
	for item in get_tree().get_nodes_in_group(&"physics_items"):
		if is_instance_valid(item):
			item.queue_free()
			count += 1
	print("Debug: deleted %d loose items" % count)

func _open_pause_menu() -> void:
	# Don't open if already paused
	if get_tree().paused:
		return
	var pause_menu := _pause_menu_scene.instantiate()
	$UI.add_child(pause_menu)

func _setup_terrain_collision() -> void:
	if not GameManager.terrain_visual_manager:
		return
	var shape: ConcavePolygonShape3D = GameManager.terrain_visual_manager.create_box_collision()
	if not shape:
		return
	var face_count: int = shape.get_faces().size() / 3
	print("[TERRAIN] Box collision: %d triangles" % face_count)
	# Remove the infinite ground plane — box collision replaces it
	var old_ground := get_node_or_null("GroundCollision")
	if old_ground:
		old_ground.queue_free()
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 4  # layer 3 (ground)
	body.collision_mask = 0
	var col_shape := CollisionShape3D.new()
	col_shape.shape = shape
	body.add_child(col_shape)
	add_child(body)

func _spawn_deposit_models() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.world_seed + 888
	var deposit_layer := Node3D.new()
	deposit_layer.name = "DepositModels"
	add_child(deposit_layer)

	# Place one 3D model per ~5 deposit tiles to avoid clutter
	for pos: Vector2i in GameManager.deposits:
		if rng.randf() > 0.2:
			continue
		var item_id: StringName = GameManager.deposits[pos]
		if not _deposit_scenes.has(item_id):
			continue
		var inst: Node3D = _deposit_scenes[item_id].instantiate()
		var world_pos := GridUtils.grid_to_world(pos)
		world_pos.y = GameManager.get_terrain_height(pos)
		inst.position = world_pos
		inst.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.5, 0.8)
		inst.scale = Vector3(s, s, s)
		deposit_layer.add_child(inst)
		# Play idle animation if present
		var anim: AnimationPlayer = inst.get_node_or_null("AnimationPlayer")
		if anim and anim.has_animation(&"idle"):
			anim.play(&"idle")

func _spawn_terrain_decorations() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.world_seed + 999
	var decoration_layer := Node3D.new()
	decoration_layer.name = "TerrainDecorations"
	add_child(decoration_layer)

	for pos: Vector2i in GameManager.walls:
		var wall_type: int = GameManager.walls[pos]
		var scene: PackedScene = null
		var chance: float = 0.0

		if wall_type == TILE_WALL:
			scene = _rock_scene
			chance = 0.08
		elif wall_type == TILE_STONE:
			scene = [_rubble_scene, _chasm_scene][rng.randi() % 2]
			chance = 0.12

		if scene == null or rng.randf() > chance:
			continue

		var inst: Node3D = scene.instantiate()
		var world_pos := GridUtils.grid_to_world(pos)
		world_pos.y = GameManager.get_terrain_height(pos)
		inst.position = world_pos
		inst.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.4, 0.7)
		inst.scale = Vector3(s, s, s)
		decoration_layer.add_child(inst)

func _spawn_player() -> void:
	player = _player_scene.instantiate()
	# Spawn at map center (grid midpoint)
	@warning_ignore("integer_division")
	var center_grid := Vector2i(GameManager.map_size / 2, GameManager.map_size / 2)
	var center := GridUtils.grid_to_world(center_grid)
	center.y = GameManager.get_terrain_height(center_grid) + 0.1
	player.position = center
	player.spawn_position = center
	add_child(player)
	GameManager.player = player
	camera.snap_to(player.position)

# Tile constants — single source of truth in TileDatabase
const TILE_GROUND = TileDatabase.TILE_GROUND
const TILE_PYROMITE = TileDatabase.TILE_PYROMITE
const TILE_CRYSTALLINE = TileDatabase.TILE_CRYSTALLINE
const TILE_BIOVINE = TileDatabase.TILE_BIOVINE
const TILE_WALL = TileDatabase.TILE_WALL
const TILE_GROUND_DARK = TileDatabase.TILE_GROUND_DARK
const TILE_GROUND_LIGHT = TileDatabase.TILE_GROUND_LIGHT
const TILE_STONE = TileDatabase.TILE_STONE
const TILE_ASH = TileDatabase.TILE_ASH
const ASH_COLOR := Color(0.50, 0.45, 0.40)
const DEPOSIT_COLORS = TileDatabase.DEPOSIT_COLORS
const WALL_COLORS = TileDatabase.WALL_COLORS
const WALL_NAMES = TileDatabase.WALL_NAMES
const DEPOSIT_ITEMS = TileDatabase.DEPOSIT_ITEMS
const WALL_ITEMS = TileDatabase.WALL_ITEMS


# ── Terrain Serialization ────────────────────────────────────────────────────

## Pack all tile map cells into a base64 string (one byte per cell).
func serialize_terrain() -> String:
	var map_size := GameManager.map_size
	var cell_count := map_size * map_size
	# Use terrain_tile_types directly (already byte-per-cell)
	if GameManager.terrain_tile_types.size() == cell_count:
		return Marshalls.raw_to_base64(GameManager.terrain_tile_types)
	# Fallback: empty terrain
	var bytes := PackedByteArray()
	bytes.resize(cell_count)
	return Marshalls.raw_to_base64(bytes)

## Restore terrain data from base64 terrain data.
## Also populates GameManager.terrain_tile_types for MultiMesh rendering.
## Supports both legacy nibble-packed format and new byte-per-cell format.
func deserialize_terrain(data: String) -> void:
	var bytes := Marshalls.base64_to_raw(data)
	var map_size := GameManager.map_size
	var cell_count := map_size * map_size
	GameManager.deposits.clear()
	GameManager.walls.clear()
	var tile_types := PackedByteArray()
	tile_types.resize(cell_count)
	# Detect format: legacy nibble-packed has ~half the bytes
	var is_legacy := bytes.size() < cell_count
	for y in range(map_size):
		for x in range(map_size):
			var idx := y * map_size + x
			var source_id: int
			if is_legacy:
				if idx % 2 == 0:
					source_id = bytes[idx / 2] & 0x0F
				else:
					source_id = (bytes[idx / 2] >> 4) & 0x0F
			else:
				source_id = bytes[idx]
			var pos := Vector2i(x, y)
			tile_types[idx] = source_id
			if WALL_COLORS.has(source_id):
				GameManager.walls[pos] = source_id
			elif DEPOSIT_ITEMS.has(source_id):
				GameManager.deposits[pos] = DEPOSIT_ITEMS[source_id]
			# TILE_ASH: no deposit, no wall — just terrain
	GameManager.terrain_tile_types = tile_types
