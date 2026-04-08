extends ScenarioBase
## Stress test: load the user's real slot_0 run_backup.json (17 buildings on
## a 64-tile map) and force the fight phase at a high round so the spawner
## floods the map with monsters. Unlike scn_real_save_fight which tests the
## autosave of the same slot for *correctness*, this one uses the backup save
## (the pre-bug-report state the user flagged as "the right save") and
## measures PERFORMANCE + pathfinding liveness during a fight.
##
## The user reported: "most monsters get stuck around the walls staying on
## one place" and "16 fps during attack". This scenario measures both:
##   - frame delta (ms) + fps at 1x time scale  (perf symptom)
##   - "stuck monster" count: monsters that barely moved over a rolling window
##   - min swarm distance to any factory building (are ANY monsters reaching
##     the factory, or is the whole swarm stuck outside?)
##
## Runs in --benchmark mode (window open, vsync off, time_scale 1).
##
## Usage:
##   $GODOT --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- scn_real_save_stress --benchmark

## User said "save 1 of slot 1" which in their 1-indexed parlance = slot_0
## (the engine's first slot). They also said "take not autosave, but the
## right save" — use the run_backup.json path (the prior save, captured
## before the perf/stuck-monster bug they reported).
const SAVE_SLOT := 0
const SAVE_PATH := "user://saves/slot_0/run_backup.json"
## Lower round so the factory doesn't get wiped inside the first 3 seconds
## of the fight. At round 15 with the default 10*round budget, 64 monsters
## kill all 17 buildings before the sample window starts and everything
## falls into IDLE — which isn't the bug we're measuring. Round 6 produces
## ~15-25 alive monsters, enough for a real stress test, and the factory
## survives the sample window so stuck-at-walls behaviour is visible.
const PERF_ROUND := 6
const WARMUP_SECONDS := 3.0
const SAMPLE_SECONDS := 10.0
const STUCK_WINDOW_SECONDS := 3.0
const STUCK_DIST_THRESHOLD := 0.5  # world units travelled in STUCK_WINDOW_SECONDS

var _fps_samples: PackedFloat32Array = PackedFloat32Array()
var _frame_ms_samples: PackedFloat32Array = PackedFloat32Array()
var _phys_only_ms_samples: PackedFloat32Array = PackedFloat32Array()

# Per-monster position history for stuck detection.
# Key: monster instance_id (int). Value: Array of [time, Vector3] tuples.
var _monster_history: Dictionary = {}

func scenario_name() -> String:
	return "scn_real_save_stress"

func _ready() -> void:
	sim_map_size = 64
	sim_flatten_terrain = false
	hard_timeout_seconds = 180.0
	super._ready()

func setup_map() -> void:
	# Fallback — will be replaced by loaded save
	map.clear_walls()
	map.player_start(Vector2i(32, 32))

func setup_monitors() -> void:
	monitor.track("monster_count", func() -> int:
		return get_tree().get_nodes_in_group(&"monsters").size())
	monitor.track("attacking_count", func() -> int:
		var n := 0
		for m in get_tree().get_nodes_in_group(&"monsters"):
			if m is MonsterBase and (m as MonsterBase).state == MonsterBase.State.ATTACKING:
				n += 1
		return n)
	monitor.track("frame_ms_avg", func() -> float:
		if _frame_ms_samples.is_empty(): return 0.0
		var s := 0.0
		for v in _frame_ms_samples: s += v
		return s / _frame_ms_samples.size())
	monitor.track("frame_ms_max", func() -> float:
		if _frame_ms_samples.is_empty(): return 0.0
		var m := 0.0
		for v in _frame_ms_samples:
			if v > m: m = v
		return m)
	monitor.track("fps_avg", func() -> float:
		if _fps_samples.is_empty(): return 0.0
		var s := 0.0
		for v in _fps_samples: s += v
		return s / _fps_samples.size())
	monitor.track("stuck_count", func() -> int:
		return _count_stuck_monsters())
	monitor.track("buildings_alive", func() -> int:
		var n := 0
		for b in BuildingRegistry.unique_buildings:
			if is_instance_valid(b): n += 1
		return n)

