class_name WorldGenerator
extends RefCounted
## Procedural world generation using noise-based terrain.
##
## Generates:
## - Rock walls (impassable) from layered simplex + cellular noise
## - Organic resource deposits in varied shapes (veins, blobs, crescents, clusters)
## - Ground tile variation for visual interest
## - Border walls around the map edge
## - Clear spawn area with starter resources nearby
## - Connectivity guarantee: all deposits reachable from spawn

# Tile source IDs (must match game_world.gd)
const TILE_GROUND := 0
const TILE_IRON := 1
const TILE_COPPER := 2
const TILE_COAL := 3
const TILE_WALL := 4
const TILE_GROUND_DARK := 5
const TILE_GROUND_LIGHT := 6
# New deposit tile IDs — requires matching constants, DEPOSIT_COLORS entries,
# DEPOSIT_ITEMS entries, and _create_tile_source calls in game_world.gd:
#   TILE_STONE   = 7  -> Color(0.55, 0.54, 0.50)  gray-beige stone
#   TILE_TIN     = 8  -> Color(0.60, 0.62, 0.65)  silvery-blue tin
#   TILE_GOLD    = 9  -> Color(0.78, 0.68, 0.20)  golden yellow
#   TILE_QUARTZ  = 10 -> Color(0.80, 0.75, 0.85)  pale lavender quartz
#   TILE_SULFUR  = 11 -> Color(0.75, 0.72, 0.15)  yellow-green sulfur
const TILE_STONE := 7
const TILE_TIN := 8
const TILE_GOLD := 9
const TILE_QUARTZ := 10
const TILE_SULFUR := 11

const DEPOSIT_ITEMS := {
	TILE_IRON: &"iron_ore",
	TILE_COPPER: &"copper_ore",
	TILE_COAL: &"coal",
	TILE_STONE: &"stone",
	TILE_TIN: &"tin_ore",
	TILE_GOLD: &"gold_ore",
	TILE_QUARTZ: &"quartz",
	TILE_SULFUR: &"sulfur",
}

# Generation parameters
const BORDER_WIDTH := 2
const SPAWN_CLEAR_RADIUS := 10
const WALL_FREQUENCY := 0.065
const WALL_THRESHOLD := 0.32
const DEPOSIT_MIN_SPACING := 6.0

var _rng: RandomNumberGenerator
var _seed: int


func generate(tile_map: TileMapLayer, map_size: int, world_seed: int) -> void:
	_seed = world_seed
	_rng = RandomNumberGenerator.new()
	_rng.seed = world_seed

	var spawn := Vector2i(map_size / 2, map_size / 2)

	# Step 1: Generate wall positions
	var walls: Dictionary = {}
	_generate_walls(walls, map_size, spawn)

	# Step 2: Generate deposit positions
	var deposits: Dictionary = {}  # Vector2i -> tile_id (int)
	_generate_all_deposits(deposits, walls, map_size, spawn)

	# Step 3: Ensure all deposits are reachable from spawn
	_ensure_connectivity(walls, deposits, map_size, spawn)

	# Step 4: Generate ground tile variation
	var ground_variant: Dictionary = {}  # Vector2i -> 0 or 1 (variant index)
	_generate_ground_variation(ground_variant, map_size)

	# Step 5: Apply to tilemap and register with GameManager
	_apply(tile_map, map_size, walls, deposits, ground_variant)


# ── Wall Generation ─────────────────────────────────────────────────────────

func _generate_walls(walls: Dictionary, map_size: int, spawn: Vector2i) -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = _seed
	noise.frequency = WALL_FREQUENCY
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5

	# Secondary noise for more interesting ridge-like shapes
	var noise2 := FastNoiseLite.new()
	noise2.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise2.seed = _seed + 100
	noise2.frequency = 0.09
	noise2.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise2.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	for x in range(map_size):
		for y in range(map_size):
			# Border walls
			if x < BORDER_WIDTH or y < BORDER_WIDTH or x >= map_size - BORDER_WIDTH or y >= map_size - BORDER_WIDTH:
				walls[Vector2i(x, y)] = true
				continue

			# Spawn area is always clear
			var dist_to_spawn := Vector2(x - spawn.x, y - spawn.y).length()
			if dist_to_spawn < SPAWN_CLEAR_RADIUS:
				continue

			# Combine two noise layers for interesting wall shapes
			var n1: float = noise.get_noise_2d(x, y)
			var n2: float = noise2.get_noise_2d(x, y)
			var combined: float = n1 * 0.7 + n2 * 0.3

			if combined > WALL_THRESHOLD:
				walls[Vector2i(x, y)] = true


