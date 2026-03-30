extends "simulation_base.gd"

## Tests new buildings: press, wire drawer, coke oven, hand assembler,
## conveyor mk2/mk3, assembler mk1, and the research + contract systems.

func run_simulation() -> void:
	# ── Test 1: Press (iron_ore -> smelter -> iron_plate -> press -> iron_gear) ──
	sim_add_deposit(Vector2i(5, 5), &"iron_ore")
	sim_place_building(&"drill", Vector2i(5, 5), 0)
	sim_place_building(&"conveyor", Vector2i(6, 5), 0)
	sim_place_building(&"conveyor", Vector2i(7, 5), 0)
	sim_place_building(&"smelter", Vector2i(8, 5), 0)
	# Smelter output gap at (9,5)
	sim_place_building(&"conveyor", Vector2i(9, 5), 0)
	sim_place_building(&"conveyor", Vector2i(10, 5), 0)
	# Press is 2x1, occupies (11,5) and (12,5). Place it without conveyor conflict.
	sim_place_building(&"press", Vector2i(11, 5), 0)
	# Output conveyor AFTER the press (at 13,5 since press takes 11-12)
	sim_place_building(&"conveyor", Vector2i(13, 5), 0)
	sim_place_building(&"sink", Vector2i(14, 5), 0)

	# Verify press placed
	var press = GameManager.get_building_at(Vector2i(11, 5))
	sim_assert(press != null, "Press placed at (11,5)")
	sim_assert(press.logic is ConverterLogic, "Press has ConverterLogic")

	# Press should have press recipes
	var press_logic: ConverterLogic = press.logic
	sim_assert(press_logic.recipes.size() > 0, "Press has recipes (got %d)" % press_logic.recipes.size())

	# ── Test 2: Wire Drawer (copper_ore -> smelter -> copper_plate -> wire_drawer -> copper_wire) ──
	sim_add_deposit(Vector2i(5, 12), &"copper_ore")
	sim_place_building(&"drill", Vector2i(5, 12), 0)
	sim_place_building(&"conveyor", Vector2i(6, 12), 0)
	sim_place_building(&"conveyor", Vector2i(7, 12), 0)
	sim_place_building(&"smelter", Vector2i(8, 12), 0)
	sim_place_building(&"conveyor", Vector2i(9, 12), 0)
	sim_place_building(&"conveyor", Vector2i(10, 12), 0)
	# Wire drawer is 1x2, anchor at (0,0), input from top, output to bottom
	# Place it so input is at (11,12) and output is at (11,13)
	sim_place_building(&"wire_drawer", Vector2i(11, 12), 0)

	var wd = GameManager.get_building_at(Vector2i(11, 12))
	sim_assert(wd != null, "Wire drawer placed at (11,12)")

	# ── Test 3: Conveyor Mk2 speed ──
	sim_place_building(&"conveyor_mk2", Vector2i(20, 5), 0)
	var mk2 = GameManager.get_building_at(Vector2i(20, 5))
	sim_assert(mk2 != null, "Conveyor Mk2 placed")
	sim_assert(mk2.logic is ConveyorBelt, "Conveyor Mk2 is ConveyorBelt")
	var mk2_logic: ConveyorBelt = mk2.logic
	sim_assert(mk2_logic.traverse_time < 1.0, "Conveyor Mk2 is faster (traverse=%.2f)" % mk2_logic.traverse_time)

	# ── Test 4: Conveyor Mk3 speed ──
	sim_place_building(&"conveyor_mk3", Vector2i(20, 7), 0)
	var mk3 = GameManager.get_building_at(Vector2i(20, 7))
	sim_assert(mk3 != null, "Conveyor Mk3 placed")
	var mk3_logic: ConveyorBelt = mk3.logic
	sim_assert(mk3_logic.traverse_time < 0.5, "Conveyor Mk3 is faster (traverse=%.3f)" % mk3_logic.traverse_time)

	# ── Test 5: Hand Assembler (manual crafter) ──
	sim_place_building(&"hand_assembler", Vector2i(20, 10), 0)
	var ha = GameManager.get_building_at(Vector2i(20, 10))
	sim_assert(ha != null, "Hand assembler placed")

	# Check that recipes are disabled by default
	var ha_logic = ha.logic
	var all_disabled := true
	for config in ha_logic.recipe_configs:
		if config.enabled:
			all_disabled = false
	sim_assert(all_disabled, "Hand assembler recipes all disabled by default")

	# ── Test 6: Coke Oven ──
	sim_place_building(&"coke_oven", Vector2i(25, 5), 0)
	var co = GameManager.get_building_at(Vector2i(25, 5))
	sim_assert(co != null, "Coke oven placed at (25,5)")
	sim_assert(co.logic.recipes.size() > 0, "Coke oven has recipes")

	# ── Test 7: Run and verify production chain ──
	# Chain: drill(2s) -> conveyors -> smelter(3s) -> conveyors -> press(2s) -> conveyor -> sink
	await sim_advance_seconds(20)

	var total_delivered: int = 0
	for item_id in GameManager.items_delivered:
		total_delivered += GameManager.items_delivered[item_id]
	sim_assert(total_delivered > 0, "Items delivered through press chain (got %d)" % total_delivered)

	# ── Test 8: Research system exists ──
	sim_assert(ResearchManager != null, "ResearchManager autoload exists")
	var techs = ResearchManager.get_available_techs()
	sim_assert(techs.size() > 0, "Available techs exist (%d)" % techs.size())

	# ── Test 9: Contract system exists ──
	sim_assert(ContractManager != null, "ContractManager autoload exists")
	sim_assert(ContractManager.active_contracts.size() > 0,
		"Active contracts exist (%d)" % ContractManager.active_contracts.size())

	# ── Test 10: Assembler Mk2 (3x2 building) placement ──
	var result = sim_place_building(&"assembler_mk2", Vector2i(30, 10), 0)
	sim_assert(result != null, "Assembler Mk2 (3x2) placed")
	# Check all 6 cells are occupied
	var cells_occupied := 0
	for dx in range(3):
		for dy in range(2):
			if GameManager.get_building_at(Vector2i(30 + dx, 10 + dy)) != null:
				cells_occupied += 1
	sim_assert(cells_occupied == 6, "Assembler Mk2 occupies 6 cells (got %d)" % cells_occupied)

	print("[SIM] All new building tests completed")
	sim_finish()
