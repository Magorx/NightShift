class_name ResearchLabLogic
extends BuildingLogic

## Research Lab building logic. Pulls items needed by current research from inputs
## and delivers them to ResearchManager to advance the current research target.
## Only accepts items required by the active research, and refuses items whose
## requirement is already satisfied (including items buffered across ALL labs).

## All active research labs — used to sum buffered items globally.
static var _all_labs: Array[ResearchLabLogic] = []

## Building rotation index (0=right, 1=down, 2=left, 3=up).
var rotation: int = 0

## Input IO points: Array of {cell: Vector2i, mask: Array} — world-space offsets.
var input_points: Array = []

## Inventory for holding research items before delivery.
var input_inv: Inventory = Inventory.new()

## Delivery timer: time between consuming an item from inventory and delivering it.
var _deliver_timer: float = 0.0
var _delivering_item: StringName = &""
const DELIVER_TIME := 2.0

## Max items to buffer per type in inventory.
const BUFFER_CAPACITY := 5

var _input_rr: RoundRobin = RoundRobin.new()
var _code_anims: Array = []

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)
	rotation = p_rotation
	input_points = def.get_rotated_inputs(p_rotation)
	# Energy setup
	energy = BuildingEnergy.new(50.0, 5.0, 0.0)
	# Register in global lab list
	if self not in _all_labs:
		_all_labs.append(self)
	# Find CodeAnim* nodes for procedural animation
	var rotatable = get_parent().get_node_or_null("Rotatable")
	if rotatable:
		for child in rotatable.get_children():
			if child is Node2D and String(child.name).begins_with("CodeAnim"):
				_code_anims.append(child)

func on_removing() -> void:
	_all_labs.erase(self)

func _physics_process(delta: float) -> void:
	# Require power to operate
	if energy and energy.base_energy_demand > 0.0 and not energy.is_powered:
		_update_building_sprites(false, delta)
		return

	_try_pull_inputs()

	if _delivering_item != &"":
		_deliver_timer += delta
		if _deliver_timer >= DELIVER_TIME:
			# Deliver the pack to ResearchManager
			ResearchManager.deliver_science_pack(_delivering_item)
			_delivering_item = &""
			_deliver_timer = 0.0
	else:
		_try_start_delivery()

	var is_working := _delivering_item != &""
	_update_building_sprites(is_working, delta)
	for anim in _code_anims:
		if anim and anim.has_method("set_active"):
			anim.set_active(is_working)

func _is_needed(item_id: StringName) -> bool:
	## Check if the current research still needs this item, accounting for
	## items buffered across ALL research labs (not yet delivered).
	if not ResearchManager.current_research:
		return false
	for stack in ResearchManager.current_research.cost:
		if stack.item.id == item_id:
			var delivered: int = ResearchManager.research_progress.get(item_id, 0)
			var buffered: int = 0
			for lab in _all_labs:
				buffered += lab.input_inv.get_count(item_id)
				if lab._delivering_item == item_id:
					buffered += 1
			return (delivered + buffered) < stack.quantity
	return false

func _ensure_capacity(item_id: StringName) -> void:
	## Ensure inventory has capacity registered for this item type.
	if input_inv.get_capacity(item_id) == 0:
		input_inv.set_capacity(item_id, BUFFER_CAPACITY)

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
			var peek_id = GameManager.peek_output_item(world_cell, dir_idx)
			if peek_id == &"":
				continue
			if not _is_needed(peek_id):
				continue
			_ensure_capacity(peek_id)
			if not input_inv.has_space(peek_id):
				continue
			GameManager.pull_item(world_cell, dir_idx)
			input_inv.add(peek_id)

func _try_start_delivery() -> void:
	# Check if there's active research
	if not ResearchManager.current_research:
		return
	# Find an item in inventory that the research still needs
	for item_id in input_inv.get_item_ids():
		if input_inv.has(item_id) and ResearchManager.needs_pack(item_id):
			input_inv.remove(item_id)
			_delivering_item = item_id
			_deliver_timer = 0.0
			return

# ── Pull interface ──────────────────────────────────────────────────────────

func has_input_from(cell: Vector2i, from_dir_idx: int) -> bool:
	for inp in input_points:
		if grid_pos + inp.cell == cell and inp.mask[from_dir_idx]:
			return true
	return false

func can_accept_from(from_dir_idx: int) -> bool:
	if not ResearchManager.current_research:
		return false
	for stack in ResearchManager.current_research.cost:
		if _is_needed(stack.item.id):
			_ensure_capacity(stack.item.id)
			if input_inv.has_space(stack.item.id):
				return true
	return false

func try_insert_item(item_id: StringName, quantity: int = 1) -> int:
	if not _is_needed(item_id):
		return quantity
	_ensure_capacity(item_id)
	var remaining := quantity
	while remaining > 0 and input_inv.has_space(item_id):
		input_inv.add(item_id)
		remaining -= 1
	return remaining

# ── Info panel / popup ────────────────────────────────────────────────────

func get_popup_progress() -> float:
	if _delivering_item != &"":
		return clampf(_deliver_timer / DELIVER_TIME, 0.0, 1.0)
	return -1.0

func get_inventory_items() -> Array:
	var result: Array = []
	for item_id in input_inv.get_item_ids():
		var c := input_inv.get_count(item_id)
		if c > 0:
			result.append({id = item_id, count = c})
	return result

func remove_inventory_item(item_id: StringName, count: int) -> int:
	var available := input_inv.get_count(item_id)
	var to_remove := mini(count, available)
	if to_remove > 0 and input_inv.remove(item_id, to_remove):
		return to_remove
	return 0

func get_info_stats() -> Array:
	var stats: Array = []
	if ResearchManager.current_research:
		stats.append({type = "stat", text = "Researching: %s" % ResearchManager.current_research.display_name})
		stats.append({type = "progress", value = ResearchManager.get_progress_fraction()})
	else:
		stats.append({type = "stat", text = "No research selected"})
	var items: Array = get_inventory_items()
	if not items.is_empty():
		stats.append({type = "inventory", label = "Input", items = items})
	return stats

# ── Serialization ──────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {}
	state["deliver_timer"] = _deliver_timer
	state["delivering_item"] = str(_delivering_item)
	state["input_inv"] = input_inv.serialize()
	if energy:
		state["energy"] = energy.serialize()
	return state

func deserialize_state(state: Dictionary) -> void:
	if state.has("deliver_timer"):
		_deliver_timer = state["deliver_timer"]
	if state.has("delivering_item") and state["delivering_item"] != "":
		var iid := StringName(state["delivering_item"])
		if GameManager.is_valid_item_id(iid):
			_delivering_item = iid
		else:
			GameLogger.warn("ResearchLab at %s: skipped invalid delivering_item '%s'" % [grid_pos, iid])
	if state.has("input_inv"):
		input_inv.deserialize(state["input_inv"])
	if state.has("energy") and energy:
		energy.deserialize(state["energy"])

