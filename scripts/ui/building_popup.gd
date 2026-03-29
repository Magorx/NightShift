extends PanelContainer

## Compact contextual popup that appears above a clicked building.
## Shows recipe + segmented craft bar, energy bar, and inventory rows.
## Recipe row is clickable to open a recipe selector menu.

const TILE_SIZE := 32
const UPDATE_INTERVAL := 0.25
const SCREEN_MARGIN := 4.0
const GAP_ABOVE := 4.0
const MENU_GAP := 6.0 # horizontal gap between popup and recipe menu

const SEGMENT_COLOR_OFF := Color(0.15, 0.15, 0.15, 0.6)
const SEGMENT_COLOR_ON := Color(0.9, 0.75, 0.2, 0.95)
const SEGMENT_THRESHOLDS := [0.2, 0.4, 0.6, 0.8]

const ICON_SIZE := Vector2(12, 12)
const ICON_BORDER := 1
const FONT_SIZE := 11
const NUM_WIDTH := 14.0 # fixed width for quantity numbers
const ENERGY_COLOR := Color(0.95, 0.85, 0.2)

var _building: Node2D
var _update_timer: float = 0.0
var _camera: Camera2D
var _recipe_menu = null
var _click_blocker: Control = null
var _recipe_menu_scene: PackedScene = preload("res://scenes/ui/recipe_menu.tscn")
var _col_widths: Dictionary = {} # {in_widths: Array, out_widths: Array, max_in: int, max_arrow_w: float}
var _recipe_row_normal_style: StyleBox
var _recipe_row_pressed_style: StyleBox

@onready var recipe_section: VBoxContainer = %RecipeSection
@onready var recipe_row_button: PanelContainer = %RecipeRowButton
@onready var craft_bar_row: HBoxContainer = %CraftBarRow
@onready var recipe_row: HBoxContainer = %RecipeRow
@onready var energy_row: HBoxContainer = %EnergyRow
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var energy_label: Label = %EnergyLabel
@onready var inventory_row: HBoxContainer = %InventoryRow
@onready var _segments: Array = [%Seg0, %Seg1, %Seg2, %Seg3]

func _ready() -> void:
	visible = false
	_recipe_row_normal_style = recipe_row_button.get_theme_stylebox("panel").duplicate()
	_recipe_row_pressed_style = _recipe_row_normal_style.duplicate()
	_recipe_row_pressed_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	_recipe_row_pressed_style.border_color = Color(0.4, 0.4, 0.4, 0.6)
	_recipe_row_pressed_style.content_margin_top = 3.0
	_recipe_row_pressed_style.content_margin_bottom = 1.0
	recipe_row_button.gui_input.connect(_on_recipe_row_input)

func _process(delta: float) -> void:
	if not _building:
		return
	if not is_instance_valid(_building):
		hide_popup()
		return
	var logic = _building.logic
	var has_content: bool = logic and _has_popup_content(logic)
	if has_content and not visible:
		visible = true
		_update_content()
		_update_position()
		return
	if not visible:
		return
	_update_position()
	_update_progress_segments()
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_update_content()

func show_building(building: Node2D, camera: Camera2D) -> void:
	if not building:
		hide_popup()
		return
	var logic = building.logic if building else null
	if logic and not _has_popup_content(logic):
		hide_popup()
		return
	_close_recipe_menu()
	_building = building
	_camera = camera
	recipe_row.custom_minimum_size.x = 0
	custom_minimum_size.x = 0
	_lock_width()
	_update_content()
	visible = true
	await get_tree().process_frame
	_update_position()

func _has_popup_content(logic) -> bool:
	if logic.get_popup_recipe():
		return true
	if logic.energy:
		return true
	if not logic.get_inventory_items().is_empty():
		return true
	return false

func _lock_width() -> void:
	if not _building or not _building.logic:
		_col_widths = {}
		return
	var logic = _building.logic
	var recipes: Array = []
	if logic.has_method("get_recipe_configs"):
		for config in logic.get_recipe_configs():
			recipes.append(config.recipe)
	elif logic.get_popup_recipe():
		recipes.append(logic.get_popup_recipe())
	if recipes.is_empty():
		_col_widths = {}
		return
	# Compute per-column number widths and arrow width
	_col_widths = _compute_column_widths(recipes)
	# Populate with widest recipe to measure row width
	var best_row_w: float = 0.0
	for recipe in recipes:
		_populate_recipe_row(recipe)
		best_row_w = maxf(best_row_w, recipe_row.get_combined_minimum_size().x)
	recipe_row.custom_minimum_size.x = best_row_w
	custom_minimum_size.x = get_combined_minimum_size().x

