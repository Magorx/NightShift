extends "res://tests/base_test.gd"

## Coordinate math tests for the isometric GridUtils.
## All expected values are computed from GridUtils constants so tests
## pass regardless of TILE_WIDTH, TILE_HEIGHT, or ROTATION settings.

const GU := preload("res://scripts/autoload/grid_utils.gd")

# -- helpers --

func assert_vec2_eq(a: Vector2, b: Vector2, msg: String = "") -> void:
	var close := a.distance_to(b) < 0.01
	if close:
		_pass_count += 1
	else:
		_fail_count += 1
		var text := "%s: expected %s == %s" % [_test_name, str(a), str(b)]
		if msg:
			text += " (%s)" % msg
		printerr("  FAIL: " + text)

func assert_vec2i_eq(a: Vector2i, b: Vector2i, msg: String = "") -> void:
	assert_eq(a, b, msg)

# ---------------------------------------------------------------
# 1. grid_to_world / grid_to_center
# ---------------------------------------------------------------

func test_grid_to_world_origin() -> void:
	assert_vec2_eq(GU.grid_to_world(Vector2i(0, 0)), Vector2(0, 0), "origin")

func test_grid_to_world_x_axis() -> void:
	# Grid X = +1 should move by _basis_x
	assert_vec2_eq(GU.grid_to_world(Vector2i(1, 0)), GU._basis_x, "grid(1,0)")

func test_grid_to_world_y_axis() -> void:
	# Grid Y = +1 should move by _basis_y
	assert_vec2_eq(GU.grid_to_world(Vector2i(0, 1)), GU._basis_y, "grid(0,1)")

func test_grid_to_world_diagonal() -> void:
	assert_vec2_eq(GU.grid_to_world(Vector2i(1, 1)), GU._basis_x + GU._basis_y, "grid(1,1)")

func test_grid_to_world_arbitrary() -> void:
	var expected := GU._basis_x * 5 + GU._basis_y * 3
	assert_vec2_eq(GU.grid_to_world(Vector2i(5, 3)), expected, "grid(5,3)")

func test_grid_to_world_negative() -> void:
	assert_vec2_eq(GU.grid_to_world(Vector2i(-1, 0)), GU._basis_x * -1, "grid(-1,0)")
	assert_vec2_eq(GU.grid_to_world(Vector2i(0, -1)), GU._basis_y * -1, "grid(0,-1)")

func test_grid_to_center_matches_grid_to_world() -> void:
	var positions := [Vector2i(0,0), Vector2i(3,7), Vector2i(-2, 5)]
	for pos in positions:
		assert_vec2_eq(GU.grid_to_center(pos), GU.grid_to_world(pos),
			"grid_to_center == grid_to_world at %s" % str(pos))

# ---------------------------------------------------------------
# 2. world_to_grid
# ---------------------------------------------------------------

func test_world_to_grid_origin() -> void:
	assert_vec2i_eq(GU.world_to_grid(Vector2(0, 0)), Vector2i(0, 0), "origin")

func test_world_to_grid_x_axis() -> void:
	assert_vec2i_eq(GU.world_to_grid(GU._basis_x), Vector2i(1, 0), "basis_x -> (1,0)")

func test_world_to_grid_y_axis() -> void:
	assert_vec2i_eq(GU.world_to_grid(GU._basis_y), Vector2i(0, 1), "basis_y -> (0,1)")

func test_world_to_grid_diagonal() -> void:
	assert_vec2i_eq(GU.world_to_grid(GU._basis_x + GU._basis_y), Vector2i(1, 1), "diagonal")

func test_world_to_grid_negative_coords() -> void:
	assert_vec2i_eq(GU.world_to_grid(GU._basis_x * -1), Vector2i(-1, 0), "neg x")
	assert_vec2i_eq(GU.world_to_grid(GU._basis_y * -1), Vector2i(0, -1), "neg y")

func test_world_to_grid_near_tile_edges() -> void:
	# Small nudge from center should stay in same tile
	var c10 := GU.grid_to_world(Vector2i(1, 0))
	assert_vec2i_eq(GU.world_to_grid(c10 + Vector2(0.5, 0.5)), Vector2i(1, 0), "near (1,0)")
	assert_vec2i_eq(GU.world_to_grid(Vector2(0.5, 0.5)), Vector2i(0, 0), "near (0,0)")

# ---------------------------------------------------------------
# 3. Roundtrip consistency
# ---------------------------------------------------------------

func test_roundtrip_grid_to_world_to_grid() -> void:
	var test_positions := [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1),
		Vector2i(5, 3), Vector2i(10, 10), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(-3, -7), Vector2i(127, 0), Vector2i(0, 127), Vector2i(63, 63),
	]
	for grid_pos in test_positions:
		var world_pos := GU.grid_to_world(grid_pos)
		var back := GU.world_to_grid(world_pos)
		assert_vec2i_eq(back, grid_pos, "roundtrip %s" % str(grid_pos))

# ---------------------------------------------------------------
# 4. grid_offset
# ---------------------------------------------------------------

func test_grid_offset_right_edge() -> void:
	# fraction=0.5 along grid (1,0) from origin = center + basis_x * 0.5
	var result := GU.grid_offset(Vector2i(0, 0), Vector2(1, 0), 0.5)
	assert_vec2_eq(result, GU._basis_x * 0.5, "right edge of (0,0)")

func test_grid_offset_bottom_left_edge() -> void:
	var result := GU.grid_offset(Vector2i(0, 0), Vector2(0, 1), 0.5)
	assert_vec2_eq(result, GU._basis_y * 0.5, "bottom-left edge of (0,0)")

