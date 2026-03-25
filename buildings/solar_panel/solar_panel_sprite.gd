extends Node2D

## Draws the Solar Panel using geometric shapes:
## A tilted panel with reflective cells and a small support stand.

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

	# Support stand
	draw_rect(Rect2(14, 22, 4, 8), Color(0.35, 0.35, 0.38))

	# Panel frame — angled rectangle (drawn as polygon)
	var panel_color := Color(0.15, 0.2, 0.35)
	draw_rect(Rect2(3, 4, TILE - 6, 20), panel_color)

	# Solar cells — 2x2 grid of blue-ish squares
	var cell_w := (TILE - 10.0) / 2.0
	var cell_h := 8.0
	var shimmer := 0.05 * sin(_time * 1.5)
	for row in 2:
		for col in 2:
			var cx := 5.0 + col * (cell_w + 1)
			var cy := 6.0 + row * (cell_h + 1)
			var cell_color := Color(0.2 + shimmer, 0.35 + shimmer, 0.65 + shimmer * 2, 1.0)
			draw_rect(Rect2(cx, cy, cell_w - 1, cell_h - 1), cell_color)

	# Highlight reflection line (diagonal shine)
	var shine_x := fmod(_time * 4.0, TILE + 10.0) - 5.0
	if shine_x > 3 and shine_x < TILE - 3:
		draw_line(Vector2(shine_x, 5), Vector2(shine_x + 3, 22), Color(0.8, 0.9, 1.0, 0.2), 1.5)

	# Energy indicator dot
	var dot_alpha := 0.3 + energy_fill * 0.6
	draw_circle(Vector2(TILE / 2.0, 27), 2.5, Color(0.3, 0.8, 0.3, dot_alpha))

func _get_logic():
	var parent = get_parent()
	if parent and "logic" in parent:
		return parent.logic
	return null
