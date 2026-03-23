extends "res://tests/simulation/simulation_base.gd"

func run_simulation() -> void:
	# Place a chain of 5 conveyors pointing right (rotation=0)
	for i in range(5):
		sim_place_building(&"conveyor", Vector2i(10 + i, 10), 0)

	# Verify conveyors were placed
	for i in range(5):
		var conv = sim_get_conveyor_at(Vector2i(10 + i, 10))
		sim_assert(conv != null, "Conveyor exists at (%d, 10)" % (10 + i))

	# Spawn an iron_ore item on the first conveyor
	var spawned = sim_spawn_item_on_conveyor(Vector2i(10, 10), &"iron_ore")
	sim_assert(spawned, "Item spawned on first conveyor")

	# Verify item is on first conveyor
	var conv0 = sim_get_conveyor_at(Vector2i(10, 10))
	sim_assert(conv0.has_item(), "First conveyor has item before transport")

	# Advance enough time for item to travel through all 5 conveyors
	await sim_advance_seconds(6.0)

	# Item should have reached the last conveyor and stopped there
	var conv_last = sim_get_conveyor_at(Vector2i(14, 10))
	sim_assert(conv_last.has_item(), "Item reached last conveyor")
	var front = conv_last.get_front_item()
	sim_assert(front.id == &"iron_ore", "Item is iron_ore")

	# First conveyor should be empty now
	conv0 = sim_get_conveyor_at(Vector2i(10, 10))
	sim_assert(not conv0.has_item(), "First conveyor is empty after transport")

	# Test blocking: spawn another item, it should stop behind the first
	sim_spawn_item_on_conveyor(Vector2i(10, 10), &"iron_ore")
	await sim_advance_seconds(6.0)

	# With max_items=2 the second item fits on the last conveyor behind the first
	sim_assert(conv_last.items.size() == 2, "Second item stopped behind first (blocked)")

	# Test side entry: place a downward conveyor and feed from the right chain
	# Conveyor at (15, 10) pointing down, fed by (14, 10) pointing right
	sim_place_building(&"conveyor", Vector2i(15, 10), 1) # pointing down
	sim_spawn_item_on_conveyor(Vector2i(10, 10), &"iron_ore")
	await sim_advance_seconds(8.0)

	var conv_down = sim_get_conveyor_at(Vector2i(15, 10))
	sim_assert(conv_down.has_item(), "Item transferred to side-entry conveyor")

	# Test removal: remove a conveyor mid-chain and verify items don't pass
	sim_remove_building(Vector2i(12, 10))
	sim_spawn_item_on_conveyor(Vector2i(10, 10), &"iron_ore")
	await sim_advance_seconds(4.0)

	var conv_before_gap = sim_get_conveyor_at(Vector2i(11, 10))
	sim_assert(conv_before_gap.has_item(), "Item stops at end of broken chain")

	sim_finish()
