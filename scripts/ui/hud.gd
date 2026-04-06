extends Control

signal building_selected(id: StringName)
signal buildings_opened
signal inventory_opened

const SPEED_STEPS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0]
const SPEED_LABELS := ["x0.25", "x0.5", "x1", "x1.5", "x2", "x3"]

@onready var phase_display: PanelContainer = %PhaseDisplay
@onready var round_label: Label = %RoundLabel
@onready var phase_label: Label = %PhaseLabel
@onready var timer_label: Label = %TimerLabel
@onready var phase_flash: ColorRect = %PhaseFlash
@onready var skip_button: Button = %SkipButton
@onready var slow_button: Button = %SlowButton
@onready var speed_label: Label = %SpeedLabel
@onready var fast_button: Button = %FastButton
@onready var buildings_button: Button = %BuildingsButton
@onready var buildings_panel: PanelContainer = $BuildingsPanel
@onready var inventory_button: Button = %InventoryButton
@onready var inventory_panel: PanelContainer = $InventoryPanel
@onready var fps_label: Label = %FpsLabel
@onready var minimap_display: Control = $BottomRight/RightColumn/MinimapPanel/MinimapDisplay
@onready var menu_toggle: Button = %MenuToggle
@onready var button_row: VBoxContainer = $BottomRight/ButtonRow
@onready var debug_button: Button = %DebugButton

var speed_index: int = 2 # default x1
var paused: bool = false
var _menu_expanded: bool = false
var _fps_frame_counter: int = 0
var _last_displayed_seconds: int = -1

func _ready() -> void:
	add_to_group("hud")
	_disable_focus_recursive(get_tree().root)
	slow_button.pressed.connect(_on_slow_pressed)
	fast_button.pressed.connect(_on_fast_pressed)
	menu_toggle.pressed.connect(_on_menu_toggle_pressed)
	buildings_button.gui_input.connect(_on_buildings_button_gui_input)
	buildings_panel.building_selected.connect(_on_building_selected)
	inventory_button.gui_input.connect(_on_inventory_button_gui_input)
	debug_button.pressed.connect(_on_debug_pressed)
	$Hotbar.inventory_panel = inventory_panel
	RoundManager.phase_changed.connect(_on_phase_changed)
	skip_button.pressed.connect(_on_skip_pressed)

func _disable_focus_recursive(node: Node) -> void:
	if node is BaseButton:
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_focus_recursive(child)

func set_camera(cam) -> void:
	minimap_display.set_camera(cam)

func _process(_delta: float) -> void:
	_fps_frame_counter += 1
	if _fps_frame_counter >= 30:
		_fps_frame_counter = 0
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_update_phase_timer()
	_update_phase_flash(_delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"time_pause"):
		_toggle_pause()
	elif event.is_action_pressed(&"time_speed_up"):
		_change_speed(1)
	elif event.is_action_pressed(&"time_speed_down"):
		_change_speed(-1)
	# Building hotkeys (Ctrl/Cmd + number)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed or event.meta_pressed:
			var keycode: int = event.physical_keycode
			if GameManager.building_hotkeys.has(keycode):
				var bid: StringName = GameManager.building_hotkeys[keycode]
				building_selected.emit(bid)
				get_viewport().set_input_as_handled()

func is_buildings_panel_open() -> bool:
	return buildings_panel.visible

func close_buildings_panel() -> void:
	buildings_panel.visible = false

func toggle_buildings_panel() -> void:
	buildings_panel.visible = not buildings_panel.visible
	if buildings_panel.visible:
		buildings_opened.emit()

func is_inventory_panel_open() -> bool:
	return inventory_panel.visible

func close_inventory_panel() -> void:
	inventory_panel.visible = false

func toggle_inventory_panel() -> void:
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible:
		inventory_opened.emit()

func _on_building_selected(id: StringName) -> void:
	building_selected.emit(id)

func _on_buildings_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			buildings_panel.visible = true
			buildings_panel.move_to_center()
		else:
			buildings_panel.visible = not buildings_panel.visible
		if buildings_panel.visible:
			buildings_opened.emit()

func _on_inventory_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			inventory_panel.visible = true
			inventory_panel.move_to_center()
		else:
			inventory_panel.visible = not inventory_panel.visible
		if inventory_panel.visible:
			inventory_opened.emit()

# ── Phase Display ─────────────────────────────────────────────────────────

var _flash_alpha: float = 0.0

## Only update the timer text (runs every frame via _process).
func _update_phase_timer() -> void:
	if not RoundManager.is_running:
		phase_display.visible = false
		return
	phase_display.visible = true
	var secs := int(RoundManager.get_time_remaining())
	if secs != _last_displayed_seconds:
		_last_displayed_seconds = secs
		var mins := secs / 60
		var sec_part := secs % 60
		timer_label.text = "%02d:%02d" % [mins, sec_part]

func _on_skip_pressed() -> void:
	if RoundManager.is_running and RoundManager.phase_timer > 1.0:
		RoundManager.phase_timer = 1.0

## Update round/phase labels + color (only on phase change, not every frame).
func _on_phase_changed(_phase: StringName) -> void:
	_flash_alpha = 0.4
	_last_displayed_seconds = -1
	round_label.text = "Round %d" % RoundManager.current_round
	phase_label.text = RoundManager.get_phase_name().to_upper()
	if RoundManager.get_phase_name() == &"build":
		phase_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		phase_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

func _update_phase_flash(delta: float) -> void:
	if _flash_alpha > 0.0:
		_flash_alpha -= delta * 0.8
		phase_flash.visible = true
		phase_flash.color.a = maxf(_flash_alpha, 0.0)
		if RoundManager.get_phase_name() == &"fight":
			phase_flash.color = Color(1.0, 0.2, 0.1, phase_flash.color.a)
		else:
			phase_flash.color = Color(1.0, 1.0, 1.0, phase_flash.color.a)
	else:
		phase_flash.visible = false

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
	if paused and direction > 0:
		# Unpause at minimum speed
		speed_index = 0
		paused = false
		Engine.time_scale = SPEED_STEPS[speed_index]
		speed_label.text = SPEED_LABELS[speed_index]
		speed_label.remove_theme_color_override("font_color")
		_update_speed_buttons()
		return
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

func _on_menu_toggle_pressed() -> void:
	_menu_expanded = not _menu_expanded
	button_row.visible = _menu_expanded
	menu_toggle.text = "▶" if _menu_expanded else "◀"

# ── Debug ─────────────────────────────────────────────────────────────────

func _on_debug_pressed() -> void:
	_debug_renew_ash()

## Debug: placeholder for Night Shift debug actions.
func _debug_renew_ash() -> void:
	print("[DEBUG] No ash renewal in Night Shift")

# ── Helpers ───────────────────────────────────────────────────────────────

func serialize_ui_panels() -> Dictionary:
	var data := {}
	if buildings_panel:
		data["buildings_panel"] = buildings_panel.serialize_ui_state()
	if inventory_panel:
		data["inventory_panel"] = inventory_panel.serialize_ui_state()
	return data

func deserialize_ui_panels(data: Dictionary) -> void:
	if buildings_panel and data.has("buildings_panel"):
		buildings_panel.deserialize_ui_state(data["buildings_panel"])
	if inventory_panel and data.has("inventory_panel"):
		inventory_panel.deserialize_ui_state(data["inventory_panel"])
