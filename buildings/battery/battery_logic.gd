class_name BatteryLogic
extends BuildingLogic

## Battery: 1x1 energy storage building. Huge capacity, single connection.

var _fill

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)
	# Energy capacity 2000 (node adds inner_capacity on top)
	energy = BuildingEnergy.new(2000.0, 0.0, 0.0)
	_fill = get_parent().get_node_or_null("Rotatable/CodeAnim")

func _physics_process(_delta: float) -> void:
	if energy and _fill:
		_fill.set_fill(energy.get_fill_ratio())

func has_output_toward(_target_pos: Vector2i) -> bool:
	return false

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return false

func cleanup_visuals() -> void:
	pass

# ── Serialization ────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {}
	if energy:
		state["energy"] = energy.serialize()
	var enode = get_energy_node()
	if enode:
		state["energy_node"] = {"connections": enode.serialize_connections()}
	return state

func deserialize_state(state: Dictionary) -> void:
	if state.has("energy") and energy:
		energy.deserialize(state["energy"])

# ── Info panel ───────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var stats: Array = []
	stats.append({type = "stat", text = "Battery"})
	if energy:
		stats.append({type = "stat", text = "Stored: %.0f/%.0f" % [energy.energy_stored, energy.energy_capacity]})
		stats.append({type = "progress", value = energy.get_fill_ratio()})
	return stats
