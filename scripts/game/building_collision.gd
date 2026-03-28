class_name BuildingCollision
extends StaticBody2D
## Manages collision shapes for buildings that block the player.
## One CollisionShape2D per occupied tile of each blocking building.

const TILE_SIZE := 32
const BUILDING_COLLISION_LAYER := 2

# Map from grid position to CollisionShape2D node
var _shapes: Dictionary = {}

var _shared_rect_shape: RectangleShape2D

func _ready() -> void:
	collision_layer = (1 << (BUILDING_COLLISION_LAYER - 1))
	collision_mask = 0  # Static body doesn't need to detect others
	_shared_rect_shape = RectangleShape2D.new()
	_shared_rect_shape.size = Vector2(TILE_SIZE, TILE_SIZE)

func add_tile(grid_pos: Vector2i) -> void:
	if _shapes.has(grid_pos):
		return
	var shape_node := CollisionShape2D.new()
	shape_node.shape = _shared_rect_shape
	shape_node.position = Vector2(grid_pos) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	add_child(shape_node)
	_shapes[grid_pos] = shape_node

func remove_tile(grid_pos: Vector2i) -> void:
	if not _shapes.has(grid_pos):
		return
	var shape_node: CollisionShape2D = _shapes[grid_pos]
	shape_node.queue_free()
	_shapes.erase(grid_pos)

func clear_all() -> void:
	for pos in _shapes:
		if is_instance_valid(_shapes[pos]):
			_shapes[pos].queue_free()
	_shapes.clear()
