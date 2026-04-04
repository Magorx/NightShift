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
	# Draw filled diamonds
	for cell: Vector2i in cell_set:
		var c := GridUtils.grid_to_center(cell)
		var points := GridUtils.get_diamond_points(c)
		canvas.draw_colored_polygon(points, fill_color)
	# Draw outline edges where a neighbor is absent
	for cell: Vector2i in cell_set:
		var c := GridUtils.grid_to_center(cell)
		var top := c + GridUtils.diamond_top()
		var right := c + GridUtils.diamond_right()
		var bottom := c + GridUtils.diamond_bottom()
		var left := c + GridUtils.diamond_left()
		if not cell_set.has(cell + Vector2i(1, 0)):
			canvas.draw_line(right, bottom, outline_color, outline_width)
		if not cell_set.has(cell + Vector2i(0, 1)):
			canvas.draw_line(bottom, left, outline_color, outline_width)
		if not cell_set.has(cell + Vector2i(-1, 0)):
			canvas.draw_line(left, top, outline_color, outline_width)
		if not cell_set.has(cell + Vector2i(0, -1)):
			canvas.draw_line(top, right, outline_color, outline_width)
