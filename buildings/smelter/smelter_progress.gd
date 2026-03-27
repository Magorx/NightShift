extends Node2D

const BAR_WIDTH := 24.0
const BAR_HEIGHT := 4.0
const BAR_OFFSET_Y := 92.0  # below the 2x3 building (3 rows * 32 = 96, minus a small margin)
const BG_COLOR := Color(0.2, 0.2, 0.2, 0.8)
const FILL_COLOR := Color(0.95, 0.6, 0.2, 0.9)

var _converter: Node
var _last_progress: float = -1.0

func _ready() -> void:
	var parent = get_parent()
	if parent:
		var conv = parent.find_child("ConverterLogic", true, false)
		if conv:
			_converter = conv

func _process(_delta: float) -> void:
	if _converter:
		var p: float = _converter.get_progress()
		if absf(p - _last_progress) > 0.005:
			_last_progress = p
			queue_redraw()

func _draw() -> void:
	if not _converter:
		return
	var progress: float = _converter.get_progress()
	# Center the bar under the building (2 tiles wide = 64px)
	var x := (64.0 - BAR_WIDTH) * 0.5
	var y := BAR_OFFSET_Y
	# Background
	draw_rect(Rect2(x, y, BAR_WIDTH, BAR_HEIGHT), BG_COLOR)
	# Fill
	if progress > 0.0:
		draw_rect(Rect2(x, y, BAR_WIDTH * progress, BAR_HEIGHT), FILL_COLOR)
