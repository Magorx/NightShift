extends "simulation_base.gd"

func run_simulation() -> void:
	# Test: Drill -> conveyors -> smelter -> output conveyor -> sink
	# Night Shift recipes need 2 inputs, so we feed pyromite + crystalline
	#
	# Layout (default rotation = right):
	#   Drill A at (10,10) on pyromite deposit, outputs right
	#   Drill B at (10,9) on crystalline deposit, outputs right
	#   Conveyors feeding both into smelter anchor at (14,10)
	#   Smelter shape: (14,9),(15,9),(14,10),(14,11),(15,11)
	#   Output gap: (15,10) → conveyor → sink

	# Place deposits and drills
	sim_add_deposit(Vector2i(10, 10), &"pyromite")
	sim_add_deposit(Vector2i(10, 9), &"crystalline")
	var result = sim_place_building(&"drill", Vector2i(10, 10), 0)
	sim_assert(result != null, "Drill placed on pyromite deposit")
	sim_place_building(&"drill", Vector2i(10, 9), 0)

	# Conveyor chains to smelter input
	for x in range(11, 14):
		sim_place_building(&"conveyor", Vector2i(x, 10), 0)
		sim_place_building(&"conveyor", Vector2i(x, 9), 0)

	# Place smelter — anchor (input cell) at (14,10)
	result = sim_place_building(&"smelter", Vector2i(14, 10), 0)
	sim_assert(result != null, "Smelter placed at anchor (14,10)")

	# Verify smelter shape cells are occupied
	sim_assert(GameManager.get_building_at(Vector2i(14, 9)) != null, "Smelter cell (14,9) occupied")
	sim_assert(GameManager.get_building_at(Vector2i(15, 9)) != null, "Smelter cell (15,9) occupied")
	sim_assert(GameManager.get_building_at(Vector2i(14, 10)) != null, "Smelter cell (14,10) occupied")
	sim_assert(GameManager.get_building_at(Vector2i(14, 11)) != null, "Smelter cell (14,11) occupied")
	sim_assert(GameManager.get_building_at(Vector2i(15, 11)) != null, "Smelter cell (15,11) occupied")
	# Output gap should be free
	sim_assert(GameManager.get_building_at(Vector2i(15, 10)) == null, "Output gap (15,10) is free")

	# Place conveyor in the output gap and onward to sink
	sim_place_building(&"conveyor", Vector2i(15, 10), 0)
	sim_place_building(&"conveyor", Vector2i(16, 10), 0)
	sim_place_building(&"sink", Vector2i(17, 10), 0)

	# Verify converter logic is configured
	var smelter = GameManager.get_building_at(Vector2i(14, 10))
	var conv_logic = smelter.find_child("ConverterLogic", true, false) if smelter else null
	sim_assert(conv_logic != null, "Smelter has ConverterLogic")
	sim_assert(conv_logic.recipes.size() > 0, "Smelter has recipes loaded (%d)" % (conv_logic.recipes.size() if conv_logic else 0))

	# Run for 25 seconds — drills produce every 2s, smelter crafts in 3s
	# Expected: steam_burst items delivered to sink
	await sim_advance_seconds(25)

	# Check sink consumed items
	var sink_building = GameManager.get_building_at(Vector2i(17, 10))
	var sink_logic = sink_building.find_child("SinkLogic", true, false) if sink_building else null
	var consumed: int = sink_logic.items_consumed if sink_logic else 0
	sim_assert(consumed > 0, "Sink received combo items from smelter chain (got %d)" % consumed)

	# Test 2: Manual item spawn to verify converter pulls from two input paths
	# Place a standalone smelter — anchor at (30,10)
	# Feed pyromite from left via (29,10) and crystalline from above via (29,9)→(30,9)
	sim_place_building(&"smelter", Vector2i(30, 10), 0)
	sim_place_building(&"conveyor", Vector2i(29, 10), 0)  # pyromite → smelter input (30,10)
	sim_place_building(&"conveyor", Vector2i(29, 9), 0)   # crystalline → smelter input (30,9)
	sim_place_building(&"conveyor", Vector2i(31, 10), 0)  # output gap conveyor
	sim_place_building(&"conveyor", Vector2i(32, 10), 0)
	sim_place_building(&"sink", Vector2i(33, 10), 0)

	# Spawn each input on its own conveyor
	sim_spawn_item_on_conveyor(Vector2i(29, 10), &"pyromite")
	sim_spawn_item_on_conveyor(Vector2i(29, 9), &"crystalline")
	await sim_advance_seconds(10)

	var sink2 = GameManager.get_building_at(Vector2i(33, 10))
	var sink2_logic = sink2.find_child("SinkLogic", true, false) if sink2 else null
	var consumed2: int = sink2_logic.items_consumed if sink2_logic else 0
	sim_assert(consumed2 > 0, "Manual spawn: sink received combo item (got %d)" % consumed2)

	sim_finish()
