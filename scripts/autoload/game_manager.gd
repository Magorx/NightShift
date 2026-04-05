extends Node

signal building_placed(building_id: StringName, grid_pos: Vector2i)
signal item_delivered(item_id: StringName)

const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

## Z-index layers for isometric depth ordering (legacy 2D, used by MultiMesh2D renderers).
## Will be removed once visual managers are converted to 3D.
const Z_CONVEYOR := 0
const Z_ITEM := 1
const Z_BUILDING := 2

# Building registry: id -> BuildingDef
var building_defs: Dictionary = {}

# Recipe registry: converter_type -> Array[RecipeDef]
var recipes_by_type: Dictionary = {}

# Placed buildings: Vector2i -> BuildingBase (grid_pos -> node, multi-cell buildings have multiple entries)
var buildings: Dictionary = {}
# Unique building list (one entry per building, no multi-cell duplicates). Used for save serialization.
var unique_buildings: Array = []

# Deposits: grid_pos -> item_id (what resource this deposit produces)
var deposits: Dictionary = {}

# Deposit stocks: grid_pos -> int (-1 = infinite, >0 = remaining units)
var deposit_stocks: Dictionary = {}

# Walls: grid_pos -> tile_id (impassable terrain, blocks building placement)
var walls: Dictionary = {}

# Cluster drain manager for finite-stock deposits (lazy-initialized)
var cluster_drain_manager

# Terrain visual data (for MultiMesh rendering and save/load)
var terrain_tile_types: PackedByteArray  # flat row-major, one byte per cell
var terrain_variants: PackedByteArray    # low nibble = fg variant, high nibble = misc variant
var terrain_visual_manager  # TerrainVisualManager (set by game_world)

# World generation seed (saved/loaded for reproducibility)
var world_seed: int = 0

# Map size in tiles per side (default 64, stress test uses 640)
var map_size: int = 128

# When true, game_world runs the stress test generator after world gen
var stress_test_pending: bool = false

# Cached item definitions: item_id -> ItemDef
var _item_def_cache: Dictionary = {}

# MultiMesh-based item visual manager (replaces per-item Node2D)
var item_visual_manager  # ItemVisualManager (preloaded in game_world)

# Currency earned from sinks
var total_currency: int = 0

# Creative mode: all buildings are free to place
var creative_mode: bool = false

# Items delivered to sinks: item_id (StringName) -> count (int)
var items_delivered: Dictionary = {}

# Multi-phase building configs: building_id -> config dict
# Config: {phases: [{building_id, max_distance (0=none), count_match (bool)}], link_fn: StringName}
# The key building_id is what the player selects; each phase has its own building_id to place.
# After all phases, link_fn(phase_placements: Array) is called on GameManager.
var placement_phases: Dictionary = {}

# Building hotkeys: key_scancode (int) -> building_id (StringName)
const DEFAULT_HOTKEYS: Dictionary = {
	KEY_1: &"conveyor",
	KEY_2: &"junction",
	KEY_3: &"splitter",
	KEY_4: &"source",
	KEY_5: &"sink",
	KEY_6: &"smelter",
	KEY_7: &"drill",
}
var building_hotkeys: Dictionary = DEFAULT_HOTKEYS.duplicate()

# Last building selected for building mode (defaults to conveyor)
var last_selected_building: StringName = &"conveyor"

# Reference to scene layer nodes (set by game_world on ready)
var building_layer: Node
var item_layer: Node
var building_tick_system: Node  # BuildingTickSystem
var building_collision  # BuildingCollision (StaticBody2D for player collision)
var player  # Player (CharacterBody2D)

func _ready() -> void:
	_load_building_defs()
	_load_recipes()
	_register_placement_phases()

func _register_placement_phases() -> void:
	placement_phases[&"tunnel_input"] = {
		phases = [
			{building_id = &"tunnel_input"},
			{building_id = &"tunnel_output", max_distance = 5, count_match = true},
		],
		link_fn = &"_link_underground_transport",
	}

