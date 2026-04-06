class_name BuildingBase
extends Node3D

const BUILDING_COLLISION_LAYER := 2
const BUILDING_BOX_HEIGHT := 1.0
## Flat buildings where items flow over via force zones — no blocking collision.
const NO_COLLISION_BUILDINGS: Array[StringName] = [&"conveyor", &"splitter", &"junction"]

var grid_pos: Vector2i
var building_id: StringName
var rotation_index: int = 0 # 0=right, 1=down, 2=left, 3=up

## Reference to the building's logic node (extends BuildingLogic).
var logic: BuildingLogic = null

## Auto-generated collision body from building grid shape.
var _model_collision: StaticBody3D = null

func init(p_id: StringName, p_grid_pos: Vector2i, p_rotation: int = 0) -> void:
	building_id = p_id
	grid_pos = p_grid_pos
	rotation_index = p_rotation

func _ready() -> void:
	# Deferred so the building is fully configured with its def
	_generate_model_collision.call_deferred()

## Create a StaticBody3D with simple box collision shapes from the building's
## grid footprint. One box per occupied cell — much cheaper than trimesh.
func _generate_model_collision() -> void:
	if building_id == &"":
		return  # Ghost node (never init'd) — skip collision generation
	if building_id in NO_COLLISION_BUILDINGS:
		return  # Flat buildings — items flow over them via force zones
	_model_collision = StaticBody3D.new()
	_model_collision.name = "ModelCollision"
	_model_collision.collision_layer = 1 << (BUILDING_COLLISION_LAYER - 1)
	_model_collision.collision_mask = 0
	add_child(_model_collision)

	var def = GameManager.get_building_def(building_id)
	if def:
		var rotated_shape: Array = def.get_rotated_shape(rotation_index)
		var anchor: Vector2i = def.anchor_cell
		for cell in rotated_shape:
			var box := BoxShape3D.new()
			box.size = Vector3(1.0, BUILDING_BOX_HEIGHT, 1.0)
			var col := CollisionShape3D.new()
			col.shape = box
			# Position relative to building origin (anchor cell is at 0,0)
			col.position = Vector3(
				float(cell.x - anchor.x) + 0.5,
				BUILDING_BOX_HEIGHT * 0.5,
				float(cell.y - anchor.y) + 0.5
			)
			_model_collision.add_child(col)
	else:
		# Fallback: single box at origin
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, BUILDING_BOX_HEIGHT, 1.0)
		var col := CollisionShape3D.new()
		col.shape = box
		col.position = Vector3(0.5, BUILDING_BOX_HEIGHT * 0.5, 0.5)
		_model_collision.add_child(col)

## Rebuild collision from building grid shape (call after model swap).
func regenerate_collision() -> void:
	if _model_collision:
		remove_child(_model_collision)
		_model_collision.queue_free()
		_model_collision = null
	_generate_model_collision()
