class_name NavDebugRenderer
extends Node3D

## Debug overlay for the GroundNavLayer. Draws sector borders, portal lines,
## and per-tile flow field arrows when SettingsManager.debug_mode is on.
##
## Lives as a child of MonsterSpawner. The spawner assigns the shared
## `pathfinding: MonsterPathfinding` reference so the renderer can reach into
## the ground nav layer directly.
##
## Rendering budget:
##   - Two ImmediateMesh instances reused across redraws — no per-frame
##     allocations, one draw call per mesh.
##   - Redraw throttled to every ~60 ms wall-clock so the overlay never
##     bottlenecks the render loop.
##   - All drawing short-circuits when debug_mode is off, leaving both meshes
##     cleared.
##
## Color scheme:
##   - Sector borders: idle grey, flash YELLOW on walkable rebuild, flash
##     CYAN on flow field compute. Both flashes fade over 600 ms.
##   - Portals: MAGENTA lines between each (a_tile, b_tile) pair. An arrow
##     head at one end signals a directed portal (descent-only cliff).
##     Bidirectional portals are drawn as plain lines with no arrow.
##   - Flow arrows: GREEN for GOAL_FACTORY, RED for GOAL_CHASE, WHITE for
##     anything else. Arrows are drawn by calling `layer.sample_flow()` on an
##     N×N sub-grid inside each tile of every sector that already has a
##     cached flow field — i.e. exactly what a monster standing at that world
##     position would receive, edge-gated bilinear blend included. Sampling
##     at integer tile centres would collapse the blend to the raw per-tile
##     direction, so the sub-grid is what makes the blend visible.

const REDRAW_INTERVAL_MSEC := 60
const FLASH_DURATION_MSEC := 600.0
const BORDER_Y := 0.08
const ARROW_Y := 0.10
const PORTAL_Y := 0.09
## Number of flow samples per axis inside each tile (so SAMPLES_PER_TILE² per
## tile). 2 ⇒ 4 arrows per tile at offsets ±0.25 from the tile centre.
const SAMPLES_PER_TILE := 2
const ARROW_LENGTH := 0.30
const ARROW_HEAD_LENGTH := 0.12

const COLOR_BORDER_IDLE := Color(0.35, 0.35, 0.40, 0.8)
const COLOR_BORDER_FLASH_WALKABLE := Color(1.0, 1.0, 0.15, 1.0)
const COLOR_BORDER_FLASH_FLOW := Color(0.15, 0.95, 1.0, 1.0)
const COLOR_PORTAL := Color(0.95, 0.20, 0.95, 1.0)
const COLOR_PORTAL_DIRECTED := Color(1.0, 0.55, 0.10, 1.0)
const COLOR_FLOW_FACTORY := Color(0.25, 0.95, 0.35, 0.95)
const COLOR_FLOW_CHASE := Color(1.0, 0.25, 0.25, 0.95)
const COLOR_FLOW_OTHER := Color(0.95, 0.95, 0.95, 0.95)
const COLOR_UNREACHED := Color(1.0, 0.15, 0.15, 0.65)

var pathfinding  # MonsterPathfinding — assigned by the spawner

var _lines_mesh: ImmediateMesh
var _lines_instance: MeshInstance3D
var _arrows_mesh: ImmediateMesh
var _arrows_instance: MeshInstance3D
var _last_redraw_msec: int = 0


func _ready() -> void:
	_setup_mesh_instances()
	SettingsManager.debug_mode_changed.connect(_on_debug_mode_changed)
	_refresh_visibility()


func _setup_mesh_instances() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_lines_mesh = ImmediateMesh.new()
	_lines_instance = MeshInstance3D.new()
	_lines_instance.mesh = _lines_mesh
	_lines_instance.material_override = mat
	_lines_instance.name = "NavDebugLines"
	_lines_instance.top_level = true
	add_child(_lines_instance)

	_arrows_mesh = ImmediateMesh.new()
	_arrows_instance = MeshInstance3D.new()
	_arrows_instance.mesh = _arrows_mesh
	_arrows_instance.material_override = mat
	_arrows_instance.name = "NavDebugArrows"
	_arrows_instance.top_level = true
	add_child(_arrows_instance)


