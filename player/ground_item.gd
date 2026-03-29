class_name GroundItem
extends Node2D
## A loose item stack on the ground. Can be picked up by the player.

const HOVER_RADIUS := 16.0
const Z_NORMAL := 10
const Z_HOVERED := 20
const MERGE_RANGE := 24.0
const MERGE_INTERVAL := 2.0
const FEED_INTERVAL := 0.5
const MAX_ITEMS_VISIBLE_IN_STACK := 3
const STACK_COUNT_FONT_SIZE := 15

var item_id: StringName = &""
var quantity: int = 1
var despawn_timer: float = 120.0  # seconds until auto-despawn
var _pickup_immunity: float = 0.0  # seconds of pickup immunity (after death drop)
var _hovered: bool = false
var _merge_timer: float = 0.0
var _feed_timer: float = 0.0

func _ready() -> void:
	add_to_group("ground_items")
	z_index = Z_NORMAL
	_merge_timer = randf() * MERGE_INTERVAL # stagger merge checks
	_feed_timer = randf() * FEED_INTERVAL

func _process(delta: float) -> void:
	despawn_timer -= delta
	if despawn_timer <= 0:
		queue_free()
		return
	if _pickup_immunity > 0:
		_pickup_immunity -= delta
	_hovered = get_local_mouse_position().length() < HOVER_RADIUS
	z_index = Z_HOVERED if _hovered else Z_NORMAL
	_merge_timer += delta
	if _merge_timer >= MERGE_INTERVAL:
		_merge_timer = 0.0
		_try_merge_nearby()
	_feed_timer += delta
	if _feed_timer >= FEED_INTERVAL:
		_feed_timer = 0.0
		_try_feed_building()
	queue_redraw()

func _draw() -> void:
	var item_def = GameManager.get_item_def(item_id)
	var color: Color = item_def.color if item_def else Color.WHITE
	var count := mini(quantity, MAX_ITEMS_VISIBLE_IN_STACK) # max 4 visible dots

	for i in count:
		var offset := Vector2(i * 3.0 - (count - 1) * 1.5, -i * 2.0)
		var rect := Rect2(offset - Vector2(4, 4), Vector2(8, 8))
		if _hovered:
			draw_rect(Rect2(offset - Vector2(6, 6), Vector2(12, 12)), Color(1, 1, 1, 0.85), false, 1.5)
		draw_rect(rect, color)
		draw_rect(rect, Color(0, 0, 0, 0.3), false, 1.0)

	if _hovered:
		var camera := get_viewport().get_camera_2d()
		var inv_zoom := 1.0 / camera.zoom.x if camera else 1.0
		# Anchor at top-right corner of the topmost dot (fixed world position)
		var top_idx := count - 1
		var top_offset := Vector2(top_idx * 3.0 - (count - 1) * 1.5, -top_idx * 2.0)
		var anchor := top_offset + Vector2(8, -8)
		# Scale text to fixed screen size; position stays pinned to the anchor
		draw_set_transform(anchor, 0.0, Vector2(inv_zoom, inv_zoom))
		var font := ThemeDB.fallback_font
		var text := str(quantity)
		draw_string_outline(font, Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, STACK_COUNT_FONT_SIZE, 2, Color.WHITE)
		draw_string(font, Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, STACK_COUNT_FONT_SIZE, Color(0.1, 0.1, 0.1))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── Click to pick up ─────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _hovered:
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var player = GameManager.player
	if not player or not is_instance_valid(player):
		return
	if player.position.distance_to(position) > Player.PICKUP_RANGE:
		return
	var remaining = player.add_item(item_id, quantity)
	if remaining < quantity:
		if remaining <= 0:
			queue_free()
		else:
			quantity = remaining
		get_viewport().set_input_as_handled()

# ── Merge ────────────────────────────────────────────────────────────────────

func _try_merge_nearby() -> void:
	for other in get_tree().get_nodes_in_group("ground_items"):
		if other == self or not is_instance_valid(other):
			continue
		if other.item_id == item_id and position.distance_to(other.position) < MERGE_RANGE:
			# Lower instance absorbs higher to prevent double-merge
			if get_instance_id() < other.get_instance_id():
				quantity += other.quantity
				other.queue_free()
				return

# ── Building feed ────────────────────────────────────────────────────────────

func _try_feed_building() -> void:
	var grid_pos := Vector2i(floori(position.x / 32.0), floori(position.y / 32.0))
	var building = GameManager.get_building_at(grid_pos)
	if not building or not building.logic:
		return
	var leftover = building.logic.try_insert_item(item_id, quantity)
	if leftover < quantity:
		quantity = leftover
		if quantity <= 0:
			queue_free()

func set_pickup_immunity(time: float) -> void:
	_pickup_immunity = time

func can_be_picked_up() -> bool:
	return _pickup_immunity <= 0

# ── Serialization ────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {
		item_id = str(item_id),
		quantity = quantity,
		x = position.x,
		y = position.y,
		despawn = despawn_timer,
	}

static func deserialize_from(data: Dictionary) -> Dictionary:
	return {
		item_id = StringName(data.get("item_id", "")),
		quantity = int(data.get("quantity", 1)),
		x = float(data.get("x", 0)),
		y = float(data.get("y", 0)),
		despawn = float(data.get("despawn", 120)),
	}
