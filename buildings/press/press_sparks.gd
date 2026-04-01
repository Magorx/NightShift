extends Node2D

## Procedural impact sparks for the press stamp.
## On each craft cycle, sparks burst outward from the stamp contact point.
## z_index=11 renders above the top sprite stamp head.

# Stamp center in Rotatable-local coords (right cell center)
const IMPACT_POS := Vector2(47, 15)

const SPARK_COLOR := Color(1.0, 0.75, 0.15, 0.9)
const SPARK_DIM := Color(0.9, 0.45, 0.08, 0.7)
const SPARK_HOT := Color(1.0, 0.95, 0.5, 1.0)

const MAX_SPARKS := 12
const SPARK_SPEED := 45.0
const SPARK_LIFETIME := 0.35
const BURST_INTERVAL := 0.6  # time between bursts (roughly matches craft cycle)
const HOLD_TIME := 0.3

var _active := false
var _hold_timer := 0.0
var _burst_timer := 0.0
var _sparks: Array = []  # [{pos, vel, age, size}]
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

	# Spawn bursts
	if want_active:
		_burst_timer += delta
		if _burst_timer >= BURST_INTERVAL:
			_burst_timer = 0.0
			_spawn_burst()

	# Update sparks
	var i := 0
	while i < _sparks.size():
		var s: Dictionary = _sparks[i]
		s.age += delta
		if s.age >= SPARK_LIFETIME:
			_sparks.remove_at(i)
			continue
		s.pos += s.vel * delta
		# Gravity/deceleration
		s.vel *= 0.95
		i += 1

	if not _sparks.is_empty():
		queue_redraw()

func _spawn_burst() -> void:
	var count := _rng.randi_range(5, MAX_SPARKS)
	for _i in range(count):
		var angle := _rng.randf() * TAU
		var speed := _rng.randf_range(SPARK_SPEED * 0.5, SPARK_SPEED)
		_sparks.append({
			pos = IMPACT_POS + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2)),
			vel = Vector2(cos(angle), sin(angle)) * speed,
			age = 0.0,
			size = _rng.randf_range(0.5, 1.5),
		})

func _draw() -> void:
	for s in _sparks:
		var t: float = float(s.age) / SPARK_LIFETIME
		var alpha: float = 1.0 - t
		var sz: float = float(s.size) * (1.0 - t * 0.5)

		var col: Color
		if t < 0.15:
			col = SPARK_HOT
		elif t < 0.5:
			col = SPARK_COLOR
		else:
			col = SPARK_DIM
		col.a *= alpha

		# Draw as short streak in velocity direction
		var pos: Vector2 = s.pos as Vector2
		var vel: Vector2 = s.vel as Vector2
		var streak := vel.normalized() * sz * 2.0
		draw_line(pos - streak, pos + streak, col, sz)
		draw_circle(pos, sz * 0.7, col)
