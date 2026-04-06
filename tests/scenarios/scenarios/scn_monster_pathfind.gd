extends ScenarioBase
## Scenario: Monster Pathfinding
##
## Tests that monsters navigate toward buildings using A* pathfinding.
## Places a building, spawns a monster manually, verifies it moves toward the building.

func scenario_name() -> String:
	return "scn_monster_pathfind"

func setup_map() -> void:
	map.clear_walls()
	# Target building at center
	map.building(&"smelter", Vector2i(16, 16), 0)
	map.player_start(Vector2i(10, 10))

func setup_monitors() -> void:
	monitor.track("monster_count", func() -> int:
		return get_tree().get_nodes_in_group(&"monsters").size()
	)

func run_scenario() -> void:
	# Don't use the spawner — manually create a monster for controlled testing
	var pathfinding := MonsterPathfinding.new()
	pathfinding.rebuild()

	# Spawn a monster far from the building
	var monster := TendrilCrawler.new()
	monster.pathfinding = pathfinding
	var spawn_grid := Vector2i(5, 16)
	monster.global_position = GridUtils.grid_to_world(spawn_grid) + Vector3(0.0, 0.1, 0.0)
	GameManager.item_layer.add_child(monster)

	await bot.wait(0.5)
	monitor.sample()
	assert_eq_scenario(get_tree().get_nodes_in_group(&"monsters").size(), 1,
		"One monster spawned")

	# Record starting position
	var start_pos := monster.global_position
	var building_pos := GridUtils.grid_to_world(Vector2i(16, 16))

	# Wait and verify monster moves toward the building
	await bot.wait(3.0)
	monitor.sample()

	if is_instance_valid(monster):
		var current_pos := monster.global_position
		var start_dist := start_pos.distance_to(building_pos)
		var current_dist := current_pos.distance_to(building_pos)

		assert_scenario(current_dist < start_dist,
			"Monster moved closer to building (%.1f -> %.1f)" % [start_dist, current_dist])
		assert_scenario(monster.state != MonsterBase.State.IDLE,
			"Monster is not idle (state=%d)" % monster.state)

		await monitor.screenshot("monster_moving")

		# Wait longer for monster to reach building
		await bot.wait(6.0)

		if is_instance_valid(monster):
			var final_dist := monster.global_position.distance_to(building_pos)
			assert_scenario(final_dist < 2.0,
				"Monster reached near building (dist=%.1f)" % final_dist)
			await monitor.screenshot("monster_at_building")
	else:
		assert_scenario(false, "Monster should still be alive")
