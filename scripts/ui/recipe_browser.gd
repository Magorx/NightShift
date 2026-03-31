extends "game_window.gd"

## Recipe Browser — shows all items with a searchable list on the left,
## and visual recipe cards for the selected item on the right.
## Each recipe is shown as a visual card: [input icons] → [building] → [output icons]

@onready var search_edit: LineEdit = %SearchEdit
@onready var item_list_box: VBoxContainer = %ItemListBox
@onready var tree_scroll: ScrollContainer = %TreeScroll
@onready var tree_content: VBoxContainer = %TreeContent
@onready var close_button: Button = %CloseButton

var _all_items: Array = []  # Array of ItemDef, sorted alphabetically
var _all_recipes: Array = []  # Array of RecipeDef
var _selected_item_id: StringName = &""

func serialize_ui_state() -> Dictionary:
	var data := super.serialize_ui_state()
	data["selected_item"] = str(_selected_item_id)
	return data

func deserialize_ui_state(data: Dictionary) -> void:
	super.deserialize_ui_state(data)
	var item_id := StringName(data.get("selected_item", ""))
	if item_id != &"" and GameManager.get_item_def(item_id):
		select_item(item_id)

# Caches: item_id -> Array[RecipeDef]
var _recipes_producing: Dictionary = {}  # recipes whose output contains item
var _recipes_consuming: Dictionary = {}  # recipes whose input contains item

# Building colors for recipe cards
const CONVERTER_COLORS: Dictionary = {
	"smelter": Color(0.85, 0.45, 0.2),
	"press": Color(0.6, 0.6, 0.7),
	"wire_drawer": Color(0.8, 0.55, 0.2),
	"assembler": Color(0.3, 0.6, 0.8),
	"assembler_mk2": Color(0.4, 0.5, 0.9),
	"coke_oven": Color(0.5, 0.35, 0.2),
	"coal_burner": Color(0.7, 0.3, 0.15),
	"fuel_generator": Color(0.6, 0.4, 0.1),
	"hand_assembler": Color(0.5, 0.7, 0.5),
}

func _ready() -> void:
	super._ready()
	search_edit.text_changed.connect(_on_search_changed)
	_load_data()
	_populate_item_list("")

