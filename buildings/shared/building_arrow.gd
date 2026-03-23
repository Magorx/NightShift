extends Node2D

const TILE_SIZE := 32
const ARROW_COLOR := Color(1, 1, 1, 0.5)

func _draw() -> void:
	var rot: int = get_meta("rotation_index", 0)
	var bsize: Vector2i = get_meta("shape_size", Vector2i(1, 1))
	var bbox_min: Vector2i = get_meta("bbox_min", Vector2i(0, 0))
	var size_px := Vector2(bsize) * TILE_SIZE
	var center := Vector2(bbox_min) * TILE_SIZE + size_px * 0.5
	var arrow_len: float = min(size_px.x, size_px.y) * 0.3
	var dir: Vector2
	match rot:
		0: dir = Vector2.RIGHT
		1: dir = Vector2.DOWN
		2: dir = Vector2.LEFT
		3: dir = Vector2.UP
		_: dir = Vector2.RIGHT
	var tip: Vector2 = center + dir * arrow_len
	var base: Vector2 = center - dir * arrow_len
	draw_line(base, tip, ARROW_COLOR, 2.0)
	var perp := Vector2(-dir.y, dir.x)
	draw_line(tip, tip - dir * 6 + perp * 4, ARROW_COLOR, 2.0)
	draw_line(tip, tip - dir * 6 - perp * 4, ARROW_COLOR, 2.0)