# ── Deposit Generation ──────────────────────────────────────────────────────

func _generate_all_deposits(deposits: Dictionary, walls: Dictionary, map_size: int, spawn: Vector2i) -> void:
	# Deposit plan: [tile_id, min_dist, max_dist, count, size_min, size_max]
	var plan := [
		# Starter deposits — close to spawn, small
		[TILE_IRON, 6, 14, 2, 3, 5],
		[TILE_COPPER, 8, 16, 1, 3, 4],
		[TILE_STONE, 6, 14, 2, 3, 5],       # common, close (like iron)
		# Mid-range deposits
		[TILE_IRON, 16, 26, 2, 5, 8],
		[TILE_COPPER, 16, 26, 2, 4, 7],
		[TILE_COAL, 14, 24, 2, 4, 6],
		[TILE_STONE, 16, 24, 2, 5, 7],      # common, mid-range
		[TILE_TIN, 16, 26, 2, 4, 6],        # medium rarity, mid-range
		[TILE_QUARTZ, 18, 28, 1, 3, 6],     # medium rarity, mid-range
		# Far deposits — large and rich
		[TILE_IRON, 22, 30, 1, 7, 10],
		[TILE_COPPER, 22, 30, 1, 6, 9],
		[TILE_COAL, 20, 28, 1, 5, 8],
		[TILE_STONE, 22, 30, 1, 6, 9],      # common, far — large deposit
		[TILE_TIN, 22, 30, 1, 5, 8],        # medium rarity, far
		[TILE_QUARTZ, 24, 32, 1, 4, 7],     # medium rarity, far
		[TILE_GOLD, 26, 34, 1, 3, 5],       # rare, far from spawn
		[TILE_SULFUR, 26, 34, 1, 3, 5],     # rare, far from spawn
	]

	var placed_centers: Array[Vector2i] = []

	for entry in plan:
		var tile_id: int = entry[0]
		var min_dist: float = entry[1]
		var max_dist: float = entry[2]
		var count: int = entry[3]
		var size_min: int = entry[4]
		var size_max: int = entry[5]

		for _i in range(count):
			var center := _find_deposit_center(map_size, spawn, min_dist, max_dist, walls, placed_centers)
			if center == Vector2i(-1, -1):
				continue
			placed_centers.append(center)
			var size: int = _rng.randi_range(size_min, size_max)
			_carve_deposit(deposits, walls, center, size, tile_id, map_size)


func _find_deposit_center(map_size: int, spawn: Vector2i, min_dist: float, max_dist: float, walls: Dictionary, existing: Array[Vector2i]) -> Vector2i:
	for _attempt in range(80):
		var angle := _rng.randf() * TAU
		var dist := _rng.randf_range(min_dist, max_dist)
		var cx := int(spawn.x + cos(angle) * dist)
		var cy := int(spawn.y + sin(angle) * dist)
		var pos := Vector2i(cx, cy)

		# Check bounds (keep away from borders)
		if cx < BORDER_WIDTH + 2 or cy < BORDER_WIDTH + 2 or cx >= map_size - BORDER_WIDTH - 2 or cy >= map_size - BORDER_WIDTH - 2:
			continue

		# Skip if in a wall
		if walls.has(pos):
			continue

		# Minimum spacing from other deposit centers
		var too_close := false
		for other in existing:
			if Vector2(pos - other).length() < DEPOSIT_MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue

		return pos

	return Vector2i(-1, -1)


func _carve_deposit(deposits: Dictionary, walls: Dictionary, center: Vector2i, size: int, tile_id: int, map_size: int) -> void:
	var shape_type: int = _rng.randi_range(0, 3)
	match shape_type:
		0: _deposit_vein(deposits, walls, center, size, tile_id, map_size)
		1: _deposit_blob(deposits, walls, center, size, tile_id, map_size)
		2: _deposit_crescent(deposits, walls, center, size, tile_id, map_size)
		3: _deposit_cluster(deposits, walls, center, size, tile_id, map_size)


