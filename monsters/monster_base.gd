class_name MonsterBase
extends CharacterBody3D

## Base class for all monsters. Handles HP, navigation (flow field), movement, and attack.
## Subclasses override stats and attack behavior.
##
## Navigation:
##   - MOVING: sample the shared factory flow field (Dijkstra outward from all
##     building-adjacent cells). Each monster reads the gradient at its own cell,
##     so the swarm fans out naturally without each monster running A*.
##   - CHASING: sample the shared chase flow field (bounded Dijkstra from the
##     player's current sub-cell, cached and refreshed on cell change / TTL).
##   - Attack targeting: when close to any building, claim an attack slot on it
##     (one of 4 cardinal sides) so monsters spread around instead of piling up.
##
## Collision setup:
##   layer 5 (bit 16) — projectiles detect this via Area3D.body_entered
##   mask: ground (4) + buildings (2) + monsters (16) — walk on ground, blocked
##   by buildings, blocked by other monsters (so they push apart instead of
##   stacking on the same cell)

signal died()

# ── Stats (override in subclass) ────────────────────────────────────────────
var move_speed: float = 2.0
var attack_damage: float = 15.0
var attack_cooldown: float = 1.5
var attack_range: float = 1.2  # world units — close to 1 tile
var max_hp: float = 50.0
var budget_cost: int = 2  # spawn budget points this monster costs

# ── State ───────────────────────────────────────────────────────────────────
enum State { IDLE, MOVING, ATTACKING, CHASING, DYING }
var state: State = State.IDLE

var health: HealthComponent
var pathfinding: MonsterPathfinding

# Pool back-reference. When set, _on_died returns the monster to the pool
# instead of queue_free'ing it. Pool ownership transfers via acquire/release;
# legacy paths (sims, integration tests) leave _pool == null and get the old
# behavior.
var _pool: MonsterPool = null

var _target_building: Node = null
var _assigned_attack_slot: int = -1  # -1 = none, 0..3 = DIRECTION_VECTORS index on target
var _attack_timer: float = 0.0
var _retarget_timer: float = 0.0
var _gravity: float = 20.0

# ── Chase / aggro ───────────────────────────────────────────────────────────
const CHASE_ENGAGE_RADIUS := 5.0    # start chasing player within this (world units ≈ tiles)
const CHASE_DISENGAGE_RADIUS := 8.0 # stop chasing when player exceeds this
const AGGRO_DISENGAGE_RADIUS := 12.0 # disengage radius when hit by player
const AGGRO_DURATION := 3.0          # seconds of aggro after taking player damage
const NEARBY_BUILDING_DAMAGE_RANGE := 1.5  # damage buildings while passing by

# ── Retarget cadence ───────────────────────────────────────────────────────
# We no longer run A* per monster per frame, so repath cadence is much cheaper.
# This timer gates "is there a closer building now?" checks, not flow-field samples.
const RETARGET_INTERVAL := 1.0
# Target acquisition radius — outside this, monsters just follow the global
# factory flow field without claiming a slot on anyone.
const TARGET_CLAIM_RADIUS := 5.0

# ── Flow-field sample throttling ───────────────────────────────────────────
# Sampling the per-sector flow field is cheap (~4 us), but at 64+ monsters
# it still dominates the hot loop. Each monster refreshes its cached
# direction every FLOW_SAMPLE_PERIOD physics ticks, with a random offset so
# the work is evenly spread across frames. Between refreshes the cached
# direction is reused — the flow field is a slowly-varying Dijkstra gradient,
# so a 2-frame delay is invisible in practice.
const FLOW_SAMPLE_PERIOD := 2   # physics ticks between refreshes
var _flow_sample_offset: int = 0
var _cached_flow_dir: Vector2 = Vector2.ZERO
var _last_flow_sample_tick: int = -999

# ── Local separation (toggle in SettingsManager) ───────────────────────────
const SEPARATION_RADIUS := 1.1      # world units — neighbors closer than this push apart
const SEPARATION_WEIGHT := 0.6      # scales the repulsion vector before blending into velocity
const SEPARATION_MAX_NEIGHBORS := 6 # cap to keep per-monster cost bounded

var _aggro_timer: float = 0.0       # >0 = in aggro mode (larger chase radius)
var _chase_attack_timer: float = 0.0 # cooldown for damaging buildings while moving

var _debug_path_mesh: MeshInstance3D
var _debug_immediate_mesh: ImmediateMesh

