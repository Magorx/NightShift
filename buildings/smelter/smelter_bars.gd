extends Node2D

## Animated bars inside the smelter casting molds.
## Two bars per mold move vertically in opposite directions with random timing.
## Active: hot glow, smooth oscillation. Inactive: glow fades, bars decelerate to stop.

# Hot (active) color
const HOT_COLOR := Color(0.55, 0.22, 0.04, 0.95)
# Cold (inactive) color
const COLD_COLOR := Color(0.14, 0.11, 0.09, 0.85)

# Mold geometry (sprite-space pixel coordinates)
const LEFT_X := 9.0
const RIGHT_X := 40.0
const CENTER_Y := 80.0     # separator line center
const SLIDE_RANGE := 3.0   # pixels each direction — stays within mold inner (y=73-87)

# Hold timer prevents flicker between craft cycles
const HOLD_TIME := 0.35
var _hold_timer := 0.0

var _active := false
var _heat := 0.0         # 0.0 (cold) to 1.0 (hot)
var _speed_mul := 0.0    # speed multiplier, decelerates to 0

# Four independent phases: [left_upper, left_lower, right_upper, right_lower]
var _phases: Array = [0.0, 0.0, 0.0, 0.0]
var _speeds: Array = [2.4, 2.0, 2.2, 2.6]

# Sprite nodes (created in _ready from the bar texture)
var _bars: Array[Sprite2D] = []

func set_active(active: bool) -> void:
	_active = active

func _ready() -> void:
	var bar_tex := preload("res://buildings/smelter/sprites/bar.png")
	for i in 4:
		var spr := Sprite2D.new()
		spr.texture = bar_tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = false
		add_child(spr)
		_bars.append(spr)
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
			if want_active and fmod(_phases[i], TAU) < delta * _speeds[i] * _speed_mul:
				_speeds[i] = randf_range(1.6, 3.0)

	# Update bar positions and colors
	var col := COLD_COLOR.lerp(HOT_COLOR, _heat)

	var offsets: Array = [
		sin(_phases[0]) * SLIDE_RANGE,
		sin(_phases[1] + PI) * SLIDE_RANGE,
		sin(_phases[2]) * SLIDE_RANGE,
		sin(_phases[3] + PI) * SLIDE_RANGE,
	]

	_bars[0].position = Vector2(LEFT_X, clampf(CENTER_Y - 4.0 + offsets[0], 73.0, 83.0))
	_bars[1].position = Vector2(LEFT_X, clampf(CENTER_Y + 1.0 + offsets[1], 73.0, 83.0))
	_bars[2].position = Vector2(RIGHT_X, clampf(CENTER_Y - 4.0 + offsets[2], 73.0, 83.0))
	_bars[3].position = Vector2(RIGHT_X, clampf(CENTER_Y + 1.0 + offsets[3], 73.0, 83.0))

	for spr in _bars:
		spr.modulate = col
