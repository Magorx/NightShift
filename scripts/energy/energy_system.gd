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

# When true, register_node() skips auto-linking (set during save load)
var loading: bool = false

# Per-tick edge flow data for visualization (built after ticking networks)
# Key: "min_logic_id:max_logic_id", Value: net flow (positive = min → max)
var edge_flows: Dictionary = {}

# Set to true by EnergyOverlay when it needs flow data (energy link mode active)
var needs_edge_flows: bool = false

# ── Registration ────────────────────────────────────────────────────────────

func register_building(logic: BuildingLogic) -> void:
	if logic.energy and not energy_buildings.has(logic):
		energy_buildings.append(logic)
		_networks_dirty = true

func unregister_building(logic: BuildingLogic) -> void:
	if logic.energy:
		logic.energy.network = null
	energy_buildings.erase(logic)
	_networks_dirty = true

func register_node(node) -> void:
	if not energy_nodes.has(node):
		energy_nodes.append(node)
		if not loading:
			# Auto-link to last placed node if in range, both have free slots,
			# and buildings are NOT already adjacent (adjacency edges handle that)
			if _last_placed_node and is_instance_valid(_last_placed_node):
				if node.can_connect_to(_last_placed_node) and not _are_buildings_adjacent(node.owner_logic, _last_placed_node.owner_logic):
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

	if needs_edge_flows:
		_build_edge_flows()
	elif not edge_flows.is_empty():
		edge_flows.clear()

# ── Network rebuild (flood-fill + edge graph) ──────────────────────────────

func _rebuild_networks() -> void:
	# Clear old network references
	for logic in energy_buildings:
		if is_instance_valid(logic) and logic.energy:
			logic.energy.network = null
	networks.clear()

	# Build adjacency map: grid_pos -> BuildingLogic (only energy-capable buildings)
	var pos_to_logic: Dictionary = {}
	for logic in energy_buildings:
		if not is_instance_valid(logic):
			continue
		if not logic.energy or logic.energy.energy_capacity <= 0.0:
			continue
		var building = logic.get_parent()
		if building and building.has_method("init"):  # BuildingBase
			var def = GameManager.get_building_def(building.building_id)
			if def:
				var rotated_shape = def.get_rotated_shape(building.rotation_index)
				for cell in rotated_shape:
					pos_to_logic[building.grid_pos + cell] = logic

	# Flood-fill to find connected components and build edge lists
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
		var edge_set: Dictionary = {}  # int key -> true, dedup all edges
		visited_logics[lid] = true

		while not queue.is_empty():
			var current = queue.pop_front()
			network.buildings.append(current)

			if current.energy.generation_rate > 0.0:
				network.generators.append(current)
			if current.energy.base_energy_demand > 0.0:
				network.consumers.append(current)

			# Find neighbors via grid adjacency and create adjacency edges
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
					if not pos_to_logic.has(neighbor_pos):
						continue
					var neighbor_logic = pos_to_logic[neighbor_pos]
					if neighbor_logic == current:
						continue  # same building occupies both cells
					var nlid = neighbor_logic.get_instance_id()

					# Record adjacency edge (deduplicated per building pair)
					var eid_a: int = current.get_instance_id()
					var eid_b: int = nlid
					var min_e: int = mini(eid_a, eid_b)
					var max_e: int = maxi(eid_a, eid_b)
					var edge_key: int = (min_e + max_e) * (min_e + max_e + 1) / 2 + max_e
					if not edge_set.has(edge_key):
						edge_set[edge_key] = true
						var throughput := minf(
							current.energy.adjacency_throughput,
							neighbor_logic.energy.adjacency_throughput
						)
						network.edges.append({
							a = current, b = neighbor_logic,
							throughput = throughput,
							net_flow = 0.0
						})

					if not visited_logics.has(nlid):
						visited_logics[nlid] = true
						queue.append(neighbor_logic)

			# Find neighbors via EnergyNode connections and create node edges
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
					# Record node edge (deduplicated, offset by 1 to distinguish from adjacency)
					var eid_a: int = enode.get_instance_id()
					var eid_b: int = connected_node.get_instance_id()
					var min_n: int = mini(eid_a, eid_b)
					var max_n: int = maxi(eid_a, eid_b)
					var edge_key: int = (min_n + max_n) * (min_n + max_n + 1) / 2 + max_n + 1
					if not edge_set.has(edge_key):
						edge_set[edge_key] = true
						var throughput := minf(enode.throughput, connected_node.throughput)
						network.edges.append({
							a = current, b = cn_logic,
							throughput = throughput,
							net_flow = 0.0
						})

		if not network.buildings.is_empty():
			for b in network.buildings:
				b.energy.network = network
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
	loading = false

## Check if two buildings share a cardinal-adjacent cell.
func _are_buildings_adjacent(logic_a, logic_b) -> bool:
	if not logic_a or not logic_b:
		return false
	var building_a = logic_a.get_parent()
	var building_b = logic_b.get_parent()
	if not building_a or not building_b:
		return false
	var def_a = GameManager.get_building_def(building_a.building_id)
	var def_b = GameManager.get_building_def(building_b.building_id)
	if not def_a or not def_b:
		return false
	var cells_b: Dictionary = {}
	for cb in def_b.get_rotated_shape(building_b.rotation_index):
		cells_b[building_b.grid_pos + cb] = true
	for ca in def_a.get_rotated_shape(building_a.rotation_index):
		var wca: Vector2i = building_a.grid_pos + ca
		for dir in DIRECTION_VECTORS:
			if cells_b.has(wca + dir):
				return true
	return false

## Build a lookup of per-tick net energy flow for each edge (for overlay visualization).
## Uses integer pair keys (Cantor pairing) instead of string formatting.
func _build_edge_flows() -> void:
	edge_flows.clear()
	for network in networks:
		for edge in network.edges:
			if not is_instance_valid(edge.a) or not is_instance_valid(edge.b):
				continue
			var id_a: int = edge.a.get_instance_id()
			var id_b: int = edge.b.get_instance_id()
			var min_id: int = mini(id_a, id_b)
			var max_id: int = maxi(id_a, id_b)
			# Cantor pairing: unique int key from two ints (no string formatting)
			var key: int = (min_id + max_id) * (min_id + max_id + 1) / 2 + max_id
			var canonical_flow: float = edge.net_flow if id_a == min_id else -edge.net_flow
			if edge_flows.has(key):
				edge_flows[key] += canonical_flow
			else:
				edge_flows[key] = canonical_flow

## Get the network a building belongs to (for debug/info panel).
func get_network_for(logic: BuildingLogic) -> EnergyNetwork:
	for network in networks:
		if network.buildings.has(logic):
			return network
	return null
