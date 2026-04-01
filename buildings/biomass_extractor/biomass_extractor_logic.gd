class_name BiomassExtractorLogic
extends BuildingLogic

## 1x2 extraction part of the biomass extractor.
## Must be placed entirely on biomass deposits.
## Produces biomass items and pushes them to the linked output device.
## Visual feedback via coded arm animation (CodeAnimArm node), not sprite states.

var direction: int = 0
var produce_interval: float = 2.0
var _timer: float = 0.0
var _covered_cells: Array = []  # Vector2i cells this extractor sits on

## Linked output device (set after both phases are placed)
var output_device: BuildingLogic = null

## Arm animation nodes (found on first tick)
var _arms: Array = []
var _arms_looked_up: bool = false

func get_placement_error(p_grid_pos: Vector2i, p_rotation: int) -> String:
	# During save/load, skip validation (building was valid when originally placed;
	# some cells may have since been drained to ash)
	if GameManager.energy_system and GameManager.energy_system.loading:
		return ""
	var def = GameManager.get_building_def(&"biomass_extractor")
	if not def:
		return "Missing building def"
	var shape: Array = def.get_rotated_shape(p_rotation)
	for cell in shape:
		var check_pos: Vector2i = p_grid_pos + Vector2i(cell)
		if GameManager.deposits.get(check_pos, &"") != &"biomass":
			return "Must be placed on biomass"
		var stock: int = GameManager.deposit_stocks.get(check_pos, 0)
		if stock == 0:
			return "Deposit depleted"
	return ""

func configure(def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(def, p_grid_pos, rotation)
	direction = rotation
	_covered_cells.clear()
	var shape: Array = def.get_rotated_shape(rotation)
	for cell in shape:
		_covered_cells.append(p_grid_pos + Vector2i(cell))

func _find_arms() -> void:
	_arms_looked_up = true
	var rotatable = get_parent().find_child("Rotatable", false, false)
	if rotatable:
		for child in rotatable.get_children():
			if child is Node2D and String(child.name).begins_with("CodeAnimArm"):
				_arms.append(child)

func _physics_process(delta: float) -> void:
	if not _arms_looked_up:
		_find_arms()

	var producing := output_device != null and output_device.has_method("accept_from_extractor")
	if not producing:
		_update_arm(false)
		_update_building_sprites(false, delta)
		return

	_timer += delta
	if _timer >= produce_interval and output_device.accept_from_extractor(&"biomass"):
		_timer = 0.0
		if GameManager.cluster_drain_manager:
			var tile: Vector2i = GameManager.cluster_drain_manager.get_next_drain_tile(grid_pos, &"biomass")
			if tile != Vector2i(-1, -1):
				GameManager.drain_deposit_stock(tile)
	elif _timer >= produce_interval:
		_timer = produce_interval

	_update_arm(true)
	_update_building_sprites(true, delta)

func _update_arm(active: bool) -> void:
	if _arms.is_empty():
		return
	var targets: Array = _get_arm_targets() if active else []
	for arm in _arms:
		if arm and arm.has_method("set_active"):
			arm.set_active(active, targets)

## Compute reachable biomass cell positions in Rotatable-local coords.
## The arm base is at (16,16) = maw center. Targets are adjacent cells
## that are biomass deposits with stock remaining.
func _get_arm_targets() -> Array:
	var targets: Array = []
	for dir_idx in range(4):
		var dir: Vector2i = DIRECTION_VECTORS[dir_idx]
		var check: Vector2i = grid_pos + dir
		# Skip cells the building occupies
		var occupied := false
		for cell in _covered_cells:
			if check == cell:
				occupied = true
				break
		if occupied:
			continue
		if GameManager.deposits.get(check, &"") != &"biomass":
			continue
		var stock: int = GameManager.deposit_stocks.get(check, 0)
		if stock == 0:
			continue
		# Convert world grid offset to Rotatable-local coords.
		# Building rotation is applied visually by _rotate_visuals, which
		# rotates the CodeAnimArm around the pivot (16,16).
		# So we need to UN-rotate the world offset to get Rotatable-local.
		var world_offset := Vector2(dir) * TILE_SIZE
		var local_offset := _unrotate(world_offset, direction)
		targets.append(Vector2(16, 16) + local_offset)
	return targets

## Un-rotate a world-space offset by the building's rotation index.
## Inverse of the rotation applied by _rotate_visuals.
static func _unrotate(v: Vector2, rot: int) -> Vector2:
	match rot:
		1: return Vector2(v.y, -v.x)   # inverse of 90° CW
		2: return Vector2(-v.x, -v.y)  # inverse of 180°
		3: return Vector2(-v.y, v.x)   # inverse of 270° CW
		_: return v

func get_progress() -> float:
	return clampf(_timer / produce_interval, 0.0, 1.0)

# ── Cluster drain interface ───────────────────────────────────────────────

func get_covered_deposit_cells() -> Array:
	return _covered_cells

func get_deposit_item_id() -> StringName:
	return &"biomass"

# ── Lifecycle ─────────────────────────────────────────────────────────────

func on_removing() -> void:
	if output_device and output_device.has_method("unlink_extractor"):
		output_device.unlink_extractor()
	output_device = null
	if GameManager.cluster_drain_manager:
		GameManager.cluster_drain_manager.invalidate_cache()

func get_linked_positions() -> Array:
	if output_device:
		return [output_device.grid_pos]
	return []

# ── Serialization ─────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	var state := {"timer": _timer, "direction": direction}
	if output_device:
		state["output_x"] = output_device.grid_pos.x
		state["output_y"] = output_device.grid_pos.y
	return state

func deserialize_state(state: Dictionary) -> void:
	if state.has("timer"):
		_timer = state["timer"]
	if state.has("direction"):
		direction = state["direction"]

# ── Info panel ────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	var stats: Array = [
		{type = "stat", text = "Extracting: Biomass"},
		{type = "progress", value = get_progress()},
	]
	if output_device:
		stats.append({type = "stat", text = "Output: linked"})
	else:
		stats.append({type = "stat", text = "Output: none"})
	return stats
