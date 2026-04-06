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
var _force_zone: Area3D
var _cached_output_dirs: Array[Vector3] = []

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)
	# Defer so the scene tree is fully set up before caching directions
	_cache_output_dirs.call_deferred()

func _ready() -> void:
	_force_zone = get_parent().get_node_or_null("ForceZone")
	if _force_zone:
		_force_zone.body_exited.connect(_on_body_exited)

func _on_body_exited(body: Node3D) -> void:
	_assigned.erase(body.get_instance_id())

func _cache_output_dirs() -> void:
	_cached_output_dirs.clear()
	var outputs: Node = get_parent().get_node_or_null("Outputs")
	if not outputs:
		return
	var building := get_parent() as Node3D
	for child in outputs.get_children():
		if child is OutputZone:
			var local_pos: Vector3 = child.position
			var dir := Vector3(local_pos.x, 0, local_pos.z).normalized()
			var world_dir: Vector3 = building.global_transform.basis * dir
			world_dir.y = 0
			_cached_output_dirs.append(world_dir.normalized())

func _physics_process(_delta: float) -> void:
	if not _force_zone:
		return
	# Skip if nothing overlaps (avoids get_overlapping_bodies allocation)
	if _assigned.is_empty():
		var bodies := _force_zone.get_overlapping_bodies()
		if bodies.is_empty():
			return
	if _cached_output_dirs.is_empty():
		return

	for body in _force_zone.get_overlapping_bodies():
		if not (body is PhysicsItem):
			continue
		var item := body as PhysicsItem
		var iid: int = item.get_instance_id()
		if _assigned.has(iid):
			# Already assigned — keep pushing
			var dir: Vector3 = _cached_output_dirs[_assigned[iid] % _cached_output_dirs.size()]
			item.apply_central_force(dir * DEFLECT_FORCE * 0.5)
		else:
			# New item — assign to next output (round-robin)
			var dir_idx: int = _output_rr_idx % _cached_output_dirs.size()
			_output_rr_idx += 1
			_assigned[iid] = dir_idx
			item.apply_central_impulse(_cached_output_dirs[dir_idx] * DEFLECT_FORCE * 0.3)

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
