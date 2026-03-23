class_name ConverterLogic
extends Node

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
var recipes: Array = []

## Current crafting state.
var _input_buffer: Dictionary = {} # item_id -> count
var _active_recipe = null # RecipeDef or null
var _craft_timer: float = 0.0
var _output_queue: Array = [] # Array of StringName (item_ids to push out)

func _physics_process(delta: float) -> void:
	# Phase 1: Try to push pending outputs first
	if _output_queue.size() > 0:
		_try_push_outputs()
		return # Don't pull or craft while outputs are pending

	# Phase 2: If crafting, advance timer
	if _active_recipe:
		_craft_timer += delta
		if _craft_timer >= _active_recipe.craft_time:
			_craft_complete()
		return

	# Phase 3: Try to pull items and start a craft
	_try_pull_inputs()
	_try_start_craft()

func _try_pull_inputs() -> void:
	for inp in input_points:
		var world_cell: Vector2i = grid_pos + inp.cell
		# Check all 4 directions for conveyors pointing at this input cell
		for dir_idx in range(4):
			if not inp.mask[dir_idx]:
				continue
			var neighbor_pos: Vector2i = world_cell + DIRECTION_VECTORS[dir_idx]
			var conv = GameManager.get_conveyor_at(neighbor_pos)
			if not conv:
				continue
			# Conveyor must point toward this cell
			if conv.get_next_pos() != world_cell:
				continue
			if conv.items.size() == 0:
				continue
			var front = conv.get_front_item()
			if front.progress < 1.0:
				continue
			# Check if this item is useful for any recipe
			var item_id: StringName = front.id
			if _is_item_useful(item_id):
				conv.pop_front_item()
				_input_buffer[item_id] = _input_buffer.get(item_id, 0) + 1

func _is_item_useful(item_id: StringName) -> bool:
	for recipe in recipes:
		for inp in recipe.inputs:
			if inp.item.id == item_id:
				var needed: int = inp.quantity
				var have: int = _input_buffer.get(item_id, 0)
				if have < needed:
					return true
	return false

func _try_start_craft() -> void:
	for recipe in recipes:
		if _can_craft(recipe):
			_start_craft(recipe)
			return

func _can_craft(recipe) -> bool:
	for inp in recipe.inputs:
		var have: int = _input_buffer.get(inp.item.id, 0)
		if have < inp.quantity:
			return false
	return true

func _start_craft(recipe) -> void:
	# Consume inputs
	for inp in recipe.inputs:
		_input_buffer[inp.item.id] -= inp.quantity
		if _input_buffer[inp.item.id] <= 0:
			_input_buffer.erase(inp.item.id)
	_active_recipe = recipe
	_craft_timer = 0.0

func _craft_complete() -> void:
	# Queue outputs
	for out in _active_recipe.outputs:
		for i in range(out.quantity):
			_output_queue.append(out.item.id)
	_active_recipe = null
	_craft_timer = 0.0
	# Immediately try to push
	_try_push_outputs()

func _try_push_outputs() -> void:
	if _output_queue.size() == 0:
		return
	for outp in output_points:
		var world_cell: Vector2i = grid_pos + outp.cell
		# Output cell is a gap in the shape — push directly onto conveyor there
		var conv = GameManager.get_conveyor_at(world_cell)
		if conv and conv.can_accept():
			var item_id: StringName = _output_queue[0]
			# Entry direction: from the building interior toward the output cell
			var entry_from: Vector2i = -conv.get_direction_vector()
			if conv.place_item(item_id, entry_from):
				_output_queue.remove_at(0)
				if _output_queue.size() == 0:
					return

## Returns craft progress as 0.0–1.0 for progress bar display.
func get_progress() -> float:
	if _active_recipe:
		return clampf(_craft_timer / _active_recipe.craft_time, 0.0, 1.0)
	if _output_queue.size() > 0:
		return 1.0 # Waiting to push output
	return 0.0
