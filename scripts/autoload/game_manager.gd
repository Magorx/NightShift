extends Node

const TILE_SIZE := 32

# Building registry: id -> BuildingDef
var building_defs: Dictionary = {}

# Placed buildings: Vector2i -> BuildingBase (grid_pos -> node)
var buildings: Dictionary = {}

# Deposits: grid_pos -> item_id (what resource this deposit produces)
var deposits: Dictionary = {}

# Reference to scene layer nodes (set by game_world on ready)
var building_layer: Node2D
var item_layer: Node2D
var conveyor_system: Node

func _ready() -> void:
	_load_building_defs()

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
							_extract_shape(def)
							_extract_io(def)
							building_defs[def.id] = def
					file_name = sub_dir.get_next()
		sub_name = root_dir.get_next()

## Extract shape cells from the scene's ColorRect children.
## Each 32x32 ColorRect position determines a cell offset.
## Falls back to a single cell at (0,0) if no ColorRects are found.
func _extract_shape(def) -> void:
	if not def.scene:
		def.shape = [Vector2i(0, 0)]
		def.shape_size = Vector2i(1, 1)
		return

	var instance = def.scene.instantiate()
	var cells: Array = []
	var shape_node = instance.find_child("Shape", false, false)
	if shape_node:
		for child in shape_node.get_children():
			if child is ColorRect:
				var gx := int(round(child.offset_left)) / TILE_SIZE
				var gy := int(round(child.offset_top)) / TILE_SIZE
				cells.append(Vector2i(gx, gy))
	instance.free()

	if cells.is_empty():
		cells.append(Vector2i(0, 0))

	def.shape = cells
	# Compute bounding box
	var max_x := 0
	var max_y := 0
	for cell in cells:
		if cell.x + 1 > max_x:
			max_x = cell.x + 1
		if cell.y + 1 > max_y:
			max_y = cell.y + 1
	def.shape_size = Vector2i(max_x, max_y)

## Extract input/output cells from the scene's Inputs/Outputs sub-nodes.
## Each InputCell/OutputCell position determines a cell offset; its exported
## booleans define the directional mask in default orientation (facing right).
func _extract_io(def) -> void:
	if not def.scene:
		def.inputs = []
		def.outputs = []
		return

	var instance = def.scene.instantiate()

	def.inputs = _read_io_group(instance, "Inputs")
	def.outputs = _read_io_group(instance, "Outputs")

	instance.free()

func _read_io_group(instance: Node, group_name: String) -> Array:
	var result: Array = []
	var group_node = instance.find_child(group_name, false, false)
	if not group_node:
		return result
	for child in group_node.get_children():
		if child is ColorRect:
			var gx := int(round(child.offset_left)) / TILE_SIZE
			var gy := int(round(child.offset_top)) / TILE_SIZE
			var mask: Array
			if child.has_method("get_mask"):
				mask = child.get_mask()
			else:
				mask = [true, true, true, true]
			result.append({cell = Vector2i(gx, gy), mask = mask})
	return result

# ── Direction rotation utilities ──────────────────────────────────────────────

## Rotate a cell position by the given rotation index (0-3, CW).
func rotate_cell(cell: Vector2i, rotation: int) -> Vector2i:
	match rotation:
		1: return Vector2i(-cell.y, cell.x)
		2: return Vector2i(-cell.x, -cell.y)
		3: return Vector2i(cell.y, -cell.x)
	return cell

## Rotate a direction mask [right, down, left, up] by rotation steps CW.
func rotate_mask(mask: Array, rotation: int) -> Array:
	if rotation == 0:
		return mask.duplicate()
	var result := [false, false, false, false]
	for i in 4:
		result[(i + rotation) % 4] = mask[i]
	return result

## Get a building def's outputs rotated for the given placement rotation.
func get_rotated_outputs(def, rotation: int) -> Array:
	var result: Array = []
	for out in def.outputs:
		result.append({
			cell = rotate_cell(out.cell, rotation),
			mask = rotate_mask(out.mask, rotation)
		})
	return result

## Get a building def's inputs rotated for the given placement rotation.
func get_rotated_inputs(def, rotation: int) -> Array:
	var result: Array = []
	for inp in def.inputs:
		result.append({
			cell = rotate_cell(inp.cell, rotation),
			mask = rotate_mask(inp.mask, rotation)
		})
	return result

func get_building_def(id: StringName):
	return building_defs.get(id)

func can_place_building(id: StringName, grid_pos: Vector2i, map_size: int) -> bool:
	var def = get_building_def(id)
	if not def:
		return false
	for cell in def.shape:
		var check_pos: Vector2i = grid_pos + Vector2i(cell)
		if check_pos.x < 0 or check_pos.y < 0 or check_pos.x >= map_size or check_pos.y >= map_size:
			return false
		if buildings.has(check_pos):
			return false
	# Extractors (drills) can only be placed on deposit tiles
	if def.category == "extractor":
		if not deposits.has(grid_pos):
			return false
	return true

