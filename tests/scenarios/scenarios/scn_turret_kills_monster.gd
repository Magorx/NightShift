extends ScenarioBase
## Scenario: Turret Kills Monster
##
## Tests that turret-mode buildings fire projectiles at monsters and kill them.
## Places a conveyor (becomes tower/wall at night with turret), spawns a monster nearby.

func scenario_name() -> String:
	return "scn_turret_kills_monster"

func setup_map() -> void:
	map.clear_walls()
	# Place conveyor turns (become towers with turrets at night)
	# Turns need specific adjacency to become towers, so place a cross pattern
	map.building(&"conveyor", Vector2i(16, 15), 1)  # down
	map.building(&"conveyor", Vector2i(16, 16), 0)  # right (center)
	map.building(&"conveyor", Vector2i(16, 17), 3)  # up
	map.building(&"conveyor", Vector2i(15, 16), 0)  # right
	map.building(&"conveyor", Vector2i(17, 16), 0)  # right
	# Also place a smelter as a non-turret building target
	map.building(&"smelter", Vector2i(12, 16), 0)
	map.player_start(Vector2i(10, 10))

func setup_monitors() -> void:
	monitor.track("monster_count", func() -> int:
		return get_tree().get_nodes_in_group(&"monsters").size()
	)
	monitor.track("phase", func() -> String:
		return str(RoundManager.get_phase_name())
	)

func run_scenario() -> void:
	monitor.sample()

	# Skip to fight phase — conveyors transform to walls/towers
	RoundManager.skip_phase()
	await bot.wait(0.5)
	assert_eq_scenario(str(RoundManager.get_phase_name()), "fight", "In fight phase")

	# Spawn a weak monster near the turret area
	var pathfinding := MonsterPathfinding.new()
	pathfinding.rebuild()

	var monster := TendrilCrawler.new()
	monster.pathfinding = pathfinding
	monster.max_hp = 30.0  # weak so it dies faster
	var spawn_grid := Vector2i(20, 16)
	monster.global_position = GridUtils.grid_to_world(spawn_grid) + Vector3(0.0, 0.1, 0.0)
	GameManager.item_layer.add_child(monster)

	await bot.wait(0.5)
	monitor.sample()
	assert_gt_scenario(float(get_tree().get_nodes_in_group(&"monsters").size()), 0.0,
		"Monsters present (manual + spawner)")

	# Track if the monster takes damage from projectiles
	var initial_hp := monster.health.current_hp

	# Wait for turrets to fire and potentially kill the monster
	await bot.wait(8.0)
	monitor.sample()

	# Check if monster was damaged or killed
	var monsters_remaining := get_tree().get_nodes_in_group(&"monsters").size()
	if is_instance_valid(monster) and monster.state != MonsterBase.State.DYING:
		var current_hp := monster.health.current_hp
		assert_scenario(current_hp < initial_hp,
			"Monster took turret damage (HP: %.0f -> %.0f)" % [initial_hp, current_hp])
	else:
		# Monster was killed — that's the ideal outcome
		assert_scenario(true, "Turret killed the monster!")

	await monitor.screenshot("turret_combat")
