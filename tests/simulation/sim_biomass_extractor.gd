extends "simulation_base.gd"

func run_simulation() -> void:
	# ── Test 1: Extractor can only be placed on biomass deposits ──────────
	var empty_pos := Vector2i(99, 99)
	GameManager.deposits.erase(empty_pos)
	var result = sim_place_building(&"biomass_extractor", empty_pos, 0)
	sim_assert(result == null, "Extractor cannot be placed on empty ground")

	# ── Test 2: Place extractor on biomass deposits ──────────────────────
	# Create a cluster of biomass tiles
	for x in range(10, 20):
		sim_add_deposit(Vector2i(x, 10), &"biomass")
		GameManager.deposit_stocks[Vector2i(x, 10)] = 3
	# The extractor is 1x2 (rotation 0 = right), so cells (10,10) and (11,10)
	result = sim_place_building(&"biomass_extractor", Vector2i(10, 10), 0)
	sim_assert(result != null, "Extractor placed on biomass at (10,10)-(11,10)")

	# ── Test 3: Two-phase placement — output device ─────────────────────
	# Output needs 1-cell gap from extractor. Extractor at (10,10)-(11,10).
	# Place output at (13,10) = 1 cell gap from (11,10) going right.
	var out_result = sim_place_building(&"biomass_extractor_output", Vector2i(13, 10), 0)
	sim_assert(out_result != null, "Output device placed at (13,10)")

	# Manually link (simulations bypass multi-phase build system)
	var ext_building = GameManager.get_building_at(Vector2i(10, 10))
	var out_building = GameManager.get_building_at(Vector2i(13, 10))
	if ext_building and out_building and ext_building.logic and out_building.logic:
		ext_building.logic.output_device = out_building.logic
		out_building.logic.extractor = ext_building.logic

	# Initialize cluster drain manager
	if not GameManager.cluster_drain_manager:
		var CDM = load("res://scripts/game/cluster_drain_manager.gd")
		GameManager.cluster_drain_manager = CDM.new()
	GameManager.cluster_drain_manager.invalidate_cache()

	# ── Test 4: Production flow — extractor to conveyor to sink ──────────
	# Output at (13,10) facing right. Conveyors from (14,10) to sink at (17,10).
	sim_place_building(&"conveyor", Vector2i(14, 10), 0)
	sim_place_building(&"conveyor", Vector2i(15, 10), 0)
	sim_place_building(&"conveyor", Vector2i(16, 10), 0)
	sim_place_building(&"sink", Vector2i(17, 10), 0)

	await sim_advance_seconds(12)

	var sink = GameManager.get_building_at(Vector2i(17, 10))
	var sink_logic = sink.find_child("SinkLogic", true, false) if sink else null
	var consumed: int = sink_logic.items_consumed if sink_logic else 0
	sim_assert(consumed > 0, "Sink consumed biomass from extractor chain (got %d)" % consumed)

	# ── Test 5: Stock depletion and ash conversion ───────────────────────
	# Set a single biomass tile with stock = 2
	var test_pos := Vector2i(30, 20)
	sim_add_deposit(test_pos, &"biomass")
	GameManager.deposit_stocks[test_pos] = 2

	# Drain it
	var drained := GameManager.drain_deposit_stock(test_pos)
	sim_assert(drained, "First drain succeeded (stock 2 -> 1)")
	sim_assert(GameManager.deposit_stocks.get(test_pos, 0) == 1, "Stock is 1 after first drain")

	drained = GameManager.drain_deposit_stock(test_pos)
	sim_assert(drained, "Second drain succeeded (stock 1 -> 0, converts to ash)")
	sim_assert(not GameManager.deposits.has(test_pos), "Tile is no longer a deposit after depletion")

	# Check terrain tile type became ash
	var idx := test_pos.y * GameManager.map_size + test_pos.x
	var tile_type: int = GameManager.terrain_tile_types[idx]
	sim_assert(tile_type == TileDatabase.TILE_ASH, "Depleted tile became ash (got %d)" % tile_type)

	# Can't drain ash
	drained = GameManager.drain_deposit_stock(test_pos)
	sim_assert(not drained, "Cannot drain ash tile")

	# ── Test 6: Infinite stock deposits are unaffected ───────────────────
	var iron_pos := Vector2i(40, 20)
	sim_add_deposit(iron_pos, &"iron_ore")
	GameManager.deposit_stocks[iron_pos] = -1
	for i in range(100):
		GameManager.drain_deposit_stock(iron_pos)
	sim_assert(GameManager.deposits.has(iron_pos), "Infinite stock deposit not depleted after 100 drains")

	# ── Test 7: BFS drain ordering — most distant first ──────────────────
	# Create a small linear cluster and an extractor at one end
	for x in range(50, 56):
		sim_add_deposit(Vector2i(x, 30), &"biomass")
		GameManager.deposit_stocks[Vector2i(x, 30)] = 5

	var ext2 = sim_place_building(&"biomass_extractor", Vector2i(50, 30), 0)
	sim_assert(ext2 != null, "Second extractor placed at (50,30)")
	# Place output at (53,30) and link
	var out2 = sim_place_building(&"biomass_extractor_output", Vector2i(53, 30), 0)
	if ext2 and out2:
		var ext2_logic = ext2.logic if ext2 else null
		var out2_logic = out2.logic if out2 else null
		if ext2_logic and out2_logic:
			ext2_logic.output_device = out2_logic
			out2_logic.extractor = ext2_logic

	GameManager.cluster_drain_manager.invalidate_cache()

	# Get drain order — should drain (55,30) first (most distant from extractor at 50-51)
	var next_tile: Vector2i = GameManager.cluster_drain_manager.get_next_drain_tile(Vector2i(50, 30), &"biomass")
	sim_assert(next_tile == Vector2i(55, 30), "BFS drains most distant tile first (got %s)" % str(next_tile))

	sim_finish()
