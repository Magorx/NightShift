extends Node2D
## Draws the player as a colored square body with a directional triangle indicator.

const BODY_SIZE := 12.0  # half-size of the square body
const ARROW_SIZE := 6.0
const BODY_COLOR := Color(0.3, 0.6, 0.9)     # blue-ish
const ARROW_COLOR := Color(0.9, 0.9, 0.95)   # near-white

func _draw() -> void:
	# Body: colored square centered at origin
	draw_rect(Rect2(-BODY_SIZE / 2, -BODY_SIZE / 2, BODY_SIZE, BODY_SIZE), BODY_COLOR)

	# Direction triangle (pointing right in local space, rotation handled by parent)
	var tip := Vector2(BODY_SIZE / 2 + ARROW_SIZE, 0)
	var base_top := Vector2(BODY_SIZE / 2 - 1, -ARROW_SIZE * 0.5)
	var base_bot := Vector2(BODY_SIZE / 2 - 1, ARROW_SIZE * 0.5)
	draw_polygon([tip, base_top, base_bot], [ARROW_COLOR, ARROW_COLOR, ARROW_COLOR])
