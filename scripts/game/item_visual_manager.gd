extends RefCounted

## Manages 3D item model instances for conveyor items and building buffers.
## Each item gets its own Node3D instance from the corresponding .glb model.
## Falls back to a small colored sphere if no model exists.

const ITEM_Y_OFFSET := 0.15

var _parent: Node

func attach_to(parent: Node) -> void:
	_parent = parent

## Create a 3D visual node for an item. Returns the Node3D instance.
func create_item_visual(item_id: StringName) -> Node3D:
	var node := PhysicsItem.create_item_model(item_id)
	node.name = "Item_%s" % str(item_id)
	node.position = Vector3(-9999, -9999, -9999)
	if _parent:
		_parent.add_child(node)
	return node

func clear_all() -> void:
	if _parent:
		for child in _parent.get_children():
			if child.name.begins_with("Item_"):
				child.queue_free()
