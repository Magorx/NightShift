extends Node

## Manages the build/fight round cycle for Night Shift.
## Phases: &"build" (place buildings, factory runs), &"fight" (factory frozen, survive).

signal phase_changed(phase: StringName)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal game_over()  # all buildings destroyed

enum Phase { BUILD, FIGHT }

const PHASE_NAMES: Array[StringName] = [&"build", &"fight"]

# ── Tuning ──────────────────────────────────────────────────────────────
const BASE_BUILD_DURATION := 60 # 180.0  # seconds, round 1
const BUILD_DECAY_PER_ROUND := 0 # 15.0 # seconds shorter each round
const MIN_BUILD_DURATION := 5.0

const BASE_FIGHT_DURATION := 60.0   # seconds, round 1
const FIGHT_GROWTH_PER_ROUND := 0 # 10.0 # seconds longer each round
const MAX_FIGHT_DURATION := 180.0

# ── State ───────────────────────────────────────────────────────────────
var current_round: int = 0
var current_phase: Phase = Phase.BUILD
var phase_timer: float = 0.0       # counts down
var is_running: bool = false

# ── Computed ────────────────────────────────────────────────────────────

func get_phase_name() -> StringName:
	return PHASE_NAMES[current_phase]

func get_time_remaining() -> float:
	return maxf(phase_timer, 0.0)

func get_phase_duration() -> float:
	match current_phase:
		Phase.BUILD:
			return _build_duration(current_round)
		Phase.FIGHT:
			return _fight_duration(current_round)
	return 0.0

func get_phase_progress() -> float:
	var dur := get_phase_duration()
	if dur <= 0.0:
		return 1.0
	return 1.0 - (phase_timer / dur)

# ── API ─────────────────────────────────────────────────────────────────

func start_run() -> void:
	current_round = 0
	is_running = true
	_start_next_round()

func stop_run() -> void:
	is_running = false
	set_physics_process(false)

func skip_phase() -> void:
	if is_running:
		_advance_phase()

## Called when all monsters are dead — end fight phase early.
func end_fight_early() -> void:
	if is_running and current_phase == Phase.FIGHT:
		print("[ROUND] Fight ended early — all monsters dead")
		_advance_phase()

## Called when all buildings are destroyed — game over.
func trigger_game_over() -> void:
	is_running = false
	set_physics_process(false)
	game_over.emit()
	print("[ROUND] GAME OVER — all buildings destroyed")

# ── Internal ────────────────────────────────────────────────────────────

func _ready() -> void:
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not is_running:
		return
	phase_timer -= delta
	if phase_timer <= 0.0:
		_advance_phase()

func _start_next_round() -> void:
	current_round += 1
	current_phase = Phase.BUILD
	phase_timer = _build_duration(current_round)
	set_physics_process(true)
	round_started.emit(current_round)
	phase_changed.emit(&"build")
	print("[ROUND] Round %d started — BUILD phase (%.0fs)" % [current_round, phase_timer])

func _advance_phase() -> void:
	match current_phase:
		Phase.BUILD:
			current_phase = Phase.FIGHT
			phase_timer = _fight_duration(current_round)
			phase_changed.emit(&"fight")
			print("[ROUND] FIGHT phase (%.0fs)" % phase_timer)
		Phase.FIGHT:
			round_ended.emit(current_round)
			print("[ROUND] Round %d ended" % current_round)
			_start_next_round()

func _build_duration(round_num: int) -> float:
	return maxf(BASE_BUILD_DURATION - BUILD_DECAY_PER_ROUND * (round_num - 1), MIN_BUILD_DURATION)

func _fight_duration(round_num: int) -> float:
	return minf(BASE_FIGHT_DURATION + FIGHT_GROWTH_PER_ROUND * (round_num - 1), MAX_FIGHT_DURATION)
