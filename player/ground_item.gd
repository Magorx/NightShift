class_name GroundItem
extends Node2D
## A loose item stack on the ground. Can be picked up by the player.

var item_id: StringName = &""
var quantity: int = 1
var despawn_timer: float = 120.0  # seconds until auto-despawn
var _pickup_immunity: float = 0.0  # seconds of pickup immunity (after death drop)

func _ready() -> void:
	add_to_group("ground_items")
	z_index = 3  # Above terrain, below player

func _process(delta: float) -> void:
	despawn_timer -= delta
	if despawn_timer <= 0:
		queue_free()
		return
	if _pickup_immunity > 0:
		_pickup_immunity -= delta
	queue_redraw()

func _draw() -> void:
	var item_def = GameManager.get_item_def(item_id)
	var color: Color = item_def.color if item_def else Color.WHITE
	# Draw stacked item dots
	var count := mini(quantity, 4)  # max 4 visible dots
	for i in count:
		var offset := Vector2(i * 3.0 - (count - 1) * 1.5, -i * 2.0)
		draw_rect(Rect2(offset - Vector2(4, 4), Vector2(8, 8)), color)
		draw_rect(Rect2(offset - Vector2(4, 4), Vector2(8, 8)), Color(0, 0, 0, 0.3), false, 1.0)

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
