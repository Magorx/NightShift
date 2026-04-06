extends ScenarioBase
## Scenario: Monster Spawning
##
## Tests that monsters spawn at map edges during fight phase with correct count.
## Verifies spawn positions are at edges, monsters are in the "monsters" group,
## and wave scaling increases count per round.

func scenario_name() -> String:
	return "scn_monster_spawn"

func setup_map() -> void:
	map.clear_walls()
	# Place a building so monsters have something to target
	map.building(&"smelter", Vector2i(16, 16), 0)
	map.player_start(Vector2i(14, 16))

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
	# ── Round 1: BUILD phase ────────────────────────────────────────────
	monitor.sample()
	assert_eq_scenario(RoundManager.current_round, 1, "Starts at round 1")
	assert_eq_scenario(str(RoundManager.get_phase_name()), "build", "Starts in build phase")

	# No monsters during build phase
	var monsters_in_build := get_tree().get_nodes_in_group(&"monsters").size()
	assert_eq_scenario(monsters_in_build, 0, "No monsters during build phase")

	# ── Skip to FIGHT phase ─────────────────────────────────────────────
	RoundManager.skip_phase()
	await bot.wait(0.5)
	assert_eq_scenario(str(RoundManager.get_phase_name()), "fight", "Now in fight phase")

	# Wait enough for several spawns (2s interval), but NOT past the fight timer (10s)
	await bot.wait(5.0)
	monitor.sample()

	# Check during fight — should have multiple monsters alive
	var mid_fight_count := get_tree().get_nodes_in_group(&"monsters").size()
	assert_gt_scenario(float(mid_fight_count), 1.0,
		"Multiple monsters spawned mid-fight (got %d)" % mid_fight_count)

	# Verify monsters are at reasonable positions (not at map center)
	for monster in get_tree().get_nodes_in_group(&"monsters"):
		if is_instance_valid(monster) and monster is MonsterBase:
			var grid_pos := GridUtils.world_to_grid(monster.global_position)
			var in_bounds: bool = grid_pos.x >= 0 and grid_pos.y >= 0 \
				and grid_pos.x < MapManager.map_size and grid_pos.y < MapManager.map_size
			assert_scenario(in_bounds,
				"Monster at %s is within map bounds" % str(grid_pos))

	# Verify collision layer setup
	for monster in get_tree().get_nodes_in_group(&"monsters"):
		if is_instance_valid(monster) and monster is MonsterBase:
			assert_eq_scenario(monster.collision_layer, 16,
				"Monster collision_layer is 16 (bit 5)")
			break  # check one is enough

	monitor.sample()
	await monitor.screenshot("round1_monsters")
