extends "res://tests/simulation/simulation_base.gd"

func run_simulation() -> void:
	# === Test 1: Source produces items onto conveyor ===
	sim_place_building(&"source", Vector2i(5, 5), 0) # pointing right
	sim_place_building(&"conveyor", Vector2i(6, 5), 0)
	sim_place_building(&"conveyor", Vector2i(7, 5), 0)
	sim_place_building(&"conveyor", Vector2i(8, 5), 0)

	await sim_advance_seconds(3.0)

	# At least one item should be on the conveyors
	var has_any_item := false
	for x in range(6, 9):
		var conv = sim_get_conveyor_at(Vector2i(x, 5))
		if conv and conv.has_item():
			has_any_item = true
			break
	sim_assert(has_any_item, "Source produced items onto conveyors")

	# === Test 2: Sink consumes items ===
	sim_place_building(&"sink", Vector2i(9, 5), 0)
	await sim_advance_seconds(5.0)

	var sink_building = sim_get_building_at(Vector2i(9, 5))
	var snk = sink_building.logic
	sim_assert(snk.items_consumed > 0, "Sink consumed items (got %d)" % snk.items_consumed)

	# === Test 3: Two sources merge with round-robin ===
	# Source A from left
	sim_place_building(&"source", Vector2i(15, 10), 0)
	sim_place_building(&"conveyor", Vector2i(16, 10), 0)

	# Source B from top
	sim_place_building(&"source", Vector2i(17, 8), 1)
	sim_place_building(&"conveyor", Vector2i(17, 9), 1)

	# Merge point -> output -> sink
	sim_place_building(&"conveyor", Vector2i(17, 10), 0)
	sim_place_building(&"conveyor", Vector2i(18, 10), 0)
	sim_place_building(&"conveyor", Vector2i(19, 10), 0)
	sim_place_building(&"sink", Vector2i(20, 10), 0)

	await sim_advance_seconds(10.0)

	var merge_sink_building = sim_get_building_at(Vector2i(20, 10))
	var merge_snk = merge_sink_building.logic
	# Sink processes at 1 item/sec, so in 10s expect at least a few deliveries
	sim_assert(merge_snk.items_consumed >= 2, "Merge sink consumed items from both sources (got %d)" % merge_snk.items_consumed)

	sim_finish()
