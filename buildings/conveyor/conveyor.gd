class_name ConveyorBelt
extends BuildingLogic
## Physics-based conveyor belt. An Area3D force zone applies directional
## force to overlapping PhysicsItem bodies, pushing them along the conveyor.
## Side walls (StaticBody3D in the scene) prevent items from falling off.

const FORCE_MAGNITUDE := 8.0   # Newtons applied to items
const TARGET_SPEED := 2.5      # tiles/s — force tapers when item reaches this speed
const DAMPING_FORCE := 3.0     # lateral damping to keep items centered

var direction: int = 0

func configure(def: BuildingDef, p_grid_pos: Vector2i, rotation: int) -> void:
	super.configure(def, p_grid_pos, rotation)
	direction = rotation

func _physics_process(delta: float) -> void:
	var force_zone: Area3D = get_parent().get_node_or_null("ForceZone")
	if not force_zone:
		return
	var has_items := false
	var fwd := _get_world_forward()
	var lateral := Vector3(-fwd.z, 0.0, fwd.x)  # perpendicular on XZ plane
	for body in force_zone.get_overlapping_bodies():
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
	_update_building_sprites(has_items, delta)

func _get_world_forward() -> Vector3:
	var building := get_parent() as Node3D
	# Building's local +X is the default facing direction (right)
	return (building.global_transform.basis * Vector3.RIGHT).normalized()

func get_direction_vector() -> Vector2i:
	return DIRECTION_VECTORS[direction]

func get_next_pos() -> Vector2i:
	return grid_pos + get_direction_vector()

# ── Conveyor push (player) ────────────────────────────────────────────────────

var push_speed: float = 1.0

# ── Stub pull interface (old system compat, returns empty/false) ──────────────

func has_item() -> bool:
	return false

func is_full() -> bool:
	return false

func can_accept() -> bool:
	return true

func place_item(_item_id: StringName, _entry_from: Vector2i = Vector2i.ZERO, _entry_dist: float = 0.5) -> bool:
	return false

func try_insert_item(_item_id: StringName, _quantity: int = 1) -> int:
	return _quantity

func pop_front_item() -> Dictionary:
	return {}

func get_front_item() -> Dictionary:
	return {}

func update_items(_delta: float, _speed: float) -> void:
	pass

func has_output_toward(target_pos: Vector2i) -> bool:
	return get_next_pos() == target_pos

func can_provide_to(_target_pos: Vector2i) -> bool:
	return false

func peek_output_for(_target_pos: Vector2i) -> StringName:
	return &""

func take_item_for(_target_pos: Vector2i) -> StringName:
	return &""

func has_input_from(_cell: Vector2i, from_dir_idx: int) -> bool:
	return from_dir_idx != direction

func can_accept_from(_from_dir_idx: int) -> bool:
	return true

func cleanup_visuals() -> void:
	pass

func on_removing() -> void:
	pass

# ── Serialization (no buffer state to save) ───────────────────────────────────

func serialize_state() -> Dictionary:
	return {}

func deserialize_state(_state: Dictionary) -> void:
	pass

func get_info_stats() -> Array:
	var dirs := ["Right", "Down", "Left", "Up"]
	return [
		{type = "stat", text = "Direction: %s" % dirs[direction]},
	]

func get_inventory_items() -> Array:
	return []

func remove_inventory_item(_item_id: StringName, _count: int) -> int:
	return 0
