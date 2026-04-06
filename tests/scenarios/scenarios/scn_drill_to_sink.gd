extends ScenarioBase
## Scenario: Drill → Conveyor line → Sink
##
## Tests the basic production chain. Bot walks to a deposit, places a drill,
## lays a conveyor line, places a sink at the end, and waits for items to flow.
## Verifies items are actually delivered to the sink.

func scenario_name() -> String:
	return "scn_drill_to_sink"

func setup_map() -> void:
	map.clear_walls()

	# Pyromite deposit cluster at (10, 10)
	map.deposit_cluster(Vector2i(10, 10), &"pyromite", 1)

	# Player starts nearby
	map.player_start(Vector2i(8, 10))

func setup_monitors() -> void:
	# Track sink consumption
	monitor.track("items_delivered", func() -> int:
		return EconomyTracker.items_delivered.get(&"pyromite", 0)
	)
	monitor.track("player_hp", func() -> float:
		return GameManager.player.hp
	)
	monitor.track("buildings_placed", func() -> int:
		return BuildingRegistry.unique_buildings.size()
	)

func run_scenario() -> void:
	# ── Step 1: Walk to deposit and place drill ──────────────────────────
	assert_scenario(MapManager.get_deposit_at(Vector2i(10, 10)) == &"pyromite",
		"Pyromite deposit exists at (10,10)")

	await bot.walk_to(Vector2i(9, 10))
	var drill_ok := await bot.place(&"drill", Vector2i(10, 10), 0)
	assert_scenario(drill_ok, "Drill placed on deposit")

	monitor.sample()

	# ── Step 2: Lay conveyor line from drill output to sink ──────────────
	# Drill outputs to the right (rotation 0), so conveyors go right from (11, 10)
	var conv_count := await bot.place_conveyor_line(Vector2i(11, 10), Vector2i(15, 10))
	assert_gt_scenario(float(conv_count), 3.0, "Conveyor line placed")

	# ── Step 3: Place sink at end of conveyor line ───────────────────────
	var sink_ok := await bot.place(&"sink", Vector2i(16, 10), 0)
	assert_scenario(sink_ok, "Sink placed at end of line")

	monitor.sample()
	await monitor.screenshot("setup_complete")

	# ── Step 4: Wait for production ──────────────────────────────────────
	# Drill should extract pyromite, conveyor moves it, sink consumes it
	await bot.wait(15.0)  # 15 game seconds — enough for several items

	monitor.sample()
	await monitor.screenshot("production_running")

	# ── Step 5: Verify items were delivered ──────────────────────────────
	monitor.assert_gt("items_delivered", 0.0, "Sink received at least one item")
	monitor.assert_gt("buildings_placed", 5.0, "Multiple buildings placed")

	# ── Step 6: Player is still alive and well ───────────────────────────
	monitor.assert_eq("player_hp", 100.0, "Player at full HP")

	# ── Step 7: Walk back and observe ────────────────────────────────────
	await bot.walk_to(Vector2i(13, 10))
	await bot.wait(5.0)

	monitor.sample()
	await monitor.screenshot("final_state")

	# Final delivery count check
	var total_delivered: int = EconomyTracker.items_delivered.get(&"pyromite", 0)
	assert_gt_scenario(float(total_delivered), 2.0,
		"Multiple items delivered (got %d)" % total_delivered)
