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
var sim_map_size: int = 64  # smaller map for fast tests; override in subclass if needed
var sim_rounds_enabled: bool = false  # set true in sims that test round cycling
var sim_flatten_terrain: bool = true  # flatten heights to 0 for predictable physics
var game_world: Node
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

var timeout_seconds := 60.0

## Hard wall-clock timeout. Unlike `timeout_seconds` (which uses a SceneTree
## timer and therefore requires the game loop to be ticking), this runs on a
## background thread and force-kills the process with OS.kill, so it fires
## even if the main thread is deadlocked, stuck in an infinite GDScript loop,
## or waiting on a physics step. Scaled generously: should be large enough to
## never fire in a healthy run, just small enough to prevent CI hangs. Set
## `hard_timeout_seconds = 0.0` in a subclass to disable.
var hard_timeout_seconds := 120.0
var _hard_timeout_thread: Thread = null
var _hard_timeout_cancelled: bool = false

func _ready():
	# Prevent simulations from overwriting real save files
	SaveManager.autosave_enabled = false

	# Auto-kill non-playable simulations after timeout_seconds to prevent hangs
	if sim_mode != "visual":
		var timer := get_tree().create_timer(timeout_seconds, true, false, true)
		timer.timeout.connect(_on_timeout)
		# Belt and braces: a background-thread watchdog that force-kills the
		# process after hard_timeout_seconds wall clock, even if the main
		# thread is wedged.
		if hard_timeout_seconds > 0.0:
			_hard_timeout_thread = Thread.new()
			_hard_timeout_thread.start(_hard_timeout_watchdog.bind(hard_timeout_seconds))

	# Use smaller map for fast tests (128x128 game default is too slow for unit sims)
	MapManager.map_size = sim_map_size

	# Ensure deterministic terrain for reproducible screenshots.
	# game_world._ready() replaces world_seed=0 with randi(), so set a
	# non-zero fixed seed when no subclass has provided one.
	if MapManager.world_seed == 0:
		MapManager.world_seed = 42

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

	# Stop round cycling by default — most sims test factory production and
	# fight phases freeze the factory. Sims that test rounds set sim_rounds_enabled = true.
	if not sim_rounds_enabled:
		RoundManager.stop_run()
		# Keep factory in build mode (building tick system running)
		GameManager.building_tick_system.set_physics_process(true)

	# Clear walls for simulations; optionally flatten terrain
	_sim_clear_walls()
	if sim_flatten_terrain:
		_sim_rebuild_terrain_collision()

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

## Clear walls and optionally flatten terrain for a clean sim grid.
func _sim_clear_walls() -> void:
	MapManager.walls.clear()
	if sim_flatten_terrain:
		# Flatten terrain to Y=0 so physics items roll predictably
		if not MapManager.terrain_heights.is_empty():
			MapManager.terrain_heights.fill(0.0)
		# Reset any pre-placed buildings to ground level
		for b in BuildingRegistry.unique_buildings:
			if is_instance_valid(b):
				b.position.y = 0.0
	# Remove 3D decorations (rocks, rubble) spawned from wall data —
	# they have collision that blocks items even after walls are cleared
	var decorations := game_world.get_node_or_null("TerrainDecorations")
	if decorations:
		game_world.remove_child(decorations)
		decorations.queue_free()

## Rebuild terrain collision after flattening heights.
func _sim_rebuild_terrain_collision() -> void:
	if not MapManager.terrain_visual_manager:
		return
	# Rebuild visual mesh from flat heights
	if MapManager.terrain_tile_types.size() > 0:
		MapManager.terrain_visual_manager.build(
			MapManager.map_size,
			MapManager.terrain_tile_types,
			MapManager.terrain_variants,
			MapManager.terrain_heights
		)
	# Replace terrain collision
	var old_col := game_world.get_node_or_null("TerrainCollision")
	if old_col:
		old_col.queue_free()
	var shape: ConcavePolygonShape3D = MapManager.terrain_visual_manager.create_box_collision()
	if not shape:
		return
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 4
	body.collision_mask = 0
	var col_shape := CollisionShape3D.new()
	col_shape.shape = shape
	body.add_child(col_shape)
	game_world.add_child(body)

