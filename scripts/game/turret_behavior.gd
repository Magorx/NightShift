class_name TurretBehavior
extends Node

## Turret targeting and firing behavior for converted buildings during the fight phase.
## Attach as a child of a building's logic node or building root. Finds the nearest
## monster in range, aims at it, and fires projectiles on cooldown.
##
## API:
##   turret.activate(element)   -- enable firing, set element type
##   turret.deactivate()        -- stop firing
##
## Requires: GameManager.item_layer to exist (projectiles are added there).

## Maximum targeting range in world units (roughly = tiles, since TILE_SIZE ~ 1.0).
var range_radius: float = 8.0

## Seconds between shots.
var fire_cooldown: float = 1.5

## Projectile travel speed (world units/sec).
var projectile_speed: float = 12.0

## Damage per projectile hit.
var projectile_damage: float = 25.0

## Element type for damage (set from building's last crafted resource).
var element: StringName = &""

## Whether the turret is actively seeking targets and firing.
var active: bool = false

var _cooldown_timer: float = 0.0
var _current_target: Node3D = null
var _cached_position_node: Node3D = null

## Enable the turret and set its element type.
func activate(p_element: StringName) -> void:
	element = p_element
	active = true
	_cooldown_timer = 0.0
	_current_target = null
	_cache_position_node()
	set_physics_process(true)

## Disable the turret. Stops firing and clears target.
func deactivate() -> void:
	active = false
	_current_target = null
	set_physics_process(false)

func _ready() -> void:
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not active:
		return

	# Tick cooldown.
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	# Validate current target is still alive and in range.
	if _current_target and is_instance_valid(_current_target):
		var dist := _get_turret_position().distance_to(_current_target.global_position)
		if dist > range_radius:
			_current_target = null
	else:
		_current_target = null

	# Find a new target if needed.
	if not _current_target:
		_current_target = _find_nearest_target()

	# Fire if ready and have a target.
	if _current_target and _cooldown_timer <= 0.0:
		_fire_at(_current_target)
		_cooldown_timer = fire_cooldown

## Cache the Node3D parent for position lookups.
func _cache_position_node() -> void:
	var node: Node = get_parent()
	while node:
		if node is Node3D:
			_cached_position_node = node
			return
		node = node.get_parent()

## Get the world position of this turret (the building it belongs to).
func _get_turret_position() -> Vector3:
	if _cached_position_node and is_instance_valid(_cached_position_node):
		return _cached_position_node.global_position
	return Vector3.ZERO

## Shared monster list cache — refreshed once per frame by the first turret that queries.
static var _cached_monsters: Array = []
static var _cache_frame: int = -1

## Find the nearest monster within range.
func _find_nearest_target() -> Node3D:
	var frame := Engine.get_physics_frames()
	if frame != _cache_frame:
		_cache_frame = frame
		_cached_monsters = get_tree().get_nodes_in_group(&"monsters")
	if _cached_monsters.is_empty():
		return null

	var turret_pos := _get_turret_position()
	var best_target: Node3D = null
	var best_dist_sq: float = range_radius * range_radius

	for monster in _cached_monsters:
		if not is_instance_valid(monster) or not monster is Node3D:
			continue
		var dist_sq := turret_pos.distance_squared_to(monster.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_target = monster

	return best_target

## Instantiate and launch a projectile toward the target.
func _fire_at(target: Node3D) -> void:
	var turret_pos := _get_turret_position()
	# Offset spawn slightly upward so it doesn't clip the ground.
	var spawn_pos := turret_pos + Vector3(0.0, 0.5, 0.0)

	var direction := (target.global_position - spawn_pos).normalized()
	if direction.length_squared() < 0.0001:
		return

	var projectile := Projectile.new()
	projectile.velocity = direction * projectile_speed
	projectile.damage = projectile_damage
	projectile.element = element
	projectile.position = spawn_pos

	# Add to item_layer if available, otherwise scene root.
	var parent_node: Node = null
	if GameManager.item_layer:
		parent_node = GameManager.item_layer
	else:
		parent_node = get_tree().current_scene
	if parent_node:
		parent_node.add_child(projectile)