## Link underground transport (tunnel/pipeline) inputs and outputs after multi-phase placement.
## phase_placements[0] = inputs [{pos, rotation}], phase_placements[1] = outputs [{pos, rotation}]
func _link_underground_transport(phase_placements: Array) -> void:
	var inputs: Array = phase_placements[0]
	var outputs: Array = phase_placements[1]
	var count := mini(inputs.size(), outputs.size())
	for i in range(count):
		var in_building = buildings.get(inputs[i].pos)
		var out_building = buildings.get(outputs[i].pos)
		if not in_building or not out_building:
			continue
		if not in_building.logic is UndergroundTransportLogic or not out_building.logic is UndergroundTransportLogic:
			continue
		var in_pos: Vector2i = inputs[i].pos
		var out_pos: Vector2i = outputs[i].pos
		var dist := absi(out_pos.x - in_pos.x) + absi(out_pos.y - in_pos.y)
		in_building.logic.setup_pair(out_building.logic, dist)
		out_building.logic.setup_pair(in_building.logic, dist)


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

# ── Item visuals (3D models) ─────────────────────────────────────────────────

## Acquire an item visual as a 3D model node.
## Accepts either an item_id (StringName/String) or legacy atlas_index (int, ignored).
func acquire_visual(item_id_or_index) -> Node3D:
	var item_id: StringName = &""
	if item_id_or_index is StringName or item_id_or_index is String:
		item_id = StringName(item_id_or_index)
	elif item_id_or_index is int:
		item_id = &"pyromite"  # fallback for legacy int callers
	return item_visual_manager.create_item_visual(item_id)

## Release an item visual (frees the 3D node).
func release_visual(handle) -> void:
	if handle and is_instance_valid(handle) and handle is Node3D:
		handle.queue_free()

## Get a cached ItemDef resource by id. Loads from disk on first access.
func get_item_def(item_id: StringName):
	if _item_def_cache.has(item_id):
		return _item_def_cache[item_id]
	var path := "res://resources/items/%s.tres" % str(item_id)
	if ResourceLoader.exists(path):
		var def = load(path)
		_item_def_cache[item_id] = def
		return def
	return null

func is_valid_item_id(item_id: StringName) -> bool:
	return item_id != &"" and get_item_def(item_id) != null

## Return all ItemDef resources sorted by category then id.
## Scans res://resources/items/ on first call, caches result.
var _all_item_defs: Array = []
func get_all_item_defs() -> Array:
	if not _all_item_defs.is_empty():
		return _all_item_defs
	var dir := DirAccess.open("res://resources/items/")
	if not dir:
		return []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var item_id := StringName(file_name.get_basename())
			var def = get_item_def(item_id)
			if def and def.id != &"energy":
				_all_item_defs.append(def)
		file_name = dir.get_next()
	dir.list_dir_end()
	_all_item_defs.sort_custom(func(a, b):
		if a.category != b.category:
			return a.category < b.category
		return a.id < b.id
	)
	return _all_item_defs

# ── Item icon atlas ────────────────────────────────────────────────────────────

var _item_atlas_texture: Texture2D
var _item_icon_cache: Dictionary = {}  # icon_atlas_index -> AtlasTexture
const ITEM_ATLAS_CELL := 16
const ITEM_ATLAS_COLS := 8

func get_item_atlas() -> Texture2D:
	if not _item_atlas_texture:
		_item_atlas_texture = load("res://resources/items/sprites/item_atlas.png")
	return _item_atlas_texture

## Get an AtlasTexture for a specific item's icon.
func get_item_icon(item_id: StringName) -> AtlasTexture:
	var def = get_item_def(item_id)
	if not def:
		return null
	var idx: int = def.icon_atlas_index
	if _item_icon_cache.has(idx):
		return _item_icon_cache[idx]
	var atlas := AtlasTexture.new()
	atlas.atlas = get_item_atlas()
	@warning_ignore("integer_division")
	var col: int = idx % ITEM_ATLAS_COLS
	@warning_ignore("integer_division")
	var row: int = idx / ITEM_ATLAS_COLS
	atlas.region = Rect2(col * ITEM_ATLAS_CELL, row * ITEM_ATLAS_CELL, ITEM_ATLAS_CELL, ITEM_ATLAS_CELL)
	atlas.filter_clip = true
	_item_icon_cache[idx] = atlas
	return atlas

