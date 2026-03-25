class_name BuildingLogic
extends Node

## Base class for all building logic nodes. Provides the unified pull interface,
## self-configuration, serialization, and info panel data.
##
## Every building logic script (ConveyorBelt, SplitterLogic, etc.) extends this.
## GameManager finds the logic node by type (`child is BuildingLogic`) rather than
## by name, so adding a new building type requires zero changes to GameManager.

const TILE_SIZE := 32
const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid_pos: Vector2i

# ── Configuration (called once during placement) ────────────────────────────

## Set up building-specific state after placement.
## Override in subclass and call super() first.
func configure(_def: BuildingDef, p_grid_pos: Vector2i, _rotation: int) -> void:
	grid_pos = p_grid_pos

# ── Pull interface ──────────────────────────────────────────────────────────

func has_output_toward(_target_pos: Vector2i) -> bool:
	return false

func can_provide_to(_target_pos: Vector2i) -> bool:
	return false

func peek_output_for(_target_pos: Vector2i) -> StringName:
	return &""

func take_item_for(_target_pos: Vector2i) -> StringName:
	return &""

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return false

# ── Visual origin ──────────────────────────────────────────────────────────

## How far (in tile-halves) from the pulling conveyor's center the item visual
## should originate.  0.5 = tile edge (conveyors), 1.0 = source center (default).
func get_output_visual_distance() -> float:
	return 1.0

# ── Downstream acceptance ───────────────────────────────────────────────────

## Returns true if this building can currently accept an item from the given
## direction. Used by splitters/routers to check downstream capacity without
## type-checking every building kind.
func can_accept_from(_from_dir_idx: int) -> bool:
	return false

# ── Lifecycle ───────────────────────────────────────────────────────────────

func cleanup_visuals() -> void:
	pass

## Called just before removal. Override for partner unlinking, unregistration, etc.
func on_removing() -> void:
	pass

## Return grid positions of buildings linked to this one (e.g. tunnel partner).
func get_linked_positions() -> Array:
	return []

# ── Serialization ───────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	return {}

func deserialize_state(_state: Dictionary) -> void:
	pass

# ── Info panel ──────────────────────────────────────────────────────────────

## Return structured display data for the building info panel.
## Entry types:
##   {type="stat", text=String}
##   {type="progress", value=float}           (0.0–1.0)
##   {type="recipe", recipe=RecipeDef, active=bool}
##   {type="inventory", label=String, items=Array[{id, count}]}
func get_info_stats() -> Array:
	return []
