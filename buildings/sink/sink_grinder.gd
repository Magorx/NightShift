extends Node2D

## Procedural rotating grinder blades inside the sink intake pit.
## Two counter-rotating blade sets spin when items are being consumed.
## Visible through the grate opening in the base layer.

# Intake pit center in Rotatable-local coords
const CENTER := Vector2(17, 15)
const RADIUS := 7.0

# Blade colors
const BLADE := Color(0.42, 0.17, 0.17, 0.9)
const BLADE_HI := Color(0.55, 0.25, 0.25, 0.85)
const HUB := Color(0.35, 0.15, 0.15, 0.95)
const HUB_HI := Color(0.50, 0.22, 0.22, 0.9)

const SPIN_SPEED := 3.0       # radians/sec when active
const DECEL_RATE := 1.5       # radians/sec/sec slowdown

var _angle := 0.0
var _speed := 0.0
var _last_consumed := 0
var _logic: Node = null

func _ready() -> void:
	# Find the ItemSink logic node
	for child in get_parent().get_parent().get_children():
		if child.has_method("serialize_state") and child.get("items_consumed") != null:
			_logic = child
			_last_consumed = child.items_consumed
			break

func _physics_process(delta: float) -> void:
	# Detect item consumption
	var consuming := false
	if _logic and is_instance_valid(_logic):
		var current: int = _logic.items_consumed
		if current > _last_consumed:
			consuming = true
		_last_consumed = current

	# Accelerate/decelerate
	if consuming:
		_speed = move_toward(_speed, SPIN_SPEED, delta * 6.0)
	else:
		_speed = move_toward(_speed, 0.0, delta * DECEL_RATE)

	if _speed > 0.01:
		_angle += _speed * delta
		queue_redraw()
	elif _speed <= 0.01 and _angle != 0.0:
		queue_redraw()  # one final draw at stopped position

func _draw() -> void:
	if _speed < 0.001:
		return

	# Draw two sets of 4 blades, counter-rotating
	_draw_blade_set(_angle, BLADE, BLADE_HI)
	_draw_blade_set(-_angle + PI * 0.25, BLADE, BLADE_HI)

	# Central hub
	draw_circle(CENTER, 2.5, HUB)
	draw_circle(CENTER, 1.5, HUB_HI)

func _draw_blade_set(angle: float, col: Color, hi_col: Color) -> void:
	for i in range(4):
		var a := angle + i * PI * 0.5
		var tip := CENTER + Vector2(cos(a), sin(a)) * RADIUS
		var side := Vector2(-sin(a), cos(a)) * 2.0

		# Blade body (tapered triangle)
		var p1 := CENTER + side * 0.5
		var p2 := CENTER - side * 0.5
		draw_line(p1, tip, col, 2.0)
		draw_line(p2, tip, col, 2.0)
		# Blade highlight (leading edge)
		draw_line(CENTER + side * 0.3, tip + side * 0.2, hi_col, 1.0)
