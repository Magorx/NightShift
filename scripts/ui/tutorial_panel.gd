extends PanelContainer

@onready var title_label: Label = %TitleLabel
@onready var step_label: Label = %StepLabel
@onready var skip_button: Button = %SkipButton
@onready var text_label: RichTextLabel = %TextLabel
@onready var task_row: HBoxContainer = %TaskRow
@onready var task_label: Label = %TaskLabel
@onready var task_check: Label = %TaskCheck
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton

func _ready() -> void:
	prev_button.pressed.connect(_on_prev)
	next_button.pressed.connect(_on_next)
	skip_button.pressed.connect(_on_skip)
	TutorialManager.step_changed.connect(_on_step_changed)
	TutorialManager.task_completed.connect(_on_task_completed)
	TutorialManager.task_progress_changed.connect(_on_task_progress)
	TutorialManager.tutorial_finished.connect(_on_finished)
	_refresh()

func _on_prev() -> void:
	TutorialManager.go_prev()

func _on_next() -> void:
	TutorialManager.go_next()

func _on_skip() -> void:
	TutorialManager.skip()

func _on_step_changed(_step_index: int) -> void:
	_refresh()

func _on_task_completed(_step_index: int) -> void:
	_refresh()

func _on_task_progress(_current: int, _required: int) -> void:
	_refresh()

func _on_finished() -> void:
	visible = false

func _refresh() -> void:
	if not TutorialManager.active:
		visible = false
		return

	visible = true
	var idx: int = TutorialManager.current_step
	if idx < 0 or idx >= TutorialManager.steps.size():
		visible = false
		return

	var step: Dictionary = TutorialManager.steps[idx]

	step_label.text = "%d/%d" % [idx + 1, TutorialManager.steps.size()]
	text_label.text = step.get("text", "")

	# Task row
	var task_text: String = step.get("task", "")
	if task_text != "":
		task_row.visible = true
		var progress: Vector2i = TutorialManager.get_task_progress()
		if TutorialManager.task_done:
			task_label.text = task_text
			task_check.text = "done"
			task_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		elif progress.y > 0:
			task_label.text = "%s (%d/%d)" % [task_text, progress.x, progress.y]
			task_check.text = ""
			task_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		else:
			task_label.text = task_text
			task_check.text = ""
			task_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	else:
		task_row.visible = false

	# Navigation buttons
	prev_button.disabled = not TutorialManager.can_go_prev()
	next_button.disabled = not TutorialManager.can_go_next()