const MONSTER_COLLISION_LAYER := 16  # bit 5
const MONSTER_COLLISION_MASK := 22   # ground (4) + buildings (2) + monsters (16)

func _ready() -> void:
	add_to_group(&"monsters")
	collision_layer = MONSTER_COLLISION_LAYER
	collision_mask = MONSTER_COLLISION_MASK

	# Stagger retargeting so freshly-spawned groups don't all fire on the same frame
	_retarget_timer = randf() * RETARGET_INTERVAL
	# Stagger flow-field refreshes across the FLOW_SAMPLE_PERIOD window so we
	# don't get a single frame where all 64 monsters sample at once.
	_flow_sample_offset = randi() % FLOW_SAMPLE_PERIOD

	_setup_collision()
	_setup_health()
	_setup_visual()
	_setup_debug_path()

## Reset per-spawn state when a monster is reused from the pool. Visuals,
## collision shapes, health component, and debug nodes were built once in
## _ready and are intentionally NOT recreated here — only the runtime state
## that varies between lives is cleared.
##
## Called by SpawnArea.spawn_monster after acquiring the monster from the pool
## and re-parenting it. The first time a monster is acquired (fresh from
## script.new()) reset_for_spawn is called too — that's safe because _ready
## has already run by then (add_child triggers _ready synchronously).
func reset_for_spawn() -> void:
	state = State.IDLE
	velocity = Vector3.ZERO
	scale = Vector3.ONE
	visible = true
	_target_building = null
	_assigned_attack_slot = -1
	_attack_timer = 0.0
	_retarget_timer = randf() * RETARGET_INTERVAL  # avoid first-frame stampede
	_aggro_timer = 0.0
	_chase_attack_timer = 0.0
	_player_attack_timer = 0.0
	# Stagger the first flow-field sample so newly-spawned batches don't all
	# sample on the same frame. Seeding with (tick - offset) means the first
	# sample will happen (FLOW_SAMPLE_PERIOD - offset) ticks from now.
	_flow_sample_offset = randi() % FLOW_SAMPLE_PERIOD
	_last_flow_sample_tick = Engine.get_physics_frames() - _flow_sample_offset
	_cached_flow_dir = Vector2.ZERO
	if health:
		health.revive()  # back to max_hp
	# Re-enable physics in case prepare_for_pool disabled it
	set_physics_process(true)
	# Make sure we're tracked by the spatial hash and the monsters group
	if not is_in_group(&"monsters"):
		add_to_group(&"monsters")

## Quiet a monster down before returning it to the pool. Stop physics, hide
## visuals, drop attack slot, etc. Called from _on_died right before
## handing back to the pool.
func prepare_for_pool() -> void:
	state = State.IDLE
	velocity = Vector3.ZERO
	visible = false
	set_physics_process(false)
	_release_attack_slot()
	_target_building = null
	# Removing from the monsters group so the spawner / separation grid stop
	# enumerating us. reset_for_spawn re-adds on next acquire.
	if is_in_group(&"monsters"):
		remove_from_group(&"monsters")

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 0.8
	col.shape = capsule
	col.position = Vector3(0.0, 0.4, 0.0)
	add_child(col)
	# Cap the number of slide iterations at 1. Default is 4, which is what
	# causes a single move_and_slide to spend ~200us per character resolving
	# cascading contacts in a dense cluster. For monsters 1 slide is enough
	# — they only need to slide off walls + other monsters, not bounce
	# through corners, and the resulting "slide-through-corner" artifacts
	# are invisible at this scale.
	max_slides = 1
	# Slightly larger safe margin so the capsule never jitters between
	# touching and not-touching a neighbour each tick.
	safe_margin = 0.05
	# Wall-min-slide angle stays at the default so we still slide along
	# floors + ramps at shallow angles.

func _setup_health() -> void:
	health = HealthComponent.new()
	health.name = "HealthComponent"
	health.max_hp = max_hp
	add_child(health)
	health.died.connect(_on_died)
	var hbar := HealthBar3D.new()
	hbar.position = Vector3(0, 1.2, 0)
	hbar.setup(health)
	add_child(hbar)

func _setup_visual() -> void:
	# Override in subclass to load model. Default: colored capsule.
	var mesh_inst := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.3
	capsule_mesh.height = 0.8
	mesh_inst.mesh = capsule_mesh
	mesh_inst.position = Vector3(0.0, 0.4, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.2, 0.3)
	mesh_inst.material_override = mat
	mesh_inst.name = "PlaceholderMesh"
	add_child(mesh_inst)

