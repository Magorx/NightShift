class_name SolarPanelLogic
extends BuildingLogic

## Solar Panel: 1x1 passive generator. Produces 8 energy/s constant, no fuel.

const GENERATION_RATE := 8.0

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)
	energy = BuildingEnergy.new(30.0, 0.0, GENERATION_RATE)

func has_output_toward(_target_pos: Vector2i) -> bool:
	return false

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return false

# ── Serialization ────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {}
	if energy:
		state["energy"] = energy.serialize()
	return state

func deserialize_state(state: Dictionary) -> void:
	if state.has("energy") and energy:
		energy.deserialize(state["energy"])

# ── Info panel ───────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var stats: Array = []
	stats.append({type = "stat", text = "Solar Panel (8 energy/s)"})
	if energy:
		stats.append({type = "stat", text = "Energy: %.0f/%.0f" % [energy.energy_stored, energy.energy_capacity]})
	return stats
