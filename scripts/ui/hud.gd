extends Control

signal building_selected(id: StringName)

const SPEED_STEPS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0]
const SPEED_LABELS := ["x0.25", "x0.5", "x1", "x1.5", "x2", "x3"]

@onready var currency_value: Label = %CurrencyValue
@onready var item_list: VBoxContainer = %ItemList
@onready var slow_button: Button = %SlowButton
@onready var speed_label: Label = %SpeedLabel
@onready var fast_button: Button = %FastButton
@onready var buildings_button: Button = %BuildingsButton
@onready var buildings_panel: PanelContainer = $BuildingsPanel
@onready var minimap_display: Control = $BottomRight/MinimapPanel/MinimapDisplay

var speed_index: int = 2 # default x1
var paused: bool = false
var _delivery_timer: float = 0.0

func _ready() -> void:
	slow_button.pressed.connect(_on_slow_pressed)
	fast_button.pressed.connect(_on_fast_pressed)
	buildings_button.gui_input.connect(_on_buildings_button_gui_input)
	buildings_panel.building_selected.connect(_on_building_selected)

func set_camera(cam: Camera2D) -> void:
	minimap_display.set_camera(cam)

func _process(delta: float) -> void:
	_delivery_timer += delta
	if _delivery_timer >= 0.5:
		_delivery_timer = 0.0
		_update_delivery_counter()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"time_pause"):
		_toggle_pause()
	elif event.is_action_pressed(&"time_speed_up"):
		_change_speed(1)
	elif event.is_action_pressed(&"time_speed_down"):
		_change_speed(-1)
	# Building hotkeys
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode: int = event.physical_keycode
		if GameManager.building_hotkeys.has(keycode):
			var bid: StringName = GameManager.building_hotkeys[keycode]
			building_selected.emit(bid)

func is_buildings_panel_open() -> bool:
	return buildings_panel.visible

func close_buildings_panel() -> void:
	buildings_panel.visible = false

func _on_building_selected(id: StringName) -> void:
	building_selected.emit(id)

func _on_buildings_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			# Double-click: show and snap to center
			buildings_panel.visible = true
			buildings_panel.move_to_center()
		else:
			# Single click: toggle visibility
			buildings_panel.visible = not buildings_panel.visible

# ── Delivery Counter ──────────────────────────────────────────────────────

func _update_delivery_counter() -> void:
	currency_value.text = str(GameManager.total_currency)

	# Clear old rows
	for child in item_list.get_children():
		child.queue_free()

	if GameManager.items_delivered.is_empty():
		return

	# Sort by count descending
	var entries: Array = []
	for item_id in GameManager.items_delivered:
		entries.append({id = item_id, count = GameManager.items_delivered[item_id]})
	entries.sort_custom(func(a, b): return a.count > b.count)

	for entry in entries:
		var row := HBoxContainer.new()

		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = Vector2(12, 12)
		var item_def = _get_item_def(entry.id)
		color_rect.color = item_def.color if item_def else Color.WHITE
		row.add_child(color_rect)

		var name_label := Label.new()
		name_label.text = " %s" % (item_def.display_name if item_def else str(entry.id))
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var count_label := Label.new()
		count_label.text = str(entry.count)
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count_label)

		item_list.add_child(row)

# ── Time Speed ────────────────────────────────────────────────────────────

func _toggle_pause() -> void:
	paused = not paused
	if paused:
		Engine.time_scale = 0.0
		speed_label.text = "PAUSED"
		speed_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		Engine.time_scale = SPEED_STEPS[speed_index]
		speed_label.text = SPEED_LABELS[speed_index]
		speed_label.remove_theme_color_override("font_color")
	_update_speed_buttons()

func _change_speed(direction: int) -> void:
	speed_index = clampi(speed_index + direction, 0, SPEED_STEPS.size() - 1)
	if not paused:
		Engine.time_scale = SPEED_STEPS[speed_index]
	speed_label.text = SPEED_LABELS[speed_index] if not paused else "PAUSED"
	_update_speed_buttons()

func _on_slow_pressed() -> void:
	_change_speed(-1)

func _on_fast_pressed() -> void:
	_change_speed(1)

func _update_speed_buttons() -> void:
	slow_button.disabled = speed_index <= 0
	fast_button.disabled = speed_index >= SPEED_STEPS.size() - 1

# ── Helpers ───────────────────────────────────────────────────────────────

func _get_item_def(item_id: StringName):
	return GameManager.get_item_def(item_id)