func _load_data() -> void:
	var dir := DirAccess.open("res://resources/items/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var def = load("res://resources/items/" + fname)
			if def and def is ItemDef and def.id != &"energy":
				_all_items.append(def)
		fname = dir.get_next()
	_all_items.sort_custom(func(a, b): return a.display_name.naturalcasecmp_to(b.display_name) < 0)

	var rdir := DirAccess.open("res://resources/recipes/")
	if not rdir:
		return
	rdir.list_dir_begin()
	fname = rdir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var recipe = load("res://resources/recipes/" + fname)
			if recipe and recipe is RecipeDef:
				_all_recipes.append(recipe)
		fname = rdir.get_next()

	for recipe in _all_recipes:
		for stack in recipe.outputs:
			if stack.item:
				var iid: StringName = stack.item.id
				if not _recipes_producing.has(iid):
					_recipes_producing[iid] = []
				_recipes_producing[iid].append(recipe)
		for stack in recipe.inputs:
			if stack.item:
				var iid: StringName = stack.item.id
				if not _recipes_consuming.has(iid):
					_recipes_consuming[iid] = []
				_recipes_consuming[iid].append(recipe)

func _populate_item_list(filter: String) -> void:
	for child in item_list_box.get_children():
		child.queue_free()

	var filter_lower := filter.to_lower()
	var idx := 0
	for item_def in _all_items:
		if filter_lower != "" and item_def.display_name.to_lower().find(filter_lower) == -1:
			continue
		var row := _create_item_row(item_def, idx)
		item_list_box.add_child(row)
		idx += 1

func _create_item_row(item_def: ItemDef, idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.22) if idx % 2 == 0 else Color(0.22, 0.22, 0.26)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(hbox)

	var icon := ItemIcon.create(item_def.id, Vector2(16, 16))
	hbox.add_child(icon)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(6, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	var label := Label.new()
	label.text = item_def.display_name
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(label)

	var iid: StringName = item_def.id
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			select_item(iid)
	)

	if item_def.id == _selected_item_id:
		style.border_color = Color(0.4, 0.7, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2

	return panel

func _on_search_changed(text: String) -> void:
	_populate_item_list(text)

func select_item(item_id: StringName) -> void:
	_selected_item_id = item_id
	_populate_item_list(search_edit.text)
	_build_recipe_view(item_id)

func show_centered_on_item(item_id: StringName) -> void:
	visible = true
	move_to_center()
	select_item(item_id)

# ── Visual Recipe View Builder ──────────────────────────────────────────────

func _build_recipe_view(item_id: StringName) -> void:
	for child in tree_content.get_children():
		child.queue_free()

	var item_def = GameManager.get_item_def(item_id)
	if not item_def:
		return

	# === Header ===
	tree_content.add_child(_make_item_header(item_def))

	# === "Produced by" section ===
	var producing: Array = _recipes_producing.get(item_id, [])
	if producing.size() > 0:
		tree_content.add_child(_make_section_label("Produced by"))
		for recipe in producing:
			tree_content.add_child(_make_visual_recipe_card(recipe, item_id))
	else:
		tree_content.add_child(_make_section_label("Source"))
		tree_content.add_child(_make_info_label("Mined from deposits (raw resource)"))

	tree_content.add_child(_make_separator())

	# === "Used in" section ===
	var consuming: Array = _recipes_consuming.get(item_id, [])
	if consuming.size() > 0:
		tree_content.add_child(_make_section_label("Used in"))
		for recipe in consuming:
			tree_content.add_child(_make_visual_recipe_card(recipe, item_id))
	else:
		tree_content.add_child(_make_section_label("End product"))
		tree_content.add_child(_make_info_label("Delivered to sinks for currency"))

	tree_content.add_child(_make_separator())

	# === Full upstream chain (visual) ===
	tree_content.add_child(_make_section_label("Full production chain"))
	var chain := _build_visual_chain(item_id)
	tree_content.add_child(chain)

func _make_item_header(item_def: ItemDef) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := ItemIcon.create(item_def.id, Vector2(32, 32))
	hbox.add_child(icon)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := Label.new()
	name_label.text = item_def.display_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var cat_label := Label.new()
	cat_label.text = item_def.category.capitalize()
	cat_label.add_theme_font_size_override("font_size", 11)
	cat_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	cat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(cat_label)

	hbox.add_child(vbox)
	return hbox

func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_info_label(text: String) -> Label:
	var label := Label.new()
	label.text = "  " + text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 8)
	return sep

# ── Visual Recipe Card ──────────────────────────────────────────────────────
# Layout: [inputs] → [building box] → [outputs]

func _make_visual_recipe_card(recipe: RecipeDef, highlight_item_id: StringName) -> PanelContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.12, 0.16, 0.9)
	card_style.set_corner_radius_all(4)
	card_style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", card_style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	# Inputs
	for i in recipe.inputs.size():
		if i > 0:
			row.add_child(_make_plus_label())
		row.add_child(_make_item_icon_with_qty(recipe.inputs[i], highlight_item_id))

	# Arrow into building
	row.add_child(_make_arrow_label("→"))

	# Building box
	row.add_child(_make_building_box(recipe))

	# Arrow out of building
	row.add_child(_make_arrow_label("→"))

	# Outputs
	for i in recipe.outputs.size():
		if i > 0:
			row.add_child(_make_plus_label())
		row.add_child(_make_item_icon_with_qty(recipe.outputs[i], highlight_item_id))

	# Energy indicators
	if recipe.energy_cost > 0:
		var energy := Label.new()
		energy.text = " ⚡%.0f" % recipe.energy_cost
		energy.add_theme_font_size_override("font_size", 10)
		energy.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
		energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(energy)
	if recipe.energy_output > 0:
		var energy := Label.new()
		energy.text = " +⚡%.0f" % recipe.energy_output
		energy.add_theme_font_size_override("font_size", 10)
		energy.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(energy)

	# Click navigates to a related item
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Navigate to an output item that isn't the highlighted one
			for stack in recipe.outputs:
				if stack.item and stack.item.id != highlight_item_id:
					select_item(stack.item.id)
					return
			for stack in recipe.inputs:
				if stack.item and stack.item.id != highlight_item_id:
					select_item(stack.item.id)
					return
	)

	return card

