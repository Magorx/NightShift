extends Node
## Persists user settings to user://settings.cfg via ConfigFile.

const SETTINGS_PATH := "user://settings.cfg"

signal pixel_art_changed(enabled: bool)
signal debug_mode_changed(enabled: bool)

var pixel_art_enabled: bool = false:
	set(value):
		if pixel_art_enabled == value:
			return
		pixel_art_enabled = value
		pixel_art_changed.emit(value)
		_save()

var debug_mode: bool = false:
	set(value):
		if debug_mode == value:
			return
		debug_mode = value
		debug_mode_changed.emit(value)
		_save()

func _ready() -> void:
	_load()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	pixel_art_enabled = cfg.get_value("graphics", "pixel_art_enabled", false)
	debug_mode = cfg.get_value("debug", "debug_mode", false)

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # load existing to preserve other sections
	cfg.set_value("graphics", "pixel_art_enabled", pixel_art_enabled)
	cfg.set_value("debug", "debug_mode", debug_mode)
	cfg.save(SETTINGS_PATH)
