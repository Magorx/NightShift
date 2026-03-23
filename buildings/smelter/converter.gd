class_name ConverterLogic
extends Node

const Inventory = preload("res://scripts/inventory.gd")
const RoundRobin = preload("res://scripts/round_robin.gd")
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

## Grid position of the building origin.
var grid_pos: Vector2i
## Building rotation index (0=right, 1=down, 2=left, 3=up).
var rotation: int = 0
## Converter type string for recipe matching (e.g. "smelter").
var converter_type: String = "smelter"

## Input IO points: Array of {cell: Vector2i, mask: Array} — world-space offsets.
var input_points: Array = []
## Output IO points: same format.
var output_points: Array = []

## All recipes this converter can use (filtered by converter_type).
var recipes: Array = []:
	set(value):
		recipes = value
		_build_capacities()

## Inventories for input ingredients and craft outputs.
var input_inv: Inventory = Inventory.new()
var output_inv: Inventory = Inventory.new()

## Current crafting state.
var _active_recipe = null # RecipeDef or null
var _craft_timer: float = 0.0
var _input_rr: RoundRobin = RoundRobin.new()

func _build_capacities() -> void:
	input_inv = Inventory.new()
	output_inv = Inventory.new()
	for recipe in recipes:
		for inp in recipe.inputs:
			var cur = input_inv.get_capacity(inp.item.id)
			if inp.quantity * 3 > cur:
				input_inv.set_capacity(inp.item.id, inp.quantity * 3)
		for out in recipe.outputs:
			var cur = output_inv.get_capacity(out.item.id)
			if out.quantity * 5 > cur:
				output_inv.set_capacity(out.item.id, out.quantity * 5)

func _physics_process(delta: float) -> void:
	_try_pull_inputs()
	_try_push_outputs()

	if _active_recipe:
		_craft_timer = minf(_craft_timer + delta, _active_recipe.craft_time)
		if _craft_timer >= _active_recipe.craft_time:
			_try_finish_craft()
	else:
		_try_start_craft()

func _try_pull_inputs() -> void:
	var count: int = input_points.size()
	var start: int = _input_rr.next(count)
	for i in range(count):
		var idx: int = (start + i) % count
		var inp = input_points[idx]
		var world_cell: Vector2i = grid_pos + inp.cell
		for dir_idx in range(4):
			if not inp.mask[dir_idx]:
				continue
			var neighbor_pos: Vector2i = world_cell + DIRECTION_VECTORS[dir_idx]
			var conv = GameManager.get_conveyor_at(neighbor_pos)
			if not conv:
				continue
			if conv.get_next_pos() != world_cell:
				continue
			if conv.items.size() == 0:
				continue
			var front = conv.get_front_item()
			if front.progress < 1.0:
				continue
			var item_id: StringName = front.id
			if input_inv.has_space(item_id):
				conv.pop_front_item()
				input_inv.add(item_id)

func _try_start_craft() -> void:
	for recipe in recipes:
		if _can_craft(recipe):
			_start_craft(recipe)
			return

func _can_craft(recipe) -> bool:
	for inp in recipe.inputs:
		if not input_inv.has(inp.item.id, inp.quantity):
			return false
	for out in recipe.outputs:
		if not output_inv.has_space(out.item.id, out.quantity):
			return false
	return true

func _start_craft(recipe) -> void:
	for inp in recipe.inputs:
		input_inv.remove(inp.item.id, inp.quantity)
	_active_recipe = recipe
	_craft_timer = 0.0

func _try_finish_craft() -> void:
	for out in _active_recipe.outputs:
		if not output_inv.has_space(out.item.id, out.quantity):
			return # Hold craft until output has room
	for out in _active_recipe.outputs:
		output_inv.add(out.item.id, out.quantity)
	_active_recipe = null
	_craft_timer = 0.0

func _try_push_outputs() -> void:
	if output_inv.is_empty():
		return
	for outp in output_points:
		var world_cell: Vector2i = grid_pos + outp.cell
		var conv = GameManager.get_conveyor_at(world_cell)
		if conv and conv.can_accept():
			var entry_from: Vector2i = -conv.get_direction_vector()
			for item_id in output_inv.get_item_ids():
				if conv.place_item(item_id, entry_from):
					output_inv.remove(item_id)
					if output_inv.is_empty():
						return
					break

## Returns craft progress as 0.0–1.0 for progress bar display.
func get_progress() -> float:
	if _active_recipe:
		return clampf(_craft_timer / _active_recipe.craft_time, 0.0, 1.0)
	if not output_inv.is_empty():
		return 1.0 # Waiting to push output
	return 0.0
