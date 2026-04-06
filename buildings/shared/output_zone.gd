class_name OutputZone
extends Area3D
## 3D output zone for physics-based buildings. Items spawn at a random
## point within the zone's collision volume with an outward impulse.
## Requires a CollisionShape3D child (BoxShape3D) defining the spawn area.
##
## Position in building-local space encodes the grid cell offset:
##   cell = Vector2i(round(position.x), round(position.z))

const SPAWN_IMPULSE := 1.5

## Directional mask — which directions are valid output at this cell.
## Defined in the building's default orientation (facing right).
@export var allow_right: bool = true
@export var allow_down: bool = true
@export var allow_left: bool = true
@export var allow_up: bool = true

var _cached_shape_node: CollisionShape3D = null

func _ready() -> void:
	# Output zones don't detect anything — they're spawn volumes only
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	# Cache the CollisionShape3D child for spawn point calculation
	for child in get_children():
		if child is CollisionShape3D:
			_cached_shape_node = child
			break

## Spawn a PhysicsItem at a random point within this zone's box volume.
func spawn_item(item_id: StringName, impulse_scale: float = 1.0) -> PhysicsItem:
	var spawn_pos := _random_point_in_box()
	spawn_pos.y = maxf(spawn_pos.y, 0.2)
	var impulse := _get_impulse_direction() * SPAWN_IMPULSE * impulse_scale
	return PhysicsItem.spawn(item_id, spawn_pos, impulse)

## Pick a random point inside the CollisionShape3D box (in global space).
func _random_point_in_box() -> Vector3:
	if not _cached_shape_node or not (_cached_shape_node.shape is BoxShape3D):
		return global_position
	var box: BoxShape3D = _cached_shape_node.shape
	var half := box.size * 0.5
	var local_pt := Vector3(
		randf_range(-half.x, half.x),
		randf_range(-half.y, half.y),
		randf_range(-half.z, half.z)
	)
	return _cached_shape_node.global_transform * local_pt

func _get_impulse_direction() -> Vector3:
	var local_dir := Vector3.ZERO
	if allow_right and not allow_left:
		local_dir.x += 1.0
	elif allow_left and not allow_right:
		local_dir.x -= 1.0
	if allow_down and not allow_up:
		local_dir.z += 1.0
	elif allow_up and not allow_down:
		local_dir.z -= 1.0
	if local_dir == Vector3.ZERO:
		local_dir = Vector3.RIGHT
	var global_dir: Vector3 = global_transform.basis * local_dir.normalized()
	global_dir.y = 0.0
	return global_dir.normalized()
