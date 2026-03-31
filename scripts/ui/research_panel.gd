extends "game_window.gd"

## Research Panel — ring-based tech tree visualization with draggable canvas.
## Nodes arranged in a clear left-to-right tree. Edges show prerequisites.
## Canvas supports pan (drag empty space) and zoom (scroll wheel).

@onready var close_button: Button = %CloseButton
@onready var tree_display: Control = %TreeDisplay
@onready var info_panel: VBoxContainer = %InfoPanel
@onready var info_name: Label = %InfoName
@onready var info_desc: Label = %InfoDesc
@onready var info_cost: VBoxContainer = %InfoCost
@onready var info_unlocks: VBoxContainer = %InfoUnlocks
@onready var info_status: Label = %InfoStatus
@onready var research_button: Button = %ResearchButton
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var progress_label: Label = %ProgressLabel

var _selected_tech_id: StringName = &""
var _update_timer: float = 0.0

# Layout data
var _ring_techs: Dictionary = {}  # ring -> Array[StringName]
var _tech_positions: Dictionary = {}  # tech_id -> Vector2 (world coords, center of node)
var _json_positions: Dictionary = {}  # tech_id -> Vector2 (from JSON)
var _edges: Array = []  # Array of {from: StringName, to: StringName}

# Canvas pan/zoom
var _pan: Vector2 = Vector2.ZERO
var _zoom: float = 1.0
var _panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO

const RING_COLORS := [
	Color(0.5, 0.5, 0.5),   # Ring 0 (free)
	Color(0.9, 0.3, 0.3),   # Ring 1 (red)
	Color(0.3, 0.8, 0.3),   # Ring 2 (green)
	Color(0.3, 0.5, 0.9),   # Ring 3 (blue)
]
const RING_NAMES := ["Ring 0", "Ring 1", "Ring 2", "Ring 3"]

const NODE_SIZE := Vector2(130, 48)
const NODE_HGAP := 160.0  # horizontal gap between columns (rings)
const NODE_VGAP := 64.0   # vertical gap between nodes in same ring

func _ready() -> void:
	super._ready()
	research_button.pressed.connect(_on_research_pressed)
	tree_display.draw.connect(_on_tree_draw)
	tree_display.gui_input.connect(_on_tree_input)
	# Don't let scroll pass through tree_display to parent ScrollContainer
	tree_display.mouse_filter = Control.MOUSE_FILTER_STOP
	ResearchManager.research_completed.connect(_on_research_completed)
	ResearchManager.research_started.connect(_on_research_started)
	_load_tree_json()
	_layout_nodes()
	_center_view()
	_update_info_panel()

