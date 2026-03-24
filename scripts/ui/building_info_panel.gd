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

	var def = GameManager.get_building_def(_building.building_id)
	if not def:
		return

	var logic: Node = _building.logic
	if not logic:
		return

	if logic is ConveyorBelt:
		_add_stat("Items on belt: %d/%d" % [logic.buffer.size(), logic.buffer.capacity])
		var dirs := ["Right", "Down", "Left", "Up"]
		_add_stat("Direction: %s" % dirs[logic.direction])

	elif logic is ExtractorLogic:
		_add_stat("Extracting: %s" % str(logic.item_id).capitalize().replace("_", " "))
		_add_progress_bar(logic.get_progress())
		_add_stat("Inventory: %d/5" % logic.inventory.get_count(logic.item_id))

	elif logic is ConverterLogic:
		_update_converter_stats(logic)

	elif logic is ItemSink:
		_add_stat("Items consumed: %d" % logic.items_consumed)

	elif logic is ItemSource:
		_add_stat("Producing: %s" % str(logic.item_id).capitalize().replace("_", " "))
		_add_stat("Rate: 1/%.1fs" % logic.produce_interval)

func _update_converter_stats(conv_logic: ConverterLogic) -> void:
	if conv_logic._active_recipe:
		recipe_section.visible = true
		recipe_label.text = "Recipe: %s" % conv_logic._active_recipe.display_name
		_populate_io_row(inputs_row, conv_logic._active_recipe.inputs)
		_populate_io_row(outputs_row, conv_logic._active_recipe.outputs)
		_add_stat("Craft progress:")
		_add_progress_bar(conv_logic.get_progress())
	elif conv_logic.recipes.size() > 0:
		recipe_section.visible = true
		var first_recipe = conv_logic.recipes[0]
		recipe_label.text = "Recipe: %s" % first_recipe.display_name
		_populate_io_row(inputs_row, first_recipe.inputs)
		_populate_io_row(outputs_row, first_recipe.outputs)
	else:
		recipe_section.visible = false

	# Input buffer
	var input_text := "Input: "
	var has_input := false
	for item_id in conv_logic.input_inv.get_item_ids():
		var count := conv_logic.input_inv.get_count(item_id)
		if count > 0:
			input_text += "%dx %s  " % [count, str(item_id).replace("_", " ")]
			has_input = true
	if has_input:
		_add_stat(input_text)

	# Output buffer
	var output_text := "Output: "
	var has_output := false
	for item_id in conv_logic.output_inv.get_item_ids():
		var count := conv_logic.output_inv.get_count(item_id)
		if count > 0:
			output_text += "%dx %s  " % [count, str(item_id).replace("_", " ")]
			has_output = true
	if has_output:
		_add_stat(output_text)

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
