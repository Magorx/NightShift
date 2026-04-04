extends RefCounted

## Renders all conveyor sprites via a single MultiMeshInstance3D instead of
## individual AnimatedSprite2D nodes. Drastically reduces draw calls.
## Conveyors render as quads on the XZ ground plane (Y=0) using a spatial shader.

const INITIAL_CAPACITY := 512
const ANIM_FPS := 10.0
const FRAME_COUNT := 4
const HIDDEN_POS := Vector3(-9999.0, -9999.0, -9999.0)

# Atlas: 4 cols x 6 rows of 64x32 in straight.png (256x192)
# Columns 0-3 are animation frames, rows 0-5 are variants:
#   Row 0: straight, Row 1: turn, Row 2: dual_side_input,
#   Row 3: side_input, Row 4: crossroad, Row 5: start

var multimesh: MultiMesh
var instance: MultiMeshInstance3D
var _material: ShaderMaterial
var _idx_map: Dictionary = {}  # Vector2i -> int (multimesh index)
var _free_list: PackedInt32Array = []
var _capacity: int = 0

func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _create_plane_mesh()

	_material = _create_material()

	instance = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _material

	_grow(INITIAL_CAPACITY)

func attach_to(parent: Node) -> void:
	parent.add_child(instance)

func register(grid_pos: Vector2i, conv) -> void:
	var idx := _allocate()
	_idx_map[grid_pos] = idx
	multimesh.set_instance_transform(idx, GridUtils.tile_transform_3d(grid_pos))
	# custom_data: r=variant_row, g=flip_v, b=highlight, a=direction
	multimesh.set_instance_custom_data(idx, Color(5.0, 0.0, 0.0, float(conv.direction)))

func unregister(grid_pos: Vector2i) -> void:
	if _idx_map.has(grid_pos):
		_release(_idx_map[grid_pos])
		_idx_map.erase(grid_pos)

func update_variant(conv) -> void:
	if not _idx_map.has(conv.grid_pos):
		return
	var idx: int = _idx_map[conv.grid_pos]

	var dir_vec := Vector2i(conv.get_direction_vector())
	var back := -dir_vec
	var right_side := Vector2i(-dir_vec.y, dir_vec.x)
	var left_side := Vector2i(dir_vec.y, -dir_vec.x)

	var has_back := _is_feeding(conv.grid_pos, back)
	var has_right := _is_feeding(conv.grid_pos, right_side)
	var has_left := _is_feeding(conv.grid_pos, left_side)

	var variant_row: float = 5.0  # start (default)
	var flip_v: float = 0.0

	if has_right and has_left and has_back:
		variant_row = 4.0  # crossroad
	elif has_right and has_left:
		variant_row = 2.0  # dual_side_input
	elif has_back and has_right:
		variant_row = 3.0  # side_input
	elif has_back and has_left:
		variant_row = 3.0  # side_input
		flip_v = 1.0
	elif has_right and not has_back:
		variant_row = 1.0  # turn
	elif has_left and not has_back:
		variant_row = 1.0  # turn
		flip_v = 1.0
	elif has_back:
		variant_row = 0.0  # straight

	multimesh.set_instance_transform(idx, GridUtils.tile_transform_3d(conv.grid_pos))
	multimesh.set_instance_custom_data(idx, Color(variant_row, flip_v, 0.0, float(conv.direction)))

func update_animation() -> void:
	var cycle_time := FRAME_COUNT / ANIM_FPS
	var global_time := Time.get_ticks_msec() / 1000.0
	var frame: float = float(int(fmod(global_time, cycle_time) * ANIM_FPS) % FRAME_COUNT)
	_material.set_shader_parameter("frame_idx", frame)

func set_highlight(grid_pos: Vector2i, enabled: bool) -> void:
	if not _idx_map.has(grid_pos):
		return
	var idx: int = _idx_map[grid_pos]
	var c: Color = multimesh.get_instance_custom_data(idx)
	c.b = 1.0 if enabled else 0.0
	multimesh.set_instance_custom_data(idx, c)

func clear_all() -> void:
	_free_list = PackedInt32Array()
	_idx_map.clear()
	_capacity = 0
	multimesh.instance_count = 0
	_grow(INITIAL_CAPACITY)

# ── Private ──────────────────────────────────────────────────────────────────

func _create_plane_mesh() -> Mesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1, 1)
	return mesh

func _allocate() -> int:
	if _free_list.is_empty():
		_grow(maxi(_capacity * 2, INITIAL_CAPACITY))
	var idx: int = _free_list[-1]
	_free_list.resize(_free_list.size() - 1)
	return idx

