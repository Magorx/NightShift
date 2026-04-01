extends Node2D

## Procedural bubbling in the research lab beaker/flask.
## Small circles rise inside the flask region, pop at the surface.
## Also adds floating data particles in the central chamber area.

# Flask region in Rotatable-local coords
const FLASK_LEFT := 31.0
const FLASK_RIGHT := 37.0
const FLASK_TOP := 18.0
const FLASK_BOTTOM := 27.0

# Chamber region for floating particles
const CHAMBER_LEFT := 18.0
const CHAMBER_RIGHT := 58.0
const CHAMBER_TOP := 8.0
const CHAMBER_BOTTOM := 56.0

const BUBBLE_COLOR := Color(0.53, 0.93, 0.87, 0.7)
const BUBBLE_POP := Color(0.53, 0.93, 0.87, 0.3)
const DATA_COLORS: Array = [
	Color(0.27, 0.73, 0.67, 0.4),  # teal
	Color(0.8, 0.2, 0.2, 0.35),    # red (science pack)
	Color(0.2, 0.67, 0.27, 0.35),  # green (science pack)
	Color(0.2, 0.4, 0.8, 0.35),    # blue (science pack)
]

const MAX_BUBBLES := 6
const BUBBLE_SPAWN := 0.2
const BUBBLE_SPEED := 8.0
const MAX_DATA_PARTICLES := 8
const DATA_SPAWN := 0.4
const DATA_SPEED := 5.0
const DATA_LIFETIME := 2.5
const HOLD_TIME := 0.4

var _active := false
var _hold_timer := 0.0
var _bubble_timer := 0.0
var _data_timer := 0.0
var _bubbles: Array = []    # [{pos, size, age}]
var _data_parts: Array = [] # [{pos, vel, age, color_idx}]
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

	if want_active:
		# Spawn bubbles
		_bubble_timer += delta
		if _bubble_timer >= BUBBLE_SPAWN and _bubbles.size() < MAX_BUBBLES:
			_bubble_timer = 0.0
			_bubbles.append({
				pos = Vector2(
					_rng.randf_range(FLASK_LEFT + 1, FLASK_RIGHT - 1),
					FLASK_BOTTOM - 1
				),
				size = _rng.randf_range(0.5, 1.2),
				age = 0.0,
			})
		# Spawn data particles
		_data_timer += delta
		if _data_timer >= DATA_SPAWN and _data_parts.size() < MAX_DATA_PARTICLES:
			_data_timer = 0.0
			_data_parts.append({
				pos = Vector2(
					_rng.randf_range(CHAMBER_LEFT + 4, CHAMBER_RIGHT - 4),
					_rng.randf_range(CHAMBER_TOP + 4, CHAMBER_BOTTOM - 4),
				),
				vel = Vector2(_rng.randf_range(-DATA_SPEED, DATA_SPEED), _rng.randf_range(-DATA_SPEED, DATA_SPEED)),
				age = 0.0,
				color_idx = _rng.randi() % DATA_COLORS.size(),
			})

	# Update bubbles
	var i := 0
	while i < _bubbles.size():
		var b: Dictionary = _bubbles[i]
		b.age += delta
		b.pos.y -= BUBBLE_SPEED * delta
		b.pos.x += sin(b.age * 4.0) * delta * 2.0
		if b.pos.y <= FLASK_TOP + 1:
			_bubbles.remove_at(i)
			continue
		i += 1

	# Update data particles
	i = 0
	while i < _data_parts.size():
		var d: Dictionary = _data_parts[i]
		d.age += delta
		if d.age >= DATA_LIFETIME:
			_data_parts.remove_at(i)
			continue
		d.pos += d.vel * delta
		# Bounce off chamber walls
		if d.pos.x < CHAMBER_LEFT + 2 or d.pos.x > CHAMBER_RIGHT - 2:
			d.vel.x = -float(d.vel.x)
		if d.pos.y < CHAMBER_TOP + 2 or d.pos.y > CHAMBER_BOTTOM - 2:
			d.vel.y = -float(d.vel.y)
		i += 1

	if not _bubbles.is_empty() or not _data_parts.is_empty():
		queue_redraw()

func _draw() -> void:
	# Bubbles in flask
	for b in _bubbles:
		var pos: Vector2 = b.pos as Vector2
		var sz: float = float(b.size)
		var rising_t: float = 1.0 - (pos.y - FLASK_TOP) / (FLASK_BOTTOM - FLASK_TOP)
		var alpha: float = 0.7 - rising_t * 0.3
		var col := BUBBLE_COLOR
		col.a = alpha
		draw_circle(pos, sz, col)
		# Highlight
		var hi := BUBBLE_POP
		hi.a = alpha * 0.5
		draw_circle(pos + Vector2(-0.5, -0.5), sz * 0.4, hi)

	# Data particles in chamber
	for d in _data_parts:
		var pos: Vector2 = d.pos as Vector2
		var t: float = float(d.age) / DATA_LIFETIME
		var alpha: float = 1.0 - t
		alpha = alpha * alpha
		var col: Color = DATA_COLORS[int(d.color_idx)]
		col.a *= alpha
		draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), col)
