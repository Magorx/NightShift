class_name GridOverlay
extends Node2D

const GRID_COLOR := Color(1, 1, 1, 0.08)

func _draw() -> void:
	var ms := GameManager.map_size

	# Get visible viewport bounds in world coordinates
	var canvas_transform := get_viewport().get_canvas_transform()
	var viewport_size := get_viewport_rect().size
	var top_left := -canvas_transform.origin / canvas_transform.get_scale()
	var bottom_right := top_left + viewport_size / canvas_transform.get_scale()

	# Clamp to map bounds and convert to tile indices
	var start_col := maxi(0, int(top_left.x / GridUtils.TILE_WIDTH))
	var end_col := mini(ms, int(bottom_right.x / GridUtils.TILE_WIDTH) + 1)
	var start_row := maxi(0, int(top_left.y / GridUtils.TILE_HEIGHT))
	var end_row := mini(ms, int(bottom_right.y / GridUtils.TILE_HEIGHT) + 1)

	# Only draw grid lines within the visible area
	for i in range(start_col, end_col + 1):
		var x := i * GridUtils.TILE_WIDTH
		draw_line(Vector2(x, start_row * GridUtils.TILE_HEIGHT), Vector2(x, end_row * GridUtils.TILE_HEIGHT), GRID_COLOR)
	for i in range(start_row, end_row + 1):
		var y := i * GridUtils.TILE_HEIGHT
		draw_line(Vector2(start_col * GridUtils.TILE_WIDTH, y), Vector2(end_col * GridUtils.TILE_WIDTH, y), GRID_COLOR)