func record_delivery(item_id: StringName, value: int = 0) -> void:
	if not items_delivered.has(item_id):
		items_delivered[item_id] = 0
	items_delivered[item_id] += 1
	total_currency += value
	item_delivered.emit(item_id)

func get_building_def(id: StringName):
	return building_defs.get(id)

# ── Building cost ────────────────────────────────────────────────────────────

## Refund ratio when removing buildings (50%).
const BUILD_COST_REFUND_RATIO := 0.5

## Check if the player has enough items to build this building.
## Returns true if build_cost is empty (free placement) or player has all required items.
func can_afford_building(id: StringName) -> bool:
	if creative_mode:
		return true
	var def = get_building_def(id)
	if not def or def.build_cost.is_empty():
		return true
	if not player:
		return true
	for stack in def.build_cost:
		if player.count_item(stack.item.id) < stack.quantity:
			return false
	return true

## Deduct building cost from the player's inventory.
## Should only be called after can_afford_building() returns true.
func deduct_building_cost(id: StringName) -> void:
	if creative_mode:
		return
	var def = get_building_def(id)
	if not def or def.build_cost.is_empty() or not player:
		return
	for stack in def.build_cost:
		player.remove_item(stack.item.id, stack.quantity)

## Refund a percentage of building cost to the player's inventory on removal.
func refund_building_cost(id: StringName) -> void:
	var def = get_building_def(id)
	if not def or def.build_cost.is_empty() or not player:
		return
	for stack in def.build_cost:
		var refund_qty: int = int(stack.quantity * BUILD_COST_REFUND_RATIO)
		if refund_qty > 0:
			player.add_item(stack.item.id, refund_qty)

# ── Building placement ───────────────────────────────────────────────────────

func can_place_building(id: StringName, grid_pos: Vector2i, map_size: int, rotation: int = 0) -> bool:
	var def = get_building_def(id)
	if not def:
		return false
	var rotated_shape: Array = def.get_rotated_shape(rotation)
	for cell in rotated_shape:
		var check_pos: Vector2i = grid_pos + Vector2i(cell)
		if check_pos.x < 0 or check_pos.y < 0 or check_pos.x >= map_size or check_pos.y >= map_size:
			return false
		if walls.has(check_pos):
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
	if not def or not building_layer:
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
	# Position so the anchor cell aligns with grid_pos
	building.position = GridUtils.grid_to_world(grid_pos - def.anchor_cell)
	# Rotation: Y-axis rotation (0=right, 1=down, 2=left, 3=up)
	building.rotation.y = -rotation * PI / 2.0

	building_layer.add_child(building)

	# Deduct build cost from player inventory
	deduct_building_cost(id)

	# Logic node is already in the .tscn scene — no dynamic creation needed

	# Register all occupied cells (rotated)
	for cell in rotated_shape:
		buildings[grid_pos + cell] = building
	unique_buildings.append(building)

	# Find and configure the logic node — no type dispatch needed.
	# Every building logic extends BuildingLogic, so we find by type.
	var logic: BuildingLogic = _find_logic_node(building)
	if logic:
		logic.configure(def, grid_pos, rotation)
		building.logic = logic
		if building_tick_system:
			building_tick_system.register(logic)

	# Model collision is generated automatically by BuildingBase._ready()

	building_placed.emit(id, grid_pos)
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
	if building.logic and building_tick_system:
		building_tick_system.unregister(building.logic)

	# Let the logic node handle its own cleanup (unregistration, partner unlinking, visuals)
	if building.logic:
		building.logic.on_removing()
		building.logic.cleanup_visuals()

	# Remove all occupied cells
	var rotated_shape: Array = []
	if def:
		rotated_shape = def.get_rotated_shape(building.rotation_index)
		for cell in rotated_shape:
			buildings.erase(building.grid_pos + cell)
		# Model collision is removed with building.queue_free()
	else:
		buildings.erase(grid_pos)
	unique_buildings.erase(building)

	building.queue_free()

