extends Node2D

## Animated molten metal pour from crucible to casting molds.
## Draws glowing droplets that travel from the crucible spout down
## a channel into the mold area. Active when the smelter is crafting.

# Pour path: crucible spout (15, 60) -> channel bend (15, 68) -> split to molds
# Left mold target: ~(16, 77), Right mold target: ~(47, 77)
# All coordinates in Rotatable-local (sprite-space)

const MOLTEN := Color(1.0, 0.55, 0.0, 0.95)
const MOLTEN_BR := Color(1.0, 0.70, 0.27, 0.9)
const MOLTEN_DIM := Color(0.63, 0.35, 0.06, 0.8)
const GLOW := Color(1.0, 0.85, 0.4, 0.3)

const HOLD_TIME := 0.35
const MAX_DRIPS := 6
const DRIP_SPEED := 40.0  # pixels per second
const SPAWN_INTERVAL := 0.18

# Path waypoints for left and right pour channels
const PATH_LEFT: Array = [
	Vector2(15, 60), Vector2(15, 65), Vector2(15, 70),
	Vector2(14, 75), Vector2(14, 78),
]
const PATH_RIGHT: Array = [
	Vector2(15, 60), Vector2(18, 63), Vector2(24, 65),
	Vector2(32, 67), Vector2(40, 70), Vector2(47, 75), Vector2(47, 78),
]

var _active := false
var _hold_timer := 0.0
var _heat := 0.0
var _spawn_timer := 0.0
var _drips: Array = []  # [{progress: float, path_idx: 0 or 1, size: float}]
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

	var target_heat := 1.0 if want_active else 0.0
	var heat_rate := 3.0 if want_active else 2.0
	_heat = move_toward(_heat, target_heat, delta * heat_rate)

	# Spawn new drips
	if want_active:
		_spawn_timer += delta
		if _spawn_timer >= SPAWN_INTERVAL and _drips.size() < MAX_DRIPS:
			_spawn_timer = 0.0
			_drips.append({
				progress = 0.0,
				path_idx = _rng.randi() % 2,
				size = _rng.randf_range(1.5, 2.5),
			})

	# Advance drips along their paths
	var i := 0
	while i < _drips.size():
		var drip: Dictionary = _drips[i]
		var path: Array = PATH_LEFT if drip.path_idx == 0 else PATH_RIGHT
		var path_len := _path_length(path)
		drip.progress += (DRIP_SPEED * delta) / path_len
		if drip.progress >= 1.0:
			_drips.remove_at(i)
		else:
			i += 1

	if _heat > 0.01 or not _drips.is_empty():
		queue_redraw()

func _draw() -> void:
	if _heat < 0.01 and _drips.is_empty():
		return

	for drip in _drips:
		var path: Array = PATH_LEFT if drip.path_idx == 0 else PATH_RIGHT
		var pos := _sample_path(path, drip.progress)
		var alpha: float = _heat * (1.0 - float(drip.progress) * 0.3)
		var col := MOLTEN
		col.a = alpha
		var col_bright := MOLTEN_BR
		col_bright.a = alpha
		var s: float = float(drip.size)

		# Glow halo
		var glow := GLOW
		glow.a = alpha * 0.4
		draw_circle(pos, s + 2.0, glow)
		# Main drip
		draw_circle(pos, s, col)
		draw_circle(pos, s * 0.5, col_bright)

	# Continuous stream at spout when active (thin line from crucible edge)
	if _heat > 0.3:
		var stream_col := MOLTEN_DIM
		stream_col.a = _heat * 0.6
		draw_line(Vector2(15, 58), Vector2(15, 63), stream_col, 1.5)

func _path_length(path: Array) -> float:
	var total := 0.0
	for j in range(1, path.size()):
		total += (path[j] as Vector2).distance_to(path[j - 1] as Vector2)
	return total

func _sample_path(path: Array, t: float) -> Vector2:
	if path.size() < 2:
		return path[0] as Vector2
	var total := _path_length(path)
	var target_dist := t * total
	var accum := 0.0
	for j in range(1, path.size()):
		var seg_len: float = (path[j] as Vector2).distance_to(path[j - 1] as Vector2)
		if accum + seg_len >= target_dist:
			var seg_t := (target_dist - accum) / seg_len
			return (path[j - 1] as Vector2).lerp(path[j] as Vector2, seg_t)
		accum += seg_len
	return path[path.size() - 1] as Vector2
