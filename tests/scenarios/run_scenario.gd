extends SceneTree
## Scenario launcher. Similar to run_simulation.gd but defaults to visual mode
## and loads scenarios from the scenarios/ subdirectory.
##
## Usage:
##   # Visual mode (default) — windowed at 4x speed, watchable
##   $GODOT --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <scenario_name>
##
##   # Fast mode — headless for CI
##   $GODOT --headless --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <scenario_name> --fast
##
##   # Screenshot baseline
##   $GODOT --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <scenario_name> --screenshot-baseline
##
##   # Screenshot compare
##   $GODOT --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- <scenario_name> --screenshot-compare
##
##   # List available scenarios
##   $GODOT --headless --path . --script res://tests/scenarios/run_scenario.gd -- --list

func _init():
	root.ready.connect(_on_root_ready)

func _on_root_ready():
	var args := OS.get_cmdline_user_args()
	var scenario_name := ""
	var mode := "visual"  # default to visual (unlike simulations which default to fast)

	for arg in args:
		match arg:
			"--fast":
				mode = "fast"
			"--visual":
				mode = "visual"
			"--benchmark":
				mode = "benchmark"
			"--screenshot-baseline":
				mode = "screenshot_baseline"
			"--screenshot-compare":
				mode = "screenshot_compare"
			"--list":
				_list_scenarios()
				quit(0)
				return
			_:
				if not arg.begins_with("--"):
					scenario_name = arg

	if scenario_name == "":
		printerr("Usage: run_scenario.gd -- <scenario_name> [--fast|--visual|--screenshot-baseline|--screenshot-compare]")
		printerr("Use --list to see available scenarios")
		quit(1)
		return

	# Engine configuration per mode
	match mode:
		"fast":
			# Lower than simulation fast mode (100x) because scenarios use
			# CharacterBody3D physics which becomes unstable at high time_scale
			# (delta=1.67s at 100x breaks move_and_slide).
			Engine.time_scale = 10.0
			Engine.max_physics_steps_per_frame = 10
		"visual":
			Engine.time_scale = 4.0
			Engine.max_physics_steps_per_frame = 4
		"benchmark":
			Engine.time_scale = 1.0
			Engine.max_fps = 0
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		"screenshot_baseline", "screenshot_compare":
			Engine.time_scale = 8.0
			Engine.max_physics_steps_per_frame = 8
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	print("[SCENARIO] Launching %s (mode: %s)" % [scenario_name, mode])

	# Try loading from scenarios/ subdirectory first, then root
	var script_path := "res://tests/scenarios/scenarios/%s.gd" % scenario_name
	var script = load(script_path)
	if not script:
		# Fallback: try without scenarios/ subdirectory
		script_path = "res://tests/scenarios/%s.gd" % scenario_name
		script = load(script_path)
	if not script:
		printerr("Scenario not found: %s" % scenario_name)
		printerr("Looked in: res://tests/scenarios/scenarios/%s.gd" % scenario_name)
		quit(1)
		return

	var scenario = script.new()
	scenario.sim_mode = mode
	scenario.sim_name = scenario_name
	root.add_child(scenario)

func _list_scenarios() -> void:
	print("Available scenarios:")
	var dir := DirAccess.open("res://tests/scenarios/scenarios/")
	if not dir:
		print("  (none found)")
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".gd") and not file_name.ends_with(".gd.uid"):
			var name := file_name.get_basename()
			print("  %s" % name)
		file_name = dir.get_next()