func get_building_at(grid_pos: Vector2i):
	return buildings.get(grid_pos)

func get_conveyor_at(grid_pos: Vector2i):
	var building = buildings.get(grid_pos)
	if building and building.logic is ConveyorBelt:
		return building.logic
	return null

## Return an array of grid positions of buildings linked to this one.
## Linked buildings are co-highlighted and co-removed in destroy mode.
func get_linked_buildings(building) -> Array:
	if not building or not is_instance_valid(building):
		return []
	if building.logic:
		return building.logic.get_linked_positions()
	return []

## Return all building nodes that form a logical group with this one
## (the building itself + any linked partners like tunnel pairs).
func get_building_group(building) -> Array:
	if not building or not is_instance_valid(building):
		return []
	var group: Array = [building]
	for linked_pos in get_linked_buildings(building):
		var linked = buildings.get(linked_pos)
		if linked and is_instance_valid(linked):
			group.append(linked)
	return group

func get_deposit_at(grid_pos: Vector2i):
	return deposits.get(grid_pos)

## Get the remaining stock for a deposit (-1 = infinite, 0 = depleted).
func get_deposit_stock(pos: Vector2i) -> int:
	return deposit_stocks.get(pos, -1)

## Drain one unit of deposit stock. Returns true if item was available.
## When stock reaches 0, converts tile to ash.
func drain_deposit_stock(pos: Vector2i) -> bool:
	if not deposits.has(pos):
		return false  # not a deposit (ash, ground, etc.)
	var stock: int = deposit_stocks.get(pos, -1)
	if stock == -1:
		return true  # infinite
	if stock <= 0:
		return false  # already depleted
	stock -= 1
	if stock <= 0:
		convert_tile_to_ash(pos)
		return true
	deposit_stocks[pos] = stock
	return true

## Convert a deposit tile to ash (depleted biomass).
func convert_tile_to_ash(pos: Vector2i) -> void:
	deposits.erase(pos)
	deposit_stocks.erase(pos)
	# Update terrain tile type array
	var idx := pos.y * map_size + pos.x
	if idx >= 0 and idx < terrain_tile_types.size():
		terrain_tile_types[idx] = TileDatabase.TILE_ASH
	# Update terrain visual
	if terrain_visual_manager:
		terrain_visual_manager.update_cell(map_size, pos.x, pos.y, TileDatabase.TILE_ASH, 0, 0)
	# Invalidate BFS cache
	if cluster_drain_manager:
		cluster_drain_manager.invalidate_cache()

func clear_all() -> void:
	# Clean up item visuals via logic nodes
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
	# Reset the MultiMesh visual pools
	if item_visual_manager:
		item_visual_manager.clear_all()
	if terrain_visual_manager:
		terrain_visual_manager.clear()
	terrain_tile_types = PackedByteArray()
	terrain_variants = PackedByteArray()
	deposit_stocks.clear()
	total_currency = 0
	items_delivered.clear()
	if building_tick_system:
		building_tick_system.clear_all()
	if building_collision:
		building_collision.clear_all()

## Hide guide ColorRect nodes (Shape/Input/Output cells) to reduce draw calls.
## These nodes have alpha=0 but are still processed by the renderer.
## No-op for Node3D buildings (they don't have 2D guide nodes).
func _hide_guide_nodes(building: Node) -> void:
	var rotatable = building.find_child("Rotatable", false, false)
	if not rotatable:
		return
	for group_name in ["Shape", "Inputs", "Outputs"]:
		var group = rotatable.find_child(group_name, false, false)
		if group:
			group.visible = false
