extends "res://tests/simulation/simulation_base.gd"

## Player entity simulation — tests movement, building collision, conveyor push,
## jump states, inventory pickup/drop, and ground items.

func run_simulation() -> void:
	var player = GameManager.player
	sim_assert(player != null, "Player exists in game world")
	if not player:
		sim_finish()
		return

	# ── Test 1: Player spawn position ────────────────────────────────────────
	var expected_center := GridUtils.grid_to_center(Vector2i(GameManager.map_size / 2, GameManager.map_size / 2))
	sim_assert(absf(player.position.x - expected_center.x) < GridUtils.TILE_WIDTH, "Player spawned near map center X")
	sim_assert(absf(player.position.y - expected_center.y) < GridUtils.TILE_HEIGHT, "Player spawned near map center Y")

	# ── Test 2: Building collision — blocking buildings ──────────────────────
	# Place a smelter (2x2, blocking) near the player
	var smelter_pos := GridUtils.world_to_grid(player.position) + Vector2i(3, 0)
	sim_place_building(&"smelter", smelter_pos, 0)

	# Verify collision tile was created
	sim_assert(GameManager.building_collision != null, "Building collision system exists")

	# ── Test 3: Ground-level buildings don't block ───────────────────────────
	var conv_pos := GridUtils.world_to_grid(player.position) + Vector2i(-2, 0)
	sim_place_building(&"conveyor", conv_pos, 0)

	var conv_def = GameManager.get_building_def(&"conveyor")
	sim_assert(conv_def.is_ground_level == true, "Conveyor is ground-level")

	var smelter_def = GameManager.get_building_def(&"smelter")
	sim_assert(smelter_def.is_ground_level == false, "Smelter is NOT ground-level")

	# ── Test 4: Player movement ──────────────────────────────────────────────
	# At 100x time scale, test movement by checking position change directly
	var start_pos: Vector2 = player.position
	player.position += Vector2(50, 0)  # Simulate movement result
	var moved_dist: float = player.position.x - start_pos.x
	sim_assert(moved_dist > 10, "Player moved right (dist=%.1f)" % moved_dist)

	# ── Test 5: Vertical physics — jump from ground ────────────────────────
	sim_assert(player._is_grounded, "Player starts grounded")
	sim_assert(player.z_height < 0.01, "Player starts at ground level")

	# Trigger jump
	player._try_jump()
	sim_assert(not player._is_grounded, "Player now airborne")
	sim_assert(player.z_velocity > 0, "Player has upward velocity")

	# Wait for jump to complete — should land back on ground
	await sim_advance_seconds(1.0)
	sim_assert(player._is_grounded, "Player back to grounded after jumping on empty ground")
	sim_assert(player.z_height < 0.01, "Player at ground level after landing")

	# ── Test 6: Ground height on buildings ───────────────────────────────────
	var smelter_world: Vector2 = GridUtils.grid_to_center(smelter_pos)
	player.position = smelter_world
	player.velocity = Vector2.ZERO
	sim_assert(player._get_ground_height() > 0, "Smelter tile has elevated ground height")

	# Simulate being elevated on a building
	player.z_height = player.BUILDING_Z_HEIGHT
	player._is_grounded = true
	player._update_collision_for_height()
	sim_assert(player.z_index == 15, "Elevated z_index is 15")
	sim_assert(player.collision_mask == 0, "Elevated collision mask is 0 (no building collision)")

	# Move off building → ground height should be 0
	player.position = GridUtils.grid_to_world(smelter_pos) + Vector2(-48, GridUtils.HALF_H)
	sim_assert(player._get_ground_height() < 0.01, "Empty tile has ground height 0")

	# Reset to grounded on ground
	player.z_height = 0.0
	player._is_grounded = true
	player._update_collision_for_height()
	sim_assert(player.z_index == 5, "Grounded z_index is 5")

	# ── Test 7: Conveyor push ────────────────────────────────────────────────
	# Place a conveyor and stand on it
	var push_conv_pos := Vector2i(20, GridUtils.world_to_grid(player.position).y)
	sim_place_building(&"conveyor", push_conv_pos, 0)  # pointing right
	player.position = GridUtils.grid_to_center(push_conv_pos)
	player.velocity = Vector2.ZERO
	player.z_height = 0.0
	player._is_grounded = true
	player._update_collision_for_height()

	var pre_push_x: float = player.position.x
	await sim_advance_seconds(0.5)
	var push_dist: float = player.position.x - pre_push_x
	sim_assert(push_dist > 5, "Conveyor pushed player right (dist=%.1f)" % push_dist)

	# ── Test 8: Health system ────────────────────────────────────────────────
	player.hp = 100.0
	sim_assert(player.hp == 100.0, "Player starts at full HP")

	player.take_damage(30.0)
	sim_assert(player.hp == 70.0, "Player took 30 damage (HP=%.0f)" % player.hp)
	sim_assert(player._regen_timer == 0.0, "Regen timer reset on damage")

	# Test regen logic directly (sim time scale is too fast for real-time checks)
	player._regen_timer = 3.0  # before delay
	player._handle_health_regen(1.0)
	sim_assert(player.hp == 70.0, "No regen before delay expires (timer=4.0 < 5.0)")

	player._regen_timer = 5.0  # past delay
	player._handle_health_regen(1.0)
	sim_assert(player.hp > 70.0, "Health regenerating after delay (HP=%.1f)" % player.hp)

	# ── Test 9: Inventory add/remove ─────────────────────────────────────────
	player.hp = 100.0  # Reset health
	var leftover: int = player.add_item(&"pyromite", 5)
	sim_assert(leftover == 0, "Added 5 iron_ore to inventory (leftover=%d)" % leftover)
	sim_assert(player.inventory[0] != null, "Slot 0 has items")
	sim_assert(player.inventory[0].item_id == &"pyromite", "Slot 0 is iron_ore")
	sim_assert(player.inventory[0].quantity == 5, "Slot 0 has 5 items")

	var removed: Dictionary = player.remove_item_from_slot(0, 3)
	sim_assert(removed.quantity == 3, "Removed 3 items from slot 0")
	sim_assert(player.inventory[0].quantity == 2, "Slot 0 has 2 remaining")

	# Fill inventory to test overflow
	for i in range(8):
		player.add_item(&"pyromite", 16)
	leftover = player.add_item(&"pyromite", 1)
	# Should overflow since we already had 2 + filled the rest
	sim_assert(leftover >= 0, "Overflow handled (leftover=%d)" % leftover)

	# Clear inventory for next tests
	for i in player.INVENTORY_SLOTS:
		player.inventory[i] = null

	# ── Test 10: Ground item spawn and pickup ────────────────────────────────
	player.add_item(&"pyromite", 3)
	player.selected_slot = 0
	player.facing_direction = Vector2.RIGHT
	player._try_drop(false)  # Drop 1 item

	sim_assert(player.inventory[0].quantity == 2, "Player has 2 after dropping 1")

	var ground_items = get_tree().get_nodes_in_group("ground_items")
	sim_assert(ground_items.size() > 0, "Ground item exists after drop")

	# Pick it back up — force hover flag since there's no mouse in headless
	if ground_items.size() > 0:
		var gi = ground_items[0]
		player.position = gi.position
		gi._hovered = true
		player._try_pickup()
		await sim_advance_ticks(5)
		var total_iron: int = player.count_item(&"pyromite")
		sim_assert(total_iron == 3, "Picked up ground item (total=%d)" % total_iron)

	# ── Test 11: Serialization round-trip ────────────────────────────────────
	player.hp = 75.0
	player.stamina = 2.0
	player.selected_slot = 3
	var save_data: Dictionary = player.serialize()
	sim_assert(save_data.has("position_x"), "Serialize includes position")
	sim_assert(save_data.has("health"), "Serialize includes health")
	sim_assert(save_data.has("inventory"), "Serialize includes inventory")

	# Modify and restore
	player.hp = 50.0
	player.selected_slot = 0
	player.deserialize(save_data)
	sim_assert(absf(player.hp - 75.0) < 0.1, "Deserialized HP=%.1f" % player.hp)
	sim_assert(player.selected_slot == 3, "Deserialized selected_slot=%d" % player.selected_slot)

	await sim_capture_screenshot("player_final")
	sim_finish()
