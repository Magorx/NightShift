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

## Energy component (BuildingEnergy or null). null = building does not participate in energy grid.
var energy = null

# ── Animation state management ────────────────────────────────────────────────
## Hold timer prevents active→idle flicker between craft cycles.
var _active_hold_timer: float = 0.0
var _anim_active: bool = false
var _anim_connected: bool = false
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

# ── Energy helpers ─────────────────────────────────────────────────────────

## Find child EnergyNode if present. Returns null if none.
## Uses duck-typing to avoid compile-time dependency on EnergyNode class.
## Result is cached after first call.
var _cached_energy_node = null
var _energy_node_looked_up: bool = false

func get_energy_node():
	if _energy_node_looked_up:
		return _cached_energy_node
	_energy_node_looked_up = true
	var building = get_parent()
	var rotatable = building.find_child("Rotatable", false, false)
	var container = rotatable if rotatable else building
	for child in container.get_children():
		if child is Node2D and child.has_method("can_connect_to"):
			_cached_energy_node = child
			return child
	return null

## Return the energy_cost of the most expensive recipe this building can
## currently craft (has all input resources). Used by the energy network to
## compute the building's energy floor. Override in converter-like buildings.
func get_max_affordable_recipe_cost() -> float:
	return 0.0

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
var _cached_sprite_base: AnimatedSprite2D
var _cached_sprite_top: AnimatedSprite2D
var _sprites_cached: bool = false

func _update_building_sprites(is_active: bool, delta: float) -> void:
	if is_active:
		_active_hold_timer = ACTIVE_HOLD_TIME
	elif _active_hold_timer > 0.0:
		_active_hold_timer -= delta
	var want_active := is_active or _active_hold_timer > 0.0
	if not _sprites_cached:
		_sprites_cached = true
		_cached_sprite_base = get_parent().get_node_or_null("Rotatable/SpriteBottom") as AnimatedSprite2D
		_cached_sprite_top = get_parent().get_node_or_null("Rotatable/SpriteTop") as AnimatedSprite2D
	var base := _cached_sprite_base
	var top := _cached_sprite_top
	if not base:
		return
	if not _anim_connected:
		base.animation_finished.connect(_on_building_anim_finished)
		_anim_connected = true
	# First call: jump directly to correct state (no transition on load)
	if not _anim_initialized:
		_anim_initialized = true
		_anim_active = want_active
		var anim: StringName = &"active" if want_active else &"idle"
		if base.sprite_frames.has_animation(anim):
			_set_building_anim(base, top, anim)
		return
	if want_active == _anim_active:
		return
	_anim_active = want_active
	if want_active:
		if base.sprite_frames.has_animation(&"windup"):
			_set_building_anim(base, top, &"windup")
		else:
			_set_building_anim(base, top, &"active")
	else:
		if base.sprite_frames.has_animation(&"winddown"):
			_set_building_anim(base, top, &"winddown")
		else:
			_set_building_anim(base, top, &"idle")

func _set_building_anim(base: AnimatedSprite2D, top: AnimatedSprite2D, anim: StringName) -> void:
	base.animation = anim
	base.play()
	if top and top.sprite_frames and top.sprite_frames.has_animation(anim):
		top.animation = anim
		top.play()

func _on_building_anim_finished() -> void:
	var base := _cached_sprite_base
	if not base:
		return
	var top := _cached_sprite_top
	if base.animation == &"windup":
		_set_building_anim(base, top, &"active")
	elif base.animation == &"winddown":
		_set_building_anim(base, top, &"idle")

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
