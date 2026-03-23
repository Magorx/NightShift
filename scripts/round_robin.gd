class_name RoundRobin
extends RefCounted

## Reusable round-robin iterator.
## Tracks a rotating index across calls so successive consumers
## are served in fair order.

var index: int = 0

## Returns the current index in [0, count) and advances past it.
func next(count: int) -> int:
	if count <= 0:
		return 0
	var result: int = index % count
	index = result + 1
	return result

## Advance so the next call to next() starts after `past`.
func advance_past(past: int) -> void:
	index = past + 1