func _setup_debug_path() -> void:
	_debug_immediate_mesh = ImmediateMesh.new()
	_debug_path_mesh = MeshInstance3D.new()
	_debug_path_mesh.mesh = _debug_immediate_mesh
	_debug_path_mesh.name = "DebugPath"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	_debug_path_mesh.material_override = mat
	# Add to scene root so lines are in world space, not local to monster
	_debug_path_mesh.top_level = true
	add_child(_debug_path_mesh)
	_debug_path_mesh.visible = SettingsManager.debug_mode
	SettingsManager.debug_mode_changed.connect(func(enabled: bool):
		if is_instance_valid(_debug_path_mesh):
			_debug_path_mesh.visible = enabled
	)

func _update_debug_path(desired_dir: Vector2) -> void:
	if not _debug_immediate_mesh or not SettingsManager.debug_mode:
		return
	_debug_immediate_mesh.clear_surfaces()
	if desired_dir.length_squared() < 0.001:
		return
	var line_y := global_position.y + 0.3
	_debug_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	_debug_immediate_mesh.surface_add_vertex(Vector3(global_position.x, line_y, global_position.z))
	_debug_immediate_mesh.surface_add_vertex(Vector3(
		global_position.x + desired_dir.x * 1.5,
		line_y,
		global_position.z + desired_dir.y * 1.5
	))
	_debug_immediate_mesh.surface_end()

func _physics_process(delta: float) -> void:
	if state == State.DYING:
		return
	var _perf_t0: int = Time.get_ticks_usec() if MonsterPerf.enabled else 0
	if MonsterPerf.enabled:
		match state:
			State.ATTACKING: MonsterPerf.frame_attacking_count += 1
			State.MOVING:    MonsterPerf.frame_moving_count += 1
			State.CHASING:   MonsterPerf.frame_chasing_count += 1

	# Gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	# Tick aggro timer
	if _aggro_timer > 0.0:
		_aggro_timer -= delta

	# Check for player chase trigger (from IDLE or MOVING)
	if state == State.IDLE or state == State.MOVING:
		if _should_start_chasing():
			state = State.CHASING

	var desired_dir := Vector2.ZERO

	match state:
		State.IDLE:
			_find_target()
			if _target_building:
				state = State.MOVING
		State.MOVING:
			desired_dir = _process_movement(delta)
			_damage_nearby_buildings(delta)
		State.ATTACKING:
			_process_attack(delta)
		State.CHASING:
			desired_dir = _process_chasing(delta)
			_damage_nearby_buildings(delta)

	# Apply movement (XZ plane) if we have a direction
	if desired_dir.length_squared() > 0.0001:
		if SettingsManager.monster_separation_enabled:
			desired_dir = _apply_separation(desired_dir)
		velocity.x = desired_dir.x * move_speed
		velocity.z = desired_dir.y * move_speed
		# Face the direction of travel
		var facing := Vector3(desired_dir.x, 0.0, desired_dir.y)
		if facing.length_squared() > 0.01:
			look_at(global_position + facing, Vector3.UP)
	elif state != State.ATTACKING:
		velocity.x = 0.0
		velocity.z = 0.0

	# Attacking monsters are stationary by definition (velocity zero, on the
	# ground). Skipping move_and_slide for them shaves the per-monster CharacterBody3D
	# collision-resolution cost — when a swarm is hammering a building, dozens of
	# monsters were running collision queries every tick for no reason.
	# We still call it when not on the floor (e.g. mid-fall) so gravity resolves.
	var _perf_t_slide: int = Time.get_ticks_usec() if MonsterPerf.enabled else 0
	if state != State.ATTACKING or not is_on_floor():
		move_and_slide()
	if MonsterPerf.enabled:
		MonsterPerf.frame_move_slide_usec += Time.get_ticks_usec() - _perf_t_slide
	_update_debug_path(desired_dir)
	if MonsterPerf.enabled:
		MonsterPerf.frame_physics_usec += Time.get_ticks_usec() - _perf_t0

# ── Chase checks ────────────────────────────────────────────────────────────

func _should_start_chasing() -> bool:
	if not GameManager.player or GameManager.player.health.is_dead:
		return false
	var dist := _player_distance()
	return dist <= CHASE_ENGAGE_RADIUS

