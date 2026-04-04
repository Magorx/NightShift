extends "res://tests/base_test.gd"

## Coordinate math tests for the isometric GridUtils.
## Validates grid_to_world, world_to_grid, roundtrip consistency,
## grid_offset, map_world_size, and map_origin.

const GU := preload("res://scripts/autoload/grid_utils.gd")

# -- helpers --

func assert_vec2_eq(a: Vector2, b: Vector2, msg: String = "") -> void:
	# Compare with small epsilon to handle floating-point math
	var close := a.distance_to(b) < 0.001
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
	# Grid X goes down-right: +HALF_W, +HALF_H per step
	assert_vec2_eq(GU.grid_to_world(Vector2i(1, 0)), Vector2(32, 16), "grid(1,0)")

func test_grid_to_world_y_axis() -> void:
	# Grid Y goes down-left: -HALF_W, +HALF_H per step
	assert_vec2_eq(GU.grid_to_world(Vector2i(0, 1)), Vector2(-32, 16), "grid(0,1)")

func test_grid_to_world_diagonal() -> void:
	# grid(1,1) = (1-1)*32, (1+1)*16 = (0, 32)
	assert_vec2_eq(GU.grid_to_world(Vector2i(1, 1)), Vector2(0, 32), "grid(1,1)")

func test_grid_to_world_arbitrary() -> void:
	# grid(5,3) = (5-3)*32, (5+3)*16 = (64, 128)
	assert_vec2_eq(GU.grid_to_world(Vector2i(5, 3)), Vector2(64, 128), "grid(5,3)")

func test_grid_to_world_negative() -> void:
	# grid(-1, 0) = (-1-0)*32, (-1+0)*16 = (-32, -16)
	assert_vec2_eq(GU.grid_to_world(Vector2i(-1, 0)), Vector2(-32, -16), "grid(-1,0)")
	# grid(0, -1) = (0-(-1))*32, (0+(-1))*16 = (32, -16)
	assert_vec2_eq(GU.grid_to_world(Vector2i(0, -1)), Vector2(32, -16), "grid(0,-1)")

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
	assert_vec2i_eq(GU.world_to_grid(Vector2(32, 16)), Vector2i(1, 0), "screen(32,16)")

func test_world_to_grid_y_axis() -> void:
	assert_vec2i_eq(GU.world_to_grid(Vector2(-32, 16)), Vector2i(0, 1), "screen(-32,16)")

func test_world_to_grid_diagonal() -> void:
	assert_vec2i_eq(GU.world_to_grid(Vector2(0, 32)), Vector2i(1, 1), "screen(0,32)")

func test_world_to_grid_negative_coords() -> void:
	# screen(-32, -16) should be grid(-1, 0)
	assert_vec2i_eq(GU.world_to_grid(Vector2(-32, -16)), Vector2i(-1, 0), "screen(-32,-16)")
	# screen(32, -16) should be grid(0, -1)
	assert_vec2i_eq(GU.world_to_grid(Vector2(32, -16)), Vector2i(0, -1), "screen(32,-16)")

func test_world_to_grid_near_tile_edges() -> void:
	# Points nudged slightly from tile centers should remain in the same tile.
	# Tile (1,0) center is (32, 16). Small nudge stays in tile.
	assert_vec2i_eq(GU.world_to_grid(Vector2(32.5, 16.5)), Vector2i(1, 0), "near center of (1,0)")
	# Tile (0,0) center is (0,0). Small positive nudge stays in tile.
	assert_vec2i_eq(GU.world_to_grid(Vector2(0.5, 0.5)), Vector2i(0, 0), "near center of (0,0)")
	# Tile (1,1) center is (0, 32). Small nudge stays in tile.
	assert_vec2i_eq(GU.world_to_grid(Vector2(0.5, 32.5)), Vector2i(1, 1), "near center of (1,1)")

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
		assert_vec2i_eq(back, grid_pos, "roundtrip %s -> %s -> %s" % [str(grid_pos), str(world_pos), str(back)])

