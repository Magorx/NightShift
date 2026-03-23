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
			var item_id = GameManager.peek_output_item(world_cell, dir_idx)
			if item_id == &"":
				continue
			if input_inv.has_space(item_id):
				GameManager.pull_item(world_cell, dir_idx)
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

# ── Pull-compatible output interface ─────────────────────────────────────────

func has_output_at(target_pos: Vector2i) -> bool:
	for outp in output_points:
		if grid_pos + outp.cell == target_pos:
			return true
	return false

func has_input_from(cell: Vector2i, from_dir_idx: int) -> bool:
	for inp in input_points:
		if grid_pos + inp.cell == cell and inp.mask[from_dir_idx]:
			return true
	return false

func can_provide_to(target_pos: Vector2i) -> bool:
	if output_inv.is_empty():
		return false
	for outp in output_points:
		if grid_pos + outp.cell == target_pos:
			return true
	return false

func peek_output_for(target_pos: Vector2i) -> StringName:
	if output_inv.is_empty():
		return &""
	for outp in output_points:
		if grid_pos + outp.cell == target_pos:
			for iid in output_inv.get_item_ids():
				if output_inv.has(iid):
					return iid
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	for outp in output_points:
		if grid_pos + outp.cell == target_pos:
			for iid in output_inv.get_item_ids():
				if output_inv.has(iid):
					output_inv.remove(iid)
					return iid
	return &""

## Returns craft progress as 0.0–1.0 for progress bar display.
func get_progress() -> float:
	if _active_recipe:
		return clampf(_craft_timer / _active_recipe.craft_time, 0.0, 1.0)
	if not output_inv.is_empty():
		return 1.0 # Waiting to push output
	return 0.0
