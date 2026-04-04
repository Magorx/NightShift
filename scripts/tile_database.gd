class_name TileDatabase

## Single source of truth for all tile type constants, deposit/wall mappings, and colors.
## Referenced by game_world.gd and world_generator.gd to avoid duplication.

# Tile source IDs
const TILE_GROUND := 0
const TILE_PYROMITE := 1
const TILE_CRYSTALLINE := 2
const TILE_BIOVINE := 3
const TILE_WALL := 4
const TILE_GROUND_DARK := 5
const TILE_GROUND_LIGHT := 6
const TILE_STONE := 7
const TILE_ASH := 8

# Map from deposit tile ID to the item it produces
const DEPOSIT_ITEMS := {
	TILE_PYROMITE: &"pyromite",
	TILE_CRYSTALLINE: &"crystalline",
	TILE_BIOVINE: &"biovine",
}

# Deposit colors for tile rendering
const DEPOSIT_COLORS := {
	TILE_PYROMITE: Color(0.85, 0.30, 0.10),     # fiery orange-red
	TILE_CRYSTALLINE: Color(0.30, 0.65, 0.90),   # icy blue
	TILE_BIOVINE: Color(0.25, 0.75, 0.25),       # organic green
}

# Wall colors (impassable terrain)
const WALL_COLORS := {
	TILE_WALL: Color(0.42, 0.32, 0.22),     # brown — mud wall
	TILE_STONE: Color(0.55, 0.54, 0.50),    # gray-beige — stone wall
}

# Wall display names
const WALL_NAMES := {
	TILE_WALL: "Mud Wall",
	TILE_STONE: "Stone Wall",
}

# Map from wall tile ID to the item a borer can extract (none for Night Shift M1)
const WALL_ITEMS := {}
