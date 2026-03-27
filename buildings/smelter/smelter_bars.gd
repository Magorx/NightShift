extends Node2D

## Animated bars inside the smelter casting molds.
## Two bars per mold move vertically in opposite directions with random timing.
## Active: hot glow, smooth oscillation. Inactive: glow fades, bars decelerate to stop.

# Hot (active) colors
const HOT_BODY := Color(0.55, 0.22, 0.04, 0.95)
const HOT_HIGHLIGHT := Color(0.85, 0.40, 0.10, 0.95)
const HOT_SHADOW := Color(0.35, 0.12, 0.02, 0.90)
# Cold (inactive) colors
const COLD_BODY := Color(0.14, 0.11, 0.09, 0.85)
const COLD_HIGHLIGHT := Color(0.22, 0.18, 0.15, 0.70)
const COLD_SHADOW := Color(0.08, 0.06, 0.05, 0.80)

# Mold geometry (sprite-space pixel coordinates)
const LEFT_X := 9.0
const RIGHT_X := 40.0
const CENTER_Y := 80.0     # separator line center
const BAR_W := 14.0
const BAR_H := 4.0
const SLIDE_RANGE := 3.0   # pixels each direction — stays within mold inner (y=73-87)
const MOLD_INNER_TOP := 73.0
const MOLD_INNER_BOT := 87.0

# Hold timer prevents flicker between craft cycles
const HOLD_TIME := 0.35
var _hold_timer := 0.0

var _active := false
var _heat := 0.0         # 0.0 (cold) to 1.0 (hot)
var _speed_mul := 0.0    # speed multiplier, decelerates to 0

# Four independent phases: [left_upper, left_lower, right_upper, right_lower]
var _phases: Array = [0.0, 0.0, 0.0, 0.0]
var _speeds: Array = [2.4, 2.0, 2.2, 2.6]

func set_active(active: bool) -> void:
	_active = active

func _ready() -> void:
	# Randomize initial state so adjacent smelters look different
	for i in 4:
		_phases[i] = randf_range(0.0, TAU)
		_speeds[i] = randf_range(1.6, 3.0)

func _physics_process(delta: float) -> void:
	# Hold: stay visually active briefly after deactivation
	if _active:
		_hold_timer = HOLD_TIME
	elif _hold_timer > 0.0:
		_hold_timer -= delta
	var want_active := _active or _hold_timer > 0.0

	# Heat ramp (fast heat-up, slower cool-down)
	var target_heat := 1.0 if want_active else 0.0
	var heat_rate := 4.0 if want_active else 1.5
	_heat = move_toward(_heat, target_heat, delta * heat_rate)

	# Speed: accelerate when active, decelerate when not
	if want_active:
		_speed_mul = move_toward(_speed_mul, 1.0, delta * 4.0)
	else:
		_speed_mul = move_toward(_speed_mul, 0.0, delta * 1.2)

	# Advance all four bar phases
	if _speed_mul > 0.001:
		for i in 4:
			_phases[i] += delta * _speeds[i] * _speed_mul
			# Re-randomize speed each full cycle for organic feel
			if want_active and fmod(_phases[i], TAU) < delta * _speeds[i] * _speed_mul:
				_speeds[i] = randf_range(1.6, 3.0)

	queue_redraw()

func _draw() -> void:
	var body_col := COLD_BODY.lerp(HOT_BODY, _heat)
	var hi_col := COLD_HIGHLIGHT.lerp(HOT_HIGHLIGHT, _heat)
	var sh_col := COLD_SHADOW.lerp(HOT_SHADOW, _heat)

	# Upper bars move one way, lower bars move opposite
	var offsets: Array = [
		sin(_phases[0]) * SLIDE_RANGE,        # left upper
		sin(_phases[1] + PI) * SLIDE_RANGE,   # left lower (opposite)
		sin(_phases[2]) * SLIDE_RANGE,         # right upper
		sin(_phases[3] + PI) * SLIDE_RANGE,    # right lower (opposite)
	]

	# Left mold: upper bar
	_draw_bar(LEFT_X, clampf(CENTER_Y - 4.0 + offsets[0], MOLD_INNER_TOP, MOLD_INNER_BOT - BAR_H), body_col, hi_col, sh_col)
	# Left mold: lower bar
	_draw_bar(LEFT_X, clampf(CENTER_Y + 1.0 + offsets[1], MOLD_INNER_TOP, MOLD_INNER_BOT - BAR_H), body_col, hi_col, sh_col)
	# Right mold: upper bar
	_draw_bar(RIGHT_X, clampf(CENTER_Y - 4.0 + offsets[2], MOLD_INNER_TOP, MOLD_INNER_BOT - BAR_H), body_col, hi_col, sh_col)
	# Right mold: lower bar
	_draw_bar(RIGHT_X, clampf(CENTER_Y + 1.0 + offsets[3], MOLD_INNER_TOP, MOLD_INNER_BOT - BAR_H), body_col, hi_col, sh_col)

func _draw_bar(x: float, y: float, body: Color, highlight: Color, shadow: Color) -> void:
	# Shadow (bottom edge)
	draw_rect(Rect2(x, y + BAR_H - 1, BAR_W, 1), shadow)
	# Main body
	draw_rect(Rect2(x, y, BAR_W, BAR_H - 1), body)
	# Highlight (top bright line)
	draw_rect(Rect2(x + 1, y, BAR_W - 2, 1), highlight)
