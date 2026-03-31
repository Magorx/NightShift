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
@onready var inventory_button: Button = %InventoryButton
@onready var inventory_panel: PanelContainer = $InventoryPanel
@onready var research_button: Button = %ResearchButton
@onready var research_panel: PanelContainer = $ResearchPanel
@onready var recipes_button: Button = %RecipesButton
@onready var recipe_browser: PanelContainer = $RecipeBrowser
@onready var fps_label: Label = %FpsLabel
@onready var minimap_display: Control = $BottomRight/RightColumn/MinimapPanel/MinimapDisplay
@onready var collapse_button: Button = %CollapseButton
@onready var contract_content: VBoxContainer = $DeliveryPanel/MarginContainer/VBox/ContractContent
@onready var menu_toggle: Button = %MenuToggle
@onready var button_row: VBoxContainer = $BottomRight/ButtonRow

var speed_index: int = 2 # default x1
var paused: bool = false
var _delivery_timer: float = 0.0
var _contracts_collapsed: bool = false
var _menu_expanded: bool = false

func _ready() -> void:
	slow_button.pressed.connect(_on_slow_pressed)
	fast_button.pressed.connect(_on_fast_pressed)
	collapse_button.pressed.connect(_on_collapse_pressed)
	menu_toggle.pressed.connect(_on_menu_toggle_pressed)
	buildings_button.gui_input.connect(_on_buildings_button_gui_input)
	buildings_panel.building_selected.connect(_on_building_selected)
	inventory_button.gui_input.connect(_on_inventory_button_gui_input)
	research_button.gui_input.connect(_on_research_button_gui_input)
	recipes_button.gui_input.connect(_on_recipes_button_gui_input)
	$Hotbar.inventory_panel = inventory_panel

func set_camera(cam: Camera2D) -> void:
	minimap_display.set_camera(cam)

func _process(delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
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

func is_inventory_panel_open() -> bool:
	return inventory_panel.visible

func close_inventory_panel() -> void:
	inventory_panel.visible = false

func toggle_inventory_panel() -> void:
	inventory_panel.visible = not inventory_panel.visible

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

func _on_inventory_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			inventory_panel.visible = true
			inventory_panel.move_to_center()
		else:
			inventory_panel.visible = not inventory_panel.visible

func _on_research_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			research_panel.visible = true
			research_panel.move_to_center()
		else:
			research_panel.visible = not research_panel.visible

func _on_recipes_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			recipe_browser.visible = true
			recipe_browser.move_to_center()
		else:
			recipe_browser.visible = not recipe_browser.visible

func open_recipe_browser_for_item(item_id: StringName) -> void:
	recipe_browser.show_centered_on_item(item_id)

# ── Delivery Counter / Contracts ──────────────────────────────────────────

func _update_delivery_counter() -> void:
	currency_value.text = str(GameManager.total_currency)

	# Clear old rows
	for child in item_list.get_children():
		child.queue_free()

	# Show active contracts
	for contract in ContractManager.active_contracts:
		if contract.completed:
			continue
		# Contract title
		var title_label := Label.new()
		title_label.text = contract.title
		title_label.add_theme_font_size_override("font_size", 11)
		if contract.is_gate:
			title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			title_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		item_list.add_child(title_label)

		# Requirements
		for req in contract.requirements:
			var row := HBoxContainer.new()
			row.add_child(ItemIcon.create(req.item_id, Vector2(16, 16)))
			var item_def = _get_item_def(req.item_id)
			var name_label := Label.new()
			name_label.text = " %s" % (item_def.display_name if item_def else str(req.item_id))
			name_label.add_theme_font_size_override("font_size", 11)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var progress_label := Label.new()
			progress_label.text = "%d/%d" % [req.delivered, req.quantity]
			progress_label.add_theme_font_size_override("font_size", 11)
			if req.delivered >= req.quantity:
				progress_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			row.add_child(progress_label)
			item_list.add_child(row)

		# Reward line
		var reward_label := Label.new()
		reward_label.text = "  +$%d" % contract.reward_currency
		reward_label.add_theme_font_size_override("font_size", 10)
		reward_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
		item_list.add_child(reward_label)

		# Separator between contracts
		var sep := HSeparator.new()
		sep.custom_minimum_size = Vector2(0, 4)
		item_list.add_child(sep)

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

# ── Contracts Collapse ────────────────────────────────────────────────────

func _on_collapse_pressed() -> void:
	_contracts_collapsed = not _contracts_collapsed
	contract_content.visible = not _contracts_collapsed
	collapse_button.text = "▶" if _contracts_collapsed else "▼"

func _on_menu_toggle_pressed() -> void:
	_menu_expanded = not _menu_expanded
	button_row.visible = _menu_expanded
	menu_toggle.text = "▶" if _menu_expanded else "◀"

# ── Helpers ───────────────────────────────────────────────────────────────

func serialize_ui_panels() -> Dictionary:
	var data := {}
	if buildings_panel:
		data["buildings_panel"] = buildings_panel.serialize_ui_state()
	if inventory_panel:
		data["inventory_panel"] = inventory_panel.serialize_ui_state()
	if research_panel:
		data["research_panel"] = research_panel.serialize_ui_state()
	if recipe_browser:
		data["recipe_browser"] = recipe_browser.serialize_ui_state()
	return data

func deserialize_ui_panels(data: Dictionary) -> void:
	if buildings_panel and data.has("buildings_panel"):
		buildings_panel.deserialize_ui_state(data["buildings_panel"])
	if inventory_panel and data.has("inventory_panel"):
		inventory_panel.deserialize_ui_state(data["inventory_panel"])
	if research_panel and data.has("research_panel"):
		research_panel.deserialize_ui_state(data["research_panel"])
	if recipe_browser and data.has("recipe_browser"):
		recipe_browser.deserialize_ui_state(data["recipe_browser"])

func _get_item_def(item_id: StringName):
	return GameManager.get_item_def(item_id)
