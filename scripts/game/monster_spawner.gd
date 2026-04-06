extends Node

## Spawns monsters via SpawnArea zones during the fight phase.
## Creates spawn areas in a ring around the factory, distributes budget,
## assigns logic (OneByOne or AllTogether) and monster pools.

signal all_monsters_dead()
signal monsters_spawning_done()

# ── Tuning ──────────────────────────────────────────────────────────────────
const SPAWN_RING_MIN := 14   # min tiles from factory center
const SPAWN_RING_MAX := 20   # max tiles from factory center
const SQUARE_SIZE := 5       # edge length for square spawn areas
const LINE_LENGTH := 8       # cell count for line spawn areas
const MIN_AREAS := 2
const MAX_AREAS := 6

# ── Monster pool ────────────────────────────────────────────────────────────
# Each entry is a GDScript class that extends MonsterBase.
# SpawnArea instantiates them with .new().
var _monster_types: Array[GDScript] = [
	preload("res://monsters/tendril_crawler/tendril_crawler.gd"),
]

# ── State ───────────────────────────────────────────────────────────────────
var pathfinding: MonsterPathfinding
var alive_monsters: Array[MonsterBase] = []
var _monster_layer: Node3D
var _spawn_areas: Array[SpawnArea] = []
var _fight_active: bool = false

func _ready() -> void:
	pathfinding = MonsterPathfinding.new()
	set_physics_process(false)
	RoundManager.phase_changed.connect(_on_phase_changed)

func setup(monster_layer: Node3D) -> void:
	_monster_layer = monster_layer

func _on_phase_changed(phase: StringName) -> void:
	match phase:
		&"fight":
			_start_fight()
		&"build":
			_end_fight()

# ── Fight lifecycle ─────────────────────────────────────────────────────────

func _start_fight() -> void:
	pathfinding.rebuild()
	_fight_active = true

	var round_num := RoundManager.current_round
	var total_budget := _calculate_budget(round_num)
	var area_count := clampi(MIN_AREAS + round_num / 2, MIN_AREAS, MAX_AREAS)
	var fight_duration := RoundManager.get_phase_duration()

	print("[SPAWNER] Round %d: budget=%d, areas=%d, duration=%.0fs" % [round_num, total_budget, area_count, fight_duration])

	# Distribute budget across areas (roughly even, remainder to last)
	var budgets: Array[int] = []
	@warning_ignore("integer_division")
	var per_area := total_budget / area_count
	for i in area_count:
		budgets.append(per_area)
	budgets[-1] += total_budget - per_area * area_count

	# Create spawn areas
	var center := _get_factory_center()
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for i in area_count:
		var area := _create_spawn_area(i, area_count, center, budgets[i], fight_duration, rng)
		if area:
			_spawn_areas.append(area)
			add_child(area)

	set_physics_process(true)

func _end_fight() -> void:
	_fight_active = false
	set_physics_process(false)
	# Clean up spawn areas
	for area in _spawn_areas:
		if is_instance_valid(area):
			area.cleanup()
	_spawn_areas.clear()
	_despawn_remaining()

func _calculate_budget(round_num: int) -> int:
	# 10 * round + 2 * round^1.5
	return roundi(10.0 * round_num + 2.0 * pow(float(round_num), 1.5))

# ── Area creation ───────────────────────────────────────────────────────────

func _create_spawn_area(index: int, total: int, center: Vector2i, budget_pts: int, fight_dur: float, rng: RandomNumberGenerator) -> SpawnArea:
	# Distribute areas evenly around the ring
	var base_angle := TAU * float(index) / float(total)
	var angle := base_angle + rng.randf_range(-0.3, 0.3)
	var dist := rng.randf_range(SPAWN_RING_MIN, SPAWN_RING_MAX)
	var offset := Vector2(cos(angle), sin(angle)) * dist
	var area_center := Vector2i(center.x + roundi(offset.x), center.y + roundi(offset.y))

	# Clamp to map bounds
	area_center = area_center.clamp(
		Vector2i(SQUARE_SIZE, SQUARE_SIZE),
		Vector2i(MapManager.map_size - SQUARE_SIZE - 1, MapManager.map_size - SQUARE_SIZE - 1)
	)

	# Alternate shapes: even = square, odd = line
	var shape: SpawnArea.Shape
	var cells: Array[Vector2i]
	if index % 2 == 0:
		shape = SpawnArea.Shape.SQUARE
		cells = _make_square_cells(area_center)
	else:
		shape = SpawnArea.Shape.LINE
		cells = _make_line_cells(area_center, center)

	# Filter out wall/building cells
	var valid_cells: Array[Vector2i] = []
	for c in cells:
		if not MapManager.walls.has(c) and BuildingRegistry.get_building_at(c) == null:
			valid_cells.append(c)
	if valid_cells.is_empty():
		return null

	# Create area
	var area := SpawnArea.new()
	area.name = "SpawnArea_%d" % index
	area.shape = shape
	area.cells = valid_cells
	area.budget = budget_pts
	area.monster_pool = _monster_types.duplicate()
	area.pathfinding = pathfinding
	area.monster_layer = _monster_layer

	# Assign logic: alternate between OneByOne and AllTogether
	var logic: SpawnLogic
	if index % 2 == 0:
		logic = SpawnLogicOneByOne.new()
	else:
		logic = SpawnLogicAllTogether.new()
	logic.fight_duration = fight_dur
	area.logic = logic

	# Track spawned monsters
	area.monster_spawned.connect(_on_area_monster_spawned)
	area.budget_exhausted.connect(_on_area_budget_exhausted.bind(area))

	print("[SPAWNER]   Area %d: %s at (%d,%d), budget=%d, logic=%s, cells=%d" % [
		index,
		"SQUARE" if shape == SpawnArea.Shape.SQUARE else "LINE",
		area_center.x, area_center.y,
		budget_pts,
		logic.get_class(),
		valid_cells.size()
	])
	return area

