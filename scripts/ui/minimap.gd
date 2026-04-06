extends Control

var _camera  # GameCamera (Camera3D)
var _last_cam_pos := Vector2.ZERO
var _last_cam_zoom := 1.0
var _redraw_timer: float = 0.0
var _cached_image: ImageTexture
var _cached_building_count: int = -1
var _cache_dirty: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_camera(cam) -> void:
	_camera = cam

func _process(delta: float) -> void:
	if not _camera:
		return
	# Always redraw if camera moved (lightweight — just camera rect on cached texture)
	var cam_pos: Vector3 = _camera.global_position
	var cam_zoom: float = _camera.size
	var cam_pos_2d := Vector2(cam_pos.x, cam_pos.z)
	if cam_pos_2d != _last_cam_pos or cam_zoom != _last_cam_zoom:
		_last_cam_pos = cam_pos_2d
		_last_cam_zoom = cam_zoom
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
	var map_tiles := float(GameManager.map_size)
	var display_size := size

	if _cache_dirty or not _cached_image:
		_rebuild_cache(map_tiles, display_size)
		_cache_dirty = false

	# Draw cached texture
	if _cached_image:
		draw_texture_rect(_cached_image, Rect2(Vector2.ZERO, display_size), false)

	# Camera viewport rectangle (drawn every frame -- very cheap)
	# Minimap shows logical grid top-down, so convert camera world pos to grid
	if _camera:
		var scale_x := display_size.x / map_tiles
		var scale_y := display_size.y / map_tiles
		var cam_grid: Vector2
		var visible_half: Vector2
		var cam_pos: Vector3 = _camera.global_position
		cam_grid = Vector2(GridUtils.world_to_grid(cam_pos))
		# Ortho camera: size is vertical extent in world units
		var half_size: float = _camera.size * 0.5
		visible_half = Vector2(half_size, half_size)
		var tl := (cam_grid - visible_half) * Vector2(scale_x, scale_y)
		var br := (cam_grid + visible_half) * Vector2(scale_x, scale_y)
		draw_rect(Rect2(tl, br - tl), Color(1, 1, 1, 0.6), false, 1.0)

func _rebuild_cache(map_tiles: float, display_size: Vector2) -> void:
	var w := int(display_size.x)
	var h := int(display_size.y)
	if w <= 0 or h <= 0:
		return

	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Color(0.08, 0.08, 0.1)
	img.fill(bg)

	var scale_x := display_size.x / map_tiles
	var scale_y := display_size.y / map_tiles

	# Deposits -- grid pos maps directly to minimap pixel position
	for pos in GameManager.deposits:
		var item_id: StringName = GameManager.deposits[pos]
		var color := Color(0.4, 0.4, 0.4, 0.4)
		var item_def = GameManager.get_item_def(item_id)
		if item_def:
			color = item_def.color
			color.a = 0.35
		var x1 := int(pos.x * scale_x)
		var y1 := int(pos.y * scale_y)
		var x2 := int((pos.x + 1) * scale_x)
		var y2 := int((pos.y + 1) * scale_y)
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
		var bx1 := int(pos.x * scale_x)
		var by1 := int(pos.y * scale_y)
		var bx2 := int((pos.x + 1) * scale_x)
		var by2 := int((pos.y + 1) * scale_y)
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
	var map_tiles := float(GameManager.map_size)
	var grid_x := local_pos.x / size.x * map_tiles
	var grid_y := local_pos.y / size.y * map_tiles
	_camera.position = GridUtils.grid_to_center(Vector2i(int(grid_x), int(grid_y)))

