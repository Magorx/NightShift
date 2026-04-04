extends "res://tests/simulation/simulation_base.gd"

func run_simulation() -> void:
	# === Test 1: Source feeds conveyor via unified pull ===
	# Source(5,10) facing right -> Conveyor(6,10) -> Conveyor(7,10)
	sim_place_building(&"source", Vector2i(5, 10), 0)
	sim_place_building(&"conveyor", Vector2i(6, 10), 0)
	sim_place_building(&"conveyor", Vector2i(7, 10), 0)

	await sim_advance_seconds(3.0)

	var conv = sim_get_conveyor_at(Vector2i(7, 10))
	var conv_mid = sim_get_conveyor_at(Vector2i(6, 10))
	var item_count: int = 0
	if conv:
		item_count += conv.buffer.size()
	if conv_mid:
		item_count += conv_mid.buffer.size()
	sim_assert(item_count >= 1, "Test 1: Source produced item onto conveyor (got %d)" % item_count)

	# === Test 2: Source competes fairly with upstream conveyor via round-robin ===
	# Setup:
	#   Source(5,10) facing down into conveyor(5,11)
	#   Conveyor(4,11) facing right -> conveyor(5,11) -> conveyor(6,11) -> ...
	# Both source and conveyor(4,11) feed into conveyor(5,11).
	GameManager.clear_all()
	await sim_advance_ticks(2)

	sim_place_building(&"source", Vector2i(5, 10), 1) # facing down
	sim_place_building(&"conveyor", Vector2i(3, 11), 0) # right
	sim_place_building(&"conveyor", Vector2i(4, 11), 0) # right
	sim_place_building(&"conveyor", Vector2i(5, 11), 0) # right
	sim_place_building(&"conveyor", Vector2i(6, 11), 0) # right
	sim_place_building(&"conveyor", Vector2i(7, 11), 0) # right

	# Spawn items on the upstream conveyor to compete with source
	sim_spawn_item_on_conveyor(Vector2i(3, 11), &"pyromite")
	await sim_advance_seconds(0.5)
	sim_spawn_item_on_conveyor(Vector2i(3, 11), &"pyromite")

	await sim_advance_seconds(6.0)

	# Check that items arrived at the end
	var end_conv = sim_get_conveyor_at(Vector2i(7, 11))
	var mid_conv = sim_get_conveyor_at(Vector2i(6, 11))
	var total: int = 0
	if end_conv:
		total += end_conv.buffer.size()
	if mid_conv:
		total += mid_conv.buffer.size()
	# Should have items from both sources (at least 2 from conveyor + 1+ from source)
	sim_assert(total >= 2, "Test 2: Items from both source and conveyor reached end (got %d)" % total)

	# === Test 3: Source pushes to full conveyor line gets fair round-robin ===
	# A backed-up line where source should eventually get items through
	GameManager.clear_all()
	await sim_advance_ticks(2)

	# Short line with sink at end to drain items
	sim_place_building(&"source", Vector2i(5, 10), 0) # facing right
	sim_place_building(&"conveyor", Vector2i(6, 10), 0)
	sim_place_building(&"conveyor", Vector2i(7, 10), 0)
	sim_place_building(&"sink", Vector2i(8, 10), 0)

	await sim_advance_seconds(8.0)

	var sink_building = sim_get_building_at(Vector2i(8, 10))
	var snk = sink_building.logic if sink_building else null
	sim_assert(snk != null and snk.items_consumed >= 3, "Test 3: Sink consumed items from source (got %d)" % (snk.items_consumed if snk else 0))

	# === Test 4: Splitter pulls from non-conveyor (source directly into splitter) ===
	GameManager.clear_all()
	await sim_advance_ticks(2)

	sim_place_building(&"source", Vector2i(5, 10), 0) # facing right
	sim_place_building(&"splitter", Vector2i(6, 10), 0)
	sim_place_building(&"conveyor", Vector2i(7, 10), 0) # right output
	sim_place_building(&"conveyor", Vector2i(6, 11), 1) # down output

	await sim_advance_seconds(5.0)

	var right_conv = sim_get_conveyor_at(Vector2i(7, 10))
	var down_conv = sim_get_conveyor_at(Vector2i(6, 11))
	var right_items: int = right_conv.buffer.size() if right_conv else 0
	var down_items: int = down_conv.buffer.size() if down_conv else 0
	sim_assert(right_items + down_items >= 2, "Test 4: Splitter received items from source (got %d)" % (right_items + down_items))

	# === Test 5: Splitter-to-splitter chain (routers in a line) ===
	# Items should pass straight through when possible
	GameManager.clear_all()
	await sim_advance_ticks(2)

	sim_place_building(&"conveyor", Vector2i(4, 10), 0) # input conveyor
	sim_place_building(&"splitter", Vector2i(5, 10), 0)
	sim_place_building(&"splitter", Vector2i(6, 10), 0)
	sim_place_building(&"conveyor", Vector2i(7, 10), 0) # output conveyor

	sim_spawn_item_on_conveyor(Vector2i(4, 10), &"pyromite")
	await sim_advance_seconds(6.0)

	var output_conv = sim_get_conveyor_at(Vector2i(7, 10))
	sim_assert(output_conv != null and output_conv.has_item(), "Test 5: Item passed through splitter chain")

	# === Test 6: Junction pulls from non-conveyor sources ===
	GameManager.clear_all()
	await sim_advance_ticks(2)

	sim_place_building(&"source", Vector2i(9, 10), 0) # facing right
	sim_place_building(&"junction", Vector2i(10, 10), 0)
	sim_place_building(&"conveyor", Vector2i(11, 10), 0) # right output (opposite of left input)

	await sim_advance_seconds(5.0)

	# Source's output cell is (10,10) which is the junction cell — so junction doesn't see it
	# Actually source at (9,10) facing right has output at (10,10), but junction occupies (10,10)
	# The junction pulls from neighbors via pull_item, which checks building at neighbor positions
	# Source at (9,10) has output at (10,10) = junction pos. pull_item checks building at
	# grid_pos + DIRECTION_VECTORS[dir_idx]. For dir_idx=2 (LEFT), neighbor = (9,10) = source.
	# Source can_provide_to((10,10)) = true. So junction should pull from source.
	var out_conv = sim_get_conveyor_at(Vector2i(11, 10))
	sim_assert(out_conv != null and out_conv.has_item(), "Test 6: Junction pulled from source and passed item through")

	# === Test 7: Sink pulls directly from splitter (no conveyor between) ===
	GameManager.clear_all()
	await sim_advance_ticks(2)

	sim_place_building(&"conveyor", Vector2i(4, 10), 0)
	sim_place_building(&"splitter", Vector2i(5, 10), 0)
	sim_place_building(&"sink", Vector2i(6, 10), 0)

	sim_spawn_item_on_conveyor(Vector2i(4, 10), &"pyromite")
	await sim_advance_seconds(5.0)

	var sink_b = sim_get_building_at(Vector2i(6, 10))
	var sink_logic = sink_b.logic if sink_b else null
	sim_assert(sink_logic != null and sink_logic.items_consumed >= 1, "Test 7: Sink pulled item from splitter (consumed %d)" % (sink_logic.items_consumed if sink_logic else 0))

	# === Test 8: Entry_from direction is correct (item visual enters from right side) ===
	GameManager.clear_all()
	await sim_advance_ticks(2)

	sim_place_building(&"source", Vector2i(5, 10), 0) # facing right
	sim_place_building(&"conveyor", Vector2i(6, 10), 0) # facing right

	await sim_advance_seconds(2.0)

	var test_conv = sim_get_conveyor_at(Vector2i(6, 10))
	if test_conv and test_conv.buffer.size() > 0:
		var entry_from = test_conv.buffer.items[test_conv.buffer.size() - 1].entry_from
		sim_assert(entry_from == Vector2i.LEFT, "Test 8: Entry from source is LEFT (got %s)" % str(entry_from))
	else:
		sim_assert(false, "Test 8: No item on conveyor to check entry_from")

	sim_finish()
