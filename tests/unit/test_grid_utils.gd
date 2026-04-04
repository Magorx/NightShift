extends "res://tests/base_test.gd"

## Coordinate math tests for GridUtils (3D world space).
## Grid (X,Y) maps to world (X, 0, Z) with 1 unit per tile.

const GU := preload("res://scripts/autoload/grid_utils.gd")

# -- helpers --

func assert_vec3_eq(a: Vector3, b: Vector3, msg: String = "") -> void:
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
	assert_vec3_eq(GU.grid_to_world(Vector2i(0, 0)), Vector3.ZERO, "origin")

func test_grid_to_world_x_axis() -> void:
	assert_vec3_eq(GU.grid_to_world(Vector2i(1, 0)), Vector3(1, 0, 0), "grid(1,0)")

func test_grid_to_world_y_axis() -> void:
	assert_vec3_eq(GU.grid_to_world(Vector2i(0, 1)), Vector3(0, 0, 1), "grid(0,1)")

func test_grid_to_world_diagonal() -> void:
	assert_vec3_eq(GU.grid_to_world(Vector2i(3, 5)), Vector3(3, 0, 5), "grid(3,5)")

func test_grid_to_world_negative() -> void:
	assert_vec3_eq(GU.grid_to_world(Vector2i(-2, -4)), Vector3(-2, 0, -4), "negative")

func test_grid_to_center_matches() -> void:
	for pos in [Vector2i(0,0), Vector2i(3,7), Vector2i(-2,5)]:
		assert_vec3_eq(GU.grid_to_center(pos), GU.grid_to_world(pos),
			"center == world at %s" % str(pos))

# ---------------------------------------------------------------
# 2. world_to_grid
# ---------------------------------------------------------------

func test_world_to_grid_origin() -> void:
	assert_vec2i_eq(GU.world_to_grid(Vector3.ZERO), Vector2i(0, 0), "origin")

func test_world_to_grid_exact() -> void:
	assert_vec2i_eq(GU.world_to_grid(Vector3(1, 0, 0)), Vector2i(1, 0), "(1,0,0)")
	assert_vec2i_eq(GU.world_to_grid(Vector3(0, 0, 1)), Vector2i(0, 1), "(0,0,1)")

func test_world_to_grid_ignores_y() -> void:
	assert_vec2i_eq(GU.world_to_grid(Vector3(2, 5.5, 3)), Vector2i(2, 3), "ignores Y height")

func test_world_to_grid_near_edge() -> void:
	assert_vec2i_eq(GU.world_to_grid(Vector3(1.3, 0, 2.1)), Vector2i(1, 2), "near edge")

func test_world_to_grid_negative() -> void:
	assert_vec2i_eq(GU.world_to_grid(Vector3(-1, 0, -1)), Vector2i(-1, -1), "negative")

# ---------------------------------------------------------------
# 3. Roundtrip consistency
# ---------------------------------------------------------------

func test_roundtrip() -> void:
	var positions := [
		Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(5,3),
		Vector2i(-3,-7), Vector2i(63,63), Vector2i(127,0),
	]
	for grid_pos in positions:
		var world_pos := GU.grid_to_world(grid_pos)
		var back := GU.world_to_grid(world_pos)
		assert_vec2i_eq(back, grid_pos, "roundtrip %s" % str(grid_pos))

# ---------------------------------------------------------------
# 4. grid_offset
# ---------------------------------------------------------------

func test_grid_offset_zero_fraction() -> void:
	var result := GU.grid_offset(Vector2i(2, 3), Vector2(1, 0), 0.0)
	assert_vec3_eq(result, GU.grid_to_world(Vector2i(2, 3)), "frac 0 = center")

func test_grid_offset_half() -> void:
	var result := GU.grid_offset(Vector2i(0, 0), Vector2(1, 0), 0.5)
	assert_vec3_eq(result, Vector3(0.5, 0, 0), "half along X")

func test_grid_offset_full() -> void:
	var result := GU.grid_offset(Vector2i(0, 0), Vector2(1, 0), 1.0)
	assert_vec3_eq(result, Vector3(1, 0, 0), "full = next center")

func test_grid_offset_z_direction() -> void:
	var result := GU.grid_offset(Vector2i(0, 0), Vector2(0, 1), 0.5)
	assert_vec3_eq(result, Vector3(0, 0, 0.5), "half along Z")

# ---------------------------------------------------------------
# 5. grid_dir_to_world
# ---------------------------------------------------------------

func test_grid_dir_to_world_normalized() -> void:
	var d := GU.grid_dir_to_world(Vector2(1, 0))
	assert_true(absf(d.length() - 1.0) < 0.001, "dir normalized")

func test_grid_dir_to_world_axes() -> void:
	assert_vec3_eq(GU.grid_dir_to_world(Vector2(1, 0)), Vector3(1, 0, 0), "dir +X")
	assert_vec3_eq(GU.grid_dir_to_world(Vector2(0, 1)), Vector3(0, 0, 1), "dir +Z")

func test_grid_dir_to_world_opposite() -> void:
	var right := GU.grid_dir_to_world(Vector2(1, 0))
	var left := GU.grid_dir_to_world(Vector2(-1, 0))
	assert_vec3_eq(right + left, Vector3.ZERO, "opposite dirs cancel")

# ---------------------------------------------------------------
# 6. tile_transform
# ---------------------------------------------------------------

func test_tile_transform_origin() -> void:
	var t := GU.tile_transform(Vector2i(0, 0))
	assert_vec3_eq(t.origin, Vector3.ZERO, "transform origin at (0,0)")

func test_tile_transform_position() -> void:
	var t := GU.tile_transform(Vector2i(5, 3))
	assert_vec3_eq(t.origin, Vector3(5, 0, 3), "transform origin at (5,3)")

# ---------------------------------------------------------------
# 7. map helpers
# ---------------------------------------------------------------

func test_map_world_size() -> void:
	var s := GU.map_world_size(16)
	assert_vec3_eq(s, Vector3(16, 0, 16), "map size 16")

func test_map_origin() -> void:
	assert_vec3_eq(GU.map_origin(16), Vector3.ZERO, "map origin")
