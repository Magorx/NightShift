## Nav Debugger — interactive flow-field editor.
##
## Launch (after setting as main scene or opening in editor):
##   $GODOT --path . res://tools/nav_debugger/nav_debugger.tscn
##
## Paint mode  Right-click erases (resets to empty/floor).
## Keyboard shortcuts:
##   1-7  select paint tool    R  rebuild    Space  run/stop    C  clear
extends Control

const GOAL_KEY := &"goal"
const TOOLBAR_H := 48.0
const LEGEND_W  := 150.0     ## reserved width on the right for the legend
const MONSTER_SPEED := 4.0   ## cells per second
const ARROW_SCALE := 0.38    ## arrow length as fraction of cell size
const TRAIL_MAX := 12        ## position samples kept per monster trail

enum PaintTool { EMPTY = 0, WALL = 1, ELEV_1 = 2, ELEV_2 = 3, ELEV_3 = 4, MONSTER = 5, GOAL = 6 }

# ── nav state ────────────────────────────────────────────────────────────────
var _nav: GroundNavLayer
var _provider: DebugMapProvider

# ── editor state ─────────────────────────────────────────────────────────────
var _tool: PaintTool = PaintTool.EMPTY
var _grid_size: int = 20
var _goals: Dictionary = {}        ## Vector2i → true
var _monsters: Array = []          ## Array of Vector2  (continuous grid-space pos)
var _monster_starts: Array = []    ## spawn positions for Reset
var _trails: Array = []            ## Array of Array[Vector2]  (per monster)
var _running: bool = false
var _flow_built: bool = false
var _painting: bool = false        ## true while mouse button held

# ── derived / cached ─────────────────────────────────────────────────────────
var _cell_px: float = 32.0         ## recalculated each draw from window size
var _canvas_origin: Vector2        ## top-left of grid area in screen space

# ── ui refs ───────────────────────────────────────────────────────────────────
var _tool_buttons: Array[Button] = []
var _btn_run: Button
var _status: Label
var _grid_spin: SpinBox

# ── colours ──────────────────────────────────────────────────────────────────
const C_BG         := Color(0.08, 0.08, 0.10)
const C_EMPTY      := Color(0.22, 0.22, 0.26)
const C_WALL       := Color(0.30, 0.12, 0.10)
const C_ELEV_1     := Color(0.36, 0.30, 0.18)
const C_ELEV_2     := Color(0.48, 0.40, 0.22)
const C_ELEV_3     := Color(0.60, 0.50, 0.28)
const C_GOAL       := Color(0.10, 0.70, 0.28, 0.45)
const C_GRID_LINE  := Color(0.05, 0.05, 0.06, 0.7)
const C_ARROW      := Color(0.35, 0.95, 0.45)
const C_MONSTER    := Color(1.00, 0.90, 0.20)
const C_REACHED    := Color(0.30, 1.00, 0.50)
const C_TRAIL      := Color(1.00, 0.85, 0.20, 0.25)
const C_UNREACHABLE := Color(0.60, 0.20, 0.20, 0.6)
const C_SECTOR     := Color(0.25, 0.45, 1.00, 0.85)


# ── init ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_provider = DebugMapProvider.new()
	_provider.map_size = _grid_size
	_nav = GroundNavLayer.new()
	_nav.map_provider = _provider

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_toolbar()
	_build_status_bar()
	_select_tool(PaintTool.EMPTY)
	_update_status()


func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.anchor_right = 1.0
	bar.custom_minimum_size.y = TOOLBAR_H
	bar.add_theme_constant_override("separation", 4)
	add_child(bar)

	_add_sep(bar)
	_add_label(bar, "Paint:")
	_tool_buttons.clear()
	_add_tool_btn(bar, "Empty",  PaintTool.EMPTY,   "(1)")
	_add_tool_btn(bar, "Wall",   PaintTool.WALL,    "(2)")
	_add_tool_btn(bar, "Elv 1",  PaintTool.ELEV_1,  "(3)")
	_add_tool_btn(bar, "Elv 2",  PaintTool.ELEV_2,  "(4)")
	_add_tool_btn(bar, "Elv 3",  PaintTool.ELEV_3,  "(5)")
	_add_tool_btn(bar, "Monster",PaintTool.MONSTER,  "(6)")
	_add_tool_btn(bar, "Goal",   PaintTool.GOAL,    "(7)")

	_add_sep(bar)

	var btn_rebuild := Button.new()
	btn_rebuild.text = "Rebuild (R)"
	btn_rebuild.pressed.connect(_on_rebuild)
	bar.add_child(btn_rebuild)

	_btn_run = Button.new()
	_btn_run.text = "▶ Run"
	_btn_run.toggle_mode = true
	_btn_run.toggled.connect(_on_run_toggled)
	bar.add_child(_btn_run)

	var btn_reset := Button.new()
	btn_reset.text = "Reset"
	btn_reset.pressed.connect(_on_reset)
	bar.add_child(btn_reset)

	var btn_clear := Button.new()
	btn_clear.text = "Clear (C)"
	btn_clear.pressed.connect(_on_clear)
	bar.add_child(btn_clear)

	_add_sep(bar)
	_add_label(bar, "Grid:")

	_grid_spin = SpinBox.new()
	_grid_spin.min_value = 8
	_grid_spin.max_value = 64
	_grid_spin.step = 1
	_grid_spin.value = _grid_size
	_grid_spin.suffix = "×"
	_grid_spin.value_changed.connect(_on_grid_size_changed)
	bar.add_child(_grid_spin)


