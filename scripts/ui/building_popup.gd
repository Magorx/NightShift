extends PanelContainer

## Compact contextual popup that appears above a clicked building.
## Shows recipe + segmented craft bar, energy bar, and inventory rows.
## Recipe row is clickable to open a recipe selector menu.

signal dismissed

const TILE_SIZE := 32
const UPDATE_INTERVAL := 0.25
const SCREEN_MARGIN := 4.0
const GAP_ABOVE := 4.0
const MENU_GAP := 6.0 # horizontal gap between popup and recipe menu

const SEGMENT_COLOR_OFF := Color(0.15, 0.15, 0.15, 0.6)
const SEGMENT_COLOR_ON := Color(0.9, 0.75, 0.2, 0.95)
const SEGMENT_THRESHOLDS := [0.2, 0.4, 0.6, 0.8]

const ICON_SIZE := Vector2(16, 16)
const FONT_SIZE := 12
const NUM_WIDTH := 16.0 # fixed width for quantity numbers

var _building: Node2D
var _update_timer: float = 0.0
var _camera: Camera2D
var _side_menu = null # currently open side menu (recipe menu or custom)
var _click_blocker: Control = null
var _recipe_menu_scene: PackedScene = preload("res://scenes/ui/recipe_menu.tscn")
var _col_widths: Dictionary = {} # {in_widths: Array, out_widths: Array, max_in: int, max_arrow_w: float}
var _clickable_row_normal_style: StyleBox
var _clickable_row_pressed_style: StyleBox
var _current_recipe = null # cached recipe to avoid rebuilding every update
var _current_custom_items: Array = [] # cached custom row items

@onready var recipe_section: VBoxContainer = %RecipeSection
@onready var recipe_row_button: PanelContainer = %RecipeRowButton
@onready var craft_bar_row: HBoxContainer = %CraftBarRow
@onready var recipe_row: HBoxContainer = %RecipeRow
@onready var custom_section: VBoxContainer = %CustomSection
@onready var custom_row_button: PanelContainer = %CustomRowButton
@onready var custom_row: HBoxContainer = %CustomRow
@onready var energy_row: HBoxContainer = %EnergyRow
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var energy_label: Label = %EnergyLabel
@onready var inventory_row: HBoxContainer = %InventoryRow
@onready var _segments: Array = [%Seg0, %Seg1, %Seg2, %Seg3]

