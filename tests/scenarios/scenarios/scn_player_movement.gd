extends ScenarioBase
## Scenario: Player Movement + Physics
##
## Tests player physical movement through the world:
## - Walking to specific positions
## - Jumping (peak height check)
## - Collision with elevated buildings (smelter)
## - Sprinting and stamina drain
## - Health, damage, and regen
## - Inventory drop/pickup

func scenario_name() -> String:
	return "scn_player_movement"

func setup_map() -> void:
	map.clear_walls()

	# Smelter (elevated, should block player)
	map.building(&"smelter", Vector2i(14, 14), 0)

	# Player starts at (10, 10)
	map.player_start(Vector2i(10, 10))

func setup_monitors() -> void:
	monitor.track("player_x", func() -> float:
		return GameManager.player.position.x
	)
	monitor.track("player_z", func() -> float:
		return GameManager.player.position.z
	)
	monitor.track("player_y", func() -> float:
		return GameManager.player.position.y
	)
	monitor.track("player_hp", func() -> float:
		return GameManager.player.hp
	)
	monitor.track("stamina", func() -> float:
		return GameManager.player.stamina
	)

func run_scenario() -> void:
	var player: Player = GameManager.player

	# ── Test 1: Basic walk ───────────────────────────────────────────────
	monitor.sample()
	var start_pos: Vector3 = bot.get_world_pos()

	var arrived := await bot.walk_to(Vector2i(12, 10))
	assert_scenario(arrived, "Walked to (12,10)")

	var walked_dist: float = bot.get_world_pos().distance_to(start_pos)
	assert_gt_scenario(walked_dist, 1.0, "Actually moved (dist=%.2f)" % walked_dist)

	monitor.sample()

	# ── Test 2: Walk further (no obstacles) ──────────────────────────────
	arrived = await bot.walk_to(Vector2i(8, 10))
	assert_scenario(arrived, "Walked back to (8,10)")

	monitor.sample()
	await monitor.screenshot("basic_walk")

	# ── Test 3: Jump ─────────────────────────────────────────────────────
	# Ensure player is on floor first
	await bot.tick(5)
	var pre_jump_y: float = player.position.y
	var jumped := await bot.jump()
	assert_scenario(jumped, "Jump initiated")

	# At 10x timescale, jump peaks in ~2 ticks — check immediately after jump starts
	var peak_y: float = player.position.y
	assert_gt_scenario(peak_y, pre_jump_y + 0.05, "Player rose during jump (y=%.3f)" % peak_y)

	# Wait for landing
	await bot.wait_until(func() -> bool: return player.is_on_floor(), 3.0)
	assert_scenario(player.is_on_floor(), "Player landed")

	monitor.sample()

	# ── Test 4: Walk toward smelter (elevated, should block) ─────────────
	arrived = await bot.walk_to(Vector2i(13, 14))
	assert_scenario(arrived, "Walked near smelter")

	# Try to walk into the smelter — should be blocked by collision
	player.velocity = Vector3(Player.BASE_SPEED, 0, 0)
	await bot.tick(30)
	player.velocity = Vector3.ZERO

	# Player should not have passed through the smelter
	var smelter_world: Vector3 = GridUtils.grid_to_world(Vector2i(14, 14))
	var dist_to_smelter: float = Vector2(
		player.position.x - smelter_world.x,
		player.position.z - smelter_world.z
	).length()
	assert_gt_scenario(dist_to_smelter, 0.2, "Player blocked by smelter (dist=%.2f)" % dist_to_smelter)

	monitor.sample()
	await monitor.screenshot("blocked_by_smelter")

	# ── Test 5: Sprint and stamina ───────────────────────────────────────
	await bot.walk_to(Vector2i(10, 10))  # reset position
	var stamina_before: float = player.stamina

	arrived = await bot.sprint_to(Vector2i(10, 16))
	assert_scenario(arrived, "Sprinted to (10,16)")
	assert_scenario(player.stamina < stamina_before, "Stamina drained after sprint (%.2f -> %.2f)" % [stamina_before, player.stamina])

	monitor.sample()

	# ── Test 6: Damage and regen ─────────────────────────────────────────
	assert_eq_scenario(bot.get_hp(), 100.0, "Player at full HP")

	bot.take_damage(40.0)
	assert_eq_scenario(bot.get_hp(), 60.0, "Took 40 damage")

	# Wait for regen (5s delay + some regen time)
	await bot.wait(7.0)
	assert_gt_scenario(bot.get_hp(), 60.0, "HP regenerated (hp=%.1f)" % bot.get_hp())

	monitor.sample()
	await monitor.screenshot("after_regen")

	# ── Test 7: Inventory round-trip ─────────────────────────────────────
	bot.give_item(&"pyromite", 5)
	assert_eq_scenario(bot.item_count(&"pyromite"), 5, "5 pyromite in inventory")

	bot.face(Vector3.RIGHT)
	await bot.drop(false)  # drop 1
	assert_eq_scenario(bot.item_count(&"pyromite"), 4, "4 pyromite after drop")

	# Walk to where item was dropped and pick up
	await bot.tick(30)  # let physics item settle
	await bot.pickup()

	monitor.sample()
	await monitor.screenshot("final_state")

	assert_scenario(bot.is_alive(), "Player alive at end")
