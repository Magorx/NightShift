extends Node

## Manages world terrain data, resource deposits, and walls.
## Extracted from GameManager to separate map/environment concerns.

# Terrain visual data (for MultiMesh rendering and save/load)
var terrain_tile_types: PackedByteArray  # flat row-major, one byte per cell
var terrain_variants: PackedByteArray    # low nibble = fg variant, high nibble = misc variant
var terrain_heights: PackedFloat32Array  # elevation per cell (row-major, world units)
var terrain_visual_manager  # TerrainVisualManager (set by game_world)

# World generation seed (saved/loaded for reproducibility)
var world_seed: int = 0

# Map size in tiles per side (default 128, stress test uses 640)
var map_size: int = 128

# Deposits: grid_pos -> item_id (what resource this deposit produces)
var deposits: Dictionary = {}

# Deposit stocks: grid_pos -> int (-1 = infinite, >0 = remaining units)
var deposit_stocks: Dictionary = {}

# Walls: grid_pos -> tile_id (impassable terrain, blocks building placement)
var walls: Dictionary = {}

# Cluster drain manager for finite-stock deposits (lazy-initialized)
var cluster_drain_manager

func get_terrain_height(grid_pos: Vector2i) -> float:
	if terrain_heights.is_empty():
		return 0.0
	var idx := grid_pos.y * map_size + grid_pos.x
	if idx < 0 or idx >= terrain_heights.size():
		return 0.0
	return terrain_heights[idx]

func get_deposit_at(grid_pos: Vector2i):
	return deposits.get(grid_pos)

## Get the remaining stock for a deposit (-1 = infinite, 0 = depleted).
func get_deposit_stock(pos: Vector2i) -> int:
	return deposit_stocks.get(pos, -1)

## Drain one unit of deposit stock. Returns true if item was available.
## When stock reaches 0, converts tile to ash.
func drain_deposit_stock(pos: Vector2i) -> bool:
	if not deposits.has(pos):
		return false  # not a deposit (ash, ground, etc.)
	var stock: int = deposit_stocks.get(pos, -1)
	if stock == -1:
		return true  # infinite
	if stock <= 0:
		return false  # already depleted
	stock -= 1
	if stock <= 0:
		convert_tile_to_ash(pos)
		return true
	deposit_stocks[pos] = stock
	return true

## Convert a deposit tile to ash (depleted biomass).
func convert_tile_to_ash(pos: Vector2i) -> void:
	deposits.erase(pos)
	deposit_stocks.erase(pos)
	# Update terrain tile type array
	var idx := pos.y * map_size + pos.x
	if idx >= 0 and idx < terrain_tile_types.size():
		terrain_tile_types[idx] = TileDatabase.TILE_ASH
	# Update terrain visual
	if terrain_visual_manager:
		terrain_visual_manager.update_cell(map_size, pos.x, pos.y, TileDatabase.TILE_ASH, 0, 0)
	# Invalidate BFS cache
	if cluster_drain_manager:
		cluster_drain_manager.invalidate_cache()

func clear() -> void:
	deposits.clear()
	deposit_stocks.clear()
	walls.clear()
	terrain_tile_types = PackedByteArray()
	terrain_variants = PackedByteArray()
	terrain_heights = PackedFloat32Array()
	if terrain_visual_manager:
		terrain_visual_manager.clear()
