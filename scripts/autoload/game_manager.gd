extends Node

## Thin facade / service locator for scene-layer references.
## Domain logic has been extracted to: BuildingRegistry, ItemRegistry, MapManager, EconomyTracker.

## Z-index layers for isometric depth ordering (legacy 2D, used by MultiMesh2D renderers).
const Z_CONVEYOR := 0
const Z_ITEM := 1
const Z_BUILDING := 2

# Reference to scene layer nodes (set by game_world on ready)
var building_layer: Node
var item_layer: Node
var building_tick_system: Node  # BuildingTickSystem
var building_collision  # BuildingCollision (StaticBody2D for player collision)
var player  # Player (CharacterBody2D)

# When true, game_world runs the stress test generator after world gen
var stress_test_pending: bool = false

# Building hotkeys: key_scancode (int) -> building_id (StringName)
const DEFAULT_HOTKEYS: Dictionary = {
	KEY_1: &"conveyor",
	KEY_2: &"junction",
	KEY_3: &"splitter",
	KEY_4: &"source",
	KEY_5: &"sink",
	KEY_6: &"smelter",
	KEY_7: &"drill",
}
var building_hotkeys: Dictionary = DEFAULT_HOTKEYS.duplicate()

# Last building selected for building mode (defaults to conveyor)
var last_selected_building: StringName = &"conveyor"

## Reset all game state across subsystems.
func clear_all() -> void:
	BuildingRegistry.clear()
	ItemRegistry.clear()
	MapManager.clear()
	EconomyTracker.clear()
	if building_tick_system:
		building_tick_system.clear_all()
	if building_collision:
		building_collision.clear_all()
