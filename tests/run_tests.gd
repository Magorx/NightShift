extends SceneTree

func _init():
	var test_dirs = ["res://tests/unit/", "res://tests/integration/"]
	var total_passed := 0
	var total_failed := 0

	for dir_path in test_dirs:
		var dir = DirAccess.open(dir_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with("test_") and file_name.ends_with(".gd"):
				var script = load(dir_path + file_name)
				var instance = script.new()
				print("Running: %s" % file_name)
				var results = instance.run_all()
				total_passed += results.passed
				total_failed += results.failed
				instance.free()
			file_name = dir.get_next()

	print("\n===== Results: %d passed, %d failed =====" % [total_passed, total_failed])

	if total_failed > 0:
		printerr("TESTS FAILED")
		quit(1)
	else:
		print("ALL TESTS PASSED")
		quit(0)
