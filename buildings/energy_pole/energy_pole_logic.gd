class_name EnergyPoleLogic
extends BuildingLogic

## Basic Energy Pole: 1x1 relay building. No items, no generation, no consumption.
## Has EnergyNode for explicit long-range connections.

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)
	# Energy capacity 50 (node adds inner_capacity on top of this)
	energy = BuildingEnergy.new(50.0, 0.0, 0.0)

# No item I/O
func has_output_toward(_target_pos: Vector2i) -> bool:
	return false

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return false

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
	# Node connections are restored by EnergySystem after all buildings are placed

# ── Info panel ───────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var stats: Array = []
	stats.append({type = "stat", text = "Energy Pole"})
	if energy:
		stats.append({type = "stat", text = "Energy: %.0f/%.0f" % [energy.energy_stored, energy.energy_capacity]})
	var enode = get_energy_node()
	if enode:
		stats.append({type = "stat", text = "Connections: %d/%d" % [enode.connections.size(), enode.max_connections]})
		stats.append({type = "stat", text = "Range: %.0f tiles" % enode.connection_range})
	return stats
