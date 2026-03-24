extends PanelContainer

signal building_selected(id: StringName)

const CATEGORY_DISPLAY_NAMES := {
	"conveyor": "Transportation",
	"splitter": "Transportation",
	"junction": "Transportation",
	"tunnel": "Transportation",
	"extractor": "Extractors",
	"converter": "Converters",
	"sink": "Outputs",
	"source": "Sources",
}

# Categories hidden from the building panel (placed via multi-phase, not directly)
const HIDDEN_CATEGORIES := ["tunnel_output"]

# Preferred display order; categories not listed here are appended alphabetically.
const _PREFERRED_ORDER := ["Transportation", "Extractors", "Converters", "Outputs", "Sources"]

@onready var categories_box: HBoxContainer = %CategoriesBox
@onready var close_button: Button = %CloseButton
@onready var building_list: VBoxContainer = %BuildingList
@onready var info_name: Label = %InfoName
@onready var info_details: Label = %InfoDetails
@onready var info_recipes: VBoxContainer = %InfoRecipes
@onready var hotkey_popup: PanelContainer = %HotkeyPopup
@onready var hotkey_label: Label = %HotkeyLabel
@onready var top_bar: HBoxContainer = %TopBar

var _awaiting_hotkey_for: StringName = &""
var _active_category: String = ""
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
# Resize state
var _resizing: bool = false
var _resize_edge: int = 0 # bitmask: 1=left, 2=right, 4=top, 8=bottom
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_pos: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
const RESIZE_MARGIN := 6.0
const MIN_PANEL_SIZE := Vector2(320, 200)
# Snap-back interpolation
var _snapping_back: bool = false
var _snap_target: Vector2 = Vector2.ZERO
const SNAP_SPEED := 12.0
# Buildings grouped by category name
var _by_category: Dictionary = {}

func _ready() -> void:
	hotkey_popup.visible = false
	close_button.pressed.connect(func(): visible = false)
	_group_buildings()
	_create_category_tabs()
	# Select first category that has buildings
	var order := _get_category_order()
	if order.size() > 0:
		_select_category(order[0])
	_clear_info()

func _group_buildings() -> void:
	_by_category.clear()
	for id in GameManager.building_defs:
		var def = GameManager.building_defs[id]
		if def.category in HIDDEN_CATEGORIES:
			continue
		var cat_name: String = CATEGORY_DISPLAY_NAMES.get(def.category, def.category.capitalize())
		if not _by_category.has(cat_name):
			_by_category[cat_name] = []
		_by_category[cat_name].append(def)

func _get_category_order() -> Array:
	var order: Array = []
	for cat_name in _PREFERRED_ORDER:
		if _by_category.has(cat_name) and cat_name not in order:
			order.append(cat_name)
	# Append any remaining categories alphabetically
	var remaining: Array = []
	for cat_name in _by_category:
		if cat_name not in order:
			remaining.append(cat_name)
	remaining.sort()
	order.append_array(remaining)
	return order

func _create_category_tabs() -> void:
	for child in categories_box.get_children():
		child.queue_free()
	for cat_name in _get_category_order():
		var btn := Button.new()
		btn.text = cat_name
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_category_pressed.bind(cat_name, btn))
		btn.set_meta("category", cat_name)
		categories_box.add_child(btn)

func _on_category_pressed(cat_name: String, btn: Button) -> void:
	_select_category(cat_name)

func _select_category(cat_name: String) -> void:
	_active_category = cat_name
	# Update tab button states
	for child in categories_box.get_children():
		if child is Button:
			child.button_pressed = (child.get_meta("category") == cat_name)
	_populate_building_list()
	_clear_info()

func _populate_building_list() -> void:
	for child in building_list.get_children():
		child.queue_free()

	var defs: Array = _by_category.get(_active_category, [])
	var idx: int = 0
	for def in defs:
		var row := _create_building_row(def, idx)
		building_list.add_child(row)
		idx += 1

func _create_building_row(def, idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	# Alternating row colors
	var style := StyleBoxFlat.new()
	if idx % 2 == 0:
		style.bg_color = Color(0.18, 0.18, 0.22)
	else:
		style.bg_color = Color(0.22, 0.22, 0.26)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Color icon
	var color_rect := ColorRect.new()
	color_rect.custom_minimum_size = Vector2(20, 20)
	color_rect.color = def.color
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(color_rect)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(6, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# Name
	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	# Hotkey label
	var hotkey_lbl := Label.new()
	hotkey_lbl.name = "HotkeyLabel"
	var key_str := _get_hotkey_for(def.id)
	hotkey_lbl.text = "[%s]" % key_str if key_str != "" else ""
	hotkey_lbl.add_theme_font_size_override("font_size", 11)
	hotkey_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hotkey_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hotkey_lbl)

	panel.add_child(row)
	panel.set_meta("building_id", def.id)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_row_gui_input.bind(def.id))
	panel.mouse_entered.connect(_on_row_hovered.bind(def))
	panel.mouse_exited.connect(_on_row_unhovered.bind(panel))

	return panel