func _get_disengage_radius() -> float:
	if _aggro_timer > 0.0:
		return AGGRO_DISENGAGE_RADIUS
	return CHASE_DISENGAGE_RADIUS

func _player_distance() -> float:
	if not GameManager.player:
		return INF
	var diff: Vector3 = global_position - GameManager.player.global_position
	diff.y = 0.0
	return diff.length()

# ── Target finding ──────────────────────────────────────────────────────────

func _find_target() -> void:
	var _perf_t0: int = Time.get_ticks_usec() if MonsterPerf.enabled else 0
	var my_grid := GridUtils.world_to_grid(global_position)
	var best_building: Node = null
	var best_dist := INF

	for building in BuildingRegistry.unique_buildings:
		if not is_instance_valid(building):
			continue
		var dist: float = my_grid.distance_squared_to(building.grid_pos)
		if dist < best_dist:
			best_dist = dist
			best_building = building

	_set_target(best_building)
	if MonsterPerf.enabled:
		MonsterPerf.find_target_calls += 1
		MonsterPerf.find_target_usec += Time.get_ticks_usec() - _perf_t0

func _set_target(new_target: Node) -> void:
	if new_target == _target_building:
		return
	# Release any slot on the old target before switching
	_release_attack_slot()
	_target_building = new_target

func _release_attack_slot() -> void:
	if _assigned_attack_slot != -1 and is_instance_valid(_target_building):
		var logic: BuildingLogic = _target_building.logic
		if logic:
			logic.release_attack_slot(self)
	_assigned_attack_slot = -1

## Attempt to claim an attack slot on the current target. Only claims when
## close enough — far-away monsters stay on the factory flow field without
## hogging slots.
func _try_claim_slot() -> void:
	if _assigned_attack_slot != -1:
		return  # already have one
	if not _target_building or not is_instance_valid(_target_building):
		return
	var dist := global_position.distance_to(
		GridUtils.grid_to_world(_target_building.grid_pos))
	if dist > TARGET_CLAIM_RADIUS:
		return
	var logic: BuildingLogic = _target_building.logic
	if logic:
		_assigned_attack_slot = logic.claim_attack_slot(self, global_position)

# ── Movement ────────────────────────────────────────────────────────────────

## Returns a normalized 2D desired direction (x=world x, y=world z) for the
## current frame, or Vector2.ZERO if the monster should stop.
func _process_movement(_delta: float) -> Vector2:
	if not _target_building or not is_instance_valid(_target_building):
		_set_target(null)
		state = State.IDLE
		return Vector2.ZERO

	# Periodic retarget — cheap compared to the old A* repath (no path query)
	_retarget_timer -= _delta
	if _retarget_timer <= 0.0:
		_retarget_timer = RETARGET_INTERVAL
		_find_target()
		if not _target_building:
			return Vector2.ZERO

	# Try to reserve a slot once we're close enough
	_try_claim_slot()

	# Attack range check — use slot position if we have one, else the building center
	var aim_world: Vector3
	if _assigned_attack_slot != -1 and is_instance_valid(_target_building):
		var logic: BuildingLogic = _target_building.logic
		if logic:
			aim_world = logic.get_attack_slot_world(_assigned_attack_slot)
		else:
			aim_world = GridUtils.grid_to_world(_target_building.grid_pos)
	else:
		aim_world = GridUtils.grid_to_world(_target_building.grid_pos)

	var dist_to_building := global_position.distance_to(
		GridUtils.grid_to_world(_target_building.grid_pos))
	if dist_to_building <= attack_range:
		state = State.ATTACKING
		_attack_timer = 0.0
		return Vector2.ZERO

	# Close-range: head straight to our assigned slot. Long-range: sample the
	# shared factory flow field so one Dijkstra serves the whole swarm.
	if _assigned_attack_slot != -1 and dist_to_building < TARGET_CLAIM_RADIUS:
		return _direction_to_world(aim_world)

	if pathfinding:
		var dir: Vector2 = _sample_factory_flow_cached()
		if dir.length_squared() > 0.001:
			return dir
	# Fallback: direct movement toward the target
	return _direction_to_world(GridUtils.grid_to_world(_target_building.grid_pos))

