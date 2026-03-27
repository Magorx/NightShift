class_name GridOverlay
extends Node2D

const TILE_SIZE := 32
const GRID_COLOR := Color(1, 1, 1, 0.08)

func _draw() -> void:
	var ms := GameManager.map_size
	var total := ms * TILE_SIZE

	# Get visible viewport bounds in world coordinates
	var canvas_transform := get_viewport().get_canvas_transform()
	var viewport_size := get_viewport_rect().size
	var top_left := -canvas_transform.origin / canvas_transform.get_scale()
	var bottom_right := top_left + viewport_size / canvas_transform.get_scale()

	# Clamp to map bounds and convert to tile indices
	var start_col := maxi(0, int(top_left.x / TILE_SIZE))
	var end_col := mini(ms, int(bottom_right.x / TILE_SIZE) + 1)
	var start_row := maxi(0, int(top_left.y / TILE_SIZE))
	var end_row := mini(ms, int(bottom_right.y / TILE_SIZE) + 1)

	# Only draw grid lines within the visible area
	for i in range(start_col, end_col + 1):
		var x := i * TILE_SIZE
		draw_line(Vector2(x, start_row * TILE_SIZE), Vector2(x, end_row * TILE_SIZE), GRID_COLOR)
	for i in range(start_row, end_row + 1):
		var y := i * TILE_SIZE
		draw_line(Vector2(start_col * TILE_SIZE, y), Vector2(end_col * TILE_SIZE, y), GRID_COLOR)
