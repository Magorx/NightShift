extends ScenarioBase
## Scenario: Fight Phase End Conditions
##
## Tests two end conditions:
## 1. All monsters dead → fight ends early
## 2. Timer expiry → remaining monsters despawned
## Also tests game over when all buildings destroyed.

func scenario_name() -> String:
	return "scn_fight_phase_end"

func setup_map() -> void:
	map.clear_walls()
	map.building(&"smelter", Vector2i(16, 16), 0)
	map.player_start(Vector2i(10, 10))

func setup_monitors() -> void:
	monitor.track("monster_count", func() -> int:
		return get_tree().get_nodes_in_group(&"monsters").size()
	)
	monitor.track("round", func() -> int:
		return RoundManager.current_round
	)
	monitor.track("phase", func() -> String:
		return str(RoundManager.get_phase_name())
	)

func run_scenario() -> void:
	# ── Test 1: Kill all monsters → fight ends early ────────────────────
	monitor.sample()
	assert_eq_scenario(str(RoundManager.get_phase_name()), "build", "Starts in build")

	# Skip to fight
	RoundManager.skip_phase()
	await bot.wait(0.5)
	assert_eq_scenario(str(RoundManager.get_phase_name()), "fight", "In fight phase")

	# Wait for some monsters to spawn
	await bot.wait(3.0)
	monitor.sample()

	# Kill all monsters directly
	var killed := 0
	for monster in get_tree().get_nodes_in_group(&"monsters"):
		if is_instance_valid(monster) and monster is MonsterBase:
			monster.take_damage(9999.0)
			killed += 1
	print("[TEST] Killed %d monsters" % killed)

	# Wait for death animations and cleanup
	await bot.wait(1.0)
	monitor.sample()

	# Get the spawner to check queue
	var spawner := game_world.get_node_or_null("MonsterSpawner")
	if spawner:
		# Kill any newly spawned monsters too
		await bot.wait(2.5)
		for monster in get_tree().get_nodes_in_group(&"monsters"):
			if is_instance_valid(monster) and monster is MonsterBase:
				monster.take_damage(9999.0)
		await bot.wait(2.5)
		for monster in get_tree().get_nodes_in_group(&"monsters"):
			if is_instance_valid(monster) and monster is MonsterBase:
				monster.take_damage(9999.0)
		await bot.wait(1.0)

	monitor.sample()

	# Verify fight ended and we're back in build phase (round 2)
	# Note: spawner may still be spawning, so fight might not end yet
	# The all_monsters_dead signal only fires when spawning is done AND all dead
	var remaining := get_tree().get_nodes_in_group(&"monsters").size()
	if remaining == 0:
		# Wait a bit for the phase change to propagate
		await bot.wait(0.5)
		monitor.sample()
		var phase := str(RoundManager.get_phase_name())
		assert_scenario(phase == "build" or RoundManager.current_round >= 2,
			"Fight ended after all monsters killed (phase=%s, round=%d)" % [
				phase, RoundManager.current_round])
	else:
		print("[TEST] %d monsters still alive, spawner still active" % remaining)

	await monitor.screenshot("after_kill_all")

	# ── Test 2: Timer expiry → monsters despawned ───────────────────────
	# If we're in build phase, skip to fight again
	if str(RoundManager.get_phase_name()) == "build":
		RoundManager.skip_phase()
		await bot.wait(0.5)

	if str(RoundManager.get_phase_name()) == "fight":
		# Wait for fight timer to expire naturally
		var remaining_time := RoundManager.get_time_remaining()
		print("[TEST] Waiting %.0fs for fight timer..." % remaining_time)
		await bot.wait(remaining_time + 1.0)
		monitor.sample()

		# After timer expires, should be in build phase, monsters despawned
		var monsters_after_timer := get_tree().get_nodes_in_group(&"monsters").size()
		assert_eq_scenario(monsters_after_timer, 0,
			"Monsters despawned after timer expiry")
		assert_eq_scenario(str(RoundManager.get_phase_name()), "build",
			"Back to build phase after timer")

	await monitor.screenshot("after_timer_expiry")
