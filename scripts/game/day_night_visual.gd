extends Node

## Rotates sun and moon DirectionalLight3Ds around the map on two different
## orbital planes.  During the middle 80% of each phase the lights spin at
## normal speed; during the 10% at each transition edge the speed ramps up
## dramatically, making sunrise/sunset feel intense.
##
## Sun is dominant during build (day), moon during fight (night).
## Environment ambient/background colours lerp to match.

# ── Orbital tuning ────────────────────────────────────────────────────────
# Each light completes a half-revolution (rise → set) per phase.
const BASE_HALF_REV := PI  # radians per phase at normal speed

# Speed multiplier during the fast transition edges (first/last 10%)
const EDGE_SPEED_MULT := 6.0
# Fraction of phase duration that counts as "edge" on each side
const EDGE_FRACTION := 0.10

# Orbital tilt offsets (so sun and moon travel in different planes)
const SUN_TILT := 0.0                # sun orbits in the XY plane tilted by this around Z
const MOON_TILT := deg_to_rad(40.0)  # moon's plane is rotated 40° off the sun's

# ── Light settings ────────────────────────────────────────────────────────
const SUN_COLOR := Color(1.0, 0.95, 0.85)
const SUN_ENERGY := 1.0

const MOON_COLOR := Color(0.5, 0.45, 0.7)
const MOON_ENERGY := 0.4

# ── Environment settings ──────────────────────────────────────────────────
const DAY_AMBIENT_COLOR := Color(0.85, 0.87, 0.9, 1.0)
const DAY_AMBIENT_ENERGY := 1.8
const DAY_BG_COLOR := Color(0.18, 0.22, 0.16, 1.0)

const NIGHT_AMBIENT_COLOR := Color(0.3, 0.25, 0.45, 1.0)
const NIGHT_AMBIENT_ENERGY := 0.5
const NIGHT_BG_COLOR := Color(0.06, 0.04, 0.1, 1.0)

# ── State ─────────────────────────────────────────────────────────────────
var environment: Environment
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D

# Accumulated orbital angle (radians).  Sun starts at "noon" (overhead),
# moon starts at "below horizon".
var _sun_angle: float = 0.0
var _moon_angle: float = PI  # offset by half-rev so they alternate

var _last_phase: StringName = &"build"
var _phase_progress_prev: float = 0.0


func setup(env: Environment, sun: DirectionalLight3D, moon: DirectionalLight3D) -> void:
	environment = env
	sun_light = sun
	moon_light = moon

	sun_light.light_color = SUN_COLOR
	moon_light.light_color = MOON_COLOR

	RoundManager.phase_changed.connect(_on_phase_changed)
	set_process(true)
	_apply_lights()
	_apply_environment(0.0)


func _on_phase_changed(phase: StringName) -> void:
	_last_phase = phase
	_phase_progress_prev = 0.0


func _process(_delta: float) -> void:
	if not RoundManager.is_running:
		return

	var progress := RoundManager.get_phase_progress()

	# How far progress moved this frame
	var dp := progress - _phase_progress_prev
	if dp < 0.0:
		dp = 0.0  # phase just reset
	_phase_progress_prev = progress

	# Apply speed curve: fast at edges, normal in middle
	var speed_mult := _speed_at(progress)
	var angle_step := dp * BASE_HALF_REV * speed_mult

	# Both lights always advance; the active one rises while the other sets
	if _last_phase == &"build":
		_sun_angle += angle_step
		_moon_angle += angle_step
	else:
		_sun_angle += angle_step
		_moon_angle += angle_step

	_apply_lights()
	_apply_environment(progress)


func _speed_at(progress: float) -> float:
	# Edges: [0, EDGE_FRACTION] and [1-EDGE_FRACTION, 1]
	# Middle 80%: speed = 1.0
	# Edges: speed ramps up to EDGE_SPEED_MULT
	if progress < EDGE_FRACTION:
		# Ramp from EDGE_SPEED_MULT down to 1.0
		var t := progress / EDGE_FRACTION
		return lerpf(EDGE_SPEED_MULT, 1.0, t)
	elif progress > 1.0 - EDGE_FRACTION:
		# Ramp from 1.0 up to EDGE_SPEED_MULT
		var t := (progress - (1.0 - EDGE_FRACTION)) / EDGE_FRACTION
		return lerpf(1.0, EDGE_SPEED_MULT, t)
	return 1.0


func _apply_lights() -> void:
	# Sun orbit: rotates around Z axis in XY plane, tilted by SUN_TILT
	var sun_dir := _orbital_direction(_sun_angle, SUN_TILT)
	sun_light.basis = _look_along(sun_dir)

	# Moon orbit: different tilt plane
	var moon_dir := _orbital_direction(_moon_angle, MOON_TILT)
	moon_light.basis = _look_along(moon_dir)

	# Energy based on elevation: full when overhead, zero when below horizon
	var sun_elev := sun_dir.y  # positive = above horizon
	sun_light.light_energy = SUN_ENERGY * clampf(sun_elev * 2.0, 0.0, 1.0)
	sun_light.visible = sun_elev > 0.0

	var moon_elev := moon_dir.y
	moon_light.light_energy = MOON_ENERGY * clampf(moon_elev * 2.0, 0.0, 1.0)
	moon_light.visible = moon_elev > 0.0


func _orbital_direction(angle: float, tilt: float) -> Vector3:
	# Base orbit in the XZ-Y plane: angle=0 → overhead (+Y), angle=PI/2 → +X horizon
	var x := sin(angle)
	var y := cos(angle)

	# Apply tilt rotation around the X axis
	var tilted_y := y * cos(tilt)
	var tilted_z := y * sin(tilt)

	return Vector3(x, tilted_y, tilted_z).normalized()


func _look_along(dir: Vector3) -> Basis:
	# DirectionalLight3D shines along its -Z axis, so we need the light's
	# -Z to point in `dir` (from sky toward ground).
	if dir.is_zero_approx():
		return Basis.IDENTITY
	var forward := -dir.normalized()
	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.99:
		up = Vector3.FORWARD
	var right := up.cross(forward).normalized()
	up = forward.cross(right).normalized()
	return Basis(right, up, forward)


func _apply_environment(progress: float) -> void:
	# Lerp environment based on phase and progress
	var t: float
	if _last_phase == &"build":
		# Night → Day: t goes 0→1 meaning day intensifies
		t = clampf(progress * 2.0, 0.0, 1.0)  # reach full day by 50% progress
	else:
		# Day → Night: t goes 1→0
		t = 1.0 - clampf(progress * 2.0, 0.0, 1.0)

	environment.ambient_light_color = NIGHT_AMBIENT_COLOR.lerp(DAY_AMBIENT_COLOR, t)
	environment.ambient_light_energy = lerpf(NIGHT_AMBIENT_ENERGY, DAY_AMBIENT_ENERGY, t)
	environment.background_color = NIGHT_BG_COLOR.lerp(DAY_BG_COLOR, t)
