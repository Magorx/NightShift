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
const WALL_DARKEN := 0.7  # side walls are darker for depth cue

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


## Get a HeightMapShape3D for smooth walkable collision.
## Visual mesh stays blocky; collision uses smooth ramps between height levels
## so CharacterBody3D can walk up/down naturally.
## Returns [shape: HeightMapShape3D, body_position: Vector3].
func create_heightmap_collision() -> Array:
	if _map_size == 0 or _heights.is_empty():
		return []

	var map_size := _map_size
	var vw: int = map_size + 1  # vertex count along each axis
	var map_data := PackedFloat32Array()
	map_data.resize(vw * vw)

	# Each vertex is at a tile corner. Set height to max of adjacent tiles
	# so the player walks on the higher surface at transitions.
	for vz in range(vw):
		for vx in range(vw):
			var max_h: float = 0.0
			# Check the 4 tiles that share this corner
			for dx in [-1, 0]:
				for dz in [-1, 0]:
					var tx: int = vx + dx
					var tz: int = vz + dz
					if tx >= 0 and tx < map_size and tz >= 0 and tz < map_size:
						var h: float = _heights[tz * map_size + tx]
						max_h = maxf(max_h, h)
			map_data[vz * vw + vx] = max_h

	var shape := HeightMapShape3D.new()
	shape.map_width = vw
	shape.map_depth = vw
	shape.map_data = map_data

	# Position the body so vertex (0,0) maps to world (-0.5, -0.5)
	# HeightMapShape3D vertices span [-(vw-1)/2, (vw-1)/2]
	# Vertex (0,0) is at local (-(vw-1)/2, -(vw-1)/2)
	# We want it at world (-0.5, -0.5)
	# So body position = (-0.5 - (-(vw-1)/2), 0, -0.5 - (-(vw-1)/2))
	#                   = (-0.5 + map_size/2, 0, -0.5 + map_size/2)
	var half := float(map_size) / 2.0
	var body_pos := Vector3(half - 0.5, 0.0, half - 0.5)

	return [shape, body_pos]


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
	var wall_col := Color(col.r * WALL_DARKEN, col.g * WALL_DARKEN, col.b * WALL_DARKEN)

	# Neighbor offsets: [dx, dz, and the 4 corner vertices of the wall quad]
	# For each direction, we emit a wall from this tile's height down to the neighbor's height
	var neighbors := [
		[1, 0],   # +X
		[-1, 0],  # -X
		[0, 1],   # +Z
		[0, -1],  # -Z
	]

	for n in neighbors:
		var nx: int = x + n[0]
		var nz: int = y + n[1]

		# Neighbor height (out-of-bounds = 0, so edges get walls)
		var nh: float = 0.0
		if nx >= 0 and nx < map_size and nz >= 0 and nz < map_size:
			nh = _heights[nz * map_size + nx]

		if h <= nh:
			continue  # no wall needed

		# Wall quad from nh to h on the edge between this tile and neighbor
		_add_wall_quad(st, x, y, h, nh, n[0], n[1], wall_col)


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


func _create_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
