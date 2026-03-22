extends Node2D

const TILE_SIZE := 32
const MAP_SIZE := 64 # tiles in each direction
const PAN_SPEED := 600.0
const ZOOM_SPEED := 0.1
const MIN_ZOOM := 0.25
const MAX_ZOOM := 3.0

@onready var camera: Camera2D = $Camera2D
@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var grid_overlay: Node2D = $GridOverlay

func _ready() -> void:
	GameManager.building_layer = $BuildingLayer
	GameManager.item_layer = $ItemLayer
	GameManager.conveyor_system = $ConveyorSystem
	GameManager.deposits.clear()
	_setup_tileset()
	_fill_ground()
	_place_deposits()
	$UI/HUD.building_selected.connect(_on_building_selected)

func _on_building_selected(id: StringName) -> void:
	$BuildSystem.select_building(id)

func _process(delta: float) -> void:
	_handle_pan(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_handle_zoom(event)
	elif event is InputEventPanGesture:
		_set_zoom(camera.zoom.x - event.delta.y * ZOOM_SPEED)
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _handle_pan(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1
	if direction != Vector2.ZERO:
		camera.position += direction.normalized() * PAN_SPEED * delta / camera.zoom.x

func _handle_zoom(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_zoom(camera.zoom.x + ZOOM_SPEED)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_zoom(camera.zoom.x - ZOOM_SPEED)

func _set_zoom(new_zoom: float) -> void:
	var clamped := clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(clamped, clamped)

# Tile source IDs
const TILE_GROUND := 0
const TILE_IRON := 1
const TILE_COPPER := 2
const TILE_COAL := 3

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
	tile_map.tile_set = tile_set

func _fill_ground() -> void:
	for x in range(MAP_SIZE):
		for y in range(MAP_SIZE):
			tile_map.set_cell(Vector2i(x, y), TILE_GROUND, Vector2i(0, 0))

func _place_deposits() -> void:
	# Place several deposit patches around the map
	var deposit_patches := [
		# [center_x, center_y, tile_source_id, patch_radius]
		[10, 10, TILE_IRON, 2],
		[10, 25, TILE_IRON, 2],
		[30, 8, TILE_COPPER, 2],
		[25, 30, TILE_COPPER, 2],
		[45, 15, TILE_COAL, 2],
		[18, 45, TILE_COAL, 2],
		[50, 40, TILE_IRON, 3],
		[40, 50, TILE_COPPER, 2],
	]
	for patch in deposit_patches:
		var cx: int = patch[0]
		var cy: int = patch[1]
		var tile_id: int = patch[2]
		var radius: int = patch[3]
		var item_id: StringName = DEPOSIT_ITEMS[tile_id]
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				# Circular-ish shape
				if dx * dx + dy * dy > radius * radius + 1:
					continue
				var pos := Vector2i(cx + dx, cy + dy)
				if pos.x < 0 or pos.y < 0 or pos.x >= MAP_SIZE or pos.y >= MAP_SIZE:
					continue
				tile_map.set_cell(pos, tile_id, Vector2i(0, 0))
				GameManager.deposits[pos] = item_id
