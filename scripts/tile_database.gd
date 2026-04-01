class_name TileDatabase

## Single source of truth for all tile type constants, deposit/wall mappings, and colors.
## Referenced by game_world.gd and world_generator.gd to avoid duplication.

# Tile source IDs
const TILE_GROUND := 0
const TILE_IRON := 1
const TILE_COPPER := 2
const TILE_COAL := 3
const TILE_WALL := 4
const TILE_GROUND_DARK := 5
const TILE_GROUND_LIGHT := 6
const TILE_STONE := 7
const TILE_TIN := 8
const TILE_GOLD := 9
const TILE_QUARTZ := 10
const TILE_SULFUR := 11
const TILE_OIL := 12
const TILE_CRYSTAL := 13
const TILE_URANIUM := 14
const TILE_BIOMASS := 15
const TILE_ASH := 16

# Map from deposit tile ID to the item it produces
const DEPOSIT_ITEMS := {
	TILE_IRON: &"iron_ore",
	TILE_COPPER: &"copper_ore",
	TILE_COAL: &"coal",
	TILE_TIN: &"tin_ore",
	TILE_GOLD: &"gold_ore",
	TILE_QUARTZ: &"quartz",
	TILE_SULFUR: &"sulfur",
	TILE_OIL: &"oil",
	TILE_CRYSTAL: &"crystal",
	TILE_URANIUM: &"uranium_ore",
	TILE_BIOMASS: &"biomass",
}

# Deposit colors for tile rendering
const DEPOSIT_COLORS := {
	TILE_IRON: Color(0.45, 0.42, 0.44),     # dark gray — iron deposit
	TILE_COPPER: Color(0.72, 0.45, 0.2),    # orange-brown — copper deposit
	TILE_COAL: Color(0.18, 0.18, 0.2),      # near-black — coal seam
	TILE_TIN: Color(0.60, 0.62, 0.65),      # silvery-blue — tin
	TILE_GOLD: Color(0.78, 0.68, 0.20),     # golden yellow — gold
	TILE_QUARTZ: Color(0.80, 0.75, 0.85),   # pale lavender — quartz
	TILE_SULFUR: Color(0.75, 0.72, 0.15),   # yellow-green — sulfur
	TILE_OIL: Color(0.15, 0.12, 0.10),      # dark brown-black — oil seep
	TILE_CRYSTAL: Color(0.70, 0.40, 0.85),  # purple — crystal deposit
	TILE_URANIUM: Color(0.30, 0.75, 0.30),  # green glow — uranium deposit
	TILE_BIOMASS: Color(0.40, 0.65, 0.20),  # organic green — biomass grove
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

# Map from wall tile ID to the item a borer can extract
const WALL_ITEMS := {
	TILE_STONE: &"stone",
}
