extends "simulation_base.gd"

func run_simulation() -> void:
	# Test 1: Drill can only be placed on a deposit
	# Use a far corner that won't have a deposit from world gen
	var empty_pos := Vector2i(99, 99)
	MapManager.deposits.erase(empty_pos)  # ensure no deposit
	var result = sim_place_building(&"drill", empty_pos, 0)
	sim_assert(result == null, "Drill cannot be placed on empty ground")

	# Test 2: Place drill on an iron deposit
	sim_add_deposit(Vector2i(10, 10), &"pyromite")
	result = sim_place_building(&"drill", Vector2i(10, 10), 0)
	sim_assert(result != null, "Drill placed on iron deposit at (10, 10)")

	# Test 3: Attach conveyors leading to a sink
	sim_place_building(&"conveyor", Vector2i(11, 10), 0)  # right
	sim_place_building(&"conveyor", Vector2i(12, 10), 0)
	sim_place_building(&"conveyor", Vector2i(13, 10), 0)
	sim_place_building(&"sink", Vector2i(14, 10), 0)

	# Let the drill produce for 10 seconds (should produce ~5 items at 1/2s rate)
	await sim_advance_seconds(10)

	# Check the sink consumed items
	var sink_building = BuildingRegistry.get_building_at(Vector2i(14, 10))
	var sink_logic = sink_building.find_child("SinkLogic", true, false) if sink_building else null
	var consumed: int = sink_logic.items_consumed if sink_logic else 0
	sim_assert(consumed > 0, "Sink consumed items from drill chain (got %d)" % consumed)

	# Test 4: Place drill on copper deposit (downward chain, turns right into sink)
	sim_add_deposit(Vector2i(30, 8), &"crystalline")
	sim_place_building(&"drill", Vector2i(30, 8), 1)  # direction: down
	sim_place_building(&"conveyor", Vector2i(30, 9), 1)
	sim_place_building(&"conveyor", Vector2i(30, 10), 0)  # turn right
	sim_place_building(&"sink", Vector2i(31, 10), 0)  # sink input faces left

	await sim_advance_seconds(15)

	var sink2 = BuildingRegistry.get_building_at(Vector2i(31, 10))
	var sink2_logic = sink2.find_child("SinkLogic", true, false) if sink2 else null
	var consumed2: int = sink2_logic.items_consumed if sink2_logic else 0
	sim_assert(consumed2 > 0, "Copper drill chain delivered items (got %d)" % consumed2)

	sim_finish()
