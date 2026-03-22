extends Node

var game_world: Node2D
var tick_count: int = 0
var _failed: bool = false

func _ready():
	# Load the real game world scene
	var scene = load("res://scenes/game/game_world.tscn")
	game_world = scene.instantiate()
	add_child(game_world)
	print("[SIM] Game world loaded")
	# Defer so game_world._ready() completes first
	run_simulation.call_deferred()

func run_simulation() -> void:
	# Override in subclass
	pass

# --- Building helpers (use GameManager directly) ---

func sim_place_building(building_id: StringName, grid_pos: Vector2i, rotation: int = 0):
	var result = GameManager.place_building(building_id, grid_pos, rotation)
	print("[SIM] Placed %s at %s rot=%d -> %s" % [building_id, str(grid_pos), rotation, "OK" if result else "FAILED"])
	return result

func sim_remove_building(grid_pos: Vector2i) -> void:
	GameManager.remove_building(grid_pos)
	print("[SIM] Removed building at %s" % str(grid_pos))

func sim_spawn_item_on_conveyor(grid_pos: Vector2i, item_id: StringName) -> bool:
	var conv = GameManager.get_conveyor_at(grid_pos)
	if conv and conv.can_accept():
		conv.place_item(item_id)
		print("[SIM] Spawned %s on conveyor at %s" % [item_id, str(grid_pos)])
		return true
	print("[SIM] Failed to spawn %s on conveyor at %s" % [item_id, str(grid_pos)])
	return false

func sim_get_conveyor_at(grid_pos: Vector2i):
	return GameManager.get_conveyor_at(grid_pos)

func sim_get_building_at(grid_pos: Vector2i):
	return GameManager.get_building_at(grid_pos)

# --- Time helpers ---

func sim_advance_ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		tick_count += 1

func sim_advance_seconds(seconds: float) -> void:
	var frames = int(seconds * 60)
	await sim_advance_ticks(frames)

# --- Assertion helpers ---

func sim_assert(condition: bool, msg: String) -> void:
	if not condition:
		printerr("[SIM FAIL] " + msg)
		_failed = true
	else:
		print("[SIM OK] " + msg)

func sim_finish() -> void:
	print("[SIM] Simulation complete. Ticks: %d" % tick_count)
	get_tree().quit(1 if _failed else 0)
