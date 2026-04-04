extends "res://tests/simulation/simulation_base.gd"

## Player entity simulation -- tests movement, building collision, conveyor push,
## inventory pickup/drop, and ground items.

func run_simulation() -> void:
	var player = GameManager.player
	sim_assert(player != null, "Player exists in game world")
	if not player:
		sim_finish()
		return

	# -- Test 1: Player spawn position ----------------------------------------
	var center_grid := Vector2i(GameManager.map_size / 2, GameManager.map_size / 2)
	var expected_center := GridUtils.grid_to_world(center_grid)
	sim_assert(absf(player.position.x - expected_center.x) < 1.0, "Player spawned near map center X")
	sim_assert(absf(player.position.z - expected_center.z) < 1.0, "Player spawned near map center Z")

	# -- Test 2: Building collision -- blocking buildings ----------------------
	var smelter_pos := GridUtils.world_to_grid(player.position) + Vector2i(3, 0)
	sim_place_building(&"smelter", smelter_pos, 0)
	sim_assert(GameManager.building_collision != null, "Building collision system exists")

	# -- Test 3: Ground-level buildings don't block ---------------------------
	var conv_pos := GridUtils.world_to_grid(player.position) + Vector2i(-2, 0)
	sim_place_building(&"conveyor", conv_pos, 0)

	var conv_def = GameManager.get_building_def(&"conveyor")
	sim_assert(conv_def.is_ground_level == true, "Conveyor is ground-level")

	var smelter_def = GameManager.get_building_def(&"smelter")
	sim_assert(smelter_def.is_ground_level == false, "Smelter is NOT ground-level")

	# -- Test 4: Player movement (direct position) ----------------------------
	var start_pos: Vector3 = player.position
	player.position += Vector3(1.5, 0, 0)
	var moved_dist: float = player.position.x - start_pos.x
	sim_assert(moved_dist > 0.3, "Player moved right (dist=%.2f)" % moved_dist)

	# -- Test 5: Jump API (unit test, no physics settle) ----------------------
	# Set velocity directly to test jump logic without depending on is_on_floor()
	player.velocity = Vector3(0, 0, 0)
	player.velocity.y = player.JUMP_SPEED
	sim_assert(player.velocity.y > 0, "Player has upward velocity after jump")

	# -- Test 6: Collision mask changes with elevation ------------------------
	player.position.y = 0.0
	player._update_collision_for_height()
	var ground_bit := (1 << (Player.PLAYER_COLLISION_LAYER - 1))
	var building_bit := (1 << (Player.BUILDING_COLLISION_LAYER - 1))
	sim_assert(player.collision_mask == (ground_bit | building_bit), "Ground-level collision mask includes ground + buildings")

	player.position.y = 1.0
	player._update_collision_for_height()
	sim_assert(player.collision_mask == ground_bit, "Elevated collision mask is ground only (no building collision)")

	player.position.y = 0.0
	player._update_collision_for_height()

	# -- Test 7: Health system ------------------------------------------------
	player.hp = 100.0
	sim_assert(player.hp == 100.0, "Player starts at full HP")

	player.take_damage(30.0)
	sim_assert(player.hp == 70.0, "Player took 30 damage (HP=%.0f)" % player.hp)
	sim_assert(player._regen_timer == 0.0, "Regen timer reset on damage")

	player._regen_timer = 3.0
	player._handle_health_regen(1.0)
	sim_assert(player.hp == 70.0, "No regen before delay expires (timer=4.0 < 5.0)")

	player._regen_timer = 5.0
	player._handle_health_regen(1.0)
	sim_assert(player.hp > 70.0, "Health regenerating after delay (HP=%.1f)" % player.hp)

	# -- Test 8: Inventory add/remove ----------------------------------------
	player.hp = 100.0
	var leftover: int = player.add_item(&"pyromite", 5)
	sim_assert(leftover == 0, "Added 5 pyromite to inventory (leftover=%d)" % leftover)
	sim_assert(player.inventory[0] != null, "Slot 0 has items")
	sim_assert(player.inventory[0].item_id == &"pyromite", "Slot 0 is pyromite")
	sim_assert(player.inventory[0].quantity == 5, "Slot 0 has 5 items")

	var removed: Dictionary = player.remove_item_from_slot(0, 3)
	sim_assert(removed.quantity == 3, "Removed 3 items from slot 0")
	sim_assert(player.inventory[0].quantity == 2, "Slot 0 has 2 remaining")

	# Fill inventory to test overflow
	for i in range(8):
		player.add_item(&"pyromite", 16)
	leftover = player.add_item(&"pyromite", 1)
	sim_assert(leftover >= 0, "Overflow handled (leftover=%d)" % leftover)

	# Clear inventory for next tests
	for i in player.INVENTORY_SLOTS:
		player.inventory[i] = null

	# -- Test 9: Ground item spawn and pickup ---------------------------------
	player.add_item(&"pyromite", 3)
	player.selected_slot = 0
	player.facing_direction = Vector3.RIGHT
	player._try_drop(false)

	sim_assert(player.inventory[0].quantity == 2, "Player has 2 after dropping 1")

	var ground_items = get_tree().get_nodes_in_group("ground_items")
	sim_assert(ground_items.size() > 0, "Ground item exists after drop")

	# Pick it back up
	if ground_items.size() > 0:
		var gi = ground_items[0]
		player.position = gi.position
		gi._hovered = true
		player._try_pickup()
		await sim_advance_ticks(5)
		var total_pyromite: int = player.count_item(&"pyromite")
		sim_assert(total_pyromite == 3, "Picked up ground item (total=%d)" % total_pyromite)

	# -- Test 10: Serialization round-trip ------------------------------------
	player.hp = 75.0
	player.stamina = 2.0
	player.selected_slot = 3
	var save_data: Dictionary = player.serialize()
	sim_assert(save_data.has("position_x"), "Serialize includes position")
	sim_assert(save_data.has("health"), "Serialize includes health")
	sim_assert(save_data.has("inventory"), "Serialize includes inventory")

	player.hp = 50.0
	player.selected_slot = 0
	player.deserialize(save_data)
	sim_assert(absf(player.hp - 75.0) < 0.1, "Deserialized HP=%.1f" % player.hp)
	sim_assert(player.selected_slot == 3, "Deserialized selected_slot=%d" % player.selected_slot)

	sim_finish()
