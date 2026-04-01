extends Node2D

## Procedural liquid flow between the two reaction chambers.
## Green chemical liquid drips travel through the connecting pipe
## between the top tank (y~26) and bottom tank (y~38).
## Also adds bubbling in both tanks.

# Pipe region (Rotatable-local coords)
const PIPE_X := 32.0
const PIPE_TOP := 24.0
const PIPE_BOTTOM := 40.0

# Tank regions for bubbles
const TANK1_RECT := Rect2(22, 8, 20, 14)   # top tank inner
const TANK2_RECT := Rect2(22, 42, 20, 12)  # bottom tank inner

const CHEM_GREEN := Color(0.25, 0.50, 0.29, 0.8)
const CHEM_BRIGHT := Color(0.34, 0.66, 0.40, 0.9)
const CHEM_GLOW := Color(0.40, 0.80, 0.47, 0.6)
const BUBBLE_COL := Color(0.40, 0.80, 0.47, 0.5)

const DRIP_SPEED := 20.0
const DRIP_SPAWN := 0.15
const MAX_DRIPS := 8
const BUBBLE_SPAWN := 0.25
const MAX_BUBBLES := 8
const BUBBLE_SPEED := 6.0
const BUBBLE_LIFE := 0.8
const HOLD_TIME := 0.3

var _active := false
var _hold_timer := 0.0
var _drip_timer := 0.0
var _bubble_timer := 0.0
var _drips: Array = []    # [{y, size}]
var _bubbles: Array = []  # [{pos, age, size, tank}]  tank: 0=top, 1=bottom
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
		# Spawn pipe drips
		_drip_timer += delta
		if _drip_timer >= DRIP_SPAWN and _drips.size() < MAX_DRIPS:
			_drip_timer = 0.0
			_drips.append({
				y = PIPE_TOP,
				size = _rng.randf_range(1.0, 2.0),
			})
		# Spawn tank bubbles
		_bubble_timer += delta
		if _bubble_timer >= BUBBLE_SPAWN and _bubbles.size() < MAX_BUBBLES:
			_bubble_timer = 0.0
			var tank := _rng.randi() % 2
			var rect: Rect2 = TANK1_RECT if tank == 0 else TANK2_RECT
			_bubbles.append({
				pos = Vector2(
					_rng.randf_range(rect.position.x + 2, rect.end.x - 2),
					rect.end.y - 1
				),
				age = 0.0,
				size = _rng.randf_range(0.5, 1.0),
				tank = tank,
			})

	# Update drips
	var i := 0
	while i < _drips.size():
		var d: Dictionary = _drips[i]
		d.y = float(d.y) + DRIP_SPEED * delta
		if float(d.y) >= PIPE_BOTTOM:
			_drips.remove_at(i)
			continue
		i += 1

	# Update bubbles
	i = 0
	while i < _bubbles.size():
		var b: Dictionary = _bubbles[i]
		b.age = float(b.age) + delta
		if float(b.age) >= BUBBLE_LIFE:
			_bubbles.remove_at(i)
			continue
		b.pos.y -= BUBBLE_SPEED * delta
		b.pos.x += sin(float(b.age) * 5.0) * delta * 1.5
		i += 1

	if not _drips.is_empty() or not _bubbles.is_empty():
		queue_redraw()

func _draw() -> void:
	# Pipe drips
	for d in _drips:
		var y: float = float(d.y)
		var t: float = (y - PIPE_TOP) / (PIPE_BOTTOM - PIPE_TOP)
		var sz: float = float(d.size)
		var col := CHEM_GREEN
		col.a = 0.8 - t * 0.3
		# Glow halo
		var glow := CHEM_GLOW
		glow.a = 0.2 - t * 0.1
		draw_circle(Vector2(PIPE_X, y), sz + 1.5, glow)
		draw_circle(Vector2(PIPE_X, y), sz, col)
		draw_circle(Vector2(PIPE_X, y), sz * 0.4, CHEM_BRIGHT)

	# Tank bubbles
	for b in _bubbles:
		var pos: Vector2 = b.pos as Vector2
		var t: float = float(b.age) / BUBBLE_LIFE
		var alpha: float = (1.0 - t) * 0.5
		var sz: float = float(b.size)
		var col := BUBBLE_COL
		col.a = alpha
		draw_circle(pos, sz, col)
