class_name OutputZone
extends Marker3D
## 3D output zone for physics-based buildings. Marks where items spawn
## and provides the impulse direction for ejected items.
## Position in building-local space encodes the grid cell offset:
##   cell = Vector2i(round(position.x), round(position.z))

const SPAWN_IMPULSE := 1.5  # default outward impulse magnitude

## Directional mask — which directions are valid output at this cell.
## Defined in the building's default orientation (facing right).
@export var allow_right: bool = true
@export var allow_down: bool = true
@export var allow_left: bool = true
@export var allow_up: bool = true

func get_mask() -> Array:
	return [allow_right, allow_down, allow_left, allow_up]

## Return the grid cell offset this zone represents.
func get_cell() -> Vector2i:
	return Vector2i(roundi(position.x), roundi(position.z))

## Spawn a PhysicsItem at this output zone with outward impulse.
## The marker is at the neighbor grid cell; items spawn at the building edge
## (shifted half a cell back toward the building).
func spawn_item(item_id: StringName, impulse_scale: float = 1.0) -> PhysicsItem:
	var impulse_dir := _get_impulse_direction()
	var spawn_pos := global_position - impulse_dir * 0.4
	spawn_pos.y = maxf(spawn_pos.y, 0.2)
	var impulse := impulse_dir * SPAWN_IMPULSE * impulse_scale
	return PhysicsItem.spawn(item_id, spawn_pos, impulse)

## Compute outward impulse direction from the mask.
func _get_impulse_direction() -> Vector3:
	# Build direction from allowed mask (in building-local space)
	# The mask directions are: [right, down, left, up] → world [+X, +Z, -X, -Z]
	# But since the building is rotated via Y rotation, we use global_transform
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
		local_dir = Vector3.RIGHT  # default
	# Transform to global space (accounts for building rotation)
	var global_dir: Vector3 = global_transform.basis * local_dir.normalized()
	global_dir.y = 0.0
	return global_dir.normalized()