func _release(idx: int) -> void:
	if idx < 0:
		return
	multimesh.set_instance_transform(idx, Transform3D(Basis(), HIDDEN_POS))
	_free_list.append(idx)

func _grow(new_capacity: int) -> void:
	var old := _capacity
	_capacity = new_capacity
	multimesh.instance_count = _capacity
	for i in range(old, _capacity):
		multimesh.set_instance_transform(i, Transform3D(Basis(), HIDDEN_POS))
		_free_list.append(i)

func _is_feeding(grid_pos: Vector2i, dir_offset: Vector2i) -> bool:
	var dir_idx: int
	if dir_offset == Vector2i.RIGHT:
		dir_idx = 0
	elif dir_offset == Vector2i.DOWN:
		dir_idx = 1
	elif dir_offset == Vector2i.LEFT:
		dir_idx = 2
	elif dir_offset == Vector2i.UP:
		dir_idx = 3
	else:
		return false
	return GameManager.has_output_at(grid_pos, dir_idx)


func _create_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform float frame_idx = 0.0;

// Atlas layout: 4 columns (frames) x 6 rows (variants), each cell 64x32
// Total texture: 256x192
const float COLS = 4.0;
const float ROWS = 6.0;
const float DARKEN = 0.3;
const float STRIPE_FREQ = 0.3 / 64.0;
const vec3 STRIPE_RGB = vec3(1.0, 0.3, 0.25);
const float STRIPE_A = 0.15;
const vec4 OUTLINE_COL = vec4(0.8, 0.1, 0.07, 0.85);

varying flat float v_row;
varying flat float v_flip;
varying flat float v_highlight;
varying flat float v_direction;

void vertex() {
	v_row = INSTANCE_CUSTOM.r;
	v_flip = INSTANCE_CUSTOM.g;
	v_highlight = INSTANCE_CUSTOM.b;
	v_direction = INSTANCE_CUSTOM.a;
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	// Rotate UV based on conveyor direction so ridges flow correctly
	// Direction 0=RIGHT (default), 1=DOWN, 2=LEFT, 3=UP
	float dir = v_direction;
	if (dir > 0.5 && dir < 1.5) {
		// DOWN: 90 deg CCW
		float tmp = u;
		u = 1.0 - v;
		v = tmp;
	} else if (dir > 1.5 && dir < 2.5) {
		// LEFT: 180 deg
		u = 1.0 - u;
		v = 1.0 - v;
	} else if (dir > 2.5) {
		// UP: 90 deg CW
		float tmp = u;
		u = v;
		v = 1.0 - tmp;
	}
	if (v_flip > 0.5) v = 1.0 - v;
	float col = floor(frame_idx);
	float row = v_row;
	vec2 atlas_uv = vec2((col + u) / COLS, (row + v) / ROWS);
	vec4 base = texture(atlas, atlas_uv);
	if (base.a < 0.01) discard;
	if (v_highlight > 0.5) {
		vec3 result = base.rgb * (1.0 - DARKEN);
		float w = (FRAGCOORD.x + FRAGCOORD.y) * STRIPE_FREQ + TIME * 2.0;
		float stripe = step(0.5, fract(w));
		result = mix(result, STRIPE_RGB, stripe * STRIPE_A);
		// Edge outline: sample 8 neighbors, treat out-of-cell as transparent
		vec2 cell_min = vec2(col / COLS, row / ROWS);
		vec2 cell_max = vec2((col + 1.0) / COLS, (row + 1.0) / ROWS);
		vec2 ps = vec2(1.0 / (COLS * 64.0), 1.0 / (ROWS * 32.0));
		vec2 offsets[8] = {
			vec2(-ps.x, 0.0), vec2(ps.x, 0.0),
			vec2(0.0, -ps.y), vec2(0.0, ps.y),
			vec2(-2.0*ps.x, 0.0), vec2(2.0*ps.x, 0.0),
			vec2(0.0, -2.0*ps.y), vec2(0.0, 2.0*ps.y)
		};
		float n = 0.0;
		for (int i = 0; i < 8; i++) {
			vec2 s = atlas_uv + offsets[i];
			if (s.x < cell_min.x || s.x > cell_max.x || s.y < cell_min.y || s.y > cell_max.y) {
				n += 0.0; // out-of-cell = transparent
			} else {
				n += step(0.01, texture(atlas, s).a);
			}
		}
		if (n < 7.99) {
			result = mix(result, OUTLINE_COL.rgb, OUTLINE_COL.a);
		}
		base = vec4(result, base.a);
	}
	ALBEDO = base.rgb;
	ALPHA = base.a;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("frame_idx", 0.0)
	mat.set_shader_parameter("atlas", load("res://buildings/conveyor/sprites/straight.png"))
	return mat
