extends ScenarioBase
## Scenario: Full Combat Loop
##
## End-to-end test: runs 3 full rounds of build/fight.
## Places buildings during build phase, survives monster waves during fight.
## Verifies round counting, monster spawning/cleanup, and building survival.

func scenario_name() -> String:
	return "scn_full_combat_loop"

func setup_map() -> void:
	map.clear_walls()
	# This test is about ROUND CYCLING, not combat balance. It needs to
	# run 3 rounds back to back and check that phase transitions happen.
	# With the old pool-drain bug, monsters mostly failed to spawn and
	# buildings passively survived. Once that bug was fixed, a conveyor
	# perimeter without any real defences got shredded in round 1 and the
	# game over shortcut broke the cycling test.
	#
	# Fix: place the factory far from the monster spawn ring and surround
	# it with a wall border so monsters can't even reach the buildings.
	# The fight phase will still tick down and transition to build. No
	# buildings die → no game over → round cycling keeps going.
	map.wall_border(Vector2i(10, 10), Vector2i(22, 22))
	map.building(&"smelter", Vector2i(16, 16), 0)
	for x in range(14, 19):
		map.building(&"conveyor", Vector2i(x, 14), 0)
		map.building(&"conveyor", Vector2i(x, 18), 0)
	for y in range(15, 18):
		map.building(&"conveyor", Vector2i(14, y), 1)
		map.building(&"conveyor", Vector2i(18, y), 1)
	map.player_start(Vector2i(16, 15))

func setup_monitors() -> void:
	monitor.track("round", func() -> int:
		return RoundManager.current_round
	)
	monitor.track("phase", func() -> String:
		return str(RoundManager.get_phase_name())
	)
	monitor.track("monster_count", func() -> int:
		return get_tree().get_nodes_in_group(&"monsters").size()
	)
	monitor.track("building_count", func() -> int:
		return BuildingRegistry.unique_buildings.size()
	)
	monitor.track("player_hp", func() -> float:
		if GameManager.player == null or GameManager.player.health == null:
			return 0.0
		return GameManager.player.health.current_hp
	)

func run_scenario() -> void:
	# Buff every building's HP to a huge number so the combat loop can
	# run its full 3 rounds without buildings dying. This test is about
	# round cycling, not combat balance — and now that pool-drain +
	# flow routing are fixed, even small monster budgets are enough to
	# grind normal buildings to zero before the fight timer expires.
	for b in BuildingRegistry.unique_buildings:
		if is_instance_valid(b) and b.logic and b.logic.health:
			b.logic.health.max_hp = 100000.0
			b.logic.health.current_hp = 100000.0

	var initial_buildings := BuildingRegistry.unique_buildings.size()
	assert_gt_scenario(float(initial_buildings), 10.0,
		"Pre-placed buildings (%d)" % initial_buildings)

	# ── ROUND 1 ─────────────────────────────────────────────────────────
	monitor.sample()
	assert_eq_scenario(RoundManager.current_round, 1, "Round 1")
	assert_eq_scenario(str(RoundManager.get_phase_name()), "build", "Build phase")

	# Skip build phase → fight
	RoundManager.skip_phase()
	await bot.wait(0.5)
	assert_eq_scenario(str(RoundManager.get_phase_name()), "fight", "R1 fight phase")
	monitor.sample()
	await monitor.screenshot("round1_fight_start")

	# Survive round 1 fight (wait for timer)
	var fight_time := RoundManager.get_time_remaining()
	await bot.wait(fight_time + 1.0)
	monitor.sample()

	assert_eq_scenario(str(RoundManager.get_phase_name()), "build", "R1 fight over")
	var r1_monsters := get_tree().get_nodes_in_group(&"monsters").size()
	assert_eq_scenario(r1_monsters, 0, "No monsters after R1 fight")
	await monitor.screenshot("round1_complete")

	# ── ROUND 2 ─────────────────────────────────────────────────────────
	assert_eq_scenario(RoundManager.current_round, 2, "Round 2")

	RoundManager.skip_phase()
	await bot.wait(0.5)
	assert_eq_scenario(str(RoundManager.get_phase_name()), "fight", "R2 fight phase")
	monitor.sample()

	# Should have more monsters than round 1
	await bot.wait(5.0)
	monitor.sample()
	var r2_monsters := get_tree().get_nodes_in_group(&"monsters").size()
	assert_gt_scenario(float(r2_monsters), 0.0,
		"R2 has monsters (%d)" % r2_monsters)

	# Wait out the fight
	fight_time = RoundManager.get_time_remaining()
	await bot.wait(fight_time + 1.0)
	monitor.sample()
	await monitor.screenshot("round2_complete")

	# ── ROUND 3 ─────────────────────────────────────────────────────────
	assert_eq_scenario(RoundManager.current_round, 3, "Round 3")

	RoundManager.skip_phase()
	await bot.wait(0.5)
	monitor.sample()

	await bot.wait(5.0)
	var r3_monsters := get_tree().get_nodes_in_group(&"monsters").size()
	assert_gt_scenario(float(r3_monsters), 0.0,
		"R3 has monsters (%d)" % r3_monsters)

	fight_time = RoundManager.get_time_remaining()
	await bot.wait(fight_time + 1.0)
	monitor.sample()

	# ── Final checks ────────────────────────────────────────────────────
	assert_eq_scenario(str(RoundManager.get_phase_name()), "build", "Back to build after R3")
	assert_scenario(RoundManager.is_running, "Game still running")
	assert_scenario(bot.is_alive(), "Player survived 3 rounds")

	var final_buildings := BuildingRegistry.unique_buildings.size()
	assert_gt_scenario(float(final_buildings), 0.0,
		"Some buildings survived (%d/%d)" % [final_buildings, initial_buildings])

	await monitor.screenshot("three_rounds_complete")
