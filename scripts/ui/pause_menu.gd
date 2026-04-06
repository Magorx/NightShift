extends Control

func _ready() -> void:
	$Panel/VBox/ResumeButton.pressed.connect(_on_resume)
	$Panel/VBox/SaveButton.pressed.connect(_on_save)
	$Panel/VBox/QuitButton.pressed.connect(_on_quit_to_menu)
	# Initialize creative mode toggle
	var creative_toggle: CheckButton = $Panel/VBox/CreativeToggle
	creative_toggle.button_pressed = EconomyTracker.creative_mode
	creative_toggle.toggled.connect(_on_creative_toggled)
	# Initialize pixel art toggle
	var pixel_art_toggle: CheckButton = $Panel/VBox/PixelArtToggle
	pixel_art_toggle.button_pressed = SettingsManager.pixel_art_enabled
	pixel_art_toggle.toggled.connect(func(enabled: bool): SettingsManager.pixel_art_enabled = enabled)
	# Initialize debug mode toggle
	var debug_toggle: CheckButton = $Panel/VBox/DebugToggle
	debug_toggle.button_pressed = SettingsManager.debug_mode
	debug_toggle.toggled.connect(func(enabled: bool): SettingsManager.debug_mode = enabled)
	# Pause the game tree
	get_tree().paused = true
	visible = true

func _on_resume() -> void:
	get_tree().paused = false
	queue_free()

func _on_save() -> void:
	SaveManager.save_run()
	$Panel/VBox/SaveButton.text = "Saved!"
	# Reset button text after a moment
	get_tree().create_timer(1.0, true, false, true).timeout.connect(
		func(): if is_instance_valid($Panel/VBox/SaveButton): $Panel/VBox/SaveButton.text = "Save"
	)

func _on_creative_toggled(enabled: bool) -> void:
	EconomyTracker.creative_mode = enabled

func _on_quit_to_menu() -> void:
	SaveManager.save_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume()
