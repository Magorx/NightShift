class_name ItemIcon
extends TextureRect

## Reusable item icon with hover tooltip.
## Use ItemIcon.create(item_id, size) to instantiate.

var _item_id: StringName
var _hover_time: float = 0.0
var _tooltip_label: Label
const HOVER_DELAY := 1.0

## If true, this icon will respond to RMB-hold to open the recipe browser.
var rmb_browsable: bool = false
var _rmb_hold_time: float = 0.0
const RMB_HOLD_THRESHOLD := 0.3

static func create(item_id: StringName, icon_size: Vector2 = Vector2(16, 16), browsable: bool = false) -> Control:
	var icon_tex := GameManager.get_item_icon(item_id)
	if not icon_tex:
		return _create_color_fallback(item_id, icon_size)
	var icon := ItemIcon.new()
	icon._item_id = item_id
	icon.rmb_browsable = browsable
	icon.texture = icon_tex
	icon.custom_minimum_size = icon_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_STOP if browsable else Control.MOUSE_FILTER_IGNORE
	return icon

static func _create_color_fallback(item_id: StringName, icon_size: Vector2) -> PanelContainer:
	var item_def = GameManager.get_item_def(item_id)
	var color: Color = item_def.color if item_def else Color.WHITE
	var outline_color := Color.BLACK if color.get_luminance() > 0.4 else Color.WHITE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = outline_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	var panel := PanelContainer.new()
	panel.custom_minimum_size = icon_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	return panel

func set_item(item_id: StringName) -> void:
	if item_id == _item_id:
		return
	_item_id = item_id
	texture = GameManager.get_item_icon(item_id)
	_hide_tooltip()
	_hover_time = 0.0

func _process(delta: float) -> void:
	var hovered := _is_hovered()
	if not hovered:
		if _tooltip_label:
			_hide_tooltip()
		_hover_time = 0.0
		_rmb_hold_time = 0.0
		return
	_hover_time += delta
	if _hover_time >= HOVER_DELAY and not _tooltip_label:
		_show_tooltip()
	if _tooltip_label and is_instance_valid(_tooltip_label):
		_update_tooltip_position()

	# RMB hold to open recipe browser
	if rmb_browsable and hovered and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rmb_hold_time += delta
		if _rmb_hold_time >= RMB_HOLD_THRESHOLD:
			_rmb_hold_time = 0.0
			_open_recipe_browser()
	else:
		_rmb_hold_time = 0.0

func _open_recipe_browser() -> void:
	# Walk up the tree to find the HUD and open recipe browser
	var node := get_parent()
	while node:
		if node.has_method("open_recipe_browser_for_item"):
			node.open_recipe_browser_for_item(_item_id)
			return
		node = node.get_parent()

func _is_hovered() -> bool:
	if not is_visible_in_tree():
		return false
	var mouse_pos := get_viewport().get_mouse_position()
	if not get_global_rect().has_point(mouse_pos):
		return false
	# Don't show tooltip if a GameWindow is visible on top of us
	if _is_covered_by_window(mouse_pos):
		return false
	return true

## Cached list of GameWindows in the scene. Rebuilt lazily.
static var _cached_windows: Array = []
static var _cache_valid: bool = false

func _is_covered_by_window(mouse_pos: Vector2) -> bool:
	## Returns true if a visible GameWindow covers this mouse position,
	## and this icon is NOT inside that window.
	if not _cache_valid:
		_cached_windows.clear()
		var root := get_tree().root
		if root:
			_collect_game_windows(root, _cached_windows)
		_cache_valid = true
		# Invalidate cache next frame so new windows are picked up
		get_tree().process_frame.connect(func(): _cache_valid = false, CONNECT_ONE_SHOT)

	# Walk ancestors to see if we're inside a GameWindow
	var our_window: Control = null
	var node := get_parent()
	while node:
		if node is GameWindow:
			our_window = node
			break
		node = node.get_parent()

	for win in _cached_windows:
		if not is_instance_valid(win):
			continue
		if win == our_window:
			continue
		if not win.visible:
			continue
		if win.get_global_rect().has_point(mouse_pos):
			return true
	return false

static func _collect_game_windows(node: Node, result: Array) -> void:
	if node is GameWindow:
		result.append(node)
	for child in node.get_children():
		_collect_game_windows(child, result)

func _show_tooltip() -> void:
	var item_def = GameManager.get_item_def(_item_id)
	if not item_def:
		return
	_tooltip_label = Label.new()
	_tooltip_label.text = item_def.display_name
	_tooltip_label.add_theme_font_size_override("font_size", 10)
	_tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	bg.set_content_margin_all(2)
	_tooltip_label.add_theme_stylebox_override("normal", bg)
	_tooltip_label.z_index = 200
	_tooltip_label.top_level = true
	add_child(_tooltip_label)
	await get_tree().process_frame
	if is_instance_valid(_tooltip_label):
		_update_tooltip_position()

func _update_tooltip_position() -> void:
	var icon_rect := get_global_rect()
	_tooltip_label.position = Vector2(
		icon_rect.position.x + icon_rect.size.x * 0.5 - _tooltip_label.size.x * 0.5,
		icon_rect.position.y - _tooltip_label.size.y - 2
	)

func _hide_tooltip() -> void:
	if _tooltip_label and is_instance_valid(_tooltip_label):
		_tooltip_label.queue_free()
		_tooltip_label = null

func _exit_tree() -> void:
	_hide_tooltip()
