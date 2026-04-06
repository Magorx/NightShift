extends HBoxContainer
## Inventory hotbar at the bottom of the screen. Interactive — delegates clicks
## to the inventory panel so held-item state is shared.

const SLOT_SIZE := 40
const SLOT_MARGIN := 2
const EMPTY_COLOR := Color(0.2, 0.2, 0.2, 0.4)
const SELECTED_COLOR := Color(0.9, 0.85, 0.3, 0.8)
const HOVER_COLOR := Color(0.6, 0.6, 0.6, 0.9)
const SELECTION_COLOR := Color(0.4, 0.8, 1.0, 0.9)
const SLOT_BG_COLOR := Color(0.15, 0.15, 0.15, 0.6)

var _slots: Array = []  # Array of PanelContainer
var _hovered_slot: int = -1
var inventory_panel = null  # Set by HUD in _ready

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", SLOT_MARGIN)
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

func _create_slot(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	var style := StyleBoxFlat.new()
	style.bg_color = SLOT_BG_COLOR
	style.border_color = EMPTY_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)

	# Item icon indicator
	var icon_rect := ItemIcon.new()
	icon_rect.name = "ItemIcon"
	icon_rect.custom_minimum_size = Vector2(16, 16)
	icon_rect.position = Vector2(12, 8)
	icon_rect.size = Vector2(16, 16)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.visible = false
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_rect)

	# Quantity label
	var label := Label.new()
	label.name = "QuantityLabel"
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_right = -3
	label.offset_bottom = -1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	# Slot number
	var idx_label := Label.new()
	idx_label.name = "IndexLabel"
	idx_label.text = str(index + 1)
	idx_label.add_theme_font_size_override("font_size", 9)
	idx_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	idx_label.position = Vector2(3, 1)
	idx_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(idx_label)

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_slot_input.bind(index))
	panel.mouse_entered.connect(func(): _hovered_slot = index)
	panel.mouse_exited.connect(func():
		if _hovered_slot == index: _hovered_slot = -1)

	return panel

func _on_slot_input(event: InputEvent, index: int) -> void:
	if inventory_panel:
		inventory_panel._on_slot_input(event, index)

func _update_slot(index: int, player) -> void:
	var slot_data = player.inventory[index]
	var is_source_empty: bool = inventory_panel.is_slot_source_empty(index) if inventory_panel else false
	var is_selected: bool = inventory_panel.is_slot_selected(index) if inventory_panel else false
	UIStyles.update_inventory_slot(
		_slots[index], slot_data, is_source_empty, is_selected,
		_hovered_slot == index, index == player.selected_slot,
		{selected = SELECTION_COLOR, hover = HOVER_COLOR, active = SELECTED_COLOR, default = EMPTY_COLOR}
	)
