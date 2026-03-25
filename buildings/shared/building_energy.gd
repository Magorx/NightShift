class_name BuildingEnergy
extends RefCounted

## Separate energy state component for buildings that participate in the energy grid.
## Buildings that don't use energy have energy == null on their BuildingLogic.

var energy_stored: float = 0.0        # current energy in this building
var energy_capacity: float = 0.0      # max local storage
var base_energy_demand: float = 0.0   # continuous energy/s needed to operate
var is_powered: bool = true           # computed: true if base_demand is met
var generation_rate: float = 0.0      # energy/s produced (generators only)

func _init(p_capacity: float = 0.0, p_demand: float = 0.0, p_generation: float = 0.0) -> void:
	energy_capacity = p_capacity
	base_energy_demand = p_demand
	generation_rate = p_generation
	# Buildings with no base demand start powered
	is_powered = p_demand <= 0.0

## Get fill ratio (0.0 - 1.0).
func get_fill_ratio() -> float:
	if energy_capacity <= 0.0:
		return 0.0
	return clampf(energy_stored / energy_capacity, 0.0, 1.0)

## Add energy, capped at capacity. Returns amount actually added.
func add_energy(amount: float) -> float:
	var space := energy_capacity - energy_stored
	var added := minf(amount, space)
	energy_stored += added
	return added

## Remove energy. Returns amount actually removed.
func remove_energy(amount: float) -> float:
	var removed := minf(amount, energy_stored)
	energy_stored -= removed
	return removed

## Check if building can afford a recipe energy cost.
func can_afford(cost: float) -> bool:
	return energy_stored >= cost

## Consume energy for a recipe. Returns true if successful.
func consume_for_recipe(cost: float) -> bool:
	if energy_stored < cost:
		return false
	energy_stored -= cost
	return true

# ── Serialization ────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	return {"energy_stored": energy_stored}

func deserialize(data: Dictionary) -> void:
	if data.has("energy_stored"):
		energy_stored = clampf(float(data["energy_stored"]), 0.0, energy_capacity)