func _add_label(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(lbl)


func _add_sep(parent: Control) -> void:
	parent.add_child(VSeparator.new())


func _add_tool_btn(parent: Control, label: String, t: PaintTool, hint: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.tooltip_text = hint
	btn.pressed.connect(func() -> void: _select_tool(t))
	_tool_buttons.append(btn)
	parent.add_child(btn)


func _build_status_bar() -> void:
	_status = Label.new()
	_status.anchor_left = 0.0
	_status.anchor_right = 1.0
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_top = -22.0
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	add_child(_status)


# ── tool selection ────────────────────────────────────────────────────────────

func _select_tool(t: PaintTool) -> void:
	_tool = t
	for i in _tool_buttons.size():
		_tool_buttons[i].button_pressed = (i == int(t))


func _update_status() -> void:
	var parts: Array[String] = []
	if _flow_built:
		parts.append("Flow OK")
	else:
		parts.append("No flow — press Rebuild")
	parts.append("%d goal tile(s)" % _goals.size())
	parts.append("%d monster(s)" % _monsters.size())
	if _running:
		parts.append("▶ RUNNING")
	_status.text = "  " + "  |  ".join(parts)


# ── toolbar callbacks ─────────────────────────────────────────────────────────

func _on_rebuild() -> void:
	_nav.rebuild()
	var pts := PackedVector2Array()
	for v: Vector2i in _goals.keys():
		pts.append(Vector2(float(v.x), float(v.y)))
	_nav.set_goal(GOAL_KEY, pts)
	_flow_built = _goals.size() > 0
	queue_redraw()
	_update_status()


func _on_run_toggled(pressed: bool) -> void:
	if pressed:
		if not _flow_built:
			_on_rebuild()
		_running = true
		_btn_run.text = "■ Stop"
	else:
		_running = false
		_btn_run.text = "▶ Run"
	_update_status()


func _on_reset() -> void:
	_monsters = _monster_starts.duplicate()
	_trails.clear()
	for _i in _monsters.size():
		_trails.append([])
	_running = false
	_btn_run.button_pressed = false
	_btn_run.text = "▶ Run"
	queue_redraw()
	_update_status()


func _on_clear() -> void:
	_provider.clear_all()
	_goals.clear()
	_monsters.clear()
	_monster_starts.clear()
	_trails.clear()
	_flow_built = false
	_running = false
	_btn_run.button_pressed = false
	_btn_run.text = "▶ Run"
	queue_redraw()
	_update_status()


func _on_grid_size_changed(v: float) -> void:
	_grid_size = int(v)
	_provider.map_size = _grid_size
	_provider.clear_all()
	_goals.clear()
	_monsters.clear()
	_monster_starts.clear()
	_trails.clear()
	_flow_built = false
	_running = false
	_btn_run.button_pressed = false
	_btn_run.text = "▶ Run"
	queue_redraw()
	_update_status()


# ── keyboard shortcuts ────────────────────────────────────────────────────────

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	var ke := event as InputEventKey
	match ke.keycode:
		KEY_1: _select_tool(PaintTool.EMPTY)
		KEY_2: _select_tool(PaintTool.WALL)
		KEY_3: _select_tool(PaintTool.ELEV_1)
		KEY_4: _select_tool(PaintTool.ELEV_2)
		KEY_5: _select_tool(PaintTool.ELEV_3)
		KEY_6: _select_tool(PaintTool.MONSTER)
		KEY_7: _select_tool(PaintTool.GOAL)
		KEY_R: _on_rebuild()
		KEY_SPACE: _btn_run.button_pressed = not _btn_run.button_pressed
		KEY_C: _on_clear()


# ── mouse / painting ──────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_painting = mb.pressed
			if mb.pressed:
				_paint_at(mb.position, mb.button_index == MOUSE_BUTTON_RIGHT)
	elif event is InputEventMouseMotion and _painting:
		var mm := event as InputEventMouseMotion
		var erase := (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
		_paint_at(mm.position, erase)


func _paint_at(screen_pos: Vector2, erase: bool) -> void:
	_recalc_cell_size()
	var local := screen_pos - _canvas_origin
	var gx := int(local.x / _cell_px)
	var gy := int(local.y / _cell_px)
	if gx < 0 or gy < 0 or gx >= _grid_size or gy >= _grid_size:
		return

	var v := Vector2i(gx, gy)

	if erase:
		_provider.set_cell(v, DebugMapProvider.CellType.EMPTY, 0)
		_goals.erase(v)
		_remove_monsters_at(v)
	else:
		match _tool:
			PaintTool.EMPTY:
				_provider.set_cell(v, DebugMapProvider.CellType.EMPTY, 0)
				_goals.erase(v)
			PaintTool.WALL:
				_provider.set_cell(v, DebugMapProvider.CellType.WALL, 0)
				_goals.erase(v)
				_remove_monsters_at(v)
			PaintTool.ELEV_1:
				_provider.set_cell(v, DebugMapProvider.CellType.EMPTY, 1)
			PaintTool.ELEV_2:
				_provider.set_cell(v, DebugMapProvider.CellType.EMPTY, 2)
			PaintTool.ELEV_3:
				_provider.set_cell(v, DebugMapProvider.CellType.EMPTY, 3)
			PaintTool.MONSTER:
				# Avoid duplicates on same cell during a drag.
				# Offset 0.45 keeps fx/fy < 0.5 so query tile stays (gx, gy).
				var already := false
				for m: Vector2 in _monsters:
					if Vector2i(int(m.x), int(m.y)) == v:
						already = true
						break
				if not already:
					var spawn := Vector2(gx + 0.45, gy + 0.45)
					_monsters.append(spawn)
					_monster_starts.append(spawn)
					_trails.append([])
			PaintTool.GOAL:
				_goals[v] = true

	_flow_built = false
	queue_redraw()
	_update_status()


func _remove_monsters_at(v: Vector2i) -> void:
	var keep_m: Array = []
	var keep_s: Array = []
	var keep_t: Array = []
	for i in _monsters.size():
		if Vector2i(int((_monsters[i] as Vector2).x), int((_monsters[i] as Vector2).y)) != v:
			keep_m.append(_monsters[i])
			keep_s.append(_monster_starts[i])
			keep_t.append(_trails[i])
	_monsters = keep_m
	_monster_starts = keep_s
	_trails = keep_t


# ── simulation ────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not _running:
		return
	var any_alive := false
	for i in _monsters.size():
		var pos: Vector2 = _monsters[i]
		var tile := Vector2i(int(pos.x), int(pos.y))
		if _goals.has(tile):
			continue
		any_alive = true
		var world := Vector3(pos.x, 0.0, pos.y)
		var dir := _nav.sample_flow(world, GOAL_KEY)
		if dir.length_squared() > 0.0001:
			var new_pos: Vector2 = pos + dir * MONSTER_SPEED * delta
			_monsters[i] = new_pos
			var trail: Array = _trails[i]
			trail.append(new_pos)
			if trail.size() > TRAIL_MAX:
				trail.pop_front()

	if not any_alive and _monsters.size() > 0:
		_running = false
		_btn_run.button_pressed = false
		_btn_run.text = "▶ Run"
		_update_status()
	queue_redraw()


# ── drawing ───────────────────────────────────────────────────────────────────

func _recalc_cell_size() -> void:
	var canvas_h := size.y - TOOLBAR_H - 22.0
	var canvas_w := size.x - LEGEND_W
	_cell_px = min(canvas_w, canvas_h) / float(_grid_size)
	_canvas_origin = Vector2(0.0, TOOLBAR_H)


func _draw() -> void:
	_recalc_cell_size()

	# Background
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)

	# Grid cells
	for y in _grid_size:
		for x in _grid_size:
			_draw_cell(x, y)

	# Sector edges
	_draw_sector_edges()

	# Flow arrows
	if _flow_built:
		_draw_flow_arrows()

	# Monster trails + bodies
	for i in _monsters.size():
		_draw_trail(i)
		_draw_monster(i)

	_draw_legend()


func _draw_cell(x: int, y: int) -> void:
	var v := Vector2i(x, y)
	var type := _provider.get_cell_type(v)
	var height := _provider.get_cell_height(v)

	var color: Color
	if type == DebugMapProvider.CellType.WALL:
		color = C_WALL
	elif height == 0:
		color = C_EMPTY
	elif height == 1:
		color = C_ELEV_1
	elif height == 2:
		color = C_ELEV_2
	else:
		color = C_ELEV_3

	var rect := Rect2(_canvas_origin + Vector2(x * _cell_px, y * _cell_px), Vector2(_cell_px, _cell_px))
	draw_rect(rect, color)

	if _goals.has(v):
		draw_rect(rect, C_GOAL)

	draw_rect(rect, C_GRID_LINE, false, 1.0)

	# Height label (only when cell is big enough)
	if height > 0 and _cell_px >= 20:
		var font := ThemeDB.fallback_font
		var font_size := int(clamp(_cell_px * 0.28, 8, 14))
		draw_string(font, rect.position + Vector2(3, font_size + 2), str(height),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.6))


func _draw_legend() -> void:
	var lx := size.x - LEGEND_W + 12.0
	var ly := TOOLBAR_H + 14.0
	var swatch := 12.0
	var row_h := 19.0
	var font := ThemeDB.fallback_font
	var font_size := 11
	var text_col := Color(0.82, 0.82, 0.82)

	var entries: Array = [
		[C_EMPTY,        "Empty"],
		[C_WALL,         "Wall"],
		[C_ELEV_1,       "Elevation 1"],
		[C_ELEV_2,       "Elevation 2"],
		[C_ELEV_3,       "Elevation 3"],
		[C_GOAL,         "Goal"],
		[C_ARROW,        "Flow direction"],
		[C_UNREACHABLE,  "Unreachable"],
		[C_MONSTER,      "Monster"],
		[C_REACHED,      "Monster at goal"],
		[C_TRAIL,        "Trail"],
		[C_SECTOR,       "Sector edge"],
	]

	for entry: Array in entries:
		var col: Color = entry[0]
		var label: String = entry[1]
		draw_rect(Rect2(lx, ly, swatch, swatch), col)
		draw_rect(Rect2(lx, ly, swatch, swatch), Color(0, 0, 0, 0.35), false, 1.0)
		draw_string(font, Vector2(lx + swatch + 6.0, ly + swatch - 1.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
		ly += row_h


func _draw_sector_edges() -> void:
	var step: int = GroundNavLayer.SECTOR_TILES
	var grid_px := _grid_size * _cell_px
	var x := step
	while x < _grid_size:
		var sx := _canvas_origin.x + x * _cell_px
		draw_line(Vector2(sx, _canvas_origin.y), Vector2(sx, _canvas_origin.y + grid_px), C_SECTOR, 1.5, true)
		x += step
	var y := step
	while y < _grid_size:
		var sy := _canvas_origin.y + y * _cell_px
		draw_line(Vector2(_canvas_origin.x, sy), Vector2(_canvas_origin.x + grid_px, sy), C_SECTOR, 1.5, true)
		y += step


func _draw_flow_arrows() -> void:
	for y in _grid_size:
		for x in _grid_size:
			var v := Vector2i(x, y)
			if _provider.get_cell_type(v) == DebugMapProvider.CellType.WALL:
				continue
			if _goals.has(v):
				continue
			# Sample at tile anchor — query tile = (x, y), fx/fy = 0
			var world := Vector3(float(x), 0.0, float(y))
			var dir := _nav.sample_flow(world, GOAL_KEY)
			var center := _canvas_origin + Vector2((x + 0.5) * _cell_px, (y + 0.5) * _cell_px)
			if dir.length_squared() < 0.0001:
				# Mark unreachable tiles
				draw_rect(
					Rect2(center - Vector2(3, 3), Vector2(6, 6)),
					C_UNREACHABLE)
				continue
			var arrow_len := _cell_px * ARROW_SCALE
			var d := Vector2(dir.x, dir.y)
			var tip := center + d * arrow_len
			draw_line(center, tip, C_ARROW, 1.5, true)
			# Arrowhead
			var perp := Vector2(-d.y, d.x) * arrow_len * 0.28
			draw_line(tip, tip - d * arrow_len * 0.4 + perp, C_ARROW, 1.5, true)
			draw_line(tip, tip - d * arrow_len * 0.4 - perp, C_ARROW, 1.5, true)


func _draw_trail(i: int) -> void:
	var trail: Array = _trails[i]
	if trail.size() < 2:
		return
	for j in range(1, trail.size()):
		var a: Vector2 = trail[j - 1]
		var b: Vector2 = trail[j]
		var alpha := float(j) / float(trail.size())
		draw_line(
			_canvas_origin + a * _cell_px,
			_canvas_origin + b * _cell_px,
			Color(C_TRAIL.r, C_TRAIL.g, C_TRAIL.b, C_TRAIL.a * alpha),
			2.0, true)


func _draw_monster(i: int) -> void:
	var pos: Vector2 = _monsters[i]
	var tile := Vector2i(int(pos.x), int(pos.y))
	var at_goal := _goals.has(tile)
	var center := _canvas_origin + pos * _cell_px
	var r := _cell_px * 0.28
	draw_circle(center, r, C_REACHED if at_goal else C_MONSTER)
	draw_arc(center, r, 0, TAU, 12, Color(0, 0, 0, 0.5), 1.5)
