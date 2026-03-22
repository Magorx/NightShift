extends SceneTree

func _init():
	# Defer to allow autoloads to initialize first
	root.ready.connect(_on_root_ready)

func _on_root_ready():
	var args = OS.get_cmdline_user_args()
	var sim_name = args[0] if args.size() > 0 else "sim_conveyor_transport"
	var sim_path = "res://tests/simulation/%s.gd" % sim_name
	var script = load(sim_path)
	if not script:
		printerr("Simulation not found: " + sim_path)
		quit(1)
		return
	var sim = script.new()
	root.add_child(sim)
