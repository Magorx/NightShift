extends Node

## Batches all non-conveyor building physics ticks into a single _physics_process call.
## Eliminates per-node notification dispatch overhead for ~300 buildings.

var buildings: Array = []  # Array[BuildingLogic]

func register(logic) -> void:
	if not buildings.has(logic) and logic.has_method("_physics_process"):
		buildings.append(logic)
		logic.set_physics_process(false)

func unregister(logic) -> void:
	buildings.erase(logic)

func clear_all() -> void:
	buildings.clear()

func _physics_process(delta: float) -> void:
	for i in range(buildings.size() - 1, -1, -1):
		var logic = buildings[i]
		if is_instance_valid(logic):
			logic._physics_process(delta)
		else:
			buildings[i] = buildings.back()
			buildings.pop_back()