## Returns the cached factory flow direction, refreshing from the pathfinding
## system at most once every FLOW_SAMPLE_PERIOD physics ticks (with per-monster
## random offset so the work is staggered across frames). This cuts
## sample_factory_flow traffic by ~FLOW_SAMPLE_PERIOD× for free — the flow
## field is a Dijkstra gradient that only changes when buildings move, so
## reusing it for 1–2 frames is imperceptible. Spawning calls reset_for_spawn
## which seeds _last_flow_sample_tick with the per-monster offset so the
## first tick of the monster's life isn't forced to sample.
func _sample_factory_flow_cached() -> Vector2:
	var tick: int = Engine.get_physics_frames()
	if tick - _last_flow_sample_tick >= FLOW_SAMPLE_PERIOD:
		_cached_flow_dir = pathfinding.sample_factory_flow(global_position)
		_last_flow_sample_tick = tick
	return _cached_flow_dir

func _direction_to_world(target_world: Vector3) -> Vector2:
	var diff := target_world - global_position
	diff.y = 0.0
	if diff.length() < 0.05:
		return Vector2.ZERO
	var n := diff.normalized()
	return Vector2(n.x, n.z)

# ── Chasing ─────────────────────────────────────────────────────────────────

func _process_chasing(_delta: float) -> Vector2:
	# Check disengage
	var dist := _player_distance()
	if not GameManager.player or GameManager.player.health.is_dead or dist > _get_disengage_radius():
		state = State.IDLE
		_release_attack_slot()  # in case we were mid-attack when player showed up
		return Vector2.ZERO

	# Attack player if close enough
	_check_player_proximity(_delta)

	# Sample the shared chase flow field (one Dijkstra serves all chasers)
	if pathfinding:
		var dir: Vector2 = pathfinding.sample_chase_flow(global_position, GameManager.player.global_position)
		if dir.length_squared() > 0.001:
			return dir
	# Fallback: move directly toward the player
	return _direction_to_world(GameManager.player.global_position)

# ── Local separation (boids) ────────────────────────────────────────────────

# Reusable scratch buffer for separation neighbour queries. The grid appends
# into this array; we clear it before each query so we never allocate a new
# Array in the hot path.
var _separation_scratch: Array = []

## Blend a repulsion vector from nearby monsters into the desired direction,
## then renormalize. Only runs when the separation toggle is on.
##
## Uses the spawner's MonsterSeparationGrid (a per-frame spatial hash) to get
## just the local 3×3 cell window of neighbors, instead of walking every
## monster in the scene tree. Drops the inner loop from O(N) per call to
## ~O(neighbours-in-3x3) ≈ constant.
func _apply_separation(desired: Vector2) -> Vector2:
	var _perf_t0: int = Time.get_ticks_usec() if MonsterPerf.enabled else 0
	var sep := Vector2.ZERO
	var count := 0
	var sep_r2: float = SEPARATION_RADIUS * SEPARATION_RADIUS

	_separation_scratch.clear()
	var grid: MonsterSeparationGrid = _get_separation_grid()
	if grid != null:
		grid.gather_neighbors(global_position, _separation_scratch, self)
	else:
		# Fallback for sims / tests that don't run with a spawner: walk the
		# group as before. Slow but always works.
		for n in get_tree().get_nodes_in_group(&"monsters"):
			if n != self:
				_separation_scratch.append(n)

	for other in _separation_scratch:
		if not (other is Node3D):
			continue
		var other_pos: Vector3 = (other as Node3D).global_position
		var diff := global_position - other_pos
		diff.y = 0.0
		var d2: float = diff.length_squared()
		if d2 <= 0.0001 or d2 > sep_r2:
			continue
		# Push away from neighbor; closer = stronger (inverse distance)
		var d: float = sqrt(d2)
		var push: Vector2 = Vector2(diff.x, diff.z) / d * (1.0 - d / SEPARATION_RADIUS)
		sep += push
		count += 1
		if count >= SEPARATION_MAX_NEIGHBORS:
			break
	if MonsterPerf.enabled:
		MonsterPerf.separation_calls += 1
		MonsterPerf.separation_usec += Time.get_ticks_usec() - _perf_t0
	if count == 0:
		return desired
	var blended := desired + sep * SEPARATION_WEIGHT
	if blended.length_squared() < 0.0001:
		return desired
	return blended.normalized()

