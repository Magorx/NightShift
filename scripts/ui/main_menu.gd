extends Control

func _ready() -> void:
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/TestButton.pressed.connect(_on_test_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")

func _on_test_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/test_world.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
