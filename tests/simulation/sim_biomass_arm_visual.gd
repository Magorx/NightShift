extends "simulation_base.gd"

## Visual test for biomass extractor arm animation.
## Zooms in close to capture arm joints, claw, and fragment movement.

func run_simulation() -> void:
	# Create a biomass cluster around the test area
	for x in range(8, 16):
		for y in range(8, 13):
			sim_add_deposit(Vector2i(x, y), &"biomass")
			GameManager.deposit_stocks[Vector2i(x, y)] = 10

	# Place extractor at (10, 10) facing right
	var ext = sim_place_building(&"biomass_extractor", Vector2i(10, 10), 0)
	sim_assert(ext != null, "Extractor placed")

	# Place output at (13, 10)
	var out_dev = sim_place_building(&"biomass_extractor_output", Vector2i(13, 10), 0)
	sim_assert(out_dev != null, "Output placed")

	# Link
	if ext and out_dev and ext.logic and out_dev.logic:
		ext.logic.output_device = out_dev.logic
		out_dev.logic.extractor = ext.logic

	if not GameManager.cluster_drain_manager:
		var CDM = load("res://scripts/game/cluster_drain_manager.gd")
		GameManager.cluster_drain_manager = CDM.new()
	GameManager.cluster_drain_manager.invalidate_cache()

	sim_place_building(&"conveyor", Vector2i(14, 10), 0)
	sim_place_building(&"sink", Vector2i(15, 10), 0)

	# Move player next to the extractor so camera follows there
	if GameManager.player:
		GameManager.player.position = Vector2(10, 10) * 32 + Vector2(32, 16)

	# Override camera zoom for close-up screenshots
	var cam = game_world.find_child("Camera2D", false, false)
	if cam:
		cam.zoom = Vector2(3, 3)
		cam.position = GameManager.player.position
		# Set internal target zoom so update_camera doesn't lerp it back
		if "set_target_zoom" in cam:
			cam.set_target_zoom(3.0)
		if "_target_zoom" in cam:
			cam._target_zoom = 3.0

	# Capture arm animation across multiple cycles
	for i in range(20):
		await sim_advance_seconds(0.3)
		if _is_screenshot_mode():
			await _capture_screenshot()

	var sink = GameManager.get_building_at(Vector2i(15, 10))
	var sink_logic = sink.find_child("SinkLogic", true, false) if sink else null
	var consumed: int = sink_logic.items_consumed if sink_logic else 0
	sim_assert(consumed > 0, "Arm animation: sink got %d items" % consumed)

	var arm = ext.find_child("CodeAnimArm", true, false) if ext else null
	sim_assert(arm != null, "Arm node exists on extractor")

	sim_finish()
