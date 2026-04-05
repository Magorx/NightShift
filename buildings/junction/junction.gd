class_name JunctionLogic
extends BuildingLogic
## Physics junction: open crossover tile. Items roll through freely
## in any direction — no forces applied, no blocking.
## In the physics system this is essentially a pass-through marker.

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)

func try_insert_item(_item_id: StringName, _quantity: int = 1) -> int:
	return _quantity

# ── Pull interface stubs ──────────────────────────────────────────────────────

func has_output_toward(_target_pos: Vector2i) -> bool:
	return false

func can_provide_to(_target_pos: Vector2i) -> bool:
	return false

func peek_output_for(_target_pos: Vector2i) -> StringName:
	return &""

func take_item_for(_target_pos: Vector2i) -> StringName:
	return &""

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return true

func can_accept_from(_from_dir_idx: int) -> bool:
	return true

func cleanup_visuals() -> void:
	pass

func serialize_state() -> Dictionary:
	return {}

func deserialize_state(_state: Dictionary) -> void:
	pass

func get_info_stats() -> Array:
	return [{type = "stat", text = "Open crossover"}]

func get_inventory_items() -> Array:
	return []

func remove_inventory_item(_item_id: StringName, _count: int) -> int:
	return 0