func _make_item_icon_with_qty(stack: ItemStack, highlight_id: StringName) -> PanelContainer:
	## A single item slot: quantity badge + icon, with optional highlight bg.
	var slot := PanelContainer.new()
	var slot_style := StyleBoxFlat.new()
	if stack.item and stack.item.id == highlight_id:
		slot_style.bg_color = Color(0.25, 0.4, 0.7, 0.4)
	else:
		slot_style.bg_color = Color(0.08, 0.08, 0.1, 0.6)
	slot_style.set_corner_radius_all(3)
	slot_style.set_content_margin_all(3)
	slot.add_theme_stylebox_override("panel", slot_style)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(vbox)

	# Icon
	var icon := ItemIcon.create(stack.item.id, Vector2(16, 16))
	vbox.add_child(icon)

	# Name + qty label
	var lbl := Label.new()
	var item_name: String = stack.item.display_name if stack.item else "?"
	if item_name.length() > 10:
		item_name = item_name.substr(0, 8) + ".."
	lbl.text = "%s x%d" % [item_name, stack.quantity] if stack.quantity > 1 else item_name
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)

	return slot

func _make_building_box(recipe: RecipeDef) -> PanelContainer:
	## Visual building representation: colored box with converter name and time.
	var box := PanelContainer.new()
	var box_style := StyleBoxFlat.new()
	var conv_color: Color = CONVERTER_COLORS.get(recipe.converter_type, Color(0.4, 0.4, 0.5))
	box_style.bg_color = Color(conv_color, 0.3)
	box_style.border_color = Color(conv_color, 0.7)
	box_style.border_width_left = 2
	box_style.border_width_right = 2
	box_style.border_width_top = 2
	box_style.border_width_bottom = 2
	box_style.set_corner_radius_all(4)
	box_style.set_content_margin_all(6)
	box.add_theme_stylebox_override("panel", box_style)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(vbox)

	# Building name
	var name_lbl := Label.new()
	var display_name: String = recipe.converter_type.replace("_", " ").capitalize()
	name_lbl.text = display_name
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(conv_color, 1.0).lightened(0.3))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Time
	var time_lbl := Label.new()
	time_lbl.text = "%.1fs" % recipe.craft_time
	time_lbl.add_theme_font_size_override("font_size", 9)
	time_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(time_lbl)

	return box

func _make_arrow_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _make_plus_label() -> Label:
	var lbl := Label.new()
	lbl.text = "+"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

# ── Visual Production Chain ─────────────────────────────────────────────────
# Shows the full upstream chain as indented visual recipe cards.

