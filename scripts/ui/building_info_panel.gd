extends PanelContainer

var _building: Node2D
var _update_timer: float = 0.0

@onready var header_color: ColorRect = %HeaderColor
@onready var header_label: Label = %HeaderLabel
@onready var type_label: Label = %TypeLabel
@onready var stats_container: VBoxContainer = %StatsContainer
@onready var recipe_section: VBoxContainer = %RecipeSection
@onready var recipe_label: Label = %RecipeLabel
@onready var inputs_row: HBoxContainer = %InputsRow
@onready var outputs_row: HBoxContainer = %OutputsRow

func _ready() -> void:
	visible = false

func _process(delta: float) -> void:
	if not visible or not _building:
		return
	if not is_instance_valid(_building):
		hide_panel()
		return
	_update_timer += delta
	if _update_timer >= 0.25:
		_update_timer = 0.0
		_update_stats()

func show_building(building: Node2D) -> void:
	if not building:
		hide_panel()
		return
	_building = building
	var def = GameManager.get_building_def(building.building_id)
	if not def:
		hide_panel()
		return

	header_color.color = def.color
	header_label.text = def.display_name
	type_label.text = def.category.capitalize()
	_update_stats()
	visible = true

func hide_panel() -> void:
	visible = false
	_building = null

func _update_stats() -> void:
	if not _building or not is_instance_valid(_building):
		return
	# Clear old stats
	for child in stats_container.get_children():
		child.queue_free()
	recipe_section.visible = false

	var logic = _building.logic
	if not logic:
		return

	# All building types return structured info via get_info_stats()
	var stats: Array = logic.get_info_stats()
	for entry in stats:
		match entry.type:
			"stat":
				_add_stat(entry.text)
			"progress":
				_add_progress_bar(entry.value)
			"recipe":
				_show_recipe(entry.recipe, entry.active)
			"inventory":
				_show_inventory(entry.label, entry.items)

func _show_recipe(recipe, _active: bool) -> void:
	recipe_section.visible = true
	recipe_label.text = "Recipe: %s" % recipe.display_name
	_populate_io_row(inputs_row, recipe.inputs)
	_populate_io_row(outputs_row, recipe.outputs)

func _show_inventory(label_text: String, items: Array) -> void:
	var text := label_text + ": "
	for item in items:
		text += "%dx %s  " % [item.count, str(item.id).replace("_", " ")]
	_add_stat(text)

func _add_stat(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	stats_container.add_child(label)

func _add_progress_bar(value: float) -> void:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.value = value * 100.0
	bar.show_percentage = false
	stats_container.add_child(bar)

func _populate_io_row(row: HBoxContainer, stacks: Array) -> void:
	for child in row.get_children():
		child.queue_free()
	for stack in stacks:
		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = Vector2(12, 12)
		color_rect.color = stack.item.color if stack.item else Color.WHITE
		row.add_child(color_rect)
		var label := Label.new()
		label.text = "%dx %s" % [stack.quantity, stack.item.display_name if stack.item else "?"]
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)
