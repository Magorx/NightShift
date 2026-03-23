extends Control

func _ready() -> void:
	$Panel/VBox/ResumeButton.pressed.connect(_on_resume)
	$Panel/VBox/SaveButton.pressed.connect(_on_save)
	$Panel/VBox/QuitButton.pressed.connect(_on_quit_to_menu)
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

func _on_quit_to_menu() -> void:
	SaveManager.save_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume()
