extends Node

const RoundRobin = preload("res://scripts/round_robin.gd")
const MOVE_SPEED := 1.0 # tiles per second
const ALL_DIRS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

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
	# First pass: advance all items
	for pos in conveyors:
		conveyors[pos].update_items(delta, MOVE_SPEED)

	# Second pass: pull-based transfers with round-robin over fixed 4 directions
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
				var neighbor_pos: Vector2i = pos + ALL_DIRS[dir_idx]
				if not conveyors.has(neighbor_pos):
					continue
				var neighbor = conveyors[neighbor_pos]
				if neighbor.get_next_pos() != pos:
					continue
				if neighbor.items.size() == 0:
					continue
				var front = neighbor.get_front_item()
				if front.progress < 1.0:
					continue
				var item_data = neighbor.pop_front_item()
				var entry_from = neighbor.grid_pos - pos
				conv.place_item(item_data.id, entry_from)
				rr.advance_past(dir_idx)
				pulled = true
				break
			if not pulled:
				break

	# Third pass: clamp items that couldn't transfer (end of chain or blocked)
	for pos in conveyors:
		var conv = conveyors[pos]
		if conv.items.size() == 0:
			continue
		var front = conv.get_front_item()
		if front.progress > 1.0:
			front.progress = 1.0
