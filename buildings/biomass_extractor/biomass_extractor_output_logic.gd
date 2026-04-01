class_name BiomassExtractorOutputLogic
extends BuildingLogic

## 1x1 output device for the biomass extractor.
## Receives items from the linked extraction part.
## Outputs in the direction it faces (rotation).

var direction: int = 0
var inventory: Inventory = Inventory.new()
var extractor: BuildingLogic = null

func configure(def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(def, p_grid_pos, rotation)
	direction = rotation
	inventory.set_capacity(&"biomass", 5)

## Called by the linked extractor to push an item in.
func accept_from_extractor(item_id: StringName) -> bool:
	if inventory.has_space(item_id):
		inventory.add(item_id)
		return true
	return false

func _physics_process(delta: float) -> void:
	_update_building_sprites(not inventory.is_empty(), delta)

func unlink_extractor() -> void:
	extractor = null

func get_output_cell() -> Vector2i:
	return grid_pos + DIRECTION_VECTORS[direction]

# ── Pull interface ────────────────────────────────────────────────────────

func has_output_toward(target_pos: Vector2i) -> bool:
	return target_pos == get_output_cell()

func can_provide_to(target_pos: Vector2i) -> bool:
	return not inventory.is_empty() and target_pos == get_output_cell()

func peek_output_for(target_pos: Vector2i) -> StringName:
	if can_provide_to(target_pos):
		return &"biomass"
	return &""

func take_item_for(target_pos: Vector2i) -> StringName:
	if can_provide_to(target_pos):
		inventory.remove(&"biomass")
		return &"biomass"
	return &""

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return false

# ── Lifecycle ─────────────────────────────────────────────────────────────

func on_removing() -> void:
	if extractor and extractor.has_method("on_removing"):
		extractor.output_device = null
	extractor = null

func get_linked_positions() -> Array:
	if extractor:
		return [extractor.grid_pos]
	return []

# ── Serialization ─────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {"direction": direction, "inventory": inventory.serialize()}
	if extractor:
		state["extractor_x"] = extractor.grid_pos.x
		state["extractor_y"] = extractor.grid_pos.y
	return state

func deserialize_state(state: Dictionary) -> void:
	if state.has("direction"):
		direction = state["direction"]
	if state.has("inventory"):
		inventory.deserialize(state["inventory"])

# ── Info panel ────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	return [
		{type = "stat", text = "Output: %s" % (str(DIRECTION_VECTORS[direction]))},
		{type = "stat", text = "Inventory: %d/5" % inventory.get_count(&"biomass")},
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
