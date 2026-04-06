extends Node

## Manages item definitions, icons, and visual models.
## Extracted from GameManager to separate item data concerns.

# Cached item definitions: item_id -> ItemDef
var _item_def_cache: Dictionary = {}

# All item defs sorted by category (lazy-loaded)
var _all_item_defs: Array = []

# MultiMesh-based item visual manager (set by game_world)
var item_visual_manager  # ItemVisualManager

# Item icon atlas
var _item_atlas_texture: Texture2D
var _item_icon_cache: Dictionary = {}  # icon_atlas_index -> AtlasTexture
const ITEM_ATLAS_CELL := 16
const ITEM_ATLAS_COLS := 8

# ── Item visuals (3D models) ─────────────────────────────────────────────────

## Acquire an item visual as a 3D model node.
## Accepts either an item_id (StringName/String) or legacy atlas_index (int, ignored).
func acquire_visual(item_id_or_index) -> Node3D:
	var item_id: StringName = &""
	if item_id_or_index is StringName or item_id_or_index is String:
		item_id = StringName(item_id_or_index)
	elif item_id_or_index is int:
		item_id = &"pyromite"  # fallback for legacy int callers
	return item_visual_manager.create_item_visual(item_id)

## Release an item visual (frees the 3D node).
func release_visual(handle) -> void:
	if handle and is_instance_valid(handle) and handle is Node3D:
		handle.queue_free()

## Get a cached ItemDef resource by id. Loads from disk on first access.
func get_item_def(item_id: StringName):
	if _item_def_cache.has(item_id):
		return _item_def_cache[item_id]
	var path := "res://resources/items/%s.tres" % str(item_id)
	if ResourceLoader.exists(path):
		var def = load(path)
		_item_def_cache[item_id] = def
		return def
	return null

func is_valid_item_id(item_id: StringName) -> bool:
	return item_id != &"" and get_item_def(item_id) != null

## Return all ItemDef resources sorted by category then id.
## Scans res://resources/items/ on first call, caches result.
func get_all_item_defs() -> Array:
	if not _all_item_defs.is_empty():
		return _all_item_defs
	var dir := DirAccess.open("res://resources/items/")
	if not dir:
		return []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var item_id := StringName(file_name.get_basename())
			var def = get_item_def(item_id)
			if def and def.id != &"energy":
				_all_item_defs.append(def)
		file_name = dir.get_next()
	dir.list_dir_end()
	_all_item_defs.sort_custom(func(a, b):
		if a.category != b.category:
			return a.category < b.category
		return a.id < b.id
	)
	return _all_item_defs

# ── Item icon atlas ────────────────────────────────────────────────────────────

func get_item_atlas() -> Texture2D:
	if not _item_atlas_texture:
		_item_atlas_texture = load("res://resources/items/sprites/item_atlas.png")
	return _item_atlas_texture

## Get an AtlasTexture for a specific item's icon.
func get_item_icon(item_id: StringName) -> AtlasTexture:
	var def = get_item_def(item_id)
	if not def:
		return null
	var idx: int = def.icon_atlas_index
	if _item_icon_cache.has(idx):
		return _item_icon_cache[idx]
	var atlas := AtlasTexture.new()
	atlas.atlas = get_item_atlas()
	@warning_ignore("integer_division")
	var col: int = idx % ITEM_ATLAS_COLS
	@warning_ignore("integer_division")
	var row: int = idx / ITEM_ATLAS_COLS
	atlas.region = Rect2(col * ITEM_ATLAS_CELL, row * ITEM_ATLAS_CELL, ITEM_ATLAS_CELL, ITEM_ATLAS_CELL)
	atlas.filter_clip = true
	_item_icon_cache[idx] = atlas
	return atlas

func clear() -> void:
	if item_visual_manager:
		item_visual_manager.clear_all()