## Elongated vein along a random direction.
func _deposit_vein(deposits: Dictionary, walls: Dictionary, center: Vector2i, size: int, tile_id: int, map_size: int) -> void:
	var angle := _rng.randf() * PI
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var length: float = size * 1.5
	var width: float = maxf(size * 0.4, 1.5)

	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.frequency = 0.2

	var scan := size + 3
	for dx in range(-scan, scan + 1):
		for dy in range(-scan, scan + 1):
			var pos := center + Vector2i(dx, dy)
			if _out_of_bounds(pos, map_size) or walls.has(pos):
				continue
			var offset := Vector2(dx, dy)
			var along: float = absf(offset.dot(dir))
			var across: float = absf(offset.dot(perp))
			var dist: float = (along / length) * (along / length) + (across / width) * (across / width)
			var noise_val: float = noise.get_noise_2d(pos.x, pos.y) * 0.3
			if dist + noise_val < 0.6:
				deposits[pos] = tile_id


## Irregular noise-shaped blob.
func _deposit_blob(deposits: Dictionary, walls: Dictionary, center: Vector2i, size: int, tile_id: int, map_size: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.frequency = 0.15
	noise.fractal_octaves = 2

	var radius: float = size * 0.7

	var scan := size + 2
	for dx in range(-scan, scan + 1):
		for dy in range(-scan, scan + 1):
			var pos := center + Vector2i(dx, dy)
			if _out_of_bounds(pos, map_size) or walls.has(pos):
				continue
			var dist: float = Vector2(dx, dy).length()
			var noise_val: float = noise.get_noise_2d(pos.x * 3, pos.y * 3) * radius * 0.5
			if dist < radius + noise_val:
				deposits[pos] = tile_id


## Arc/crescent shape — a circle with a chunk removed.
func _deposit_crescent(deposits: Dictionary, walls: Dictionary, center: Vector2i, size: int, tile_id: int, map_size: int) -> void:
	var radius: float = size * 0.8
	var offset_angle := _rng.randf() * TAU
	var offset_dist: float = radius * 0.6
	var hole_center := Vector2(cos(offset_angle) * offset_dist, sin(offset_angle) * offset_dist)
	var hole_radius: float = radius * 0.7

	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.frequency = 0.18

	var scan := size + 2
	for dx in range(-scan, scan + 1):
		for dy in range(-scan, scan + 1):
			var pos := center + Vector2i(dx, dy)
			if _out_of_bounds(pos, map_size) or walls.has(pos):
				continue
			var v := Vector2(dx, dy)
			var dist: float = v.length()
			var hole_dist: float = (v - hole_center).length()
			var noise_val: float = noise.get_noise_2d(pos.x, pos.y) * 1.5
			if dist < radius + noise_val and hole_dist > hole_radius:
				deposits[pos] = tile_id


## Multiple small patches near each other.
func _deposit_cluster(deposits: Dictionary, walls: Dictionary, center: Vector2i, size: int, tile_id: int, map_size: int) -> void:
	var num_patches: int = _rng.randi_range(3, 5)
	var sub_radius: float = size * 0.35

	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.frequency = 0.2

	for _p in range(num_patches):
		var offset := Vector2(_rng.randf_range(-size * 0.6, size * 0.6), _rng.randf_range(-size * 0.6, size * 0.6))
		var patch_center := center + Vector2i(int(offset.x), int(offset.y))
		var scan := int(sub_radius) + 2
		for dx in range(-scan, scan + 1):
			for dy in range(-scan, scan + 1):
				var pos := patch_center + Vector2i(dx, dy)
				if _out_of_bounds(pos, map_size) or walls.has(pos):
					continue
				var dist: float = Vector2(dx, dy).length()
				var noise_val: float = noise.get_noise_2d(pos.x * 2, pos.y * 2) * sub_radius * 0.3
				if dist < sub_radius + noise_val:
					deposits[pos] = tile_id


# ── Ground Variation ────────────────────────────────────────────────────────

func _generate_ground_variation(ground_variant: Dictionary, map_size: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = _seed + 500
	noise.frequency = 0.08
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	for x in range(map_size):
		for y in range(map_size):
			var val: float = noise.get_noise_2d(x, y)
			if val > 0.2:
				ground_variant[Vector2i(x, y)] = 1  # dark variant
			elif val < -0.2:
				ground_variant[Vector2i(x, y)] = 2  # light variant


# ── Connectivity ────────────────────────────────────────────────────────────

func _ensure_connectivity(walls: Dictionary, deposits: Dictionary, map_size: int, spawn: Vector2i) -> void:
	# BFS from spawn to find reachable area
	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = [spawn]
	reachable[spawn] = true

	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for dir: Vector2i in dirs:
			var next: Vector2i = pos + dir
			if reachable.has(next):
				continue
			if next.x < 0 or next.y < 0 or next.x >= map_size or next.y >= map_size:
				continue
			if walls.has(next):
				continue
			reachable[next] = true
			queue.append(next)

	# Find unreachable deposit cells and carve paths to them
	var unreachable_targets: Array[Vector2i] = []
	var seen: Dictionary = {}
	for pos in deposits:
		if reachable.has(pos):
			continue
		# Only process one representative per cluster (avoid carving duplicate paths)
		var dominated := false
		for existing in unreachable_targets:
			if Vector2(pos - existing).length() < 8:
				dominated = true
				break
		if dominated:
			continue
		unreachable_targets.append(pos)

	for target in unreachable_targets:
		_carve_path_to_reachable(walls, target, map_size, reachable)


func _carve_path_to_reachable(walls: Dictionary, target: Vector2i, map_size: int, reachable: Dictionary) -> void:
	# BFS from target to find nearest reachable cell
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [target]
	visited[target] = true
	var nearest := Vector2i(-1, -1)

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		if reachable.has(pos) and pos != target:
			nearest = pos
			break
		var bfs_dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
		for dir: Vector2i in bfs_dirs:
			var next: Vector2i = pos + dir
			if visited.has(next):
				continue
			if next.x < 1 or next.y < 1 or next.x >= map_size - 1 or next.y >= map_size - 1:
				continue
			visited[next] = true
			parent[next] = pos
			queue.append(next)

	if nearest == Vector2i(-1, -1):
		return

	# Carve path using Bresenham line from target to nearest (width 2)
	_carve_line(walls, target, nearest, reachable)


func _carve_line(walls: Dictionary, from: Vector2i, to: Vector2i, reachable: Dictionary) -> void:
	var dx := absi(to.x - from.x)
	var dy := -absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err := dx + dy
	var current := from

	while true:
		# Carve a 3-wide corridor
		for ox in range(-1, 2):
			for oy in range(-1, 2):
				var p := current + Vector2i(ox, oy)
				walls.erase(p)
				reachable[p] = true

		if current == to:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			current.x += sx
		if e2 <= dx:
			err += dx
			current.y += sy


# ── Apply to World ──────────────────────────────────────────────────────────

func _apply(tile_map: TileMapLayer, map_size: int, walls: Dictionary, deposits: Dictionary, ground_variant: Dictionary) -> void:
	for x in range(map_size):
		for y in range(map_size):
			var pos := Vector2i(x, y)
			if walls.has(pos):
				tile_map.set_cell(pos, TILE_WALL, Vector2i(0, 0))
				GameManager.walls[pos] = true
			elif deposits.has(pos):
				var tile_id: int = deposits[pos]
				tile_map.set_cell(pos, tile_id, Vector2i(0, 0))
				GameManager.deposits[pos] = DEPOSIT_ITEMS[tile_id]
			elif ground_variant.has(pos):
				var variant: int = ground_variant[pos]
				if variant == 1:
					tile_map.set_cell(pos, TILE_GROUND_DARK, Vector2i(0, 0))
				else:
					tile_map.set_cell(pos, TILE_GROUND_LIGHT, Vector2i(0, 0))
			else:
				tile_map.set_cell(pos, TILE_GROUND, Vector2i(0, 0))


# ── Helpers ─────────────────────────────────────────────────────────────────

func _out_of_bounds(pos: Vector2i, map_size: int) -> bool:
	return pos.x < BORDER_WIDTH or pos.y < BORDER_WIDTH or pos.x >= map_size - BORDER_WIDTH or pos.y >= map_size - BORDER_WIDTH
