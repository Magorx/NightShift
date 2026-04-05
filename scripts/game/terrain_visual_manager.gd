extends RefCounted

## Renders terrain as flat colored quads via a single MultiMeshInstance3D.
## Each tile is a PlaneMesh on the XZ ground plane (Y=0).  INSTANCE_CUSTOM
## encodes an RGB color directly (packed into r, g, b channels).
##
## Replaces the old atlas-based 3-layer approach.  Visual variety now comes
## from 3D deposit decorations rather than tile sprite details.

# ── Tile color palette ──────────────────────────────────────────────────────
# Indexed by TileDatabase tile type ID (0-8).  Any unknown type falls back
# to TILE_GROUND color.

const TILE_COLORS := {
	0: Color(0.35, 0.50, 0.30),   # TILE_GROUND       — base green
	1: Color(0.55, 0.35, 0.25),   # TILE_PYROMITE      — reddish brown
	2: Color(0.35, 0.50, 0.60),   # TILE_CRYSTALLINE   — blue-grey
	3: Color(0.30, 0.50, 0.25),   # TILE_BIOVINE       — organic green
	4: Color(0.40, 0.38, 0.35),   # TILE_WALL          — stone grey
	5: Color(0.30, 0.43, 0.26),   # TILE_GROUND_DARK   — darker green
	6: Color(0.40, 0.55, 0.35),   # TILE_GROUND_LIGHT  — lighter green
	7: Color(0.50, 0.48, 0.42),   # TILE_STONE         — light stone
	8: Color(0.50, 0.45, 0.40),   # TILE_ASH           — ashy brown
}

const DEFAULT_COLOR := Color(0.35, 0.50, 0.30)

var _mm: MultiMesh
var _inst: MultiMeshInstance3D
var _map_size: int = 0


func attach_to(parent: Node, _z_unused: int = -1) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1, 1)

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = mesh

	_inst = MultiMeshInstance3D.new()
	_inst.multimesh = _mm
	_inst.name = "Terrain"
	_inst.material_override = _create_material()
	parent.add_child(_inst)


## Build terrain for the entire map.  Called once after world generation or
## deserialization.
## tile_types: flat PackedByteArray of map_size*map_size tile type IDs (row-major)
## variants:   kept for signature compatibility but unused by flat-color rendering
func build(map_size: int, tile_types: PackedByteArray, _variants: PackedByteArray) -> void:
	_map_size = map_size
	var count := map_size * map_size
	_mm.instance_count = count

	for y in range(map_size):
		for x in range(map_size):
			var idx := y * map_size + x
			var tile_type: int = tile_types[idx]
			var xform := GridUtils.tile_transform(Vector2i(x, y))
			var col: Color = TILE_COLORS.get(tile_type, DEFAULT_COLOR)
			_mm.set_instance_transform(idx, xform)
			_mm.set_instance_custom_data(idx, col)


## Update a single cell's terrain visuals (e.g. when a deposit becomes ash).
func update_cell(map_size: int, x: int, y: int, tile_type: int, _fg_var: int, _misc_var: int) -> void:
	if _map_size == 0 or not _mm:
		return
	var idx := y * map_size + x
	if idx < 0 or idx >= _mm.instance_count:
		return
	var xform := GridUtils.tile_transform(Vector2i(x, y))
	var col: Color = TILE_COLORS.get(tile_type, DEFAULT_COLOR)
	_mm.set_instance_transform(idx, xform)
	_mm.set_instance_custom_data(idx, col)


func clear() -> void:
	if _mm:
		_mm.instance_count = 0
	_map_size = 0


# ── Private ──────────────────────────────────────────────────────────────────

func _create_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type spatial;
render_mode unshaded, cull_disabled;

varying flat vec3 v_color;

void vertex() {
	v_color = vec3(INSTANCE_CUSTOM.r, INSTANCE_CUSTOM.g, INSTANCE_CUSTOM.b);
}

void fragment() {
	ALBEDO = v_color;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
