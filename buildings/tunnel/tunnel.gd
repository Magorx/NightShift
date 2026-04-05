class_name TunnelLogic
extends UndergroundTransportLogic
## Physics tunnel: items entering the input end are teleported to the
## paired output end. Overrides the buffer-based transport with instant
## item teleportation via PhysicsItem spawn.

func _is_input_category(category: String) -> bool:
	return category == "tunnel"

func _physics_process(_delta: float) -> void:
	if not is_input or not partner:
		return
	_consume_and_teleport()

func _consume_and_teleport() -> void:
	var inputs_node: Node = get_parent().get_node_or_null("Inputs")
	if not inputs_node:
		return
	for child in inputs_node.get_children():
		if not (child is InputZone):
			continue
		var zone: InputZone = child
		var id: StringName = zone.consume_any()
		while id != &"":
			_teleport_to_output(id)
			id = zone.consume_any()

func _teleport_to_output(item_id: StringName) -> void:
	var output_zone: OutputZone = _get_partner_output()
	if output_zone:
		output_zone.spawn_item(item_id)

func _get_partner_output() -> OutputZone:
	if not partner:
		return null
	var outputs: Node = partner.get_parent().get_node_or_null("Outputs")
	if outputs and outputs.get_child_count() > 0:
		return outputs.get_child(0) as OutputZone
	return null
