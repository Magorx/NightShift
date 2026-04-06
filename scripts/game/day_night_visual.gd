extends Node

## Manages day/night visual transitions by tweening WorldEnvironment and DirectionalLight3D.
## Listens to RoundManager.phase_changed.

# Day settings (build phase) — matches game_world.tscn defaults
const DAY_AMBIENT_COLOR := Color(0.6, 0.62, 0.65, 1.0)
const DAY_AMBIENT_ENERGY := 0.4
const DAY_BG_COLOR := Color(0.18, 0.22, 0.16, 1.0)
const DAY_LIGHT_ENERGY := 0.9
const DAY_LIGHT_COLOR := Color(1.0, 1.0, 1.0, 1.0)

# Night settings (fight phase) — darker, blueish tint
const NIGHT_AMBIENT_COLOR := Color(0.2, 0.15, 0.35, 1.0)
const NIGHT_AMBIENT_ENERGY := 0.2
const NIGHT_BG_COLOR := Color(0.06, 0.04, 0.1, 1.0)
const NIGHT_LIGHT_ENERGY := 0.3
const NIGHT_LIGHT_COLOR := Color(0.5, 0.4, 0.7, 1.0)

const TRANSITION_DURATION := 1.5  # seconds

var environment: Environment
var directional_light: DirectionalLight3D
var _tween: Tween

func setup(env: Environment, light: DirectionalLight3D) -> void:
	environment = env
	directional_light = light
	RoundManager.phase_changed.connect(_on_phase_changed)

func _on_phase_changed(phase: StringName) -> void:
	match phase:
		&"build":
			_transition_to_day()
		&"fight":
			_transition_to_night()

func _transition_to_night() -> void:
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(environment, "ambient_light_color", NIGHT_AMBIENT_COLOR, TRANSITION_DURATION)
	_tween.tween_property(environment, "ambient_light_energy", NIGHT_AMBIENT_ENERGY, TRANSITION_DURATION)
	_tween.tween_property(environment, "background_color", NIGHT_BG_COLOR, TRANSITION_DURATION)
	_tween.tween_property(directional_light, "light_energy", NIGHT_LIGHT_ENERGY, TRANSITION_DURATION)
	_tween.tween_property(directional_light, "light_color", NIGHT_LIGHT_COLOR, TRANSITION_DURATION)

func _transition_to_day() -> void:
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(environment, "ambient_light_color", DAY_AMBIENT_COLOR, TRANSITION_DURATION)
	_tween.tween_property(environment, "ambient_light_energy", DAY_AMBIENT_ENERGY, TRANSITION_DURATION)
	_tween.tween_property(environment, "background_color", DAY_BG_COLOR, TRANSITION_DURATION)
	_tween.tween_property(directional_light, "light_energy", DAY_LIGHT_ENERGY, TRANSITION_DURATION)
	_tween.tween_property(directional_light, "light_color", DAY_LIGHT_COLOR, TRANSITION_DURATION)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
