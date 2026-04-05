class_name SplitterLogic
extends BuildingLogic
## Physics-based splitter. Detects items in a central zone and applies
## a deflection force toward alternating output directions (round-robin).

const DEFLECT_FORCE := 6.0

var _output_rr_idx: int = 0
## Maps item instance_id -> assigned output direction index.
## Entries added on body_entered, removed on body_exited — bounded by
## the number of items physically inside the zone at any moment.
var _assigned: Dictionary = {}

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)

func _ready() -> void:
	# Connect signals so _assigned stays bounded
	var force_zone: Area3D = get_parent().get_node_or_null("ForceZone")
	if force_zone:
		force_zone.body_exited.connect(_on_body_exited)

func _on_body_exited(body: Node3D) -> void:
	_assigned.erase(body.get_instance_id())

func _physics_process(_delta: float) -> void:
	var force_zone: Area3D = get_parent().get_node_or_null("ForceZone")
	if not force_zone:
		return

	var output_dirs: Array[Vector3] = _get_output_directions()
	if output_dirs.is_empty():
		return

	for body in force_zone.get_overlapping_bodies():
		if not (body is PhysicsItem):
			continue
		var item := body as PhysicsItem
		var iid: int = item.get_instance_id()
		if _assigned.has(iid):
			# Already assigned — keep pushing
			var dir: Vector3 = output_dirs[_assigned[iid] % output_dirs.size()]
			item.apply_central_force(dir * DEFLECT_FORCE * 0.5)
		else:
			# New item — assign to next output (round-robin)
			var dir_idx: int = _output_rr_idx % output_dirs.size()
			_output_rr_idx += 1
			_assigned[iid] = dir_idx
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
