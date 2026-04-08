extends SceneTree

## Headless diagnostic driver for GroundNavLayer. Reproduces the problems
## from the nav debugger screenshots and dumps enough state to reason about
## them without a GUI.
##
## Usage:
##   $GODOT --headless --path . --script res://tools/nav_debugger/nav_diagnostic.gd
##   $GODOT --headless --path . --script res://tools/nav_debugger/nav_diagnostic.gd -- scenario1
##   $GODOT --headless --path . --script res://tools/nav_debugger/nav_diagnostic.gd -- scenario2
##   $GODOT --headless --path . --script res://tools/nav_debugger/nav_diagnostic.gd -- scenario3
##
## IMPORTANT: all references to `GroundNavLayer` / `DebugMapProvider` go
## through runtime `load()` because `ground_nav_layer.gd` references the
## `MapManager` autoload at compile time, and autoloads are not yet
## registered when Godot parses the main --script. Compile-time class_name
## references would cascade into MapManager lookup and fail.

const GOAL_KEY := &"goal"

var NavScript: GDScript
var ProviderScript: GDScript
# Bit constants mirrored from ground_nav_layer.gd
const BIT_E := 1
const BIT_SE := 2
const BIT_S := 4
const BIT_SW := 8
const BIT_W := 16
const BIT_NW := 32
const BIT_N := 64
const BIT_NE := 128
const SECTOR_TILES := 8
const UNREACHED := 0x7fffffff


func _init() -> void:
	# Autoloads are instantiated as children of `root`. Wait for them to
	# finish coming up before touching any script that references
	# `MapManager` (our nav layer does, even though we override it via
	# map_provider).
	root.ready.connect(_on_root_ready)


func _on_root_ready() -> void:
	NavScript = load("res://scripts/game/nav/ground_nav_layer.gd")
	ProviderScript = load("res://tools/nav_debugger/debug_map_provider.gd")

	var args := OS.get_cmdline_user_args()
	var scenario: String = args[0] if args.size() > 0 else "all"

	match scenario:
		"all":
			_run_scenario1_cross_sector()
			_run_scenario2_bridge_descent()
			_run_scenario3_sampler_cliff_edge()
			_run_scenario4_elevated_approach()
			_run_scenario5_image4_bridge_approach()
		"scenario1", "1":
			_run_scenario1_cross_sector()
		"scenario2", "2":
			_run_scenario2_bridge_descent()
		"scenario3", "3":
			_run_scenario3_sampler_cliff_edge()
		"scenario4", "4":
			_run_scenario4_elevated_approach()
		"scenario5", "5":
			_run_scenario5_image4_bridge_approach()
		_:
			push_error("unknown scenario: " + scenario)
	quit(0)


func _make_nav(size: int) -> Dictionary:
	var provider = ProviderScript.new()
	provider.map_size = size
	var nav = NavScript.new()
	nav.map_provider = provider
	return {"nav": nav, "provider": provider}


# ── Scenario 1 ──────────────────────────────────────────────────────────────
# Flat 16x16 grid. Goal in top sector. Bottom sector should be reachable.

func _run_scenario1_cross_sector() -> void:
	print_section("Scenario 1 — flat map, goal in top sector, bottom sector must be reachable")
	var d := _make_nav(16)
	var nav = d.nav
	var provider = d.provider

	# A few walls up top — nothing between the top and bottom sectors.
	_set_wall(provider, 4, 3)
	_set_wall(provider, 5, 3)
	_set_wall(provider, 6, 3)
	_set_wall(provider, 7, 3)

	var goal_tile := Vector2i(4, 2)
	nav.rebuild()
	nav.set_goal(GOAL_KEY, PackedVector2Array([Vector2(goal_tile.x, goal_tile.y)]))
	nav.sample_flow(Vector3(goal_tile.x, 0, goal_tile.y), GOAL_KEY)

	_dump(nav, provider, goal_tile)
	_dump_sector_boundary_report(nav, 16)


# ── Scenario 2 ──────────────────────────────────────────────────────────────
# Elevated bridge ring around a goal. Monster at ground must walk AROUND.