func _load_tree_json() -> void:
	var file := FileAccess.open("res://resources/tech/research_tree.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Dictionary = json.data
	_edges.clear()
	for edge_data in data.get("edges", []):
		_edges.append({
			from = StringName(edge_data.get("from", "")),
			to = StringName(edge_data.get("to", "")),
		})
	_json_positions.clear()
	for node_data in data.get("nodes", []):
		var id := StringName(node_data.get("id", ""))
		var pos_data: Dictionary = node_data.get("position", {})
		_json_positions[id] = Vector2(
			float(pos_data.get("x", 0.0)),
			float(pos_data.get("y", 0.0))
		)

func _process(delta: float) -> void:
	super._process(delta)
	if not visible:
		return
	_update_timer += delta
	if _update_timer >= 0.5:
		_update_timer = 0.0
		_refresh_progress_display()
		tree_display.queue_redraw()

const GRID_SCALE := 80.0  # matches GRID in the HTML editor

func _layout_nodes() -> void:
	_ring_techs.clear()
	_tech_positions.clear()

	# Group techs by ring
	for tech_id in ResearchManager.tech_defs:
		var tech: TechDef = ResearchManager.tech_defs[tech_id]
		if not _ring_techs.has(tech.ring):
			_ring_techs[tech.ring] = []
		_ring_techs[tech.ring].append(tech_id)

	# Sort each ring alphabetically for stable fallback
	for ring in _ring_techs:
		_ring_techs[ring].sort()

	# Use JSON positions if available, fallback to computed grid
	for tech_id in ResearchManager.tech_defs:
		if _json_positions.has(tech_id):
			var jp: Vector2 = _json_positions[tech_id]
			_tech_positions[tech_id] = jp * GRID_SCALE
		else:
			# Fallback: place by ring column
			var tech: TechDef = ResearchManager.tech_defs[tech_id]
			var ring_list: Array = _ring_techs.get(tech.ring, [])
			var idx: int = ring_list.find(tech_id)
			var count: int = ring_list.size()
			var col_x: float = tech.ring * NODE_HGAP
			var total_height: float = (count - 1) * NODE_VGAP
			_tech_positions[tech_id] = Vector2(col_x, -total_height * 0.5 + idx * NODE_VGAP)

func _center_view() -> void:
	# Center pan on the middle of all nodes
	if _tech_positions.is_empty():
		return
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for pos in _tech_positions.values():
		min_pos.x = minf(min_pos.x, pos.x)
		min_pos.y = minf(min_pos.y, pos.y)
		max_pos.x = maxf(max_pos.x, pos.x)
		max_pos.y = maxf(max_pos.y, pos.y)
	var center := (min_pos + max_pos) * 0.5
	_pan = -center

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var display_center := tree_display.size * 0.5
	return (world_pos + _pan) * _zoom + display_center

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var display_center := tree_display.size * 0.5
	return (screen_pos - display_center) / _zoom - _pan

# ── Drawing ──────────────────────────────────────────────────────────────────

func _on_tree_draw() -> void:
	# Dark blue background
	tree_display.draw_rect(Rect2(Vector2.ZERO, tree_display.size), Color(0.11, 0.12, 0.26), true)

	# Grid lines
	var grid_spacing := GRID_SCALE * _zoom
	if grid_spacing > 8.0:  # don't draw grid if too zoomed out
		var grid_color := Color(1.0, 1.0, 1.0, 0.1)
		var display_size := tree_display.size
		# Compute grid offset from pan
		var origin_screen := _world_to_screen(Vector2.ZERO)
		var start_x := fmod(origin_screen.x, grid_spacing)
		if start_x < 0:
			start_x += grid_spacing
		var start_y := fmod(origin_screen.y, grid_spacing)
		if start_y < 0:
			start_y += grid_spacing
		var x := start_x
		while x < display_size.x:
			tree_display.draw_line(Vector2(x, 0), Vector2(x, display_size.y), grid_color)
			x += grid_spacing
		var y := start_y
		while y < display_size.y:
			tree_display.draw_line(Vector2(0, y), Vector2(display_size.x, y), grid_color)
			y += grid_spacing

	# Draw ring column labels — positioned based on average x of nodes in each ring
	var rings_sorted: Array = _ring_techs.keys()
	rings_sorted.sort()
	for ring in rings_sorted:
		if ring >= RING_COLORS.size():
			continue
		var techs: Array = _ring_techs[ring]
		if techs.is_empty():
			continue
		# Compute average X and min Y from actual node positions
		var avg_x := 0.0
		var min_y := INF
		for tid in techs:
			var pos: Vector2 = _tech_positions.get(tid, Vector2.ZERO)
			avg_x += pos.x
			min_y = minf(min_y, pos.y)
		avg_x /= techs.size()
		# Ring label above topmost node
		var label_world := Vector2(avg_x, min_y - NODE_SIZE.y * 0.5 - 16)
		var label_screen := _world_to_screen(label_world)
		var ring_name: String = RING_NAMES[ring] if ring < RING_NAMES.size() else "Ring %d" % ring
		var label_font := int(14 * _zoom)
		if label_font >= 6:
			var label_width := _estimate_text_width(ring_name, label_font)
			tree_display.draw_string(ThemeDB.fallback_font, Vector2(label_screen.x - label_width * 0.5, label_screen.y), ring_name, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font, Color(RING_COLORS[ring], 0.6))

	# Draw edges
	for edge in _edges:
		var from_id: StringName = edge.from
		var to_id: StringName = edge.to
		if not _tech_positions.has(from_id) or not _tech_positions.has(to_id):
			continue
		var from_screen: Vector2 = _world_to_screen(_tech_positions[from_id])
		var to_screen: Vector2 = _world_to_screen(_tech_positions[to_id])

		var from_tech: TechDef = ResearchManager.tech_defs.get(from_id)
		var to_tech: TechDef = ResearchManager.tech_defs.get(to_id)
		var edge_color := Color(0.4, 0.4, 0.5, 0.5)
		if from_tech:
			var rc: Color = RING_COLORS[from_tech.ring] if from_tech.ring < RING_COLORS.size() else Color.WHITE
			edge_color = Color(rc, 0.4)
		var both_unlocked: bool = ResearchManager.unlocked_techs.has(from_id) and ResearchManager.unlocked_techs.has(to_id)
		if both_unlocked:
			edge_color.a = 0.8

		# Draw bezier curve from right side of from-node to left side of to-node
		var from_right := from_screen + Vector2(NODE_SIZE.x * 0.5 * _zoom, 0)
		var to_left := to_screen - Vector2(NODE_SIZE.x * 0.5 * _zoom, 0)
		var cp_offset := Vector2(absf(to_left.x - from_right.x) * 0.4, 0)
		# Draw as polyline approximation of bezier
		var points: PackedVector2Array = PackedVector2Array()
		for t_i in 13:
			var t: float = t_i / 12.0
			var p := from_right.bezier_interpolate(from_right + cp_offset, to_left - cp_offset, to_left, t)
			points.append(p)
		tree_display.draw_polyline(points, edge_color, 2.0 * _zoom)

		# Arrow head at to_left
		var arrow_dir := (points[12] - points[11]).normalized()
		var perp := Vector2(-arrow_dir.y, arrow_dir.x)
		var arrow_size := 6.0 * _zoom
		tree_display.draw_line(to_left, to_left - arrow_dir * arrow_size + perp * arrow_size * 0.5, edge_color, 2.0 * _zoom)
		tree_display.draw_line(to_left, to_left - arrow_dir * arrow_size - perp * arrow_size * 0.5, edge_color, 2.0 * _zoom)

	# Draw tech nodes
	for tech_id in _tech_positions:
		_draw_tech_node(tech_id)

func _draw_tech_node(tech_id: StringName) -> void:
	var tech: TechDef = ResearchManager.tech_defs.get(tech_id)
	if not tech:
		return
	var screen_center: Vector2 = _world_to_screen(_tech_positions[tech_id])
	var half := NODE_SIZE * 0.5 * _zoom
	var rect := Rect2(screen_center - half, NODE_SIZE * _zoom)

	var ring: int = tech.ring
	var ring_color: Color = RING_COLORS[ring] if ring < RING_COLORS.size() else Color.WHITE
	var is_unlocked: bool = ResearchManager.unlocked_techs.has(tech_id)
	var is_current: bool = ResearchManager.current_research != null and ResearchManager.current_research.id == tech_id
	var is_available: bool = _is_tech_available(tech_id)
	var is_selected: bool = tech_id == _selected_tech_id

	# Shadow
	var shadow_rect := Rect2(rect.position + Vector2(2, 2) * _zoom, rect.size)
	tree_display.draw_rect(shadow_rect, Color(0, 0, 0, 0.3))

	# Background
	var bg_alpha := 0.15 if not is_selected else 0.35
	if is_unlocked:
		bg_alpha = 0.3 if not is_selected else 0.45
	elif is_current:
		bg_alpha = 0.25 if not is_selected else 0.4
	elif not is_available:
		bg_alpha = 0.08
	var bg_color := Color(ring_color.r, ring_color.g, ring_color.b, bg_alpha)
	tree_display.draw_rect(rect, bg_color)

	# Border
	var border_width := 1.5 * _zoom
	var border_color := Color(ring_color, 0.6)
	if is_selected:
		border_color = Color(1.0, 0.9, 0.3, 1.0)
		border_width = 2.5 * _zoom
	elif is_unlocked:
		border_color = Color(ring_color, 0.9)
	elif is_current:
		border_color = Color(1.0, 1.0, 1.0, 0.8)
		border_width = 2.0 * _zoom
	tree_display.draw_rect(rect, border_color, false, border_width)

	# Progress bar for current research
	if is_current:
		var progress := ResearchManager.get_progress_fraction()
		var bar_h := 3.0 * _zoom
		var bar_rect := Rect2(rect.position.x + 2 * _zoom, rect.position.y + rect.size.y - bar_h - 2 * _zoom, (rect.size.x - 4 * _zoom) * progress, bar_h)
		tree_display.draw_rect(bar_rect, Color(0.3, 0.9, 0.3, 0.9))
		var bar_bg := Rect2(rect.position.x + 2 * _zoom, rect.position.y + rect.size.y - bar_h - 2 * _zoom, rect.size.x - 4 * _zoom, bar_h)
		tree_display.draw_rect(bar_bg, Color(0.2, 0.2, 0.2, 0.5), false, 1.0)

	var font_size := int(11 * _zoom)
	if font_size < 6:
		return

	# Ring indicator dot
	var dot_radius := 4.0 * _zoom
	var dot_center := Vector2(rect.position.x + 10.0 * _zoom, rect.position.y + 14.0 * _zoom)
	tree_display.draw_circle(dot_center, dot_radius, ring_color)

	# Checkmark for unlocked (next to dot)
	if is_unlocked:
		var check_pos := Vector2(rect.position.x + rect.size.x - 14 * _zoom, rect.position.y + 14 * _zoom)
		tree_display.draw_string(ThemeDB.fallback_font, check_pos, "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.3, 0.95, 0.3))

	# Tech name — bold, after the dot
	var text_color := Color.WHITE if (is_available or is_unlocked or is_current) else Color(0.45, 0.45, 0.5)
	var name_x: float = rect.position.x + 20.0 * _zoom
	var name_y: float = rect.position.y + 14.0 * _zoom + font_size * 0.35
	var name_width := int(rect.size.x - 26.0 * _zoom)
	tree_display.draw_string(ThemeDB.fallback_font, Vector2(name_x, name_y), tech.display_name, HORIZONTAL_ALIGNMENT_LEFT, name_width, font_size, text_color)

	# Cost row — icons + quantities at the bottom
	var cost_font_size := int(9 * _zoom)
	if cost_font_size < 5:
		return
	var icon_size := 16.0 * _zoom
	var cost_x: float = rect.position.x + 6.0 * _zoom
	var cost_y: float = rect.position.y + rect.size.y - 6.0 * _zoom
	for stack in tech.cost:
		# Draw item icon from atlas
		var icon_tex: Texture2D = GameManager.get_item_icon(stack.item.id)
		if icon_tex:
			var icon_rect := Rect2(cost_x, cost_y - icon_size, icon_size, icon_size)
			tree_display.draw_texture_rect(icon_tex, icon_rect, false)
			cost_x += icon_size + 1.0 * _zoom
		# Draw quantity
		var qty_str := str(stack.quantity)
		tree_display.draw_string(ThemeDB.fallback_font, Vector2(cost_x, cost_y - 1.0 * _zoom), qty_str, HORIZONTAL_ALIGNMENT_LEFT, -1, cost_font_size, Color(0.8, 0.8, 0.8))
		cost_x += _estimate_text_width(qty_str, cost_font_size) + 6.0 * _zoom

# ── Input ────────────────────────────────────────────────────────────────────

func _on_tree_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if clicked on a node
			var world_pos := _screen_to_world(event.position)
			var half := NODE_SIZE * 0.5
			for tech_id in _tech_positions:
				var node_pos: Vector2 = _tech_positions[tech_id]
				if absf(world_pos.x - node_pos.x) <= half.x and absf(world_pos.y - node_pos.y) <= half.y:
					_selected_tech_id = tech_id
					_update_info_panel()
					tree_display.queue_redraw()
					get_viewport().set_input_as_handled()
					return
			# Start panning
			_panning = true
			_pan_start_mouse = event.position
			_pan_start_offset = _pan
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_panning = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.15)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / 1.15)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _panning:
		var delta_screen: Vector2 = event.position - _pan_start_mouse
		_pan = _pan_start_offset + delta_screen / _zoom
		tree_display.queue_redraw()
		get_viewport().set_input_as_handled()

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_world := _screen_to_world(screen_pos)
	_zoom = clampf(_zoom * factor, 0.3, 3.0)
	var new_world := _screen_to_world(screen_pos)
	_pan += new_world - old_world
	tree_display.queue_redraw()

