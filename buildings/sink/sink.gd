class_name ItemSink
extends Node

const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid_pos: Vector2i
var items_consumed: int = 0
var _pull_index: int = 0

func _physics_process(_delta: float) -> void:
	# Keep pulling until nothing is ready
	var keep_pulling := true
	while keep_pulling:
		keep_pulling = false
		for i in range(4):
			var dir_idx = (_pull_index + i) % 4
			var neighbor_pos = grid_pos + DIRECTION_VECTORS[dir_idx]
			var conv = GameManager.get_conveyor_at(neighbor_pos)
			if conv and conv.get_next_pos() == grid_pos:
				while conv.items.size() > 0:
					var front = conv.get_front_item()
					if front.progress < 1.0:
						break
					conv.pop_front_item()
					items_consumed += 1
					keep_pulling = true
				if keep_pulling:
					_pull_index = (dir_idx + 1) % 4
					break
