extends PanelContainer

## Dropdown menu showing all recipes for a converter building.
## Each row: [n1][item1] [n2][item2] →Xs [n1][item1] | priority | enabled
## Columns are aligned across rows by computing per-column number widths.

const ICON_SIZE := Vector2(16, 16)
const FONT_SIZE := 11
const SLOT_SEP := 2
const ENABLED_COLOR := Color(0.2, 0.8, 0.3)
const DISABLED_COLOR := Color(0.8, 0.2, 0.2)
const ARROW_COLOR := Color(0.7, 0.7, 0.7)
const ARROW_HOVER_COLOR := Color(1.0, 1.0, 1.0)

@onready var vbox: VBoxContainer = %VBox

var _configs: Array = []

func populate(configs: Array) -> void:
	_configs = configs
	_configs.sort_custom(func(a, b): return a.priority < b.priority)
	_rebuild()

# ── Layout computation ────────────────────────────────────────────────────

## Get all item input slot texts for a recipe (excluding energy cost).
func _get_input_texts(recipe) -> Array:
	var texts: Array = []
	for stack in recipe.inputs:
		texts.append(str(stack.quantity))
	return texts

## Get all output slot texts for a recipe.
func _get_output_texts(recipe) -> Array:
	var texts: Array = []
	for stack in recipe.outputs:
		texts.append(str(stack.quantity))
	if recipe is RecipeDef and recipe.energy_output > 0.0:
		texts.append(str(int(recipe.energy_output)))
	return texts