func _estimate_text_width(text: String, font_size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func _is_tech_available(tech_id: StringName) -> bool:
	if ResearchManager.unlocked_techs.has(tech_id):
		return true
	var tech: TechDef = ResearchManager.tech_defs.get(tech_id)
	if not tech:
		return false
	return ContractManager._current_ring >= tech.ring

# ── Info Panel ───────────────────────────────────────────────────────────────

func _update_info_panel() -> void:
	if _selected_tech_id == &"":
		info_name.text = "Select a technology"
		info_desc.text = ""
		_clear_children(info_cost)
		_clear_children(info_unlocks)
		info_status.text = ""
		research_button.visible = false
		progress_bar.visible = false
		progress_label.visible = false
		return

	var tech: TechDef = ResearchManager.tech_defs.get(_selected_tech_id)
	if not tech:
		return

	info_name.text = tech.display_name
	info_desc.text = tech.description

	# Cost
	_clear_children(info_cost)
	var cost_title := Label.new()
	cost_title.text = "Cost:"
	cost_title.add_theme_font_size_override("font_size", 12)
	cost_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	info_cost.add_child(cost_title)
	for stack in tech.cost:
		var row := HBoxContainer.new()
		row.add_child(ItemIcon.create(stack.item.id, Vector2(16, 16)))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(4, 0)
		row.add_child(gap)
		var lbl := Label.new()
		var delivered: int = 0
		if ResearchManager.current_research and ResearchManager.current_research.id == _selected_tech_id:
			delivered = ResearchManager.research_progress.get(stack.item.id, 0)
		lbl.text = "%s: %d/%d" % [stack.item.display_name, delivered, stack.quantity]
		lbl.add_theme_font_size_override("font_size", 11)
		if delivered >= stack.quantity:
			lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		row.add_child(lbl)
		info_cost.add_child(row)

	# Unlocks
	_clear_children(info_unlocks)
	if tech.unlocks.size() > 0:
		var unlock_title := Label.new()
		unlock_title.text = "Unlocks:"
		unlock_title.add_theme_font_size_override("font_size", 12)
		unlock_title.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		info_unlocks.add_child(unlock_title)
		for building_id in tech.unlocks:
			var bdef = GameManager.get_building_def(building_id)
			var bname: String = bdef.display_name if bdef else str(building_id)
			var lbl := Label.new()
			lbl.text = "  " + bname
			lbl.add_theme_font_size_override("font_size", 11)
			info_unlocks.add_child(lbl)

	# Status + button
	var is_unlocked: bool = ResearchManager.unlocked_techs.has(_selected_tech_id)
	var is_current: bool = ResearchManager.current_research != null and ResearchManager.current_research.id == _selected_tech_id
	var is_available: bool = _is_tech_available(_selected_tech_id)

	if is_unlocked:
		info_status.text = "COMPLETED"
		info_status.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		research_button.visible = false
	elif is_current:
		info_status.text = "RESEARCHING..."
		info_status.add_theme_color_override("font_color", Color(0.9, 0.85, 0.2))
		research_button.visible = false
	elif is_available:
		info_status.text = "Available"
		info_status.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		research_button.visible = true
		research_button.text = "Start Research"
	else:
		info_status.text = "Locked (Ring %d)" % tech.ring
		info_status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		research_button.visible = false

	# Progress bar
	_refresh_progress_display()

func _refresh_progress_display() -> void:
	## Update only the progress bar and label — does NOT call _update_info_panel.
	var is_current: bool = ResearchManager.current_research != null and ResearchManager.current_research.id == _selected_tech_id
	progress_bar.visible = is_current
	progress_label.visible = is_current
	if is_current:
		var frac := ResearchManager.get_progress_fraction()
		progress_bar.value = frac * 100.0
		progress_label.text = "%d%%" % int(frac * 100.0)

func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

func _on_research_pressed() -> void:
	if _selected_tech_id != &"":
		ResearchManager.start_research(_selected_tech_id)
		_update_info_panel()
		tree_display.queue_redraw()

func _on_research_completed(_tech_id: StringName) -> void:
	_update_info_panel()
	tree_display.queue_redraw()

func _on_research_started(_tech_id: StringName) -> void:
	_update_info_panel()
	tree_display.queue_redraw()
