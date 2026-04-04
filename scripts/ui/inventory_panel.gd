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
const FLY_DURATION := 0.18

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
var _ghost_icon: TextureRect
var _ghost_label: Label

# Pickup fly animation (slot → cursor)
var _fly_item: Control = null
var _fly_start: Vector2 = Vector2.ZERO
var _fly_progress: float = 0.0

func _ready() -> void:
	super()
	_create_slots()
	_create_cursor_ghost()

func _process(delta: float) -> void:
	super(delta)
	_update_fly_animation(delta)
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

	var icon_rect := ItemIcon.new()
	icon_rect.name = "ItemIcon"
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.position = Vector2(8, 8)
	icon_rect.size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.visible = false
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_rect)

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

	_ghost_icon = TextureRect.new()
	_ghost_icon.size = Vector2(32, 32)
	_ghost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost_icon.modulate.a = 0.75
	_ghost_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_ghost.add_child(_ghost_icon)

	_ghost_label = Label.new()
	_ghost_label.add_theme_font_size_override("font_size", 10)
	_ghost_label.position = Vector2(18, 18)
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
	var icon_rect: ItemIcon = panel.get_node("ItemIcon")
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
		icon_rect.set_item(slot_data.item_id)
		icon_rect.visible = true
		label.text = str(slot_data.quantity) if slot_data.quantity > 1 else ""
	else:
		icon_rect.visible = false
		label.text = ""

	panel.modulate = Color(0.5, 0.5, 0.5, 0.5) if is_source_empty else Color.WHITE

func _update_cursor_ghost() -> void:
	if _held_item.is_empty():
		if _cursor_ghost:
			_cursor_ghost.visible = false
		return
	# Hide ghost while fly animation is active
	if _fly_item and is_instance_valid(_fly_item):
		_cursor_ghost.visible = false
		return
	_cursor_ghost.visible = true
	var ghost_size := Vector2(32, 32)
	var vp_size := get_viewport_rect().size
	var pos := get_global_mouse_position() + Vector2(8, 8)
	pos.x = clampf(pos.x, 0, vp_size.x - ghost_size.x)
	pos.y = clampf(pos.y, 0, vp_size.y - ghost_size.y)
	_cursor_ghost.global_position = pos
	_ghost_icon.texture = GameManager.get_item_icon(_held_item.item_id)
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
			_animate_pickup_to_cursor(index, slot_data.item_id, slot_data.quantity)
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
			_animate_pickup_to_cursor(index, slot_data.item_id, half)
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
	var camera := get_viewport().get_camera_3d()
	if not camera:
		_return_held_item()
		return
	# Screen → world conversion via ground plane raycast
	var screen_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	# Intersect with Y=0 ground plane
	if absf(ray_dir.y) < 0.001:
		_return_held_item()
		return
	var t := -ray_origin.y / ray_dir.y
	var world_pos: Vector3 = ray_origin + ray_dir * t
	# Clamp to max range from player
	var to_target: Vector3 = world_pos - player.position
	to_target.y = 0.0
	if to_target.length() > DROP_RANGE:
		world_pos = player.position + to_target.normalized() * DROP_RANGE
	# Try to insert into building at drop position
	var drop_grid := GridUtils.world_to_grid(world_pos)
	var building = GameManager.get_building_at(drop_grid)
	if building and building.logic:
		var leftover: int = building.logic.try_insert_item(_held_item.item_id, _held_item.quantity)
		if leftover <= 0:
			_clear_held()
			return
		_held_item.quantity = leftover
	# Drop on top of the building so it can consume from the stack later
	var ground_pos: Vector3 = world_pos
	if building:
		ground_pos = GridUtils.grid_to_center(drop_grid)
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

# ── Fly Animation (pickup & place) ─────────────────────────────────────────

func _get_cursor_ghost_pos() -> Vector2:
	var ghost_size := Vector2(32, 32)
	var vp_size := get_viewport_rect().size
	var pos := get_global_mouse_position() + Vector2(8, 8)
	pos.x = clampf(pos.x, 0, vp_size.x - ghost_size.x)
	pos.y = clampf(pos.y, 0, vp_size.y - ghost_size.y)
	return pos

func _get_slot_screen_center(index: int) -> Vector2:
	if visible and index < _slots.size():
		return _slots[index].get_global_rect().get_center()
	if index < 8:
		var hotbar = get_parent().get_node_or_null("Hotbar")
		if hotbar and index < hotbar._slots.size():
			return hotbar._slots[index].get_global_rect().get_center()
	return get_global_mouse_position()

func _animate_pickup_to_cursor(slot_index: int, item_id: StringName, quantity: int) -> void:
	if _fly_item and is_instance_valid(_fly_item):
		_fly_item.queue_free()

	_fly_start = _get_slot_screen_center(slot_index)
	_fly_progress = 0.0

	_fly_item = Control.new()
	_fly_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly_item.top_level = true
	_fly_item.z_index = 101

	var icon_rect := TextureRect.new()
	icon_rect.size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.texture = GameManager.get_item_icon(item_id)
	icon_rect.modulate.a = 0.75
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly_item.add_child(icon_rect)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", 10)
	label.position = Vector2(14, 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(quantity) if quantity > 1 else ""
	_fly_item.add_child(label)

	_fly_item.global_position = _fly_start
	get_parent().add_child(_fly_item)

func _update_fly_animation(delta: float) -> void:
	if not _fly_item or not is_instance_valid(_fly_item):
		return

	_fly_progress += delta / FLY_DURATION
	if _fly_progress >= 1.0:
		_fly_item.queue_free()
		_fly_item = null
		return

	var t := 1.0 - pow(1.0 - _fly_progress, 3.0)
	var end := _get_cursor_ghost_pos()
	_fly_item.global_position = _fly_start.lerp(end, t)
	_fly_item.modulate.a = lerpf(0.0, 0.75, t)
	var s := lerpf(1.3, 1.0, t)
	_fly_item.scale = Vector2(s, s)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_selected_slots.clear()
		# Don't clear held item — hotbar stays interactive while panel is hidden.
		# Cursor ghost visibility is managed by _update_cursor_ghost in _process.
