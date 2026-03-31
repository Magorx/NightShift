class_name ResearchLabLogic
extends BuildingLogic

## Research Lab building logic. Pulls science packs from inputs and delivers
## them to ResearchManager to advance the current research target.

## Building rotation index (0=right, 1=down, 2=left, 3=up).
var rotation: int = 0

## Input IO points: Array of {cell: Vector2i, mask: Array} — world-space offsets.
var input_points: Array = []

## Inventory for holding science packs before delivery.
var input_inv: Inventory = Inventory.new()

## Delivery timer: time between consuming a pack from inventory and delivering it.
var _deliver_timer: float = 0.0
var _delivering_item: StringName = &""
const DELIVER_TIME := 2.0

var _input_rr: RoundRobin = RoundRobin.new()

## Accepted science pack item IDs.
var _accepted_packs: Array[StringName] = [&"science_pack_1", &"science_pack_2", &"science_pack_3"]

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)
	rotation = p_rotation
	input_points = def.get_rotated_inputs(p_rotation)
	# Set up inventory capacity for all science pack types
	for pack_id in _accepted_packs:
		input_inv.set_capacity(pack_id, 5)
	# Energy setup
	energy = BuildingEnergy.new(50.0, 5.0, 0.0)

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

	_update_building_sprites(_delivering_item != &"", delta)

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
			# Only accept science packs that the current research needs
			if peek_id not in _accepted_packs:
				continue
			if not input_inv.has_space(peek_id):
				continue
			GameManager.pull_item(world_cell, dir_idx)
			input_inv.add(peek_id)

func _try_start_delivery() -> void:
	# Check if there's active research
	if not ResearchManager.current_research:
		return
	# Find a pack in inventory that the research needs
	for pack_id in _accepted_packs:
		if input_inv.has(pack_id) and ResearchManager.needs_pack(pack_id):
			input_inv.remove(pack_id)
			_delivering_item = pack_id
			_deliver_timer = 0.0
			return

# ── Pull interface ──────────────────────────────────────────────────────────

func has_input_from(cell: Vector2i, from_dir_idx: int) -> bool:
	for inp in input_points:
		if grid_pos + inp.cell == cell and inp.mask[from_dir_idx]:
			return true
	return false

func can_accept_from(from_dir_idx: int) -> bool:
	for pack_id in _accepted_packs:
		if input_inv.has_space(pack_id):
			return true
	return false

func try_insert_item(item_id: StringName, quantity: int = 1) -> int:
	if item_id not in _accepted_packs:
		return quantity
	var remaining := quantity
	while remaining > 0 and input_inv.has_space(item_id):
		input_inv.add(item_id)
		remaining -= 1
	return remaining

func cleanup_visuals() -> void:
	pass

# ── Info panel / popup ────────────────────────────────────────────────────

func get_popup_progress() -> float:
	if _delivering_item != &"":
		return clampf(_deliver_timer / DELIVER_TIME, 0.0, 1.0)
	return -1.0

func get_inventory_items() -> Array:
	var result: Array = []
	for pack_id in _accepted_packs:
		var c := input_inv.get_count(pack_id)
		if c > 0:
			result.append({id = pack_id, count = c})
	return result

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
	state["input_inv"] = _serialize_inventory(input_inv)
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
		_deserialize_inventory(input_inv, state["input_inv"])
	if state.has("energy") and energy:
		energy.deserialize(state["energy"])

func _serialize_inventory(inv: Inventory) -> Dictionary:
	var result := {}
	for iid in inv.get_item_ids():
		result[str(iid)] = inv.get_count(iid)
	return result

func _deserialize_inventory(inv: Inventory, data: Dictionary) -> void:
	for item_id_str in data:
		var iid := StringName(item_id_str)
		if not GameManager.is_valid_item_id(iid):
			GameLogger.warn("ResearchLab at %s: skipped invalid item '%s'" % [grid_pos, iid])
			continue
		var count: int = int(data[item_id_str])
		if inv.get_capacity(iid) == 0:
			inv.set_capacity(iid, count + 10)
		for i in count:
			inv.add(iid)
