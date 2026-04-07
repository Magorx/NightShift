extends "simulation_base.gd"

## Benchmark: how expensive is monster combat against the factory?
##
## Loads slot_0 ("save 1"), forces the round system into FIGHT phase, then
## measures per-physics-frame wall time as monsters spawn, walk to the factory,
## and start hitting buildings. Reports a histogram of frame times plus the
## suspect-call counters that monster_base.gd / monster_pathfinding.gd
## populate while running.
##
## We run TWO passes back to back so the cost of separation can be A/B'd:
##   pass 1 — monster_separation_enabled = true   (default)
##   pass 2 — monster_separation_enabled = false
##
## The sim is intentionally headless and ignores rendering. Anything that only
## hurts the GPU side will look fine here. The goal is to find the gameplay /
## scripting cost spikes that match the lag the user is seeing.

const SAVE_PATH := "user://saves/slot_0/run_autosave.json"

# Sampling cadence: skip the first warmup frames (spawn area construction etc.)
# then sample for FRAMES_PER_PASS physics frames per pass.
const WARMUP_FRAMES := 60
const FRAMES_PER_PASS := 600   # 10s at 60Hz

func _ready() -> void:
	# We want this sim to use the REAL save data (custom map size, real
	# buildings), so disable the simulation_base autoflatten + map override.
	sim_map_size = 64
	sim_flatten_terrain = false
	sim_rounds_enabled = true
	timeout_seconds = 240.0
	super._ready()

func run_simulation() -> void:
	# Real-time-ish so frame timings are meaningful (default fast = 4x).
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 1

	# 1. Load slot_0 ("save 1") if it exists
	if not _load_save_slot_0():
		printerr("[PERF] Failed to load slot 0 — aborting")
		sim_finish()
		return

	# Wait a couple frames for deferred loaders (terrain mesh, building tick reg).
	await sim_advance_ticks(5)

	var building_count := BuildingRegistry.unique_buildings.size()
	print("[PERF] Loaded slot 0: %d buildings, map_size=%d" % [building_count, MapManager.map_size])

	# 2. Pass 1 — separation ON (default)
	SettingsManager.monster_separation_enabled = true
	var on_results := await _run_pass("separation_ON")

	# 3. Cleanup: end fight, force build phase, despawn monsters, settle
	await _between_passes()

	# 4. Pass 2 — separation OFF
	SettingsManager.monster_separation_enabled = false
	var off_results := await _run_pass("separation_OFF")

	# 5. Restore default
	SettingsManager.monster_separation_enabled = true

	# 6. Side-by-side report
	print("[PERF] ════════════════════════════════════════════════════════")
	print("[PERF] SUMMARY")
	print("[PERF]   buildings = %d, map_size = %d" % [building_count, MapManager.map_size])
	print("[PERF]   pass               | monsters | avg ms | p95 ms | max ms |")
	_print_row("separation ON         ", on_results)
	_print_row("separation OFF        ", off_results)
	print("[PERF] ════════════════════════════════════════════════════════")
	print("[PERF] HOT FUNCTION CALL COUNTS  (totals over the whole pass)")
	_print_counters("separation ON ", on_results)
	_print_counters("separation OFF", off_results)
	print("[PERF] ════════════════════════════════════════════════════════")

	sim_finish()

func _print_row(label: String, r: Dictionary) -> void:
	print("[PERF]   %s | %8d | %6.2f | %6.2f | %6.2f |" % [
		label,
		r.get("monster_count_avg", 0),
		r.get("avg_ms", 0.0),
		r.get("p95_ms", 0.0),
		r.get("max_ms", 0.0),
	])

func _print_counters(label: String, r: Dictionary) -> void:
	var c: Dictionary = r.get("counters", {})
	print("[PERF]   %s: separation=%d, find_target=%d, damage_nearby=%d, sample_factory=%d, register_goal=%d, flush_dirty=%d, ff_compute=%d" % [
		label,
		c.get("separation", 0),
		c.get("find_target", 0),
		c.get("damage_nearby", 0),
		c.get("sample_factory", 0),
		c.get("register_goal", 0),
		c.get("flush_dirty", 0),
		c.get("ff_compute", 0),
	])
	print("[PERF]   %s usec totals: separation=%d, find_target=%d, damage_nearby=%d, sample_factory=%d, register_goal=%d, ff_compute=%d" % [
		label,
		c.get("separation_usec", 0),
		c.get("find_target_usec", 0),
		c.get("damage_nearby_usec", 0),
		c.get("sample_factory_usec", 0),
		c.get("register_goal_usec", 0),
		c.get("ff_compute_usec", 0),
	])

