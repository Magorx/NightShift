class_name BuildingDef
extends Resource

const TILE_SIZE := 32

@export var id: StringName
@export var display_name: String
@export var color: Color = Color.GRAY
@export var category: String # "extractor", "conveyor", "converter", "sink"
@export var description: String = ""
@export var scene: PackedScene
@export var unlock_tech: StringName
## Building IDs that can replace this building when placed on top of it.
@export var replaceable_by: Array[StringName] = []
## Ground-level buildings (conveyors, junctions, etc.) don't block the player.
@export var is_ground_level: bool = false
## Items required to place this building. Empty = free placement.
@export var build_cost: Array[ItemStack] = []

## Anchor cell offset, read from BuildAnchor node position at load time.
## The cursor/grid_pos aligns to this cell when placing.
var anchor_cell: Vector2i = Vector2i(0, 0)

## Populated at load time from the scene's ShapeCell children.
## Array of Vector2i cell offsets relative to the anchor.
var shape: Array = []

## IO points extracted from Inputs/Outputs sub-nodes at load time.
## Each entry: {cell: Vector2i, mask: [right, down, left, up]}
## Defined in default orientation (facing right); rotate at placement time.
var inputs: Array = []
var outputs: Array = []

# ── Scene extraction (called once at load time) ────────────────────────────

## Extract anchor, shape, and IO data from the scene.
func extract_from_scene() -> void:
	_extract_shape()
	_extract_io()

## Find the Rotatable container inside a building (or fall back to the node itself).
static func get_rotatable(building: Node) -> Node:
	var rotatable = building.find_child("Rotatable", false, false)
	return rotatable if rotatable else building

func _extract_shape() -> void:
	if not scene:
		shape = [Vector2i(0, 0)]
		anchor_cell = Vector2i(0, 0)
		return

	var instance = scene.instantiate()
	var container = get_rotatable(instance)

	# Read anchor
	var a_cell := Vector2i(0, 0)
	var anchor_node = container.find_child("BuildAnchor", false, false)
	if anchor_node and anchor_node is Node2D:
		@warning_ignore("integer_division")
		a_cell.x = int(round(anchor_node.position.x)) / TILE_SIZE
		@warning_ignore("integer_division")
		a_cell.y = int(round(anchor_node.position.y)) / TILE_SIZE
	anchor_cell = a_cell

	# Read shape cells, make anchor-relative
	var cells: Array = []
	var shape_node = container.find_child("Shape", false, false)
	if shape_node:
		for child in shape_node.get_children():
			if child is ColorRect:
				@warning_ignore("integer_division")
				var gx := int(round(child.offset_left)) / TILE_SIZE
				@warning_ignore("integer_division")
				var gy := int(round(child.offset_top)) / TILE_SIZE
				cells.append(Vector2i(gx, gy) - anchor_cell)
	instance.free()

	if cells.is_empty():
		cells.append(Vector2i(0, 0))
	shape = cells

func _extract_io() -> void:
	if not scene:
		inputs = []
		outputs = []
		return

	var instance = scene.instantiate()
	var container = get_rotatable(instance)
	inputs = _read_io_group(container, "Inputs")
	outputs = _read_io_group(container, "Outputs")
	instance.free()

func _read_io_group(container: Node, group_name: String) -> Array:
	var result: Array = []
	var group_node = container.find_child(group_name, false, false)
	if not group_node:
		return result
	for child in group_node.get_children():
		if child is ColorRect:
			@warning_ignore("integer_division")
			var gx := int(round(child.offset_left)) / TILE_SIZE
			@warning_ignore("integer_division")
			var gy := int(round(child.offset_top)) / TILE_SIZE
			var mask: Array
			if child.has_method("get_mask"):
				mask = child.get_mask()
			else:
				mask = [true, true, true, true]
			result.append({cell = Vector2i(gx, gy) - anchor_cell, mask = mask})
	return result

# ── Rotation utilities ──────────────────────────────────────────────────────

## Rotate a cell position by the given rotation index (0-3, CW).
static func rotate_cell(cell: Vector2i, rotation: int) -> Vector2i:
	match rotation:
		1: return Vector2i(-cell.y, cell.x)
		2: return Vector2i(-cell.x, -cell.y)
		3: return Vector2i(cell.y, -cell.x)
	return cell

## Rotate a direction mask [right, down, left, up] by rotation steps CW.
static func rotate_mask(mask: Array, rotation: int) -> Array:
	if rotation == 0:
		return mask.duplicate()
	var result := [false, false, false, false]
	for i in 4:
		result[(i + rotation) % 4] = mask[i]
	return result

## Get shape cells rotated for the given placement rotation.
func get_rotated_shape(rotation: int) -> Array:
	if rotation == 0:
		return shape.duplicate()
	var result: Array = []
	for cell in shape:
		result.append(rotate_cell(cell, rotation))
	return result

## Compute the bounding box of a rotated shape.
## Returns {min_cell: Vector2i, size: Vector2i}.
func get_rotated_shape_bbox(rotation: int) -> Dictionary:
	var rotated := get_rotated_shape(rotation)
	var min_c := Vector2i(999, 999)
	var max_c := Vector2i(-999, -999)
	for cell in rotated:
		if cell.x < min_c.x: min_c.x = cell.x
		if cell.y < min_c.y: min_c.y = cell.y
		if cell.x + 1 > max_c.x: max_c.x = cell.x + 1
		if cell.y + 1 > max_c.y: max_c.y = cell.y + 1
	return {min_cell = min_c, size = max_c - min_c}

## Get outputs rotated for the given placement rotation.
func get_rotated_outputs(rotation: int) -> Array:
	var result: Array = []
	for out in outputs:
		result.append({
			cell = rotate_cell(out.cell, rotation),
			mask = rotate_mask(out.mask, rotation)
		})
	return result

