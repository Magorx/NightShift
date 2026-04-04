extends Control

var _camera: Camera2D
var _last_cam_pos := Vector2.ZERO
var _last_cam_zoom := 1.0
var _redraw_timer: float = 0.0
var _cached_image: ImageTexture
var _cached_building_count: int = -1
var _cache_dirty: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_camera(cam: Camera2D) -> void:
	_camera = cam

func _process(delta: float) -> void:
	if not _camera:
		return
	# Always redraw if camera moved (lightweight — just camera rect on cached texture)
	if _camera.position != _last_cam_pos or _camera.zoom.x != _last_cam_zoom:
		_last_cam_pos = _camera.position
		_last_cam_zoom = _camera.zoom.x
		queue_redraw()
	# Periodic check for building changes
	_redraw_timer += delta
	if _redraw_timer >= 1.0:
		_redraw_timer = 0.0
		var count := GameManager.unique_buildings.size()
		if count != _cached_building_count:
			_cache_dirty = true
			queue_redraw()

func _draw() -> void:
	var map_px := GridUtils.map_world_size(GameManager.map_size).x
	var display_size := size

	if _cache_dirty or not _cached_image:
		_rebuild_cache(map_px, display_size)
		_cache_dirty = false

	# Draw cached texture
	if _cached_image:
		draw_texture_rect(_cached_image, Rect2(Vector2.ZERO, display_size), false)

	# Camera viewport rectangle (drawn every frame — very cheap)
	if _camera:
		var scale_x := display_size.x / map_px
		var scale_y := display_size.y / map_px
		var viewport_size := get_viewport_rect().size
		var cam_half := viewport_size / (2.0 * _camera.zoom.x)
		var cam_tl := _camera.position - cam_half
		var cam_br := _camera.position + cam_half
		var rect_tl := Vector2(cam_tl.x * scale_x, cam_tl.y * scale_y)
		var rect_size := Vector2((cam_br.x - cam_tl.x) * scale_x, (cam_br.y - cam_tl.y) * scale_y)
		draw_rect(Rect2(rect_tl, rect_size), Color(1, 1, 1, 0.6), false, 1.0)

func _rebuild_cache(map_px: float, display_size: Vector2) -> void:
	var w := int(display_size.x)
	var h := int(display_size.y)
	if w <= 0 or h <= 0:
		return

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Color(0.08, 0.08, 0.1)
	img.fill(bg)

	var scale_x := display_size.x / map_px
	var scale_y := display_size.y / map_px

	# Deposits
	for pos in GameManager.deposits:
		var item_id: StringName = GameManager.deposits[pos]
		var color := Color(0.4, 0.4, 0.4, 0.4)
		var item_def = _get_item_def(item_id)
		if item_def:
			color = item_def.color
			color.a = 0.35
		var x1 := int(pos.x * GridUtils.TILE_WIDTH * scale_x)
		var y1 := int(pos.y * GridUtils.TILE_HEIGHT * scale_y)
		var x2 := int((pos.x + 1) * GridUtils.TILE_WIDTH * scale_x)
		var y2 := int((pos.y + 1) * GridUtils.TILE_HEIGHT * scale_y)
		_fill_rect_on_image(img, x1, y1, maxi(x2 - x1, 1), maxi(y2 - y1, 1), color, w, h)

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
		var bx1 := int(pos.x * GridUtils.TILE_WIDTH * scale_x)
		var by1 := int(pos.y * GridUtils.TILE_HEIGHT * scale_y)
		var bx2 := int((pos.x + 1) * GridUtils.TILE_WIDTH * scale_x)
		var by2 := int((pos.y + 1) * GridUtils.TILE_HEIGHT * scale_y)
		_fill_rect_on_image(img, bx1, by1, maxi(bx2 - bx1, 2), maxi(by2 - by1, 2), color, w, h)

	_cached_building_count = GameManager.unique_buildings.size()
	_cached_image = ImageTexture.create_from_image(img)

func _fill_rect_on_image(img: Image, x: int, y: int, w: int, h: int, color: Color, img_w: int, img_h: int) -> void:
	var x_end := mini(x + w, img_w)
	var y_end := mini(y + h, img_h)
	x = maxi(x, 0)
	y = maxi(y, 0)
	for py in range(y, y_end):
		for px in range(x, x_end):
			img.set_pixel(px, py, color)

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
	var map_px := GridUtils.map_world_size(GameManager.map_size).x
	var world_x := (local_pos.x / size.x) * map_px
	var world_y := (local_pos.y / size.y) * map_px
	_camera.position = Vector2(world_x, world_y)

func _get_item_def(item_id: StringName):
	return GameManager.get_item_def(item_id)