# ── Save loading ────────────────────────────────────────────────────────────

func _load_save_slot_0() -> bool:
	var prev_slot := AccountManager.active_slot
	AccountManager.active_slot = 0
	if not FileAccess.file_exists(SAVE_PATH):
		AccountManager.active_slot = prev_slot
		printerr("[PERF] No save at %s" % SAVE_PATH)
		return false
	var ok := SaveManager.load_run()
	AccountManager.active_slot = prev_slot
	return ok

# ── Pass execution ──────────────────────────────────────────────────────────

## Forces a higher round number so the spawn budget is large enough for the
## benchmark to be representative of real lag conditions. Round 1's natural
## budget is only ~12 (≈6 monsters), which won't surface scaling problems.
## Round 15: budget ≈ 266 ≈ 130 monsters spawned over the fight, ~50 alive at peak.
const PERF_ROUND_NUMBER := 15

func _run_pass(label: String) -> Dictionary:
	print("[PERF] ── pass: %s ──" % label)
	# Enable + reset perf counters before the pass
	MonsterPerf.enabled = true
	MonsterPerf.reset()

	# Force the round system into FIGHT phase at PERF_ROUND_NUMBER. start_run()
	# resets current_round to 1 internally, so we override it before
	# skip_phase() flips us into FIGHT — _start_fight reads RoundManager.current_round
	# when it computes the budget.
	RoundManager.start_run()
	RoundManager.current_round = PERF_ROUND_NUMBER
	RoundManager.skip_phase()
	# RoundManager emits phase_changed("fight"), monster_spawner._start_fight()
	# kicks off, monsters start spawning along the ring.

	# Warm-up frames: let monsters spawn and start moving so the per-frame
	# costs we are measuring are representative.
	await sim_advance_ticks(WARMUP_FRAMES)

	var spawner: Node = _get_spawner()
	if spawner == null:
		printerr("[PERF] Could not find MonsterSpawner")
		return {}

	var alive_after_warmup: int = spawner.get("alive_monsters").size() if spawner else 0
	print("[PERF]   warmup done — alive monsters: %d" % alive_after_warmup)

	# Reset counters AGAIN so warmup spawn cost is excluded from totals.
	MonsterPerf.reset()

	# Sample frames
	var frame_ms := PackedFloat32Array()
	var monster_phys_ms := PackedFloat32Array()
	var monster_slide_ms := PackedFloat32Array()
	var counts := PackedInt32Array()
	frame_ms.resize(0); monster_phys_ms.resize(0); monster_slide_ms.resize(0); counts.resize(0)
	var monster_count_sum := 0
	var samples := 0

	var attack_counts := PackedInt32Array()
	var moving_counts := PackedInt32Array()
	for i in FRAMES_PER_PASS:
		MonsterPerf.frame_physics_usec = 0
		MonsterPerf.frame_move_slide_usec = 0
		MonsterPerf.frame_attacking_count = 0
		MonsterPerf.frame_moving_count = 0
		MonsterPerf.frame_chasing_count = 0
		var t0 := Time.get_ticks_usec()
		await get_tree().physics_frame
		var dt_us := Time.get_ticks_usec() - t0
		frame_ms.append(float(dt_us) / 1000.0)
		monster_phys_ms.append(float(MonsterPerf.frame_physics_usec) / 1000.0)
		monster_slide_ms.append(float(MonsterPerf.frame_move_slide_usec) / 1000.0)
		attack_counts.append(MonsterPerf.frame_attacking_count)
		moving_counts.append(MonsterPerf.frame_moving_count + MonsterPerf.frame_chasing_count)
		var n: int = spawner.get("alive_monsters").size()
		counts.append(n)
		monster_count_sum += n
		samples += 1
		tick_count += 1

	# Find the worst spike frames
	var max_idx := 0
	var max_val := frame_ms[0]
	for i in frame_ms.size():
		if frame_ms[i] > max_val:
			max_val = frame_ms[i]
			max_idx = i
	print("[PERF]   spike: frame %d / %d  total=%.2f ms  monster_phys=%.2f ms  move_slide=%.2f ms  monsters=%d" % [
		max_idx, samples,
		frame_ms[max_idx], monster_phys_ms[max_idx], monster_slide_ms[max_idx], counts[max_idx],
	])
	# Print top-5 worst frames
	var worst_idx: Array = []
	worst_idx.resize(samples)
	for i in samples:
		worst_idx[i] = i
	worst_idx.sort_custom(func(a, b): return frame_ms[a] > frame_ms[b])
	print("[PERF]   top spikes (frame: total/phys/slide ms, alive/attacking/moving):")
	for j in mini(8, samples):
		var idx: int = worst_idx[j]
		print("[PERF]     #%d  %.2f / %.2f / %.2f ms  alive=%d  attacking=%d  moving=%d" % [
			idx, frame_ms[idx], monster_phys_ms[idx], monster_slide_ms[idx],
			counts[idx], attack_counts[idx], moving_counts[idx],
		])
	# Average attacking count and correlation with frame time
	var sum_atk := 0
	var sum_mov := 0
	for v in attack_counts: sum_atk += v
	for v in moving_counts: sum_mov += v
	print("[PERF]   avg per frame: alive=%.1f  attacking=%.1f  moving+chasing=%.1f" % [
		float(monster_count_sum) / samples,
		float(sum_atk) / samples,
		float(sum_mov) / samples,
	])

	# Average per-frame breakdown
	var sum_phys := 0.0
	var sum_slide := 0.0
	for v in monster_phys_ms: sum_phys += v
	for v in monster_slide_ms: sum_slide += v
	print("[PERF]   avg per-frame: total=%.2f ms  monster_phys=%.2f ms  move_slide=%.2f ms" % [
		(sum_phys + (sum_slide - sum_slide)) / 1.0,  # placeholder
		sum_phys / samples,
		sum_slide / samples,
	])

	var avg_count: int = monster_count_sum / max(samples, 1)
	var stats := _frame_stats(frame_ms)
	stats["monster_count_avg"] = avg_count
	stats["counters"] = MonsterPerf.snapshot()
	print("[PERF]   pass done — avg %.2f ms, p95 %.2f ms, max %.2f ms (%d frames, %d monsters avg)" % [
		stats["avg_ms"], stats["p95_ms"], stats["max_ms"], samples, avg_count])
	return stats

