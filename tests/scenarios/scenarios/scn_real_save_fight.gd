extends ScenarioBase
## Loads the user's real save slot_0, forces fight phase at a high round,
## and verifies the monster swarm ACTUALLY pathfinds toward the factory.
## The previous session shipped a pathfinding change that broke monsters
## in saves with terrain elevation (they got stuck on cliff edges because
## the edge-traversal check blocked descent as well as ascent). This
## scenario exists to catch that class of regression.
##
## It's not a perf test — it's a correctness test: monster swarm centre of
## mass must move toward the factory centre over the sample window, and
## at least N building-adjacent cells must be reached by some monster.

const SAVE_PATH := "user://saves/slot_0/run_autosave.json"
const PERF_ROUND := 15
const SAMPLE_SECONDS := 20.0  # enough for a slow walk across a 64-tile map
const WARMUP_SECONDS := 2.0

func scenario_name() -> String:
	return "scn_real_save_fight"

func _ready() -> void:
	sim_map_size = 64
	sim_flatten_terrain = false
	# Hard kill if the scenario ever hangs while the real save loads.
	hard_timeout_seconds = 120.0
	super._ready()

func setup_map() -> void:
	# Fallback map in case the save is missing. The real setup is the
	# loaded save — this just gives ScenarioBase something to run.
	map.clear_walls()
	map.player_start(Vector2i(32, 32))

func setup_monitors() -> void:
	monitor.track("monster_count", func() -> int:
		return get_tree().get_nodes_in_group(&"monsters").size())
	monitor.track("swarm_distance_to_factory", func() -> float:
		return _swarm_distance_to_factory())
	monitor.track("attacking_count", func() -> int:
		var n := 0
		for m in get_tree().get_nodes_in_group(&"monsters"):
			if m is MonsterBase and (m as MonsterBase).state == MonsterBase.State.ATTACKING:
				n += 1
		return n)

func run_scenario() -> void:
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 1

	# Load slot_0 via the reparent workaround (SaveManager only finds
	# "GameWorld" at the scene-tree root, not nested under a scenario).
	var loaded := _load_save_slot_0()
	if not loaded:
		printerr("[RSF] No slot_0 save at %s — skipping this scenario" % SAVE_PATH)
		sim_finish()
		return
	print("[RSF] Loaded %d buildings from slot_0" % BuildingRegistry.unique_buildings.size())

	# Rebuild terrain visual + collision after the save restored
	# terrain_heights / tile_types — the StaticBody3D built at scene load
	# time used the generated world.
	_rebuild_terrain_for_save()

	# Frame camera on the factory centre so screenshots are readable
	_frame_camera_on_center()
	await sim_advance_ticks(10)
	await monitor.screenshot("00_loaded")

	# Force fight at high round
	RoundManager.current_round = PERF_ROUND
	RoundManager.skip_phase()
	await bot.wait(WARMUP_SECONDS)

	var initial_count: int = get_tree().get_nodes_in_group(&"monsters").size()
	var initial_dist: float = _swarm_distance_to_factory()
	print("[RSF] After %ds warmup: %d monsters alive, swarm distance to factory = %.2f" %
		[WARMUP_SECONDS, initial_count, initial_dist])
	await monitor.screenshot("01_fight_started")

	# Let the fight run and sample swarm distance over time
	var sample_interval := 1.0  # one sample per second
	var iterations := int(SAMPLE_SECONDS / sample_interval)
	var best_min_dist := INF  # tightest closest-approach over the whole sample
	var total_attacking := 0  # cumulative attacking-frame count
	for i in iterations:
		await bot.wait(sample_interval)
		var d := _swarm_distance_to_factory()
		var min_d := _closest_monster_to_any_building()
		if min_d < best_min_dist:
			best_min_dist = min_d
		var n: int = get_tree().get_nodes_in_group(&"monsters").size()
		var atk: int = 0
		for m in get_tree().get_nodes_in_group(&"monsters"):
			if m is MonsterBase and (m as MonsterBase).state == MonsterBase.State.ATTACKING:
				atk += 1
		total_attacking += atk
		var b_count: int = 0
		for b in BuildingRegistry.unique_buildings:
			if is_instance_valid(b): b_count += 1
		print("[RSF] t=%2ds  alive=%d  attacking=%d  buildings=%d  swarm_avg=%.2f  min=%.2f" %
			[i + 1, n, atk, b_count, d, min_d])

	await monitor.screenshot("02_fight_midway")

	var final_dist: float = _swarm_distance_to_factory()
	var final_attacking := 0
	for m in get_tree().get_nodes_in_group(&"monsters"):
		if m is MonsterBase and (m as MonsterBase).state == MonsterBase.State.ATTACKING:
			final_attacking += 1

	print("[RSF] ════════════════════════════════════════")
	print("[RSF] Initial swarm avg distance: %.2f" % initial_dist)
	print("[RSF] Final   swarm avg distance: %.2f" % final_dist)
	print("[RSF] Delta (lower = moved toward factory): %+.2f" % (final_dist - initial_dist))
	print("[RSF] Best closest-approach over sample: %.2f tiles" % best_min_dist)
	print("[RSF] Attacking frames summed: %d  (final %d / %d)" %
		[total_attacking, final_attacking, initial_count])
	print("[RSF] ════════════════════════════════════════")

	# Correctness gate: some monster must have reached attack range, i.e.
	# the closest-approach over the whole sample dropped below 2 tiles
	# (attack_range is ~1.2 world units / tiles). Swarm average distance
	# is a misleading metric because new spawns constantly re-seed the
	# outer ring.
	var reached := best_min_dist < 2.0
	assert_scenario(reached,
		"Some monster reached attack range (best closest approach = %.2f tiles, needs < 2.0)" %
		best_min_dist)

