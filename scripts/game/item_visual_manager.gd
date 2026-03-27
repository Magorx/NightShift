extends RefCounted

## Renders all item visuals via a single MultiMeshInstance2D instead of
## individual Node2D instances. Drastically reduces draw calls.

const ITEM_RADIUS := 6.0
const INITIAL_CAPACITY := 256
const HIDDEN_POS := Vector2(-99999, -99999)

var multimesh: MultiMesh
var instance: MultiMeshInstance2D
var _free_list: Array[int] = []
var _capacity: int = 0

func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = _create_mesh()

	instance = MultiMeshInstance2D.new()
	instance.multimesh = multimesh

	_grow(INITIAL_CAPACITY)

func attach_to(parent: Node) -> void:
	parent.add_child(instance)

func allocate(color: Color) -> int:
	if _free_list.is_empty():
		_grow(maxi(_capacity * 2, INITIAL_CAPACITY))
	var idx: int = _free_list.pop_back()
	multimesh.set_instance_transform_2d(idx, Transform2D(0, HIDDEN_POS))
	multimesh.set_instance_color(idx, color)
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
		# Setting instance_count may clear existing data — preserve it
		var old_buf := multimesh.buffer.duplicate()
		multimesh.instance_count = _capacity
		var new_buf := multimesh.buffer
		for i in range(mini(old_buf.size(), new_buf.size())):
			new_buf[i] = old_buf[i]
		multimesh.buffer = new_buf
	for i in range(old, _capacity):
		multimesh.set_instance_transform_2d(i, Transform2D(0, HIDDEN_POS))
		_free_list.append(i)

func _create_mesh() -> Mesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(ITEM_RADIUS * 2, ITEM_RADIUS * 2)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;
void fragment() {
	float d = length(UV - vec2(0.5));
	if (d > 0.5) discard;
	float edge = smoothstep(0.35, 0.5, d);
	COLOR.rgb *= mix(1.0, 0.7, edge);
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mesh.material = mat
	return mesh
