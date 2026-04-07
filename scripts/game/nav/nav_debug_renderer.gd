class_name NavDebugRenderer
extends Node3D

## Visualises the hierarchical nav system at runtime.
##
## What you see (only when SettingsManager.debug_mode is on):
##  - Sector borders as thin rectangle outlines, drawn just above the ground.
##    Default colour is muted grey.
##    YELLOW flash = sector's local walkable mask was just rebuilt (dirty
##                   sector flush from a building placement / removal).
##    CYAN flash   = a per-sector flow field was just (re)computed in this
##                   sector (lazy on-demand BFS).
##    Flashes fade out over FLASH_DURATION_MSEC.
##
##  - Flow field arrows for every cached per-sector flow field, sub-sampled
##    every ARROW_STRIDE sub-cells to keep the line count manageable. Each
##    arrow is a short line from the cell centre along the gradient direction,
##    coloured by goal type:
##        GREEN = factory goal
##        RED   = chase goal
##        WHITE = anything else (custom goals from new code paths)
##
## Performance: redrawn at REDRAW_INTERVAL_MSEC cadence (~60 ms = ~16 fps for
## the debug overlay) regardless of game framerate, so it never bottlenecks
## the main render loop. Two ImmediateMeshes are reused — no per-frame allocs.

const FLASH_DURATION_MSEC := 600
const REDRAW_INTERVAL_MSEC := 60
const ARROW_STRIDE := 2          ## sample every Nth sub-cell when drawing arrows
const ARROW_LENGTH := 0.35       ## world units; sub_cell is 0.5 units, this fits
const SECTOR_LINE_Y := 0.08      ## above ground, below most buildings
const ARROW_LINE_Y := 0.10
const SUB_CELL := 2

const COLOR_SECTOR_IDLE := Color(0.45, 0.45, 0.45, 0.55)
const COLOR_SECTOR_WALKABLE_FLASH := Color(1.0, 0.85, 0.0, 1.0)
const COLOR_SECTOR_FLOW_FLASH := Color(0.1, 0.85, 1.0, 1.0)
const COLOR_FACTORY_ARROW := Color(0.30, 1.00, 0.40, 0.85)
const COLOR_CHASE_ARROW := Color(1.00, 0.35, 0.35, 0.85)
const COLOR_OTHER_ARROW := Color(1.00, 1.00, 1.00, 0.85)

# ── References ──────────────────────────────────────────────────────────────
var pathfinding: MonsterPathfinding

# ── Mesh / material setup ───────────────────────────────────────────────────
var _sectors_mesh: ImmediateMesh
var _arrows_mesh: ImmediateMesh
var _sectors_inst: MeshInstance3D
var _arrows_inst: MeshInstance3D
var _last_redraw_msec: int = 0

func _ready() -> void:
	top_level = true  # render in world space regardless of parent transform
	visible = SettingsManager.debug_mode
	SettingsManager.debug_mode_changed.connect(_on_debug_changed)

	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	line_mat.no_depth_test = true
	line_mat.vertex_color_use_as_albedo = true
	line_mat.albedo_color = Color.WHITE
	line_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_sectors_mesh = ImmediateMesh.new()
	_sectors_inst = MeshInstance3D.new()
	_sectors_inst.name = "SectorBorders"
	_sectors_inst.mesh = _sectors_mesh
	_sectors_inst.material_override = line_mat
	add_child(_sectors_inst)

	_arrows_mesh = ImmediateMesh.new()
	_arrows_inst = MeshInstance3D.new()
	_arrows_inst.name = "FlowArrows"
	_arrows_inst.mesh = _arrows_mesh
	_arrows_inst.material_override = line_mat
	add_child(_arrows_inst)

func _on_debug_changed(enabled: bool) -> void:
	visible = enabled
	if not enabled:
		_sectors_mesh.clear_surfaces()
		_arrows_mesh.clear_surfaces()

func _process(_delta: float) -> void:
	if not visible or pathfinding == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_redraw_msec < REDRAW_INTERVAL_MSEC:
		return
	_last_redraw_msec = now
	_redraw(now)

# ────────────────────────────────────────────────────────────────────────────
# Redraw
# ────────────────────────────────────────────────────────────────────────────

func _redraw(now_msec: int) -> void:
	var layer: GroundNavLayer = pathfinding.ground
	if layer == null or layer.num_sectors == 0:
		return

	_redraw_sector_borders(layer, now_msec)
	_redraw_flow_arrows(layer)

