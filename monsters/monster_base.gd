class_name MonsterBase
extends CharacterBody3D

## Base class for all monsters. Handles HP, pathfinding, movement, and attack.
## Subclasses override stats and attack behavior.
##
## Collision setup:
##   layer 5 (bit 16) — projectiles detect this via Area3D.body_entered
##   mask: ground (4) + buildings (2) — walk on ground, blocked by buildings

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

var _target_building: Node = null
var _current_path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _attack_timer: float = 0.0
var _repath_timer: float = 0.0
var _gravity: float = 20.0

# ── Chase / aggro ───────────────────────────────────────────────────────────
const CHASE_ENGAGE_RADIUS := 5.0    # start chasing player within this (world units ≈ tiles)
const CHASE_DISENGAGE_RADIUS := 8.0 # stop chasing when player exceeds this
const AGGRO_DISENGAGE_RADIUS := 12.0 # disengage radius when hit by player
const AGGRO_DURATION := 3.0          # seconds of aggro after taking player damage
const NEARBY_BUILDING_DAMAGE_RANGE := 1.5  # damage buildings while passing by
const CHASE_REPATH_INTERVAL := 0.2

var _aggro_timer: float = 0.0       # >0 = in aggro mode (larger chase radius)
var _chase_attack_timer: float = 0.0 # cooldown for damaging buildings while moving

var _debug_path_mesh: MeshInstance3D
var _debug_immediate_mesh: ImmediateMesh

const REPATH_INTERVAL := 2.0
const MONSTER_COLLISION_LAYER := 16  # bit 5
const MONSTER_COLLISION_MASK := 6    # ground (4) + buildings (2)

func _ready() -> void:
	add_to_group(&"monsters")
	collision_layer = MONSTER_COLLISION_LAYER
	collision_mask = MONSTER_COLLISION_MASK

	_setup_collision()
	_setup_health()
	_setup_visual()
	_setup_debug_path()

func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 0.8
	col.shape = capsule
	col.position = Vector3(0.0, 0.4, 0.0)
	add_child(col)

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

func _update_debug_path() -> void:
	if not _debug_immediate_mesh or not SettingsManager.debug_mode:
		return
	_debug_immediate_mesh.clear_surfaces()
	if _current_path.size() < 2 or _path_index >= _current_path.size():
		return
	var line_y := global_position.y + 0.3
	_debug_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	# Start from monster position
	_debug_immediate_mesh.surface_add_vertex(Vector3(global_position.x, line_y, global_position.z))
	# Draw remaining path waypoints
	for i in range(_path_index, _current_path.size()):
		var pt := _current_path[i]
		_debug_immediate_mesh.surface_add_vertex(Vector3(pt.x, line_y, pt.y))
	_debug_immediate_mesh.surface_end()

func _physics_process(delta: float) -> void:
	if state == State.DYING:
		return

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
			_repath_timer = 0.0

	match state:
		State.IDLE:
			_find_target()
			if _target_building:
				state = State.MOVING
		State.MOVING:
			_process_movement(delta)
			_damage_nearby_buildings(delta)
		State.ATTACKING:
			_process_attack(delta)
		State.CHASING:
			_process_chasing(delta)
			_damage_nearby_buildings(delta)

	move_and_slide()
	_update_debug_path()

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

	_target_building = best_building
	if _target_building:
		_repath()

# ── Pathfinding ─────────────────────────────────────────────────────────────

func _repath() -> void:
	if not _target_building or not is_instance_valid(_target_building):
		_target_building = null
		state = State.IDLE
		return

	var my_grid := GridUtils.world_to_grid(global_position)

	if pathfinding:
		var attack_cell := pathfinding.find_attack_cell(my_grid, _target_building.grid_pos)
		if attack_cell != Vector2i(-1, -1):
			_current_path = pathfinding.get_path(my_grid, attack_cell)
			_path_index = 1  # skip the starting cell
			return

	# Fallback: direct movement if no pathfinding or no path found
	_current_path = PackedVector2Array()
	_path_index = 0

