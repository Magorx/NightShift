class_name UndergroundTransportLogic
extends BuildingLogic
## Base class for paired underground transport buildings (tunnels).
## Handles partner linking, direction, and serialization.
## Subclasses override _physics_process for actual item transport.

var max_tunnel_gap: int = 4
var direction: int = 0
var is_input: bool = true
var partner: UndergroundTransportLogic = null
var tunnel_length: int = 1

func configure(def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(def, p_grid_pos, rotation)
	direction = rotation
	is_input = _is_input_category(def.category)

func _is_input_category(_category: String) -> bool:
	return false

func setup_pair(p_partner: UndergroundTransportLogic, p_length: int) -> void:
	partner = p_partner
	tunnel_length = p_length

func has_input_from(_cell: Vector2i, from_dir_idx: int) -> bool:
	if not is_input or not partner:
		return false
	return from_dir_idx == (direction + 2) % 4

func get_linked_positions() -> Array:
	if partner:
		return [partner.grid_pos]
	return []

func on_removing() -> void:
	if partner:
		partner.partner = null

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {}
	state["tunnel_is_input"] = is_input
	state["tunnel_direction"] = direction
	state["tunnel_length"] = tunnel_length
	if partner:
		state["tunnel_partner_x"] = partner.grid_pos.x
		state["tunnel_partner_y"] = partner.grid_pos.y
	return state

func deserialize_state(_state: Dictionary) -> void:
	pass

func get_info_stats() -> Array:
	var stats: Array = []
	stats.append({type = "stat", text = "End: %s" % ("Input" if is_input else "Output")})
	stats.append({type = "stat", text = "Length: %d" % tunnel_length})
	stats.append({type = "stat", text = "Partner: %s" % (str(partner.grid_pos) if partner else "none")})
	return stats

func get_inventory_items() -> Array:
	return []

func remove_inventory_item(_item_id: StringName, _count: int) -> int:
	return 0
