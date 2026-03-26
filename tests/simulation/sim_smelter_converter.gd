extends "simulation_base.gd"

func run_simulation() -> void:
	# Test: Drill -> conveyors -> smelter -> output conveyor -> sink
	#
	# Layout (default rotation = right):
	#   Drill at (10,10) on iron deposit, outputs right
	#   Conveyors at (11,10), (12,10), (13,10) going right
	#   Smelter anchor at (14,10) — anchor is the input cell (0,1):
	#     Shape cells (anchor-relative): (0,-1),(1,-1),(0,0),(0,1),(1,1)
	#     World cells: (14,9),(15,9),(14,10),(14,11),(15,11)
	#     Input: (14,10) accepts from LEFT
	#     Output gap: (15,10) — conveyor placed here
	#   Conveyor at (15,10) going right (output gap)
	#   Conveyor at (16,10) going right
	#   Sink at (17,10)

	# Place drill on iron deposit
	sim_add_deposit(Vector2i(10, 10), &"iron_ore")
	var result = sim_place_building(&"drill", Vector2i(10, 10), 0)
	sim_assert(result != null, "Drill placed on iron deposit")

	# Conveyor chain to smelter input
	sim_place_building(&"conveyor", Vector2i(11, 10), 0)
	sim_place_building(&"conveyor", Vector2i(12, 10), 0)
	sim_place_building(&"conveyor", Vector2i(13, 10), 0)

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

	# Run for 20 seconds — drill produces iron_ore every 2s, smelter crafts in 3s
	# Expected: several iron plates delivered to sink
	await sim_advance_seconds(20)

	# Check sink consumed items
	var sink_building = GameManager.get_building_at(Vector2i(17, 10))
	var sink_logic = sink_building.find_child("SinkLogic", true, false) if sink_building else null
	var consumed: int = sink_logic.items_consumed if sink_logic else 0
	sim_assert(consumed > 0, "Sink received iron plates from smelter chain (got %d)" % consumed)

	# Test 2: Manual item spawn to verify converter pulls correctly
	# Place a standalone smelter — anchor at (30,10)
	sim_place_building(&"smelter", Vector2i(30, 10), 0)
	sim_place_building(&"conveyor", Vector2i(29, 10), 0)  # feeds into input from left
	sim_place_building(&"conveyor", Vector2i(31, 10), 0)  # output gap conveyor
	sim_place_building(&"conveyor", Vector2i(32, 10), 0)
	sim_place_building(&"sink", Vector2i(33, 10), 0)

	# Spawn iron ore directly on the input conveyor
	sim_spawn_item_on_conveyor(Vector2i(29, 10), &"iron_ore")
	await sim_advance_seconds(8)  # enough for item to reach smelter + craft time

	var sink2 = GameManager.get_building_at(Vector2i(33, 10))
	var sink2_logic = sink2.find_child("SinkLogic", true, false) if sink2 else null
	var consumed2: int = sink2_logic.items_consumed if sink2_logic else 0
	sim_assert(consumed2 > 0, "Manual spawn: sink received iron plate (got %d)" % consumed2)

	sim_finish()
