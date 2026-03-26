class_name EnergyOverlay
extends Node2D

## Draws energy connection wires between linked EnergyNodes,
## spawns GPU particle emitters along wires for energy flow,
## and shows "no power" indicators on unpowered buildings.

const TILE_SIZE := 32.0
const WIRE_COLOR := Color(0.3, 0.65, 1.0, 0.5)
const WIRE_COLOR_ACTIVE := Color(0.4, 0.8, 1.0, 0.7)
const WIRE_WIDTH := 1.5
const NO_POWER_COLOR := Color(1.0, 0.25, 0.15, 0.85)
const SMOOTH_RATE := 2.5  # how fast flow direction changes (per second)

## The particle emitter scene — tweak visuals in this .tscn via the editor.
var _emitter_scene: PackedScene = preload("res://scripts/energy/energy_wire_emitter.tscn")

var _time: float = 0.0
var _delta: float = 0.0
var _smoothed_flow: Dictionary = {}  # canonical pair key -> smoothed direction (-1..1)
var _wire_emitters: Dictionary = {}  # pair_key -> GPUParticles2D
var _active_pairs: Dictionary = {}   # pair_key -> true, built each frame

func _is_energy_mode() -> bool:
	var bs = get_node_or_null("../BuildSystem")
	return bs and bs.energy_link_mode

func _process(delta: float) -> void:
	_time += delta
	_delta = delta
	_active_pairs.clear()
	_update_emitters()
	_cleanup_stale_emitters()
	queue_redraw()

func _draw() -> void:
	if not GameManager.energy_system:
		return

	var es = GameManager.energy_system
	var show_wires: bool = _is_energy_mode()

	if show_wires:
		var drawn_pairs: Dictionary = {}
		for node in es.energy_nodes:
			if not is_instance_valid(node):
				continue
			for other in node.connections:
				if not is_instance_valid(other):
					continue
				var id_a: int = node.get_instance_id()
				var id_b: int = other.get_instance_id()
				var pair_key: String
				if id_a < id_b:
					pair_key = "%d:%d" % [id_a, id_b]
				else:
					pair_key = "%d:%d" % [id_b, id_a]
				if drawn_pairs.has(pair_key):
					continue
				drawn_pairs[pair_key] = true
				_draw_wire(node, other)

	# No-power icons always visible
	for logic in es.energy_buildings:
		if not is_instance_valid(logic):
			continue
		if not logic.energy:
			continue
		if logic.energy.base_energy_demand > 0.0 and not logic.energy.is_powered:
			_draw_no_power_icon(logic)

# ── Wire drawing ─────────────────────────────────────────────────────────────

func _draw_wire(from_node, to_node) -> void:
	var from_pos: Vector2 = _get_node_world_pos(from_node)
	var to_pos: Vector2 = _get_node_world_pos(to_node)

	var from_fill: float = 0.0
	var to_fill: float = 0.0
	if from_node.owner_logic and from_node.owner_logic.energy:
		from_fill = from_node.owner_logic.energy.get_fill_ratio()
	if to_node.owner_logic and to_node.owner_logic.energy:
		to_fill = to_node.owner_logic.energy.get_fill_ratio()
	var avg_fill: float = (from_fill + to_fill) * 0.5
	var wire_col: Color = WIRE_COLOR.lerp(WIRE_COLOR_ACTIVE, avg_fill)

	draw_line(from_pos, to_pos, wire_col, WIRE_WIDTH)

# ── Particle emitter management ──────────────────────────────────────────────

func _update_emitters() -> void:
	if not GameManager.energy_system:
		return

	var es = GameManager.energy_system

	for node in es.energy_nodes:
		if not is_instance_valid(node):
			continue
		for other in node.connections:
			if not is_instance_valid(other):
				continue
			var id_a: int = node.get_instance_id()
			var id_b: int = other.get_instance_id()
			if id_a >= id_b:
				continue  # process each pair once
			var pair_key: String = "%d:%d" % [id_a, id_b]
			_active_pairs[pair_key] = true
			_update_wire_emitter(pair_key, node, other)

