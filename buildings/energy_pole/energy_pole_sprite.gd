extends Node2D

## Draws the Energy Pole using geometric shapes:
## A tall pole with a glowing energy node on top and connection indicators.

const TILE := 32.0
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var logic = _get_logic()
	var energy_fill := 0.0
	if logic and logic.energy:
		energy_fill = logic.energy.get_fill_ratio()

	var cx := TILE / 2.0

	# Base plate — small dark square
	draw_rect(Rect2(cx - 8, TILE - 6, 16, 4), Color(0.3, 0.3, 0.35))

	# Pole shaft — thin vertical line
	draw_rect(Rect2(cx - 2, 6, 4, TILE - 12), Color(0.4, 0.4, 0.45))

	# Cross arms — horizontal bar near top
	draw_rect(Rect2(cx - 10, 6, 20, 3), Color(0.45, 0.45, 0.5))

	# Insulators — small dots at arm ends
	var insulator_color := Color(0.3, 0.6, 0.9, 0.6 + energy_fill * 0.4)
	draw_circle(Vector2(cx - 10, 7), 3.0, insulator_color)
	draw_circle(Vector2(cx + 10, 7), 3.0, insulator_color)

	# Central energy glow
	var pulse := 0.5 + 0.5 * sin(_time * 2.5)
	var glow_alpha := 0.2 + energy_fill * 0.6 * pulse
	var glow_color := Color(0.3, 0.7, 1.0, glow_alpha)
	draw_circle(Vector2(cx, 7), 5.0, glow_color)

	# Small energy level indicator bar at bottom
	if logic and logic.energy:
		var bar_w := 12.0
		var bar_h := 2.0
		var bar_x := cx - bar_w / 2.0
		var bar_y := TILE - 2.0
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.25))
		draw_rect(Rect2(bar_x, bar_y, bar_w * energy_fill, bar_h), Color(0.3, 0.7, 1.0, 0.8))

func _get_logic():
	var parent = get_parent()
	if parent and "logic" in parent:
		return parent.logic
	return null
