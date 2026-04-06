class_name UIStyles

## Shared UI style helpers to reduce StyleBoxFlat boilerplate across UI scripts.

const ENABLED_COLOR := Color(0.2, 0.8, 0.3)
const DISABLED_COLOR := Color(0.8, 0.2, 0.2)

## Create a slot-style panel (item/recipe slots in popups and menus).
static func slot_panel(bg_color := Color(0.08, 0.08, 0.08, 0.6), corner_radius: int = 3, margin: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.set_corner_radius_all(corner_radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s

## Create a card-style panel (recipe cards, building info panels).
static func card_panel(bg_color := Color(0.12, 0.12, 0.16, 0.9), corner_radius: int = 4, margin: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.set_corner_radius_all(corner_radius)
	s.set_content_margin_all(margin)
	return s

## Create a row-style panel for list items (alternating colors).
static func row_panel(bg_color: Color, corner_radius: int = 2, margin: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.set_corner_radius_all(corner_radius)
	s.set_content_margin_all(margin)
	return s

## Create a transparent click-target panel.
static func transparent_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	return s

## Update an inventory slot's visual state (border color, icon, label).
static func update_inventory_slot(
	panel: PanelContainer,
	slot_data,  # {item_id, quantity} or null
	is_source_empty: bool,
	is_selected: bool,
	is_hovered: bool,
	is_active_slot: bool,
	colors: Dictionary,  # {selected, hover, active, default}
) -> void:
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	var icon_rect: ItemIcon = panel.get_node("ItemIcon")
	var label: Label = panel.get_node("QuantityLabel")

	if is_selected:
		style.border_color = colors.selected
	elif is_hovered:
		style.border_color = colors.hover
	elif is_active_slot:
		style.border_color = colors.active
	else:
		style.border_color = colors.default

	if slot_data != null and not is_source_empty:
		icon_rect.set_item(slot_data.item_id)
		icon_rect.visible = true
		label.text = str(slot_data.quantity) if slot_data.quantity > 1 else ""
	else:
		icon_rect.visible = false
		label.text = ""

	panel.modulate = Color(0.5, 0.5, 0.5, 0.5) if is_source_empty else Color.WHITE

## Create a bordered box (e.g., building boxes in recipe browser).
static func bordered_panel(bg_color: Color, border_color: Color, border_width: int = 2, corner_radius: int = 4, margin: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.border_color = border_color
	s.border_width_left = border_width
	s.border_width_right = border_width
	s.border_width_top = border_width
	s.border_width_bottom = border_width
	s.set_corner_radius_all(corner_radius)
	s.set_content_margin_all(margin)
	return s
