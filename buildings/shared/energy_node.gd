class_name EnergyNode
extends Node2D

## Composable energy connection component. Attach as a child of any building scene
## to grant that building explicit long-range energy connections beyond adjacency.

@export var max_connections: int = 3           # max number of explicit links
@export var throughput: float = 100.0          # max energy transfer per connection per second
@export var inner_capacity: float = 50.0       # additional energy storage from the node itself
@export var connection_range: float = 5.0      # max distance in tiles for linking

## Linked nodes (bidirectional). Managed by EnergySystem.
var connections: Array = []  # Array of EnergyNode references

## Grid position of the owning building (set during registration).
var owner_grid_pos: Vector2i = Vector2i.ZERO

## Back-reference to the owning BuildingLogic (set during registration).
var owner_logic: Node = null  # BuildingLogic

# ── Connection management ────────────────────────────────────────────────────

func can_connect_to(other: EnergyNode) -> bool:
	if other == self:
		return false
	if is_connected_to(other):
		return false
	if connections.size() >= max_connections:
		return false
	if other.connections.size() >= other.max_connections:
		return false
	if not is_in_range(other):
		return false
	return true

func connect_to(other: EnergyNode) -> bool:
	if not can_connect_to(other):
		return false
	connections.append(other)
	other.connections.append(self)
	return true

func disconnect_from(other: EnergyNode) -> void:
	connections.erase(other)
	other.connections.erase(self)

func disconnect_all() -> void:
	for other in connections.duplicate():
		other.connections.erase(self)
	connections.clear()

func is_connected_to(other: EnergyNode) -> bool:
	return connections.has(other)

func is_in_range(other: EnergyNode) -> bool:
	var dist := _tile_distance(other)
	# Use the larger of the two ranges (either node can reach the other)
	return dist <= maxf(connection_range, other.connection_range)

func has_free_slot() -> bool:
	return connections.size() < max_connections

func _tile_distance(other: EnergyNode) -> float:
	return float(absi(owner_grid_pos.x - other.owner_grid_pos.x) + absi(owner_grid_pos.y - other.owner_grid_pos.y))

# ── Serialization ────────────────────────────────────────────────────────────

func serialize_connections() -> Array:
	var result: Array = []
	for other in connections:
		if is_instance_valid(other):
			result.append({"x": other.owner_grid_pos.x, "y": other.owner_grid_pos.y})
	return result
