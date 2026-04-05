class_name SplitterLogic
extends BuildingLogic
## Physics-based splitter. Detects items in a central zone and applies
## a deflection force toward alternating output directions (round-robin).

const DEFLECT_FORCE := 6.0

var _output_rr_idx: int = 0
## Items we've already deflected (don't double-deflect)
var _deflected: Dictionary = {}  # item instance_id -> output_dir index

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)

func _physics_process(_delta: float) -> void:
	var force_zone: Area3D = get_parent().get_node_or_null("ForceZone")
	if not force_zone:
		return

	# Get available output directions from OutputZone children
	var output_dirs: Array[Vector3] = _get_output_directions()
	if output_dirs.is_empty():
		return

	# Prune freed items from deflected set
	var to_erase: Array = []
	for iid in _deflected:
		if not is_instance_valid(instance_from_id(iid)):
			to_erase.append(iid)
	for iid in to_erase:
		_deflected.erase(iid)

	for body in force_zone.get_overlapping_bodies():
		if not (body is PhysicsItem):
			continue
		var item := body as PhysicsItem
		var iid: int = item.get_instance_id()
		if _deflected.has(iid):
			# Already assigned — keep pushing in that direction
			var dir: Vector3 = output_dirs[_deflected[iid] % output_dirs.size()]
			item.apply_central_force(dir * DEFLECT_FORCE * 0.5)
			continue
		# New item — assign to next output (round-robin)
		var dir_idx: int = _output_rr_idx % output_dirs.size()
		_output_rr_idx += 1
		_deflected[iid] = dir_idx
		item.apply_central_impulse(output_dirs[dir_idx] * DEFLECT_FORCE * 0.3)

func _get_output_directions() -> Array[Vector3]:
	var dirs: Array[Vector3] = []
	var outputs: Node = get_parent().get_node_or_null("Outputs")
	if not outputs:
		return dirs
	var building := get_parent() as Node3D
	for child in outputs.get_children():
		if child is OutputZone:
			var zone: OutputZone = child
			# Compute world direction from building center to output position
			var local_pos := zone.position
			var dir := Vector3(local_pos.x, 0, local_pos.z).normalized()
			var world_dir: Vector3 = building.global_transform.basis * dir
			world_dir.y = 0
			dirs.append(world_dir.normalized())
	return dirs

func try_insert_item(_item_id: StringName, _quantity: int = 1) -> int:
	return _quantity

# ── Pull interface stubs ──────────────────────────────────────────────────────

func has_output_toward(_target_pos: Vector2i) -> bool:
	return false

func can_provide_to(_target_pos: Vector2i) -> bool:
	return false

func peek_output_for(_target_pos: Vector2i) -> StringName:
	return &""

func take_item_for(_target_pos: Vector2i) -> StringName:
	return &""

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return true

func can_accept_from(_from_dir_idx: int) -> bool:
	return true

func cleanup_visuals() -> void:
	pass

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	return {"rr_idx": _output_rr_idx}

func deserialize_state(state: Dictionary) -> void:
	if state.has("rr_idx"):
		_output_rr_idx = state["rr_idx"]

func get_info_stats() -> Array:
	return [
		{type = "stat", text = "Items deflected: %d" % _output_rr_idx},
	]

func get_inventory_items() -> Array:
	return []

func remove_inventory_item(_item_id: StringName, _count: int) -> int:
	return 0
