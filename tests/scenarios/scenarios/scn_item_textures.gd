extends ScenarioBase
## Scenario: Item Texture Showcase
##
## Spawns all 6 elemental resource items on flat ground in a row
## for close-up visual inspection of their procedural textures.
## Takes screenshots from multiple angles.

func scenario_name() -> String:
	return "scn_item_textures"

func setup_map() -> void:
	map.clear_walls()
	# Player starts at a good vantage point
	map.player_start(Vector2i(10, 14))

func setup_monitors() -> void:
	monitor.track("physics_items", func() -> int:
		return get_tree().get_nodes_in_group(&"physics_items").size())

func run_scenario() -> void:
	# Spawn all 6 base items in a row, spaced 2 tiles apart
	var items: Array[StringName] = [
		&"pyromite", &"crystalline", &"biovine",
		&"voltite", &"umbrite", &"resonite",
	]

	var start_x := 8
	var row_y := 10
	for i in items.size():
		var pos := Vector2i(start_x + i * 2, row_y)
		map.spawn_item(pos, items[i])
		# Spawn a second one slightly offset so we see them from different angles
		var pos2 := Vector2i(start_x + i * 2, row_y + 1)
		map.spawn_item(pos2, items[i])

	# Let items settle
	await bot.wait(1.5)
	monitor.sample()

	# Position camera close for detail view
	var cam: GameCamera = game_world.camera
	if cam:
		cam.size = 8.0
		cam._target_size = 8.0
		var center_world := GridUtils.grid_to_world(Vector2i(13, 10))
		cam.snap_to_3d(center_world)

	await bot.wait(0.5)
	await monitor.screenshot("01_all_items_overview")

	# Zoom into first 3 items (pyromite, crystalline, biovine)
	if cam:
		cam.size = 5.0
		cam._target_size = 5.0
		var left_world := GridUtils.grid_to_world(Vector2i(10, 10))
		cam.snap_to_3d(left_world)
	await bot.wait(0.5)
	await monitor.screenshot("02_fire_ice_nature")

	# Zoom into last 3 items (voltite, umbrite, resonite)
	if cam:
		var right_world := GridUtils.grid_to_world(Vector2i(16, 10))
		cam.snap_to_3d(right_world)
	await bot.wait(0.5)
	await monitor.screenshot("03_lightning_shadow_force")

	# Ultra close-up on individual items
	if cam:
		cam.size = 3.0
		cam._target_size = 3.0

	for i in items.size():
		var pos := Vector2i(start_x + i * 2, row_y)
		var world_pos := GridUtils.grid_to_world(pos)
		if cam:
			cam.snap_to_3d(world_pos)
		await bot.wait(0.3)
		await monitor.screenshot("04_closeup_%s" % items[i])

	# Verify all items spawned
	monitor.sample()
	monitor.assert_gt("physics_items", 10.0, "All items spawned (12 expected)")
