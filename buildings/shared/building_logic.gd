class_name BuildingLogic
extends Node

## Base class for all building logic nodes. Provides self-configuration,
## serialization, and info panel data.
##
## Every building logic script (ConveyorBelt, SplitterLogic, etc.) extends this.
## GameManager finds the logic node by type (`child is BuildingLogic`) rather than
## by name, so adding a new building type requires zero changes to GameManager.

const DIRECTION_VECTORS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var grid_pos: Vector2i

## Get the grid cell adjacent to this building in the given direction.
func adjacent_cell(dir_idx: int) -> Vector2i:
	return grid_pos + DIRECTION_VECTORS[dir_idx]

## Get the opposite direction index (0↔2, 1↔3).
static func opposite_dir(dir_idx: int) -> int:
	return (dir_idx + 2) % 4

# ── Animation state management ────────────────────────────────────────────────
## Hold timer prevents active→idle flicker between craft cycles.
var _active_hold_timer: float = 0.0
var _anim_active: bool = false
var _anim_initialized: bool = false
const ACTIVE_HOLD_TIME := 0.3

# ── Placement validation ────────────────────────────────────────────────────

## Return an error string if this building cannot be placed at the given position,
## or "" if placement is allowed. Override in subclasses that have placement
## requirements (e.g. drills require deposits). Called before instantiation.
func get_placement_error(_grid_pos: Vector2i, _rotation: int) -> String:
	return ""

# ── Configuration (called once during placement) ────────────────────────────

## Set up building-specific state after placement.
## Override in subclass and call super() first.
func configure(_def: BuildingDef, p_grid_pos: Vector2i, _rotation: int) -> void:
	grid_pos = p_grid_pos

# ── Player item insertion ──────────────────────────────────────────────────

## Try to insert items directly (e.g. player drops). Returns leftover count.
func try_insert_item(_item_id: StringName, quantity: int = 1) -> int:
	return quantity # Default: building does not accept items

# ── Lifecycle ───────────────────────────────────────────────────────────────

func cleanup_visuals() -> void:
	pass

## Called just before removal. Override for partner unlinking, unregistration, etc.
func on_removing() -> void:
	pass

# ── Sprite animation helpers ─────────────────────────────────────────────────

## Call each frame with the building's functional active state.
## Handles hold timer (anti-flicker) and windup/winddown transitions.
## Supports both legacy AnimatedSprite2D and 3D model AnimationPlayer.
var _cached_anim_player: AnimationPlayer
var _visuals_cached: bool = false
var _use_3d_model: bool = false

func _update_building_sprites(is_active: bool, delta: float) -> void:
	if is_active:
		_active_hold_timer = ACTIVE_HOLD_TIME
	elif _active_hold_timer > 0.0:
		_active_hold_timer -= delta
	var want_active := is_active or _active_hold_timer > 0.0
	if not _visuals_cached:
		_visuals_cached = true
		# Try 3D model AnimationPlayer first
		var model := get_parent().get_node_or_null("Model")
		if model:
			_cached_anim_player = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if not _cached_anim_player:
				# AnimationPlayer might be deeper in the tree (e.g. glb root > child)
				_cached_anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if _cached_anim_player:
				_use_3d_model = true
				_cached_anim_player.animation_finished.connect(_on_3d_anim_finished)
	if not _use_3d_model or not _cached_anim_player:
		return
	# First call: jump directly to correct state
	if not _anim_initialized:
		_anim_initialized = true
		_anim_active = want_active
		var anim: StringName = &"active" if want_active else &"idle"
		if _cached_anim_player.has_animation(anim):
			_cached_anim_player.play(anim)
		return
	if want_active == _anim_active:
		return
	_anim_active = want_active
	if want_active:
		if _cached_anim_player.has_animation(&"windup"):
			_cached_anim_player.play(&"windup")
		elif _cached_anim_player.has_animation(&"active"):
			_cached_anim_player.play(&"active")
	else:
		if _cached_anim_player.has_animation(&"winddown"):
			_cached_anim_player.play(&"winddown")
		elif _cached_anim_player.has_animation(&"idle"):
			_cached_anim_player.play(&"idle")

func _on_3d_anim_finished(anim_name: StringName) -> void:
	if not _cached_anim_player:
		return
	if anim_name == &"windup" and _cached_anim_player.has_animation(&"active"):
		_cached_anim_player.play(&"active")
	elif anim_name == &"winddown" and _cached_anim_player.has_animation(&"idle"):
		_cached_anim_player.play(&"idle")
	elif anim_name == &"active" and _anim_active:
		_cached_anim_player.play(&"active")
	elif anim_name == &"idle" and not _anim_active:
		_cached_anim_player.play(&"idle")

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

# ── Popup interface ────────────────────────────────────────────────────────

## Return the recipe to display in the popup (current, last, or first available).
## Override in converter-like buildings.
func get_popup_recipe():
	return null

## Return true if this building has a custom clickable popup row with a side menu.
## Override in buildings with custom popup UI (e.g. source item selector).
func has_custom_popup_row() -> bool:
	return false

## Return items to display in the custom popup row as [{id: StringName}].
## Only called when has_custom_popup_row() is true.
func get_custom_row_items() -> Array:
	return []

## Create and return a fully populated side menu Control.
## Called when the custom popup row is clicked.
func create_side_menu() -> Control:
	return null

## Return craft progress 0.0–1.0 for the popup segmented bar.
## Override in converter-like buildings.
func get_popup_progress() -> float:
	return -1.0 # negative means no progress bar

## Return items inside this building as [{id: StringName, count: int}, ...].
## Override in all buildings that hold items.
func get_inventory_items() -> Array:
	return []

## Remove up to count of item_id from this building's inventory.
## Returns the amount actually removed. Override in buildings that hold items.
func remove_inventory_item(item_id: StringName, count: int) -> int:
	return 0
