extends Node2D

## Draws the Coal Burner using geometric shapes:
## A furnace body with a chimney/smokestack, glowing fire effect when burning.

const TILE := 32.0
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var logic = _get_logic()

	# Base body — dark brown rectangle spanning both cells
	var body_rect := Rect2(2, 2, TILE * 2 - 4, TILE - 4)
	draw_rect(body_rect, Color(0.3, 0.22, 0.18))

	# Inner furnace chamber — darker inset
	var chamber := Rect2(6, 6, TILE - 8, TILE - 12)
	draw_rect(chamber, Color(0.15, 0.1, 0.08))

	# Fire glow when burning
	var is_burning := false
	if logic and logic._is_burning:
		is_burning = true
		var flicker := 0.7 + 0.3 * sin(_time * 8.0)
		var fire_color := Color(1.0, 0.4 * flicker, 0.1, 0.9 * flicker)
		var fire_rect := Rect2(8, 10, TILE - 12, TILE - 18)
		draw_rect(fire_rect, fire_color)
		# Small bright core
		var core_color := Color(1.0, 0.8, 0.2, 0.7 * flicker)
		draw_rect(Rect2(12, 14, TILE - 20, TILE - 26), core_color)

	# Chimney / smokestack on the right cell
	var chimney_x := TILE + 8.0
	var chimney_rect := Rect2(chimney_x, 2, 16, TILE - 4)
	draw_rect(chimney_rect, Color(0.25, 0.2, 0.18))
	# Chimney cap
	draw_rect(Rect2(chimney_x - 2, 2, 20, 4), Color(0.35, 0.28, 0.22))

	# Smoke puffs when burning
	if is_burning:
		var smoke_alpha := 0.3 + 0.15 * sin(_time * 3.0)
		var smoke_y := -2.0 - fmod(_time * 6.0, 12.0)
		draw_circle(Vector2(chimney_x + 8, smoke_y), 4.0, Color(0.5, 0.5, 0.5, smoke_alpha))
		draw_circle(Vector2(chimney_x + 10, smoke_y - 6), 3.0, Color(0.6, 0.6, 0.6, smoke_alpha * 0.7))

	# Coal intake indicator on left side
	var intake_color := Color(0.2, 0.18, 0.15) if not is_burning else Color(0.4, 0.3, 0.2)
	draw_rect(Rect2(0, 10, 4, 12), intake_color)

	# Energy output indicator — small lightning bolt shape on top-right
	var energy_fill := 0.0
	if logic and logic.energy:
		energy_fill = logic.energy.get_fill_ratio()
	var bolt_color := Color(1.0, 0.9, 0.2, 0.3 + energy_fill * 0.7)
	# Simple lightning bolt as lines
	var bolt_x := TILE * 2 - 10.0
	draw_line(Vector2(bolt_x, 4), Vector2(bolt_x - 3, 12), bolt_color, 2.0)
	draw_line(Vector2(bolt_x - 3, 12), Vector2(bolt_x + 1, 12), bolt_color, 2.0)
	draw_line(Vector2(bolt_x + 1, 12), Vector2(bolt_x - 2, 20), bolt_color, 2.0)

func _get_logic():
	var parent = get_parent()
	if parent and "logic" in parent:
		return parent.logic
	return null
