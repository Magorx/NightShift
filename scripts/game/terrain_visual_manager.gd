extends RefCounted

## Renders terrain via three MultiMeshInstance3D layers (bg, fg, misc) using
## an atlas texture and a spatial shader.  Each tile is a PlaneMesh quad on
## the XZ ground plane (Y=0).  Atlas cell selection uses INSTANCE_CUSTOM data
## encoding (atlas_col, atlas_row, tint_r, tint_g).
##
## Atlas layout (8 cols x 15 rows of 64x32 isometric tiles):
##   See ATLAS_INDEX below for the mapping from (tile_type, layer, variant)
##   to flat atlas index.  Row = index / 8, Col = index % 8.

const ATLAS_COLS := 8
const ATLAS_ROWS := 15

# ── Atlas index table ───────────────────────────────────────────────────────
# Maps tile_type -> { "bg": int, "fg": [int...], "misc": [int...] }
# Indices are flat (row * 8 + col) into the 8x15 atlas.

# Tile type constants (match game_world.gd)
const T_GROUND := 0
const T_IRON := 1
const T_COPPER := 2
const T_COAL := 3
const T_WALL := 4
const T_GROUND_DARK := 5
const T_GROUND_LIGHT := 6
const T_STONE := 7
const T_TIN := 8
const T_GOLD := 9
const T_QUARTZ := 10
const T_SULFUR := 11
const T_OIL := 12
const T_CRYSTAL := 13
const T_URANIUM := 14
const T_BIOMASS := 15
const T_ASH := 16

# Grass tint multipliers for the 3 ground variants (applied in shader)
# Normal grass = white (no tint), dark = darker, light = lighter
const GRASS_TINTS := {
	T_GROUND: Color(1.0, 1.0, 1.0, 1.0),
	T_GROUND_DARK: Color(0.84, 0.84, 0.82, 1.0),
	T_GROUND_LIGHT: Color(1.14, 1.14, 1.12, 1.0),
}

# Atlas layout:
# Row 0: grass_bg(0), grass_fg0-5(1-6), grass_misc0(7)
# Row 1: grass_misc1-5(8-12), iron_bg(13), iron_fg0(14), iron_fg1(15)
# Row 2: iron_fg2(16), iron_misc0-2(17-19), copper_bg(20), copper_fg0-2(21-23)
# Row 3: copper_misc0-2(24-26), coal_bg(27), coal_fg0-2(28-30), coal_misc0(31)
# Row 4: coal_misc1-2(32-33), tin_bg(34), tin_fg0-2(35-37), tin_misc0-1(38-39)
# Row 5: tin_misc2(40), gold_bg(41), gold_fg0-2(42-44), gold_misc0-2(45-47)
# Row 6: quartz_bg(48), quartz_fg0-2(49-51), quartz_misc0-2(52-54), sulfur_bg(55)
# Row 7: sulfur_fg0-2(56-58), sulfur_misc0-2(59-61), mud_bg(62), mud_fg0(63)
# Row 8: mud_fg1-2(64-65), mud_misc0-2(66-68), stone_bg(69), stone_fg0-1(70-71)
# Row 9: stone_fg2(72), stone_misc0-2(73-75)
# Row 10: oil_bg(80), oil_fg0-2(81-83), oil_misc0-2(84-86), crystal_bg(87)
# Row 11: crystal_fg0-2(88-90), crystal_misc0-2(91-93), uranium_bg(94), uranium_fg0(95)
# Row 12: uranium_fg1-2(96-97), uranium_misc0-2(98-100), biomass_bg(101), biomass_fg0-1(102-103)
# Row 13: biomass_fg2(104), biomass_misc0-2(105-107), ash_bg(108), ash_fg0-2(109-111)
# Row 14: (ash misc reuses ash bg/fg slots)

