extends "simulation_base.gd"

func _ready():
	GameManager.stress_test_pending = true
	GameManager.map_size = 128
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
			cam.position = Vector2(64 * 32, 64 * 32)  # center of 128-tile map
			cam.zoom = Vector2(0.15, 0.15)             # zoom out to see everything
			await sim_advance_ticks(2)
			await sim_capture_screenshot("full_map")
			# Zoom into a factory block in the top-left area
			cam.position = Vector2(10 * 32, 18 * 32)
			cam.zoom = Vector2(0.6, 0.6)
			await sim_advance_ticks(2)
			await sim_capture_screenshot("factory_closeup")

	sim_finish()
