extends Node

## Rotates sun and moon DirectionalLight3Ds around the map on two different
## orbital planes.  ProceduralSkyMaterial automatically renders sun/moon discs
## at each light's position.
##
## Speed curve: middle 80% of each phase is normal rotation, the 10% edges
## at each transition ramp up for intense sunrise/sunset.
##
## Angle is computed directly from phase progress (not accumulated), so
## there is no frame-rate jitter.

# ── Orbital tuning ────────────────────────────────────────────────────────
const EDGE_SPEED_MULT := 6.0
const EDGE_FRACTION := 0.0

# Orbital plane tilts (Y rotation) so sun and moon travel different paths
const SUN_YAW := 0.0
const MOON_YAW := deg_to_rad(40.0)

# ── Light settings ────────────────────────────────────────────────────────
const SUN_COLOR := Color(1.0, 0.95, 0.85)
const SUN_ENERGY := 1.0

const MOON_COLOR := Color(0.75, 0.45, 0.5)
const MOON_ENERGY := 0.4

# ── Sky color palettes ────────────────────────────────────────────────────
const DAY_SKY_TOP := Color(0.35, 0.45, 0.65)
const DAY_SKY_HORIZON := Color(0.55, 0.6, 0.67)
const DAY_GROUND_BOTTOM := Color(0.18, 0.22, 0.16)
const DAY_GROUND_HORIZON := Color(0.3, 0.35, 0.3)
const DAY_AMBIENT_ENERGY := 1.0

const NIGHT_SKY_TOP := Color(0.04, 0.03, 0.08)
const NIGHT_SKY_HORIZON := Color(0.08, 0.06, 0.14)
const NIGHT_GROUND_BOTTOM := Color(0.04, 0.03, 0.06)
const NIGHT_GROUND_HORIZON := Color(0.06, 0.05, 0.1)
const NIGHT_AMBIENT_ENERGY := 0.3

# ── Speed curve normalization ─────────────────────────────────────────────
const _SPEED_INTEGRAL: float = EDGE_FRACTION * (1.0 + EDGE_SPEED_MULT) + (1.0 - 2.0 * EDGE_FRACTION)

# ── State ─────────────────────────────────────────────────────────────────
var environment: Environment
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial

# Counts completed half-revolutions (incremented each phase change).
# Starts at -1 because RoundManager emits phase_changed on the initial start_run().
var _half_rev_count: int = -1
var _last_phase: StringName = &"build"


func setup(env: Environment, sun: DirectionalLight3D, moon: DirectionalLight3D) -> void:
	environment = env
	sun_light = sun
	moon_light = moon

	sun_light.light_color = SUN_COLOR
	moon_light.light_color = MOON_COLOR
	moon_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY

	if environment.sky and environment.sky.sky_material is ProceduralSkyMaterial:
		sky_mat = environment.sky.sky_material

	RoundManager.phase_changed.connect(_on_phase_changed)
	set_process(true)
	_update(0.0)


func _on_phase_changed(phase: StringName) -> void:
	_last_phase = phase
	_half_rev_count += 1


func _process(_delta: float) -> void:
	if not RoundManager.is_running:
		return
	_update(RoundManager.get_phase_progress())


func _update(progress: float) -> void:
	var eased := _eased_progress(progress)

	# Deterministic angle: base + eased fraction of current half-rev
	var sun_angle := (float(_half_rev_count) + eased) * PI
	var moon_angle := sun_angle + PI

	# Quantize to 0.25° steps — prevents shadow map texel snapping jitter
	# var snap := PI / 720.0
	# sun_angle = roundf(sun_angle / snap) * snap
	# moon_angle = roundf(moon_angle / snap) * snap

	# Apply rotation and energy
	sun_light.rotation = Vector3(-sun_angle, SUN_YAW, 0.0)
	moon_light.rotation = Vector3(-moon_angle, MOON_YAW, 0.0)

	var sun_elev := sin(sun_angle)
	sun_light.light_energy = SUN_ENERGY * clampf(sun_elev * 2.0, 0.0, 1.0)
	sun_light.visible = sun_elev > 0.0

	# At low sun elevation (grazing angle) self-shadowing increases — ramp up
	# shadow bias so terrain doesn't shadow itself into dark bands.
	# At elev >= 0.3 (17°) no adjustment needed; at elev == 0 (horizon) bias peaks.
	var low_angle_t := clampf(1.0 - sun_elev / 0.3, 0.0, 1.0)
	sun_light.shadow_bias = lerpf(0.1, 0.3, low_angle_t)

	var moon_elev := sin(moon_angle)
	moon_light.light_energy = MOON_ENERGY * clampf(moon_elev * 2.0, 0.0, 1.0)
	moon_light.visible = moon_elev > 0.0

	_apply_sky(progress)


## Maps [0,1] progress to [0,1] eased progress using the speed curve.
## This is the cumulative integral of speed_at(t), normalized.
func _eased_progress(p: float) -> float:
	if p <= 0.0:
		return 0.0
	if p >= 1.0:
		return 1.0

	var e := EDGE_FRACTION
	var s := EDGE_SPEED_MULT
	var integral: float

	if p < e:
		# Leading edge: speed = lerp(s, 1, p/e)
		integral = s * p + (1.0 - s) * p * p / (2.0 * e)
	elif p <= 1.0 - e:
		# Middle: constant speed 1.0
		var edge_area := e * (s + 1.0) / 2.0
		integral = edge_area + (p - e)
	else:
		# Trailing edge: speed = lerp(1, s, (p-(1-e))/e)
		var edge_area := e * (s + 1.0) / 2.0
		var middle_area := 1.0 - 2.0 * e
		var lt := p - (1.0 - e)
		var trail_area := lt + (s - 1.0) * lt * lt / (2.0 * e)
		integral = edge_area + middle_area + trail_area

	return integral / _SPEED_INTEGRAL


func _apply_sky(progress: float) -> void:
	var t: float
	if _last_phase == &"build":
		t = clampf(progress * 2.0, 0.0, 1.0)
	else:
		t = 1.0 - clampf(progress * 2.0, 0.0, 1.0)

	environment.ambient_light_energy = lerpf(NIGHT_AMBIENT_ENERGY, DAY_AMBIENT_ENERGY, t)

	if sky_mat:
		sky_mat.sky_top_color = NIGHT_SKY_TOP.lerp(DAY_SKY_TOP, t)
		sky_mat.sky_horizon_color = NIGHT_SKY_HORIZON.lerp(DAY_SKY_HORIZON, t)
		sky_mat.ground_bottom_color = NIGHT_GROUND_BOTTOM.lerp(DAY_GROUND_BOTTOM, t)
		sky_mat.ground_horizon_color = NIGHT_GROUND_HORIZON.lerp(DAY_GROUND_HORIZON, t)
