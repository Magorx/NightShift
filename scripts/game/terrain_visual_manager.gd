extends RefCounted

## Renders terrain as elevated blocks via a single ArrayMesh.
## Each tile gets a top face at its terrain height, plus vertical side-wall
## quads wherever adjacent tiles have a lower height.  Colors come from
## TILE_COLORS; walls use a darkened variant of the top color for depth.

# ── Tile color palette ──────────────────────────────────────────────────────
# Indexed by TileDatabase tile type ID (0-8).

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

# Per-direction wall darkening (simulates directional light, makes corners visible)
const WALL_DARKEN_PX := 0.42  # +X wall (right side, darkest)
const WALL_DARKEN_NX := 0.62  # -X wall (left side)
const WALL_DARKEN_PZ := 0.48  # +Z wall (front-facing in iso view)
const WALL_DARKEN_NZ := 0.72  # -Z wall (back-facing, lightest)

var _mesh_instance: MeshInstance3D
var _map_size: int = 0

# Cached data for update_cell
var _tile_types: PackedByteArray
var _heights: PackedFloat32Array


func attach_to(parent: Node, _z_unused: int = -1) -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Terrain"
	_mesh_instance.material_override = _create_material()
	parent.add_child(_mesh_instance)


## Build terrain mesh for the entire map.
## tile_types: flat PackedByteArray of tile type IDs (row-major)
## heights:    flat PackedFloat32Array of elevation per cell (row-major)
func build(map_size: int, tile_types: PackedByteArray, _variants: PackedByteArray, heights: PackedFloat32Array = PackedFloat32Array()) -> void:
	_map_size = map_size
	_tile_types = tile_types
	_heights = heights

	# If no heights provided, use flat terrain
	if _heights.is_empty():
		_heights.resize(map_size * map_size)
		_heights.fill(0.0)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for y in range(map_size):
		for x in range(map_size):
			var idx := y * map_size + x
			var h: float = _heights[idx]
			var tile_type: int = tile_types[idx]
			var col: Color = TILE_COLORS.get(tile_type, DEFAULT_COLOR)

			# ── Top face (XZ quad at height h) ──
			_add_top_face(st, x, y, h, col)

			# ── Side walls (where this tile is higher than neighbor) ──
			# Check 4 neighbors: +X, -X, +Z, -Z
			_add_side_walls(st, x, y, h, col, map_size)

	st.generate_normals()
	var mesh := st.commit()
	_mesh_instance.mesh = mesh


## Update a single cell's terrain visuals.
## Rebuilds the entire mesh (needed for correctness with side walls).
func update_cell(map_size: int, x: int, y: int, tile_type: int, _fg_var: int, _misc_var: int) -> void:
	if _map_size == 0 or _tile_types.is_empty():
		return
	var idx := y * map_size + x
	if idx < 0 or idx >= _tile_types.size():
		return
	_tile_types[idx] = tile_type
	# Rebuild mesh (side walls depend on neighbors)
	build(map_size, _tile_types, PackedByteArray(), _heights)


func clear() -> void:
	if _mesh_instance and _mesh_instance.mesh:
		_mesh_instance.mesh = null
	_map_size = 0
	_tile_types = PackedByteArray()
	_heights = PackedFloat32Array()


## Build a ConcavePolygonShape3D with flat top faces + vertical wall faces.
## No ramps — each tile is a flat platform, walls block at height transitions.
## Wall normals face outward from the higher tile (toward the lower side),
## so the player is blocked approaching from below but can walk off edges
## going down (backface_collision = false).
func create_box_collision() -> ConcavePolygonShape3D:
	if _map_size == 0 or _heights.is_empty():
		return null

	var map_size := _map_size
	var faces := PackedVector3Array()

	for y_pos in range(map_size):
		for x_pos in range(map_size):
			var idx := y_pos * map_size + x_pos
			var h: float = _heights[idx]
			var x0 := float(x_pos) - 0.5
			var x1 := float(x_pos) + 0.5
			var z0 := float(y_pos) - 0.5
			var z1 := float(y_pos) + 0.5

			# ── Top face (CCW from above → normal UP) ──
			faces.append(Vector3(x0, h, z0))
			faces.append(Vector3(x0, h, z1))
			faces.append(Vector3(x1, h, z1))

			faces.append(Vector3(x0, h, z0))
			faces.append(Vector3(x1, h, z1))
			faces.append(Vector3(x1, h, z0))

			# ── Wall faces at height transitions ──
			# Only where this tile is higher than the neighbor.
			# Normal faces outward (toward the lower neighbor).
			var neighbors := [[1, 0], [-1, 0], [0, 1], [0, -1]]
			for n in neighbors:
				var nx: int = x_pos + n[0]
				var nz: int = y_pos + n[1]
				var nh: float = 0.0
				if nx >= 0 and nx < map_size and nz >= 0 and nz < map_size:
					nh = _heights[nz * map_size + nx]
				if h <= nh:
					continue
				# Wall quad from nh up to h
				var wx0: float; var wx1: float; var wz0: float; var wz1: float
				if n[0] == 1:    # +X wall
					wx0 = x1; wx1 = x1; wz0 = z0; wz1 = z1
				elif n[0] == -1: # -X wall
					wx0 = x0; wx1 = x0; wz0 = z1; wz1 = z0
				elif n[1] == 1:  # +Z wall
					wx0 = x1; wx1 = x0; wz0 = z1; wz1 = z1
				else:            # -Z wall
					wx0 = x0; wx1 = x1; wz0 = z0; wz1 = z0
				# Two triangles (outward-facing normal)
				faces.append(Vector3(wx0, h, wz0))
				faces.append(Vector3(wx1, h, wz1))
				faces.append(Vector3(wx1, nh, wz1))
				faces.append(Vector3(wx0, h, wz0))
				faces.append(Vector3(wx1, nh, wz1))
				faces.append(Vector3(wx0, nh, wz0))

	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	return shape