func _build_visual_chain(item_id: StringName) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var steps: Array = []
	_collect_chain_steps(item_id, steps, {}, 0)

	for step in steps:
		var indent: int = step.indent
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Indent spacer
		if indent > 0:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(indent * 20, 0)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(spacer)

		if step.has("recipe"):
			# Mini recipe card
			var recipe: RecipeDef = step.recipe
			row.add_child(_make_mini_recipe_card(recipe, step.item_id))
		else:
			# Raw resource or item label
			var icon := ItemIcon.create(step.item_id, Vector2(16, 16))
			row.add_child(icon)
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(4, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
			var lbl := Label.new()
			var item_def = GameManager.get_item_def(step.item_id)
			lbl.text = (item_def.display_name if item_def else str(step.item_id))
			if step.get("is_raw", false):
				lbl.text += " (raw)"
				lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6))
			elif step.item_id == item_id:
				lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(lbl)

			# Clickable
			if step.item_id != item_id and step.item_id != &"":
				var click_panel := PanelContainer.new()
				click_panel.mouse_filter = Control.MOUSE_FILTER_STOP
				var click_style := StyleBoxFlat.new()
				click_style.bg_color = Color(0, 0, 0, 0)
				click_panel.add_theme_stylebox_override("panel", click_style)
				click_panel.add_child(row)
				var sid: StringName = step.item_id
				click_panel.gui_input.connect(func(event: InputEvent):
					if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
						select_item(sid)
				)
				vbox.add_child(click_panel)
				continue

		vbox.add_child(row)

	return vbox

func _make_mini_recipe_card(recipe: RecipeDef, _highlight_id: StringName) -> HBoxContainer:
	## Compact inline recipe: [icons] → [building] → [icons]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Inputs as small icons
	for i in recipe.inputs.size():
		if i > 0:
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 9)
			plus.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(plus)
		var slot := HBoxContainer.new()
		slot.add_theme_constant_override("separation", 1)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if recipe.inputs[i].quantity > 1:
			var qty := Label.new()
			qty.text = "%d" % recipe.inputs[i].quantity
			qty.add_theme_font_size_override("font_size", 9)
			qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(qty)
		slot.add_child(ItemIcon.create(recipe.inputs[i].item.id, Vector2(16, 16)))
		row.add_child(slot)

	# Arrow + building
	var conv_color: Color = CONVERTER_COLORS.get(recipe.converter_type, Color(0.4, 0.4, 0.5))
	var arrow := Label.new()
	arrow.text = " → "
	arrow.add_theme_font_size_override("font_size", 10)
	arrow.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)

	# Building badge
	var badge := Label.new()
	badge.text = "[%s %.1fs]" % [recipe.converter_type.replace("_", " "), recipe.craft_time]
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override("font_color", Color(conv_color, 1.0).lightened(0.2))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)

	var arrow2 := Label.new()
	arrow2.text = " → "
	arrow2.add_theme_font_size_override("font_size", 10)
	arrow2.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	arrow2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow2)

	# Outputs as small icons
	for i in recipe.outputs.size():
		if i > 0:
			var plus := Label.new()
			plus.text = "+"
			plus.add_theme_font_size_override("font_size", 9)
			plus.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
			plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(plus)
		var slot := HBoxContainer.new()
		slot.add_theme_constant_override("separation", 1)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if recipe.outputs[i].quantity > 1:
			var qty := Label.new()
			qty.text = "%d" % recipe.outputs[i].quantity
			qty.add_theme_font_size_override("font_size", 9)
			qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(qty)
		slot.add_child(ItemIcon.create(recipe.outputs[i].item.id, Vector2(16, 16)))
		row.add_child(slot)

	return row

func _collect_chain_steps(item_id: StringName, steps: Array, visited: Dictionary, depth: int) -> void:
	if visited.has(item_id) or depth > 6:
		return
	visited[item_id] = true

	var producing: Array = _recipes_producing.get(item_id, [])

	if producing.is_empty():
		# Raw resource
		steps.append({indent = depth, item_id = item_id, is_raw = true})
		return

	# For each recipe that produces this item, show upstream first
	for recipe in producing:
		for input_stack in recipe.inputs:
			if input_stack.item:
				_collect_chain_steps(input_stack.item.id, steps, visited, depth)

		# Then the recipe itself
		steps.append({indent = depth, recipe = recipe, item_id = item_id})

		# Then this item
		steps.append({indent = depth, item_id = item_id})
