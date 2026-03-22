extends Control

signal building_selected(id: StringName)

@onready var toolbar: HBoxContainer = $ToolbarPanel/Toolbar

func _ready() -> void:
	_populate_toolbar()

func _populate_toolbar() -> void:
	for child in toolbar.get_children():
		child.queue_free()

	var defs = GameManager.building_defs
	for id in defs:
		var def = defs[id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(80, 60)
		button.text = def.display_name

		# Colored icon via a ColorRect inside the button
		var icon_rect := ColorRect.new()
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.color = def.color
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		var label := Label.new()
		label.text = def.display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)

		button.pressed.connect(_on_building_button_pressed.bind(def.id))
		toolbar.add_child(button)

func _on_building_button_pressed(id: StringName) -> void:
	building_selected.emit(id)
