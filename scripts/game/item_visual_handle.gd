extends RefCounted

## Lightweight proxy that wraps a 3D item model Node3D.
## Buildings set handle.position / handle.visible exactly as before.

var _node: Node3D
var _pos: Vector3
var _vis: bool = true

const HIDDEN_POS := Vector3(-9999.0, -9999.0, -9999.0)

func _init(node: Node3D) -> void:
	_node = node

var position: Vector3:
	get: return _pos
	set(value):
		_pos = value
		if _node and _vis:
			_node.position = value

var visible: bool:
	get: return _vis
	set(value):
		if _vis == value:
			return
		_vis = value
		if not _node:
			return
		if value:
			_node.position = _pos
		else:
			_node.position = HIDDEN_POS

func release() -> void:
	if _node and is_instance_valid(_node):
		_node.queue_free()
		_node = null