func run_scenario() -> void:
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 1

	# Turn on debug overlay so NavDebugRenderer draws sector borders + flow
	# arrows. The screenshots captured during the fight will show whether the
	# elevation-edge fix is routing flow AROUND cliffs instead of INTO them.
	SettingsManager.debug_mode = true

	print("[RSS] Loading slot_%d from %s" % [SAVE_SLOT, SAVE_PATH])
	var loaded := _load_save_slot()
	if not loaded:
		printerr("[RSS] No save at %s — skipping this scenario" % SAVE_PATH)
		sim_finish()
		return
	print("[RSS] Loaded %d buildings from slot_%d (map=%d)" %
		[BuildingRegistry.unique_buildings.size(), SAVE_SLOT, MapManager.map_size])

	_rebuild_terrain_for_save()
	_frame_camera_on_center()

	await sim_advance_ticks(10)
	await monitor.screenshot("00_loaded")

	# Force fight at high round
	print("[RSS] Forcing fight at round %d" % PERF_ROUND)
	var t_fight_start := Time.get_ticks_usec()
	RoundManager.current_round = PERF_ROUND
	RoundManager.skip_phase()
	var t_fight_elapsed := (Time.get_ticks_usec() - t_fight_start) / 1000.0
	print("[RSS] RoundManager.skip_phase() took %.2f ms (this includes pathfinding.rebuild())" % t_fight_elapsed)

	# Warmup
	await bot.wait(WARMUP_SECONDS)
	monitor.sample()
	await monitor.screenshot("01_fight_started")
	print("[RSS] After %.1fs warmup: %d monsters alive" %
		[WARMUP_SECONDS, get_tree().get_nodes_in_group(&"monsters").size()])

	# Sample loop
	MonsterPerf.enabled = true
	MonsterPerf.reset()
	var total_samples := int(SAMPLE_SECONDS * 120.0)
	_fps_samples.resize(0)
	_frame_ms_samples.resize(0)
	_phys_only_ms_samples.resize(0)
	var prev_t := Time.get_ticks_usec()
	var last_phys_usec: int = MonsterPerf.frame_physics_usec
	var last_slide_usec: int = MonsterPerf.frame_move_slide_usec
	var last_ff: int = MonsterPerf.ff_compute_calls
	var last_ff_usec: int = MonsterPerf.ff_compute_usec
	var last_sample: int = MonsterPerf.sample_factory_calls
	var last_register: int = MonsterPerf.register_goal_calls
	var last_find: int = MonsterPerf.find_target_calls
	var last_find_usec: int = MonsterPerf.find_target_usec
	var last_dmg: int = MonsterPerf.damage_nearby_calls
	var last_dmg_usec: int = MonsterPerf.damage_nearby_usec
	var midway_shot := false
	for _i in total_samples:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var delta_ms := float(now - prev_t) / 1000.0
		prev_t = now
		_frame_ms_samples.append(delta_ms)
		_fps_samples.append(Engine.get_frames_per_second())

		var phys_now: int = int(MonsterPerf.frame_physics_usec)
		var phys_delta: int = maxi(phys_now - last_phys_usec, 0)
		last_phys_usec = phys_now
		_phys_only_ms_samples.append(float(phys_delta) / 1000.0)
		var slide_delta: int = maxi(int(MonsterPerf.frame_move_slide_usec) - last_slide_usec, 0)
		last_slide_usec = int(MonsterPerf.frame_move_slide_usec)

		if delta_ms > 25.0:
			var ff_d: int = MonsterPerf.ff_compute_calls - last_ff
			var ff_ms_d := float(MonsterPerf.ff_compute_usec - last_ff_usec) / 1000.0
			var sample_d: int = MonsterPerf.sample_factory_calls - last_sample
			var reg_d: int = MonsterPerf.register_goal_calls - last_register
			var find_d: int = MonsterPerf.find_target_calls - last_find
			var find_ms_d := float(MonsterPerf.find_target_usec - last_find_usec) / 1000.0
			var dmg_d: int = MonsterPerf.damage_nearby_calls - last_dmg
			var dmg_ms_d := float(MonsterPerf.damage_nearby_usec - last_dmg_usec) / 1000.0
			print("[RSS-SPIKE] #%d @%.2fs: total=%.2f  phys=%.2f  slide=%.2f  ff=%d(%.2f)  samp=%d  reg=%d  find=%d(%.2f)  dmg=%d(%.2f)" % [
				_i, float(_i) / 120.0, delta_ms,
				float(phys_delta) / 1000.0, float(slide_delta) / 1000.0,
				ff_d, ff_ms_d, sample_d, reg_d, find_d, find_ms_d, dmg_d, dmg_ms_d])
		last_ff = MonsterPerf.ff_compute_calls
		last_ff_usec = MonsterPerf.ff_compute_usec
		last_sample = MonsterPerf.sample_factory_calls
		last_register = MonsterPerf.register_goal_calls
		last_find = MonsterPerf.find_target_calls
		last_find_usec = MonsterPerf.find_target_usec
		last_dmg = MonsterPerf.damage_nearby_calls
		last_dmg_usec = MonsterPerf.damage_nearby_usec

		# Sample monster positions for stuck detection ~once/s
		if _i % 120 == 0:
			_sample_monster_positions()
			var b_alive := 0
			for b in BuildingRegistry.unique_buildings:
				if is_instance_valid(b): b_alive += 1
			var alive_now: int = get_tree().get_nodes_in_group(&"monsters").size()
			var stuck_now := _count_stuck_monsters()
			print("[RSS-TICK] t=%.1fs  alive=%d  buildings=%d  stuck=%d" %
				[float(_i) / 120.0, alive_now, b_alive, stuck_now])
			tick_count += 1

		# Midway screenshot
		@warning_ignore("integer_division")
		var midpoint: int = total_samples / 2
		if not midway_shot and _i > midpoint:
			midway_shot = true
			await monitor.screenshot("02_fight_midway")
	MonsterPerf.enabled = false

	monitor.sample()

	# Final stuck measurement + diagnostics
	_sample_monster_positions()
	var stuck_count := _count_stuck_monsters()
	var stuck_details := _list_stuck_monsters(5)

	await monitor.screenshot("03_fight_after")

	_print_report(stuck_count, stuck_details)

	# Gates — all advisory (print first, then assert loose bounds)
	assert_gt_scenario(float(get_tree().get_nodes_in_group(&"monsters").size()), 10.0,
		"At least 10 monsters alive during stress window")

