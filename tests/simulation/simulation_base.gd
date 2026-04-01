extends Node
## Base class for all simulations.
##
## Modes (set by run_simulation.gd before _ready):
##   "fast"                — headless, 100x time scale (default)
##   "visual"              — windowed at x2 speed, fully playable, doesn't auto-quit
##   "screenshot_baseline" — fast with rendering, saves reference screenshots
##   "screenshot_compare"  — fast with rendering, compares against baseline

var sim_mode: String = "fast"
var sim_name: String = ""
var game_world: Node2D
var tick_count: int = 0
var _failed: bool = false

# ── Screenshot settings ──────────────────────────────────────────────────
# NOTE on screenshot determinism: When randomness is introduced to the game
# (e.g. random deposit placement, particle effects, random conveyor jitter),
# it MUST be frozen/seeded in simulations so that screenshot baselines remain
# reproducible. Use a fixed RNG seed or disable random systems entirely.

const SCREENSHOT_WIDTH := 1280
const SCREENSHOT_HEIGHT := 720
const SCREENSHOT_INTERVAL := 60  # auto-capture at most every N ticks
const SCREENSHOT_DIFF_THRESHOLD := 0.02  # max 2% average pixel diff

var _screenshot_index: int = 0
var _screenshot_dir: String = ""
var _last_capture_tick: int = -SCREENSHOT_INTERVAL  # ensure first eligible capture fires

const TIMEOUT_SECONDS := 60.0

func _ready():
	# Prevent simulations from overwriting real save files
	SaveManager.autosave_enabled = false

	# Auto-kill non-playable simulations after TIMEOUT_SECONDS to prevent hangs
	if sim_mode != "visual":
		var timer := get_tree().create_timer(TIMEOUT_SECONDS, true, false, true)
		timer.timeout.connect(_on_timeout)

	# Ensure deterministic terrain for reproducible screenshots.
	# game_world._ready() replaces world_seed=0 with randi(), so set a
	# non-zero fixed seed when no subclass has provided one.
	if GameManager.world_seed == 0:
		GameManager.world_seed = 42

	# Load the real game world scene
	var scene = load("res://scenes/game/game_world.tscn")
	game_world = scene.instantiate()
	add_child(game_world)
	print("[SIM] Game world loaded (mode: %s)" % sim_mode)

	# Mode-specific setup (game_world._ready() has already completed)
	match sim_mode:
		"visual":
			Engine.time_scale = 2.0
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_title("Simulation: %s" % sim_name)
			# Sync HUD to x2 speed (index 4 in SPEED_STEPS)
			var hud = game_world.hud
			if hud:
				hud.speed_index = 4
				hud.speed_label.text = "x2"
				hud._update_speed_buttons()
		"benchmark":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_title("BENCHMARK: %s" % sim_name)
		"screenshot_baseline":
			_setup_screenshot_dir("baseline")
		"screenshot_compare":
			_setup_screenshot_dir("current")

	# Clear walls for simulations — tests need a clean grid, not terrain obstacles
	_sim_clear_walls()

	# Defer so game_world._ready() completes first
	run_simulation.call_deferred()

func _setup_screenshot_dir(subdir: String) -> void:
	var rel_path := "res://tests/simulation/screenshots/%s/%s" % [sim_name, subdir]
	_screenshot_dir = ProjectSettings.globalize_path(rel_path)
	DirAccess.make_dir_recursive_absolute(_screenshot_dir)
	print("[SIM] Screenshot dir: %s" % _screenshot_dir)

func run_simulation() -> void:
	# Override in subclass
	pass

# ── World helpers ────────────────────────────────────────────────────────

## Clear all walls so simulations have a clean grid for building placement.
func _sim_clear_walls() -> void:
	var tm = game_world.find_child("TileMapLayer", false, false)
	if tm:
		for pos in GameManager.walls:
			tm.set_cell(pos, 0, Vector2i(0, 0))  # TILE_GROUND = 0
	GameManager.walls.clear()

## Register a deposit at a position so drills can be placed there.
func sim_add_deposit(pos: Vector2i, item_id: StringName) -> void:
	GameManager.deposits[pos] = item_id

# ── Building helpers (use GameManager directly) ──────────────────────────

func sim_place_building(building_id: StringName, grid_pos: Vector2i, rotation: int = 0):
	var result = GameManager.place_building(building_id, grid_pos, rotation)
	print("[SIM] Placed %s at %s rot=%d -> %s" % [building_id, str(grid_pos), rotation, "OK" if result else "FAILED"])
	return result

func sim_remove_building(grid_pos: Vector2i) -> void:
	GameManager.remove_building(grid_pos)
	print("[SIM] Removed building at %s" % str(grid_pos))

func sim_spawn_item_on_conveyor(grid_pos: Vector2i, item_id: StringName) -> bool:
	var conv = GameManager.get_conveyor_at(grid_pos)
	if conv and conv.can_accept():
		conv.place_item(item_id)
		print("[SIM] Spawned %s on conveyor at %s" % [item_id, str(grid_pos)])
		return true
	print("[SIM] Failed to spawn %s on conveyor at %s" % [item_id, str(grid_pos)])
	return false

func sim_get_conveyor_at(grid_pos: Vector2i):
	return GameManager.get_conveyor_at(grid_pos)

func sim_get_building_at(grid_pos: Vector2i):
	return GameManager.get_building_at(grid_pos)

# ── Time helpers ─────────────────────────────────────────────────────────

