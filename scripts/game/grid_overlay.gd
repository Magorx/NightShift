extends Node2D

const TILE_SIZE := 32
const MAP_SIZE := 64
const GRID_COLOR := Color(1, 1, 1, 0.08)

func _draw() -> void:
	var total := MAP_SIZE * TILE_SIZE
	for i in range(MAP_SIZE + 1):
		var pos := i * TILE_SIZE
		draw_line(Vector2(pos, 0), Vector2(pos, total), GRID_COLOR)
		draw_line(Vector2(0, pos), Vector2(total, pos), GRID_COLOR)
