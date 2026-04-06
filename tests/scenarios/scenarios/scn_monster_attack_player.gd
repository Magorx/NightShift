extends ScenarioBase
## Scenario: Monster Attacks Player
##
## Tests that monsters deal damage to the player when adjacent.
## Spawns a monster near the player, verifies player HP decreases.

func scenario_name() -> String:
	return "scn_monster_attack_player"

func setup_map() -> void:
	map.clear_walls()
	# No buildings — monster stays near player with no other target
	map.player_start(Vector2i(16, 16))

func setup_monitors() -> void:
	monitor.track("player_hp", func() -> float:
		return GameManager.player.hp
	)
	monitor.track("monster_count", func() -> int:
		return get_tree().get_nodes_in_group(&"monsters").size()
	)

func run_scenario() -> void:
	monitor.sample()
	monitor.assert_eq("player_hp", 100.0, "Player starts at full HP")

	# Spawn a monster right next to the player
	var pathfinding := MonsterPathfinding.new()
	pathfinding.rebuild()

	var monster := TendrilCrawler.new()
	monster.pathfinding = pathfinding
	# Spawn adjacent to player
	var player_grid := GridUtils.world_to_grid(GameManager.player.global_position)
	var spawn_grid := player_grid + Vector2i(1, 0)
	monster.global_position = GridUtils.grid_to_world(spawn_grid) + Vector3(0.0, 0.1, 0.0)
	GameManager.item_layer.add_child(monster)

	await bot.wait(0.5)

	# Player doesn't move — let the monster attack
	# Monster player attack cooldown is 2.0s, so wait for first attack
	await bot.wait(3.0)
	monitor.sample()

	var hp_after: float = GameManager.player.hp
	assert_scenario(hp_after < 100.0,
		"Player took damage from monster (HP=%.0f)" % hp_after)

	await monitor.screenshot("player_damaged")

	# Wait for another attack
	await bot.wait(3.0)
	monitor.sample()

	var hp_later: float = GameManager.player.hp
	assert_scenario(hp_later < hp_after,
		"Player took additional damage (HP=%.0f -> %.0f)" % [hp_after, hp_later])

	# Player should still be alive (10 damage per hit, 100 HP, 3 attacks max in 6s)
	assert_scenario(bot.is_alive(), "Player survived the attacks")

	await monitor.screenshot("player_after_combat")