## Advance tick-by-tick until callback returns true, or fail after max_ticks.
## Returns true if the condition was met.
func sim_advance_until(callback: Callable, max_ticks: int = 600) -> bool:
	for i in max_ticks:
		await get_tree().physics_frame
		tick_count += 1
		if callback.call():
			return true
	return false

func sim_advance_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		tick_count += 1
	# Auto-capture after advancing if enough ticks passed since last capture
	if _is_screenshot_mode() and tick_count - _last_capture_tick >= SCREENSHOT_INTERVAL:
		await _capture_screenshot()

func sim_advance_seconds(seconds: float) -> void:
	var frames := int(seconds * 60)
	await sim_advance_ticks(frames)

# ── Screenshot helpers ───────────────────────────────────────────────────

func _is_screenshot_mode() -> bool:
	return sim_mode in ["screenshot_baseline", "screenshot_compare"]

func _capture_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("[SIM] Cannot capture screenshots in headless mode")
		return
	# Wait for the current frame to finish rendering
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT, Image.INTERPOLATE_BILINEAR)
	var filename := "frame_%04d.png" % _screenshot_index
	var path := _screenshot_dir.path_join(filename)
	image.save_png(path)
	print("[SIM] Captured: %s (tick %d)" % [filename, tick_count])
	_screenshot_index += 1
	_last_capture_tick = tick_count

## Manually capture a named screenshot at the current simulation state.
## Use this in simulation scripts for important visual checkpoints.
func sim_capture_screenshot(label: String) -> void:
	if not _is_screenshot_mode():
		return
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT, Image.INTERPOLATE_BILINEAR)
	var path := _screenshot_dir.path_join("%s.png" % label)
	image.save_png(path)
	print("[SIM] Manual capture: %s.png (tick %d)" % [label, tick_count])

func _compare_screenshots() -> void:
	var baseline_dir := ProjectSettings.globalize_path(
		"res://tests/simulation/screenshots/%s/baseline" % sim_name)
	var dir := DirAccess.open(baseline_dir)
	if not dir:
		printerr("[SIM FAIL] No baseline found: %s" % baseline_dir)
		_failed = true
		return

	var compared := 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".png"):
			var bp := baseline_dir.path_join(fname)
			var cp := _screenshot_dir.path_join(fname)
			if not FileAccess.file_exists(cp):
				printerr("[SIM FAIL] Missing current screenshot: %s" % fname)
				_failed = true
			else:
				var bi := Image.load_from_file(bp)
				var ci := Image.load_from_file(cp)
				var diff := _compute_image_diff(bi, ci)
				if diff > SCREENSHOT_DIFF_THRESHOLD:
					printerr("[SIM FAIL] %s differs: %.1f%%" % [fname, diff * 100])
					_failed = true
				else:
					print("[SIM OK] %s matches (%.2f%%)" % [fname, diff * 100])
			compared += 1
		fname = dir.get_next()

	if compared == 0:
		printerr("[SIM FAIL] No baseline screenshots to compare")
		_failed = true
	else:
		print("[SIM] Compared %d screenshots" % compared)

func _compute_image_diff(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 1.0
	var total_diff := 0.0
	var pixel_count := a.get_width() * a.get_height()
	for y in a.get_height():
		for x in a.get_width():
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total_diff += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0
	return total_diff / pixel_count

# ── Benchmark helpers ───────────────────────────────────────────────────

## Measure average FPS over a number of rendered frames.
## Returns {avg_fps, min_fps, max_fps, frame_count}.
func sim_benchmark_fps(duration_seconds: float, label: String = "") -> Dictionary:
	var frame_times: Array[float] = []  # microseconds per frame
	var start_time := Time.get_ticks_usec()
	var end_time := start_time + int(duration_seconds * 1000000.0)
	var prev_time := start_time

	while Time.get_ticks_usec() < end_time:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_times.append(float(now - prev_time))
		prev_time = now

	if frame_times.is_empty():
		return {avg_fps = 0.0, min_fps = 0.0, max_fps = 0.0, frame_count = 0}

	var total_time := 0.0
	var min_ft := 9999999.0
	var max_ft := 0.0
	for ft in frame_times:
		total_time += ft
		min_ft = minf(min_ft, ft)
		max_ft = maxf(max_ft, ft)
	var avg_ft := total_time / frame_times.size()
	var avg_fps := 1000000.0 / avg_ft
	var min_fps := 1000000.0 / max_ft  # worst frame time = min FPS
	var max_fps := 1000000.0 / min_ft  # best frame time = max FPS

	var tag := (" [%s]" % label) if label != "" else ""
	print("[BENCH]%s avg=%.1f min=%.0f max=%.0f frames=%d" % [tag, avg_fps, min_fps, max_fps, frame_times.size()])
	return {avg_fps = avg_fps, min_fps = min_fps, max_fps = max_fps, frame_count = frame_times.size()}

# ── Assertion helpers ────────────────────────────────────────────────────

func sim_assert(condition: bool, msg: String) -> void:
	if not condition:
		printerr("[SIM FAIL] " + msg)
		_failed = true
	else:
		print("[SIM OK] " + msg)

func _on_timeout() -> void:
	printerr("[SIM FAIL] Simulation timed out after %d seconds" % int(TIMEOUT_SECONDS))
	get_tree().quit(1)

func sim_finish() -> void:
	# Run screenshot comparison if in compare mode
	if sim_mode == "screenshot_compare":
		_compare_screenshots()

	print("[SIM] Simulation complete. Ticks: %d" % tick_count)

	if sim_mode == "visual":
		# Don't quit — let user keep playing and inspecting
		print("[SIM] Visual mode — game remains playable. Close window to exit.")
		return

	get_tree().quit(1 if _failed else 0)
