extends Node2D

const RADIUS := 6.0

func _draw() -> void:
	var color: Color = get_meta("color", Color.WHITE)
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 16, color.darkened(0.3), 1.0)