func _run_scenario2_bridge_descent() -> void:
	print_section("Scenario 2 — bridge/elevation: monster must approach via low ground")
	var d := _make_nav(12)
	var nav = d.nav
	var provider = d.provider

	# A 4x2 bridge of elevation-1 tiles at y=4..5, x=3..6.
	for x in range(3, 7):
		provider.set_cell(Vector2i(x, 4), ProviderScript.CellType.EMPTY, 1)
		provider.set_cell(Vector2i(x, 5), ProviderScript.CellType.EMPTY, 1)
	var goal_tile := Vector2i(4, 2)

	nav.rebuild()
	nav.set_goal(GOAL_KEY, PackedVector2Array([Vector2(goal_tile.x, goal_tile.y)]))
	nav.sample_flow(Vector3(goal_tile.x, 0, goal_tile.y), GOAL_KEY)
	_dump(nav, provider, goal_tile)

	print("\nSuspect tiles:")
	_inspect_tile(nav, provider, 4, 6, "ground south of bridge")
	_inspect_tile(nav, provider, 3, 6, "ground SW of bridge")
	_inspect_tile(nav, provider, 2, 4, "ground west of bridge")
	_inspect_tile(nav, provider, 4, 4, "bridge tile NW")
	_inspect_tile(nav, provider, 4, 5, "bridge tile S row")


# ── Scenario 3 ──────────────────────────────────────────────────────────────
# Cliff wall, sampler query-tile drift as the monster moves across it.

func _run_scenario3_sampler_cliff_edge() -> void:
	print_section("Scenario 3 — sampler with monster straddling a cliff boundary")
	var d := _make_nav(8)
	var nav = d.nav
	var provider = d.provider

	for y in 8:
		for x in range(4, 8):
			provider.set_cell(Vector2i(x, y), ProviderScript.CellType.EMPTY, 1)

	var goal_tile := Vector2i(0, 4)
	nav.rebuild()
	nav.set_goal(GOAL_KEY, PackedVector2Array([Vector2(goal_tile.x, goal_tile.y)]))
	nav.sample_flow(Vector3(goal_tile.x, 0, goal_tile.y), GOAL_KEY)
	_dump(nav, provider, goal_tile)

	print("\nSampler query-tile drift across the cliff boundary (monster y=0):")
	for mx_int in range(20, 50):
		var mx := float(mx_int) * 0.1  # 2.0 .. 4.9
		var dir: Vector2 = nav.sample_flow(Vector3(mx, 0.0, 4.0), GOAL_KEY)
		var bx := int(floor(mx))
		var fx := mx - float(bx)
		var qx: int = bx + (1 if fx >= 0.5 else 0)
		print("  wx=%.1f  query_tile=%d  dir=(%+.2f, %+.2f)" % [mx, qx, dir.x, dir.y])


# ── Scenario 4 ──────────────────────────────────────────────────────────────
# Elevated plateau with a goal on top. Monster starts on the plateau. Flow
# should keep it on the plateau all the way to the goal, NOT push it off
# the cliff to a ground-level cell it can't return from.

func _run_scenario4_elevated_approach() -> void:
	print_section("Scenario 4 — elevated plateau: monster on top stays on top")
	var d := _make_nav(12)
	var nav = d.nav
	var provider = d.provider

	# Elevated plateau: a 4x4 block at y=3..6, x=3..6.
	for y in range(3, 7):
		for x in range(3, 7):
			provider.set_cell(Vector2i(x, y), ProviderScript.CellType.EMPTY, 1)

	var goal_tile := Vector2i(4, 4)  # on top of the plateau
	nav.rebuild()
	nav.set_goal(GOAL_KEY, PackedVector2Array([Vector2(goal_tile.x, goal_tile.y)]))
	# Force flow compute. Caller is at elevation 1 so pass y=1.
	nav.sample_flow(Vector3(goal_tile.x, 1, goal_tile.y), GOAL_KEY)
	_dump(nav, provider, goal_tile)

	# Inspect the monster's tile.
	print("\nSuspect tiles (monster standing on plateau, y=1):")
	_inspect_tile_at_y(nav, provider, 6, 6, 1.0, "plateau SE corner")
	_inspect_tile_at_y(nav, provider, 5, 6, 1.0, "plateau south edge")
	_inspect_tile_at_y(nav, provider, 6, 5, 1.0, "plateau east edge")

	print("\nFlow if the SAME monster position is evaluated with y=0 (bug case):")
	_inspect_tile_at_y(nav, provider, 6, 6, 0.0, "plateau SE corner, y=0")
	_inspect_tile_at_y(nav, provider, 5, 6, 0.0, "plateau south edge, y=0")


# ── Scenario 5 ──────────────────────────────────────────────────────────────
# Image-4-style: a 4x2 elevated bridge with a goal on the FAR side. A ground
# monster on the near side must be steered AROUND the bridge, not under it.
# Tests bilinear sampling at sub-tile positions both at and adjacent to the
# bridge edge — the case where the OLD sampler would pick a bridge tile as
# the query and read its "descend" flow even though the agent is at y=0.