func test_grid_offset_zero_fraction() -> void:
	var result := GU.grid_offset(Vector2i(3, 2), Vector2(1, 0), 0.0)
	assert_vec2_eq(result, GU.grid_to_center(Vector2i(3, 2)), "fraction 0 = center")

func test_grid_offset_full_fraction() -> void:
	# fraction=1.0 along (1,0) from (0,0) should reach center of (1,0)
	var result := GU.grid_offset(Vector2i(0, 0), Vector2(1, 0), 1.0)
	assert_vec2_eq(result, GU.grid_to_center(Vector2i(1, 0)), "fraction 1.0 = next center")

func test_grid_offset_non_origin() -> void:
	var center := GU.grid_to_center(Vector2i(2, 3))
	var result := GU.grid_offset(Vector2i(2, 3), Vector2(0, 1), 0.5)
	assert_vec2_eq(result, center + GU._basis_y * 0.5, "offset from (2,3) along y")

# ---------------------------------------------------------------
# 5. map_world_size
# ---------------------------------------------------------------

func test_map_world_size_1() -> void:
	# Single tile: AABB of grid corners (0,0) to (1,1)
	var expected := GU.map_world_size(1)
	# Verify it's positive and non-zero
	assert_true(expected.x > 0, "1-tile width > 0")
	assert_true(expected.y > 0, "1-tile height > 0")

func test_map_world_size_scales_linearly() -> void:
	# map_world_size(N) should grow with N
	var s1 := GU.map_world_size(1)
	var s4 := GU.map_world_size(4)
	assert_true(s4.x > s1.x * 2, "4-tile wider than 2x 1-tile")
	assert_true(s4.y > s1.y * 2, "4-tile taller than 2x 1-tile")

# ---------------------------------------------------------------
# 6. map_origin
# ---------------------------------------------------------------

func test_map_origin_1() -> void:
	# 1-tile map: AABB of corners grid(0,0) to grid(1,1)
	var origin := GU.map_origin(1)
	var size := GU.map_world_size(1)
	# Origin + size should contain the grid center (0,0)
	assert_true(origin.x <= 0.0, "origin.x <= 0")
	assert_true(origin.y <= 0.0, "origin.y <= 0")

func test_map_origin_is_top_left() -> void:
	# Origin should be the min-x, min-y corner of the AABB
	var origin := GU.map_origin(16)
	var center := GU.grid_to_world(Vector2i(8, 8))
	assert_true(origin.x <= center.x, "origin left of center")
	assert_true(origin.y <= center.y, "origin above center")

# ---------------------------------------------------------------
# 7. Diamond vertex helpers
# ---------------------------------------------------------------

func test_diamond_vertices_sum_to_zero() -> void:
	# The 4 diamond offsets should cancel out (they're symmetric)
	var sum := GU.diamond_top() + GU.diamond_right() + GU.diamond_bottom() + GU.diamond_left()
	assert_vec2_eq(sum, Vector2.ZERO, "diamond vertices cancel")

func test_diamond_points_centered() -> void:
	var c := Vector2(100, 200)
	var pts := GU.get_diamond_points(c)
	var avg := (pts[0] + pts[1] + pts[2] + pts[3]) / 4.0
	assert_vec2_eq(avg, c, "diamond centroid = center")

func test_diamond_top_is_above_center() -> void:
	# With ROTATION=0, top should have negative y offset
	if GU.ROTATION == 0.0:
		assert_true(GU.diamond_top().y < 0, "top vertex above center")

# ---------------------------------------------------------------
# 8. grid_dir_to_screen
# ---------------------------------------------------------------

func test_grid_dir_to_screen_normalized() -> void:
	var d := GU.grid_dir_to_screen(Vector2(1, 0))
	assert_true(absf(d.length() - 1.0) < 0.001, "dir is normalized")

func test_grid_dir_to_screen_opposite() -> void:
	var right := GU.grid_dir_to_screen(Vector2(1, 0))
	var left := GU.grid_dir_to_screen(Vector2(-1, 0))
	assert_vec2_eq(right + left, Vector2.ZERO, "opposite dirs cancel")

# ---------------------------------------------------------------
# 9. Roundtrip at tile vertices (picking test)
# ---------------------------------------------------------------

func test_picking_at_diamond_top() -> void:
	# The top vertex of tile (0,0) should pick as tile (0,0)
	var top := GU.grid_to_center(Vector2i(0, 0)) + GU.diamond_top() * 0.9
	assert_vec2i_eq(GU.world_to_grid(top), Vector2i(0, 0), "top of (0,0) picks (0,0)")

func test_picking_at_diamond_right() -> void:
	var right := GU.grid_to_center(Vector2i(0, 0)) + GU.diamond_right() * 0.9
	assert_vec2i_eq(GU.world_to_grid(right), Vector2i(0, 0), "right of (0,0) picks (0,0)")

func test_picking_at_diamond_bottom() -> void:
	var bottom := GU.grid_to_center(Vector2i(0, 0)) + GU.diamond_bottom() * 0.9
	assert_vec2i_eq(GU.world_to_grid(bottom), Vector2i(0, 0), "bottom of (0,0) picks (0,0)")

func test_picking_at_diamond_left() -> void:
	var left := GU.grid_to_center(Vector2i(0, 0)) + GU.diamond_left() * 0.9
	assert_vec2i_eq(GU.world_to_grid(left), Vector2i(0, 0), "left of (0,0) picks (0,0)")