func _on_row_gui_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var was_building := _is_building_mode()
			building_selected.emit(id)
			# Only close when entering building mode for the first time
			if not was_building:
				visible = false
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_start_hotkey_assignment(id)
			accept_event()

func _on_row_hovered(def) -> void:
	_show_info(def)

func _on_row_unhovered(panel: PanelContainer) -> void:
	# Only clear if mouse isn't over any row
	pass

func _show_info(def) -> void:
	info_name.text = def.display_name

	var shape_size := _get_shape_size(def)
	var details := "Category: %s\nSize: %dx%d" % [def.category.capitalize(), shape_size.x, shape_size.y]
	if def.description != "":
		details += "\n\n%s" % def.description
	var key_str := _get_hotkey_for(def.id)
	if key_str != "":
		details += "\n\nHotkey: [%s]" % key_str
	else:
		details += "\n\nRMB to assign hotkey"
	info_details.text = details

	# Show recipes
	for child in info_recipes.get_children():
		child.queue_free()
	var recipes: Array = GameManager.recipes_by_type.get(str(def.id), [])
	if recipes.size() > 0:
		var header := Label.new()
		header.text = "Recipes:"
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		info_recipes.add_child(header)
		for recipe in recipes:
			var recipe_label := Label.new()
			var inputs_str := ""
			for inp in recipe.inputs:
				if inputs_str != "":
					inputs_str += " + "
				inputs_str += "%dx %s" % [inp.quantity, inp.item.display_name]
			var outputs_str := ""
			for out in recipe.outputs:
				if outputs_str != "":
					outputs_str += " + "
				outputs_str += "%dx %s" % [out.quantity, out.item.display_name]
			recipe_label.text = "  %s -> %s (%.0fs)" % [inputs_str, outputs_str, recipe.craft_time]
			recipe_label.add_theme_font_size_override("font_size", 11)
			recipe_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			info_recipes.add_child(recipe_label)

func _clear_info() -> void:
	info_name.text = ""
	info_details.text = "Hover a building to see details"
	for child in info_recipes.get_children():
		child.queue_free()

# ── Snap-back & center ──────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _snapping_back:
		global_position = global_position.lerp(_snap_target, SNAP_SPEED * delta)
		if global_position.distance_to(_snap_target) < 1.0:
			global_position = _snap_target
			_snapping_back = false

func move_to_center() -> void:
	var vp_size := get_viewport_rect().size
	_snap_target = (vp_size - size) * 0.5
	_snapping_back = true

func _is_out_of_bounds() -> bool:
	var vp_size := get_viewport_rect().size
	var margin := 40.0
	# Check if enough of the panel is outside the viewport to be unreachable
	return (global_position.x + size.x < margin
		or global_position.x > vp_size.x - margin
		or global_position.y + size.y < margin
		or global_position.y > vp_size.y - margin)

# ── Dragging & Resizing ─────────────────────────────────────────────────────

func _get_resize_edge(local_pos: Vector2) -> int:
	var edge := 0
	if local_pos.x < RESIZE_MARGIN:
		edge |= 1 # left
	elif local_pos.x > size.x - RESIZE_MARGIN:
		edge |= 2 # right
	if local_pos.y < RESIZE_MARGIN:
		edge |= 4 # top
	elif local_pos.y > size.y - RESIZE_MARGIN:
		edge |= 8 # bottom
	return edge

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var local_pos: Vector2 = event.position
			var edge := _get_resize_edge(local_pos)
			if edge != 0:
				# Start resize
				_resizing = true
				_resize_edge = edge
				_resize_start_mouse = get_global_mouse_position()
				_resize_start_pos = global_position
				_resize_start_size = size
				_snapping_back = false
				accept_event()
			else:
				# Start drag
				_dragging = true
				_snapping_back = false
				_drag_offset = global_position - get_global_mouse_position()
				accept_event()
		else:
			if _resizing:
				_resizing = false
			elif _dragging:
				_dragging = false
				if _is_out_of_bounds():
					move_to_center()
	elif event is InputEventMouseMotion:
		if _resizing:
			_apply_resize()
			accept_event()
		elif _dragging:
			global_position = get_global_mouse_position() + _drag_offset
			accept_event()
		else:
			# Update cursor shape based on edge
			var edge := _get_resize_edge(event.position)
			_update_cursor(edge)

