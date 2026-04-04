extends RefCounted

## Lightweight proxy that mimics a spatial node's .position and .visible API.
## Buildings set handle.position / handle.visible exactly as before,
## but the handle forwards to the shared MultiMesh instead of
## triggering an individual draw call.
##
## Position is Vector3 (XZ ground plane). Buildings use grid_to_center_3d()
## and grid_offset_3d() which return Vector3.

var _idx: int = -1
var _mgr  # ItemVisualManager
var _pos: Vector3
var _vis: bool = true

func _init(mgr, idx: int) -> void:
	_mgr = mgr
	_idx = idx

var position: Vector3:
	get: return _pos
	set(value):
		_pos = value
		if _vis and _idx >= 0:
			_mgr.set_position_3d(_idx, value)

var visible: bool:
	get: return _vis
	set(value):
		if _vis == value:
			return
		_vis = value
		if _idx < 0:
			return
		if value:
			_mgr.set_position_3d(_idx, _pos)
		else:
			_mgr.hide(_idx)

func release() -> void:
	if _idx >= 0:
		_mgr.release(_idx)
		_idx = -1