func _on_debug_mode_changed(_enabled: bool) -> void:
	_refresh_visibility()
	if not _enabled:
		_clear_meshes()


func _refresh_visibility() -> void:
	var on := SettingsManager.debug_mode
	if _lines_instance:
		_lines_instance.visible = on
	if _arrows_instance:
		_arrows_instance.visible = on


func _process(_delta: float) -> void:
	if not SettingsManager.debug_mode:
		return
	var now := Time.get_ticks_msec()
	if now - _last_redraw_msec < REDRAW_INTERVAL_MSEC:
		return
	_last_redraw_msec = now
	_redraw()


# ────────────────────────────────────────────────────────────────────────────
# Redraw
# ────────────────────────────────────────────────────────────────────────────

func _redraw() -> void:
	_clear_meshes()
	if pathfinding == null:
		return
	var layer: GroundNavLayer = pathfinding.ground if "ground" in pathfinding else null
	if layer == null or layer.map_size <= 0:
		return

	_draw_sector_borders_and_portals(layer)
	_draw_flow_arrows(layer)


func _clear_meshes() -> void:
	if _lines_mesh:
		_lines_mesh.clear_surfaces()
	if _arrows_mesh:
		_arrows_mesh.clear_surfaces()


# ── Sector borders + portal lines (shared LINES surface) ────────────────────

func _draw_sector_borders_and_portals(layer: GroundNavLayer) -> void:
	if layer.sectors.is_empty():
		return
	_lines_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var now := float(Time.get_ticks_msec())

	# Sector borders, colour-flashed on recent rebuild / flow compute.
	# UNREACHED sectors (no portal path to the factory goal) get a red X cross
	# drawn across their interior so you can spot isolation at a glance.
	var factory_g = layer.goals.get(&"factory")
	for s in layer.sectors:
		if s == null:
			continue
		var color := _sector_border_color(s, now)
		var x0 := float(s.x0) - 0.5
		var y0 := float(s.y0) - 0.5
		var x1 := float(s.x1) - 0.5
		var y1 := float(s.y1) - 0.5
		_line(x0, y0, x1, y0, color)
		_line(x1, y0, x1, y1, color)
		_line(x1, y1, x0, y1, color)
		_line(x0, y1, x0, y0, color)
		if factory_g != null \
				and factory_g.sector_distance.size() > s.idx \
				and factory_g.sector_distance[s.idx] == GroundNavLayer.UNREACHED:
			_line(x0, y0, x1, y1, COLOR_UNREACHED)
			_line(x1, y0, x0, y1, COLOR_UNREACHED)

	# Portals: one line per (a_tile, b_tile) pair in the portal's run.
	# Bidirectional portals get plain magenta lines. Directed portals (one-way
	# descent across a cliff) get an orange line with an arrowhead indicating
	# the ALLOWED travel direction.
	for p in layer.portals:
		if p == null:
			continue
		_draw_portal(layer, p)

	_lines_mesh.surface_end()


func _sector_border_color(s, now_msec: float) -> Color:
	var walk_age := now_msec - float(s.last_walkable_rebuild_msec)
	var flow_age := now_msec - float(s.last_flow_compute_msec)
	if s.last_walkable_rebuild_msec > 0 and walk_age < FLASH_DURATION_MSEC:
		var t := 1.0 - walk_age / FLASH_DURATION_MSEC
		return COLOR_BORDER_IDLE.lerp(COLOR_BORDER_FLASH_WALKABLE, t)
	if s.last_flow_compute_msec > 0 and flow_age < FLASH_DURATION_MSEC:
		var t2 := 1.0 - flow_age / FLASH_DURATION_MSEC
		return COLOR_BORDER_IDLE.lerp(COLOR_BORDER_FLASH_FLOW, t2)
	return COLOR_BORDER_IDLE


