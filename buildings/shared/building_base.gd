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
## When true, force collision generation even for normally flat buildings (e.g. conveyor→wall).
var force_collision: bool = false

func init(p_id: StringName, p_grid_pos: Vector2i, p_rotation: int = 0) -> void:
	building_id = p_id
	grid_pos = p_grid_pos
	rotation_index = p_rotation

func _ready() -> void:
	# Deferred so the building is fully configured with its def
	_generate_model_collision.call_deferred()

## Generate collision from the Model node's actual meshes (trimesh).
## Falls back to per-cell boxes if no Model meshes are found.
func _generate_model_collision() -> void:
	if building_id == &"":
		return
	if building_id in NO_COLLISION_BUILDINGS and not force_collision:
		return

	_model_collision = StaticBody3D.new()
	_model_collision.name = "ModelCollision"
	_model_collision.collision_layer = 1 << (BUILDING_COLLISION_LAYER - 1)
	_model_collision.collision_mask = 0
	add_child(_model_collision)

	# Collect all mesh faces from the Model subtree
	var model := get_node_or_null("Model")
	if model:
		var faces := PackedVector3Array()
		_collect_mesh_faces(model, faces)
		if faces.size() >= 3:
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			var col := CollisionShape3D.new()
			col.shape = shape
			_model_collision.add_child(col)
			return

	# Fallback: per-cell boxes (no Model found or no meshes)
	var def = BuildingRegistry.get_building_def(building_id)
	if def:
		var rotated_shape: Array = def.get_rotated_shape(rotation_index)
		var anchor: Vector2i = def.anchor_cell
		for cell in rotated_shape:
			var box := BoxShape3D.new()
			box.size = Vector3(1.0, BUILDING_BOX_HEIGHT, 1.0)
			var col := CollisionShape3D.new()
			col.shape = box
			col.position = Vector3(
				float(cell.x - anchor.x) + 0.5,
				BUILDING_BOX_HEIGHT * 0.5,
				float(cell.y - anchor.y) + 0.5
			)
			_model_collision.add_child(col)
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, BUILDING_BOX_HEIGHT, 1.0)
		var col := CollisionShape3D.new()
		col.shape = box
		col.position = Vector3(0.5, BUILDING_BOX_HEIGHT * 0.5, 0.5)
		_model_collision.add_child(col)

## Recursively collect triangle faces from all MeshInstance3D nodes under `node`.
## Positions are in the BuildingBase's local space.
func _collect_mesh_faces(node: Node, faces: PackedVector3Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh:
			# Transform from mesh-local to building-local
			var xform := mi.global_transform * global_transform.inverse()
			for surf_idx in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surf_idx)
				if arrays.size() == 0:
					continue
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices = arrays[Mesh.ARRAY_INDEX]
				if indices and indices.size() >= 3:
					for i in range(0, indices.size(), 3):
						faces.append(xform * verts[indices[i]])
						faces.append(xform * verts[indices[i + 1]])
						faces.append(xform * verts[indices[i + 2]])
				elif verts.size() >= 3:
					for v in verts:
						faces.append(xform * v)
	for child in node.get_children():
		_collect_mesh_faces(child, faces)

## Rebuild collision from building grid shape (call after model swap).
func regenerate_collision() -> void:
	if _model_collision:
		remove_child(_model_collision)
		_model_collision.queue_free()
		_model_collision = null
	_generate_model_collision()
