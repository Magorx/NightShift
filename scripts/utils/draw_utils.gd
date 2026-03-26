class_name DrawUtils

## Draw a filled Manhattan-distance area with an outline around its perimeter.
## `canvas` — the CanvasItem doing the drawing (call from _draw())
## `origins` — array of Vector2i grid positions to measure distance from
## `max_distance` — maximum Manhattan distance (inclusive)
## `tile_size` — pixels per grid cell
## `map_size` — grid dimension (cells are clamped to 0..map_size-1)
## `fill_color` / `outline_color` / `outline_width` — visual style
static func draw_manhattan_area(
	canvas: CanvasItem,
	origins: Array,
	max_distance: int,
	tile_size: int,
	map_size: int,
	fill_color: Color,
	outline_color: Color,
	outline_width: float,
) -> void:
	if origins.is_empty() or max_distance <= 0:
		return
	var cell_set: Dictionary = {}
	for origin: Vector2i in origins:
		for dx in range(-max_distance, max_distance + 1):
			var remaining := max_distance - absi(dx)
			for dy in range(-remaining, remaining + 1):
				var cell := Vector2i(origin.x + dx, origin.y + dy)
				if cell.x >= 0 and cell.x < map_size and cell.y >= 0 and cell.y < map_size:
					cell_set[cell] = true
	var s := float(tile_size)
	for cell: Vector2i in cell_set:
		canvas.draw_rect(Rect2(Vector2(cell) * s, Vector2(s, s)), fill_color)
	for cell: Vector2i in cell_set:
		var wp := Vector2(cell) * s
		if not cell_set.has(cell + Vector2i(1, 0)):
			canvas.draw_line(Vector2(wp.x + s, wp.y), Vector2(wp.x + s, wp.y + s), outline_color, outline_width)
		if not cell_set.has(cell + Vector2i(0, 1)):
			canvas.draw_line(Vector2(wp.x, wp.y + s), Vector2(wp.x + s, wp.y + s), outline_color, outline_width)
		if not cell_set.has(cell + Vector2i(-1, 0)):
			canvas.draw_line(Vector2(wp.x, wp.y), Vector2(wp.x, wp.y + s), outline_color, outline_width)
		if not cell_set.has(cell + Vector2i(0, -1)):
			canvas.draw_line(Vector2(wp.x, wp.y), Vector2(wp.x + s, wp.y), outline_color, outline_width)
