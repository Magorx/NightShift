class_name BuildingBase
extends Node3D

const BUILDING_COLLISION_LAYER := 2

var grid_pos: Vector2i
var building_id: StringName
var rotation_index: int = 0 # 0=right, 1=down, 2=left, 3=up

## Reference to the building's logic node (extends BuildingLogic).
var logic: BuildingLogic = null

## Auto-generated collision body from model meshes.
var _model_collision: StaticBody3D = null

func init(p_id: StringName, p_grid_pos: Vector2i, p_rotation: int = 0) -> void:
	building_id = p_id
	grid_pos = p_grid_pos
	rotation_index = p_rotation

func _ready() -> void:
	# Deferred so the Model instance and all its meshes are fully loaded
	_generate_model_collision.call_deferred()

## Create a StaticBody3D with trimesh collision shapes from all model meshes.
## This makes buildings physically solid — player and items collide with the
## actual 3D model geometry instead of invisible placeholder boxes.
func _generate_model_collision() -> void:
	var model: Node3D = get_node_or_null("Model")
	if not model:
		return
	_model_collision = StaticBody3D.new()
	_model_collision.name = "ModelCollision"
	_model_collision.collision_layer = 1 << (BUILDING_COLLISION_LAYER - 1)
	_model_collision.collision_mask = 0
	add_child(_model_collision)

	_collect_trimesh_shapes(model)

func _collect_trimesh_shapes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node
		if mesh_inst.mesh:
			var shape: ConcavePolygonShape3D = mesh_inst.mesh.create_trimesh_shape()
			if shape:
				var col := CollisionShape3D.new()
				col.shape = shape
				# Transform: mesh global → building-local → collision body local
				var rel: Transform3D = _model_collision.global_transform.affine_inverse() * mesh_inst.global_transform
				col.transform = rel
				_model_collision.add_child(col)
	for child in node.get_children():
		_collect_trimesh_shapes(child)