## Register a deposit at a position so drills can be placed there.
func sim_add_deposit(pos: Vector2i, item_id: StringName) -> void:
	MapManager.deposits[pos] = item_id

# ── Building helpers (use GameManager directly) ──────────────────────────

func sim_place_building(building_id: StringName, grid_pos: Vector2i, rotation: int = 0):
	var result = BuildingRegistry.place_building(building_id, grid_pos, rotation)
	print("[SIM] Placed %s at %s rot=%d -> %s" % [building_id, str(grid_pos), rotation, "OK" if result else "FAILED"])
	return result

func sim_remove_building(grid_pos: Vector2i) -> void:
	BuildingRegistry.remove_building(grid_pos)
	print("[SIM] Removed building at %s" % str(grid_pos))

func sim_spawn_item_on_conveyor(grid_pos: Vector2i, item_id: StringName) -> bool:
	var pos := Vector3(grid_pos.x + 0.5, 0.3, grid_pos.y + 0.5)
	PhysicsItem.spawn(item_id, pos, Vector3.ZERO)
	print("[SIM] Spawned %s at %s" % [item_id, str(grid_pos)])
	return true

func sim_get_conveyor_at(grid_pos: Vector2i):
	return BuildingRegistry.get_conveyor_at(grid_pos)

func sim_get_building_at(grid_pos: Vector2i):
	return BuildingRegistry.get_building_at(grid_pos)

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
	# Account for Engine.time_scale: each physics tick covers (1/60)*time_scale game seconds
	var frames := int(seconds * 60.0 / Engine.time_scale)
	frames = maxi(frames, 1)
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
## Use this in simulation scripts for important visual checkpoints. Works in
## any mode where rendering is active (visual, benchmark, screenshot_*). In
## benchmark/visual mode the screenshot dir is created on demand under the
## sim's `current/` folder so the caller doesn't need to opt into a
## screenshot subcommand to get captures.
func sim_capture_screenshot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _screenshot_dir == "":
		# Lazy setup for modes that don't pre-create the dir (visual, benchmark).
		_setup_screenshot_dir("current")
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT, Image.INTERPOLATE_BILINEAR)
	var path := _screenshot_dir.path_join("%s.png" % label)
	image.save_png(path)
	print("[SIM] Manual capture: %s (tick %d)" % [path, tick_count])

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
	printerr("[SIM FAIL] Simulation timed out after %d seconds" % int(timeout_seconds))
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 1
	get_tree().quit(1)

## Runs on a background thread. Sleeps wall-clock `timeout_sec` in small
## increments so sim_finish() can cancel it cleanly, then sends SIGKILL to
## our own pid. Last-resort watchdog — if the main thread hangs or the scene
## tree stops processing, the engine timer in _on_timeout() never fires, but
## this thread still does.
func _hard_timeout_watchdog(timeout_sec: float) -> void:
	var end_msec := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < end_msec:
		if _hard_timeout_cancelled:
			return
		OS.delay_msec(100)
	if _hard_timeout_cancelled:
		return
	printerr("[SIM KILL] Hard wall-clock timeout after %.1fs — force killing process" % timeout_sec)
	OS.kill(OS.get_process_id())

## Called from sim_finish() (and any other clean exit paths) to stop the
## watchdog so the Thread destructor doesn't warn about an unjoined thread.
func _stop_hard_timeout() -> void:
	_hard_timeout_cancelled = true
	if _hard_timeout_thread != null and _hard_timeout_thread.is_started():
		_hard_timeout_thread.wait_to_finish()
	_hard_timeout_thread = null

func sim_finish() -> void:
	# Run screenshot comparison if in compare mode
	if sim_mode == "screenshot_compare":
		_compare_screenshots()

	print("[SIM] Simulation complete. Ticks: %d" % tick_count)

	if sim_mode == "visual":
		# Don't quit — let user keep playing and inspecting. Stop the
		# watchdog so it doesn't nuke the still-alive session.
		_stop_hard_timeout()
		print("[SIM] Visual mode — game remains playable. Close window to exit.")
		return

	# Reset time scale so quit() processes promptly (at 100x with 100 max physics
	# steps, the engine can take very long to finish the current frame batch)
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 1
	_stop_hard_timeout()
	get_tree().quit(1 if _failed else 0)