func _draw_portal(layer: GroundNavLayer, p) -> void:
	var bidirectional: bool = p.a_to_b and p.b_to_a
	var base_color: Color = COLOR_PORTAL if bidirectional else COLOR_PORTAL_DIRECTED
	var ms: int = layer.map_size
	for pair_i in p.tile_pairs_a.size():
		var a_tile: int = p.tile_pairs_a[pair_i]
		var b_tile: int = p.tile_pairs_b[pair_i]
		var ax: float = float(a_tile % ms)
		@warning_ignore("integer_division")
		var ay: float = float(a_tile / ms)
		var bx: float = float(b_tile % ms)
		@warning_ignore("integer_division")
		var by: float = float(b_tile / ms)
		_line(ax, ay, bx, by, base_color)
		if not bidirectional:
			# Draw a small arrowhead at the END of the allowed direction.
			# a_to_b true → arrow points at b; b_to_a true → arrow at a.
			var tip: Vector2
			var tail: Vector2
			if p.a_to_b:
				tip = Vector2(bx, by)
				tail = Vector2(ax, ay)
			else:
				tip = Vector2(ax, ay)
				tail = Vector2(bx, by)
			_arrow_head(tail, tip, base_color, _lines_mesh, PORTAL_Y)


# ── Flow arrows (separate ARROWS surface for potential frequency split) ─────
#
# Arrows are drawn by calling `layer.sample_flow(world_pos, goal_key)` at an
# N×N sub-grid of world positions inside each tile of every sector that
# already has a cached flow field. This matches exactly what a monster at
# that world position would receive (edge-gated bilinear blend included), so
# the overlay visualises real agent behaviour rather than the raw stored
# per-tile direction.
#
# Why a sub-grid: sampling at integer tile centres collapses the bilinear
# blend to a single corner (fx=fy=0 ⇒ only the query tile contributes),
# which would just recreate the old raw-per-tile visualisation.
#
# Scope: we only iterate sectors already present in each goal's flow_cache
# so that the debug overlay itself never triggers fresh sector compute.
# Sub-tile samples that happen to cross a sector boundary may still lazily
# compute a neighbour sector's field via sample_flow — that's intentional
# (it mirrors what a monster crossing the same boundary would do) and is
# throttled by REDRAW_INTERVAL_MSEC.

func _draw_flow_arrows(layer: GroundNavLayer) -> void:
	# Short-circuit if no goal has any cached sector flow yet — ImmediateMesh
	# errors if surface_end is called with no vertices added.
	var any_cached := false
	for goal_key_pre in layer.goals:
		var g_pre = layer.goals[goal_key_pre]
		if not g_pre.flow_cache.is_empty():
			any_cached = true
			break
	if not any_cached:
		return

	_arrows_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var emitted := false
	var step: float = 1.0 / float(SAMPLES_PER_TILE)
	var base_off: float = -0.5 + step * 0.5  # first sample offset from tile centre
	for goal_key in layer.goals:
		var g = layer.goals[goal_key]
		var color := _flow_arrow_color(goal_key)
		for sector_idx_v in g.flow_cache:
			var sector_idx: int = sector_idx_v
			var sd = layer.sectors[sector_idx]
			var sx0: int = sd.x0
			var sy0: int = sd.y0
			var w: int = int(sd.x1) - sx0
			var h: int = int(sd.y1) - sy0
			for ly in h:
				for lx in w:
					var tx: int = sx0 + lx
					var ty: int = sy0 + ly
					for sj in SAMPLES_PER_TILE:
						for si in SAMPLES_PER_TILE:
							var wx: float = float(tx) + base_off + float(si) * step
							var wy: float = float(ty) + base_off + float(sj) * step
							var dir: Vector2 = layer.sample_flow(Vector3(wx, 0.0, wy), goal_key)
							if dir.length_squared() < 0.01:
								continue
							_flow_arrow(wx, wy, dir.x, dir.y, color)
							emitted = true
	if emitted:
		_arrows_mesh.surface_end()
	else:
		# Pop the surface we opened; ImmediateMesh forbids empty surfaces.
		_arrows_mesh.clear_surfaces()