func _run_scenario5_image4_bridge_approach() -> void:
	print_section("Scenario 5 — image 4 case: ground monster approaches a bridge")
	var d := _make_nav(12)
	var nav = d.nav
	var provider = d.provider

	# Bridge: 4 wide, 2 tall, at y=4..5, x=3..6.
	for x in range(3, 7):
		provider.set_cell(Vector2i(x, 4), ProviderScript.CellType.EMPTY, 1)
		provider.set_cell(Vector2i(x, 5), ProviderScript.CellType.EMPTY, 1)
	# Goal on the NORTH side of the bridge.
	var goal_tile := Vector2i(4, 1)
	nav.rebuild()
	nav.set_goal(GOAL_KEY, PackedVector2Array([Vector2(goal_tile.x, goal_tile.y)]))
	# Force flow compute by sampling once.
	nav.sample_flow(Vector3(goal_tile.x, 0, goal_tile.y), GOAL_KEY)

	_dump(nav, provider, goal_tile)

	# A ground monster at world y=0 approaches the bridge from the south.
	# Walk a continuous line from south of the bridge toward (and into) it,
	# checking the flow direction at every step. The monster MUST NOT be
	# pulled toward the bridge tiles' descent flow.
	print("\nGround monster (y=0) walking north toward the bridge:")
	for step in 25:
		var wz: float = 7.5 - 0.2 * float(step)  # 7.5 → 2.7
		var wx := 4.5
		var dir: Vector2 = nav.sample_flow(Vector3(wx, 0.0, wz), GOAL_KEY)
		var bx := int(floor(wx))
		var by := int(floor(wz))
		var fx := wx - float(bx)
		var fy := wz - float(by)
		var qx := bx + (1 if fx >= 0.5 else 0)
		var qy := by + (1 if fy >= 0.5 else 0)
		var qh: int = provider.get_cell_height(Vector2i(qx, qy))
		print("  pos=(%.1f, 0, %.1f)  geom_q=(%d,%d,h=%d)  dir=(%+.2f, %+.2f)  %s"
			% [wx, wz, qx, qy, qh, dir.x, dir.y, _arrow_char(dir)])

	# A ground monster directly underneath the centre of the bridge — all 4
	# bilinear candidates are at elev 1, agent is at y=0. The OLD sampler
	# would happily pick a bridge tile and return its descent flow. The
	# height-aware sampler should detect "no candidate matches my elevation"
	# and return ZERO so the caller falls back to direct movement.
	print("\nMonster physically under the bridge centre (no valid candidate):")
	for cz in [4.5, 5.0]:
		for cx in [3.5, 4.5, 5.5]:
			var dir: Vector2 = nav.sample_flow(Vector3(cx, 0.0, cz), GOAL_KEY)
			print("  pos=(%.1f, 0, %.1f)  dir=(%+.2f, %+.2f)  %s"
				% [cx, cz, dir.x, dir.y, "ZERO" if dir.length_squared() < 0.0001 else "non-zero"])

	# Same case from the OPPOSITE direction (north of the bridge, ground
	# walking south toward it). Should be steered around as well.
	print("\nGround monster (y=0) walking south toward the bridge:")
	for step in 12:
		var wz: float = 1.0 + 0.3 * float(step)  # 1.0 → 4.3
		var wx := 4.5
		var dir: Vector2 = nav.sample_flow(Vector3(wx, 0.0, wz), GOAL_KEY)
		print("  pos=(%.1f, 0, %.1f)  dir=(%+.2f, %+.2f)  %s"
			% [wx, wz, dir.x, dir.y, _arrow_char(dir)])


# ─────────────────────────────────────────────────────────────────────────────
# Dump helpers
# ─────────────────────────────────────────────────────────────────────────────

func _dump(nav: Object, provider: Object, goal_tile: Vector2i) -> void:
	print("\nMap (. empty, # wall, N elev, G goal):")
	var m: int = provider.map_size
	for y in m:
		var row := ""
		for x in m:
			var v := Vector2i(x, y)
			if v == goal_tile:
				row += "G "
			elif provider.get_cell_type(v) == ProviderScript.CellType.WALL:
				row += "# "
			else:
				var h: int = provider.get_cell_height(v)
				row += (str(h) if h > 0 else ".") + " "
		print(row)

	print("\nFlow (> \\ v / < ` ^ ' arrows, . unreachable, G goal, * blocked):")
	for y in m:
		var row := ""
		for x in m:
			if Vector2i(x, y) == goal_tile:
				row += "G "
				continue
			var v := Vector2i(x, y)
			if provider.get_cell_type(v) == ProviderScript.CellType.WALL:
				row += "* "
				continue
			var flow: Vector2 = nav.sample_flow(Vector3(float(x), 0.0, float(y)), GOAL_KEY)
			row += _arrow_char(flow) + " "
		print(row)

	print("\nSector distances:")
	var g = nav.goals.get(GOAL_KEY)
	if g == null:
		print("  <no goal>")
	else:
		for sy in nav.sector_count:
			var row := "  "
			for sx in nav.sector_count:
				var si: int = sy * nav.sector_count + sx
				var dist: int = g.sector_distance[si] if g.sector_distance.size() > si else -1
				if dist == UNREACHED:
					row += " .  "
				else:
					row += "%3d " % dist
			print(row)

	print("\nPortals (sector_a <-> sector_b  dir  #tiles):")
	for i in nav.portals.size():
		var p = nav.portals[i]
		var dstr := ""
		if p.a_to_b and p.b_to_a:
			dstr = "<->"
		elif p.a_to_b:
			dstr = "-->"
		elif p.b_to_a:
			dstr = "<--"
		else:
			dstr = " ? "
		print("  #%02d sector %d %s %d  (%d pairs)" % [i, p.sector_a, dstr, p.sector_b, p.tile_pairs_a.size()])

	print("\nportal_index_per_sector contents:")
	for si in nav.portal_index_per_sector.size():
		var entry = nav.portal_index_per_sector[si]
		var items: Array = []
		for v in entry:
			items.append(int(v))
		print("  sector %d -> %s" % [si, str(items)])