func _redraw_sector_borders(layer: GroundNavLayer, now_msec: int) -> void:
	_sectors_mesh.clear_surfaces()
	_sectors_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var sector_world_size: float = float(NavLayer.SECTOR_SUB_SIZE) / float(SUB_CELL)

	for sector in layer.sectors:
		var color: Color = _sector_color(sector, now_msec)
		var x0: float = float(sector.sub_origin.x) / float(SUB_CELL)
		var z0: float = float(sector.sub_origin.y) / float(SUB_CELL)
		var x1: float = x0 + sector_world_size
		var z1: float = z0 + sector_world_size
		var y: float = SECTOR_LINE_Y

		var v00 := Vector3(x0, y, z0)
		var v10 := Vector3(x1, y, z0)
		var v11 := Vector3(x1, y, z1)
		var v01 := Vector3(x0, y, z1)
		# Four edges as separate line pairs
		_add_line(_sectors_mesh, v00, v10, color)
		_add_line(_sectors_mesh, v10, v11, color)
		_add_line(_sectors_mesh, v11, v01, color)
		_add_line(_sectors_mesh, v01, v00, color)

	_sectors_mesh.surface_end()

func _sector_color(sector: NavSector, now_msec: int) -> Color:
	var walk_age: int = now_msec - sector.last_walkable_rebuild_msec
	var flow_age: int = now_msec - sector.last_flow_compute_msec

	# Walkable rebuild flash takes priority — it's the rarer / more meaningful event
	if sector.last_walkable_rebuild_msec > 0 and walk_age < FLASH_DURATION_MSEC:
		var t: float = 1.0 - float(walk_age) / float(FLASH_DURATION_MSEC)
		return COLOR_SECTOR_IDLE.lerp(COLOR_SECTOR_WALKABLE_FLASH, t)
	if sector.last_flow_compute_msec > 0 and flow_age < FLASH_DURATION_MSEC:
		var t: float = 1.0 - float(flow_age) / float(FLASH_DURATION_MSEC)
		return COLOR_SECTOR_IDLE.lerp(COLOR_SECTOR_FLOW_FLASH, t)
	return COLOR_SECTOR_IDLE

func _redraw_flow_arrows(layer: GroundNavLayer) -> void:
	_arrows_mesh.clear_surfaces()
	if layer.flow_field_cache.is_empty():
		return
	_arrows_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	var sub_to_world: float = 1.0 / float(SUB_CELL)
	var stride: int = ARROW_STRIDE

	for cache_key in layer.flow_field_cache.keys():
		var key_str: String = cache_key
		var ff: FlowField = layer.flow_field_cache[cache_key] as FlowField
		if ff == null:
			continue

		# cache_key format: "<goal_key>:<sector_idx>"
		var sep: int = key_str.rfind(":")
		if sep < 0:
			continue
		var goal_key_str: String = key_str.substr(0, sep)
		var sector_idx_str: String = key_str.substr(sep + 1)
		var sector_idx: int = sector_idx_str.to_int()
		if sector_idx < 0 or sector_idx >= layer.sectors.size():
			continue
		var sector: NavSector = layer.sectors[sector_idx]
		var color: Color = _arrow_color_for_goal(goal_key_str)

		var sz: int = ff.size
		var ox: int = sector.sub_origin.x
		var oz: int = sector.sub_origin.y

		var ly: int = 0
		while ly < sz:
			var lx: int = 0
			while lx < sz:
				var idx: int = ly * sz + lx
				var dir: Vector2 = ff.directions[idx]
				if dir.length_squared() > 0.001:
					var cx: float = float(ox + lx) * sub_to_world + sub_to_world * 0.5
					var cz: float = float(oz + ly) * sub_to_world + sub_to_world * 0.5
					var hx: float = cx + dir.x * ARROW_LENGTH
					var hz: float = cz + dir.y * ARROW_LENGTH
					var start := Vector3(cx, ARROW_LINE_Y, cz)
					var head := Vector3(hx, ARROW_LINE_Y, hz)
					_add_line(_arrows_mesh, start, head, color)
					_add_arrow_head(_arrows_mesh, start, head, color)
				lx += stride
			ly += stride

	_arrows_mesh.surface_end()

func _arrow_color_for_goal(goal_key: String) -> Color:
	if goal_key == String(MonsterPathfinding.GOAL_FACTORY):
		return COLOR_FACTORY_ARROW
	if goal_key == String(MonsterPathfinding.GOAL_CHASE):
		return COLOR_CHASE_ARROW
	return COLOR_OTHER_ARROW

func _add_line(mesh: ImmediateMesh, a: Vector3, b: Vector3, color: Color) -> void:
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(a)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(b)

## Draw two short lines forming a >-shaped arrowhead at b, opening back toward a.
func _add_arrow_head(mesh: ImmediateMesh, a: Vector3, b: Vector3, color: Color) -> void:
	var dir := b - a
	var len: float = dir.length()
	if len < 0.001:
		return
	dir /= len
	# Perpendicular in the XZ plane
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var head_size: float = len * 0.4
	var p1 := b - dir * head_size + perp * head_size * 0.5
	var p2 := b - dir * head_size - perp * head_size * 0.5
	_add_line(mesh, b, p1, color)
	_add_line(mesh, b, p2, color)
