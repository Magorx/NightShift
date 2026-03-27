extends RefCounted

## Lightweight proxy that mimics Node2D's .position and .visible API.
## Buildings set handle.position / handle.visible exactly as before,
## but the handle forwards to the shared MultiMesh instead of
## triggering an individual _draw() call.

var _idx: int = -1
var _mgr  # ItemVisualManager
var _pos: Vector2
var _vis: bool = true

func _init(mgr, idx: int) -> void:
	_mgr = mgr
	_idx = idx

var position: Vector2:
	get: return _pos
	set(value):
		_pos = value
		if _vis and _idx >= 0:
			_mgr.set_position(_idx, value)

var visible: bool:
	get: return _vis
	set(value):
		if _vis == value:
			return
		_vis = value
		if _idx < 0:
			return
		if value:
			_mgr.set_position(_idx, _pos)
		else:
			_mgr.hide(_idx)

func release() -> void:
	if _idx >= 0:
		_mgr.release(_idx)
		_idx = -1
