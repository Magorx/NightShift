class_name RecipeBillet

## Static helper for building recipe slot UI billets (small labeled icon panels).
## Extracted from building_popup.gd and recipe_menu.gd to eliminate duplication.
## All methods are static -- callers pass their own font_size and icon_size constants.

static func add_item_slot(row: HBoxContainer, stack, num_w: float, icon_size: Vector2, font_size: int) -> void:
	var qty: int = stack.quantity
	var item_id: StringName = &""
	if stack is ItemStack and stack.item:
		item_id = stack.item.id
	row.add_child(create_slot_billet(str(qty), num_w, ItemIcon.create(item_id, icon_size), icon_size, font_size))

static func add_energy_slot(row: HBoxContainer, num_text: String, num_w: float, icon_size: Vector2, font_size: int) -> void:
	row.add_child(create_slot_billet(num_text, num_w, ItemIcon.create(&"energy", icon_size), icon_size, font_size))

static func create_slot_billet(num_text: String, num_w: float, icon: Control, icon_size: Vector2, font_size: int) -> PanelContainer:
	return build_billet(UIStyles.slot_panel(Color(0.08, 0.08, 0.08, 0.6), 3, 1), num_text, num_w, icon, icon_size, font_size)

static func create_empty_billet(num_w: float, icon_size: Vector2, font_size: int) -> PanelContainer:
	return build_billet(UIStyles.slot_panel(Color.TRANSPARENT, 0, 1), "", num_w, null, icon_size, font_size)

static func build_billet(style: StyleBoxFlat, num_text: String, num_w: float, icon: Control, icon_size: Vector2, font_size: int) -> PanelContainer:
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
	num_label.add_theme_font_size_override("font_size", font_size)
	num_label.custom_minimum_size = Vector2(num_w, 0)
	if num_text != "":
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(num_label)
	if icon:
		hbox.add_child(icon)
	else:
		var icon_pad := Control.new()
		icon_pad.custom_minimum_size = icon_size
		icon_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon_pad)
	panel.add_child(hbox)
	return panel
