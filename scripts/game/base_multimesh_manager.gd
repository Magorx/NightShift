class_name BaseMultiMeshManager
extends RefCounted

## Shared infrastructure for MultiMesh-based visual managers.
## Provides: grow with data preservation, quad mesh creation, free-list allocation.

const HIDDEN_POS := Vector2(-99999, -99999)

var multimesh: MultiMesh
var instance: MultiMeshInstance2D
var _free_list: Array[int] = []
var _capacity: int = 0

func _grow(new_capacity: int) -> void:
	var old := _capacity
	_capacity = new_capacity
	if old == 0:
		multimesh.instance_count = _capacity
	else:
		var old_transforms: Array = []
		var old_custom: Array = []
		for i in range(old):
			old_transforms.append(multimesh.get_instance_transform_2d(i))
			old_custom.append(multimesh.get_instance_custom_data(i))
		multimesh.instance_count = _capacity
		for i in range(old):
			multimesh.set_instance_transform_2d(i, old_transforms[i])
			multimesh.set_instance_custom_data(i, old_custom[i])
	for i in range(old, _capacity):
		multimesh.set_instance_transform_2d(i, Transform2D(0, HIDDEN_POS))
		_free_list.append(i)

static func create_quad_mesh(tile_size: float) -> Mesh:
	return create_rect_mesh(tile_size, tile_size)

## Create a rectangular quad mesh centered at the origin.
static func create_rect_mesh(width: float, height: float) -> Mesh:
	var arr_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var hw := width * 0.5
	var hh := height * 0.5
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-hw, -hh, 0), Vector3(hw, -hh, 0),
		Vector3(hw, hh, 0), Vector3(-hw, hh, 0),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0),
		Vector2(1, 1), Vector2(0, 1),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh
