extends GameWindow
## Inventory window — displays player inventory slots in a grid with drag interactions.

const SLOT_SIZE := 48
const COLUMNS := 8
const EMPTY_SLOT_COLOR := Color(0.15, 0.15, 0.15, 0.6)
const SLOT_BORDER_COLOR := Color(0.3, 0.3, 0.35, 0.8)
const HOVER_BORDER_COLOR := Color(0.6, 0.6, 0.6, 0.9)
const HOTBAR_BORDER_COLOR := Color(0.9, 0.85, 0.3, 0.8)
const SELECTED_BORDER_COLOR := Color(0.4, 0.8, 1.0, 0.9)
const DROP_RANGE := 48.0 # 1.5 tiles

@onready var hotbar_grid: GridContainer = %HotbarGrid
@onready var expansion_grid: GridContainer = %ExpansionGrid

var _slots: Array[PanelContainer] = []
var _held_item: Dictionary = {} # {item_id: StringName, quantity: int} or empty
var _held_source_slot: int = -1
var _hovered_slot: int = -1
var _selected_slots: Dictionary = {} # index -> true
var _last_clicked_slot: int = -1

# Cursor ghost (created in code with top_level so it follows the mouse freely)
var _cursor_ghost: Control
var _ghost_color: ColorRect
var _ghost_label: Label

func _ready() -> void:
	super()
	_create_slots()
	_create_cursor_ghost()

func _process(delta: float) -> void:
	super(delta)
	_update_cursor_ghost()
	if visible:
		_update_slots()

func _create_slots() -> void:
	for i in Player.INVENTORY_SLOTS:
		var slot := _create_slot(i)
		if i < 8:
			hotbar_grid.add_child(slot)
		else:
			expansion_grid.add_child(slot)
		_slots.append(slot)

