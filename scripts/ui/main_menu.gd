extends Control

@onready var continue_button: Button = $CenterMargin/VBox/ContinueButton
@onready var new_run_button: Button = $CenterMargin/VBox/NewRunButton
@onready var settings_button: Button = $CenterMargin/VBox/SettingsButton
@onready var stress_test_button: Button = $CenterMargin/VBox/StressTestButton
@onready var quit_button: Button = $CenterMargin/VBox/QuitButton
@onready var account_button: Button = $AccountButton
@onready var account_panel: PanelContainer = $AccountPanel
@onready var slot_buttons: Array[Button] = [
	$AccountPanel/SlotList/SlotButton0,
	$AccountPanel/SlotList/SlotButton1,
	$AccountPanel/SlotList/SlotButton2,
]
@onready var confirm_overlay: ColorRect = $ConfirmOverlay
@onready var confirm_label: Label = $ConfirmOverlay/Panel/VBox/ConfirmLabel
@onready var confirm_yes: Button = $ConfirmOverlay/Panel/VBox/ButtonRow/ConfirmYes
@onready var confirm_no: Button = $ConfirmOverlay/Panel/VBox/ButtonRow/ConfirmNo

var _confirm_action: Callable

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	stress_test_button.pressed.connect(_on_stress_test_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	account_button.pressed.connect(_on_account_button_pressed)
	confirm_yes.pressed.connect(func(): _confirm_action.call())
	confirm_no.pressed.connect(func(): confirm_overlay.visible = false)
	for i in slot_buttons.size():
		slot_buttons[i].pressed.connect(_on_slot_selected.bind(i))
	_update_continue_button()
	_update_account_button()
	_update_slot_buttons()

func _update_continue_button() -> void:
	continue_button.visible = SaveManager.has_run_save()

func _update_account_button() -> void:
	var meta := AccountManager.load_meta(AccountManager.active_slot)
	account_button.text = "Account: %s (Slot %d)" % [meta.get("player_name", "Player"), AccountManager.active_slot + 1]

func _update_slot_buttons() -> void:
	for i in slot_buttons.size():
		var meta := AccountManager.load_meta(i)
		var label := "Slot %d — %s" % [i + 1, meta.get("player_name", "Player %d" % (i + 1))]
		if AccountManager.has_run_save(i):
			label += "  [save]"
		slot_buttons[i].text = label
		slot_buttons[i].disabled = (i == AccountManager.active_slot)

func _on_account_button_pressed() -> void:
	_update_slot_buttons()
	account_panel.visible = not account_panel.visible

func _on_slot_selected(id: int) -> void:
	AccountManager.set_active_slot(id)
	account_panel.visible = false
	_update_account_button()
	_update_slot_buttons()
	_update_continue_button()

func _on_continue_pressed() -> void:
	SaveManager.pending_load = true
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")

func _on_new_run_pressed() -> void:
	if SaveManager.has_run_save():
		_show_confirm("This will overwrite your current run. Continue?", _start_new_run)
	else:
		_start_new_run()

func _start_new_run() -> void:
	GameLogger.info("New game started (slot %d)" % AccountManager.active_slot)
	_launch_game(64, false)

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")

func _on_stress_test_pressed() -> void:
	if SaveManager.has_run_save():
		_show_confirm("Stress test will overwrite your current run. Continue?", _start_stress_test)
	else:
		_start_stress_test()

func _start_stress_test() -> void:
	_launch_game(160, true, 0)

func _launch_game(map_size: int, stress_test: bool, seed_val: int = -1) -> void:
	confirm_overlay.visible = false
	SaveManager.delete_run_save()
	GameManager.total_currency = 0
	GameManager.map_size = map_size
	GameManager.stress_test_pending = stress_test
	if seed_val >= 0:
		GameManager.world_seed = seed_val
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")

func _show_confirm(message: String, action: Callable) -> void:
	confirm_label.text = message
	_confirm_action = action
	confirm_overlay.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()