func _apply_resize() -> void:
	var mouse := get_global_mouse_position()
	var delta := mouse - _resize_start_mouse
	var new_pos := _resize_start_pos
	var new_size := _resize_start_size

	if _resize_edge & 1: # left
		new_pos.x = _resize_start_pos.x + delta.x
		new_size.x = _resize_start_size.x - delta.x
	if _resize_edge & 2: # right
		new_size.x = _resize_start_size.x + delta.x
	if _resize_edge & 4: # top
		new_pos.y = _resize_start_pos.y + delta.y
		new_size.y = _resize_start_size.y - delta.y
	if _resize_edge & 8: # bottom
		new_size.y = _resize_start_size.y + delta.y

	# Clamp to minimum
	if new_size.x < MIN_PANEL_SIZE.x:
		if _resize_edge & 1:
			new_pos.x -= MIN_PANEL_SIZE.x - new_size.x
		new_size.x = MIN_PANEL_SIZE.x
	if new_size.y < MIN_PANEL_SIZE.y:
		if _resize_edge & 4:
			new_pos.y -= MIN_PANEL_SIZE.y - new_size.y
		new_size.y = MIN_PANEL_SIZE.y

	global_position = new_pos
	custom_minimum_size = new_size
	size = new_size

func _update_cursor(edge: int) -> void:
	if edge == 0:
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif edge == 1 or edge == 2:
		mouse_default_cursor_shape = Control.CURSOR_HSIZE
	elif edge == 4 or edge == 8:
		mouse_default_cursor_shape = Control.CURSOR_VSIZE
	elif edge == 5 or edge == 10: # top-left or bottom-right
		mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	elif edge == 6 or edge == 9: # top-right or bottom-left
		mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE

# ── Close on RMB outside ─────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		visible = false
		get_viewport().set_input_as_handled()

# ── Hotkey Assignment ────────────────────────────────────────────────────────

func _start_hotkey_assignment(id: StringName) -> void:
	_awaiting_hotkey_for = id
	hotkey_popup.visible = true
	hotkey_label.text = "Press a key (0-9, F1-F4)\nfor %s" % str(id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if _awaiting_hotkey_for != &"" and event is InputEventKey and event.pressed:
		var keycode: int = event.physical_keycode
		var valid := (keycode >= KEY_0 and keycode <= KEY_9) or (keycode >= KEY_F1 and keycode <= KEY_F4)
		if valid:
			# Remove any existing binding for this building
			for existing_key in GameManager.building_hotkeys.keys():
				if GameManager.building_hotkeys[existing_key] == _awaiting_hotkey_for:
					GameManager.building_hotkeys.erase(existing_key)
			GameManager.building_hotkeys[keycode] = _awaiting_hotkey_for
			_awaiting_hotkey_for = &""
			hotkey_popup.visible = false
			_refresh_hotkey_labels()
			AccountManager.save_hotkeys()
		get_viewport().set_input_as_handled()

func _refresh_hotkey_labels() -> void:
	for row in building_list.get_children():
		if row is PanelContainer and row.has_meta("building_id"):
			var bid: StringName = row.get_meta("building_id")
			var hotkey_lbl = row.find_child("HotkeyLabel", true, false)
			if hotkey_lbl:
				var key_str := _get_hotkey_for(bid)
				hotkey_lbl.text = "[%s]" % key_str if key_str != "" else ""

func _get_hotkey_for(building_id: StringName) -> String:
	for keycode in GameManager.building_hotkeys:
		if GameManager.building_hotkeys[keycode] == building_id:
			return OS.get_keycode_string(keycode)
	return ""

func _is_building_mode() -> bool:
	var gw = get_tree().root.get_node_or_null("GameWorld")
	if gw:
		var bs = gw.get_node_or_null("BuildSystem")
		if bs:
			return bs.building_mode
	return false

func _get_shape_size(def) -> Vector2i:
	if def.shape.is_empty():
		return Vector2i(1, 1)
	var min_c := Vector2i(999, 999)
	var max_c := Vector2i(-999, -999)
	for cell in def.shape:
		min_c.x = mini(min_c.x, cell.x)
		min_c.y = mini(min_c.y, cell.y)
		max_c.x = maxi(max_c.x, cell.x)
		max_c.y = maxi(max_c.y, cell.y)
	return max_c - min_c + Vector2i(1, 1)