func _make_square_cells(center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	@warning_ignore("integer_division")
	var half := SQUARE_SIZE / 2
	for dx in range(-half, half + 1):
		for dy in range(-half, half + 1):
			cells.append(Vector2i(center.x + dx, center.y + dy))
	return cells

func _make_line_cells(center: Vector2i, factory_center: Vector2i) -> Array[Vector2i]:
	# Line runs roughly parallel to the base (perpendicular to the direction toward base)
	var to_base := Vector2(factory_center - center).normalized()
	# Perpendicular direction
	var perp := Vector2(-to_base.y, to_base.x)

	# Snap to nearest cardinal/diagonal
	var best_dir := Vector2i.ZERO
	var best_dot := -INF
	for dir in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
		var d := absf(perp.dot(Vector2(dir).normalized()))
		if d > best_dot:
			best_dot = d
			best_dir = dir

	var cells: Array[Vector2i] = []
	@warning_ignore("integer_division")
	var half := LINE_LENGTH / 2
	for i in range(-half, half):
		cells.append(Vector2i(center.x + best_dir.x * i, center.y + best_dir.y * i))
	return cells

# ── Callbacks ───────────────────────────────────────────────────────────────

func _on_area_monster_spawned(monster: MonsterBase) -> void:
	monster.died.connect(_on_monster_died.bind(monster))
	alive_monsters.append(monster)

func _on_area_budget_exhausted(_area: SpawnArea) -> void:
	# Check if all areas are done
	var all_done := true
	for a in _spawn_areas:
		if is_instance_valid(a) and a.get_budget_remaining() > 0:
			all_done = false
			break
	if all_done:
		monsters_spawning_done.emit()

func _on_monster_died(_monster: MonsterBase) -> void:
	_cleanup_dead()

# ── Physics tick ────────────────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	_cleanup_dead()
	# Check if fight is over (all spawned, all dead)
	if not _fight_active:
		return
	var all_exhausted := true
	for a in _spawn_areas:
		if is_instance_valid(a) and a.get_budget_remaining() > 0:
			all_exhausted = false
			break
	if all_exhausted and alive_monsters.is_empty():
		set_physics_process(false)
		if RoundManager.current_phase == RoundManager.Phase.FIGHT:
			all_monsters_dead.emit()

func _cleanup_dead() -> void:
	var i := alive_monsters.size() - 1
	while i >= 0:
		if not is_instance_valid(alive_monsters[i]) or alive_monsters[i].state == MonsterBase.State.DYING:
			alive_monsters.remove_at(i)
		i -= 1

func _despawn_remaining() -> void:
	var count := alive_monsters.size()
	for monster in alive_monsters.duplicate():
		if is_instance_valid(monster):
			monster.queue_free()
	alive_monsters.clear()
	if count > 0:
		print("[SPAWNER] Despawned %d remaining monsters" % count)

# ── Helpers ─────────────────────────────────────────────────────────────────

func _get_factory_center() -> Vector2i:
	if BuildingRegistry.unique_buildings.is_empty():
		if GameManager.player:
			return GridUtils.world_to_grid(GameManager.player.global_position)
		@warning_ignore("integer_division")
		return Vector2i(MapManager.map_size / 2, MapManager.map_size / 2)

	var sum := Vector2i.ZERO
	var count := 0
	for building in BuildingRegistry.unique_buildings:
		if is_instance_valid(building):
			sum += building.grid_pos
			count += 1
	if count == 0:
		@warning_ignore("integer_division")
		return Vector2i(MapManager.map_size / 2, MapManager.map_size / 2)
	@warning_ignore("integer_division")
	return sum / count

func get_alive_count() -> int:
	_cleanup_dead()
	return alive_monsters.size()
