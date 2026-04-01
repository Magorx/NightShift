extends Node2D

## Procedural smoke particles rising from the coal burner chimney.
## Particles spawn at the chimney cap, rise upward with gentle drift,
## expand, and fade. z_index=11 renders above top sprite.

# Chimney cap position in Rotatable-local coords
const CHIMNEY := Vector2(57, 6)

const SPAWN_INTERVAL := 0.12
const MAX_PARTICLES := 10
const RISE_SPEED := 14.0   # pixels/sec upward
const DRIFT_SPEED := 3.0   # pixels/sec horizontal
const LIFETIME := 1.8      # seconds before particle is removed
const HOLD_TIME := 0.5

# Smoke colors (with alpha)
const SMOKE_DARK := Color(0.47, 0.47, 0.47, 0.55)
const SMOKE_MID := Color(0.51, 0.51, 0.51, 0.40)
const SMOKE_LIGHT := Color(0.55, 0.55, 0.55, 0.25)

var _active := false
var _hold_timer := 0.0
var _spawn_timer := 0.0
var _particles: Array = []  # [{pos: Vector2, age: float, drift: float, size: float}]
var _rng := RandomNumberGenerator.new()

func set_active(active: bool) -> void:
	_active = active

func _ready() -> void:
	_rng.seed = hash(get_instance_id())

func _physics_process(delta: float) -> void:
	if _active:
		_hold_timer = HOLD_TIME
	elif _hold_timer > 0.0:
		_hold_timer -= delta
	var want_active := _active or _hold_timer > 0.0

	# Spawn
	if want_active:
		_spawn_timer += delta
		if _spawn_timer >= SPAWN_INTERVAL and _particles.size() < MAX_PARTICLES:
			_spawn_timer = 0.0
			_particles.append({
				pos = CHIMNEY + Vector2(_rng.randf_range(-1.0, 1.0), 0),
				age = 0.0,
				drift = _rng.randf_range(-DRIFT_SPEED, DRIFT_SPEED),
				size = _rng.randf_range(1.0, 2.0),
			})

	# Update
	var i := 0
	while i < _particles.size():
		var p: Dictionary = _particles[i]
		p.age += delta
		if p.age >= LIFETIME:
			_particles.remove_at(i)
			continue
		p.pos.y -= RISE_SPEED * delta
		p.pos.x += float(p.drift) * delta
		i += 1

	if not _particles.is_empty():
		queue_redraw()

func _draw() -> void:
	for p in _particles:
		var t: float = float(p.age) / LIFETIME
		var alpha: float = 1.0 - t  # fade out
		alpha *= alpha  # quadratic fade
		var grow: float = float(p.size) + t * 3.0  # expand as it rises

		var col: Color
		if t < 0.3:
			col = SMOKE_DARK
		elif t < 0.6:
			col = SMOKE_MID
		else:
			col = SMOKE_LIGHT
		col.a *= alpha

		draw_circle(p.pos as Vector2, grow, col)
