extends Node

## Transforms buildings between day (factory) and night (defense) forms.
## Listens to RoundManager.phase_changed and calls set_night_mode() on all buildings.
## Each building type handles its own transform logic via override.
##
## Instantiated as a child of GameWorld, not registered as an autoload.

func _ready() -> void:
	RoundManager.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: StringName) -> void:
	match phase:
		&"fight":
			_set_all_night_mode(true)
		&"build":
			_set_all_night_mode(false)

func _set_all_night_mode(enabled: bool) -> void:
	for building in BuildingRegistry.unique_buildings:
		if not is_instance_valid(building):
			continue
		var logic: BuildingLogic = building.logic
		if not logic:
			continue
		logic.set_night_mode(enabled)
	if enabled:
		print("[NIGHT] Transformed %d buildings to night form" % BuildingRegistry.unique_buildings.size())
	else:
		print("[NIGHT] Restored %d buildings to day form" % BuildingRegistry.unique_buildings.size())
