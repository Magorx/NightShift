class_name EnergySystem
extends Node

## Manages all energy processing: registration, network rebuild, per-tick distribution.
## Added as child of GameWorld (like ConveyorSystem).

const TILE_SIZE := 32
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

# All buildings with energy != null, registered on placement
var energy_buildings: Array = []  # Array[BuildingLogic]

# All EnergyNode instances, registered on placement
var energy_nodes: Array = []  # Array[EnergyNode]

# Computed networks (rebuilt when dirty)
var networks: Array = []  # Array[EnergyNetwork]
var _networks_dirty: bool = true

# Tracks last placed node for auto-link on next placement
var _last_placed_node = null  # EnergyNode or null

# ── Registration ────────────────────────────────────────────────────────────

func register_building(logic: BuildingLogic) -> void:
	if logic.energy and not energy_buildings.has(logic):
		energy_buildings.append(logic)
		_networks_dirty = true

func unregister_building(logic: BuildingLogic) -> void:
	energy_buildings.erase(logic)
	_networks_dirty = true

func register_node(node) -> void:
	if not energy_nodes.has(node):
		energy_nodes.append(node)
		# Auto-link to last placed node if in range and both have free slots
		if _last_placed_node and is_instance_valid(_last_placed_node):
			if node.can_connect_to(_last_placed_node):
				node.connect_to(_last_placed_node)
		_last_placed_node = node
		_networks_dirty = true

func unregister_node(node) -> void:
	node.disconnect_all()
	energy_nodes.erase(node)
	if _last_placed_node == node:
		_last_placed_node = null
	_networks_dirty = true

# ── Per-tick processing ─────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if _networks_dirty:
		_rebuild_networks()
		_networks_dirty = false

	for network in networks:
		network.tick(delta)

# ── Network rebuild (flood-fill) ────────────────────────────────────────────

func _rebuild_networks() -> void:
	networks.clear()

	# Build adjacency map: grid_pos -> BuildingLogic (only energy-capable buildings)
	var pos_to_logic: Dictionary = {}
	for logic in energy_buildings:
		if not is_instance_valid(logic):
			continue
		if not logic.energy or logic.energy.energy_capacity <= 0.0:
			continue
		# Register all cells this building occupies
		var building = logic.get_parent()
		if building and building.has_method("init"):  # BuildingBase
			var def = GameManager.get_building_def(building.building_id)
			if def:
				var rotated_shape = def.get_rotated_shape(building.rotation_index)
				for cell in rotated_shape:
					pos_to_logic[building.grid_pos + cell] = logic

	# Build node adjacency: EnergyNode -> list of connected EnergyNode
	# (already stored in node.connections)

	# Flood-fill to find connected components
	var visited_logics: Dictionary = {}  # logic instance_id -> true
	for logic in energy_buildings:
		if not is_instance_valid(logic):
			continue
		if not logic.energy or logic.energy.energy_capacity <= 0.0:
			continue
		var lid = logic.get_instance_id()
		if visited_logics.has(lid):
			continue

		# BFS from this building
		var network = EnergyNetwork.new()
		var queue: Array = [logic]
		visited_logics[lid] = true

		while not queue.is_empty():
			var current = queue.pop_front()
			network.buildings.append(current)

			if current.energy.generation_rate > 0.0:
				network.generators.append(current)
			if current.energy.base_energy_demand > 0.0:
				network.consumers.append(current)

			# Find neighbors via adjacency (4-directional)
			var current_building = current.get_parent()
			if not current_building:
				continue
			var current_def = GameManager.get_building_def(current_building.building_id)
			if not current_def:
				continue
			var current_cells: Array = current_def.get_rotated_shape(current_building.rotation_index)
			for cell in current_cells:
				var world_cell: Vector2i = current_building.grid_pos + cell
				for dir in DIRECTION_VECTORS:
					var neighbor_pos = world_cell + dir
					if pos_to_logic.has(neighbor_pos):
						var neighbor_logic = pos_to_logic[neighbor_pos]
						var nlid = neighbor_logic.get_instance_id()
						if not visited_logics.has(nlid):
							visited_logics[nlid] = true
							queue.append(neighbor_logic)

			# Find neighbors via EnergyNode connections
			var enode = current.get_energy_node()
			if enode:
				for connected_node in enode.connections:
					if not is_instance_valid(connected_node):
						continue
					if not connected_node.owner_logic:
						continue
					var cn_logic = connected_node.owner_logic
					var cn_lid = cn_logic.get_instance_id()
					if not visited_logics.has(cn_lid):
						visited_logics[cn_lid] = true
						queue.append(cn_logic)
					# Record node edge for throughput constraints
					network.node_edges.append({from_node = enode, to_node = connected_node})

		if not network.buildings.is_empty():
			networks.append(network)

# ── Utility ─────────────────────────────────────────────────────────────────

func mark_dirty() -> void:
	_networks_dirty = true

func clear_all() -> void:
	energy_buildings.clear()
	energy_nodes.clear()
	networks.clear()
	_networks_dirty = true
	_last_placed_node = null

## Get the network a building belongs to (for debug/info panel).
func get_network_for(logic: BuildingLogic) -> EnergyNetwork:
	for network in networks:
		if network.buildings.has(logic):
			return network
	return null