func _flow_arrow_color(goal_key: StringName) -> Color:
	if goal_key == &"factory":
		return COLOR_FLOW_FACTORY
	if goal_key == &"chase":
		return COLOR_FLOW_CHASE
	return COLOR_FLOW_OTHER


func _flow_arrow(cx: float, cy: float, dx: float, dy: float, color: Color) -> void:
	var half := ARROW_LENGTH * 0.5
	var sx := cx - dx * half
	var sy := cy - dy * half
	var ex := cx + dx * half
	var ey := cy + dy * half
	_arrows_mesh.surface_set_color(color)
	_arrows_mesh.surface_add_vertex(Vector3(sx, ARROW_Y, sy))
	_arrows_mesh.surface_set_color(color)
	_arrows_mesh.surface_add_vertex(Vector3(ex, ARROW_Y, ey))
	# Arrowhead: two short segments forming a '>' at the tip
	var perp_x := -dy
	var perp_y := dx
	var hx := ex - dx * ARROW_HEAD_LENGTH
	var hy := ey - dy * ARROW_HEAD_LENGTH
	var head_a_x := hx + perp_x * ARROW_HEAD_LENGTH * 0.5
	var head_a_y := hy + perp_y * ARROW_HEAD_LENGTH * 0.5
	var head_b_x := hx - perp_x * ARROW_HEAD_LENGTH * 0.5
	var head_b_y := hy - perp_y * ARROW_HEAD_LENGTH * 0.5
	_arrows_mesh.surface_set_color(color)
	_arrows_mesh.surface_add_vertex(Vector3(ex, ARROW_Y, ey))
	_arrows_mesh.surface_set_color(color)
	_arrows_mesh.surface_add_vertex(Vector3(head_a_x, ARROW_Y, head_a_y))
	_arrows_mesh.surface_set_color(color)
	_arrows_mesh.surface_add_vertex(Vector3(ex, ARROW_Y, ey))
	_arrows_mesh.surface_set_color(color)
	_arrows_mesh.surface_add_vertex(Vector3(head_b_x, ARROW_Y, head_b_y))


# ── Geometry primitives ─────────────────────────────────────────────────────

## Append a line in XZ with constant Y=BORDER_Y to the LINES surface. (x,y)
## coordinates are grid-space world coordinates (tile centre = integer).
func _line(x0: float, y0: float, x1: float, y1: float, color: Color) -> void:
	_lines_mesh.surface_set_color(color)
	_lines_mesh.surface_add_vertex(Vector3(x0, BORDER_Y, y0))
	_lines_mesh.surface_set_color(color)
	_lines_mesh.surface_add_vertex(Vector3(x1, BORDER_Y, y1))


## Append a short arrowhead at `tip` pointing back toward `tail`.
func _arrow_head(tail: Vector2, tip: Vector2, color: Color, mesh: ImmediateMesh, y: float) -> void:
	var dir := tip - tail
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var head_base := tip - dir * ARROW_HEAD_LENGTH
	var head_a := head_base + perp * ARROW_HEAD_LENGTH * 0.5
	var head_b := head_base - perp * ARROW_HEAD_LENGTH * 0.5
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(Vector3(tip.x, y, tip.y))
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(Vector3(head_a.x, y, head_a.y))
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(Vector3(tip.x, y, tip.y))
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(Vector3(head_b.x, y, head_b.y))
