extends Node2D
## Draws a simple oval shadow beneath the player when elevated.

func _draw() -> void:
	draw_ellipse(Vector2.ZERO, Vector2(10, 5), Color(0, 0, 0, 0.3))

func draw_ellipse(center: Vector2, radii: Vector2, color: Color, segments: int = 16) -> void:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
