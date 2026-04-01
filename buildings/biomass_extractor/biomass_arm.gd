extends Node2D

## Animated 2-segment arm that visually grabs biomass from nearby cells.
## Placed under Rotatable as "CodeAnimArm*" — building_def rotates it with the building.
## Multiple instances can coexist; each picks random targets independently.

const TILE_SIZE := 32.0
const SEG1 := 20.0  # upper arm
const SEG2 := 18.0  # forearm
const INNER_SCATTER := 10.0  # random offset within target cell (pixels from center)

# Timing
const EXTEND_TIME := 0.5
const GRAB_TIME := 0.25
const RETRACT_TIME := 0.45
const PAUSE_MIN := 0.1
const PAUSE_MAX := 0.6
var _pause_time := 0.3

# Colors
var COL_ARM := Color(0.35, 0.30, 0.18)
var COL_ARM_HI := Color(0.42, 0.36, 0.22)
var COL_JOINT := Color(0.29, 0.24, 0.15)
var COL_CLAW := Color(0.24, 0.36, 0.14)
var COL_FRAG := Color(0.30, 0.44, 0.16)
var COL_FRAG_HI := Color(0.40, 0.55, 0.22)

enum { IDLE, EXTENDING, GRABBING, RETRACTING, PAUSING }

var state := IDLE
var _timer := 0.0
var _target := Vector2.ZERO  # randomized point inside a target cell
@export var base_pos := Vector2(16, 16)  # shoulder pivot (Rotatable-local, unrotated)
var drop_pos := Vector2(16, 16)  # where the arm deposits fragments (maw center)

var _shoulder := Vector2.ZERO
var _elbow := Vector2.ZERO
var _hand := Vector2.ZERO
var _has_fragment := false
var _active := false
var _ever_animated := false  # true once first cycle starts
var _extend_from := Vector2.ZERO  # hand position at start of extend

## Initial delay before first cycle (used to stagger multiple arms).
@export var start_delay: float = 0.0

## Candidate target cell centers in Rotatable-local coords (set by logic).
var _targets: Array = []
var _rng := RandomNumberGenerator.new()

## Elbow bend direction: +1 or -1 (set per-instance so two arms bend opposite ways).
@export var bend_sign: float = -1.0


func set_active(active: bool, targets: Array) -> void:
	_active = active
	_targets = targets


func _ready() -> void:
	_rng.seed = hash(get_instance_id())
	_shoulder = base_pos
	_elbow = base_pos
	_hand = drop_pos
	_extend_from = drop_pos


func _process(delta: float) -> void:
	if state == IDLE:
		if start_delay > 0.0:
			start_delay -= delta
			queue_redraw()
			return
		if _active and not _targets.is_empty():
			_start_cycle()
		else:
			queue_redraw()
			return

	_timer += delta

	match state:
		EXTENDING:
			if _timer >= EXTEND_TIME:
				state = GRABBING
				_timer = 0.0
		GRABBING:
			if _timer >= GRAB_TIME:
				state = RETRACTING
				_timer = 0.0
				_has_fragment = true
		RETRACTING:
			if _timer >= RETRACT_TIME:
				state = PAUSING
				_timer = 0.0
				_has_fragment = false
				_pause_time = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)
				# Don't recompute joints — freeze in place
				queue_redraw()
				return
		PAUSING:
			if _timer >= _pause_time:
				state = IDLE
				_timer = 0.0
			# Frozen — don't recompute joints
			queue_redraw()
			return

	_compute_joints()
	queue_redraw()


func _start_cycle() -> void:
	var idx := _rng.randi() % _targets.size()
	var cell_center: Vector2 = _targets[idx]
	var offset := Vector2(
		_rng.randf_range(-INNER_SCATTER, INNER_SCATTER),
		_rng.randf_range(-INNER_SCATTER, INNER_SCATTER)
	)
	_extend_from = _hand  # start from current hand position
	_target = cell_center + offset
	state = EXTENDING
	_timer = 0.0
	_has_fragment = false
	_ever_animated = true


func _compute_joints() -> void:
	_shoulder = base_pos

	match state:
		EXTENDING:
			var t := _smoothstep(_timer / EXTEND_TIME)
			_hand = _extend_from.lerp(_target, t)
		GRABBING:
			_hand = _target
		RETRACTING:
			var t := _smoothstep(_timer / RETRACT_TIME)
			_hand = _target.lerp(drop_pos, t)
		_:
			_hand = drop_pos

	# 2-segment IK for elbow position
	var reach := _shoulder.distance_to(_hand)
	if reach < 6.0:
		# Too close to base — keep previous elbow/hand to avoid degenerate pose
		return

	var clamped := clampf(reach, absf(SEG1 - SEG2) + 0.5, SEG1 + SEG2 - 0.5)
	var angle_to_hand := (_hand - _shoulder).angle()
	var cos_a := (SEG1 * SEG1 + clamped * clamped - SEG2 * SEG2) / (2.0 * SEG1 * clamped)
	cos_a = clampf(cos_a, -1.0, 1.0)
	var elbow_offset := acos(cos_a)
	var elbow_angle := angle_to_hand + bend_sign * elbow_offset
	_elbow = _shoulder + Vector2(cos(elbow_angle), sin(elbow_angle)) * SEG1


func _draw() -> void:
	if not _ever_animated:
		return

	# Upper arm
	draw_line(_shoulder, _elbow, COL_ARM, 3.0)
	# Forearm
	draw_line(_elbow, _hand, COL_ARM, 3.0)

	# Highlight edges
	if _shoulder.distance_to(_elbow) > 1.0:
		var n1 := (_elbow - _shoulder).normalized().orthogonal()
		draw_line(_shoulder + n1, _elbow + n1, COL_ARM_HI, 1.0)
	if _elbow.distance_to(_hand) > 1.0:
		var n2 := (_hand - _elbow).normalized().orthogonal()
		draw_line(_elbow + n2, _hand + n2, COL_ARM_HI, 1.0)

	# Shoulder joint
	draw_circle(_shoulder, 3.0, COL_JOINT)
	# Elbow joint
	draw_circle(_elbow, 2.5, COL_JOINT)
	draw_circle(_elbow, 1.5, COL_ARM_HI)

	# Claw
	var claw_dir: Vector2
	if _hand.distance_to(_elbow) > 1.0:
		claw_dir = (_hand - _elbow).normalized()
	else:
		claw_dir = (_target - base_pos).normalized() if _target != base_pos else Vector2.RIGHT
	var claw_perp := claw_dir.orthogonal()
	var claw_len := 5.0
	var spread := 3.0
	if state == GRABBING:
		var close_t := clampf(_timer / GRAB_TIME, 0.0, 1.0)
		spread = lerpf(3.0, 1.0, close_t)
	elif _has_fragment:
		spread = 1.0

	var claw_tip := _hand + claw_dir * claw_len
	draw_line(_hand, claw_tip + claw_perp * spread, COL_CLAW, 2.0)
	draw_line(_hand, claw_tip - claw_perp * spread, COL_CLAW, 2.0)
	# Wrist joint
	draw_circle(_hand, 2.0, COL_JOINT)

	# Carried fragment
	if _has_fragment or (state == GRABBING and _timer > GRAB_TIME * 0.6):
		draw_rect(Rect2(claw_tip - Vector2(2.5, 2.5), Vector2(5, 5)), COL_FRAG)
		draw_rect(Rect2(claw_tip - Vector2(1.5, 1.5), Vector2(3, 3)), COL_FRAG_HI)


static func _smoothstep(t: float) -> float:
	var c := clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
