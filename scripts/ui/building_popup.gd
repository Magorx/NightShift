extends PanelContainer

## Compact contextual popup that appears above a clicked building.
## Shows recipe, energy bar, and inventory rows as applicable.

const TILE_SIZE := 32
const UPDATE_INTERVAL := 0.25
const SCREEN_MARGIN := 4.0
const GAP_ABOVE := 4.0 # pixels between popup bottom and building top

var _building: Node2D
var _update_timer: float = 0.0
var _camera: Camera2D

@onready var recipe_row: HBoxContainer = %RecipeRow
@onready var energy_row: HBoxContainer = %EnergyRow
@onready var energy_bar: ProgressBar = %EnergyBar
@onready var energy_label: Label = %EnergyLabel
@onready var inventory_row: HBoxContainer = %InventoryRow

func _ready() -> void:
	visible = false
	# Style the energy bar blue
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.2, 0.45, 0.85, 0.9)
	bar_style.corner_radius_top_left = 2
	bar_style.corner_radius_top_right = 2
	bar_style.corner_radius_bottom_left = 2
	bar_style.corner_radius_bottom_right = 2
	energy_bar.add_theme_stylebox_override("fill", bar_style)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.14, 0.18, 0.7)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	energy_bar.add_theme_stylebox_override("background", bar_bg)

func _process(delta: float) -> void:
	if not visible or not _building:
		return
	if not is_instance_valid(_building):
		hide_popup()
		return
	_update_position()
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
	# Position immediately (need to wait one frame for size to be calculated)
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

	# Get the building's bounding box in grid coords
	var rotated_shape: Array = def.get_rotated_shape(_building.rotation_index)
	var min_cell := Vector2i(999, 999)
	var max_cell := Vector2i(-999, -999)
	for cell in rotated_shape:
		var world_cell: Vector2i = _building.grid_pos + cell
		min_cell.x = mini(min_cell.x, world_cell.x)
		min_cell.y = mini(min_cell.y, world_cell.y)
		max_cell.x = maxi(max_cell.x, world_cell.x + 1)
		max_cell.y = maxi(max_cell.y, world_cell.y + 1)

	# World-space positions
	var top_center_world := Vector2(
		(min_cell.x + max_cell.x) * 0.5 * TILE_SIZE,
		min_cell.y * TILE_SIZE
	)
	var bottom_center_world := Vector2(
		top_center_world.x,
		max_cell.y * TILE_SIZE
	)

	# Convert to screen space
	var viewport_size := get_viewport_rect().size
	var canvas_xform := get_viewport().get_canvas_transform()
	var top_screen: Vector2 = canvas_xform * top_center_world
	var bottom_screen: Vector2 = canvas_xform * bottom_center_world

	# If building is entirely off-screen, hide
	if bottom_screen.y < 0 or top_screen.y > viewport_size.y \
		or bottom_screen.x < -TILE_SIZE * _camera.zoom.x or top_screen.x > viewport_size.x + TILE_SIZE * _camera.zoom.x:
		hide_popup()
		return

	# Position: bottom of popup above building top
	var popup_size := size
	var target_x := top_screen.x - popup_size.x * 0.5
	var target_y := top_screen.y - popup_size.y - GAP_ABOVE

	# Clamp X to keep on screen
	target_x = clampf(target_x, SCREEN_MARGIN, viewport_size.x - popup_size.x - SCREEN_MARGIN)

	position = Vector2(target_x, target_y)

# ── Content ────────────────────────────────────────────────────────────────

func _update_content() -> void:
	if not _building or not is_instance_valid(_building):
		return
	var logic = _building.logic
	if not logic:
		return

	# Recipe row
	var recipe = logic.get_popup_recipe()
	_update_recipe_row(recipe)

	# Energy row
	_update_energy_row(logic.energy)

	# Inventory row
	var items: Array = logic.get_inventory_items()
	_update_inventory_row(items)

func _update_recipe_row(recipe) -> void:
	if not recipe:
		recipe_row.visible = false
		return
	recipe_row.visible = true
	# Clear old children
	for child in recipe_row.get_children():
		child.queue_free()
	# Build: "qty [color] qty [color] -> qty [color] qty [color]"
	for i in range(recipe.inputs.size()):
		var stack = recipe.inputs[i]
		if i > 0:
			_add_separator(recipe_row)
		_add_item_display(recipe_row, stack)
	# Arrow
	var arrow := Label.new()
	arrow.text = " → "
	arrow.add_theme_font_size_override("font_size", 11)
	recipe_row.add_child(arrow)
	# Outputs
	for i in range(recipe.outputs.size()):
		var stack = recipe.outputs[i]
		if i > 0:
			_add_separator(recipe_row)
		_add_item_display(recipe_row, stack)

func _add_item_display(row: HBoxContainer, stack) -> void:
	if stack.quantity > 1:
		var qty_label := Label.new()
		qty_label.text = str(stack.quantity)
		qty_label.add_theme_font_size_override("font_size", 11)
		row.add_child(qty_label)
	var color_rect := ColorRect.new()
	color_rect.custom_minimum_size = Vector2(10, 10)
	color_rect.color = stack.item.color if stack.item else Color.WHITE
	row.add_child(color_rect)

func _add_separator(row: HBoxContainer) -> void:
	var sep := Label.new()
	sep.text = "+"
	sep.add_theme_font_size_override("font_size", 9)
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
	# Clear old children
	for child in inventory_row.get_children():
		child.queue_free()
	for entry in items:
		var item_def = GameManager.get_item_def(entry.id)
		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = Vector2(10, 10)
		color_rect.color = item_def.color if item_def else Color.WHITE
		inventory_row.add_child(color_rect)
		var label := Label.new()
		label.text = str(entry.count)
		label.add_theme_font_size_override("font_size", 10)
		inventory_row.add_child(label)
