extends Node

signal active_slot_changed(slot_id: int)

var active_slot: int = 0
var slot_count: int = 3

func _ready() -> void:
	_ensure_save_dirs()
	_load_active_slot()
	load_hotkeys()

func _ensure_save_dirs() -> void:
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	for i in slot_count:
		var slot_path := "saves/slot_%d" % i
		if not dir.dir_exists(slot_path):
			dir.make_dir_recursive(slot_path)

func _load_active_slot() -> void:
	var path := "user://saves/active_slot.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			active_slot = f.get_line().to_int()
			active_slot = clampi(active_slot, 0, slot_count - 1)

func _save_active_slot() -> void:
	var f := FileAccess.open("user://saves/active_slot.txt", FileAccess.WRITE)
	if f:
		f.store_line(str(active_slot))

func get_slot_dir(slot_id: int) -> String:
	return "user://saves/slot_%d/" % slot_id

func set_active_slot(slot_id: int) -> void:
	active_slot = clampi(slot_id, 0, slot_count - 1)
	_save_active_slot()
	load_hotkeys()
	active_slot_changed.emit(active_slot)

func get_all_slots() -> Array:
	var result: Array = []
	for i in slot_count:
		result.append(load_meta(i))
	return result

func load_meta(slot_id: int) -> Dictionary:
	var path := get_slot_dir(slot_id) + "meta.json"
	if not FileAccess.file_exists(path):
		return _default_meta(slot_id)
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return _default_meta(slot_id)
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return _default_meta(slot_id)
	var data: Dictionary = json.data
	data["slot_id"] = slot_id
	return data

func save_meta(slot_id: int, data: Dictionary) -> void:
	_ensure_save_dirs()
	var path := get_slot_dir(slot_id) + "meta.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))

func _default_meta(slot_id: int) -> Dictionary:
	return {
		"version": 1,
		"slot_id": slot_id,
		"player_name": "Player %d" % (slot_id + 1),
		"created_at": "",
		"last_played": "",
		"total_playtime_sec": 0,
	}

func create_slot(slot_id: int, player_name: String) -> void:
	var data := _default_meta(slot_id)
	data["player_name"] = player_name
	data["created_at"] = Time.get_datetime_string_from_system(true)
	save_meta(slot_id, data)

func delete_slot(slot_id: int) -> void:
	var dir_path := get_slot_dir(slot_id)
	var dir := DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()

func rename_slot(slot_id: int, new_name: String) -> void:
	var data := load_meta(slot_id)
	data["player_name"] = new_name
	save_meta(slot_id, data)

func has_run_save(slot_id: int = -1) -> bool:
	if slot_id < 0:
		slot_id = active_slot
	var path := get_slot_dir(slot_id) + "run_autosave.json"
	return FileAccess.file_exists(path)

## Save building hotkeys to the account meta for the given slot.
func save_hotkeys(slot_id: int = -1) -> void:
	if slot_id < 0:
		slot_id = active_slot
	var meta := load_meta(slot_id)
	var hotkeys := {}
	for keycode in GameManager.building_hotkeys:
		hotkeys[str(keycode)] = str(GameManager.building_hotkeys[keycode])
	meta["building_hotkeys"] = hotkeys
	save_meta(slot_id, meta)

## Load building hotkeys from the account meta for the given slot.
func load_hotkeys(slot_id: int = -1) -> void:
	if slot_id < 0:
		slot_id = active_slot
	var meta := load_meta(slot_id)
	GameManager.building_hotkeys.clear()
	if meta.has("building_hotkeys"):
		for keycode_str in meta["building_hotkeys"]:
			GameManager.building_hotkeys[int(keycode_str)] = StringName(meta["building_hotkeys"][keycode_str])
	else:
		GameManager.building_hotkeys = GameManager.DEFAULT_HOTKEYS.duplicate()
