class_name EnergyOverlay
extends Node2D

## Draws energy connection wires between linked EnergyNodes and
## "no power" indicators on unpowered buildings.

const TILE_SIZE := 32.0
const WIRE_COLOR := Color(0.3, 0.65, 1.0, 0.5)
const WIRE_COLOR_ACTIVE := Color(0.4, 0.8, 1.0, 0.7)
const WIRE_WIDTH := 1.5
const PARTICLE_COLOR := Color(0.5, 0.85, 1.0, 0.85)
const PARTICLE_SPEED := 40.0
const PARTICLE_SPACING := 16.0
const PARTICLE_RADIUS := 1.8
const NO_POWER_COLOR := Color(1.0, 0.25, 0.15, 0.85)

var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if not GameManager.energy_system:
		return

	var es = GameManager.energy_system
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
			_draw_energy_wire(node, other)

	for logic in es.energy_buildings:
		if not is_instance_valid(logic):
			continue
		if not logic.energy:
			continue
		if logic.energy.base_energy_demand > 0.0 and not logic.energy.is_powered:
			_draw_no_power_icon(logic)

func _draw_energy_wire(from_node, to_node) -> void:
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

	# Catenary sag
	var mid: Vector2 = (from_pos + to_pos) * 0.5
	var dist: float = from_pos.distance_to(to_pos)
	var sag: float = dist * 0.08
	var mid_sagged: Vector2 = mid + Vector2(0, sag)

	# Draw as bezier segments
	var segments: int = maxi(int(dist / 8.0), 4)
	var prev: Vector2 = from_pos
	for i in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var a: Vector2 = from_pos.lerp(mid_sagged, t)
		var b: Vector2 = mid_sagged.lerp(to_pos, t)
		var point: Vector2 = a.lerp(b, t)
		draw_line(prev, point, wire_col, WIRE_WIDTH)
		prev = point

	# Energy particles
	if avg_fill < 0.01:
		return

	# Particles flow from high stored energy toward low stored energy
	var from_stored: float = 0.0
	var to_stored: float = 0.0
	if from_node.owner_logic and from_node.owner_logic.energy:
		from_stored = from_node.owner_logic.energy.energy_stored
	if to_node.owner_logic and to_node.owner_logic.energy:
		to_stored = to_node.owner_logic.energy.energy_stored
	var flow_dir: float = sign(from_stored - to_stored)
	if absf(from_stored - to_stored) < 0.5:
		flow_dir = 0.0

	var particle_count: int = maxi(int(dist / PARTICLE_SPACING), 1)
	var particle_alpha: float = 0.3 + avg_fill * 0.7
	var p_color := Color(PARTICLE_COLOR.r, PARTICLE_COLOR.g, PARTICLE_COLOR.b, particle_alpha)

	for i in range(particle_count):
		var base_t: float = float(i) / float(particle_count)
		var offset_t: float = fmod(_time * PARTICLE_SPEED / dist * flow_dir + base_t, 1.0)
		if offset_t < 0.0:
			offset_t += 1.0
		var a: Vector2 = from_pos.lerp(mid_sagged, offset_t)
		var b: Vector2 = mid_sagged.lerp(to_pos, offset_t)
		var p_pos: Vector2 = a.lerp(b, offset_t)
		var radius: float = PARTICLE_RADIUS * (0.7 + avg_fill * 0.3)
		draw_circle(p_pos, radius, p_color)

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

func _get_node_world_pos(node) -> Vector2:
	# Use the EnergyNode's actual scene position (rotated during placement)
	if node is Node2D:
		return node.global_position
	return Vector2(node.owner_grid_pos) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
