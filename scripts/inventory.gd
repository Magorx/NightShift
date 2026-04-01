class_name Inventory
extends RefCounted

## Per-item storage with individual capacity limits.
## Items without a registered capacity cannot be stored.

var _items: Dictionary = {}       # StringName -> int
var _capacities: Dictionary = {}  # StringName -> int

## Register an item type with its max capacity.
func set_capacity(item_id: StringName, max_count: int) -> void:
	_capacities[item_id] = max_count

func get_capacity(item_id: StringName) -> int:
	return _capacities.get(item_id, 0)

func get_count(item_id: StringName) -> int:
	return _items.get(item_id, 0)

func has_space(item_id: StringName, amount: int = 1) -> bool:
	if not _capacities.has(item_id):
		return false
	return get_count(item_id) + amount <= _capacities[item_id]

## Add items. Returns true if there was enough space.
func add(item_id: StringName, amount: int = 1) -> bool:
	if not has_space(item_id, amount):
		return false
	_items[item_id] = get_count(item_id) + amount
	return true

## Remove items. Returns true if there were enough items.
func remove(item_id: StringName, amount: int = 1) -> bool:
	if get_count(item_id) < amount:
		return false
	_items[item_id] -= amount
	if _items[item_id] <= 0:
		_items.erase(item_id)
	return true

func has(item_id: StringName, amount: int = 1) -> bool:
	return get_count(item_id) >= amount

## Returns true if any items are stored.
func is_empty() -> bool:
	return _items.is_empty()

## Returns all stored item IDs.
func get_item_ids() -> Array:
	return _items.keys()

## Serialize inventory contents to a dictionary (item_id_string -> count).
func serialize() -> Dictionary:
	var data := {}
	for iid in _items:
		if _items[iid] > 0:
			data[str(iid)] = _items[iid]
	return data

## Deserialize inventory contents from a dictionary. Validates item IDs and
## auto-creates capacity if not already registered.
func deserialize(data: Dictionary) -> void:
	for item_id_str in data:
		var iid := StringName(item_id_str)
		if not GameManager.is_valid_item_id(iid):
			GameLogger.warn("Inventory: skipped invalid item '%s'" % iid)
			continue
		var count: int = int(data[item_id_str])
		if get_capacity(iid) == 0:
			set_capacity(iid, count + 10)
		for i in count:
			add(iid)
