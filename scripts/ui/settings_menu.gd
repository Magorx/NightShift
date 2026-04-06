extends Control

@onready var back_button: Button = $CenterMargin/VBox/BottomSpacer/BackButton
@onready var pixel_art_toggle: CheckButton = $CenterMargin/VBox/PixelArtToggle

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	pixel_art_toggle.button_pressed = SettingsManager.pixel_art_enabled
	pixel_art_toggle.toggled.connect(func(enabled: bool): SettingsManager.pixel_art_enabled = enabled)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