# ---------------------------------------------------------------
# 4. grid_offset
# ---------------------------------------------------------------

func test_grid_offset_right_edge() -> void:
	# grid_offset((0,0), Vector2(1,0), 0.5) = center + (32,16)*0.5 = (16, 8)
	var result := GU.grid_offset(Vector2i(0, 0), Vector2(1, 0), 0.5)
	assert_vec2_eq(result, Vector2(16, 8), "right edge of (0,0)")

func test_grid_offset_bottom_left_edge() -> void:
	# grid_offset((0,0), Vector2(0,1), 0.5) = center + (-32,16)*0.5 = (-16, 8)
	var result := GU.grid_offset(Vector2i(0, 0), Vector2(0, 1), 0.5)
	assert_vec2_eq(result, Vector2(-16, 8), "bottom-left edge of (0,0)")

func test_grid_offset_zero_fraction() -> void:
	# fraction=0 should return the tile center
	var result := GU.grid_offset(Vector2i(3, 2), Vector2(1, 0), 0.0)
	assert_vec2_eq(result, GU.grid_to_center(Vector2i(3, 2)), "fraction 0 = center")

func test_grid_offset_full_fraction() -> void:
	# fraction=1.0 along (1,0) from (0,0) should reach center of (1,0)
	var result := GU.grid_offset(Vector2i(0, 0), Vector2(1, 0), 1.0)
	assert_vec2_eq(result, GU.grid_to_center(Vector2i(1, 0)), "fraction 1.0 = next center")

func test_grid_offset_non_origin() -> void:
	# grid_offset from tile (2,3) along (0,1) at 0.5
	var center := GU.grid_to_center(Vector2i(2, 3))
	var result := GU.grid_offset(Vector2i(2, 3), Vector2(0, 1), 0.5)
	assert_vec2_eq(result, center + Vector2(-16, 8), "offset from (2,3) along y")

# ---------------------------------------------------------------
# 5. map_world_size
# ---------------------------------------------------------------

func test_map_world_size_128() -> void:
	# 128 tiles: 128*64 = 8192 wide, 128*32 = 4096 tall
	assert_vec2_eq(GU.map_world_size(128), Vector2(8192, 4096), "128-tile map")

func test_map_world_size_1() -> void:
	# Single tile: 64 x 32
	assert_vec2_eq(GU.map_world_size(1), Vector2(64, 32), "1-tile map")

func test_map_world_size_16() -> void:
	assert_vec2_eq(GU.map_world_size(16), Vector2(1024, 512), "16-tile map")

# ---------------------------------------------------------------
# 6. map_origin
# ---------------------------------------------------------------

func test_map_origin_128() -> void:
	# Leftmost point: -(128-1)*32 = -4064, y=0
	assert_vec2_eq(GU.map_origin(128), Vector2(-4064, 0), "128-tile origin")

func test_map_origin_1() -> void:
	# Single tile: origin is (0, 0) since -(1-1)*32 = 0
	assert_vec2_eq(GU.map_origin(1), Vector2(0, 0), "1-tile origin")

func test_map_origin_16() -> void:
	# -(16-1)*32 = -480
	assert_vec2_eq(GU.map_origin(16), Vector2(-480, 0), "16-tile origin")

# ---------------------------------------------------------------
# Bonus: grid_dir_to_screen / tile_size_vec
# ---------------------------------------------------------------

func test_tile_size_vec() -> void:
	assert_vec2_eq(GU.tile_size_vec(), Vector2(64, 32), "tile size")

func test_grid_dir_to_screen_right() -> void:
	# grid dir (1,0) -> screen (32, 16) normalized
	var expected := Vector2(32, 16).normalized()
	assert_vec2_eq(GU.grid_dir_to_screen(Vector2(1, 0)), expected, "dir right")

func test_grid_dir_to_screen_down() -> void:
	# grid dir (0,1) -> screen (-32, 16) normalized
	var expected := Vector2(-32, 16).normalized()
	assert_vec2_eq(GU.grid_dir_to_screen(Vector2(0, 1)), expected, "dir down")
