extends "res://tests/simulation/simulation_base.gd"

## Synthetic test: places conveyors in configurations that produce all 6 variants
## (straight, turn, side_input, dual_side_input, crossroad, start) at all 4
## rotations, rendered via MultiMeshInstance2D. Captures screenshots to verify
## the shader samples the atlas correctly.

func run_simulation() -> void:
	var cam: GameCamera = game_world.camera
	if cam:
		cam.target_node = null
		cam.snap_to_3d(GridUtils.grid_to_world(Vector2i(20, 18)))
		cam.size = 35.0
		cam._target_size = 35.0

	# ── Row 1 (y=5): rotation=0 (right-pointing) ──
	_place_all_variants(Vector2i(3, 5), 0)
	# ── Row 2 (y=12): rotation=1 (down-pointing) ──
	_place_all_variants(Vector2i(3, 12), 1)
	# ── Row 3 (y=19): rotation=2 (left-pointing) ──
	_place_all_variants(Vector2i(3, 19), 2)
	# ── Row 4 (y=26): rotation=3 (up-pointing) ──
	_place_all_variants(Vector2i(3, 26), 3)

	# Let variant detection run
	await sim_advance_ticks(5)

	# Verify conveyors were placed
	var conv_count := 0
	for b in GameManager.unique_buildings:
		if is_instance_valid(b) and b.building_id == &"conveyor":
			conv_count += 1
	sim_assert(conv_count > 20, "Placed many conveyors (got %d)" % conv_count)

	if _is_screenshot_mode():
		# Capture 4 frames to cover the full animation cycle
		for frame_i in range(4):
			# At 10 FPS, each frame lasts 0.1s = 6 ticks at 60fps
			await sim_advance_ticks(6)
			await sim_capture_screenshot("frame_%d" % frame_i)

		# Also capture a zoomed-in view of one variant group
		if cam:
			cam.snap_to_3d(GridUtils.grid_to_world(Vector2i(8, 5)))
			cam.size = 8.0
			cam._target_size = 8.0
			await sim_advance_ticks(2)
			await sim_capture_screenshot("closeup")

	sim_finish()

## Place all 6 conveyor variants at different x offsets from origin.
## Each variant group is spaced 5 tiles apart horizontally.
func _place_all_variants(origin: Vector2i, rot: int) -> void:
	var dir := _rot_vec(Vector2i.RIGHT, rot)
	var right := _rot_vec(Vector2i(0, 1), rot)   # perpendicular CW
	var left := _rot_vec(Vector2i(0, -1), rot)    # perpendicular CCW

	# ── 1. start: standalone conveyor (no feeding neighbors) ──
	var p := origin
	sim_place_building(&"conveyor", p, rot)

	# ── 2. straight: back feeds in (chain of 2) ──
	p = origin + _rot_vec(Vector2i(4, 0), rot)
	sim_place_building(&"conveyor", p - dir, rot)  # upstream
	sim_place_building(&"conveyor", p, rot)         # this one is "straight"

	# ── 3. turn (no flip): right-side feeds, no back ──
	p = origin + _rot_vec(Vector2i(8, 0), rot)
	# Feeder from the right side, pointing into p
	var right_neighbor := p + right
	var feed_rot := _dir_to_rot(-right)  # feeder points toward p
	sim_place_building(&"conveyor", right_neighbor, feed_rot)
	sim_place_building(&"conveyor", p, rot)

	# ── 4. turn (flip): left-side feeds, no back ──
	p = origin + _rot_vec(Vector2i(12, 0), rot)
	var left_neighbor := p + left
	var feed_rot_l := _dir_to_rot(-left)
	sim_place_building(&"conveyor", left_neighbor, feed_rot_l)
	sim_place_building(&"conveyor", p, rot)

	# ── 5. side_input (no flip): back + right feed ──
	p = origin + _rot_vec(Vector2i(16, 0), rot)
	sim_place_building(&"conveyor", p - dir, rot)  # back feeder
	var rn := p + right
	sim_place_building(&"conveyor", rn, _dir_to_rot(-right))  # right feeder
	sim_place_building(&"conveyor", p, rot)

	# ── 6. side_input (flip): back + left feed ──
	p = origin + _rot_vec(Vector2i(20, 0), rot)
	sim_place_building(&"conveyor", p - dir, rot)  # back feeder
	var ln := p + left
	sim_place_building(&"conveyor", ln, _dir_to_rot(-left))  # left feeder
	sim_place_building(&"conveyor", p, rot)

	# ── 7. dual_side_input: both sides feed ──
	p = origin + _rot_vec(Vector2i(24, 0), rot)
	sim_place_building(&"conveyor", p + right, _dir_to_rot(-right))
	sim_place_building(&"conveyor", p + left, _dir_to_rot(-left))
	sim_place_building(&"conveyor", p, rot)

	# ── 8. crossroad: back + both sides feed ──
	p = origin + _rot_vec(Vector2i(28, 0), rot)
	sim_place_building(&"conveyor", p - dir, rot)  # back
	sim_place_building(&"conveyor", p + right, _dir_to_rot(-right))
	sim_place_building(&"conveyor", p + left, _dir_to_rot(-left))
	sim_place_building(&"conveyor", p, rot)

## Rotate a Vector2i by rot steps (0=0°, 1=90°CW, 2=180°, 3=270°CW).
func _rot_vec(v: Vector2i, rot: int) -> Vector2i:
	var r := v
	for i in rot:
		r = Vector2i(-r.y, r.x)
	return r

## Convert a direction vector to a rotation index (0=right, 1=down, 2=left, 3=up).
func _dir_to_rot(d: Vector2i) -> int:
	if d == Vector2i.RIGHT: return 0
	if d == Vector2i.DOWN: return 1
	if d == Vector2i.LEFT: return 2
	if d == Vector2i.UP: return 3
	return 0