func _create_slot(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = EMPTY_SLOT_COLOR
	style.border_color = SLOT_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)

	var color_rect := ColorRect.new()
	color_rect.name = "ItemColor"
	color_rect.custom_minimum_size = Vector2(28, 28)
	color_rect.position = Vector2(10, 10)
	color_rect.size = Vector2(28, 28)
	color_rect.visible = false
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(color_rect)

	var label := Label.new()
	label.name = "QuantityLabel"
	label.add_theme_font_size_override("font_size", 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_right = -3
	label.offset_bottom = -1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	if index < 8:
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

func _create_cursor_ghost() -> void:
	_cursor_ghost = Control.new()
	_cursor_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_ghost.visible = false
	_cursor_ghost.top_level = true
	_cursor_ghost.z_index = 100

	_ghost_color = ColorRect.new()
	_ghost_color.size = Vector2(24, 24)
	_ghost_color.modulate.a = 0.75
	_ghost_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_ghost.add_child(_ghost_color)

	_ghost_label = Label.new()
	_ghost_label.add_theme_font_size_override("font_size", 10)
	_ghost_label.position = Vector2(14, 14)
	_ghost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_ghost.add_child(_ghost_label)

	# Add to HUD (parent) so ghost stays visible when inventory panel is hidden
	get_parent().add_child.call_deferred(_cursor_ghost)

# ── Slot Display ────────────────────────────────────────────────────────────

func _update_slots() -> void:
	var player = GameManager.player
	if not player or not is_instance_valid(player):
		return
	for i in _slots.size():
		_update_slot(i, player)

func _update_slot(index: int, player) -> void:
	var panel: PanelContainer = _slots[index]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	var color_rect: ColorRect = panel.get_node("ItemColor")
	var label: Label = panel.get_node("QuantityLabel")
	var slot_data = player.inventory[index]
	# Source slot is dimmed only when it was fully emptied by the pick-up
	var is_source_empty := (index == _held_source_slot and not _held_item.is_empty() and slot_data == null)

	# Border — selection takes priority
	if _selected_slots.has(index):
		style.border_color = SELECTED_BORDER_COLOR
	elif _hovered_slot == index:
		style.border_color = HOVER_BORDER_COLOR
	elif index == player.selected_slot:
		style.border_color = HOTBAR_BORDER_COLOR
	else:
		style.border_color = SLOT_BORDER_COLOR

	# Content
	if slot_data != null and not is_source_empty:
		var item_def = GameManager.get_item_def(slot_data.item_id)
		color_rect.color = item_def.color if item_def else Color.WHITE
		color_rect.visible = true
		label.text = str(slot_data.quantity) if slot_data.quantity > 1 else ""
	else:
		color_rect.visible = false
		label.text = ""

	panel.modulate = Color(0.5, 0.5, 0.5, 0.5) if is_source_empty else Color.WHITE

func _update_cursor_ghost() -> void:
	if _held_item.is_empty():
		if _cursor_ghost:
			_cursor_ghost.visible = false
		return
	_cursor_ghost.visible = true
	var ghost_size := Vector2(24, 24)
	var vp_size := get_viewport_rect().size
	var pos := get_global_mouse_position() + Vector2(8, 8)
	pos.x = clampf(pos.x, 0, vp_size.x - ghost_size.x)
	pos.y = clampf(pos.y, 0, vp_size.y - ghost_size.y)
	_cursor_ghost.global_position = pos
	var item_def = GameManager.get_item_def(_held_item.item_id)
	_ghost_color.color = item_def.color if item_def else Color.WHITE
	_ghost_label.text = str(_held_item.quantity) if _held_item.quantity > 1 else ""

# ── Slot Interactions ───────────────────────────────────────────────────────

func _on_slot_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var player = GameManager.player
	if not player or not is_instance_valid(player):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.ctrl_pressed:
			_toggle_selection(index)
		elif event.shift_pressed:
			_range_select(index)
		else:
			_selected_slots.clear()
			_handle_left_click(index, player)
			_last_clicked_slot = index
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_right_click(index, player)
		accept_event()

func _handle_left_click(index: int, player) -> void:
	if _held_item.is_empty():
		# Pick up item from slot
		var slot_data = player.inventory[index]
		if slot_data != null:
			_held_item = {item_id = slot_data.item_id, quantity = slot_data.quantity}
			_held_source_slot = index
			player.inventory[index] = null
	else:
		_place_held_item(index, player)

func _place_held_item(index: int, player) -> void:
	var slot_data = player.inventory[index]
	if slot_data == null:
		# Place into empty slot
		player.inventory[index] = {item_id = _held_item.item_id, quantity = _held_item.quantity}
		_clear_held()
	elif slot_data.item_id == _held_item.item_id:
		# Merge stacks up to stack limit; overflow stays in hand
		var space: int = Player.STACK_SIZE - slot_data.quantity
		var to_add: int = mini(_held_item.quantity, space)
		slot_data.quantity += to_add
		_held_item.quantity -= to_add
		if _held_item.quantity <= 0:
			_clear_held()
	else:
		# Swap
		var temp = {item_id = slot_data.item_id, quantity = slot_data.quantity}
		player.inventory[index] = {item_id = _held_item.item_id, quantity = _held_item.quantity}
		_held_item = temp
		_held_source_slot = index

func _handle_right_click(index: int, player) -> void:
	if _held_item.is_empty():
		# Pick up half the stack
		var slot_data = player.inventory[index]
		if slot_data != null and slot_data.quantity > 0:
			var half: int = ceili(float(slot_data.quantity) / 2.0)
			_held_item = {item_id = slot_data.item_id, quantity = half}
			_held_source_slot = index
			slot_data.quantity -= half
			if slot_data.quantity <= 0:
				player.inventory[index] = null
	else:
		# Deposit one item into this slot
		var slot_data = player.inventory[index]
		if slot_data == null:
			player.inventory[index] = {item_id = _held_item.item_id, quantity = 1}
			_held_item.quantity -= 1
			if _held_item.quantity <= 0:
				_clear_held()
		elif slot_data.item_id == _held_item.item_id and slot_data.quantity < Player.STACK_SIZE:
			slot_data.quantity += 1
			_held_item.quantity -= 1
			if _held_item.quantity <= 0:
				_clear_held()

func _clear_held() -> void:
	_held_item = {}
	_held_source_slot = -1
	if _cursor_ghost:
		_cursor_ghost.visible = false

# ── Selection ───────────────────────────────────────────────────────────────

func _toggle_selection(index: int) -> void:
	if _selected_slots.has(index):
		_selected_slots.erase(index)
	else:
		_selected_slots[index] = true
	_last_clicked_slot = index

func _range_select(index: int) -> void:
	if _last_clicked_slot < 0:
		_selected_slots[index] = true
		_last_clicked_slot = index
		return
	var from := mini(_last_clicked_slot, index)
	var to := maxi(_last_clicked_slot, index)
	for i in range(from, to + 1):
		_selected_slots[i] = true

# ── Window Overrides ────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	# Block drag/resize while holding an item — clicks inside the panel are no-ops
	if not _held_item.is_empty():
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			accept_event()
			return
	super(event)

func _unhandled_input(event: InputEvent) -> void:
	# Always handle held-item operations (hotbar can start them while panel is hidden)
	if not _held_item.is_empty():
		if event.is_action_pressed("ui_cancel"):
			_return_held_item()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_drop_held_item_at_cursor()
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_return_held_item()
				get_viewport().set_input_as_handled()
				return
	if not visible:
		return
	# Panel-specific: ESC to clear selection or close window
	if event.is_action_pressed("ui_cancel"):
		if not _selected_slots.is_empty():
			_selected_slots.clear()
		else:
			visible = false
		get_viewport().set_input_as_handled()
		return
	# Base: close on RMB when not holding
	super(event)

# ── Drop / Return ───────────────────────────────────────────────────────────

func _drop_held_item_at_cursor() -> void:
	var player = GameManager.player
	if not player or not is_instance_valid(player):
		_clear_held()
		return
	var camera := get_viewport().get_camera_2d()
	if not camera:
		_return_held_item()
		return
	# Screen → world conversion
	var screen_pos := get_global_mouse_position()
	var viewport_size := get_viewport_rect().size
	var offset := screen_pos - viewport_size / 2.0
	var world_pos: Vector2 = camera.global_position + offset / camera.zoom.x
	# Clamp to max range from player
	var to_target: Vector2 = world_pos - player.position
	if to_target.length() > DROP_RANGE:
		world_pos = player.position + to_target.normalized() * DROP_RANGE
	# Try to insert into building at drop position
	var drop_grid := Vector2i(floori(world_pos.x / Player.TILE_SIZE), floori(world_pos.y / Player.TILE_SIZE))
	var building = GameManager.get_building_at(drop_grid)
	if building and building.logic:
		var leftover: int = building.logic.try_insert_item(_held_item.item_id, _held_item.quantity)
		if leftover <= 0:
			_clear_held()
			return
		_held_item.quantity = leftover
	# Drop on top of the building so it can consume from the stack later
	var ground_pos := world_pos
	if building:
		ground_pos = Vector2(drop_grid) * Player.TILE_SIZE + Vector2(Player.TILE_SIZE, Player.TILE_SIZE) * 0.5
	player._spawn_ground_item(_held_item.item_id, _held_item.quantity, ground_pos)
	_clear_held()

func _return_held_item() -> void:
	var player = GameManager.player
	if player and is_instance_valid(player):
		# Try to return to original slot first
		if _held_source_slot >= 0 and _held_source_slot < Player.INVENTORY_SLOTS and player.inventory[_held_source_slot] == null:
			player.inventory[_held_source_slot] = {item_id = _held_item.item_id, quantity = _held_item.quantity}
		else:
			var leftover = player.add_item(_held_item.item_id, _held_item.quantity)
			if leftover > 0:
				player._spawn_ground_item(_held_item.item_id, leftover, player.position)
	_clear_held()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_selected_slots.clear()
		# Don't clear held item — hotbar stays interactive while panel is hidden.
		# Cursor ghost visibility is managed by _update_cursor_ghost in _process.
