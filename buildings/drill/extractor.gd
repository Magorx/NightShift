class_name ExtractorLogic
extends BuildingLogic


func get_placement_error(p_grid_pos: Vector2i, _rotation: int) -> String:
	if not GameManager.deposits.has(p_grid_pos):
		return "No resource deposit"
	return ""

var direction: int = 0
var item_id: StringName = &"iron_ore":
	set(value):
		item_id = value
		inventory = Inventory.new()
		inventory.set_capacity(item_id, 5)
var produce_interval: float = 2.0  # 1 item every 2 seconds
var _timer: float = 0.0
var inventory: Inventory = Inventory.new()

func configure(_def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(_def, p_grid_pos, rotation)
	direction = rotation
	item_id = GameManager.deposits.get(grid_pos, &"iron_ore")
	# Speed tiers
	if str(_def.id) == "drill_mk2":
		produce_interval = 1.0  # 2x faster
		inventory.set_capacity(item_id, 10)  # larger buffer

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= produce_interval and inventory.has_space(item_id):
		inventory.add(item_id)
		_timer = 0.0
	elif _timer >= produce_interval:
		_timer = produce_interval  # cap timer while full
	_update_building_sprites(inventory.has_space(item_id), delta)

func get_output_cell() -> Vector2i:
	return grid_pos + DIRECTION_VECTORS[direction]

func can_provide_to(target_pos: Vector2i) -> bool:
	return not inventory.is_empty() and target_pos == get_output_cell()

func take_item() -> StringName:
	inventory.remove(item_id)
	return item_id

## Returns production progress as 0.0–1.0 for the progress bar.
func get_progress() -> float:
	return clampf(_timer / produce_interval, 0.0, 1.0)

# ── Pull interface ─────────────────────────────────────────────────────────────

func has_output_toward(target_pos: Vector2i) -> bool:
	return target_pos == get_output_cell()

func peek_output_for(target_pos: Vector2i) -> StringName:
	if can_provide_to(target_pos):
		return item_id
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	if can_provide_to(target_pos):
		return take_item()
	return &""

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return false

func cleanup_visuals() -> void:
	pass

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var inv_data := {}
	for iid in inventory.get_item_ids():
		inv_data[str(iid)] = inventory.get_count(iid)
	return {"timer": _timer, "inventory": inv_data}

func deserialize_state(state: Dictionary) -> void:
	if state.has("timer"):
		_timer = state["timer"]
	if state.has("inventory"):
		for item_id_str in state["inventory"]:
			var iid := StringName(item_id_str)
			if not GameManager.is_valid_item_id(iid):
				GameLogger.warn("Extractor at %s: skipped invalid item '%s'" % [grid_pos, iid])
				continue
			var count: int = int(state["inventory"][item_id_str])
			if inventory.get_capacity(iid) == 0:
				inventory.set_capacity(iid, count + 10)
			for i in count:
				inventory.add(iid)

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	return [
		{type = "stat", text = "Extracting: %s" % str(item_id).capitalize().replace("_", " ")},
		{type = "progress", value = get_progress()},
		{type = "stat", text = "Inventory: %d/5" % inventory.get_count(item_id)},
	]

func get_inventory_items() -> Array:
	var result: Array = []
	for iid in inventory.get_item_ids():
		var count := inventory.get_count(iid)
		if count > 0:
			result.append({id = iid, count = count})
	return result
