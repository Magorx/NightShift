extends "simulation_base.gd"

## Tests the massive content update: new buildings, items, atlas rendering,
## multipart shapes, and production chains.

func run_simulation() -> void:
	# ── Test 1: Item Atlas Rendering ────────────────────────────────────────
	# Display ALL new items on conveyors to verify atlas indices are correct.
	# Each item should render as a distinct sprite, not duplicates.

	var new_items: Array[StringName] = [
		&"oil", &"crystal", &"uranium_ore", &"biomass",
		&"plastic", &"rubber", &"acid", &"silicon",
		&"carbon_fiber", &"refined_uranium", &"bio_compound", &"ceramic",
		&"alloy_plate", &"insulated_wire", &"heat_sink", &"filter",
		&"plastic_casing", &"crystal_oscillator", &"quantum_chip", &"nano_fiber",
		&"fusion_cell", &"robot_arm", &"science_pack_4",
		&"quantum_computer", &"power_armor", &"terraformer",
	]

	# Row 1: new items
	for i in range(new_items.size()):
		sim_place_building(&"conveyor", Vector2i(3 + i, 5), 0)
	await sim_advance_ticks(5)
	for i in range(new_items.size()):
		sim_spawn_item_on_conveyor(Vector2i(3 + i, 5), new_items[i])

	# Row 2: original items for comparison
	var old_items: Array[StringName] = [
		&"iron_ore", &"copper_ore", &"coal", &"stone",
		&"iron_plate", &"copper_ring", &"steel", &"glass",
		&"gear", &"copper_wire", &"circuit_board", &"motor",
		&"advanced_circuit", &"processor", &"science_pack_1", &"science_pack_2",
	]
	for i in range(old_items.size()):
		sim_place_building(&"conveyor", Vector2i(3 + i, 7), 0)
	await sim_advance_ticks(5)
	for i in range(old_items.size()):
		sim_spawn_item_on_conveyor(Vector2i(3 + i, 7), old_items[i])

	# Move camera to see items
	var camera = game_world.find_child("Camera2D", false, false)
	if camera:
		camera.position = Vector2(16 * 32, 6 * 32)
		camera.zoom = Vector2(2.0, 2.0)

	await sim_advance_ticks(10)
	await sim_capture_screenshot("item_atlas_all")

	# Verify all items have valid icon_atlas_index
	for item_id in new_items:
		var item_def = GameManager.get_item_def(item_id)
		sim_assert(item_def != null, "Item def exists: %s" % item_id)
		if item_def:
			sim_assert(item_def.icon_atlas_index >= 37 and item_def.icon_atlas_index <= 62,
				"Item %s has valid atlas index %d" % [item_id, item_def.icon_atlas_index])

	# ── Test 2: Chemical Plant production ───────────────────────────────────
	# Chemical plant at (9,16) is 2x2: cells (9,16)(10,16)(9,17)(10,17)
	# Coal burner ADJACENT at (11,16) for power (2x1: cells (11,16)(11,17))
	sim_add_deposit(Vector2i(13, 15), &"coal")
	sim_place_building(&"drill", Vector2i(13, 15), 1)  # output down
	sim_place_building(&"conveyor", Vector2i(13, 16), 0)  # goes right... actually left to burner
	# Coal burner adjacent to chemical plant output side
	sim_place_building(&"coal_burner", Vector2i(11, 16), 0)
	# Energy pole between them
	sim_place_building(&"energy_pole", Vector2i(10, 15), 0)
	# Feed coal to burner: drill at (13,15)→down→(13,16)→left conveyors→burner
	sim_place_building(&"conveyor", Vector2i(12, 16), 2)  # goes left

	# Oil source → conveyors → chemical plant input
	sim_place_building(&"source", Vector2i(5, 16), 0)
	var source = GameManager.get_building_at(Vector2i(5, 16))
	if source:
		var src_logic = source.find_child("SourceLogic", true, false)
		if src_logic:
			src_logic.item_id = &"oil"

	for x in range(6, 9):
		sim_place_building(&"conveyor", Vector2i(x, 16), 0)

	var chem = sim_place_building(&"chemical_plant", Vector2i(9, 16), 0)
	sim_assert(chem != null, "Chemical plant placed")

	# Output from chemical plant right side → sink
	for x in range(11, 14):
		sim_place_building(&"conveyor", Vector2i(x, 17), 0)
	sim_place_building(&"sink", Vector2i(14, 17), 0)

	var chem_b = GameManager.get_building_at(Vector2i(9, 16))
	var chem_logic = chem_b.find_child("ConverterLogic", true, false) if chem_b else null
	sim_assert(chem_logic != null and chem_logic.recipes.size() >= 5,
		"Chemical plant has recipes (%d)" % (chem_logic.recipes.size() if chem_logic else 0))

	await sim_advance_seconds(5)
	await sim_capture_screenshot("chemical_plant_chain")

	# ── Test 3: Multipart Building Shapes ───────────────────────────────────

	# Particle Accelerator (L-shape): cells (0,0)(1,0)(2,0)(0,1)(0,2)
	var pa = sim_place_building(&"particle_accelerator", Vector2i(20, 12), 0)
	sim_assert(pa != null, "Particle Accelerator placed")
	sim_assert(GameManager.get_building_at(Vector2i(20, 12)) != null, "PA (0,0)")
	sim_assert(GameManager.get_building_at(Vector2i(21, 12)) != null, "PA (1,0)")
	sim_assert(GameManager.get_building_at(Vector2i(22, 12)) != null, "PA (2,0)")
	sim_assert(GameManager.get_building_at(Vector2i(20, 13)) != null, "PA (0,1)")
	sim_assert(GameManager.get_building_at(Vector2i(20, 14)) != null, "PA (0,2)")
	sim_assert(GameManager.get_building_at(Vector2i(21, 13)) == null, "PA gap (1,1) free")
	sim_assert(GameManager.get_building_at(Vector2i(22, 14)) == null, "PA gap (2,2) free")

	# Fabricator (T-shape): cells (0,0)(1,0)(2,0)(1,1)(1,2)
	var fab = sim_place_building(&"fabricator", Vector2i(26, 12), 0)
	sim_assert(fab != null, "Fabricator placed")
	sim_assert(GameManager.get_building_at(Vector2i(26, 12)) != null, "Fab (0,0)")
	sim_assert(GameManager.get_building_at(Vector2i(27, 12)) != null, "Fab (1,0)")
	sim_assert(GameManager.get_building_at(Vector2i(28, 12)) != null, "Fab (2,0)")
	sim_assert(GameManager.get_building_at(Vector2i(27, 13)) != null, "Fab (1,1)")
	sim_assert(GameManager.get_building_at(Vector2i(27, 14)) != null, "Fab (1,2)")
	sim_assert(GameManager.get_building_at(Vector2i(26, 13)) == null, "Fab gap (0,1) free")

	# Nuclear Reactor (cross-shape): cells (1,0)(0,1)(1,1)(2,1)(1,2)
	var nuc = sim_place_building(&"nuclear_reactor", Vector2i(32, 12), 0)
	sim_assert(nuc != null, "Nuclear Reactor placed")

	# Verify recipes
	var pa_b = GameManager.get_building_at(Vector2i(20, 12))
	var pa_logic = pa_b.find_child("ConverterLogic", true, false) if pa_b else null
	sim_assert(pa_logic != null and pa_logic.recipes.size() > 0,
		"PA has recipes (%d)" % (pa_logic.recipes.size() if pa_logic else 0))

	var fab_b = GameManager.get_building_at(Vector2i(26, 12))
	var fab_logic = fab_b.find_child("ConverterLogic", true, false) if fab_b else null
	sim_assert(fab_logic != null and fab_logic.recipes.size() > 0,
		"Fabricator has recipes (%d)" % (fab_logic.recipes.size() if fab_logic else 0))

	await sim_capture_screenshot("multipart_buildings")

	# ── Test 4: Greenhouse (bio_compound -> biomass) ────────────────────────
	# Greenhouse at (20,20) is 2x1: cells (20,20)(21,20)
	# Coal burner ADJACENT above: (20,19) is 2x1: cells (20,19)(21,19)
	sim_add_deposit(Vector2i(22, 18), &"coal")
	sim_place_building(&"drill", Vector2i(22, 18), 1)  # output down
	sim_place_building(&"conveyor", Vector2i(22, 19), 2)  # goes left
	sim_place_building(&"coal_burner", Vector2i(20, 19), 0)  # adjacent above greenhouse

	sim_place_building(&"greenhouse", Vector2i(20, 20), 0)
	sim_place_building(&"conveyor", Vector2i(19, 20), 0)
	sim_place_building(&"conveyor", Vector2i(22, 20), 0)
	sim_place_building(&"sink", Vector2i(23, 20), 0)

	var gh_b = GameManager.get_building_at(Vector2i(20, 20))
	var gh_logic = gh_b.find_child("ConverterLogic", true, false) if gh_b else null
	sim_assert(gh_logic != null and gh_logic.recipes.size() > 0,
		"Greenhouse has recipes (%d)" % (gh_logic.recipes.size() if gh_logic else 0))

	# ── Test 5: Centrifuge (uranium_ore -> refined_uranium) ─────────────────
	# Centrifuge at (28, 26), 2x2: cells (28,26)(29,26)(28,27)(29,27)
	# Coal burner ADJACENT above: (28,25) is 2x1: cells (28,25)(29,25)
	sim_add_deposit(Vector2i(30, 24), &"coal")
	sim_place_building(&"drill", Vector2i(30, 24), 1)  # output down
	sim_place_building(&"conveyor", Vector2i(30, 25), 2)  # goes left
	sim_place_building(&"coal_burner", Vector2i(28, 25), 0)  # adjacent above centrifuge

	sim_place_building(&"centrifuge", Vector2i(28, 26), 0)
	# Feed uranium via source -> conveyors -> centrifuge input (left side)
	sim_place_building(&"source", Vector2i(25, 26), 0)
	var u_source = GameManager.get_building_at(Vector2i(25, 26))
	if u_source:
		var u_src_logic = u_source.find_child("SourceLogic", true, false)
		if u_src_logic:
			u_src_logic.item_id = &"uranium_ore"
	var cent_b = GameManager.get_building_at(Vector2i(28, 26))
	var cent_logic = cent_b.find_child("ConverterLogic", true, false) if cent_b else null
	sim_assert(cent_logic != null and cent_logic.recipes.size() > 0,
		"Centrifuge has recipes (%d)" % (cent_logic.recipes.size() if cent_logic else 0))

	# ── Test 6: Pump extracts oil from deposits ─────────────────────────────
	sim_add_deposit(Vector2i(35, 20), &"oil")
	var pump = sim_place_building(&"pump", Vector2i(35, 20), 0)
	sim_assert(pump != null, "Pump placed on oil deposit")
	sim_place_building(&"conveyor", Vector2i(36, 20), 0)
	sim_place_building(&"sink", Vector2i(37, 20), 0)

	await sim_advance_seconds(10)

	var pump_sink = GameManager.get_building_at(Vector2i(37, 20))
	var pump_l = pump_sink.find_child("SinkLogic", true, false) if pump_sink else null
	sim_assert(pump_l != null and pump_l.items_consumed > 0,
		"Pump extracted oil (got %d)" % (pump_l.items_consumed if pump_l else 0))

	# ── Test 7: Research tree has ring 4-5 nodes ────────────────────────────
	var ring4_exists := false
	var ring5_exists := false
	for tech_id in ResearchManager.tech_defs:
		var tech: TechDef = ResearchManager.tech_defs[tech_id]
		if tech.ring == 4: ring4_exists = true
		if tech.ring == 5: ring5_exists = true
	sim_assert(ring4_exists, "Ring 4 techs exist")
	sim_assert(ring5_exists, "Ring 5 techs exist")

	# ── Test 8: Contract manager has ring 4-5 gates ─────────────────────────
	sim_assert(ContractManager.GATE_DEFS.has(4), "Gate 4 defined")
	sim_assert(ContractManager.GATE_DEFS.has(5), "Gate 5 defined")

	await sim_capture_screenshot("final_overview")

	print("[SIM] All content update tests completed")
	sim_finish()