func _compute_column_widths(recipes: Array) -> Dictionary:
	var font: Font = get_theme_font("font")
	var max_in: int = 0
	var max_out: int = 0
	for recipe in recipes:
		var in_count: int = recipe.inputs.size()
		if recipe is RecipeDef and recipe.energy_cost > 0.0:
			in_count += 1
		max_in = maxi(max_in, in_count)
		var out_count: int = recipe.outputs.size()
		if recipe is RecipeDef and recipe.energy_output > 0.0:
			out_count += 1
		max_out = maxi(max_out, out_count)
	var in_widths: Array = []
	in_widths.resize(max_in)
	in_widths.fill(0.0)
	var out_widths: Array = []
	out_widths.resize(max_out)
	out_widths.fill(0.0)
	var max_arrow_w: float = 0.0
	for recipe in recipes:
		var idx: int = 0
		for stack in recipe.inputs:
			var w: float = font.get_string_size(str(stack.quantity), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			in_widths[idx] = maxf(in_widths[idx], w)
			idx += 1
		if recipe is RecipeDef and recipe.energy_cost > 0.0:
			var w: float = font.get_string_size(str(int(recipe.energy_cost)), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			in_widths[idx] = maxf(in_widths[idx], w)
		var out_idx: int = 0
		for i in range(recipe.outputs.size()):
			var w: float = font.get_string_size(str(recipe.outputs[i].quantity), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			out_widths[i] = maxf(out_widths[i], w)
			out_idx = i + 1
		if recipe is RecipeDef and recipe.energy_output > 0.0:
			var w: float = font.get_string_size(str(int(recipe.energy_output)), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			out_widths[out_idx] = maxf(out_widths[out_idx], w)
		if recipe is RecipeDef:
			var aw: float = font.get_string_size("—%.0fs→" % recipe.craft_time, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			max_arrow_w = maxf(max_arrow_w, aw)
		else:
			var aw: float = font.get_string_size("→", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			max_arrow_w = maxf(max_arrow_w, aw)
	return {in_widths = in_widths, out_widths = out_widths, max_in = max_in, max_arrow_w = max_arrow_w}

func hide_popup() -> void:
	_close_recipe_menu()
	visible = false
	_building = null

# ── Recipe menu ────────────────────────────────────────────────────────────

func _on_recipe_row_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _building or not _building.logic or not _building.logic.has_method("get_recipe_configs"):
		return
	recipe_row_button.accept_event()
	if event.pressed:
		recipe_row_button.add_theme_stylebox_override("panel", _recipe_row_pressed_style)
	else:
		recipe_row_button.add_theme_stylebox_override("panel", _recipe_row_normal_style)
		_toggle_recipe_menu()

func _toggle_recipe_menu() -> void:
	if _recipe_menu:
		_close_recipe_menu()
		return
	var configs: Array = _building.logic.get_recipe_configs()
	if configs.is_empty():
		return
	# Click blocker (full-screen transparent layer to catch outside clicks)
	_click_blocker = Control.new()
	_click_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_click_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_blocker.gui_input.connect(_on_blocker_input)
	get_parent().add_child(_click_blocker)
	# Menu
	_recipe_menu = _recipe_menu_scene.instantiate()
	get_parent().add_child(_recipe_menu)
	_recipe_menu.populate(configs)
	# Position to the right of the recipe row
	await get_tree().process_frame
	_position_recipe_menu()

func _position_recipe_menu() -> void:
	if not _recipe_menu or not is_instance_valid(recipe_row_button):
		return
	var popup_rect := get_global_rect()
	var row_rect := recipe_row_button.get_global_rect()
	var menu_x := popup_rect.end.x + MENU_GAP
	var menu_y := popup_rect.position.y
	# If menu would go off-screen right, place it to the left
	var viewport_w := get_viewport_rect().size.x
	if menu_x + _recipe_menu.size.x > viewport_w - SCREEN_MARGIN:
		menu_x = popup_rect.position.x - _recipe_menu.size.x - MENU_GAP
	_recipe_menu.position = Vector2(menu_x, menu_y)

func _on_blocker_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var click_pos: Vector2 = event.global_position
	var in_popup := get_global_rect().has_point(click_pos)
	var in_menu: bool = _recipe_menu and _recipe_menu.get_global_rect().has_point(click_pos)
	if not in_popup and not in_menu:
		_close_recipe_menu()
		hide_popup()
	elif not in_menu:
		_close_recipe_menu()

func _close_recipe_menu() -> void:
	if _recipe_menu:
		_recipe_menu.queue_free()
		_recipe_menu = null
	if _click_blocker:
		_click_blocker.queue_free()
		_click_blocker = null

# ── Positioning ────────────────────────────────────────────────────────────

func _update_position() -> void:
	if not _building or not _camera:
		return
	var def = GameManager.get_building_def(_building.building_id)
	if not def:
		return
	var rotated_shape: Array = def.get_rotated_shape(_building.rotation_index)
	var min_cell := Vector2i(999, 999)
	var max_cell := Vector2i(-999, -999)
	for cell in rotated_shape:
		var world_cell: Vector2i = _building.grid_pos + cell
		min_cell.x = mini(min_cell.x, world_cell.x)
		min_cell.y = mini(min_cell.y, world_cell.y)
		max_cell.x = maxi(max_cell.x, world_cell.x + 1)
		max_cell.y = maxi(max_cell.y, world_cell.y + 1)
	var top_center_world := Vector2(
		(min_cell.x + max_cell.x) * 0.5 * TILE_SIZE,
		min_cell.y * TILE_SIZE
	)
	var bottom_center_world := Vector2(top_center_world.x, max_cell.y * TILE_SIZE)
	var viewport_size := get_viewport_rect().size
	var canvas_xform := get_viewport().get_canvas_transform()
	var top_screen: Vector2 = canvas_xform * top_center_world
	var bottom_screen: Vector2 = canvas_xform * bottom_center_world
	if bottom_screen.y < 0 or top_screen.y > viewport_size.y \
		or bottom_screen.x < -TILE_SIZE * _camera.zoom.x or top_screen.x > viewport_size.x + TILE_SIZE * _camera.zoom.x:
		hide_popup()
		return
	var popup_size := size
	var target_x := top_screen.x - popup_size.x * 0.5
	var target_y := top_screen.y - popup_size.y - GAP_ABOVE
	target_x = clampf(target_x, SCREEN_MARGIN, viewport_size.x - popup_size.x - SCREEN_MARGIN)
	position = Vector2(target_x, target_y)
	# Reposition menu if open
	if _recipe_menu:
		_position_recipe_menu()

# ── Content ────────────────────────────────────────────────────────────────

func _update_content() -> void:
	if not _building or not is_instance_valid(_building):
		return
	var logic = _building.logic
	if not logic:
		return
	if not _has_popup_content(logic):
		visible = false
		return
	visible = true
	var recipe = logic.get_popup_recipe()
	_update_recipe_section(recipe, logic)
	_update_energy_row(logic.energy)
	var items: Array = logic.get_inventory_items()
	_update_inventory_row(items)
	# Force PanelContainer to recalculate height when rows hide (keep locked width)
	var locked_w := custom_minimum_size.x
	size = Vector2(locked_w, 0) if locked_w > 0 else Vector2.ZERO

func _update_recipe_section(recipe, logic) -> void:
	if not recipe:
		recipe_section.visible = false
		return
	recipe_section.visible = true
	var progress: float = logic.get_popup_progress()
	craft_bar_row.visible = progress >= 0.0
	_populate_recipe_row(recipe)

func _populate_recipe_row(recipe) -> void:
	for child in recipe_row.get_children():
		recipe_row.remove_child(child)
		child.queue_free()

	var in_widths: Array = _col_widths.get("in_widths", [])
	var out_widths: Array = _col_widths.get("out_widths", [])
	var max_in: int = _col_widths.get("max_in", 0)
	var max_arrow_w: float = _col_widths.get("max_arrow_w", 0.0)
	var sep: float = recipe_row.get_theme_constant("separation")

	# Inputs
	var slot_idx: int = 0
	for stack in recipe.inputs:
		var w: float = in_widths[slot_idx] if slot_idx < in_widths.size() else NUM_WIDTH
		_add_item_slot(recipe_row, stack, w)
		slot_idx += 1
	# Energy cost
	if recipe is RecipeDef and recipe.energy_cost > 0.0:
		var w: float = in_widths[slot_idx] if slot_idx < in_widths.size() else NUM_WIDTH
		_add_slot(recipe_row, str(int(recipe.energy_cost)), ENERGY_COLOR, w)
		slot_idx += 1
	# Pad empty input columns
	while slot_idx < max_in:
		var w: float = in_widths[slot_idx] if slot_idx < in_widths.size() else NUM_WIDTH
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(w + ICON_SIZE.x + sep, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		recipe_row.add_child(pad)
		slot_idx += 1

	# Arrow with craft time (fixed width for alignment)
	var arrow := Label.new()
	if recipe is RecipeDef:
		arrow.text = "—%.0fs→" % recipe.craft_time
	else:
		arrow.text = "→"
	arrow.add_theme_font_size_override("font_size", FONT_SIZE)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if max_arrow_w > 0.0:
		arrow.custom_minimum_size = Vector2(max_arrow_w, 0)
	recipe_row.add_child(arrow)

	# Outputs
	var out_slot_idx: int = 0
	for i in range(recipe.outputs.size()):
		var w: float = out_widths[i] if i < out_widths.size() else NUM_WIDTH
		_add_item_slot(recipe_row, recipe.outputs[i], w)
		out_slot_idx = i + 1
	# Energy output
	if recipe is RecipeDef and recipe.energy_output > 0.0:
		var w: float = out_widths[out_slot_idx] if out_slot_idx < out_widths.size() else NUM_WIDTH
		_add_slot(recipe_row, str(int(recipe.energy_output)), ENERGY_COLOR, w)

func _update_progress_segments() -> void:
	if not _building or not is_instance_valid(_building):
		return
	var logic = _building.logic
	if not logic:
		return
	var progress: float = logic.get_popup_progress()
	if progress < 0.0:
		return
	for i in _segments.size():
		_segments[i].color = SEGMENT_COLOR_ON if progress >= SEGMENT_THRESHOLDS[i] else SEGMENT_COLOR_OFF

func _add_item_slot(row: HBoxContainer, stack, num_w: float = NUM_WIDTH) -> void:
	var qty: int = stack.quantity
	var item_id: StringName = &""
	if stack is ItemStack and stack.item:
		item_id = stack.item.id
	var num_label := Label.new()
	num_label.text = str(qty)
	num_label.add_theme_font_size_override("font_size", FONT_SIZE)
	num_label.custom_minimum_size = Vector2(num_w, 0)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(num_label)
	row.add_child(_create_item_icon(item_id))

func _add_slot(row: HBoxContainer, num_text: String, color: Color, num_w: float = NUM_WIDTH) -> void:
	var num_label := Label.new()
	num_label.text = num_text
	num_label.add_theme_font_size_override("font_size", FONT_SIZE)
	num_label.custom_minimum_size = Vector2(num_w, 0)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(num_label)
	row.add_child(_create_color_icon(color))

func _create_item_icon(item_id: StringName) -> Control:
	var icon := GameManager.get_item_icon(item_id)
	if icon:
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon
		tex_rect.custom_minimum_size = ICON_SIZE
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tex_rect
	return _create_color_icon(Color.WHITE)

func _create_color_icon(color: Color) -> PanelContainer:
	var outline_color := Color.BLACK if color.get_luminance() > 0.4 else Color.WHITE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = outline_color
	style.border_width_left = ICON_BORDER
	style.border_width_top = ICON_BORDER
	style.border_width_right = ICON_BORDER
	style.border_width_bottom = ICON_BORDER
	var panel := PanelContainer.new()
	panel.custom_minimum_size = ICON_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _update_energy_row(e) -> void:
	if not e:
		energy_row.visible = false
		return
	energy_row.visible = true
	energy_bar.value = e.get_fill_ratio() * 100.0
	energy_label.text = "%d/%d" % [int(e.energy_stored), int(e.energy_capacity)]

func _update_inventory_row(items: Array) -> void:
	if items.is_empty():
		inventory_row.visible = false
		return
	inventory_row.visible = true
	for child in inventory_row.get_children():
		inventory_row.remove_child(child)
		child.queue_free()
	# Compute max number width across all inventory items
	var font: Font = get_theme_font("font")
	var max_num_w: float = 0.0
	for entry in items:
		var w: float = font.get_string_size(str(entry.count), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		max_num_w = maxf(max_num_w, w)
	for entry in items:
		var num_label := Label.new()
		num_label.text = str(entry.count)
		num_label.add_theme_font_size_override("font_size", FONT_SIZE)
		num_label.custom_minimum_size = Vector2(max_num_w, 0)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inventory_row.add_child(num_label)
		inventory_row.add_child(_create_item_icon(entry.id))