func _update_wire_emitter(pair_key: String, from_node, to_node) -> void:
	var from_pos: Vector2 = _get_node_world_pos(from_node)
	var to_pos: Vector2 = _get_node_world_pos(to_node)
	var dist: float = from_pos.distance_to(to_pos)
	if dist < 1.0:
		_stop_emitter(pair_key)
		return

	# Look up actual energy flow direction
	var target_dir: float = 0.0
	var from_logic = from_node.owner_logic
	var to_logic = to_node.owner_logic
	if from_logic and to_logic and GameManager.energy_system:
		var es = GameManager.energy_system
		var id_from: int = from_logic.get_instance_id()
		var id_to: int = to_logic.get_instance_id()
		var min_id: int = mini(id_from, id_to)
		var max_id: int = maxi(id_from, id_to)
		var flow_key := "%d:%d" % [min_id, max_id]
		var canonical_flow: float = es.edge_flows.get(flow_key, 0.0)
		var directed_flow: float = canonical_flow if id_from == min_id else -canonical_flow
		if absf(directed_flow) >= 0.01:
			target_dir = signf(directed_flow)

	# Smooth the flow direction for momentum
	var from_is_min: bool = (from_node.get_instance_id() <= to_node.get_instance_id())
	var canonical_target: float = target_dir if from_is_min else -target_dir
	var current_vel: float = _smoothed_flow.get(pair_key, 0.0)
	current_vel = move_toward(current_vel, canonical_target, _delta * SMOOTH_RATE)
	_smoothed_flow[pair_key] = current_vel
	var flow_dir: float = current_vel if from_is_min else -current_vel

	# Check activity — show particles when there's flow or stored energy
	var from_fill: float = 0.0
	var to_fill: float = 0.0
	if from_logic and from_logic.energy:
		from_fill = from_logic.energy.get_fill_ratio()
	if to_logic and to_logic.energy:
		to_fill = to_logic.energy.get_fill_ratio()
	var avg_fill: float = (from_fill + to_fill) * 0.5
	var activity: float = maxf(avg_fill, absf(flow_dir))

	if activity < 0.01:
		_stop_emitter(pair_key)
		return

	# Determine emission source and direction
	var source_pos: Vector2
	var target_pos: Vector2
	if flow_dir >= 0.0:
		source_pos = from_pos
		target_pos = to_pos
	else:
		source_pos = to_pos
		target_pos = from_pos

	var dir_vec: Vector2 = (target_pos - source_pos).normalized()
	var angle: float = dir_vec.angle()

	# Get or create emitter
	var emitter: GPUParticles2D = _wire_emitters.get(pair_key)
	if not emitter or not is_instance_valid(emitter):
		emitter = _emitter_scene.instantiate() as GPUParticles2D
		add_child(emitter)
		_wire_emitters[pair_key] = emitter

	emitter.position = source_pos
	emitter.rotation = angle

	# Lifetime = distance / avg speed so particles traverse the full wire
	var mat: ParticleProcessMaterial = emitter.process_material
	var avg_speed: float = (mat.initial_velocity_min + mat.initial_velocity_max) * 0.5
	if avg_speed > 0.0:
		emitter.lifetime = dist / avg_speed
	else:
		emitter.lifetime = 1.0

	emitter.emitting = true

func _stop_all_emitters() -> void:
	for key in _wire_emitters:
		var emitter = _wire_emitters[key]
		if is_instance_valid(emitter):
			emitter.emitting = false

func _stop_emitter(pair_key: String) -> void:
	var emitter: GPUParticles2D = _wire_emitters.get(pair_key)
	if emitter and is_instance_valid(emitter):
		emitter.emitting = false

func _cleanup_stale_emitters() -> void:
	var to_remove: Array = []
	for key in _wire_emitters:
		if not _active_pairs.has(key):
			to_remove.append(key)
	for key in to_remove:
		var emitter = _wire_emitters[key]
		if is_instance_valid(emitter):
			emitter.queue_free()
		_wire_emitters.erase(key)
		_smoothed_flow.erase(key)

# ── No-power icon ────────────────────────────────────────────────────────────

func _draw_no_power_icon(logic) -> void:
	var building = logic.get_parent()
	if not building or not is_instance_valid(building):
		return

	var pos := Vector2(logic.grid_pos) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	var flash: float = 0.5 + 0.5 * sin(_time * 4.0)

	# Red circle background
	var bg_alpha: float = 0.4 + 0.3 * flash
	draw_circle(pos, 8.0, Color(0.15, 0.05, 0.05, bg_alpha))

	# Lightning bolt
	var bolt_col := Color(NO_POWER_COLOR.r, NO_POWER_COLOR.g, NO_POWER_COLOR.b, 0.6 + 0.4 * flash)
	draw_line(pos + Vector2(1, -6), pos + Vector2(-2, -1), bolt_col, 1.5)
	draw_line(pos + Vector2(-2, -1), pos + Vector2(2, -1), bolt_col, 1.5)
	draw_line(pos + Vector2(2, -1), pos + Vector2(-1, 6), bolt_col, 1.5)

	# Red X
	var x_col := Color(1.0, 0.2, 0.1, 0.5 + 0.3 * flash)
	draw_line(pos + Vector2(-5, -5), pos + Vector2(5, 5), x_col, 1.5)
	draw_line(pos + Vector2(5, -5), pos + Vector2(-5, 5), x_col, 1.5)

# ── Utility ──────────────────────────────────────────────────────────────────

func _get_node_world_pos(node) -> Vector2:
	if node is Node2D:
		return node.global_position
	return Vector2(node.owner_grid_pos) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
