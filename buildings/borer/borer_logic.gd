class_name BorerLogic
extends BuildingLogic

## Extracts resources from adjacent wall terrain.
## Faces a wall tile and produces items based on the wall type.
## Output goes in the opposite direction from the bore face.

var direction: int = 0
var item_id: StringName = &""
var produce_interval: float = 3.0
var _timer: float = 0.0
var inventory: Inventory = Inventory.new()

func configure(_def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(_def, p_grid_pos, rotation)
	direction = rotation
	# Check the wall tile we're facing
	var bore_pos: Vector2i = grid_pos + DIRECTION_VECTORS[direction]
	var wall_tile: int = int(GameManager.walls.get(bore_pos, -1))
	# Look up what item this wall produces (TILE_STONE = 7)
	var wall_items: Dictionary = {7: &"stone"}
	item_id = StringName(wall_items.get(wall_tile, &""))
	if item_id != &"":
		inventory.set_capacity(item_id, 5)

func _physics_process(delta: float) -> void:
	if item_id == &"":
		_update_building_sprites(false, delta)
		return
	_timer += delta
	if _timer >= produce_interval and inventory.has_space(item_id):
		inventory.add(item_id)
		_timer = 0.0
	elif _timer >= produce_interval:
		_timer = produce_interval
	_update_building_sprites(inventory.has_space(item_id), delta)

func get_output_cell() -> Vector2i:
	# Output goes opposite the bore direction
	return grid_pos + DIRECTION_VECTORS[(direction + 2) % 4]

func can_provide_to(target_pos: Vector2i) -> bool:
	return not inventory.is_empty() and target_pos == get_output_cell()

func take_item() -> StringName:
	inventory.remove(item_id)
	return item_id

func get_progress() -> float:
	if item_id == &"":
		return -1.0
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

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	return {"timer": _timer, "inventory": inventory.serialize()}

func deserialize_state(state: Dictionary) -> void:
	if state.has("timer"):
		_timer = state["timer"]
	if state.has("inventory"):
		inventory.deserialize(state["inventory"])

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	if item_id == &"":
		return [{type = "stat", text = "Not facing a mineable wall"}]
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

func remove_inventory_item(item_id: StringName, count: int) -> int:
	var available := inventory.get_count(item_id)
	var to_remove := mini(count, available)
	if to_remove > 0 and inventory.remove(item_id, to_remove):
		return to_remove
	return 0
