class_name ItemSink
extends BuildingLogic
## Debug building: consumes any PhysicsItem that enters its input zone.
## Records deliveries for scoring.

var items_consumed: int = 0

func configure(def: BuildingDef, p_grid_pos: Vector2i, p_rotation: int) -> void:
	super.configure(def, p_grid_pos, p_rotation)

func _physics_process(_delta: float) -> void:
	var inputs_node: Node = get_parent().get_node_or_null("Inputs")
	if not inputs_node:
		return
	for child in inputs_node.get_children():
		if not (child is InputZone):
			continue
		var zone: InputZone = child
		var id: StringName = zone.consume_any()
		while id != &"":
			items_consumed += 1
			var item_def = GameManager.get_item_def(id)
			var export_val: int = item_def.export_value if item_def else 1
			GameManager.record_delivery(id, export_val)
			id = zone.consume_any()

# ── Pull interface stubs ──────────────────────────────────────────────────────

func has_input_from(_cell: Vector2i, _from_dir_idx: int) -> bool:
	return true

func can_accept_from(_from_dir_idx: int) -> bool:
	return true

func get_inventory_items() -> Array:
	return []

# ── Serialization ──────────────────────────────────────────────────────────────

func serialize_state() -> Dictionary:
	return {"items_consumed": items_consumed}

func deserialize_state(state: Dictionary) -> void:
	if state.has("items_consumed"):
		items_consumed = int(state["items_consumed"])

func get_info_stats() -> Array:
	return [
		{type = "stat", text = "Items delivered: %d" % items_consumed},
	]
