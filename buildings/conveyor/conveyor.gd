class_name ConveyorBelt
extends BuildingLogic
## Physics-based conveyor belt. An Area3D force zone applies directional
## force to overlapping PhysicsItem bodies, pushing them along the conveyor.
##
## Auto-shape: detects adjacent conveyors and swaps model variant
## (straight, turn, two_straight, two_turn, cross) to match connections.

const FORCE_MAGNITUDE := 8.0   # Newtons applied to items
const TARGET_SPEED := 2.5      # tiles/s — force tapers when item reaches this speed
const DAMPING_FORCE := 3.0     # lateral damping to keep items centered

var direction: int = 0

# ── Auto-shape ────────────────────────────────────────────────────────────────

## Model scenes for each variant (preloaded for fast swapping).
const VARIANT_SCENES := {
	&"conveyor": preload("res://buildings/conveyor/models/conveyor.glb"),
	&"conveyor_turn": preload("res://buildings/conveyor/models/conveyor_turn.glb"),
	&"conveyor_two_straight": preload("res://buildings/conveyor/models/conveyor_two_straight.glb"),
	&"conveyor_two_turn": preload("res://buildings/conveyor/models/conveyor_two_turn.glb"),
	&"conveyor_cross": preload("res://buildings/conveyor/models/conveyor_cross.glb"),
	&"wall": preload("res://buildings/conveyor/models/wall.glb"),
	&"tower": preload("res://buildings/conveyor/models/tower.glb"),
}

## Turn variants that become towers at night (taller, elevated vantage).
const TURN_VARIANTS: Array[StringName] = [&"conveyor_turn", &"conveyor_two_turn"]

## Base model transform from conveyor.tscn (-90° Y rotation aligning model to building).
const BASE_MODEL_TRANSFORM := Transform3D(
	Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3.ZERO
)

var _current_variant: StringName = &"conveyor"
var _current_rotation_steps: int = 0
var _force_zone: Area3D
var _overlap_count: int = 0

# ── Night transform state ────────────────────────────────────────────────────
var is_night_form: bool = false
var _day_variant: StringName = &""
var _day_rotation_steps: int = 0

func set_night_mode(enabled: bool) -> void:
	is_night_mode = enabled
	is_night_form = enabled
	var building := get_parent() as BuildingBase
	if enabled:
		_day_variant = _current_variant
		_day_rotation_steps = _current_rotation_steps
		set_physics_process(false)
		# Walls/towers need collision — conveyors normally skip it
		if building:
			building.force_collision = true
		var night_variant: StringName = &"tower" if _current_variant in TURN_VARIANTS else &"wall"
		_swap_model(night_variant, 0)
	else:
		set_physics_process(true)
		if building:
			building.force_collision = false
		if _day_variant != &"":
			_swap_model(_day_variant, _day_rotation_steps)
			_day_variant = &""
			_day_rotation_steps = 0

