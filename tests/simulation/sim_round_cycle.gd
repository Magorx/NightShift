extends "res://tests/simulation/simulation_base.gd"

## Sim test for P3: Verifies build/fight phase cycling across 3 full rounds.
## Checks: phase transitions, timer countdown, round counter, build system toggle.

func _ready() -> void:
	sim_rounds_enabled = true
	super._ready()

func run_simulation() -> void:
	print("[SIM] === Round Cycle Test ===")

	# RoundManager should already be running (started by game_world._ready)
	sim_assert(RoundManager.is_running, "RoundManager is running after game world load")
	sim_assert(RoundManager.current_round == 1, "Starts at round 1")
	sim_assert(RoundManager.get_phase_name() == &"build", "Starts in build phase")

	# Verify build system is enabled during build phase
	sim_assert(game_world.build_system._enabled, "Build system enabled during build phase")

	# Track phase transitions via signals
	var phases_seen: Array[StringName] = []
	var rounds_started: Array[int] = []
	var rounds_ended: Array[int] = []
	RoundManager.phase_changed.connect(func(p): phases_seen.append(p))
	RoundManager.round_started.connect(func(r): rounds_started.append(r))
	RoundManager.round_ended.connect(func(r): rounds_ended.append(r))

	# --- Round 1: Build phase ---
	var build_time := RoundManager.get_time_remaining()
	sim_assert(build_time > 170.0 and build_time <= 180.0, "Round 1 build duration ~180s (got %.1f)" % build_time)

	# Advance through build phase (skip most of it)
	RoundManager.skip_phase()
	await sim_advance_ticks(2)

	sim_assert(RoundManager.get_phase_name() == &"fight", "Transitioned to fight phase")
	sim_assert(not game_world.build_system._enabled, "Build system disabled during fight phase")

	# Check fight duration
	var fight_time := RoundManager.get_time_remaining()
	sim_assert(fight_time > 50.0 and fight_time <= 60.0, "Round 1 fight duration ~60s (got %.1f)" % fight_time)

	# Verify factory frozen
	sim_assert(not GameManager.building_tick_system.is_physics_processing(), "Building tick system paused during fight")

	# --- Round 1 -> Round 2 ---
	RoundManager.skip_phase()
	await sim_advance_ticks(2)

	sim_assert(RoundManager.current_round == 2, "Advanced to round 2")
	sim_assert(RoundManager.get_phase_name() == &"build", "Round 2 starts with build phase")
	sim_assert(game_world.build_system._enabled, "Build system re-enabled for round 2 build")
	sim_assert(GameManager.building_tick_system.is_physics_processing(), "Building tick system resumed for build")

	# Check decreasing build duration
	var r2_build := RoundManager.get_time_remaining()
	sim_assert(r2_build < build_time, "Round 2 build shorter than round 1 (%.0f < %.0f)" % [r2_build, build_time])

	# --- Complete rounds 2 and 3 ---
	RoundManager.skip_phase()  # R2 build -> R2 fight
	await sim_advance_ticks(2)
	sim_assert(RoundManager.get_phase_name() == &"fight", "Round 2 fight phase")

	RoundManager.skip_phase()  # R2 fight -> R3 build
	await sim_advance_ticks(2)
	sim_assert(RoundManager.current_round == 3, "Advanced to round 3")

	RoundManager.skip_phase()  # R3 build -> R3 fight
	await sim_advance_ticks(2)

	RoundManager.skip_phase()  # R3 fight -> R4 build (round 3 ended)
	await sim_advance_ticks(2)

	# --- Validate signal history ---
	# Expected phases: build(start), fight, build, fight, build, fight, build
	# We connected after the initial build, so we see: fight, build, fight, build, fight, build
	sim_assert(phases_seen.size() == 6, "6 phase transitions seen (got %d)" % phases_seen.size())
	sim_assert(rounds_ended.has(1), "Round 1 ended signal received")
	sim_assert(rounds_ended.has(2), "Round 2 ended signal received")
	sim_assert(rounds_ended.has(3), "Round 3 ended signal received")

	print("[SIM] === Round Cycle Test Complete ===")
	sim_finish()
