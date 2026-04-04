extends RefCounted

## Renders all item visuals via a single MultiMeshInstance3D instead of
## individual Node2D instances. Drastically reduces draw calls.
## Uses an atlas texture (8x8 grid of 16x16 items).
## Items render as small quads on the XZ ground plane, slightly above Y=0.

const ITEM_QUAD_SIZE := 0.3
const INITIAL_CAPACITY := 256
const HIDDEN_POS := Vector3(-9999.0, -9999.0, -9999.0)

# Atlas layout
const ATLAS_COLS := 8
const ATLAS_ROWS := 8

var multimesh: MultiMesh
var instance: MultiMeshInstance3D
var _free_list: PackedInt32Array = []
var _capacity: int = 0

func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _create_plane_mesh()

	instance = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _create_atlas_material()

	_grow(INITIAL_CAPACITY)

func attach_to(parent: Node) -> void:
	parent.add_child(instance)

func allocate(atlas_index: int) -> int:
	if _free_list.is_empty():
		_grow(maxi(_capacity * 2, INITIAL_CAPACITY))
	var idx: int = _free_list[-1]
	_free_list.resize(_free_list.size() - 1)
	multimesh.set_instance_transform(idx, Transform3D(Basis(), HIDDEN_POS))
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
	multimesh.set_instance_transform(idx, Transform3D(Basis(), HIDDEN_POS))
	_free_list.append(idx)

func set_position_3d(idx: int, pos: Vector3) -> void:
	var basis := Basis.IDENTITY.scaled(Vector3(ITEM_QUAD_SIZE, ITEM_QUAD_SIZE, ITEM_QUAD_SIZE))
	multimesh.set_instance_transform(idx, Transform3D(basis, pos))

func hide(idx: int) -> void:
	multimesh.set_instance_transform(idx, Transform3D(Basis(), HIDDEN_POS))

func clear_all() -> void:
	_free_list = PackedInt32Array()
	_capacity = 0
	multimesh.instance_count = 0
	_grow(INITIAL_CAPACITY)


# ── Private ──────────────────────────────────────────────────────────────────

func _create_plane_mesh() -> Mesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1, 1)
	return mesh

func _grow(new_capacity: int) -> void:
	var old := _capacity
	_capacity = new_capacity
	multimesh.instance_count = _capacity
	# Hide new instances and add to free list
	for i in range(old, _capacity):
		multimesh.set_instance_transform(i, Transform3D(Basis(), HIDDEN_POS))
		_free_list.append(i)

func _create_atlas_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D atlas : source_color, filter_nearest;

// Atlas layout: 8 columns x 8 rows of 16x16 items
const float COLS = 8.0;
const float ROWS = 8.0;

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
	vec4 tex = texture(atlas, atlas_uv);
	if (tex.a < 0.01) discard;
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("atlas", load("res://resources/items/sprites/item_atlas.png"))
	return mat