func configure(def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(def, p_grid_pos, rotation)
	direction = rotation
	_force_zone = get_parent().get_node_or_null("ForceZone")
	if _force_zone:
		_force_zone.body_entered.connect(_on_zone_body_entered)
		_force_zone.body_exited.connect(_on_zone_body_exited)
	# Defer so adjacent buildings are fully registered in the grid first
	update_shape.call_deferred()

func _on_zone_body_entered(_body: Node3D) -> void:
	_overlap_count += 1

func _on_zone_body_exited(_body: Node3D) -> void:
	_overlap_count -= 1

func _physics_process(delta: float) -> void:
	if not _force_zone or _overlap_count <= 0:
		_update_building_sprites(false, delta)
		return
	var has_items := false
	var fwd := _get_world_forward()
	var lateral := Vector3(-fwd.z, 0.0, fwd.x)  # perpendicular on XZ plane
	for body in _force_zone.get_overlapping_bodies():
		if body is PhysicsItem:
			has_items = true
			var item := body as PhysicsItem
			# Push along conveyor direction
			var speed_along: float = item.linear_velocity.dot(fwd)
			if speed_along < TARGET_SPEED:
				item.apply_central_force(fwd * FORCE_MAGNITUDE)
			# Damp lateral drift (keep items centered)
			var lat_speed: float = item.linear_velocity.dot(lateral)
			if absf(lat_speed) > 0.1:
				item.apply_central_force(-lateral * lat_speed * DAMPING_FORCE)
		elif body is Player:
			body.conveyor_push = fwd * TARGET_SPEED
	_update_building_sprites(has_items, delta)

func _get_world_forward() -> Vector3:
	var building := get_parent() as Node3D
	return (building.global_transform.basis * Vector3.RIGHT).normalized()

func get_direction_vector() -> Vector2i:
	return DIRECTION_VECTORS[direction]

func get_next_pos() -> Vector2i:
	return grid_pos + get_direction_vector()

# ── Auto-shape detection ──────────────────────────────────────────────────────

func _has_adjacent_conveyor(dir_idx: int) -> bool:
	return BuildingRegistry.get_conveyor_at(adjacent_cell(dir_idx)) != null

## Determine the best model variant and rotation for current neighbors.
## Returns [variant_name, rotation_steps] where rotation_steps is 0-3
## (each step = 90° CW in building-local space).
func _determine_shape() -> Array:
	# Check all 4 building-local directions:
	# forward (output), right, backward (input), left
	var f := _has_adjacent_conveyor(direction)
	var r := _has_adjacent_conveyor((direction + 1) % 4)
	var b := _has_adjacent_conveyor((direction + 2) % 4)
	var l := _has_adjacent_conveyor((direction + 3) % 4)

	var n_sides := int(l) + int(r)
	var n_along := int(f) + int(b)

	# No side connections → straight
	if n_sides == 0:
		return [&"conveyor", 0]

	# All four → cross
	if n_sides == 2 and n_along == 2:
		return [&"conveyor_cross", 0]

	# Both sides connected → two_turn (T-shape)
	if n_sides == 2:
		if b:
			return [&"conveyor_two_turn", 2]  # wall at front
		return [&"conveyor_two_turn", 0]      # wall at back

	# One side + both along → two_straight
	if n_along == 2:
		if r:
			return [&"conveyor_two_straight", 0]
		return [&"conveyor_two_straight", 2]

	# One side, 0-1 along → turn
	if r:
		if b:
			return [&"conveyor_turn", 2]  # open B+R
		return [&"conveyor_turn", 1]      # open F+R
	# left connected
	if b:
		return [&"conveyor_turn", 3]      # open B+L
	return [&"conveyor_turn", 0]          # open F+L

## Check neighbors and swap model if the shape changed.
func update_shape() -> void:
	var result := _determine_shape()
	var variant: StringName = result[0]
	var rot_steps: int = result[1]

	if variant == _current_variant and rot_steps == _current_rotation_steps:
		return

	_current_variant = variant
	_current_rotation_steps = rot_steps
	_swap_model(variant, rot_steps)

func _swap_model(variant: StringName, rot_steps: int) -> void:
	var building := get_parent()
	var old_model := building.get_node_or_null("Model")
	if old_model:
		building.remove_child(old_model)
		old_model.queue_free()

	var new_model: Node3D = VARIANT_SCENES[variant].instantiate()
	new_model.name = "Model"

	# Apply base transform + extra CW rotation in building space
	if rot_steps == 0:
		new_model.transform = BASE_MODEL_TRANSFORM
	else:
		var extra := Basis(Vector3.UP, -rot_steps * PI / 2.0)
		new_model.transform = Transform3D(extra, Vector3.ZERO) * BASE_MODEL_TRANSFORM

	building.add_child(new_model)

	# Reset animation cache so it re-discovers the new AnimationPlayer
	_cached_anim_player = null
	_visuals_cached = false
	_use_3d_model = false
	_anim_initialized = false

	# Rebuild collision from new model meshes
	if building.has_method("regenerate_collision"):
		building.regenerate_collision.call_deferred()

# ── Serialization ─────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	return {}

func deserialize_state(_state: Dictionary) -> void:
	# Re-evaluate shape on load (neighbors may already be placed)
	update_shape.call_deferred()

func get_info_stats() -> Array:
	var dirs := ["Right", "Down", "Left", "Up"]
	return [
		{type = "stat", text = "Direction: %s" % dirs[direction]},
	]
