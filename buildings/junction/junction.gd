class_name JunctionLogic
extends BuildingLogic
## Physics junction: open crossover tile. Items roll through freely
## in any direction — no forces applied, no blocking.
## In the physics system this is essentially a pass-through marker.

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)

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
