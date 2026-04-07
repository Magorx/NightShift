extends ScenarioBase
## Scenario: Monster FPS stress test
##
## Places a small factory cluster (smelter + conveyor ring) in the middle of a
## flat 64-tile map, forces the round system into FIGHT phase at round 15 so
## the spawner generates ~64 monsters, then samples the render frame delta
## for SAMPLE_SECONDS and reports any frame over the 60 fps budget.
##
## Runs in --benchmark mode (window open, vsync off, time_scale 1.0). That's
## the ONLY way the measurement reflects real in-game performance — headless
## mode doesn't render, and visual mode's 4x time_scale distorts FPS.
##
## Usage:
##   $GODOT --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- scn_monster_fps_stress --benchmark

const PERF_ROUND := 15
const SAMPLE_SECONDS := 12.0
# Longer warmup so shader pipeline compilation (first-time-visible health
# bars, first-visibility tendril crawler meshes, particle system pipelines)
# is flushed BEFORE the sample window. Without this, the first 1-2s of the
# sample catches the tail of pipeline compilation and logs bogus 20-30ms
# spikes that the user never sees in live gameplay past the first fight.
const WARMUP_SECONDS := 4.0

var _fps_samples: PackedFloat32Array = PackedFloat32Array()
var _frame_ms_samples: PackedFloat32Array = PackedFloat32Array()
## Physics-loop-only cost captured from MonsterPerf for the same sample
## window. Lets us split "is the spike from physics work or from rendering".
var _phys_only_ms_samples: PackedFloat32Array = PackedFloat32Array()

func scenario_name() -> String:
	return "scn_monster_fps_stress"

func _ready() -> void:
	# Bigger than default scenario (32) so the spawner has room for its ring.
	sim_map_size = 64
	# Flat terrain so the stress test isn't muddied by elevation edge cases.
	sim_flatten_terrain = true
	super._ready()

func setup_map() -> void:
	map.clear_walls()
	# Build a small fortified cluster at the map centre so monsters have real
	# targets to path toward. Smelter + conveyor ring gives the spawner 9
	# buildings to path around — enough for multi-sector flow fields without
	# getting into endgame chaos.
	var cx := 32
	var cy := 32
	map.building(&"smelter", Vector2i(cx, cy), 0)
	# Conveyor perimeter (one cell out)
	for dx in range(-2, 3):
		map.building(&"conveyor", Vector2i(cx + dx, cy - 2), 0)
		map.building(&"conveyor", Vector2i(cx + dx, cy + 2), 0)
	for dy in range(-1, 2):
		map.building(&"conveyor", Vector2i(cx - 2, cy + dy), 1)
		map.building(&"conveyor", Vector2i(cx + 2, cy + dy), 1)
	map.player_start(Vector2i(cx, cy))

func setup_monitors() -> void:
	monitor.track("monster_count", func() -> int:
		return get_tree().get_nodes_in_group(&"monsters").size())
	monitor.track("frame_ms_avg", func() -> float:
		if _frame_ms_samples.is_empty():
			return 0.0
		var s := 0.0
		for v in _frame_ms_samples: s += v
		return s / _frame_ms_samples.size())
	monitor.track("frame_ms_max", func() -> float:
		if _frame_ms_samples.is_empty():
			return 0.0
		var m := 0.0
		for v in _frame_ms_samples:
			if v > m: m = v
		return m)
	monitor.track("fps_avg", func() -> float:
		if _fps_samples.is_empty():
			return 0.0
		var s := 0.0
		for v in _fps_samples: s += v
		return s / _fps_samples.size())