## Resolve the spawner's separation grid lazily. Cached after first hit.
var _cached_separation_grid: MonsterSeparationGrid = null
var _grid_lookup_failed: bool = false
func _get_separation_grid() -> MonsterSeparationGrid:
	if _cached_separation_grid != null:
		return _cached_separation_grid
	if _grid_lookup_failed:
		return null
	# Walk up parents to find the MonsterSpawner. The monster lives under
	# the GameWorld's monster_layer, sibling to the spawner.
	var spawner := _find_spawner()
	if spawner == null or not (&"separation_grid" in spawner):
		_grid_lookup_failed = true
		return null
	_cached_separation_grid = spawner.get(&"separation_grid")
	return _cached_separation_grid

func _find_spawner() -> Node:
	# The spawner sits as a sibling under GameWorld. Walk up to GameWorld and
	# search its children for the MonsterSpawner.
	var n: Node = get_parent()
	while n != null:
		for child in n.get_children():
			if child.get_script() != null and child.has_method("enqueue_spawn"):
				return child
		n = n.get_parent()
	return null

# ── Nearby building damage (while moving/chasing) ──────────────────────────

func _damage_nearby_buildings(delta: float) -> void:
	_chase_attack_timer -= delta
	if _chase_attack_timer > 0.0:
		return
	_chase_attack_timer = attack_cooldown

	var _perf_t0: int = Time.get_ticks_usec() if MonsterPerf.enabled else 0
	for building in BuildingRegistry.unique_buildings:
		if not is_instance_valid(building):
			continue
		var dist := global_position.distance_to(GridUtils.grid_to_world(building.grid_pos))
		if dist <= NEARBY_BUILDING_DAMAGE_RANGE:
			var logic: BuildingLogic = building.logic
			if logic:
				logic.take_damage(DamageEvent.create(attack_damage, &"", self))
	if MonsterPerf.enabled:
		MonsterPerf.damage_nearby_calls += 1
		MonsterPerf.damage_nearby_usec += Time.get_ticks_usec() - _perf_t0

# ── Attack ──────────────────────────────────────────────────────────────────

func _process_attack(delta: float) -> void:
	if not _target_building or not is_instance_valid(_target_building):
		_release_attack_slot()
		_target_building = null
		state = State.IDLE
		return

	velocity.x = 0.0
	velocity.z = 0.0

	# Check if target moved out of range
	var dist := global_position.distance_to(
		GridUtils.grid_to_world(_target_building.grid_pos))
	if dist > attack_range * 1.5:
		state = State.MOVING
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_do_attack()

func _do_attack() -> void:
	if not _target_building or not is_instance_valid(_target_building):
		return
	var logic: BuildingLogic = _target_building.logic
	if logic:
		logic.take_damage(DamageEvent.create(attack_damage, &"", self))
	# Check if building died — find new target
	if not is_instance_valid(_target_building) or (logic and logic.health and logic.health.is_dead):
		_release_attack_slot()
		_target_building = null
		state = State.IDLE

# ── Player attack ───────────────────────────────────────────────────────────

var _player_attack_timer: float = 0.0
const PLAYER_ATTACK_RANGE := 1.5
const PLAYER_DAMAGE := 10.0
const PLAYER_ATTACK_COOLDOWN := 2.0

func _check_player_proximity(delta: float) -> void:
	if not GameManager.player or state == State.DYING:
		return
	var dist := global_position.distance_to(GameManager.player.global_position)
	if dist > PLAYER_ATTACK_RANGE:
		_player_attack_timer = 0.0
		return
	_player_attack_timer -= delta
	if _player_attack_timer <= 0.0:
		_player_attack_timer = PLAYER_ATTACK_COOLDOWN
		GameManager.player.take_damage(DamageEvent.create(PLAYER_DAMAGE, &"", self))

# ── Damage ──────────────────────────────────────────────────────────────────

func take_damage(event: DamageEvent) -> void:
	if health:
		health.damage(event.amount)
	# Aggro when damaged by player or player-owned sources (turret projectiles)
	if is_instance_valid(event.source) and event.source is Player:
		_aggro_timer = AGGRO_DURATION
		if state != State.DYING and state != State.ATTACKING:
			state = State.CHASING

func _on_died() -> void:
	state = State.DYING
	_release_attack_slot()
	velocity = Vector3.ZERO
	died.emit()
	# Death anim: shrink, then either return to the pool (preferred — keeps
	# the .glb model and collision shapes loaded) or queue_free as a fallback
	# for legacy / sim paths that bypassed the pool.
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.tween_callback(_finish_death)

func _finish_death() -> void:
	if _pool != null:
		prepare_for_pool()
		_pool.release(self)
	else:
		queue_free()
