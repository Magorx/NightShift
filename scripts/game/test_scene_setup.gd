extends Node

func _ready() -> void:
	# Wait one frame for GameManager to be fully ready
	await get_tree().process_frame
	_build_test_factory()

func _build_test_factory() -> void:
	# === Line 1: Simple source -> conveyor chain -> sink ===
	# Source at (5, 5) pointing right
	BuildingRegistry.place_building(&"source", Vector2i(5, 5), 0)
	# Conveyor chain
	for i in range(6):
		BuildingRegistry.place_building(&"conveyor", Vector2i(6 + i, 5), 0)
	# Sink at (12, 5)
	BuildingRegistry.place_building(&"sink", Vector2i(12, 5), 0)

	# === Line 2: Two sources merging into one line -> sink ===
	# Source A at (5, 10) pointing right
	BuildingRegistry.place_building(&"source", Vector2i(5, 10), 0)
	# Conveyor from source A
	BuildingRegistry.place_building(&"conveyor", Vector2i(6, 10), 0)
	BuildingRegistry.place_building(&"conveyor", Vector2i(7, 10), 0)

	# Source B at (8, 8) pointing down
	BuildingRegistry.place_building(&"source", Vector2i(8, 8), 1)
	# Conveyor from source B going down to merge point
	BuildingRegistry.place_building(&"conveyor", Vector2i(8, 9), 1)

	# Merge point and output
	BuildingRegistry.place_building(&"conveyor", Vector2i(8, 10), 0)
	BuildingRegistry.place_building(&"conveyor", Vector2i(9, 10), 0)
	BuildingRegistry.place_building(&"conveyor", Vector2i(10, 10), 0)
	# Sink
	BuildingRegistry.place_building(&"sink", Vector2i(11, 10), 0)

	# === Line 3: Three sources merging (test round-robin) ===
	# Center conveyor line
	for i in range(4):
		BuildingRegistry.place_building(&"conveyor", Vector2i(8 + i, 15), 0)
	BuildingRegistry.place_building(&"sink", Vector2i(12, 15), 0)

	# Source from left
	BuildingRegistry.place_building(&"source", Vector2i(6, 15), 0)
	BuildingRegistry.place_building(&"conveyor", Vector2i(7, 15), 0)

	# Source from top
	BuildingRegistry.place_building(&"source", Vector2i(8, 13), 1)
	BuildingRegistry.place_building(&"conveyor", Vector2i(8, 14), 1)

	# Source from bottom
	BuildingRegistry.place_building(&"source", Vector2i(8, 17), 3)
	BuildingRegistry.place_building(&"conveyor", Vector2i(8, 16), 3)

	# === Line 4: Source -> conveyors -> Smelter -> conveyor -> sink ===
	# Demonstrates the full smelter production chain: iron_ore -> iron_plate
	#
	#   Source → ══ → ══ → [Smelter ] → ══ → ══ → Sink
	#                       [  IN ◻ ]  ← output gap (9,20) has a conveyor
	#                       [       ]
	#
	# Source at (5, 20) producing iron_ore, facing right
	BuildingRegistry.place_building(&"source", Vector2i(5, 20), 0)
	# Conveyor chain into smelter input
	BuildingRegistry.place_building(&"conveyor", Vector2i(6, 20), 0)
	BuildingRegistry.place_building(&"conveyor", Vector2i(7, 20), 0)
	# Smelter anchor at (8, 20): input cell at anchor, output gap at (9,20)
	BuildingRegistry.place_building(&"smelter", Vector2i(8, 20), 0)
	# Conveyor in the output gap + chain to sink
	BuildingRegistry.place_building(&"conveyor", Vector2i(9, 20), 0)
	BuildingRegistry.place_building(&"conveyor", Vector2i(10, 20), 0)
	BuildingRegistry.place_building(&"conveyor", Vector2i(11, 20), 0)
	# Sink at the end
	BuildingRegistry.place_building(&"sink", Vector2i(12, 20), 0)

	print("[TEST] Test factory built")
