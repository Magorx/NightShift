extends ScenarioBase
## Scenario: Terrain Elevation
##
## Tests the 3D terrain elevation system:
## - Player stands at correct height on elevated tiles
## - Player must jump to climb terrain steps (can't walk up)
## - Player walks down from elevated terrain freely
## - Buildings placed on elevated ground are at correct height
## - Drill + conveyor + sink production chain works on elevated terrain
## - Bot auto-jumps when walking toward higher terrain

func scenario_name() -> String:
	return "scn_terrain_elevation"

func setup_map() -> void:
	map.clear_walls()

	# Create terrain with multiple elevation levels:
	# Region 1: Flat ground at height 0 (default, tiles 4-12, 4-20)
	# Region 2: Elevated plateau at height 1.0 (tiles 14-22, 8-16)
	# Region 3: Step ramp 0 -> 0.5 -> 1.0 (tile column 13, then 14+)
	# Region 4: High plateau at height 1.5 (tiles 23-26, 10-14)

	# Plateau at height 1.0
	map.set_height_rect(Vector2i(14, 8), Vector2i(22, 16), 1.0)

	# Ramp: step at 0.5
	map.set_height_rect(Vector2i(13, 8), Vector2i(13, 16), 0.5)

	# High plateau at 1.5
	map.set_height_rect(Vector2i(23, 10), Vector2i(26, 14), 1.5)

	# Deposit on the elevated plateau for production test
	map.deposit_cluster(Vector2i(18, 12), &"pyromite", 1)

	# Player starts on flat ground
	map.player_start(Vector2i(8, 12))

func setup_monitors() -> void:
	monitor.track("player_y", func() -> float:
		return GameManager.player.position.y)
	monitor.track("player_x", func() -> float:
		return GameManager.player.position.x)
	monitor.track("player_z", func() -> float:
		return GameManager.player.position.z)
	monitor.track("items_delivered", func() -> int:
		return EconomyTracker.items_delivered.get(&"pyromite", 0))

func run_scenario() -> void:
	var player: Player = GameManager.player

	# ── Test 1: Player on flat ground (height 0) ────────────────────────
	await bot.wait(0.5)
	monitor.sample()
	var y_on_flat: float = player.position.y
	assert_scenario(absf(y_on_flat) < 0.2, "Player on flat ground near Y=0 (y=%.3f)" % y_on_flat)
	await monitor.screenshot("01_flat_ground")

	# ── Test 2: Bot auto-jumps to reach step ────────────────────────────
	# Walls block horizontal movement; bot must jump to climb
	var arrived := await bot.walk_to(Vector2i(13, 12))
	assert_scenario(arrived, "Bot auto-jumped to step (13,12)")
	await bot.wait(0.3)
	monitor.sample()
	var y_on_step: float = player.position.y
	assert_scenario(y_on_step > 0.3, "Player elevated on 0.5 step (y=%.3f)" % y_on_step)
	await monitor.screenshot("03_on_step")

	# ── Test 4: Bot auto-jumps to reach 1.0 plateau ─────────────────────
	arrived = await bot.walk_to(Vector2i(16, 12))
	assert_scenario(arrived, "Bot auto-jumped to plateau (16,12)")
	await bot.wait(0.3)
	monitor.sample()
	var y_on_plateau: float = player.position.y
	assert_scenario(y_on_plateau > 0.8, "Player elevated on 1.0 plateau (y=%.3f)" % y_on_plateau)
	await monitor.screenshot("04_on_plateau")

	# ── Test 5: Place buildings on elevated terrain ─────────────────────
	var drill_placed := await bot.place(&"drill", Vector2i(18, 12), 0)
	assert_scenario(drill_placed, "Drill placed on elevated deposit")

	var drill_building = BuildingRegistry.get_building_at(Vector2i(18, 12))
	if drill_building:
		var drill_y: float = drill_building.position.y
		assert_scenario(drill_y > 0.8, "Drill at correct height (y=%.3f)" % drill_y)

	# Place conveyor line and sink (instant, no walking through buildings)
	await bot.place_conveyor_line(Vector2i(19, 12), Vector2i(21, 12))
	var sink_placed := await bot.place_at(&"sink", Vector2i(22, 12), 0)
	assert_scenario(sink_placed, "Sink placed on elevated terrain")
	await monitor.screenshot("05_buildings_on_plateau")

	# ── Test 6: Production chain works on elevated terrain ──────────────
	await bot.wait(12.0)
	monitor.sample()
	var items: int = EconomyTracker.items_delivered.get(&"pyromite", 0)
	assert_gt_scenario(float(items), 0.0, "Production works on elevated terrain (items=%d)" % items)
	await monitor.screenshot("06_production_running")

	# ── Test 7: Walk back DOWN to flat ground (no jump needed) ──────────
	arrived = await bot.walk_to(Vector2i(8, 12))
	assert_scenario(arrived, "Walked down to flat ground (no jump needed)")
	await bot.wait(0.3)
	monitor.sample()
	var y_back_flat: float = player.position.y
	assert_scenario(y_back_flat < 0.3, "Player back at ground level (y=%.3f)" % y_back_flat)
	await monitor.screenshot("07_back_on_flat")

	# ── Test 8: Teleport to high plateau (1.5) ─────────────────────────
	await bot.teleport_to(Vector2i(24, 12))
	await bot.wait(0.5)
	monitor.sample()
	var y_on_high: float = player.position.y
	assert_scenario(y_on_high > 1.3, "Player on high plateau (y=%.3f)" % y_on_high)
	await monitor.screenshot("08_high_plateau")

	# ── Test 9: Verify height differences ───────────────────────────────
	assert_gt_scenario(y_on_plateau - y_on_flat, 0.5,
		"Plateau higher than flat (diff=%.3f)" % (y_on_plateau - y_on_flat))
	assert_gt_scenario(y_on_step - y_on_flat, 0.2,
		"Step higher than flat (diff=%.3f)" % (y_on_step - y_on_flat))
	assert_gt_scenario(y_on_high - y_on_plateau, 0.3,
		"High plateau higher than plateau (diff=%.3f)" % (y_on_high - y_on_plateau))