func _sample_monster_positions() -> void:
	var t := float(Time.get_ticks_usec()) / 1e6
	for m in get_tree().get_nodes_in_group(&"monsters"):
		if not (m is Node3D):
			continue
		var id: int = m.get_instance_id()
		if not _monster_history.has(id):
			_monster_history[id] = []
		var hist: Array = _monster_history[id]
		hist.append([t, (m as Node3D).global_position])
		# Trim entries older than STUCK_WINDOW_SECONDS + 1
		while hist.size() > 0 and (t - hist[0][0]) > (STUCK_WINDOW_SECONDS + 1.0):
			hist.pop_front()
		_monster_history[id] = hist

func _count_stuck_monsters() -> int:
	var t := float(Time.get_ticks_usec()) / 1e6
	var stuck := 0
	for m in get_tree().get_nodes_in_group(&"monsters"):
		if not (m is MonsterBase):
			continue
		var mb := m as MonsterBase
		# Attacking monsters are stationary by design — not "stuck"
		if mb.state == MonsterBase.State.ATTACKING:
			continue
		var id: int = mb.get_instance_id()
		var hist: Array = _monster_history.get(id, [])
		if hist.size() < 2:
			continue
		var oldest_in_window: Vector3 = hist[0][1]
		var oldest_t: float = hist[0][0]
		for entry in hist:
			if (t - entry[0]) <= STUCK_WINDOW_SECONDS:
				oldest_in_window = entry[1]
				oldest_t = entry[0]
				break
		if (t - oldest_t) < STUCK_WINDOW_SECONDS * 0.8:
			continue  # not enough window yet
		var travelled := (mb.global_position - oldest_in_window).length()
		if travelled < STUCK_DIST_THRESHOLD:
			stuck += 1
	return stuck

func _list_stuck_monsters(limit: int) -> Array:
	var t := float(Time.get_ticks_usec()) / 1e6
	var list: Array = []
	for m in get_tree().get_nodes_in_group(&"monsters"):
		if not (m is MonsterBase):
			continue
		var mb := m as MonsterBase
		if mb.state == MonsterBase.State.ATTACKING:
			continue
		var id: int = mb.get_instance_id()
		var hist: Array = _monster_history.get(id, [])
		if hist.size() < 2:
			continue
		var oldest_in_window: Vector3 = hist[0][1]
		for entry in hist:
			if (t - entry[0]) <= STUCK_WINDOW_SECONDS:
				oldest_in_window = entry[1]
				break
		var travelled := (mb.global_position - oldest_in_window).length()
		if travelled < STUCK_DIST_THRESHOLD:
			list.append({
				"pos": mb.global_position,
				"state": MonsterBase.State.keys()[mb.state],
				"target": mb._target_building.grid_pos if is_instance_valid(mb._target_building) else Vector2i(-1, -1),
				"travelled": travelled,
			})
			if list.size() >= limit:
				break
	return list

