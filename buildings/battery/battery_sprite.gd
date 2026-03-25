extends Node2D

## Draws the Battery using geometric shapes:
## A rectangular cell with fill-level indicator and terminal contacts.

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

	# Battery outer casing
	draw_rect(Rect2(3, 5, TILE - 6, TILE - 8), Color(0.25, 0.3, 0.35))

	# Battery terminal (top nub)
	draw_rect(Rect2(12, 2, 8, 4), Color(0.4, 0.45, 0.5))

	# Inner fill area background
	var inner := Rect2(5, 8, TILE - 10, TILE - 14)
	draw_rect(inner, Color(0.12, 0.14, 0.16))

	# Fill level — green to yellow gradient based on charge
	var fill_h := inner.size.y * energy_fill
	var fill_y := inner.position.y + inner.size.y - fill_h
	if energy_fill > 0.01:
		var fill_color: Color
		if energy_fill > 0.6:
			fill_color = Color(0.2, 0.8, 0.3, 0.9)
		elif energy_fill > 0.3:
			fill_color = Color(0.8, 0.8, 0.2, 0.9)
		else:
			fill_color = Color(0.9, 0.3, 0.2, 0.9)
		draw_rect(Rect2(inner.position.x, fill_y, inner.size.x, fill_h), fill_color)

	# Segment lines (battery cell dividers)
	for i in range(1, 4):
		var seg_y := inner.position.y + inner.size.y * i / 4.0
		draw_line(Vector2(inner.position.x, seg_y), Vector2(inner.position.x + inner.size.x, seg_y), Color(0.2, 0.22, 0.25, 0.5), 1.0)

	# Lightning bolt symbol in center
	var cx := TILE / 2.0
	var cy := TILE / 2.0
	var bolt_alpha := 0.3 + energy_fill * 0.5
	var bolt_color := Color(1.0, 0.95, 0.4, bolt_alpha)
	draw_line(Vector2(cx + 1, cy - 6), Vector2(cx - 2, cy), bolt_color, 1.5)
	draw_line(Vector2(cx - 2, cy), Vector2(cx + 1, cy), bolt_color, 1.5)
	draw_line(Vector2(cx + 1, cy), Vector2(cx - 2, cy + 6), bolt_color, 1.5)

func _get_logic():
	var parent = get_parent()
	if parent and "logic" in parent:
		return parent.logic
	return null
