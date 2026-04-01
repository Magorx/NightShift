extends PanelContainer

## Side menu for ItemSource: grid of all game items.
## Each 16x16 icon sits on a 20x20 square — green if enabled, red if disabled.
## Click to toggle. Reports changes back to the source logic.

const ICON_SIZE := Vector2(16, 16)
const CELL_SIZE := Vector2(20, 20)
const GRID_COLUMNS := 8
const ENABLED_COLOR := Color(0.2, 0.8, 0.3, 0.9)
const DISABLED_COLOR := Color(0.8, 0.2, 0.2, 0.9)

var _source_logic # ItemSource reference
var _cells: Array = [] # [{panel: PanelContainer, item_id: StringName, style: StyleBoxFlat}]
var grid: GridContainer

func populate(source_logic) -> void:
	grid = $MarginContainer/Grid
	_source_logic = source_logic
	var all_items: Array = GameManager.get_all_item_defs()
	for item_def in all_items:
		var is_enabled: bool = source_logic.enabled_items.has(item_def.id)
		var cell := _create_cell(item_def.id, is_enabled)
		grid.add_child(cell.panel)
		_cells.append(cell)

func _create_cell(item_id: StringName, enabled: bool) -> Dictionary:
	var style := StyleBoxFlat.new()
	style.bg_color = ENABLED_COLOR if enabled else DISABLED_COLOR
	style.set_corner_radius_all(2)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	var panel := PanelContainer.new()
	panel.custom_minimum_size = CELL_SIZE
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var icon: Control = ItemIcon.create(item_id, ICON_SIZE)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)

	var entry := {panel = panel, item_id = item_id, style = style}
	panel.gui_input.connect(_on_cell_input.bind(entry))
	return entry

func _on_cell_input(event: InputEvent, entry: Dictionary) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	entry.panel.accept_event()
	if not _source_logic:
		return
	var item_id: StringName = entry.item_id
	var is_enabled: bool = _source_logic.enabled_items.has(item_id)
	if is_enabled:
		_source_logic.enabled_items.erase(item_id)
	else:
		_source_logic.enabled_items.append(item_id)
	is_enabled = _source_logic.enabled_items.has(item_id)
	entry.style.bg_color = ENABLED_COLOR if is_enabled else DISABLED_COLOR