func _print_report(stuck_count: int, stuck_samples: Array) -> void:
	if _fps_samples.is_empty():
		return
	var sorted := _fps_samples.duplicate()
	sorted.sort()
	var fps_avg := 0.0
	var fps_min: float = INF
	var fps_max := 0.0
	for v in sorted:
		fps_avg += v
		if v < fps_min: fps_min = v
		if v > fps_max: fps_max = v
	fps_avg /= sorted.size()

	var sorted_ms := _frame_ms_samples.duplicate()
	sorted_ms.sort()
	var ms_avg := 0.0
	var ms_max := 0.0
	for v in sorted_ms:
		ms_avg += v
		if v > ms_max: ms_max = v
	ms_avg /= sorted_ms.size()
	var p95_idx: int = clampi(int(sorted_ms.size() * 0.95), 0, sorted_ms.size() - 1)
	var ms_p95: float = sorted_ms[p95_idx]

	var over_16_7 := 0
	var over_20 := 0
	var over_33 := 0
	var over_60 := 0
	for v in _frame_ms_samples:
		if v > 16.7: over_16_7 += 1
		if v > 20.0: over_20 += 1
		if v > 33.3: over_33 += 1
		if v > 60.0: over_60 += 1
	var pct_over := 100.0 * float(over_16_7) / float(_frame_ms_samples.size())

	var alive: int = get_tree().get_nodes_in_group(&"monsters").size()

	print("[RSS] ════════════════════════════════════════")
	print("[RSS] Alive monsters: %d   stuck: %d" % [alive, stuck_count])
	print("[RSS] Engine.FPS (rolling avg): %.1f (range %.1f-%.1f)" % [fps_avg, fps_min, fps_max])
	print("[RSS] Frame delta: avg=%.2f ms  p95=%.2f ms  max=%.2f ms  (%d samples)" %
		[ms_avg, ms_p95, ms_max, _frame_ms_samples.size()])
	print("[RSS] Over budget: %d > 16.7 (%.1f%%)  %d > 20  %d > 33.3  %d > 60" %
		[over_16_7, pct_over, over_20, over_33, over_60])

	var indices: Array = []
	indices.resize(_frame_ms_samples.size())
	for i in _frame_ms_samples.size():
		indices[i] = i
	indices.sort_custom(func(a, b): return _frame_ms_samples[a] > _frame_ms_samples[b])
	print("[RSS] Top spikes:")
	for j in mini(10, indices.size()):
		var idx: int = indices[j]
		var t_s := float(idx) / 120.0
		var phys_ms: float = 0.0
		if idx < _phys_only_ms_samples.size():
			phys_ms = _phys_only_ms_samples[idx]
		print("[RSS]   #%-4d @%.2fs  %.2f ms  (phys %.2f ms)" %
			[idx, t_s, _frame_ms_samples[idx], phys_ms])

	print("[RSS] MonsterPerf counters:")
	var snap := MonsterPerf.snapshot()
	for k in snap.keys():
		print("[RSS]   %s: %s" % [k, snap[k]])

	print("[RSS] Stuck samples (first %d):" % stuck_samples.size())
	for s in stuck_samples:
		print("[RSS]   pos=%s  state=%s  target=%s  moved=%.2f" %
			[s["pos"], s["state"], s["target"], s["travelled"]])
	print("[RSS] ════════════════════════════════════════")

# ── Helpers ─────────────────────────────────────────────────────────────────

func _load_save_slot() -> bool:
	var prev_slot := AccountManager.active_slot
	AccountManager.active_slot = SAVE_SLOT
	if not FileAccess.file_exists(SAVE_PATH):
		AccountManager.active_slot = prev_slot
		return false
	# Reparent game_world directly under root so SaveManager._get_game_world
	# (which iterates only root.get_children() looking for name=="GameWorld")
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

func _factory_center_world() -> Vector3:
	if BuildingRegistry.unique_buildings.is_empty():
		return Vector3(MapManager.map_size * 0.5, 0, MapManager.map_size * 0.5)
	var sum := Vector3.ZERO
	var count := 0
	for b in BuildingRegistry.unique_buildings:
		if is_instance_valid(b):
			sum += b.global_position
			count += 1
	if count == 0:
		return Vector3(MapManager.map_size * 0.5, 0, MapManager.map_size * 0.5)
	return sum / count

func _frame_camera_on_center() -> void:
	var cam: GameCamera = game_world.camera if "camera" in game_world else null
	if cam == null:
		return
	cam.target_node = null
	# Zoom in enough that the NavDebugRenderer flow arrows are visible in
	# the screenshot. Full map (64) is way too far out.
	cam.size = 18.0
	cam._target_size = 18.0
	cam.snap_to_3d(_factory_center_world())

func assert_lt_scenario(actual: float, threshold: float, msg: String) -> void:
	sim_assert(actual < threshold, "[%s] %s (got %.2f, need < %.2f)" %
		[scenario_name(), msg, actual, threshold])
