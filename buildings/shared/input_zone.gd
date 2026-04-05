class_name InputZone
extends Area3D
## 3D input zone for physics-based buildings. Detects PhysicsItem bodies
## that overlap the zone so building logic can consume them.
## Position in building-local space encodes the grid cell offset:
##   cell = Vector2i(round(position.x), round(position.z))

## Directional mask — which directions items can arrive from at this cell.
## Defined in the building's default orientation (facing right).
@export var allow_right: bool = true
@export var allow_down: bool = true
@export var allow_left: bool = true
@export var allow_up: bool = true

## Items currently overlapping this zone.
var _overlapping_items: Array[PhysicsItem] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = PhysicsItem.ITEM_COLLISION_LAYER
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_mask() -> Array:
	return [allow_right, allow_down, allow_left, allow_up]

## Return the grid cell offset this zone represents.
func get_cell() -> Vector2i:
	return Vector2i(roundi(position.x), roundi(position.z))

## Get all PhysicsItems currently inside the zone.
func get_items() -> Array[PhysicsItem]:
	# Prune freed items
	var i := 0
	while i < _overlapping_items.size():
		if not is_instance_valid(_overlapping_items[i]):
			_overlapping_items.remove_at(i)
		else:
			i += 1
	return _overlapping_items

## Check if any item with the given id is inside the zone.
func has_item(item_id: StringName) -> bool:
	for item in get_items():
		if item.item_id == item_id:
			return true
	return false

## Consume (remove) one item with the given id. Returns true if consumed.
func consume_item(item_id: StringName) -> bool:
	for i in _overlapping_items.size():
		var item := _overlapping_items[i]
		if is_instance_valid(item) and item.item_id == item_id:
			_overlapping_items.remove_at(i)
			item.queue_free()
			return true
	return false

## Consume the first available item regardless of type. Returns item_id or empty.
func consume_any() -> StringName:
	for i in _overlapping_items.size():
		var item := _overlapping_items[i]
		if is_instance_valid(item):
			var id := item.item_id
			_overlapping_items.remove_at(i)
			item.queue_free()
			return id
	return &""

func _on_body_entered(body: Node3D) -> void:
	if body is PhysicsItem:
		_overlapping_items.append(body)

func _on_body_exited(body: Node3D) -> void:
	if body is PhysicsItem:
		_overlapping_items.erase(body)
