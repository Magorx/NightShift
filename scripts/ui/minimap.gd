extends Control

const TILE_SIZE := 32
const MAP_SIZE := 64

var _camera: Camera2D
var _last_cam_pos := Vector2.ZERO
var _last_cam_zoom := 1.0
var _redraw_timer: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_camera(cam: Camera2D) -> void:
	_camera = cam

func _process(delta: float) -> void:
	if not _camera:
		return
	# Always redraw if camera moved
	if _camera.position != _last_cam_pos or _camera.zoom.x != _last_cam_zoom:
		_last_cam_pos = _camera.position
		_last_cam_zoom = _camera.zoom.x
		queue_redraw()
	# Periodic full redraw for building changes
	_redraw_timer += delta
	if _redraw_timer >= 1.0:
		_redraw_timer = 0.0
		queue_redraw()

func _draw() -> void:
	var map_px := float(MAP_SIZE * TILE_SIZE)
	var display_size := size
	var scale_x := display_size.x / map_px
	var scale_y := display_size.y / map_px

	# Background
	draw_rect(Rect2(Vector2.ZERO, display_size), Color(0.08, 0.08, 0.1))

	# Deposits
	for pos in GameManager.deposits:
		var item_id: StringName = GameManager.deposits[pos]
		var color := Color(0.4, 0.4, 0.4, 0.4)
		var item_def = _get_item_def(item_id)
		if item_def:
			color = item_def.color
			color.a = 0.35
		var rect_pos := Vector2(pos.x * TILE_SIZE, pos.y * TILE_SIZE)
		draw_rect(Rect2(rect_pos * scale_x, Vector2(TILE_SIZE * scale_x, TILE_SIZE * scale_y)), color)

	# Buildings
	var drawn_buildings: Dictionary = {}
	for pos in GameManager.buildings:
		var building = GameManager.buildings[pos]
		if not is_instance_valid(building):
			continue
		var nid: int = building.get_instance_id()
		if drawn_buildings.has(nid):
			continue
		drawn_buildings[nid] = true
		var def = GameManager.get_building_def(building.building_id)
		var color := Color.WHITE
		if def:
			color = def.color
		var bld_pos := Vector2(pos.x * TILE_SIZE, pos.y * TILE_SIZE)
		var dot_size := Vector2(maxf(TILE_SIZE * scale_x, 2), maxf(TILE_SIZE * scale_y, 2))
		draw_rect(Rect2(bld_pos * scale_x, dot_size), color)

	# Camera viewport rectangle
	if _camera:
		var viewport_size := get_viewport_rect().size
		var cam_half := viewport_size / (2.0 * _camera.zoom.x)
		var cam_tl := _camera.position - cam_half
		var cam_br := _camera.position + cam_half
		var rect_tl := Vector2(cam_tl.x * scale_x, cam_tl.y * scale_y)
		var rect_size := Vector2((cam_br.x - cam_tl.x) * scale_x, (cam_br.y - cam_tl.y) * scale_y)
		draw_rect(Rect2(rect_tl, rect_size), Color(1, 1, 1, 0.6), false, 1.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pan_camera_to(event.position)
		accept_event()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pan_camera_to(event.position)
		accept_event()

func _pan_camera_to(local_pos: Vector2) -> void:
	if not _camera:
		return
	var map_px := float(MAP_SIZE * TILE_SIZE)
	var world_x := (local_pos.x / size.x) * map_px
	var world_y := (local_pos.y / size.y) * map_px
	_camera.position = Vector2(world_x, world_y)

func _get_item_def(item_id: StringName):
	var path := "res://resources/items/%s.tres" % str(item_id)
	if ResourceLoader.exists(path):
		return load(path)
	return null
