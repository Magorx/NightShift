extends HBoxContainer
## Inventory hotbar at the bottom of the screen.

const SLOT_SIZE := 40
const SLOT_MARGIN := 2
const EMPTY_COLOR := Color(0.2, 0.2, 0.2, 0.4)
const SELECTED_COLOR := Color(0.9, 0.85, 0.3, 0.8)
const SLOT_BG_COLOR := Color(0.15, 0.15, 0.15, 0.6)

var _slots: Array = []  # Array of PanelContainer

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", SLOT_MARGIN)
	# Create slot nodes (8 slots matches Player.INVENTORY_SLOTS)
	for i in 8:
		var slot := _create_slot(i)
		add_child(slot)
		_slots.append(slot)

func _process(_delta: float) -> void:
	var player = GameManager.player
	if not player or not is_instance_valid(player):
		return
	for i in _slots.size():
		_update_slot(i, player)

func _create_slot(_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_BG_COLOR
	style.border_color = EMPTY_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)

	# Item color indicator
	var color_rect := ColorRect.new()
	color_rect.name = "ItemColor"
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	color_rect.custom_minimum_size = Vector2(20, 20)
	color_rect.position = Vector2(10, 6)
	color_rect.size = Vector2(20, 20)
	color_rect.visible = false
	panel.add_child(color_rect)

	# Quantity label
	var label := Label.new()
	label.name = "QuantityLabel"
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_right = -3
	label.offset_bottom = -1
	panel.add_child(label)

	return panel

func _update_slot(index: int, player) -> void:
	var panel: PanelContainer = _slots[index]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	var color_rect: ColorRect = panel.get_node("ItemColor")
	var label: Label = panel.get_node("QuantityLabel")
	var slot_data = player.inventory[index]

	# Selected highlight
	if index == player.selected_slot:
		style.border_color = SELECTED_COLOR
	else:
		style.border_color = EMPTY_COLOR

	if slot_data != null:
		var item_def = GameManager.get_item_def(slot_data.item_id)
		color_rect.color = item_def.color if item_def else Color.WHITE
		color_rect.visible = true
		label.text = str(slot_data.quantity) if slot_data.quantity > 1 else ""
	else:
		color_rect.visible = false
		label.text = ""