func _dump_sector_boundary_report(nav: Object, map_size: int) -> void:
	print("\nSector boundary edge-mask report (horizontal edges, rows A|B):")
	var sc: int = nav.sector_count
	for sy in range(0, sc - 1):
		var a_row := (sy + 1) * SECTOR_TILES - 1
		var b_row := (sy + 1) * SECTOR_TILES
		if b_row >= map_size:
			continue
		for sx in sc:
			var x0 := sx * SECTOR_TILES
			var x1: int = mini((sx + 1) * SECTOR_TILES, map_size)
			var line := "  rows %d|%d sx=%d: " % [a_row, b_row, sx]
			for x in range(x0, x1):
				var a_tile := a_row * map_size + x
				var b_tile := b_row * map_size + x
				var aw: int = nav.walkable_mask[a_tile]
				var bw: int = nav.walkable_mask[b_tile]
				var a_bits: int = nav.edge_mask[a_tile]
				var b_bits: int = nav.edge_mask[b_tile]
				var a_south: bool = (a_bits & BIT_S) != 0
				var b_north: bool = (b_bits & BIT_N) != 0
				line += "[%d%d %s%s] " % [aw, bw, ("S" if a_south else "-"), ("N" if b_north else "-")]
			print(line)


func _inspect_tile(nav: Object, provider: Object, x: int, y: int, label: String) -> void:
	_inspect_tile_at_y(nav, provider, x, y, 0.0, label)


func _inspect_tile_at_y(nav: Object, provider: Object, x: int, y: int, agent_y: float, label: String) -> void:
	var tile := y * (provider.map_size as int) + x
	var mask: int = nav.edge_mask[tile]
	var bits := ""
	bits += ("E" if (mask & BIT_E) != 0 else "-")
	bits += ("S" if (mask & BIT_S) != 0 else "-")
	bits += ("W" if (mask & BIT_W) != 0 else "-")
	bits += ("N" if (mask & BIT_N) != 0 else "-")
	bits += (" SE" if (mask & BIT_SE) != 0 else " --")
	bits += (" SW" if (mask & BIT_SW) != 0 else " --")
	bits += (" NW" if (mask & BIT_NW) != 0 else " --")
	bits += (" NE" if (mask & BIT_NE) != 0 else " --")
	var flow: Vector2 = nav.sample_flow(Vector3(float(x), agent_y, float(y)), GOAL_KEY)
	@warning_ignore("integer_division")
	var s_idx: int = (y / SECTOR_TILES) * (nav.sector_count as int) + (x / SECTOR_TILES)
	var h: int = provider.get_cell_height(Vector2i(x, y))
	print("  (%d,%d) %-30s sector=%d elev=%d edge=%s flow=(%+.2f, %+.2f)" % [x, y, label, s_idx, h, bits, flow.x, flow.y])


func _set_wall(provider: Object, x: int, y: int) -> void:
	provider.set_cell(Vector2i(x, y), ProviderScript.CellType.WALL, 0)


func _arrow_char(d: Vector2) -> String:
	if d.length_squared() < 0.0001:
		return "."
	var ang := atan2(d.y, d.x)
	var idx := int(round(ang / (PI / 4.0))) & 7
	# 0=E 1=SE 2=S 3=SW 4=W 5=NW 6=N 7=NE
	var chars := [">", "\\", "v", "/", "<", "`", "^", "'"]
	return chars[idx]


func print_section(title: String) -> void:
	print("\n" + "=".repeat(72))
	print(title)
	print("=".repeat(72))