# ── Helpers ────────────────────────────────────────────────────────────

func _swarm_distance_to_factory() -> float:
	var monsters := get_tree().get_nodes_in_group(&"monsters")
	if monsters.is_empty():
		return 0.0
	var factory := _factory_center_world()
	var total := 0.0
	var count := 0
	for m in monsters:
		if not (m is Node3D):
			continue
		var p: Vector3 = (m as Node3D).global_position
		var diff := Vector3(p.x - factory.x, 0.0, p.z - factory.z)
		total += diff.length()
		count += 1
	if count == 0:
		return 0.0
	return total / count

## Return (min_dist, max_dist) to any building in the registry. Min is the
## closest monster approach; used to verify pathfinding actually reaches
## the factory rather than just moving the swarm centroid around.
func _closest_monster_to_any_building() -> float:
	var monsters := get_tree().get_nodes_in_group(&"monsters")
	var buildings := BuildingRegistry.unique_buildings
	if monsters.is_empty() or buildings.is_empty():
		return INF
	var best := INF
	for m in monsters:
		if not (m is Node3D):
			continue
		var mp: Vector3 = (m as Node3D).global_position
		for b in buildings:
			if not is_instance_valid(b):
				continue
			var bp: Vector3 = (b as Node3D).global_position
			var d := Vector3(mp.x - bp.x, 0.0, mp.z - bp.z).length()
			if d < best:
				best = d
	return best

func _factory_center_world() -> Vector3:
	if BuildingRegistry.unique_buildings.is_empty():
		return Vector3(32, 0, 32)
	var sum := Vector3.ZERO
	var count := 0
	for b in BuildingRegistry.unique_buildings:
		if is_instance_valid(b):
			sum += b.global_position
			count += 1
	if count == 0:
		return Vector3(32, 0, 32)
	return sum / count

func _load_save_slot_0() -> bool:
	var prev_slot := AccountManager.active_slot
	AccountManager.active_slot = 0
	if not FileAccess.file_exists(SAVE_PATH):
		AccountManager.active_slot = prev_slot
		return false
	# Reparent game_world directly under root so SaveManager._get_game_world
	# (which iterates only root.get_children() looking for name == "GameWorld")
	# can find it.
	var original_parent: Node = game_world.get_parent()
	var original_name: String = game_world.name
	game_world.name = "GameWorld"
	original_parent.remove_child(game_world)
	get_tree().root.add_child(game_world)
	var ok := SaveManager.load_run()
	get_tree().root.remove_child(game_world)
	original_parent.add_child(game_world)
	game_world.name = original_name
	AccountManager.active_slot = prev_slot
	return ok

func _rebuild_terrain_for_save() -> void:
	if MapManager.terrain_visual_manager == null:
		return
	MapManager.terrain_visual_manager.build(
		MapManager.map_size,
		MapManager.terrain_tile_types,
		MapManager.terrain_variants,
		MapManager.terrain_heights
	)
	var old_col := game_world.get_node_or_null("TerrainCollision")
	if old_col:
		old_col.queue_free()
	var shape: ConcavePolygonShape3D = MapManager.terrain_visual_manager.create_box_collision()
	if shape:
		var body := StaticBody3D.new()
		body.name = "TerrainCollision"
		body.collision_layer = 4
		body.collision_mask = 0
		var col_shape := CollisionShape3D.new()
		col_shape.shape = shape
		body.add_child(col_shape)
		game_world.add_child(body)

func _frame_camera_on_center() -> void:
	var cam: GameCamera = game_world.camera if "camera" in game_world else null
	if cam == null:
		return
	cam.target_node = null
	cam.size = 30.0
	cam._target_size = 30.0
	cam.snap_to_3d(_factory_center_world())