func place_building(id: StringName, grid_pos: Vector2i, rotation: int = 0) -> Node2D:
	var def = get_building_def(id)
	if not def or not building_layer:
		return null
	# Extractors require a deposit
	if def.category == "extractor" and not deposits.has(grid_pos):
		return null

	var building: Node2D
	if def.scene:
		building = def.scene.instantiate()
	else:
		var base_script = load("res://buildings/shared/building_base.gd")
		building = base_script.new()
	building.init(id, grid_pos, rotation)
	building.position = Vector2(grid_pos) * TILE_SIZE

	# Configure arrow meta if present
	var arrow = building.find_child("Arrow", true, false)
	if arrow:
		arrow.set_meta("rotation_index", rotation)
		arrow.set_meta("shape_size", def.shape_size)

	building_layer.add_child(building)

	# Register all occupied cells
	for cell in def.shape:
		buildings[grid_pos + cell] = building

	# Register conveyor with the conveyor system
	if def.category == "conveyor" and conveyor_system:
		var conv = building.find_child("ConveyorLogic", true, false)
		if conv:
			conv.grid_pos = grid_pos
			conv.direction = rotation
			building.set_meta("conveyor", conv)
			conveyor_system.register_conveyor(conv)
			_update_conveyor_sprites(grid_pos)

	# Configure source
	if def.category == "source":
		var src = building.find_child("SourceLogic", true, false)
		if src:
			src.grid_pos = grid_pos
			src.direction = rotation
			src.item_id = &"iron_ore"
			building.set_meta("source", src)

	# Configure extractor (drill)
	if def.category == "extractor":
		var ext = building.find_child("ExtractorLogic", true, false)
		if ext:
			ext.grid_pos = grid_pos
			ext.direction = rotation
			ext.item_id = deposits.get(grid_pos, &"iron_ore")
			building.set_meta("extractor", ext)

	# Configure sink
	if def.category == "sink":
		var snk = building.find_child("SinkLogic", true, false)
		if snk:
			snk.grid_pos = grid_pos
			building.set_meta("sink", snk)

	return building

func remove_building(grid_pos: Vector2i) -> void:
	if not buildings.has(grid_pos):
		return
	var building = buildings[grid_pos]
	var def = get_building_def(building.building_id)

	# Unregister conveyor and update neighbor sprites
	var removed_pos: Vector2i = building.grid_pos
	if def and def.category == "conveyor" and conveyor_system:
		if building.has_meta("conveyor"):
			var conv = building.get_meta("conveyor")
			conv.cleanup_visuals()
			conveyor_system.unregister_conveyor(removed_pos)

	# Remove all occupied cells
	if def:
		for cell in def.shape:
			buildings.erase(building.grid_pos + cell)
	else:
		buildings.erase(grid_pos)

	building.queue_free()

	# Update neighboring conveyor sprites after removal
	if def and def.category == "conveyor":
		_update_neighbor_conveyor_sprites(removed_pos)

func get_building_at(grid_pos: Vector2i):
	return buildings.get(grid_pos)

func get_conveyor_at(grid_pos: Vector2i):
	var building = buildings.get(grid_pos)
	if building and building.has_meta("conveyor"):
		return building.get_meta("conveyor")
	return null

func get_deposit_at(grid_pos: Vector2i):
	return deposits.get(grid_pos)

const _NEIGHBOR_DIRS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

## Update the conveyor sprite at grid_pos and all its neighbors.
func _update_conveyor_sprites(grid_pos: Vector2i) -> void:
	_update_single_conveyor_sprite(grid_pos)
	_update_neighbor_conveyor_sprites(grid_pos)

## Update only the neighboring conveyor sprites around grid_pos.
func _update_neighbor_conveyor_sprites(grid_pos: Vector2i) -> void:
	for dir in _NEIGHBOR_DIRS:
		_update_single_conveyor_sprite(grid_pos + dir)

## Update a single conveyor's sprite variant if it exists.
func _update_single_conveyor_sprite(grid_pos: Vector2i) -> void:
	var building = buildings.get(grid_pos)
	if not building or not is_instance_valid(building):
		return
	if not building.has_meta("conveyor"):
		return
	var sprite = building.find_child("ConveyorSprite", true, false)
	if sprite and conveyor_system:
		var conv = building.get_meta("conveyor")
		sprite.update_variant(conv, conveyor_system)

func clear_all() -> void:
	for building in buildings.values():
		if is_instance_valid(building):
			building.queue_free()
	buildings.clear()
	if conveyor_system:
		conveyor_system.conveyors.clear()
