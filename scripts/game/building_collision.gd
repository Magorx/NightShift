class_name BuildingCollision
extends StaticBody3D
## Manages collision shapes for buildings that block the player.
## One BoxShape3D per occupied tile of each blocking building.

const BUILDING_COLLISION_LAYER := 2

# Map from grid position to CollisionShape3D node
var _shapes: Dictionary = {}

var _shared_box_shape: BoxShape3D

func _ready() -> void:
	collision_layer = (1 << (BUILDING_COLLISION_LAYER - 1))
	collision_mask = 0  # Static body doesn't need to detect others
	_shared_box_shape = BoxShape3D.new()
	_shared_box_shape.size = Vector3(1.0, 1.0, 1.0)

func add_tile(grid_pos: Vector2i) -> void:
	if _shapes.has(grid_pos):
		return
	var shape_node := CollisionShape3D.new()
	shape_node.shape = _shared_box_shape
	var world_pos := GridUtils.grid_to_world(grid_pos)
	shape_node.position = Vector3(world_pos.x, 0.5, world_pos.z)  # center box at Y=0.5
	add_child(shape_node)
	_shapes[grid_pos] = shape_node

func remove_tile(grid_pos: Vector2i) -> void:
	if not _shapes.has(grid_pos):
		return
	var shape_node: CollisionShape3D = _shapes[grid_pos]
	shape_node.queue_free()
	_shapes.erase(grid_pos)

func clear_all() -> void:
	for pos in _shapes:
		if is_instance_valid(_shapes[pos]):
			_shapes[pos].queue_free()
	_shapes.clear()