func _between_passes() -> void:
	# End the fight: skip the FIGHT phase to bounce back to BUILD,
	# which the spawner uses as the cue to despawn monsters.
	RoundManager.skip_phase()  # FIGHT -> BUILD (next round)
	# Give the despawn a frame, then stop the round system entirely so we
	# can manually start the next pass cleanly.
	await sim_advance_ticks(5)
	RoundManager.stop_run()
	await sim_advance_ticks(2)

# ── Stats ───────────────────────────────────────────────────────────────────

func _frame_stats(samples: PackedFloat32Array) -> Dictionary:
	if samples.is_empty():
		return {"avg_ms": 0.0, "p95_ms": 0.0, "max_ms": 0.0}
	var sorted := samples.duplicate()
	sorted.sort()
	var sum := 0.0
	var maxv := 0.0
	for v in sorted:
		sum += v
		if v > maxv:
			maxv = v
	var p95_idx: int = clampi(int(sorted.size() * 0.95), 0, sorted.size() - 1)
	return {
		"avg_ms": sum / sorted.size(),
		"p95_ms": float(sorted[p95_idx]),
		"max_ms": maxv,
	}

func _get_spawner() -> Node:
	for child in game_world.get_children():
		if child.get_script() != null and child.has_method("setup") and child.has_method("_start_fight"):
			return child
	# Fallback: search by member name
	for child in game_world.get_children():
		if child.name == "MonsterSpawner" or "spawner" in child.name.to_lower():
			return child
	return null
