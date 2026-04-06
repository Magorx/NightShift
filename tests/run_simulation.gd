extends SceneTree

## Simulation launcher. Parses CLI args to determine which simulation to run
## and in what mode.
##
## Usage (IMPORTANT: --fixed-fps 60 is required for fast/screenshot modes):
##
##   # Fast mode (default) — headless, ~1s per sim instead of minutes
##   $GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name>
##
##   # Visual mode — windowed at x2 speed, fully playable, doesn't auto-quit
##   $GODOT --path . --script res://tests/run_simulation.gd -- <sim_name> --visual
##
##   # Screenshot baseline — capture reference screenshots
##   $GODOT --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name> --screenshot-baseline
##
##   # Screenshot compare — compare against baseline
##   $GODOT --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- <sim_name> --screenshot-compare
##
## The --fixed-fps 60 flag tells Godot to bypass real-time sync, letting the
## engine process frames as fast as the CPU allows. Without it, simulations
## run in real time (~24s for a typical sim vs ~1s with the flag).

func _init():
	root.ready.connect(_on_root_ready)

func _on_root_ready():
	var args := OS.get_cmdline_user_args()
	var sim_name := "sim_conveyor_transport"
	var mode := "fast"

	for arg in args:
		match arg:
			"--visual":
				mode = "visual"
			"--benchmark":
				mode = "benchmark"
			"--screenshot-baseline":
				mode = "screenshot_baseline"
			"--screenshot-compare":
				mode = "screenshot_compare"
			_:
				if not arg.begins_with("--"):
					sim_name = arg

	# Engine configuration per mode
	match mode:
		"fast":
			# Physics-based item transport (RigidBody3D) needs stable delta for
			# items to roll on conveyors and enter building input zones reliably.
			# 4x keeps delta=0.067s (safe for rigid body simulation).
			Engine.time_scale = 4.0
			Engine.max_physics_steps_per_frame = 4
		"benchmark":
			# Real-time rendering with vsync off for accurate FPS measurement
			Engine.time_scale = 1.0
			Engine.max_fps = 0
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
				# macOS: also try mailbox mode as fallback if disabled doesn't work
				if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
					DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_MAILBOX)
		"screenshot_baseline", "screenshot_compare":
			# Moderate batching — fast but still rendering each frame
			Engine.time_scale = 8.0
			Engine.max_physics_steps_per_frame = 8
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	print("[SIM] Launching %s (mode: %s)" % [sim_name, mode])

	var sim_path := "res://tests/simulation/%s.gd" % sim_name
	var script = load(sim_path)
	if not script:
		printerr("Simulation not found: " + sim_path)
		quit(1)
		return

	var sim = script.new()
	sim.sim_mode = mode
	sim.sim_name = sim_name
	root.add_child(sim)
