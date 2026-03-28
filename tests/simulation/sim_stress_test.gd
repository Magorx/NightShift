extends "simulation_base.gd"

func _ready():
	GameManager.stress_test_pending = true
	GameManager.map_size = 160
	GameManager.world_seed = 0
	super._ready()

func run_simulation() -> void:
	# The stress test generator ran during game_world._ready()
	var building_count := GameManager.unique_buildings.size()
	sim_assert(building_count > 50, "Stress test placed many buildings (got %d)" % building_count)

	# Count building types
	var type_counts := {}
	for building in GameManager.unique_buildings:
		if not is_instance_valid(building):
			continue
		var bid: StringName = building.building_id
		type_counts[bid] = type_counts.get(bid, 0) + 1

	for bid in type_counts:
		print("[SIM] %s: %d" % [bid, type_counts[bid]])

	# Verify we have diverse building types
	sim_assert(type_counts.has(&"drill"), "Has drills")
	sim_assert(type_counts.has(&"conveyor"), "Has conveyors")
	sim_assert(type_counts.has(&"sink"), "Has sinks")

	# ── Benchmark mode: measure FPS at different zoom levels ──
	if sim_mode == "benchmark":
		await _run_benchmark()
		return

	# Let the factory run for 30 seconds
	await sim_advance_seconds(30)

	# Check that items were delivered to sinks
	var total_delivered := 0
	for item_id: StringName in GameManager.items_delivered:
		var count: int = GameManager.items_delivered[item_id]
		total_delivered += count
		print("[SIM] Delivered %s: %d" % [item_id, count])

	sim_assert(total_delivered > 0, "Items were delivered to sinks (total: %d)" % total_delivered)

	# Capture overview screenshot showing the full map
	if _is_screenshot_mode():
		var cam = game_world.find_child("Camera2D", false, false)
		if cam:
			cam.position = Vector2(80 * 32, 80 * 32)  # center of 160-tile map
			cam.zoom = Vector2(0.15, 0.15)             # zoom out to see everything
			await sim_advance_ticks(2)
			await sim_capture_screenshot("full_map")
			# Zoom into a factory block in the top-left area
			cam.position = Vector2(10 * 32, 18 * 32)
			cam.zoom = Vector2(0.6, 0.6)
			await sim_advance_ticks(2)
			await sim_capture_screenshot("factory_closeup")
			# Find a conveyor with neighbors for UV debug
			var conv_pos := Vector2.ZERO
			for b in GameManager.unique_buildings:
				if is_instance_valid(b) and b.building_id == &"conveyor":
					var gp: Vector2i = b.logic.grid_pos
					var has_neighbor := false
					for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
						var nb = GameManager.buildings.get(gp + offset)
						if nb and is_instance_valid(nb) and nb.building_id == &"conveyor":
							has_neighbor = true
							break
					if has_neighbor:
						conv_pos = Vector2(gp) * 32.0 + Vector2(16, 16)
						break
			cam.position = conv_pos
			cam.zoom = Vector2(6.0, 6.0)
			await sim_advance_ticks(2)
			await sim_capture_screenshot("uv_debug")

	sim_finish()

func _run_benchmark() -> void:
	var cam = game_world.find_child("Camera2D", false, false)
	if not cam:
		printerr("[BENCH] No camera found")
		get_tree().quit(1)
		return

	print("[BENCH] Warming up factory for 3 seconds...")
	# Let factory produce items for a few seconds so conveyors are loaded
	await sim_benchmark_fps(3.0, "warmup")

	# ── Test 1: Zoomed out (worst case — everything visible) ──
	cam.position = Vector2(80 * 32, 80 * 32)
	cam.zoom = Vector2(0.12, 0.12)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[BENCH] === ZOOMED OUT (full map) ===")
	var zoomed_out := await sim_benchmark_fps(5.0, "zoomed_out")

	# ── Test 2: Medium zoom ──
	cam.position = Vector2(40 * 32, 40 * 32)
	cam.zoom = Vector2(0.5, 0.5)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[BENCH] === MEDIUM ZOOM ===")
	var medium := await sim_benchmark_fps(5.0, "medium_zoom")

	# ── Test 3: Close up ──
	cam.position = Vector2(10 * 32, 18 * 32)
	cam.zoom = Vector2(1.0, 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	print("[BENCH] === CLOSE UP ===")
	var close_up := await sim_benchmark_fps(5.0, "close_up")

	print("[BENCH] ═══════════════════════════════════════")
	print("[BENCH] RESULTS: zoomed_out=%.1f  medium=%.1f  close_up=%.1f" % [
		zoomed_out.avg_fps, medium.avg_fps, close_up.avg_fps])
	print("[BENCH] ═══════════════════════════════════════")

	get_tree().quit(0)