func _repath_toward_player() -> void:
	if not GameManager.player or not pathfinding:
		_current_path = PackedVector2Array()
		_path_index = 0
		return
	_current_path = pathfinding.get_path_world(global_position, GameManager.player.global_position)
	_path_index = 1

# ── Movement ────────────────────────────────────────────────────────────────

func _follow_path(_delta: float) -> void:
	if _current_path.size() > 0 and _path_index < _current_path.size():
		var next_point := _current_path[_path_index]
		var target_world := Vector3(next_point.x, global_position.y, next_point.y)
		var diff := target_world - global_position
		diff.y = 0.0
		var dist := diff.length()

		if dist < 0.3:
			_path_index += 1
		else:
			var dir := diff.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			if dir.length_squared() > 0.01:
				look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _move_directly_toward(target_pos: Vector3) -> void:
	var diff := target_pos - global_position
	diff.y = 0.0
	if diff.length() > 0.1:
		var dir := diff.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		if dir.length_squared() > 0.01:
			look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _process_movement(delta: float) -> void:
	if not _target_building or not is_instance_valid(_target_building):
		_target_building = null
		state = State.IDLE
		return

	# Check if we're close enough to attack
	var dist_to_target := global_position.distance_to(
		GridUtils.grid_to_world(_target_building.grid_pos))
	if dist_to_target <= attack_range:
		state = State.ATTACKING
		_attack_timer = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		return

	# Periodic repath
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = REPATH_INTERVAL
		_find_target()
		if not _target_building:
			return

	# Follow A* path, fallback to direct movement
	if _current_path.size() > 0 and _path_index < _current_path.size():
		_follow_path(delta)
	else:
		_move_directly_toward(GridUtils.grid_to_world(_target_building.grid_pos))

# ── Chasing ─────────────────────────────────────────────────────────────────

func _process_chasing(delta: float) -> void:
	# Check disengage
	var dist := _player_distance()
	if not GameManager.player or GameManager.player.health.is_dead or dist > _get_disengage_radius():
		state = State.IDLE
		velocity.x = 0.0
		velocity.z = 0.0
		return

	# Attack player if close enough
	_check_player_proximity(delta)

	# Periodic repath toward player
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = CHASE_REPATH_INTERVAL
		_repath_toward_player()

	# Follow path toward player, fallback to direct
	if _current_path.size() > 0 and _path_index < _current_path.size():
		_follow_path(delta)
	else:
		_move_directly_toward(GameManager.player.global_position)

# ── Nearby building damage (while moving/chasing) ──────────────────────────

func _damage_nearby_buildings(delta: float) -> void:
	_chase_attack_timer -= delta
	if _chase_attack_timer > 0.0:
		return
	_chase_attack_timer = attack_cooldown

	for building in BuildingRegistry.unique_buildings:
		if not is_instance_valid(building):
			continue
		var dist := global_position.distance_to(GridUtils.grid_to_world(building.grid_pos))
		if dist <= NEARBY_BUILDING_DAMAGE_RANGE:
			var logic: BuildingLogic = building.logic
			if logic:
				logic.take_damage(DamageEvent.create(attack_damage, &"", self))

# ── Attack ──────────────────────────────────────────────────────────────────

func _process_attack(delta: float) -> void:
	if not _target_building or not is_instance_valid(_target_building):
		_target_building = null
		state = State.IDLE
		return

	# Check if target moved out of range
	var dist := global_position.distance_to(
		GridUtils.grid_to_world(_target_building.grid_pos))
	if dist > attack_range * 1.5:
		state = State.MOVING
		_repath()
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
	if event.source is Player or event.source is Projectile:
		_aggro_timer = AGGRO_DURATION
		if state != State.DYING and state != State.ATTACKING:
			state = State.CHASING
			_repath_timer = 0.0

func _on_died() -> void:
	state = State.DYING
	velocity = Vector3.ZERO
	died.emit()
	# Simple death: remove after brief delay
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.tween_callback(queue_free)
