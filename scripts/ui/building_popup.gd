extends PanelContainer

## Compact contextual popup that appears above a clicked building.
## Shows recipe + segmented craft bar, energy bar, and inventory rows.

const TILE_SIZE := 32
const UPDATE_INTERVAL := 0.25
const SCREEN_MARGIN := 4.0
const GAP_ABOVE := 4.0

const SEGMENT_COUNT := 4
const SEGMENT_GAP := 2
const SEGMENT_COLOR_OFF := Color(0.15, 0.15, 0.15, 0.6)
const SEGMENT_COLOR_ON := Color(0.9, 0.75, 0.2, 0.95)
const SEGMENT_THRESHOLDS := [0.2, 0.4, 0.6, 0.8]

const ICON_SIZE := Vector2(12, 12)
const FONT_SIZE := 11

var _building: Node2D
var _update_timer: float = 0.0
var _camera: Camera2D
var _segments: Array = [] # 4 ColorRects inside CraftBar

@onready var recipe_section: VBoxContainer = %RecipeSection
@onready var craft_bar_row: HBoxContainer = %CraftBarRow
@onready var craft_bar: HBoxContainer = %CraftBar
@onready var recipe_row: HBoxContainer = %RecipeRow
@onready var energy_row: HBoxContainer = %EnergyRow
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var energy_label: Label = %EnergyLabel
@onready var inventory_row: HBoxContainer = %InventoryRow

func _ready() -> void:
	visible = false
	_setup_energy_bar_style()
	_setup_craft_segments()

func _setup_energy_bar_style() -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.45, 0.85, 0.9)
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	energy_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.14, 0.18, 0.7)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	energy_bar.add_theme_stylebox_override("background", bg)

func _setup_craft_segments() -> void:
	_segments.clear()
	for child in craft_bar.get_children():
		child.queue_free()
	for i in SEGMENT_COUNT:
		var seg := ColorRect.new()
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.custom_minimum_size = Vector2(0, 12)
		seg.color = SEGMENT_COLOR_OFF
		craft_bar.add_child(seg)
		_segments.append(seg)

func _process(delta: float) -> void:
	if not visible or not _building:
		return
	if not is_instance_valid(_building):
		hide_popup()
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
	_building = building
	_camera = camera
	_update_content()
	visible = true
	await get_tree().process_frame
	_update_position()

func hide_popup() -> void:
	visible = false
	_building = null

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

# ── Content ────────────────────────────────────────────────────────────────

func _update_content() -> void:
	if not _building or not is_instance_valid(_building):
		return
	var logic = _building.logic
	if not logic:
		return
	var recipe = logic.get_popup_recipe()
	_update_recipe_section(recipe, logic)
	_update_energy_row(logic.energy)
	var items: Array = logic.get_inventory_items()
	_update_inventory_row(items)

func _update_recipe_section(recipe, logic) -> void:
	if not recipe:
		recipe_section.visible = false
		return
	recipe_section.visible = true
	# Show/hide craft bar based on whether building has progress
	var progress: float = logic.get_popup_progress()
	craft_bar_row.visible = progress >= 0.0
	# Rebuild recipe items row
	for child in recipe_row.get_children():
		child.queue_free()
	for i in range(recipe.inputs.size()):
		if i > 0:
			_add_separator(recipe_row)
		_add_item_display(recipe_row, recipe.inputs[i])
	var arrow := Label.new()
	arrow.text = " → "
	arrow.add_theme_font_size_override("font_size", FONT_SIZE)
	recipe_row.add_child(arrow)
	for i in range(recipe.outputs.size()):
		if i > 0:
			_add_separator(recipe_row)
		_add_item_display(recipe_row, recipe.outputs[i])

func _update_progress_segments() -> void:
	if _segments.is_empty() or not _building or not is_instance_valid(_building):
		return
	var logic = _building.logic
	if not logic:
		return
	var progress: float = logic.get_popup_progress()
	if progress < 0.0:
		return
	for i in SEGMENT_COUNT:
		_segments[i].color = SEGMENT_COLOR_ON if progress >= SEGMENT_THRESHOLDS[i] else SEGMENT_COLOR_OFF

func _add_item_display(row: HBoxContainer, stack) -> void:
	var qty: int = stack.quantity
	var color: Color
	if stack is ItemStack:
		color = stack.item.color if stack.item else Color.WHITE
	else:
		color = stack.color # dict with {quantity, color}
	if qty > 1:
		var qty_label := Label.new()
		qty_label.text = str(qty)
		qty_label.add_theme_font_size_override("font_size", FONT_SIZE)
		row.add_child(qty_label)
	var color_rect := ColorRect.new()
	color_rect.custom_minimum_size = ICON_SIZE
	color_rect.color = color
	row.add_child(color_rect)

func _add_separator(row: HBoxContainer) -> void:
	var sep := Label.new()
	sep.text = "+"
	sep.add_theme_font_size_override("font_size", FONT_SIZE)
	sep.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	row.add_child(sep)

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
		child.queue_free()
	for entry in items:
		var item_def = GameManager.get_item_def(entry.id)
		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = ICON_SIZE
		color_rect.color = item_def.color if item_def else Color.WHITE
		inventory_row.add_child(color_rect)
		var label := Label.new()
		label.text = str(entry.count)
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		inventory_row.add_child(label)
