extends "res://tests/simulation/simulation_base.gd"

## Visual test: captures day and night screenshots to verify lighting.
## Run with: --screenshot-baseline to save, or --visual to watch.

func run_simulation() -> void:
	print("[SIM] === Day/Night Visual Test ===")

	# Let the world settle for a couple frames
	await sim_advance_ticks(10)

	# Screenshot 1: Day (build phase, default state)
	sim_assert(RoundManager.get_phase_name() == &"build", "Starting in build phase (day)")
	await sim_capture_screenshot("day_build_phase")

	# Skip to fight phase
	RoundManager.skip_phase()
	await sim_advance_ticks(2)
	sim_assert(RoundManager.get_phase_name() == &"fight", "Now in fight phase (night)")

	# Wait for the tween to complete (1.5s transition = 90 frames at 60fps)
	await sim_advance_ticks(100)

	# Screenshot 2: Night (fight phase, fully transitioned)
	await sim_capture_screenshot("night_fight_phase")

	print("[SIM] === Day/Night Visual Test Complete ===")
	sim_finish()
