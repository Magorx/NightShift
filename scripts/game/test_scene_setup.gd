extends Node

func _ready() -> void:
	# Wait one frame for GameManager to be fully ready
	await get_tree().process_frame
	_build_test_factory()

func _build_test_factory() -> void:
	# === Line 1: Simple source -> conveyor chain -> sink ===
	# Source at (5, 5) pointing right
	GameManager.place_building(&"source", Vector2i(5, 5), 0)
	# Conveyor chain
	for i in range(6):
		GameManager.place_building(&"conveyor", Vector2i(6 + i, 5), 0)
	# Sink at (12, 5)
	GameManager.place_building(&"sink", Vector2i(12, 5), 0)

	# === Line 2: Two sources merging into one line -> sink ===
	# Source A at (5, 10) pointing right
	GameManager.place_building(&"source", Vector2i(5, 10), 0)
	# Conveyor from source A
	GameManager.place_building(&"conveyor", Vector2i(6, 10), 0)
	GameManager.place_building(&"conveyor", Vector2i(7, 10), 0)

	# Source B at (8, 8) pointing down
	GameManager.place_building(&"source", Vector2i(8, 8), 1)
	# Conveyor from source B going down to merge point
	GameManager.place_building(&"conveyor", Vector2i(8, 9), 1)

	# Merge point and output
	GameManager.place_building(&"conveyor", Vector2i(8, 10), 0)
	GameManager.place_building(&"conveyor", Vector2i(9, 10), 0)
	GameManager.place_building(&"conveyor", Vector2i(10, 10), 0)
	# Sink
	GameManager.place_building(&"sink", Vector2i(11, 10), 0)

	# === Line 3: Three sources merging (test round-robin) ===
	# Center conveyor line
	for i in range(4):
		GameManager.place_building(&"conveyor", Vector2i(8 + i, 15), 0)
	GameManager.place_building(&"sink", Vector2i(12, 15), 0)

	# Source from left
	GameManager.place_building(&"source", Vector2i(6, 15), 0)
	GameManager.place_building(&"conveyor", Vector2i(7, 15), 0)

	# Source from top
	GameManager.place_building(&"source", Vector2i(8, 13), 1)
	GameManager.place_building(&"conveyor", Vector2i(8, 14), 1)

	# Source from bottom
	GameManager.place_building(&"source", Vector2i(8, 17), 3)
	GameManager.place_building(&"conveyor", Vector2i(8, 16), 3)

	print("[TEST] Test factory built")
