class_name GridOverlay
extends Node2D

const GRID_COLOR := Color(1, 1, 1, 0.08)

func _draw() -> void:
	if not visible:
		return
	var cam := get_viewport().get_canvas_transform()
	var vp_size := get_viewport_rect().size
	var scale_val := cam.x.x  # uniform zoom
	var tl := -cam.origin / scale_val
	var br := tl + vp_size / scale_val
	# Convert screen corners to grid range (with margin for partially-visible tiles)
	var min_grid := GridUtils.world_to_grid(tl) - Vector2i(3, 3)
	var max_grid := GridUtils.world_to_grid(br) + Vector2i(3, 3)
	var n := GameManager.map_size
	min_grid = min_grid.clamp(Vector2i.ZERO, Vector2i(n, n))
	max_grid = max_grid.clamp(Vector2i.ZERO, Vector2i(n, n))
	var hw := GridUtils.HALF_W
	var hh := GridUtils.HALF_H
	# Draw only the top two edges of each diamond (top-right and top-left).
	# The bottom edges are the top edges of adjacent tiles, so this avoids double-drawing.
	for gx in range(min_grid.x, max_grid.x + 1):
		for gy in range(min_grid.y, max_grid.y + 1):
			var c := GridUtils.grid_to_center(Vector2i(gx, gy))
			var top := c + Vector2(0, -hh)
			draw_line(top, c + Vector2(hw, 0), GRID_COLOR)
			draw_line(top, c + Vector2(-hw, 0), GRID_COLOR)
