extends "simulation_base.gd"

## Energy system integration simulation.
## Tests: generation, adjacency transfer, node connections, battery storage,
## coal burner fuel chain, network topology, powered smelter recipe.

func run_simulation() -> void:
	# ═══════════════════════════════════════════════════════════════
	# TEST 1: Solar Panel generates energy passively
	# ═══════════════════════════════════════════════════════════════
	sim_place_building(&"solar_panel", Vector2i(20, 20), 0)
	await sim_advance_seconds(1)

	var solar = GameManager.get_building_at(Vector2i(20, 20))
	sim_assert(solar != null, "Solar panel placed")
	sim_assert(solar.logic.energy != null, "Solar panel has energy component")
	sim_assert(solar.logic.energy.energy_stored > 0.0,
		"Solar panel generated energy (%.1f)" % solar.logic.energy.energy_stored)

	# ═══════════════════════════════════════════════════════════════
	# TEST 2: Adjacent buildings share energy via network equalization
	# ═══════════════════════════════════════════════════════════════
	sim_place_building(&"energy_pole", Vector2i(20, 21), 0)
	await sim_advance_seconds(1)

	var pole1 = GameManager.get_building_at(Vector2i(20, 21))
	sim_assert(pole1.logic.energy.energy_stored > 0.0,
		"Adjacent pole received energy from solar (%.1f)" % pole1.logic.energy.energy_stored)

	# ═══════════════════════════════════════════════════════════════
	# TEST 3: Energy Poles auto-connect within range and bridge energy
	# ═══════════════════════════════════════════════════════════════
	# Place two poles far from test 2 area, within 5-tile range of each other
	sim_place_building(&"energy_pole", Vector2i(25, 30), 0)
	sim_place_building(&"energy_pole", Vector2i(28, 30), 0)

	var pole_a = GameManager.get_building_at(Vector2i(25, 30))
	var pole_b = GameManager.get_building_at(Vector2i(28, 30))
	var enode_a = pole_a.logic.get_energy_node()
	var enode_b = pole_b.logic.get_energy_node()

	sim_assert(enode_a != null and enode_b != null, "Both poles have EnergyNodes")
	sim_assert(enode_b.is_connected_to(enode_a),
		"Poles auto-connected (distance 3, range 5)")

	# Place solar panel adjacent to first pole
	sim_place_building(&"solar_panel", Vector2i(25, 31), 0)
	await sim_advance_seconds(2)

	sim_assert(pole_b.logic.energy.energy_stored > 0.0,
		"Distant pole received energy via node connection (%.1f)" % pole_b.logic.energy.energy_stored)

	# ═══════════════════════════════════════════════════════════════
	# TEST 4: Battery charges from adjacent generator
	# ═══════════════════════════════════════════════════════════════
	sim_place_building(&"solar_panel", Vector2i(35, 40), 0)
	sim_place_building(&"battery", Vector2i(36, 40), 0)
	await sim_advance_seconds(3)

	var battery = GameManager.get_building_at(Vector2i(36, 40))
	var batt_stored = battery.logic.energy.energy_stored
	sim_assert(batt_stored > 10.0,
		"Battery charged from adjacent solar (%.1f)" % batt_stored)

	# Remove solar — battery retains energy
	sim_remove_building(Vector2i(35, 40))
	var before_drain = battery.logic.energy.energy_stored
	await sim_advance_seconds(1)
	sim_assert(battery.logic.energy.energy_stored <= before_drain + 1.0,
		"Battery retains energy after solar removed (%.1f)" % battery.logic.energy.energy_stored)
	sim_assert(battery.logic.energy.energy_stored > 0.0,
		"Battery still has energy (%.1f)" % battery.logic.energy.energy_stored)

	# ═══════════════════════════════════════════════════════════════
	# TEST 5: Coal Burner pulls fuel and generates energy
	# ═══════════════════════════════════════════════════════════════
	# Coal deposit — add explicitly for procedural world
	sim_add_deposit(Vector2i(45, 15), &"coal")
	var drill = sim_place_building(&"drill", Vector2i(45, 15), 0)
	sim_assert(drill != null, "Drill placed on coal deposit")
	sim_place_building(&"conveyor", Vector2i(46, 15), 0)
	# Coal burner anchor at (47,15), occupies (47,15)+(48,15)
	# In_0 at left cell accepts from LEFT
	var burner_result = sim_place_building(&"coal_burner", Vector2i(47, 15), 0)
	sim_assert(burner_result != null, "Coal burner placed")

	await sim_advance_seconds(15)

	var burner = GameManager.get_building_at(Vector2i(47, 15))
	sim_assert(burner.logic.energy != null, "Coal burner has energy component")
	sim_assert(burner.logic.energy.energy_stored > 0.0,
		"Coal burner generated energy from coal (%.1f)" % burner.logic.energy.energy_stored)

	# ═══════════════════════════════════════════════════════════════
	# TEST 6: Network topology — isolated building creates new network
	# ═══════════════════════════════════════════════════════════════
	var es = GameManager.energy_system
	await sim_advance_ticks(2)
	var nets_before = es.networks.size()
	sim_assert(nets_before > 0, "Energy system has %d networks" % nets_before)

	sim_place_building(&"solar_panel", Vector2i(55, 55), 0)
	await sim_advance_ticks(2)
	var nets_after = es.networks.size()
	sim_assert(nets_after == nets_before + 1,
		"Isolated building creates new network (%d -> %d)" % [nets_before, nets_after])

	# ═══════════════════════════════════════════════════════════════
	# TEST 7: Powered smelter recipe (energy allows better recipe)
	# ═══════════════════════════════════════════════════════════════
	# Iron deposit at (10,10). Drill -> conveyors -> smelter.
	# Solar panels adjacent to smelter provide energy.
	sim_add_deposit(Vector2i(10, 10), &"iron_ore")
	sim_place_building(&"drill", Vector2i(10, 10), 0)
	sim_place_building(&"conveyor", Vector2i(11, 10), 0)
	sim_place_building(&"conveyor", Vector2i(12, 10), 0)
	sim_place_building(&"conveyor", Vector2i(13, 10), 0)
	# Smelter anchor at (14,10) — cells: (14,9),(15,9),(14,10),(14,11),(15,11)
	sim_place_building(&"smelter", Vector2i(14, 10), 0)
	# Output gap conveyor + sink
	sim_place_building(&"conveyor", Vector2i(15, 10), 0)
	sim_place_building(&"conveyor", Vector2i(16, 10), 0)
	sim_place_building(&"sink", Vector2i(17, 10), 0)

	# Place solar panels adjacent to smelter cells for energy
	# (14,9) has neighbors: (13,9), (14,8) etc.
	sim_place_building(&"solar_panel", Vector2i(13, 9), 0)
	sim_place_building(&"solar_panel", Vector2i(16, 9), 0)
	sim_place_building(&"solar_panel", Vector2i(16, 11), 0)
	sim_place_building(&"solar_panel", Vector2i(13, 11), 0)

	# Let energy accumulate before iron ore arrives
	await sim_advance_seconds(5)

	var smelter = GameManager.get_building_at(Vector2i(14, 10))
	var smelter_logic = smelter.logic if smelter else null
	sim_assert(smelter_logic != null, "Smelter has logic")
	sim_assert(smelter_logic.energy != null, "Smelter has energy component")
	sim_assert(smelter_logic.energy.energy_stored > 0.0,
		"Smelter received energy from solar panels (%.1f)" % smelter_logic.energy.energy_stored)

	# Run the full chain for 20 more seconds
	await sim_advance_seconds(20)

	var sink = GameManager.get_building_at(Vector2i(17, 10))
	var sink_logic = sink.find_child("SinkLogic", true, false) if sink else null
	var consumed: int = sink_logic.items_consumed if sink_logic else 0
	sim_assert(consumed > 0, "Sink received iron plates from powered smelter (got %d)" % consumed)

	# ═══════════════════════════════════════════════════════════════
	# TEST 8: Network splitting — removing bridge disconnects groups
	# ═══════════════════════════════════════════════════════════════
	# Build: solar(40,5) — pole(41,5) ~~node~~ pole(44,5) — battery(45,5)
	sim_place_building(&"solar_panel", Vector2i(40, 5), 0)
	sim_place_building(&"energy_pole", Vector2i(41, 5), 0)
	sim_place_building(&"energy_pole", Vector2i(44, 5), 0)
	sim_place_building(&"battery", Vector2i(45, 5), 0)

	# Verify poles are connected
	var bridge_a = GameManager.get_building_at(Vector2i(41, 5))
	var bridge_b = GameManager.get_building_at(Vector2i(44, 5))
	var bridge_enode_a = bridge_a.logic.get_energy_node()
	var bridge_enode_b = bridge_b.logic.get_energy_node()
	sim_assert(bridge_enode_b.is_connected_to(bridge_enode_a),
		"Bridge poles are connected")

	await sim_advance_seconds(5)
	await sim_advance_ticks(2)
	var nets_before_split = es.networks.size()

	# Remove bridge pole A — breaks the connection
	sim_remove_building(Vector2i(41, 5))
	await sim_advance_ticks(2)
	var nets_after_split = es.networks.size()
	sim_assert(nets_after_split > nets_before_split,
		"Removing bridge pole split network (%d -> %d)" % [nets_before_split, nets_after_split])

	# ═══════════════════════════════════════════════════════════════
	# TEST 9: Coal burner + battery equalization and charging rate
	# ═══════════════════════════════════════════════════════════════
	# Setup: source(coal) -> conveyor -> coal_burner, battery adjacent to burner.
	# Burner generates 25 en/s. Both should equalize equally until burner caps at 200,
	# then all generation flows to battery.
	#
	# NOTE: In fast mode, Engine.time_scale=100, so each physics tick ≈ 1.667 game-seconds.
	# We use sim_advance_ticks for precise frame control.

	# Source producing coal fast enough to keep burner fueled
	var source9 = sim_place_building(&"source", Vector2i(60, 20), 0)
	source9.logic.item_id = &"coal"
	source9.logic.produce_interval = 0.25
	sim_place_building(&"conveyor", Vector2i(61, 20), 0)
	# Coal burner at (62,20), occupies (62,20)+(63,20). Input from LEFT on anchor cell.
	sim_place_building(&"coal_burner", Vector2i(62, 20), 0)
	# Battery adjacent to burner anchor cell (south neighbor)
	sim_place_building(&"battery", Vector2i(62, 21), 0)

	var burner9 = GameManager.get_building_at(Vector2i(62, 20))
	var battery9 = GameManager.get_building_at(Vector2i(62, 21))
	sim_assert(burner9 != null and burner9.logic.energy != null, "T9: Burner placed with energy")
	sim_assert(battery9 != null and battery9.logic.energy != null, "T9: Battery placed with energy")

	# Warmup: let coal arrive and burning start (3 ticks ≈ 5 game-seconds at 100x)
	await sim_advance_ticks(3)

	# Phase 1: After 4 more ticks (~6.7s), both should have energy.
	# Fill-ratio equalization: battery (2000 cap) absorbs proportionally more than
	# burner (200 cap). Both fill ratios should roughly converge.
	await sim_advance_ticks(4)
	var be9: float = burner9.logic.energy.energy_stored
	var bte9: float = battery9.logic.energy.energy_stored
	sim_assert(be9 > 1.0, "T9: Burner has energy (%.1f)" % be9)
	sim_assert(bte9 > 10.0, "T9: Battery has energy (%.1f)" % bte9)
	var fill_diff := absf(burner9.logic.energy.get_fill_ratio() - battery9.logic.energy.get_fill_ratio())
	sim_assert(fill_diff < 0.15,
		"T9 Phase 1: Fill ratios close (burner=%.3f, battery=%.3f, diff=%.3f)" % [
			burner9.logic.energy.get_fill_ratio(),
			battery9.logic.energy.get_fill_ratio(), fill_diff])

	# Phase 2: Run 10 more ticks — burner stays proportional, battery accumulates bulk.
	# Total ~17 ticks ≈ 700 energy generated. Burner share ≈ 9% of total ≈ 63.
	await sim_advance_ticks(10)
	be9 = burner9.logic.energy.energy_stored
	bte9 = battery9.logic.energy.energy_stored
	sim_assert(be9 > 10.0,
		"T9 Phase 2: Burner has proportional share (%.1f / 200)" % be9)
	sim_assert(bte9 > 100.0,
		"T9 Phase 2: Battery absorbed bulk energy (%.1f / 2000)" % bte9)

	# Phase 3: Verify battery keeps gaining energy over time.
	var batt_before: float = battery9.logic.energy.energy_stored
	await sim_advance_ticks(5)
	var batt_after: float = battery9.logic.energy.energy_stored
	var gain: float = batt_after - batt_before
	sim_assert(gain > 50.0,
		"T9 Phase 3: Battery gaining energy (gain=%.1f over 5 ticks, %.1f → %.1f)" % [gain, batt_before, batt_after])

	sim_finish()
