extends "simulation_base.gd"

func run_simulation() -> void:
	# Test: Drill -> conveyors -> smelter -> output conveyor -> sink
	# Night Shift recipes need 2 inputs, so we feed pyromite + crystalline
	#
	# Layout (default rotation = right):
	#   Drill A at (10,10) on pyromite deposit, outputs right
	#   Drill B at (10,11) on crystalline deposit, outputs right
	#   Conveyors feeding both into smelter inputs from the left
	#   Smelter anchor at (14,10), L-shape:
	#     (14,10) (15,10)
	#     (14,11) [gap 15,11] ← output
	#   Output gap (15,11) → conveyor → sink

	# Place deposits and drills
	sim_add_deposit(Vector2i(10, 10), &"pyromite")
	sim_add_deposit(Vector2i(10, 11), &"crystalline")
	var result = sim_place_building(&"drill", Vector2i(10, 10), 0)
	sim_assert(result != null, "Drill placed on pyromite deposit")
	sim_place_building(&"drill", Vector2i(10, 11), 0)

	# Conveyor chains to smelter inputs (one chain per input resource)
	for x in range(11, 14):
		sim_place_building(&"conveyor", Vector2i(x, 10), 0)
		sim_place_building(&"conveyor", Vector2i(x, 11), 0)

	# Place smelter — anchor at (14,10)
	result = sim_place_building(&"smelter", Vector2i(14, 10), 0)
	sim_assert(result != null, "Smelter placed at anchor (14,10)")

	# Verify smelter shape cells are occupied (2x2 L-shape, 3 cells)
	sim_assert(GameManager.get_building_at(Vector2i(14, 10)) != null, "Smelter cell (14,10) occupied")
	sim_assert(GameManager.get_building_at(Vector2i(15, 10)) != null, "Smelter cell (15,10) occupied")
	sim_assert(GameManager.get_building_at(Vector2i(14, 11)) != null, "Smelter cell (14,11) occupied")
	# Output gap should be free
	sim_assert(GameManager.get_building_at(Vector2i(15, 11)) == null, "Output gap (15,11) is free")

	# Place conveyor in the output gap and onward to sink
	sim_place_building(&"conveyor", Vector2i(15, 11), 0)
	sim_place_building(&"conveyor", Vector2i(16, 11), 0)
	sim_place_building(&"sink", Vector2i(17, 11), 0)

	# Verify converter logic is configured
	var smelter = GameManager.get_building_at(Vector2i(14, 10))
	var conv_logic = smelter.find_child("ConverterLogic", true, false) if smelter else null
	sim_assert(conv_logic != null, "Smelter has ConverterLogic")
	sim_assert(conv_logic.recipes.size() > 0, "Smelter has recipes loaded (%d)" % (conv_logic.recipes.size() if conv_logic else 0))

	# Run for 30 seconds — drills produce every 2s, smelter crafts in 3s
	# Expected: combo items delivered to sink
	await sim_advance_seconds(30)

	# Check sink consumed items
	var sink_building = GameManager.get_building_at(Vector2i(17, 11))
	var sink_logic = sink_building.find_child("SinkLogic", true, false) if sink_building else null
	var consumed: int = sink_logic.items_consumed if sink_logic else 0
	sim_assert(consumed > 0, "Sink received combo items from smelter chain (got %d)" % consumed)

	# Test 2: Manual item spawn to verify converter pulls from two input paths
	# Standalone smelter — anchor at (30,10), L-shape:
	#   (30,10) (31,10)
	#   (30,11) [gap 31,11]
	sim_place_building(&"smelter", Vector2i(30, 10), 0)
	sim_place_building(&"conveyor", Vector2i(29, 10), 0)  # pyromite feed
	sim_place_building(&"conveyor", Vector2i(29, 11), 0)  # crystalline feed
	sim_place_building(&"conveyor", Vector2i(31, 11), 0)  # output gap conveyor
	sim_place_building(&"conveyor", Vector2i(32, 11), 0)
	sim_place_building(&"sink", Vector2i(33, 11), 0)

	# Spawn each input on its own conveyor
	sim_spawn_item_on_conveyor(Vector2i(29, 10), &"pyromite")
	sim_spawn_item_on_conveyor(Vector2i(29, 11), &"crystalline")
	await sim_advance_seconds(10)

	var sink2 = GameManager.get_building_at(Vector2i(33, 11))
	var sink2_logic = sink2.find_child("SinkLogic", true, false) if sink2 else null
	var consumed2: int = sink2_logic.items_consumed if sink2_logic else 0
	sim_assert(consumed2 > 0, "Manual spawn: sink received combo item (got %d)" % consumed2)

	sim_finish()