## Compute per-column max number widths using the theme font.
func _compute_column_widths() -> Dictionary:
	var font: Font = get_theme_font("font")
	var max_in: int = 0
	var max_out: int = 0
	var has_energy_cost: bool = false
	for config in _configs:
		var in_texts := _get_input_texts(config.recipe)
		var out_texts := _get_output_texts(config.recipe)
		max_in = maxi(max_in, in_texts.size())
		max_out = maxi(max_out, out_texts.size())
		if config.recipe.energy_cost > 0.0:
			has_energy_cost = true
	# Per-column widths
	var in_widths: Array = []
	in_widths.resize(max_in)
	in_widths.fill(0.0)
	var out_widths: Array = []
	out_widths.resize(max_out)
	out_widths.fill(0.0)
	var energy_cost_w: float = 0.0
	var max_arrow_w: float = 0.0
	for config in _configs:
		var in_texts := _get_input_texts(config.recipe)
		for i in range(in_texts.size()):
			var w: float = font.get_string_size(in_texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			in_widths[i] = maxf(in_widths[i], w)
		if config.recipe.energy_cost > 0.0:
			var w: float = font.get_string_size(str(int(config.recipe.energy_cost)), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			energy_cost_w = maxf(energy_cost_w, w)
		var out_texts := _get_output_texts(config.recipe)
		for i in range(out_texts.size()):
			var w: float = font.get_string_size(out_texts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
			out_widths[i] = maxf(out_widths[i], w)
		var arrow_text := "—%.0fs→" % config.recipe.craft_time
		var aw: float = font.get_string_size(arrow_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		max_arrow_w = maxf(max_arrow_w, aw)
	return {in_widths = in_widths, out_widths = out_widths, max_in = max_in, has_energy_cost = has_energy_cost, energy_cost_w = energy_cost_w, max_arrow_w = max_arrow_w}

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
	var has_energy_cost: bool = col.has_energy_cost
	var energy_cost_w: float = col.energy_cost_w

	# Item inputs
	var slot_idx: int = 0
	for stack in recipe.inputs:
		var w: float = in_widths[slot_idx] if slot_idx < in_widths.size() else 12.0
		_add_item_slot(row, stack, w)
		slot_idx += 1

	# Pad empty item input columns
	while slot_idx < max_in:
		var w: float = in_widths[slot_idx] if slot_idx < in_widths.size() else 12.0
		row.add_child(_create_empty_billet(w))
		slot_idx += 1

	# Energy cost (dedicated last input columns)
	if has_energy_cost:
		if recipe.energy_cost > 0.0:
			_add_energy_slot(row, str(int(recipe.energy_cost)), energy_cost_w)
		else:
			row.add_child(_create_empty_billet(energy_cost_w))

	# Arrow with craft time (fixed width for alignment)
	var max_arrow_w: float = col.get("max_arrow_w", 0.0)
	var arrow := Label.new()
	arrow.text = "—%.0fs→" % recipe.craft_time
	arrow.add_theme_font_size_override("font_size", FONT_SIZE)
	if max_arrow_w > 0.0:
		arrow.custom_minimum_size = Vector2(max_arrow_w, 0)
	row.add_child(arrow)

	# Outputs
	var out_slot_idx: int = 0
	for i in range(recipe.outputs.size()):
		var w: float = out_widths[i] if i < out_widths.size() else 12.0
		_add_item_slot(row, recipe.outputs[i], w)
		out_slot_idx = i + 1
	if recipe is RecipeDef and recipe.energy_output > 0.0:
		var w: float = out_widths[out_slot_idx] if out_slot_idx < out_widths.size() else 12.0
		_add_energy_slot(row, str(int(recipe.energy_output)), w)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# Vertical separator
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(2, 0)
	row.add_child(sep)

	# Priority arrows (up/down to reorder, horizontal layout)
	var config_idx := _configs.find(config)

	var up_btn := Label.new()
	up_btn.text = "▲"
	up_btn.add_theme_font_size_override("font_size", 8)
	up_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if config_idx > 0:
		up_btn.add_theme_color_override("font_color", ARROW_COLOR)
		up_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		up_btn.gui_input.connect(_on_move_input.bind(config_idx, -1))
	else:
		up_btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		up_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(up_btn)

	var down_btn := Label.new()
	down_btn.text = "▼"
	down_btn.add_theme_font_size_override("font_size", 8)
	down_btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if config_idx < _configs.size() - 1:
		down_btn.add_theme_color_override("font_color", ARROW_COLOR)
		down_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		down_btn.gui_input.connect(_on_move_input.bind(config_idx, 1))
	else:
		down_btn.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		down_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(down_btn)

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
	var item_id: StringName = &""
	if stack is ItemStack and stack.item:
		item_id = stack.item.id
	row.add_child(_create_slot_billet(str(qty), num_w, ItemIcon.create(item_id, ICON_SIZE)))

func _add_energy_slot(row: HBoxContainer, num_text: String, num_w: float) -> void:
	row.add_child(_create_slot_billet(num_text, num_w, ItemIcon.create(&"energy", ICON_SIZE)))

func _create_slot_billet(num_text: String, num_w: float, icon: Control) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.6)
	style.set_corner_radius_all(3)
	style.content_margin_left = 2
	style.content_margin_right = 2
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
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(num_label)
	hbox.add_child(icon)
	panel.add_child(hbox)
	return panel

func _create_empty_billet(num_w: float) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 1)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var num_label := Label.new()
	num_label.add_theme_font_size_override("font_size", FONT_SIZE)
	num_label.custom_minimum_size = Vector2(num_w, 0)
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(num_label)
	var icon_pad := Control.new()
	icon_pad.custom_minimum_size = ICON_SIZE
	icon_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_pad)
	panel.add_child(hbox)
	return panel

func _on_move_input(event: InputEvent, idx: int, direction: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	var new_idx := idx + direction
	if new_idx < 0 or new_idx >= _configs.size():
		return
	# Swap configs in array
	var tmp = _configs[idx]
	_configs[idx] = _configs[new_idx]
	_configs[new_idx] = tmp
	# Update priorities to match new order (1-based)
	for i in range(_configs.size()):
		_configs[i].priority = i + 1
	_rebuild()

func _on_toggle_input(event: InputEvent, config, rect: ColorRect) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	rect.accept_event()
	config.enabled = not config.enabled
	rect.color = ENABLED_COLOR if config.enabled else DISABLED_COLOR
