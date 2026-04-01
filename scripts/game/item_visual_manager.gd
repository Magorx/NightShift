extends BaseMultiMeshManager

## Renders all item visuals via a single MultiMeshInstance2D instead of
## individual Node2D instances. Drastically reduces draw calls.
## Uses an atlas texture (8x8 grid of 16x16 items).

const ITEM_SIZE := 16.0
const INITIAL_CAPACITY := 256

# Atlas layout
const ATLAS_COLS := 8
const ATLAS_ROWS := 8

func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = true
	multimesh.mesh = BaseMultiMeshManager.create_quad_mesh(ITEM_SIZE)

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


func _create_atlas_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;
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
	vec4 tex = texture(TEXTURE, atlas_uv);
	if (tex.a < 0.01) discard;
	COLOR = tex;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
