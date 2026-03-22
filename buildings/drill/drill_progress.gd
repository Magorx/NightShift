extends Node2D

const BAR_WIDTH := 24.0
const BAR_HEIGHT := 4.0
const BAR_OFFSET_Y := 28.0  # below the building
const BG_COLOR := Color(0.2, 0.2, 0.2, 0.8)
const FILL_COLOR := Color(0.3, 0.85, 0.4, 0.9)

var _extractor: Node

func _ready() -> void:
	var parent = get_parent()
	if parent:
		var ext = parent.find_child("ExtractorLogic", true, false)
		if ext:
			_extractor = ext

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not _extractor:
		return
	var progress: float = _extractor.get_progress()
	var x := (32.0 - BAR_WIDTH) * 0.5  # center in tile
	var y := BAR_OFFSET_Y
	# Background
	draw_rect(Rect2(x, y, BAR_WIDTH, BAR_HEIGHT), BG_COLOR)
	# Fill
	if progress > 0.0:
		draw_rect(Rect2(x, y, BAR_WIDTH * progress, BAR_HEIGHT), FILL_COLOR)
