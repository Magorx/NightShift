extends Node

## Persistent append-only logger that writes to user://absolute_log.txt.
## Never deletes the file — only appends new lines with timestamps.

var _path: String

func _ready() -> void:
	_path = OS.get_user_data_dir() + "/absolute_log.txt"
	info("Game launched (Godot %s, %s)" % [Engine.get_version_info().string, OS.get_name()])

func _timestamp() -> String:
	return Time.get_datetime_string_from_system(true)

func info(message: String) -> void:
	_append("[%s] %s" % [_timestamp(), message])

func warn(message: String) -> void:
	_append("[%s] WARN: %s" % [_timestamp(), message])
	push_warning(message)

func err(message: String) -> void:
	_append("[%s] ERROR: %s" % [_timestamp(), message])
	push_error(message)

func _append(line: String) -> void:
	if _path.is_empty():
		return
	var f := FileAccess.open(_path, FileAccess.READ_WRITE)
	if not f:
		f = FileAccess.open(_path, FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
