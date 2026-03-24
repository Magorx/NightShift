extends "res://tests/simulation/simulation_base.gd"

func run_simulation() -> void:
	# === Test 1: Basic pass-through — item enters from left, exits right ===
	# Layout:
	#   conveyor(8,10)-> conveyor(9,10)-> JUNCTION(10,10) conveyor(11,10)-> conveyor(12,10)->

	sim_place_building(&"conveyor", Vector2i(8, 10), 0)
	sim_place_building(&"conveyor", Vector2i(9, 10), 0)
	sim_place_building(&"junction", Vector2i(10, 10), 0)
	sim_place_building(&"conveyor", Vector2i(11, 10), 0)
	sim_place_building(&"conveyor", Vector2i(12, 10), 0)

	var jnc_building = sim_get_building_at(Vector2i(10, 10))
	sim_assert(jnc_building != null, "Junction placed at (10,10)")
	sim_assert(jnc_building.has_meta("junction"), "Building has junction meta")

	sim_spawn_item_on_conveyor(Vector2i(8, 10), &"iron_ore")
	await sim_advance_seconds(6.0)

	# Item should have passed through to the right side
	var conv_right_end = sim_get_conveyor_at(Vector2i(12, 10))
	var conv_right_mid = sim_get_conveyor_at(Vector2i(11, 10))
	var right_count: int = 0
	if conv_right_end:
		right_count += conv_right_end.buffer.size()
	if conv_right_mid:
		right_count += conv_right_mid.buffer.size()
	sim_assert(right_count == 1, "Item passed through junction to the right (got %d)" % right_count)

	# === Test 2: No output at opposite side — item should NOT be accepted ===
	GameManager.clear_all()
	await sim_advance_ticks(2)

	# Conveyor pointing right into junction, but only output is downward (not opposite)
	sim_place_building(&"conveyor", Vector2i(5, 5), 0) # points right
	sim_place_building(&"junction", Vector2i(6, 5), 0)
	sim_place_building(&"conveyor", Vector2i(6, 6), 1) # points down (not opposite of left input)

	sim_spawn_item_on_conveyor(Vector2i(5, 5), &"iron_ore")
	await sim_advance_seconds(3.0)

	# Item should still be on the input conveyor — junction refused it
	var conv_input = sim_get_conveyor_at(Vector2i(5, 5))
	sim_assert(conv_input.has_item(), "Item stayed on input conveyor (no opposite output)")

	# Now add the correct opposite output (to the left of junction = pos 7,5 pointing right)
	# Actually: input is from left (dir_idx=2), opposite is right (dir_idx=0), so output at (7,5)
	sim_place_building(&"conveyor", Vector2i(7, 5), 0)
	await sim_advance_seconds(3.0)

	sim_assert(not conv_input.has_item(), "Item accepted after opposite output appeared")
	var conv_output = sim_get_conveyor_at(Vector2i(7, 5))
	sim_assert(conv_output.has_item(), "Item arrived at opposite output")

	# === Test 3: Crossing paths — two streams cross without mixing ===
	GameManager.clear_all()
	await sim_advance_ticks(2)

	# Horizontal stream: left to right through junction at (10,10)
	sim_place_building(&"conveyor", Vector2i(9, 10), 0) # points right
	sim_place_building(&"junction", Vector2i(10, 10), 0)
	sim_place_building(&"conveyor", Vector2i(11, 10), 0) # points right

	# Vertical stream: top to bottom through same junction
	sim_place_building(&"conveyor", Vector2i(10, 9), 1) # points down
	sim_place_building(&"conveyor", Vector2i(10, 11), 1) # points down

	# Spawn items on both streams
	sim_spawn_item_on_conveyor(Vector2i(9, 10), &"iron_ore")
	sim_spawn_item_on_conveyor(Vector2i(10, 9), &"iron_ore")
	await sim_advance_seconds(5.0)

	# Horizontal item should be on the right output
	var h_out = sim_get_conveyor_at(Vector2i(11, 10))
	sim_assert(h_out.has_item(), "Horizontal item crossed junction to the right")

	# Vertical item should be on the bottom output
	var v_out = sim_get_conveyor_at(Vector2i(10, 11))
	sim_assert(v_out.has_item(), "Vertical item crossed junction downward")

	# === Test 4: Items wait when output is removed ===
	GameManager.clear_all()
	await sim_advance_ticks(2)

	sim_place_building(&"conveyor", Vector2i(5, 10), 0)
	sim_place_building(&"junction", Vector2i(6, 10), 0)
	sim_place_building(&"conveyor", Vector2i(7, 10), 0)

	sim_spawn_item_on_conveyor(Vector2i(5, 10), &"iron_ore")
	await sim_advance_seconds(4.0)

	# Item should have passed through
	var out_conv = sim_get_conveyor_at(Vector2i(7, 10))
	sim_assert(out_conv.has_item(), "Item passed through before output removal")

	# Spawn another item, then remove output while it's in transit
	sim_spawn_item_on_conveyor(Vector2i(5, 10), &"iron_ore")
	await sim_advance_seconds(1.5) # let it get pulled into junction
	GameManager.remove_building(Vector2i(7, 10)) # remove output
	await sim_advance_seconds(3.0)

	# Item should be stuck in the junction buffer
	var jnc = sim_get_building_at(Vector2i(6, 10)).get_meta("junction")
	var h_buf: int = jnc.buffers[0].size()
	var v_buf: int = jnc.buffers[1].size()
	sim_assert(h_buf + v_buf > 0, "Item waiting in junction after output removed")

	# Re-add the output
	sim_place_building(&"conveyor", Vector2i(7, 10), 0)
	await sim_advance_seconds(2.0)

	# Item should have been pushed out
	out_conv = sim_get_conveyor_at(Vector2i(7, 10))
	sim_assert(out_conv.has_item(), "Item pushed out after output restored")
	h_buf = jnc.buffers[0].size()
	v_buf = jnc.buffers[1].size()
	sim_assert(h_buf + v_buf == 0, "Junction buffer empty after output restored")

	# === Test 5: Axis direction reversal — stranded item reverses, no overflow ===
	GameManager.clear_all()
	await sim_advance_ticks(2)

	# Item enters from left, heading right
	sim_place_building(&"conveyor", Vector2i(5, 10), 0) # points right (input)
	sim_place_building(&"junction", Vector2i(6, 10), 0)
	sim_place_building(&"conveyor", Vector2i(7, 10), 0) # points right (output)

	sim_spawn_item_on_conveyor(Vector2i(5, 10), &"iron_ore")
	await sim_advance_seconds(1.5) # let it get pulled into junction

	# Remove both input and output
	GameManager.remove_building(Vector2i(7, 10))
	GameManager.remove_building(Vector2i(5, 10))
	await sim_advance_ticks(2)

	jnc = sim_get_building_at(Vector2i(6, 10)).get_meta("junction")
	sim_assert(jnc.buffers[0].size() == 1, "Item stranded in horizontal buffer")

	# Reverse the axis: new input from right, output to left
	sim_place_building(&"conveyor", Vector2i(7, 10), 2) # points left (new input)
	sim_place_building(&"conveyor", Vector2i(5, 10), 2) # points left (new output)

	# Spawn 2 items on the new input
	sim_spawn_item_on_conveyor(Vector2i(7, 10), &"iron_ore")
	await sim_advance_seconds(0.5)
	sim_spawn_item_on_conveyor(Vector2i(7, 10), &"iron_ore")
	await sim_advance_seconds(5.0)

	# Buffer should never have exceeded capacity — all items should be on the output
	sim_assert(jnc.buffers[0].size() <= 2, "Horizontal buffer never exceeded capacity (got %d)" % jnc.buffers[0].size())
	var left_out = sim_get_conveyor_at(Vector2i(5, 10))
	var total_out: int = left_out.buffer.size() if left_out else 0
	sim_assert(total_out > 0, "Items arrived at reversed output")

	sim_finish()