func _ready() -> void:
	visible = false
	_clickable_row_normal_style = recipe_row_button.get_theme_stylebox("panel").duplicate()
	_clickable_row_pressed_style = _clickable_row_normal_style.duplicate()
	_clickable_row_pressed_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	_clickable_row_pressed_style.border_color = Color(0.4, 0.4, 0.4, 0.6)
	_clickable_row_pressed_style.content_margin_top = 3.0
	_clickable_row_pressed_style.content_margin_bottom = 1.0
	recipe_row_button.gui_input.connect(_on_clickable_row_input.bind(recipe_row_button, _toggle_recipe_menu))
	custom_row_button.gui_input.connect(_on_clickable_row_input.bind(custom_row_button, _toggle_custom_menu))

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
	_close_side_menu()
	_building = building
	_camera = camera
	_current_recipe = null
	_current_custom_items = []
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
	if logic.has_custom_popup_row():
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
	var has_energy_cost: bool = false
	for recipe in recipes:
		max_in = maxi(max_in, recipe.inputs.size())
		if recipe is RecipeDef and recipe.energy_cost > 0.0:
			has_energy_cost = true
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
	var energy_cost_w: float = 0.0
	var max_arrow_w: float = 0.0
	for recipe in recipes:
		for idx in range(recipe.inputs.size()):
			var w: float = font.get_string_size(str(recipe.inputs[idx].quantity), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			in_widths[idx] = maxf(in_widths[idx], w)
		if recipe is RecipeDef and recipe.energy_cost > 0.0:
			var w: float = font.get_string_size(str(int(recipe.energy_cost)), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			energy_cost_w = maxf(energy_cost_w, w)
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
	return {in_widths = in_widths, out_widths = out_widths, max_in = max_in, max_arrow_w = max_arrow_w, has_energy_cost = has_energy_cost, energy_cost_w = energy_cost_w}

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _side_menu:
			_close_side_menu()
		else:
			hide_popup()
			dismissed.emit()
		get_viewport().set_input_as_handled()

func hide_popup() -> void:
	_close_side_menu()
	visible = false
	_building = null
	_current_recipe = null
	_current_custom_items = []

# ── Clickable row + side menu (shared by recipe row and custom row) ───────

func _on_clickable_row_input(event: InputEvent, button: PanelContainer, toggle_fn: Callable) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if not _building or not _building.logic:
		return
	button.accept_event()
	if event.pressed:
		button.add_theme_stylebox_override("panel", _clickable_row_pressed_style)
	else:
		button.add_theme_stylebox_override("panel", _clickable_row_normal_style)
		toggle_fn.call()

func _toggle_recipe_menu() -> void:
	if _side_menu:
		_close_side_menu()
		return
	if not _building.logic.has_method("get_recipe_configs"):
		return
	var configs: Array = _building.logic.get_recipe_configs()
	if configs.is_empty():
		return
	var menu = _recipe_menu_scene.instantiate()
	_open_side_menu(menu)
	menu.populate(configs, _building.logic)

func _toggle_custom_menu() -> void:
	if _side_menu:
		_close_side_menu()
		return
	if not _building or not _building.logic:
		return
	var menu: Control = _building.logic.create_side_menu()
	if not menu:
		return
	_open_side_menu(menu)

func _open_side_menu(menu: Control) -> void:
	_close_side_menu()
	_click_blocker = Control.new()
	_click_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_click_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_click_blocker.gui_input.connect(_on_blocker_input)
	get_parent().add_child(_click_blocker)
	_side_menu = menu
	get_parent().add_child(_side_menu)
	await get_tree().process_frame
	_position_side_menu()

func _position_side_menu() -> void:
	if not _side_menu:
		return
	var popup_rect := get_global_rect()
	var menu_x := popup_rect.end.x + MENU_GAP
	var menu_y := popup_rect.position.y
	var viewport_w := get_viewport_rect().size.x
	if menu_x + _side_menu.size.x > viewport_w - SCREEN_MARGIN:
		menu_x = popup_rect.position.x - _side_menu.size.x - MENU_GAP
	_side_menu.position = Vector2(menu_x, menu_y)

func _on_blocker_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var click_pos: Vector2 = event.global_position
	var in_popup := get_global_rect().has_point(click_pos)
	var in_menu: bool = _side_menu and _side_menu.get_global_rect().has_point(click_pos)
	if not in_popup and not in_menu:
		_close_side_menu()
		hide_popup()
		dismissed.emit()
	elif not in_menu:
		_close_side_menu()

func _close_side_menu() -> void:
	if _side_menu:
		_side_menu.queue_free()
		_side_menu = null
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
	target_y = clampf(target_y, SCREEN_MARGIN, viewport_size.y - popup_size.y - SCREEN_MARGIN)
	position = Vector2(target_x, target_y)
	# Reposition menu if open
	if _side_menu:
		_position_side_menu()

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
	_update_custom_section(logic)
	_update_energy_row(logic.energy)
	var items: Array = logic.get_inventory_items()
	_update_inventory_row(items)
	# Force PanelContainer to recalculate height when rows hide (keep locked width)
	var locked_w := custom_minimum_size.x
	size = Vector2(locked_w, 0) if locked_w > 0 else Vector2.ZERO

func _update_recipe_section(recipe, logic) -> void:
	if not recipe:
		recipe_section.visible = false
		_current_recipe = null
		return
	recipe_section.visible = true
	var progress: float = logic.get_popup_progress()
	craft_bar_row.visible = progress >= 0.0
	if recipe != _current_recipe:
		_current_recipe = recipe
		_populate_recipe_row(recipe)

func _update_custom_section(logic) -> void:
	if not logic.has_custom_popup_row():
		custom_section.visible = false
		return
	custom_section.visible = true
	var items: Array = logic.get_custom_row_items()
	if items == _current_custom_items:
		return
	_current_custom_items = items.duplicate()
	_populate_custom_row(items)

func _populate_custom_row(items: Array) -> void:
	for child in custom_row.get_children():
		custom_row.remove_child(child)
		child.queue_free()
	for entry in items:
		var icon: Control = ItemIcon.create(entry.id, ICON_SIZE)
		custom_row.add_child(icon)

func _populate_recipe_row(recipe) -> void:
	for child in recipe_row.get_children():
		recipe_row.remove_child(child)
		child.queue_free()

	var in_widths: Array = _col_widths.get("in_widths", [])
	var out_widths: Array = _col_widths.get("out_widths", [])
	var max_in: int = _col_widths.get("max_in", 0)
	var max_arrow_w: float = _col_widths.get("max_arrow_w", 0.0)
	var has_energy_cost: bool = _col_widths.get("has_energy_cost", false)
	var energy_cost_w: float = _col_widths.get("energy_cost_w", 0.0)
	var sep: float = recipe_row.get_theme_constant("separation")

	# Item inputs
	var slot_idx: int = 0
	for stack in recipe.inputs:
		var w: float = in_widths[slot_idx] if slot_idx < in_widths.size() else NUM_WIDTH
		_add_item_slot(recipe_row, stack, w)
		slot_idx += 1
	# Pad empty item input columns
	while slot_idx < max_in:
		var w: float = in_widths[slot_idx] if slot_idx < in_widths.size() else NUM_WIDTH
		recipe_row.add_child(_create_empty_billet(w))
		slot_idx += 1
	# Energy cost (dedicated last input columns)
	if has_energy_cost:
		if recipe is RecipeDef and recipe.energy_cost > 0.0:
			_add_energy_slot(recipe_row, str(int(recipe.energy_cost)), energy_cost_w)
		else:
			recipe_row.add_child(_create_empty_billet(energy_cost_w))

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
		_add_energy_slot(recipe_row, str(int(recipe.energy_output)), w)

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
	row.add_child(_create_slot_billet(str(qty), num_w, ItemIcon.create(item_id, ICON_SIZE)))

func _add_energy_slot(row: HBoxContainer, num_text: String, num_w: float = NUM_WIDTH) -> void:
	row.add_child(_create_slot_billet(num_text, num_w, ItemIcon.create(&"energy", ICON_SIZE)))

func _create_slot_billet(num_text: String, num_w: float, icon: Control) -> PanelContainer:
	return _build_billet(UIStyles.slot_panel(Color(0.08, 0.08, 0.08, 0.6), 3, 1), num_text, num_w, icon)

func _create_empty_billet(num_w: float) -> PanelContainer:
	return _build_billet(UIStyles.slot_panel(Color.TRANSPARENT, 0, 1), "", num_w, null)

func _build_billet(style: StyleBoxFlat, num_text: String, num_w: float, icon: Control) -> PanelContainer:
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 1)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num_label := Label.new()
	num_label.text = num_text
	num_label.add_theme_font_size_override("font_size", FONT_SIZE)
	num_label.custom_minimum_size = Vector2(num_w, 0)
	if num_text != "":
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(num_label)
	if icon:
		hbox.add_child(icon)
	else:
		var icon_pad := Control.new()
		icon_pad.custom_minimum_size = ICON_SIZE
		icon_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon_pad)
	panel.add_child(hbox)
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
	# Compute max number width across all inventory items
	var font: Font = get_theme_font("font")
	var max_num_w: float = 0.0
	for entry in items:
		var w: float = font.get_string_size(str(entry.count), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		max_num_w = maxf(max_num_w, w)
	var existing := inventory_row.get_children()
	# Reuse existing slots, add new ones as needed, remove extras
	for i in items.size():
		var entry = items[i]
		if i < existing.size():
			# Reuse existing billet
			var panel: PanelContainer = existing[i]
			var hbox: HBoxContainer = panel.get_child(0)
			var num_label: Label = hbox.get_child(0)
			num_label.text = str(entry.count)
			num_label.custom_minimum_size.x = max_num_w
			var icon: ItemIcon = hbox.get_child(1) as ItemIcon
			if icon:
				icon.set_item(entry.id)
			panel.set_meta(&"item_id", entry.id)
		else:
			# Create new billet
			var slot := _create_inventory_slot(str(entry.count), max_num_w, entry.id)
			inventory_row.add_child(slot)
	# Remove excess slots
	for i in range(existing.size() - 1, items.size() - 1, -1):
		var child := existing[i]
		inventory_row.remove_child(child)
		child.queue_free()

func _create_inventory_slot(num_text: String, num_w: float, item_id: StringName) -> PanelContainer:
	var panel := _create_slot_billet(num_text, num_w, ItemIcon.create(item_id, ICON_SIZE))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta(&"item_id", item_id)
	panel.gui_input.connect(_on_inventory_slot_input.bind(panel))
	return panel

func _on_inventory_slot_input(event: InputEvent, panel: PanelContainer) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if not _building or not is_instance_valid(_building) or not _building.logic:
		return
	var player: Player = GameManager.player
	if not player or not is_instance_valid(player):
		return
	var item_id: StringName = panel.get_meta(&"item_id", &"")
	if item_id == &"":
		return
	panel.accept_event()
	# Try to remove 1 item from building and add to player
	var removed: int = _building.logic.remove_inventory_item(item_id, 1)
	if removed > 0:
		var leftover: int = player.add_item(item_id, removed)
		if leftover > 0:
			# Player inventory full — drop as ground item
			player._spawn_ground_item(item_id, leftover, player.position)
		_update_content()