## Get inputs rotated for the given placement rotation.
func get_rotated_inputs(rotation: int) -> Array:
	var result: Array = []
	for inp in inputs:
		result.append({
			cell = rotate_cell(inp.cell, rotation),
			mask = rotate_mask(inp.mask, rotation)
		})
	return result

# ── Visual rotation ───────────────────────────────────────────────────────────

## Apply all visual rotation to a building instance in one call.
## Repositions Shape/Inputs/Outputs ColorRects, rotates sprites and Sprite2Ds,
## repositions EnergyNodes, and configures the Arrow overlay.
## Must be called after add_child (so _ready defaults are overridden).
func apply_rotation(building: Node2D, rotation: int) -> void:
	if rotation == 0:
		return
	var container: Node = get_rotatable(building)
	_rotate_group(container, "Shape", rotation)
	_rotate_group(container, "Inputs", rotation)
	_rotate_group(container, "Outputs", rotation)
	_rotate_visuals(container, rotation)
	var arrow = container.find_child("Arrow", false, false)
	if arrow:
		var bbox: Dictionary = get_rotated_shape_bbox(rotation)
		arrow.set_meta("rotation_index", rotation)
		arrow.set_meta("shape_size", bbox.size)
		arrow.set_meta("bbox_min", bbox.min_cell)

## Reposition ColorRect children of a named group to match the rotated layout.
func _rotate_group(container: Node, group_name: String, rotation: int) -> void:
	var group_node = container.find_child(group_name, false, false)
	if not group_node:
		return
	for child in group_node.get_children():
		if child is ColorRect:
			@warning_ignore("integer_division")
			var gx := int(round(child.offset_left)) / TILE_SIZE
			@warning_ignore("integer_division")
			var gy := int(round(child.offset_top)) / TILE_SIZE
			var rel := Vector2i(gx, gy) - anchor_cell
			var rotated_rel := rotate_cell(rel, rotation)
			var new_cell := rotated_rel + anchor_cell
			child.offset_left = new_cell.x * TILE_SIZE
			child.offset_top = new_cell.y * TILE_SIZE
			child.offset_right = child.offset_left + TILE_SIZE
			child.offset_bottom = child.offset_top + TILE_SIZE

## Rotate sprite children and EnergyNode positions inside the Rotatable container.
func _rotate_visuals(container: Node, rotation: int) -> void:
	var rot_rad := rotation * PI / 2.0

	# Compute unrotated scene pixel bounding box from shape
	var scene_w: float = TILE_SIZE
	var scene_h: float = TILE_SIZE
	if not shape.is_empty():
		var min_c := Vector2i(999, 999)
		var max_c := Vector2i(-999, -999)
		for cell in shape:
			var sc: Vector2i = cell + anchor_cell
			min_c.x = mini(min_c.x, sc.x)
			min_c.y = mini(min_c.y, sc.y)
			max_c.x = maxi(max_c.x, sc.x + 1)
			max_c.y = maxi(max_c.y, sc.y + 1)
		scene_w = float((max_c.x - min_c.x) * TILE_SIZE)
		scene_h = float((max_c.y - min_c.y) * TILE_SIZE)

	# Position offset so the rotated drawing aligns with the rotated cell area
	var offset: Vector2
	match rotation:
		1: offset = Vector2(scene_h, 0)
		2: offset = Vector2(scene_w, scene_h)
		3: offset = Vector2(0, scene_w)
		_: offset = Vector2.ZERO

	# Pivot for rotating individual point positions (anchor cell center)
	var pivot := Vector2(anchor_cell) * TILE_SIZE + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)

	for child in container.get_children():
		if child is AnimatedSprite2D:
			child.rotation = rot_rad
			var rel: Vector2 = child.position - pivot
			match rotation:
				1: child.position = Vector2(-rel.y, rel.x) + pivot
				2: child.position = Vector2(-rel.x, -rel.y) + pivot
				3: child.position = Vector2(rel.y, -rel.x) + pivot
		elif child is Sprite2D:
			child.rotation = rot_rad
			var rel: Vector2 = child.position - pivot
			match rotation:
				1: child.position = Vector2(-rel.y, rel.x) + pivot
				2: child.position = Vector2(-rel.x, -rel.y) + pivot
				3: child.position = Vector2(rel.y, -rel.x) + pivot
		elif child is Node2D:
			# EnergyNode — rotate its position around anchor center
			if child.has_method("can_connect_to"):
				var rel: Vector2 = child.position - pivot
				match rotation:
					1: child.position = Vector2(-rel.y, rel.x) + pivot
					2: child.position = Vector2(-rel.x, -rel.y) + pivot
					3: child.position = Vector2(rel.y, -rel.x) + pivot
			# Code-animated parts (name starts with "CodeAnim") — pivot rotation
			elif String(child.name).begins_with("CodeAnim"):
				child.rotation = rot_rad
				var rel: Vector2 = child.position - pivot
				match rotation:
					1: child.position = Vector2(-rel.y, rel.x) + pivot
					2: child.position = Vector2(-rel.x, -rel.y) + pivot
					3: child.position = Vector2(rel.y, -rel.x) + pivot
			# Full-canvas drawn sprites (ProgressBar, etc.) — offset + rotation
			elif _is_drawn_sprite(child):
				child.rotation = rot_rad
				child.position = offset

## Check if a node is a script-drawn sprite (not a system node).
static func _is_drawn_sprite(node: Node) -> bool:
	if not node is Node2D or node is AnimatedSprite2D or node is Sprite2D:
		return false
	var n: String = node.name
	if n in ["Shape", "Inputs", "Outputs", "BuildAnchor", "Arrow"]:
		return false
	return node.get_script() != null
