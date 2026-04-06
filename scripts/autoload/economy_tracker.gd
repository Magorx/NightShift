extends Node

## Tracks item deliveries, currency, and creative mode.
## Extracted from GameManager to separate economy concerns.

signal item_delivered(item_id: StringName)

# Currency earned from sinks
var total_currency: int = 0

# Items delivered to sinks: item_id (StringName) -> count (int)
var items_delivered: Dictionary = {}

# Creative mode: all buildings are free to place
var creative_mode: bool = false

func record_delivery(item_id: StringName, value: int = 0) -> void:
	if not items_delivered.has(item_id):
		items_delivered[item_id] = 0
	items_delivered[item_id] += 1
	total_currency += value
	item_delivered.emit(item_id)

func clear() -> void:
	total_currency = 0
	items_delivered.clear()
