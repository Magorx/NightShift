extends Node

## Manages building definitions, placed buildings, placement/removal, and queries.
## Extracted from GameManager to separate building concerns.

signal building_placed(building_id: StringName, grid_pos: Vector2i)

# Building registry: id -> BuildingDef
var building_defs: Dictionary = {}

# Recipe registry: converter_type -> Array[RecipeDef]
var recipes_by_type: Dictionary = {}

# Placed buildings: Vector2i -> BuildingBase (grid_pos -> node, multi-cell buildings have multiple entries)
var buildings: Dictionary = {}
# Unique building list (one entry per building, no multi-cell duplicates). Used for save serialization.
var unique_buildings: Array = []

# Multi-phase building configs: building_id -> config dict
# Config: {phases: [{building_id, max_distance (0=none), count_match (bool)}], link_fn: StringName}
# The key building_id is what the player selects; each phase has its own building_id to place.
# After all phases, link_fn(phase_placements: Array) is called on BuildingRegistry.
var placement_phases: Dictionary = {}

## Refund ratio when removing buildings (50%).
const BUILD_COST_REFUND_RATIO := 0.5

func _ready() -> void:
	_load_building_defs()
	_load_recipes()
	_register_placement_phases()

# ── Definition loading ──────────────────────────────────────────────────────

func _load_building_defs() -> void:
	var root_dir := DirAccess.open("res://buildings/")
	if not root_dir:
		return
	root_dir.list_dir_begin()
	var sub_name := root_dir.get_next()
	while sub_name != "":
		if root_dir.current_is_dir() and not sub_name.begins_with("_"):
			var sub_path := "res://buildings/" + sub_name + "/"
			var sub_dir := DirAccess.open(sub_path)
			if sub_dir:
				sub_dir.list_dir_begin()
				var file_name := sub_dir.get_next()
				while file_name != "":
					if file_name.ends_with(".tres"):
						var def = load(sub_path + file_name)
						if def:
							def.extract_from_scene()
							building_defs[def.id] = def
					file_name = sub_dir.get_next()
		sub_name = root_dir.get_next()

func _load_recipes() -> void:
	var dir_path := "res://resources/recipes/"
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var recipe = load(dir_path + file_name)
			if recipe:
				var ctype: String = recipe.converter_type
				if not recipes_by_type.has(ctype):
					recipes_by_type[ctype] = []
				recipes_by_type[ctype].append(recipe)
		file_name = dir.get_next()

func get_building_def(id: StringName):
	return building_defs.get(id)

# ── Multi-phase placement ───────────────────────────────────────────────────

func _register_placement_phases() -> void:
	placement_phases[&"tunnel_input"] = {
		phases = [
			{building_id = &"tunnel_input"},
			{building_id = &"tunnel_output", max_distance = 5, count_match = true},
		],
		link_fn = &"_link_underground_transport",
	}

## Link a tunnel input/output pair at two grid positions.
func link_tunnel_pair(pos_a: Vector2i, pos_b: Vector2i, length: int = -1) -> void:
	var a = buildings.get(pos_a)
	var b = buildings.get(pos_b)
	if not a or not b:
		return
	if not a.logic is UndergroundTransportLogic or not b.logic is UndergroundTransportLogic:
		return
	var dist: int = length if length >= 0 else (absi(pos_b.x - pos_a.x) + absi(pos_b.y - pos_a.y))
	a.logic.setup_pair(b.logic, dist)
	b.logic.setup_pair(a.logic, dist)

## Link underground transport inputs and outputs after multi-phase placement.
func _link_underground_transport(phase_placements: Array) -> void:
	var inputs: Array = phase_placements[0]
	var outputs: Array = phase_placements[1]
	var count := mini(inputs.size(), outputs.size())
	for i in range(count):
		link_tunnel_pair(inputs[i].pos, outputs[i].pos)

# ── Building cost ────────────────────────────────────────────────────────────

func can_afford_building(id: StringName) -> bool:
	if EconomyTracker.creative_mode:
		return true
	var def = get_building_def(id)
	if not def or def.build_cost.is_empty():
		return true
	if not GameManager.player:
		return true
	for stack in def.build_cost:
		if GameManager.player.count_item(stack.item.id) < stack.quantity:
			return false
	return true

func deduct_building_cost(id: StringName) -> void:
	if EconomyTracker.creative_mode:
		return
	var def = get_building_def(id)
	if not def or def.build_cost.is_empty() or not GameManager.player:
		return
	for stack in def.build_cost:
		GameManager.player.remove_item(stack.item.id, stack.quantity)

func refund_building_cost(id: StringName) -> void:
	var def = get_building_def(id)
	if not def or def.build_cost.is_empty() or not GameManager.player:
		return
	for stack in def.build_cost:
		var refund_qty: int = int(stack.quantity * BUILD_COST_REFUND_RATIO)
		if refund_qty > 0:
			GameManager.player.add_item(stack.item.id, refund_qty)

# ── Building placement ───────────────────────────────────────────────────────

