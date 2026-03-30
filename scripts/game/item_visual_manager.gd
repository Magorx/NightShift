extends RefCounted

## Renders all item visuals via a single MultiMeshInstance2D instead of
## individual Node2D instances. Drastically reduces draw calls.
## Now uses an atlas texture (8x5 grid of 16x16 items) instead of colored circles.

const ITEM_SIZE := 15.0
const INITIAL_CAPACITY := 256
const HIDDEN_POS := Vector2(-99999, -99999)

# Atlas layout
const ATLAS_COLS := 8
const ATLAS_ROWS := 5

var multimesh: MultiMesh
var instance: MultiMeshInstance2D
var _free_list: Array[int] = []
var _capacity: int = 0

func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = true
	multimesh.mesh = _create_mesh()

	instance = MultiMeshInstance2D.new()
	instance.multimesh = multimesh
	instance.z_index = GameManager.Z_ITEM
	instance.texture = load("res://resources/items/sprites/item_atlas.png")
	instance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	instance.material = _create_atlas_material()

	_grow(INITIAL_CAPACITY)

func attach_to(parent: Node) -> void:
	parent.add_child(instance)

func allocate(atlas_index: int) -> int:
	if _free_list.is_empty():
		_grow(maxi(_capacity * 2, INITIAL_CAPACITY))
	var idx: int = _free_list.pop_back()
	multimesh.set_instance_transform_2d(idx, Transform2D(0, HIDDEN_POS))
	# Encode atlas row and column in custom data
	@warning_ignore("integer_division")
	var col: float = float(atlas_index % ATLAS_COLS)
	@warning_ignore("integer_division")
	var row: float = float(atlas_index / ATLAS_COLS)
	multimesh.set_instance_custom_data(idx, Color(col, row, 0.0, 1.0))
	return idx

func release(idx: int) -> void:
	if idx < 0:
		return
	multimesh.set_instance_transform_2d(idx, Transform2D(0, HIDDEN_POS))
	_free_list.append(idx)

func set_position(idx: int, pos: Vector2) -> void:
	multimesh.set_instance_transform_2d(idx, Transform2D(0, pos))

func hide(idx: int) -> void:
	multimesh.set_instance_transform_2d(idx, Transform2D(0, HIDDEN_POS))

func clear_all() -> void:
	_free_list.clear()
	_capacity = 0
	multimesh.instance_count = 0
	_grow(INITIAL_CAPACITY)

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

func _create_mesh() -> Mesh:
	var arr_mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var h := ITEM_SIZE * 0.5
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-h, -h, 0), Vector3(h, -h, 0),
		Vector3(h, h, 0), Vector3(-h, h, 0),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0),
		Vector2(1, 1), Vector2(0, 1),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh

func _create_atlas_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;
// Atlas layout: 8 columns x 5 rows of 16x16 items
const float COLS = 8.0;
const float ROWS = 5.0;
varying flat float v_col;
varying flat float v_row;
void vertex() {
	v_col = INSTANCE_CUSTOM.r;
	v_row = INSTANCE_CUSTOM.g;
}
void fragment() {
	float u = UV.x;
	float v = UV.y;
	vec2 atlas_uv = vec2((v_col + u) / COLS, (v_row + v) / ROWS);
	vec4 tex = texture(TEXTURE, atlas_uv);
	if (tex.a < 0.01) discard;
	COLOR = tex;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
