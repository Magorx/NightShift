extends Node

const MOVE_SPEED := 1.0 # tiles per second
const ALL_DIRS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var conveyors: Dictionary = {} # Vector2i -> ConveyorBelt

# Round-robin state per conveyor: tracks which input direction was last pulled from
var _last_pull_index: Dictionary = {} # Vector2i -> int

func register_conveyor(conv) -> void:
	conveyors[conv.grid_pos] = conv
	_last_pull_index[conv.grid_pos] = 0

func unregister_conveyor(pos: Vector2i) -> void:
	conveyors.erase(pos)
	_last_pull_index.erase(pos)

func _physics_process(delta: float) -> void:
	# First pass: advance all items
	for pos in conveyors:
		conveyors[pos].update_items(delta, MOVE_SPEED)

	# Second pass: pull-based transfers with round-robin
	for pos in conveyors:
		var conv = conveyors[pos]
		if not conv.can_accept():
			continue

		# Find all neighbors that want to push into this conveyor
		var candidates: Array = [] # Array of ConveyorBelt
		for dir in ALL_DIRS:
			var neighbor_pos = pos + dir
			if not conveyors.has(neighbor_pos):
				continue
			var neighbor = conveyors[neighbor_pos]
			# Neighbor must point toward us
			if neighbor.get_next_pos() != pos:
				continue
			# Neighbor must have a front item ready to transfer
			if neighbor.items.size() == 0:
				continue
			var front = neighbor.get_front_item()
			if front.progress >= 1.0:
				candidates.append(neighbor)

		if candidates.size() == 0:
			continue

		# Round-robin: pick the next candidate after the last one used
		var pull_idx = _last_pull_index.get(pos, 0) % candidates.size()
		# Try starting from pull_idx, wrapping around
		for i in range(candidates.size()):
			var idx = (pull_idx + i) % candidates.size()
			var source = candidates[idx]
			if conv.can_accept():
				var item_data = source.pop_front_item()
				var entry_from = source.grid_pos - pos
				conv.place_item(item_data.id, entry_from)
				_last_pull_index[pos] = (idx + 1)
				break

	# Third pass: clamp items that couldn't transfer (end of chain or blocked)
	for pos in conveyors:
		var conv = conveyors[pos]
		if conv.items.size() == 0:
			continue
		var front = conv.get_front_item()
		if front.progress > 1.0:
			front.progress = 1.0
