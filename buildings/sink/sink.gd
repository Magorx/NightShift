class_name ItemSink
extends BuildingLogic

var items_consumed: int = 0
var _pull_index: int = 0

func configure(_def: BuildingDef, p_grid_pos: Vector2i, _rotation: int) -> void:
	super.configure(_def, p_grid_pos, _rotation)

func _physics_process(_delta: float) -> void:
	# Keep pulling until nothing is ready
	var keep_pulling := true
	while keep_pulling:
		keep_pulling = false
		for i in range(4):
			var dir_idx = (_pull_index + i) % 4
			var result = GameManager.pull_item(grid_pos, dir_idx)
			if not result.is_empty():
				items_consumed += 1
				var item_def = GameManager.get_item_def(result.id)
				var export_val: int = item_def.export_value if item_def else 1
				GameManager.record_delivery(result.id, export_val)
				_pull_index = (dir_idx + 1) % 4
				keep_pulling = true
				break

# ── Pull interface ─────────────────────────────────────────────────────────────

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return true

func can_accept_from(_from_dir_idx: int) -> bool:
	return true

func cleanup_visuals() -> void:
	pass

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	return {"items_consumed": items_consumed}

func deserialize_state(state: Dictionary) -> void:
	if state.has("items_consumed"):
		items_consumed = int(state["items_consumed"])

# ── Info panel ─────────────────────────────────────────────────────────────────

func get_info_stats() -> Array:
	return [
		{type = "stat", text = "Items consumed: %d" % items_consumed},
	]
