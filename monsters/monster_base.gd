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

# ── State ───────────────────────────────────────────────────────────────────
enum State { IDLE, MOVING, ATTACKING, DYING }
var state: State = State.IDLE

var health: HealthComponent
var pathfinding: MonsterPathfinding

var _target_building: Node = null
var _current_path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _attack_timer: float = 0.0
var _repath_timer: float = 0.0
var _gravity: float = 20.0

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

func _physics_process(delta: float) -> void:
	if state == State.DYING:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	match state:
		State.IDLE:
			_find_target()
			if _target_building:
				state = State.MOVING
		State.MOVING:
			_process_movement(delta)
		State.ATTACKING:
			_process_attack(delta)

	move_and_slide()

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

# ── Movement ────────────────────────────────────────────────────────────────

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

	# Follow A* path
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
			# Face movement direction
			if dir.length_squared() > 0.01:
				look_at(global_position + dir, Vector3.UP)
	else:
		# No path or end of path — move directly toward target
		var target_pos := GridUtils.grid_to_world(_target_building.grid_pos)
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
	if logic and logic.health:
		logic.health.damage(attack_damage)
		print("[MONSTER] Attacked building at %s for %.0f damage" % [
			str(_target_building.grid_pos), attack_damage])
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
		if GameManager.player.has_method("take_damage"):
			GameManager.player.take_damage(PLAYER_DAMAGE)

# ── Damage ──────────────────────────────────────────────────────────────────

func take_damage(amount: float, _element: StringName = &"") -> void:
	if health:
		health.damage(amount)

func _on_died() -> void:
	state = State.DYING
	velocity = Vector3.ZERO
	died.emit()
	# Simple death: remove after brief delay
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.3)
	tween.tween_callback(queue_free)