func run_scenario() -> void:
	# Force real-time speed. ScenarioBase / run_scenario may have set it
	# higher for other modes; we want 1:1 because Engine.get_frames_per_second
	# and process_frame delta only make sense at 1x.
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 1
	var prev_sep := SettingsManager.monster_separation_enabled
	SettingsManager.monster_separation_enabled = false
	print("[FPS] Disabling boid separation for this test — physics collision alone handles spacing")

	# Pin the camera to the factory centre and zoom out so screenshots show
	# monsters + buildings in one frame. Without this the camera follows the
	# player (who stands in the middle of the factory), and once combat
	# starts the view tracks them through building damage / knockback and
	# screenshots become unreadable.
	_frame_camera_on_center()

	# Let the scene settle (terrain mesh, collision, deferred loads)
	await sim_advance_ticks(5)
	await monitor.screenshot("00_loaded")

	# Force the round system into FIGHT at a high round so the spawner
	# produces a realistic 64-monster wave. skip_phase flips from BUILD→FIGHT
	# (the default start-of-run phase is BUILD).
	RoundManager.current_round = PERF_ROUND
	RoundManager.skip_phase()

	# Warmup: let monsters drip out of the spawn queue (spawner caps at
	# MAX_SPAWNS_PER_FRAME per physics tick)
	await bot.wait(WARMUP_SECONDS)
	monitor.sample()
	await monitor.screenshot("01_fight_spawned")

	var n_after_warmup: int = get_tree().get_nodes_in_group(&"monsters").size()
	print("[FPS] Warmup done — %d monsters alive" % n_after_warmup)

	# Sample render frame delta for SAMPLE_SECONDS
	MonsterPerf.enabled = true
	MonsterPerf.reset()
	var total_samples := int(SAMPLE_SECONDS * 120.0)  # budget for 120 fps
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
	for _i in total_samples:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var delta_ms := float(now - prev_t) / 1000.0
		prev_t = now
		_frame_ms_samples.append(delta_ms)
		_fps_samples.append(Engine.get_frames_per_second())
		# MonsterPerf.frame_physics_usec accumulates; take the delta since
		# the previous render frame so we get a per-render-frame view of
		# how much the physics loop spent on monster work.
		var phys_now: int = MonsterPerf.frame_physics_usec
		var phys_delta: int = phys_now - last_phys_usec
		if phys_delta < 0:
			phys_delta = 0
		last_phys_usec = phys_now
		_phys_only_ms_samples.append(float(phys_delta) / 1000.0)
		# Log a diagnostic line when this frame was a spike so we can see
		# WHICH monster counter lit up.
		var slide_delta := MonsterPerf.frame_move_slide_usec - last_slide_usec
		if slide_delta < 0: slide_delta = 0
		last_slide_usec = MonsterPerf.frame_move_slide_usec
		if delta_ms > 20.0:
			var ff_d: int = MonsterPerf.ff_compute_calls - last_ff
			var ff_ms_d := float(MonsterPerf.ff_compute_usec - last_ff_usec) / 1000.0
			var sample_d: int = MonsterPerf.sample_factory_calls - last_sample
			var reg_d: int = MonsterPerf.register_goal_calls - last_register
			print("[FPS-SPIKE] #%d @%.2fs: total=%.2f ms phys=%.2f ms slide=%.2f ms  ff_compute=%d (%.2f ms)  sample=%d  reg=%d" % [
				_i, float(_i) / 120.0, delta_ms,
				float(phys_delta) / 1000.0, float(slide_delta) / 1000.0,
				ff_d, ff_ms_d, sample_d, reg_d])
		last_ff = MonsterPerf.ff_compute_calls
		last_ff_usec = MonsterPerf.ff_compute_usec
		last_sample = MonsterPerf.sample_factory_calls
		last_register = MonsterPerf.register_goal_calls
		if _i % 60 == 0:
			tick_count += 1
	MonsterPerf.enabled = false

	monitor.sample()
	await monitor.screenshot("02_fight_midway")

	_print_report()

	await bot.wait(2.0)
	await monitor.screenshot("03_fight_after")

	assert_gt_scenario(float(n_after_warmup), 30.0,
		"Spawned at least 30 monsters (%d)" % n_after_warmup)
	var ms_max: float = float(monitor.get_value("frame_ms_max"))
	assert_lt_scenario(ms_max, 20.0,
		"Max frame below 20 ms (got %.2f)" % ms_max)

func _frame_camera_on_center() -> void:
	var cam: GameCamera = game_world.camera if "camera" in game_world else null
	if cam == null:
		return
	# Unfollow the player so the camera doesn't chase them through combat
	cam.target_node = null
	cam.size = 25.0
	cam._target_size = 25.0
	cam.snap_to_3d(GridUtils.grid_to_world(Vector2i(32, 32)))

# ── Report ───────────────────────────────────────────────────────────────

func _print_report() -> void:
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
	for v in _frame_ms_samples:
		if v > 16.7: over_16_7 += 1
		if v > 20.0: over_20 += 1
	var pct_over := 100.0 * float(over_16_7) / float(_frame_ms_samples.size())

	print("[FPS] ════════════════════════════════════════")
	print("[FPS] Engine.FPS (rolling avg): %.1f (range %.1f-%.1f)" %
		[fps_avg, fps_min, fps_max])
	print("[FPS] Frame delta: avg=%.2f ms  p95=%.2f ms  max=%.2f ms  (%d samples)" %
		[ms_avg, ms_p95, ms_max, _frame_ms_samples.size()])
	print("[FPS] Over budget: %d frames > 16.7ms (%.1f%%), %d > 20ms" %
		[over_16_7, pct_over, over_20])

	var indices: Array = []
	indices.resize(_frame_ms_samples.size())
	for i in _frame_ms_samples.size():
		indices[i] = i
	indices.sort_custom(func(a, b): return _frame_ms_samples[a] > _frame_ms_samples[b])
	print("[FPS] top spikes (sample_idx/time_s: total_ms / monster_phys_ms):")
	for j in mini(10, indices.size()):
		var idx: int = indices[j]
		var t_s := float(idx) / 120.0
		var phys_ms: float = 0.0
		if idx < _phys_only_ms_samples.size():
			phys_ms = _phys_only_ms_samples[idx]
		print("[FPS]   #%-4d @%.2fs  %.2f ms  (phys %.2f ms)" %
			[idx, t_s, _frame_ms_samples[idx], phys_ms])
	print("[FPS] ════════════════════════════════════════")

func assert_lt_scenario(actual: float, threshold: float, msg: String) -> void:
	sim_assert(actual < threshold, "[%s] %s (got %.2f, need < %.2f)" %
		[scenario_name(), msg, actual, threshold])
