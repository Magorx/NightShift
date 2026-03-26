extends "res://tests/simulation/simulation_base.gd"

func run_simulation() -> void:
	# === Test 1: Basic split — 1 input, 2 outputs ===
	# Layout (all at row 10):
	#   conveyor(8,10)->  conveyor(9,10)->  SPLITTER(10,10)  conveyor(11,10)->  conveyor(12,10)->
	#                                            |
	#                                      conveyor(10,11) (pointing down)
	#                                            |
	#                                      conveyor(10,12) (pointing down)

	# Input chain: 2 conveyors pointing right into the splitter
	sim_place_building(&"conveyor", Vector2i(8, 10), 0)
	sim_place_building(&"conveyor", Vector2i(9, 10), 0)

	# Splitter at (10,10)
	sim_place_building(&"splitter", Vector2i(10, 10), 0)

	# Output chain right: 2 conveyors pointing right
	sim_place_building(&"conveyor", Vector2i(11, 10), 0)
	sim_place_building(&"conveyor", Vector2i(12, 10), 0)

	# Output chain down: 2 conveyors pointing down
	sim_place_building(&"conveyor", Vector2i(10, 11), 1)
	sim_place_building(&"conveyor", Vector2i(10, 12), 1)

	# Verify splitter was placed
	var spl_building = sim_get_building_at(Vector2i(10, 10))
	sim_assert(spl_building != null, "Splitter placed at (10,10)")
	sim_assert(spl_building.logic is SplitterLogic, "Building has SplitterLogic")

	# Spawn 2 items on the input chain
	sim_spawn_item_on_conveyor(Vector2i(8, 10), &"iron_ore")
	await sim_advance_seconds(1.5)
	sim_spawn_item_on_conveyor(Vector2i(8, 10), &"iron_ore")

	# Wait for items to travel through the splitter
	await sim_advance_seconds(5.0)

	# With round-robin, items should be split between the two outputs
	var conv_right_end = sim_get_conveyor_at(Vector2i(12, 10))
	var conv_down_end = sim_get_conveyor_at(Vector2i(10, 12))
	var right_count = conv_right_end.buffer.size() if conv_right_end else 0
	var down_count = conv_down_end.buffer.size() if conv_down_end else 0

	# Also check the intermediate conveyors
	var conv_right_mid = sim_get_conveyor_at(Vector2i(11, 10))
	var conv_down_mid = sim_get_conveyor_at(Vector2i(10, 11))
	right_count += conv_right_mid.buffer.size() if conv_right_mid else 0
	down_count += conv_down_mid.buffer.size() if conv_down_mid else 0

	var total_output = right_count + down_count
	sim_assert(total_output == 2, "Both items passed through splitter (got %d)" % total_output)
	sim_assert(right_count >= 1, "At least 1 item went right (got %d)" % right_count)
	sim_assert(down_count >= 1, "At least 1 item went down (got %d)" % down_count)

	# === Test 2: No U-turn — item should not go back where it came from ===
	# Clear and rebuild: input from left, only output is also left (should block)
	GameManager.clear_all()
	await sim_advance_ticks(2)

	# Conveyor pointing right into splitter
	sim_place_building(&"conveyor", Vector2i(5, 5), 0)
	sim_place_building(&"splitter", Vector2i(6, 5), 0)
	# No output conveyors — item should stay buffered in splitter

	sim_spawn_item_on_conveyor(Vector2i(5, 5), &"iron_ore")
	await sim_advance_seconds(3.0)

	# Input conveyor should be empty (splitter pulled the item)
	var conv_input = sim_get_conveyor_at(Vector2i(5, 5))
	sim_assert(not conv_input.has_item(), "Input conveyor is empty (item was pulled)")

	# Now add an output conveyor to the right (away from input)
	sim_place_building(&"conveyor", Vector2i(7, 5), 0)
	await sim_advance_seconds(2.0)

	# Item should have been pushed to the output
	var conv_output = sim_get_conveyor_at(Vector2i(7, 5))
	sim_assert(conv_output.has_item(), "Item pushed to output conveyor after it was placed")

	# === Test 3: Blocked output reroute ===
	# Two items heading for the same output should both advance to progress 1.0
	# independently and exit promptly when a free output appears. With the old
	# clamped advancement, item 2 would be stuck at progress 0.5 behind item 1.
	GameManager.clear_all()
	await sim_advance_ticks(2)

	# Input and splitter only — no outputs so items buffer internally
	sim_place_building(&"conveyor", Vector2i(9, 10), 0)
	sim_place_building(&"splitter", Vector2i(10, 10), 0)

	# Send 2 items in, staggered for entry-gap clearance
	sim_spawn_item_on_conveyor(Vector2i(9, 10), &"iron_ore")
	await sim_advance_seconds(0.7)
	sim_spawn_item_on_conveyor(Vector2i(9, 10), &"iron_ore")

	# Wait for both items to enter the splitter and advance
	await sim_advance_seconds(3.0)

	var spl3 = sim_get_building_at(Vector2i(10, 10))
	sim_assert(spl3.logic.buffer.size() == 2,
		"2 items buffered in splitter (got %d)" % spl3.logic.buffer.size())

	# With unclamped advancement, both items reach progress 1.0 independently
	var all_complete := true
	for item in spl3.logic.buffer.items:
		if item.progress < 1.0:
			all_complete = false
	sim_assert(all_complete, "Both items at progress 1.0 (unclamped advancement)")

	# Add an output — both should exit within a few ticks, not just the first
	sim_place_building(&"conveyor", Vector2i(10, 11), 1)
	sim_place_building(&"conveyor", Vector2i(10, 12), 1)

	await sim_advance_seconds(0.5)

	sim_assert(spl3.logic.buffer.size() == 0,
		"Both items exited promptly (%d stuck)" % spl3.logic.buffer.size())

	sim_finish()
