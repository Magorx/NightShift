class_name ItemBuffer
extends RefCounted

## A progress-based item buffer used by transport buildings (conveyors, tunnels,
## splitters, junctions). Items travel from progress 0.0 (entry) to 1.0 (exit).
##
## Each item is a Dictionary with at least: {id: StringName, progress: float, visual: Node2D}.
## Buildings may store extra keys (entry_from, from_dir_idx, output_dir_idx, etc.).

var items: Array = []
var capacity: int
var item_gap: float

func _init(p_capacity: int = 2) -> void:
	set_capacity(p_capacity)

func set_capacity(p_capacity: int) -> void:
	capacity = maxi(p_capacity, 1)
	item_gap = 1.0 / capacity

func size() -> int:
	return items.size()

func is_empty() -> bool:
	return items.is_empty()

func is_full() -> bool:
	return items.size() >= capacity

## Returns true if the buffer has room AND the newest item has traveled far enough.
func can_accept() -> bool:
	if is_full():
		return false
	if not items.is_empty() and items.back().progress < item_gap:
		return false
	return true

## Create an item with a visual and append it. Returns the item dict.
## Extra fields (entry_from, from_dir_idx, etc.) are merged into the item.
func add_item(item_id: StringName, extra: Dictionary = {}) -> Dictionary:
	var visual := create_visual(item_id)
	var item := {id = item_id, progress = 0.0, visual = visual}
	item.merge(extra)
	items.append(item)
	return item

## Peek at the front item (highest progress, index 0). Returns {} if empty.
func peek_front() -> Dictionary:
	if items.is_empty():
		return {}
	return items[0]

## Remove and return the front item, freeing its visual.
func pop_front() -> Dictionary:
	if items.is_empty():
		return {}
	var item: Dictionary = items[0]
	free_visual(item)
	items.remove_at(0)
	return item

## Advance items toward progress 1.0, clamping so items maintain item_gap spacing.
## Use for conveyors and tunnels where items queue behind each other.
func advance_clamped(delta: float, speed: float) -> void:
	for i in range(items.size()):
		var item = items[i]
		var max_progress := 1.0
		if i > 0:
			max_progress = items[i - 1].progress - item_gap
		item.progress = minf(item.progress + speed * delta, max_progress)

## Advance items toward progress 1.0 independently (no gap enforcement).
## Use for splitters and junctions where items travel to different outputs.
func advance_unclamped(delta: float, speed: float) -> void:
	for item in items:
		if item.progress < 1.0:
			item.progress = minf(item.progress + speed * delta, 1.0)

## Free all item visuals and clear the buffer.
func cleanup() -> void:
	for item in items:
		free_visual(item)
	items.clear()

## Create a colored item-dot visual and add it to the item layer.
func create_visual(item_id: StringName) -> Node2D:
	var visual := Node2D.new()
	var item_def = _get_item_def(item_id)
	var color := Color.WHITE
	if item_def:
		color = item_def.color
	visual.set_meta("color", color)
	visual.set_script(load("res://buildings/shared/item_visual.gd"))
	GameManager.item_layer.add_child(visual)
	return visual

## Free a single item's visual node.
func free_visual(item: Dictionary) -> void:
	if item.has("visual") and item.visual:
		item.visual.queue_free()

func _get_item_def(item_id: StringName):
	var path := "res://resources/items/%s.tres" % str(item_id)
	if ResourceLoader.exists(path):
		return load(path)
	return null
