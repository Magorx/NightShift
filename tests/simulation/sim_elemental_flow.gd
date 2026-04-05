extends "simulation_base.gd"

func run_simulation() -> void:
	# Test: Two drills on different deposits feed a smelter → combo item → sink
	#
	# Layout (smelter anchor at (20,10), L-shape):
	#   Smelter cells: (20,10), (21,10), (20,11)
	#   Output gap: (21,11) → conveyor → sink
	#
	#   Drill A on pyromite at (10,10), outputs right
	#   Conveyors: (11,10)...(19,10) going right → feeds into smelter left edge
	#
	#   Drill B on crystalline at (10,11), outputs right
	#   Conveyors: (11,11)...(19,11) going right → feeds into smelter left edge
	#
	#   Output: conveyor at (21,11), (22,11) → sink at (23,11)

	# --- Place deposits ---
	sim_add_deposit(Vector2i(10, 10), &"pyromite")
	sim_add_deposit(Vector2i(10, 11), &"crystalline")

	# --- Place drills ---
	var drill_a = sim_place_building(&"drill", Vector2i(10, 10), 0)
	sim_assert(drill_a != null, "Drill A placed on pyromite deposit")

	var drill_b = sim_place_building(&"drill", Vector2i(10, 11), 0)
	sim_assert(drill_b != null, "Drill B placed on crystalline deposit")

	# --- Conveyor chains to smelter inputs ---
	# Row 10: feeds pyromite into smelter cell (20,10)
	for x in range(11, 20):
		sim_place_building(&"conveyor", Vector2i(x, 10), 0)

	# Row 11: feeds crystalline into smelter cell (20,11)
	for x in range(11, 20):
		sim_place_building(&"conveyor", Vector2i(x, 11), 0)

	# --- Place smelter ---
	var smelter = sim_place_building(&"smelter", Vector2i(20, 10), 0)
	sim_assert(smelter != null, "Smelter placed at anchor (20,10)")

	# Verify smelter has recipes
	var conv_logic = smelter.find_child("ConverterLogic", true, false) if smelter else null
	sim_assert(conv_logic != null, "Smelter has ConverterLogic")
	sim_assert(conv_logic.recipes.size() > 0, "Smelter has %d recipes" % (conv_logic.recipes.size() if conv_logic else 0))

	# --- Output chain ---
	sim_place_building(&"conveyor", Vector2i(21, 11), 0)  # output gap
	sim_place_building(&"conveyor", Vector2i(22, 11), 0)
	sim_place_building(&"sink", Vector2i(23, 11), 0)

	# --- Run and verify ---
	# Drills produce every 2s. Smelter needs 1 pyromite + 1 crystalline, crafts in 3s.
	# After ~15s we should see combo items reaching the sink.
	await sim_advance_seconds(15)

	var sink_building = GameManager.get_building_at(Vector2i(23, 11))
	var sink_logic = sink_building.find_child("SinkLogic", true, false) if sink_building else null
	var consumed: int = sink_logic.items_consumed if sink_logic else 0
	sim_assert(consumed > 0, "Sink received steam_burst from elemental flow (got %d)" % consumed)

	# --- Test 2: Verify other combo recipe works (biovine + crystalline → verdant compound) ---
	sim_add_deposit(Vector2i(40, 10), &"biovine")
	sim_add_deposit(Vector2i(40, 11), &"crystalline")

	sim_place_building(&"drill", Vector2i(40, 10), 0)
	sim_place_building(&"drill", Vector2i(40, 11), 0)

	for x in range(41, 50):
		sim_place_building(&"conveyor", Vector2i(x, 10), 0)
		sim_place_building(&"conveyor", Vector2i(x, 11), 0)

	sim_place_building(&"smelter", Vector2i(50, 10), 0)
	sim_place_building(&"conveyor", Vector2i(51, 11), 0)  # output gap
	sim_place_building(&"conveyor", Vector2i(52, 11), 0)
	sim_place_building(&"sink", Vector2i(53, 11), 0)

	await sim_advance_seconds(15)

	var sink2 = GameManager.get_building_at(Vector2i(53, 11))
	var sink2_logic = sink2.find_child("SinkLogic", true, false) if sink2 else null
	var consumed2: int = sink2_logic.items_consumed if sink2_logic else 0
	sim_assert(consumed2 > 0, "Sink received verdant_compound from biovine+crystalline (got %d)" % consumed2)

	sim_finish()