func can_place_building(id: StringName, grid_pos: Vector2i, grid_size: int, rotation: int = 0) -> bool:
	var def = get_building_def(id)
	if not def:
		return false
	var rotated_shape: Array = def.get_rotated_shape(rotation)
	for cell in rotated_shape:
		var check_pos: Vector2i = grid_pos + Vector2i(cell)
		if check_pos.x < 0 or check_pos.y < 0 or check_pos.x >= grid_size or check_pos.y >= grid_size:
			return false
		if MapManager.walls.has(check_pos):
			return false
		if buildings.has(check_pos):
			var existing = buildings[check_pos]
			var existing_def = get_building_def(existing.building_id)
			if not existing_def or not existing_def.replaceable_by.has(id):
				return false
	# Delegate building-specific placement checks to the logic script
	if def.get_placement_error(grid_pos, rotation) != "":
		return false
	return true

func place_building(id: StringName, grid_pos: Vector2i, rotation: int = 0) -> Node:
	var def = get_building_def(id)
	if not def or not GameManager.building_layer:
		return null
	# Delegate building-specific placement checks
	if def.get_placement_error(grid_pos, rotation) != "":
		return null

	# Remove any existing replaceable buildings in the footprint
	var rotated_shape: Array = def.get_rotated_shape(rotation)
	var to_replace: Dictionary = {} # grid_pos -> true (deduplicate multi-cell buildings)
	for cell in rotated_shape:
		var check_pos: Vector2i = grid_pos + Vector2i(cell)
		if buildings.has(check_pos):
			var existing = buildings[check_pos]
			to_replace[existing.grid_pos] = true
	for replace_pos in to_replace:
		remove_building(replace_pos)

	# Instantiate building from its .tscn scene (contains Model + IO markers)
	var building: Node3D = def.scene.instantiate()
	building.init(id, grid_pos, rotation)
	# Position so the anchor cell aligns with grid_pos, elevated to terrain
	building.position = GridUtils.grid_to_world(grid_pos - def.anchor_cell)
	building.position.y = MapManager.get_terrain_height(grid_pos)
	# Rotation: Y-axis rotation (0=right, 1=down, 2=left, 3=up)
	building.rotation.y = -rotation * PI / 2.0

	GameManager.building_layer.add_child(building)

	# Deduct build cost from player inventory
	deduct_building_cost(id)

	# Register all occupied cells (rotated)
	for cell in rotated_shape:
		buildings[grid_pos + cell] = building
	unique_buildings.append(building)

	# Find and configure the logic node
	var logic: BuildingLogic = _find_logic_node(building)
	if logic:
		logic.configure(def, grid_pos, rotation)
		building.logic = logic
		if GameManager.building_tick_system:
			GameManager.building_tick_system.register(logic)

	building_placed.emit(id, grid_pos)
	_notify_adjacent_conveyors(grid_pos)
	return building

## Find the first BuildingLogic child of a building node.
func _find_logic_node(building: Node) -> BuildingLogic:
	for child in building.get_children():
		if child is BuildingLogic:
			return child
	return null

func remove_building(grid_pos: Vector2i) -> void:
	var building = buildings.get(grid_pos)
	if not building:
		return
	var def = get_building_def(building.building_id)

	# Refund partial build cost to player
	refund_building_cost(building.building_id)

	# Unregister from BuildingTickSystem
	if building.logic and GameManager.building_tick_system:
		GameManager.building_tick_system.unregister(building.logic)

	# Let the logic node handle its own cleanup
	if building.logic:
		building.logic.on_removing()
		building.logic.cleanup_visuals()

	# Remove all occupied cells
	var rotated_shape: Array = []
	if def:
		rotated_shape = def.get_rotated_shape(building.rotation_index)
		for cell in rotated_shape:
			buildings.erase(building.grid_pos + cell)
	else:
		buildings.erase(grid_pos)
	unique_buildings.erase(building)

	building.queue_free()
	_notify_adjacent_conveyors(grid_pos)

## Tell adjacent conveyors to re-evaluate their shape after a placement or removal.
func _notify_adjacent_conveyors(grid_pos: Vector2i) -> void:
	for dir_idx in 4:
		var adj_pos: Vector2i = grid_pos + BuildingLogic.DIRECTION_VECTORS[dir_idx]
		var conveyor = get_conveyor_at(adj_pos)
		if conveyor:
			conveyor.update_shape()

# ── Building queries ─────────────────────────────────────────────────────────

func get_building_at(grid_pos: Vector2i):
	return buildings.get(grid_pos)

func get_conveyor_at(grid_pos: Vector2i):
	var building = buildings.get(grid_pos)
	if building and building.logic is ConveyorBelt:
		return building.logic
	return null

## Return an array of grid positions of buildings linked to this one.
func get_linked_buildings(building) -> Array:
	if not building or not is_instance_valid(building):
		return []
	if building.logic:
		return building.logic.get_linked_positions()
	return []

## Return all building nodes that form a logical group with this one.
func get_building_group(building) -> Array:
	if not building or not is_instance_valid(building):
		return []
	var group: Array = [building]
	for linked_pos in get_linked_buildings(building):
		var linked = buildings.get(linked_pos)
		if linked and is_instance_valid(linked):
			group.append(linked)
	return group

# ── Cleanup ──────────────────────────────────────────────────────────────────

func clear() -> void:
	var seen: Dictionary = {}
	for building in buildings.values():
		if not is_instance_valid(building):
			continue
		var nid: int = building.get_instance_id()
		if seen.has(nid):
			continue
		seen[nid] = true
		if building.logic:
			building.logic.cleanup_visuals()
	for building in buildings.values():
		if is_instance_valid(building):
			building.queue_free()
	buildings.clear()
	unique_buildings.clear()
