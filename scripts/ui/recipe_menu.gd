extends PanelContainer

## Dropdown menu showing all recipes for a converter building.
## Each row: [n1][item1] [n2][item2] →Xs [n1][item1] | priority | enabled
## Columns are aligned across rows by computing per-column number widths.

const ICON_SIZE := Vector2(12, 12)
const ICON_BORDER := 1
const FONT_SIZE := 11
const SLOT_SEP := 2
const ENERGY_COLOR := Color(0.95, 0.85, 0.2)
const ENABLED_COLOR := Color(0.2, 0.8, 0.3)
const DISABLED_COLOR := Color(0.8, 0.2, 0.2)
const SELECTED_COLOR := Color(0.2, 0.8, 0.8, 0.5)

@onready var vbox: VBoxContainer = %VBox

var _configs: Array = []
var _selected_config = null # first click for priority swap
var _selected_label: Label = null

func populate(configs: Array) -> void:
	_configs = configs
	_rebuild()

# ── Layout computation ────────────────────────────────────────────────────

## Get all input slot texts for a recipe (inputs + energy cost).
func _get_input_texts(recipe) -> Array:
	var texts: Array = []
	for stack in recipe.inputs:
		texts.append(str(stack.quantity))
	if recipe.energy_cost > 0.0:
		texts.append(str(int(recipe.energy_cost)))
	return texts

## Get all output slot texts for a recipe.
func _get_output_texts(recipe) -> Array:
	var texts: Array = []
	for stack in recipe.outputs:
		texts.append(str(stack.quantity))
	return texts

## Compute per-column max number widths using the theme font.
func _compute_column_widths() -> Dictionary:
	var font: Font = get_theme_font("font")
	var max_in: int = 0
	var max_out: int = 0
	for config in _configs:
		var in_texts := _get_input_texts(config.recipe)
		var out_texts := _get_output_texts(config.recipe)
		max_in = maxi(max_in, in_texts.size())
		max_out = maxi(max_out, out_texts.size())
	# Per-column widths
	var in_widths: Array = []
	in_widths.resize(max_in)
	in_widths.fill(0.0)
	var out_widths: Array = []
	out_widths.resize(max_out)
	out_widths.fill(0.0)
	for config in _configs:
		var in_texts := _get_input_texts(config.recipe)
		for i in range(in_texts.size()):
			var w: float = font.get_string_size(in_texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			in_widths[i] = maxf(in_widths[i], w)
		var out_texts := _get_output_texts(config.recipe)
		for i in range(out_texts.size()):
			var w: float = font.get_string_size(out_texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			out_widths[i] = maxf(out_widths[i], w)
	return {in_widths = in_widths, out_widths = out_widths, max_in = max_in}

# ── Build ─────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.queue_free()
	var col := _compute_column_widths()
	for config in _configs:
		vbox.add_child(_create_recipe_row(config, col))

func _create_recipe_row(config, col: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SLOT_SEP)

	var recipe = config.recipe
	var in_widths: Array = col.in_widths
	var out_widths: Array = col.out_widths
	var max_in: int = col.max_in

	# Inputs
	var slot_idx: int = 0
	for stack in recipe.inputs:
		var w: float = in_widths[slot_idx] if slot_idx < in_widths.size() else 12.0
		_add_item_slot(row, stack, w)
		slot_idx += 1

	# Energy cost
	if recipe.energy_cost > 0.0:
		var w: float = in_widths[slot_idx] if slot_idx < in_widths.size() else 12.0
		_add_slot(row, str(int(recipe.energy_cost)), ENERGY_COLOR, w)
		slot_idx += 1

	# Pad empty input columns to align arrow
	while slot_idx < max_in:
		var w: float = in_widths[slot_idx] if slot_idx < in_widths.size() else 12.0
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(w + ICON_SIZE.x + SLOT_SEP, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pad)
		slot_idx += 1

	# Arrow with craft time
	var arrow := Label.new()
	arrow.text = "—%.0fs→" % recipe.craft_time
	arrow.add_theme_font_size_override("font_size", FONT_SIZE)
	row.add_child(arrow)

	# Outputs
	for i in range(recipe.outputs.size()):
		var w: float = out_widths[i] if i < out_widths.size() else 12.0
		_add_item_slot(row, recipe.outputs[i], w)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# Vertical separator
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 0)
	row.add_child(sep)

	# Priority label (clickable)
	var pri_label := Label.new()
	pri_label.text = str(config.priority)
	pri_label.add_theme_font_size_override("font_size", FONT_SIZE)
	pri_label.custom_minimum_size = Vector2(12, 0)
	pri_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pri_label.mouse_filter = Control.MOUSE_FILTER_STOP
	pri_label.gui_input.connect(_on_priority_input.bind(config, pri_label))
	row.add_child(pri_label)

	# Enabled toggle (clickable)
	var toggle := ColorRect.new()
	toggle.custom_minimum_size = ICON_SIZE
	toggle.color = ENABLED_COLOR if config.enabled else DISABLED_COLOR
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.gui_input.connect(_on_toggle_input.bind(config, toggle))
	row.add_child(toggle)

	return row

# ── Slot helpers ──────────────────────────────────────────────────────────

func _add_item_slot(row: HBoxContainer, stack, num_w: float) -> void:
	var qty: int = stack.quantity
	var color: Color
	if stack is ItemStack:
		color = stack.item.color if stack.item else Color.WHITE
	else:
		color = stack.color
	_add_slot(row, str(qty), color, num_w)

func _add_slot(row: HBoxContainer, num_text: String, color: Color, num_w: float) -> void:
	var num_label := Label.new()
	num_label.text = num_text
	num_label.add_theme_font_size_override("font_size", FONT_SIZE)
	num_label.custom_minimum_size = Vector2(num_w, 0)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(num_label)
	row.add_child(_create_outlined_icon(color))

func _on_priority_input(event: InputEvent, config, label: Label) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	label.accept_event()
	if _selected_config == null:
		# First click: select this priority
		_selected_config = config
		_selected_label = label
		label.add_theme_color_override("font_color", SELECTED_COLOR)
	elif _selected_config == config:
		# Clicked same one: deselect
		_selected_config = null
		_selected_label.remove_theme_color_override("font_color")
		_selected_label = null
	else:
		# Second click: swap priorities
		var tmp: int = _selected_config.priority
		_selected_config.priority = config.priority
		config.priority = tmp
		_selected_config = null
		_selected_label = null
		_rebuild()

func _on_toggle_input(event: InputEvent, config, rect: ColorRect) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	rect.accept_event()
	config.enabled = not config.enabled
	rect.color = ENABLED_COLOR if config.enabled else DISABLED_COLOR

# ── Icon helpers ──────────────────────────────────────────────────────────

func _create_outlined_icon(color: Color) -> PanelContainer:
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
	panel.add_theme_stylebox_override("panel", style)
	return panel
