class_name SpawnLogic
extends RefCounted

## Base class for spawn area logic. Decides when and how many monsters to spawn.

var area: SpawnArea
var fight_duration: float = 60.0  # set by spawner before start

func start() -> void:
	pass

func update(_delta: float) -> void:
	pass

func stop() -> void:
	pass
