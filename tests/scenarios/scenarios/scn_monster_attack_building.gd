extends ScenarioBase
## Scenario: Monster Attacks Building
##
## Tests that a monster damages a building when adjacent.
## Spawns a monster close to a building, waits, verifies HP decreases.

func scenario_name() -> String:
	return "scn_monster_attack_building"

func setup_map() -> void:
	map.clear_walls()
	map.building(&"smelter", Vector2i(16, 16), 0)
	map.player_start(Vector2i(10, 10))

func setup_monitors() -> void:
	monitor.track("building_hp", func() -> float:
		var b = BuildingRegistry.get_building_at(Vector2i(16, 16))
		if b and b.logic and b.logic.health:
			return b.logic.health.current_hp
		return -1.0
	)
	monitor.track("monster_count", func() -> int:
		return get_tree().get_nodes_in_group(&"monsters").size()
	)

func run_scenario() -> void:
	# Check initial building HP
	monitor.sample()
	monitor.assert_eq("building_hp", 100.0, "Building starts at full HP")

	# Spawn monster right next to the building
	var pathfinding := MonsterPathfinding.new()
	pathfinding.rebuild()

	var monster := TendrilCrawler.new()
	monster.pathfinding = pathfinding
	# Place adjacent to building (1 tile away)
	var spawn_grid := Vector2i(15, 16)
	monster.global_position = GridUtils.grid_to_world(spawn_grid) + Vector3(0.0, 0.1, 0.0)
	GameManager.item_layer.add_child(monster)

	await bot.wait(0.5)
	monitor.sample()

	# Wait for monster to reach building and attack
	# attack_cooldown = 1.5s, so first attack should happen within 2-3 seconds
	await bot.wait(4.0)
	monitor.sample()

	var hp_after_val = monitor.get_value("building_hp")
	var hp_after: float = float(hp_after_val) if hp_after_val != null else -1.0
	assert_scenario(hp_after >= 0.0 and hp_after < 100.0,
		"Building took damage (HP=%.1f)" % hp_after)

	# Monster should have attacked at least twice (1.5s cooldown, 4s elapsed)
	if hp_after >= 0.0:
		var damage_taken: float = 100.0 - hp_after
		assert_gt_scenario(damage_taken, 10.0,
			"Significant damage dealt (%.1f)" % damage_taken)

	await monitor.screenshot("after_attacks")

	# Wait more and verify building can be destroyed
	await bot.wait(8.0)
	monitor.sample()

	var hp_late_val = monitor.get_value("building_hp")
	var hp_late: float = float(hp_late_val) if hp_late_val != null else -1.0
	if hp_late >= 0.0:
		assert_scenario(hp_late < hp_after,
			"Continued damage (HP=%.1f -> %.1f)" % [hp_after, hp_late])

	await monitor.screenshot("building_damaged")
