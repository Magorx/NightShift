extends Node

## Spawns monsters at map edges during the fight phase.
## Connects to RoundManager for phase transitions.
## Manages alive monster count and signals when all dead.

signal all_monsters_dead()
signal monsters_spawning_done()

# ── Wave tuning ─────────────────────────────────────────────────────────────
const BASE_MONSTER_COUNT := 5
const MONSTERS_PER_ROUND := 3
const SPAWN_INTERVAL := 2.0  # seconds between spawns

# ── State ───────────────────────────────────────────────────────────────────
var pathfinding: MonsterPathfinding
var alive_monsters: Array[MonsterBase] = []
var _spawn_timer: float = 0.0
var _spawn_queue: int = 0
var _is_spawning: bool = false
var _monster_layer: Node3D

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

func _start_fight() -> void:
	pathfinding.rebuild()
	var count := BASE_MONSTER_COUNT + MONSTERS_PER_ROUND * (RoundManager.current_round - 1)
	_spawn_queue = count
	_spawn_timer = 0.0
	_is_spawning = true
	set_physics_process(true)
	print("[SPAWNER] Fight round %d: spawning %d monsters" % [RoundManager.current_round, count])

func _end_fight() -> void:
	_is_spawning = false
	_spawn_queue = 0
	set_physics_process(false)
	_despawn_remaining()

func _despawn_remaining() -> void:
	var count := alive_monsters.size()
	for monster in alive_monsters.duplicate():
		if is_instance_valid(monster):
			monster.queue_free()
	alive_monsters.clear()
	if count > 0:
		print("[SPAWNER] Despawned %d remaining monsters" % count)

func _physics_process(delta: float) -> void:
	# Spawn monsters on interval
	if _is_spawning and _spawn_queue > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = SPAWN_INTERVAL
			_spawn_one()
			_spawn_queue -= 1
			if _spawn_queue <= 0:
				_is_spawning = false
				monsters_spawning_done.emit()

	# Check for all dead
	_cleanup_dead()
	if not _is_spawning and _spawn_queue <= 0 and alive_monsters.is_empty():
		set_physics_process(false)
		if RoundManager.current_phase == RoundManager.Phase.FIGHT:
			all_monsters_dead.emit()

func _cleanup_dead() -> void:
	var i := alive_monsters.size() - 1
	while i >= 0:
		if not is_instance_valid(alive_monsters[i]) or alive_monsters[i].state == MonsterBase.State.DYING:
			alive_monsters.remove_at(i)
		i -= 1

func _spawn_one() -> void:
	var spawn_pos := _pick_edge_position()
	if spawn_pos == Vector2i(-1, -1):
		return

	var monster := TendrilCrawler.new()
	monster.pathfinding = pathfinding
	monster.global_position = GridUtils.grid_to_world(spawn_pos) + Vector3(0.0, 0.1, 0.0)
	monster.died.connect(_on_monster_died.bind(monster))

	if _monster_layer:
		_monster_layer.add_child(monster)
	else:
		add_child(monster)

	alive_monsters.append(monster)

func _on_monster_died(_monster: MonsterBase) -> void:
	_cleanup_dead()

func _pick_edge_position() -> Vector2i:
	var map_size := MapManager.map_size
	if map_size <= 4:
		return Vector2i(-1, -1)

	# Try random edge positions, avoiding walls
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	for _attempt in 20:
		var pos := Vector2i.ZERO
		var edge := rng.randi() % 4
		match edge:
			0:  # top edge
				pos = Vector2i(rng.randi_range(1, map_size - 2), 1)
			1:  # bottom edge
				pos = Vector2i(rng.randi_range(1, map_size - 2), map_size - 2)
			2:  # left edge
				pos = Vector2i(1, rng.randi_range(1, map_size - 2))
			3:  # right edge
				pos = Vector2i(map_size - 2, rng.randi_range(1, map_size - 2))

		if not MapManager.walls.has(pos) and BuildingRegistry.get_building_at(pos) == null:
			return pos

	return Vector2i(1, 1)  # fallback

func get_alive_count() -> int:
	_cleanup_dead()
	return alive_monsters.size()
