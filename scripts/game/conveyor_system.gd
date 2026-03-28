class_name ConveyorSystem
extends Node

var conveyors: Dictionary = {} # Vector2i -> ConveyorBelt

# Per-conveyor round-robin for input direction fairness
var _pull_rr: Dictionary = {} # Vector2i -> RoundRobin

func register_conveyor(conv) -> void:
	conveyors[conv.grid_pos] = conv
	_pull_rr[conv.grid_pos] = RoundRobin.new()

func unregister_conveyor(pos: Vector2i) -> void:
	conveyors.erase(pos)
	_pull_rr.erase(pos)

func _physics_process(delta: float) -> void:
	# First pass: advance all items (per-conveyor speed from traverse_time)
	for pos in conveyors:
		var conv = conveyors[pos]
		conv.update_items(delta, 1.0 / conv.traverse_time)

	# Second pass: pull-based transfers from ANY output provider (round-robin)
	for pos in conveyors:
		var conv = conveyors[pos]
		if not conv.can_accept():
			continue

		var rr: RoundRobin = _pull_rr[pos]
		while conv.can_accept():
			var pulled := false
			var start: int = rr.index % 4
			for i in range(4):
				var dir_idx: int = (start + i) % 4
				var result = GameManager.pull_item(pos, dir_idx)
				if not result.is_empty():
					conv.place_item(result.id, result.entry_from, result.get("entry_dist", 0.5))
					rr.advance_past(dir_idx)
					pulled = true
					break
			if not pulled:
				break

	# Third pass: clamp items that couldn't transfer (end of chain or blocked)
	for pos in conveyors:
		var conv = conveyors[pos]
		if conv.buffer.is_empty():
			continue
		var front = conv.get_front_item()
		if front.progress > 1.0:
			front.progress = 1.0

	# Fourth pass: pick up ground items sitting on conveyors
	_pickup_ground_items()

const TILE_SIZE := 32

func _pickup_ground_items() -> void:
	var ground_items := get_tree().get_nodes_in_group("ground_items")
	if ground_items.is_empty():
		return
	for item in ground_items:
		if not is_instance_valid(item) or item.quantity <= 0:
			continue
		var grid_pos := Vector2i(floori(item.position.x / TILE_SIZE), floori(item.position.y / TILE_SIZE))
		if not conveyors.has(grid_pos):
			continue
		var conv = conveyors[grid_pos]
		while conv.can_accept() and item.quantity > 0:
			conv.place_item(item.item_id)
			item.quantity -= 1
		if item.quantity <= 0:
			item.queue_free()