const ATLAS := {
	T_GROUND: {"bg": 0, "fg": [1, 2, 3, 4, 5, 6], "misc": [7, 8, 9, 10, 11, 12]},
	T_GROUND_DARK: {"bg": 0, "fg": [1, 2, 3, 4, 5, 6], "misc": [7, 8, 9, 10, 11, 12]},
	T_GROUND_LIGHT: {"bg": 0, "fg": [1, 2, 3, 4, 5, 6], "misc": [7, 8, 9, 10, 11, 12]},
	T_IRON: {"bg": 13, "fg": [14, 15, 16], "misc": [17, 18, 19]},
	T_COPPER: {"bg": 20, "fg": [21, 22, 23], "misc": [24, 25, 26]},
	T_COAL: {"bg": 27, "fg": [28, 29, 30], "misc": [31, 32, 33]},
	T_TIN: {"bg": 34, "fg": [35, 36, 37], "misc": [38, 39, 40]},
	T_GOLD: {"bg": 41, "fg": [42, 43, 44], "misc": [45, 46, 47]},
	T_QUARTZ: {"bg": 48, "fg": [49, 50, 51], "misc": [52, 53, 54]},
	T_SULFUR: {"bg": 55, "fg": [56, 57, 58], "misc": [59, 60, 61]},
	T_WALL: {"bg": 62, "fg": [63, 64, 65], "misc": [66, 67, 68]},
	T_STONE: {"bg": 69, "fg": [70, 71, 72], "misc": [73, 74, 75]},
	T_OIL: {"bg": 80, "fg": [81, 82, 83], "misc": [84, 85, 86]},
	T_CRYSTAL: {"bg": 87, "fg": [88, 89, 90], "misc": [91, 92, 93]},
	T_URANIUM: {"bg": 94, "fg": [95, 96, 97], "misc": [98, 99, 100]},
	T_BIOMASS: {"bg": 101, "fg": [102, 103, 104], "misc": [105, 106, 107]},
	T_ASH: {"bg": 108, "fg": [109, 110, 111], "misc": [108, 109, 110]},
}

var _bg_mm: MultiMesh
var _fg_mm: MultiMesh
var _misc_mm: MultiMesh
var _bg_inst: MultiMeshInstance3D
var _fg_inst: MultiMeshInstance3D
var _misc_inst: MultiMeshInstance3D
var _map_size: int = 0


func attach_to(parent: Node, _z_unused: int = -1) -> void:
	var texture: Texture2D = load("res://resources/sprites/terrain/terrain_atlas.png")
	var shader := _create_shader()
	var mesh := _create_plane_mesh()

	var bg_result := _create_layer(texture, shader, mesh)
	_bg_mm = bg_result[0]
	_bg_inst = bg_result[1]
	_bg_inst.name = "TerrainBG"
	parent.add_child(_bg_inst)

	var fg_result := _create_layer(texture, shader, mesh)
	_fg_mm = fg_result[0]
	_fg_inst = fg_result[1]
	_fg_inst.name = "TerrainFG"
	_fg_inst.position.y = 0.001  # above bg to prevent z-fighting
	parent.add_child(_fg_inst)

	var misc_result := _create_layer(texture, shader, mesh)
	_misc_mm = misc_result[0]
	_misc_inst = misc_result[1]
	_misc_inst.name = "TerrainMisc"
	_misc_inst.position.y = 0.002  # above fg to prevent z-fighting
	parent.add_child(_misc_inst)


## Build terrain for the entire map.  Called once after world generation or
## deserialization.
## tile_types: flat PackedByteArray of map_size*map_size tile type IDs (row-major)
## variants:   flat PackedByteArray of map_size*map_size, low nibble = fg, high nibble = misc
func build(map_size: int, tile_types: PackedByteArray, variants: PackedByteArray) -> void:
	_map_size = map_size
	var count := map_size * map_size

	_init_multimesh(_bg_mm, count)
	_init_multimesh(_fg_mm, count)
	_init_multimesh(_misc_mm, count)

	for y in range(map_size):
		for x in range(map_size):
			var idx := y * map_size + x
			var tile_type: int = tile_types[idx]
			var v: int = variants[idx]
			var fg_var: int = v & 0x0F
			var misc_var: int = (v >> 4) & 0x0F

			var xform := GridUtils.tile_transform(Vector2i(x, y))

			if not ATLAS.has(tile_type):
				# Fallback: use grass
				tile_type = T_GROUND

			var entry: Dictionary = ATLAS[tile_type]

			# Tint for grass variants
			var tint := Color(1, 1, 1, 1)
			if GRASS_TINTS.has(tile_type):
				tint = GRASS_TINTS[tile_type]

			# BG
			var bg_atlas_idx: int = entry["bg"]
			_set_instance(_bg_mm, idx, xform, bg_atlas_idx, tint)

			# FG
			var fg_arr: Array = entry["fg"]
			var fg_idx: int = fg_var % fg_arr.size()
			_set_instance(_fg_mm, idx, xform, fg_arr[fg_idx], tint)

			# Misc
			var misc_arr: Array = entry["misc"]
			var misc_idx: int = misc_var % misc_arr.size()
			_set_instance(_misc_mm, idx, xform, misc_arr[misc_idx], tint)


