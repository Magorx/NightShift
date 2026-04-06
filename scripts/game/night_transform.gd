extends Node

## Transforms buildings between day (factory) and night (defense) forms.
## Listens to RoundManager.phase_changed and iterates all placed buildings:
##   - Conveyors: stop item transport, act as walls/towers
##   - Other buildings: stop production (turret behavior added by P4.3)
##
## Instantiated as a child of GameWorld, not registered as an autoload.

func _ready() -> void:
	RoundManager.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: StringName) -> void:
	match phase:
		&"fight":
			_transform_to_night()
		&"build":
			_restore_to_day()

# ── Night (fight phase) ─────────────────────────────────────────────────────

func _transform_to_night() -> void:
	for building in BuildingRegistry.unique_buildings:
		if not is_instance_valid(building):
			continue
		var logic: BuildingLogic = building.logic
		if not logic:
			continue
		logic.is_night_mode = true
		if logic is ConveyorBelt:
			_transform_conveyor(logic)
		elif logic is ConverterLogic:
			logic.set_night_mode(true)
		else:
			# Other buildings (drills, etc.): stop production
			logic.set_physics_process(false)
	print("[NIGHT] Transformed %d buildings to night form" % BuildingRegistry.unique_buildings.size())

# ── Day (build phase) ───────────────────────────────────────────────────────

func _restore_to_day() -> void:
	for building in BuildingRegistry.unique_buildings:
		if not is_instance_valid(building):
			continue
		var logic: BuildingLogic = building.logic
		if not logic:
			continue
		logic.is_night_mode = false
		if logic is ConveyorBelt:
			_restore_conveyor(logic)
		elif logic is ConverterLogic:
			logic.set_night_mode(false)
		else:
			logic.set_physics_process(true)
	print("[NIGHT] Restored %d buildings to day form" % BuildingRegistry.unique_buildings.size())

# ── Conveyor helpers ─────────────────────────────────────────────────────────

func _transform_conveyor(conv: ConveyorBelt) -> void:
	# Save current day state before transforming
	conv.is_night_form = true
	conv._day_variant = conv._current_variant
	conv._day_rotation_steps = conv._current_rotation_steps
	# Stop item pushing
	conv.set_physics_process(false)
	# Swap to night model: turn variants → tower, others → wall
	var night_variant: StringName = &"tower" if conv._current_variant in ConveyorBelt.TURN_VARIANTS else &"wall"
	conv._swap_model(night_variant, 0)

func _restore_conveyor(conv: ConveyorBelt) -> void:
	conv.is_night_form = false
	conv.set_physics_process(true)
	# Restore day model if it was swapped (by future P4.5 night models)
	if conv._day_variant != &"":
		conv._swap_model(conv._day_variant, conv._day_rotation_steps)
		conv._day_variant = &""
		conv._day_rotation_steps = 0
