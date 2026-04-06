extends "res://tests/simulation/simulation_base.gd"

## Sim test for P4.6: Verifies building transformation between day/night forms.
## Checks: conveyor night mode, health component, converter turret activation,
## resource memory (get_last_resource), and phase restore.

func _ready() -> void:
	sim_rounds_enabled = true
	super._ready()

func run_simulation() -> void:
	print("[SIM] === Night Transform Test ===")

	# --- Setup: place buildings ---
	# Straight conveyor line (should become walls)
	var conv_pos := Vector2i(32, 32)
	sim_place_building(&"conveyor", conv_pos, 0)
	sim_place_building(&"conveyor", conv_pos + Vector2i(1, 0), 0)

	# Turn conveyor (should become tower)
	var turn_pos := Vector2i(32, 34)
	sim_place_building(&"conveyor", turn_pos, 0)
	sim_place_building(&"conveyor", turn_pos + Vector2i(1, 0), 1)  # right then down = creates turn

	# Drill on deposit
	var drill_pos := Vector2i(30, 32)
	sim_add_deposit(drill_pos, &"pyromite")
	sim_place_building(&"drill", drill_pos, 0)

	# Smelter (converter)
	var smelter_pos := Vector2i(34, 32)
	sim_place_building(&"smelter", smelter_pos, 0)

	await sim_advance_ticks(5)

	# --- Verify day state ---
	var conv_logic = sim_get_conveyor_at(conv_pos)
	sim_assert(conv_logic != null, "Conveyor placed successfully")
	sim_assert(conv_logic.is_night_form == false, "Conveyor starts in day form")
	sim_assert(conv_logic.is_night_mode == false, "Conveyor is_night_mode starts false")

	# Verify all buildings have health
	var drill_building = sim_get_building_at(drill_pos)
	sim_assert(drill_building != null, "Drill placed successfully")
	var drill_logic: BuildingLogic = drill_building.logic if drill_building else null
	sim_assert(drill_logic != null, "Drill has logic node")
	sim_assert(drill_logic.health != null, "Drill has HealthComponent")
	sim_assert(drill_logic.health.current_hp == 100.0, "Drill starts at full HP (%.0f)" % drill_logic.health.current_hp)

	var smelter_building = sim_get_building_at(smelter_pos)
	var smelter_logic = smelter_building.logic if smelter_building else null
	sim_assert(smelter_logic != null, "Smelter has logic node")
	sim_assert(smelter_logic.health != null, "Smelter has HealthComponent")

	# Verify conveyor has health
	sim_assert(conv_logic.health != null, "Conveyor has HealthComponent")
	sim_assert(conv_logic.health.current_hp == 100.0, "Conveyor starts at full HP")

	# Verify resource memory
	sim_assert(drill_logic.get_last_resource() == &"pyromite", "Drill remembers pyromite (got '%s')" % drill_logic.get_last_resource())

	# --- Transition to fight (night) ---
	print("[SIM] Skipping to fight phase...")
	RoundManager.skip_phase()
	await sim_advance_ticks(5)

	sim_assert(RoundManager.get_phase_name() == &"fight", "Now in fight phase")

	# Conveyor should be in night mode
	sim_assert(conv_logic.is_night_mode == true, "Conveyor is_night_mode set")
	sim_assert(conv_logic.is_night_form == true, "Conveyor is_night_form set")
	sim_assert(not conv_logic.is_physics_processing(), "Conveyor physics stopped in night")

	# Drill should be in night mode
	sim_assert(drill_logic.is_night_mode == true, "Drill is_night_mode set")

	# Smelter should have turret active
	if smelter_logic is ConverterLogic:
		sim_assert(smelter_logic.night_mode == true, "Smelter night_mode set")
		sim_assert(smelter_logic.turret != null, "Smelter has turret behavior")
		sim_assert(smelter_logic.turret.active == true, "Smelter turret is active")

	# --- Test HP damage ---
	conv_logic.health.damage(30.0)
	sim_assert(conv_logic.health.current_hp == 70.0, "Conveyor HP after 30 damage = %.0f" % conv_logic.health.current_hp)
	sim_assert(conv_logic.health.get_damage_state() == 1, "Damage state 1 at 70%% HP")

	conv_logic.health.damage(30.0)
	sim_assert(conv_logic.health.current_hp == 40.0, "Conveyor HP after 60 total damage = %.0f" % conv_logic.health.current_hp)
	sim_assert(conv_logic.health.get_damage_state() == 2, "Damage state 2 at 40%% HP")

	# --- Transition back to build (day) ---
	print("[SIM] Skipping to build phase...")
	RoundManager.skip_phase()
	await sim_advance_ticks(5)

	sim_assert(RoundManager.get_phase_name() == &"build", "Back to build phase")

	# Conveyor should be restored to day
	sim_assert(conv_logic.is_night_mode == false, "Conveyor is_night_mode cleared")
	sim_assert(conv_logic.is_night_form == false, "Conveyor is_night_form cleared")
	sim_assert(conv_logic.is_physics_processing(), "Conveyor physics restored")

	# HP damage persists across phases
	sim_assert(conv_logic.health.current_hp == 40.0, "Conveyor HP persists after day restore (%.0f)" % conv_logic.health.current_hp)

	# Smelter should be back to day mode
	if smelter_logic is ConverterLogic:
		sim_assert(smelter_logic.night_mode == false, "Smelter night_mode cleared")
		sim_assert(smelter_logic.turret.active == false, "Smelter turret deactivated")

	# --- Test building destruction via HP ---
	# Damage the drill to 0
	drill_logic.health.damage(200.0)
	await sim_advance_ticks(2)
	var drill_after = sim_get_building_at(drill_pos)
	sim_assert(drill_after == null, "Drill destroyed after HP reaches 0")

	print("[SIM] === Night Transform Test Complete ===")
	sim_finish()