## Update a single cell's terrain visuals (e.g. when biomass becomes ash).
func update_cell(map_size: int, x: int, y: int, tile_type: int, fg_var: int, misc_var: int) -> void:
	if _map_size == 0 or not _bg_mm:
		return
	var idx := y * map_size + x
	if idx < 0 or idx >= _bg_mm.instance_count:
		return
	var actual_type := tile_type
	if not ATLAS.has(actual_type):
		actual_type = T_GROUND
	var entry: Dictionary = ATLAS[actual_type]
	var tint := Color(1, 1, 1, 1)
	if GRASS_TINTS.has(actual_type):
		tint = GRASS_TINTS[actual_type]
	var xform := GridUtils.tile_transform(Vector2i(x, y))
	_set_instance(_bg_mm, idx, xform, entry["bg"], tint)
	var fg_arr: Array = entry["fg"]
	_set_instance(_fg_mm, idx, xform, fg_arr[fg_var % fg_arr.size()], tint)
	var misc_arr: Array = entry["misc"]
	_set_instance(_misc_mm, idx, xform, misc_arr[misc_var % misc_arr.size()], tint)


func clear() -> void:
	if _bg_mm:
		_bg_mm.instance_count = 0
	if _fg_mm:
		_fg_mm.instance_count = 0
	if _misc_mm:
		_misc_mm.instance_count = 0
	_map_size = 0


# ── Private ──────────────────────────────────────────────────────────────────

## Create a 1x1 PlaneMesh lying flat on XZ (Y=0), facing up.
func _create_plane_mesh() -> Mesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1, 1)
	return mesh


func _create_layer(texture: Texture2D, shader: Shader, mesh: Mesh) -> Array:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh

	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("atlas", texture)
	inst.material_override = mat

	return [mm, inst]


func _init_multimesh(mm: MultiMesh, count: int) -> void:
	mm.instance_count = count


func _set_instance(mm: MultiMesh, idx: int, xform: Transform3D, atlas_idx: int, tint: Color) -> void:
	mm.set_instance_transform(idx, xform)
	@warning_ignore("integer_division")
	var col: float = float(atlas_idx % ATLAS_COLS)
	@warning_ignore("integer_division")
	var row: float = float(atlas_idx / ATLAS_COLS)
	# Pack atlas col, row, and tint brightness into custom data
	mm.set_instance_custom_data(idx, Color(col, row, tint.r, tint.g))


func _create_shader() -> Shader:
	var shader := Shader.new()
	shader.code = "shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D atlas : source_color, filter_nearest;

// Terrain atlas: 8 columns x 15 rows of 64x32 isometric tiles
const float COLS = 8.0;
const float ROWS = 15.0;

varying flat float v_col;
varying flat float v_row;
varying flat float v_tint_r;
varying flat float v_tint_g;

void vertex() {
	v_col = INSTANCE_CUSTOM.r;
	v_row = INSTANCE_CUSTOM.g;
	v_tint_r = INSTANCE_CUSTOM.b;
	v_tint_g = INSTANCE_CUSTOM.a;
}

void fragment() {
	vec2 atlas_uv = vec2((v_col + UV.x) / COLS, (v_row + UV.y) / ROWS);
	vec4 tex = texture(atlas, atlas_uv);
	if (tex.a < 0.01) discard;
	// Apply grass tint (non-grass tiles pass 1.0, 1.0 = no change)
	tex.rgb *= vec3(v_tint_r, v_tint_g, v_tint_r);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}
"
	return shader