# ── Private ──────────────────────────────────────────────────────────────────

func _add_top_face(st: SurfaceTool, x: int, y: int, h: float, col: Color) -> void:
	var x0 := float(x) - 0.5
	var x1 := float(x) + 0.5
	var z0 := float(y) - 0.5
	var z1 := float(y) + 0.5

	st.set_color(col)

	# Counter-clockwise winding from above → normals point UP (+Y)
	# Triangle 1
	st.add_vertex(Vector3(x0, h, z0))
	st.add_vertex(Vector3(x0, h, z1))
	st.add_vertex(Vector3(x1, h, z1))

	# Triangle 2
	st.add_vertex(Vector3(x0, h, z0))
	st.add_vertex(Vector3(x1, h, z1))
	st.add_vertex(Vector3(x1, h, z0))


func _add_side_walls(st: SurfaceTool, x: int, y: int, h: float, col: Color, map_size: int) -> void:
	# Each direction gets its own darkening factor for directional shading
	var dir_darken := [
		[1, 0, WALL_DARKEN_PX],
		[-1, 0, WALL_DARKEN_NX],
		[0, 1, WALL_DARKEN_PZ],
		[0, -1, WALL_DARKEN_NZ],
	]

	for entry in dir_darken:
		var dx: int = entry[0]
		var dz: int = entry[1]
		var darken: float = entry[2]
		var nx: int = x + dx
		var nz: int = y + dz

		# Neighbor height (out-of-bounds = 0, so edges get walls)
		var nh: float = 0.0
		if nx >= 0 and nx < map_size and nz >= 0 and nz < map_size:
			nh = _heights[nz * map_size + nx]

		if h <= nh:
			continue  # no wall needed

		var wall_col := Color(col.r * darken, col.g * darken, col.b * darken)
		_add_wall_quad(st, x, y, h, nh, dx, dz, wall_col)


func _add_wall_quad(st: SurfaceTool, x: int, y: int, h_top: float, h_bottom: float, dx: int, dz: int, col: Color) -> void:
	st.set_color(col)

	# Determine the edge of this tile facing the neighbor
	var x0: float
	var x1: float
	var z0: float
	var z1: float

	if dx == 1:  # +X face
		x0 = float(x) + 0.5
		x1 = float(x) + 0.5
		z0 = float(y) - 0.5
		z1 = float(y) + 0.5
	elif dx == -1:  # -X face
		x0 = float(x) - 0.5
		x1 = float(x) - 0.5
		z0 = float(y) + 0.5
		z1 = float(y) - 0.5
	elif dz == 1:  # +Z face
		x0 = float(x) + 0.5
		x1 = float(x) - 0.5
		z0 = float(y) + 0.5
		z1 = float(y) + 0.5
	else:  # -Z face
		x0 = float(x) - 0.5
		x1 = float(x) + 0.5
		z0 = float(y) - 0.5
		z1 = float(y) - 0.5

	# Two triangles for the wall quad (top-left, top-right, bottom-right, bottom-left)
	# Triangle 1: top-left, top-right, bottom-right
	st.add_vertex(Vector3(x0, h_top, z0))
	st.add_vertex(Vector3(x1, h_top, z1))
	st.add_vertex(Vector3(x1, h_bottom, z1))

	# Triangle 2: top-left, bottom-right, bottom-left
	st.add_vertex(Vector3(x0, h_top, z0))
	st.add_vertex(Vector3(x1, h_bottom, z1))
	st.add_vertex(Vector3(x0, h_bottom, z0))


func _create_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = "shader_type spatial;
render_mode unshaded, cull_disabled;

varying vec3 v_color;
varying vec3 v_world_pos;
varying vec3 v_normal;

void vertex() {
	v_color = COLOR.rgb;
	v_world_pos = VERTEX;  // terrain mesh is at origin
	v_normal = NORMAL;
}

void fragment() {
	vec3 col = v_color;
	// Top faces only: draw thin dark border lines at tile boundaries
	if (v_normal.y > 0.5) {
		float edge_x = abs(fract(v_world_pos.x + 0.5) - 0.5);
		float edge_z = abs(fract(v_world_pos.z + 0.5) - 0.5);
		float edge = max(edge_x, edge_z);
		float line = smoothstep(0.42, 0.50, edge);
		col *= mix(1.0, 0.72, line);
	}
	ALBEDO = col;
}
"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
