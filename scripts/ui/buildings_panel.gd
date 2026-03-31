extends GameWindow

signal building_selected(id: StringName)

const CATEGORY_DISPLAY_NAMES := {
	"conveyor": "Transportation",
	"splitter": "Transportation",
	"junction": "Transportation",
	"tunnel": "Transportation",
	"extractor": "Extractors",
	"converter": "Converters",
	"sink": "Outputs",
	"source": "Sources",
}

# Categories hidden from the building panel (placed via multi-phase, not directly)
const HIDDEN_CATEGORIES := ["tunnel_output"]

# Preferred display order; categories not listed here are appended alphabetically.
const _PREFERRED_ORDER := ["Transportation", "Extractors", "Converters", "Outputs", "Sources"]

@onready var categories_box: HBoxContainer = %CategoriesBox
@onready var building_list: VBoxContainer = %BuildingList
@onready var info_name: Label = %InfoName
@onready var info_details: Label = %InfoDetails
@onready var info_recipes: VBoxContainer = %InfoRecipes
@onready var hotkey_popup: PanelContainer = %HotkeyPopup
@onready var hotkey_label: Label = %HotkeyLabel

var _awaiting_hotkey_for: StringName = &""
var _active_category: String = ""
var _icon_cache: Dictionary = {}  # building_id -> Texture2D

func serialize_ui_state() -> Dictionary:
	var data := super.serialize_ui_state()
	data["active_category"] = _active_category
	return data

func deserialize_ui_state(data: Dictionary) -> void:
	super.deserialize_ui_state(data)
	var cat: String = data.get("active_category", "")
	if cat != "" and _by_category.has(cat):
		_select_category(cat)
# Buildings grouped by category name
var _by_category: Dictionary = {}

func _ready() -> void:
	super()
	hotkey_popup.visible = false
	_group_buildings()
	_create_category_tabs()
	# Select first category that has buildings
	var order := _get_category_order()
	if order.size() > 0:
		_select_category(order[0])
	_clear_info()
	ResearchManager.research_completed.connect(_on_research_completed)
	SaveManager.load_completed.connect(_on_load_completed)

func _on_load_completed(_success: bool) -> void:
	_refresh_buildings()

func _on_research_completed(_tech_id: StringName) -> void:
	_refresh_buildings()

func _refresh_buildings() -> void:
	_group_buildings()
	_create_category_tabs()
	if _active_category != "" and _by_category.has(_active_category):
		_select_category(_active_category)
	else:
		var order := _get_category_order()
		if order.size() > 0:
			_select_category(order[0])

func _group_buildings() -> void:
	_by_category.clear()
	for id in GameManager.building_defs:
		var def = GameManager.building_defs[id]
		if def.category in HIDDEN_CATEGORIES:
			continue
		if not ResearchManager.is_building_unlocked(id):
			continue
		var cat_name: String = CATEGORY_DISPLAY_NAMES.get(def.category, def.category.capitalize())
		if not _by_category.has(cat_name):
			_by_category[cat_name] = []
		_by_category[cat_name].append(def)

func _get_category_order() -> Array:
	var order: Array = []
	for cat_name in _PREFERRED_ORDER:
		if _by_category.has(cat_name) and cat_name not in order:
			order.append(cat_name)
	# Append any remaining categories alphabetically
	var remaining: Array = []
	for cat_name in _by_category:
		if cat_name not in order:
			remaining.append(cat_name)
	remaining.sort()
	order.append_array(remaining)
	return order

func _create_category_tabs() -> void:
	for child in categories_box.get_children():
		child.queue_free()
	for cat_name in _get_category_order():
		var btn := Button.new()
		btn.text = cat_name
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_category_pressed.bind(cat_name, btn))
		btn.set_meta("category", cat_name)
		categories_box.add_child(btn)

func _on_category_pressed(cat_name: String, btn: Button) -> void:
	_select_category(cat_name)

func _select_category(cat_name: String) -> void:
	_active_category = cat_name
	# Update tab button states
	for child in categories_box.get_children():
		if child is Button:
			child.button_pressed = (child.get_meta("category") == cat_name)
	_populate_building_list()
	_clear_info()

func _populate_building_list() -> void:
	for child in building_list.get_children():
		child.queue_free()

	var defs: Array = _by_category.get(_active_category, [])
	var idx: int = 0
	for def in defs:
		var row := _create_building_row(def, idx)
		building_list.add_child(row)
		idx += 1

func _create_building_row(def, idx: int) -> PanelContainer:
	var panel := PanelContainer.new()
	# Alternating row colors
	var style := StyleBoxFlat.new()
	if idx % 2 == 0:
		style.bg_color = Color(0.18, 0.18, 0.22)
	else:
		style.bg_color = Color(0.22, 0.22, 0.26)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Building sprite icon
	var icon_tex := _get_building_icon(def)
	if icon_tex:
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.custom_minimum_size = Vector2(24, 24)
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tex_rect)
	else:
		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = Vector2(24, 24)
		color_rect.color = def.color
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(color_rect)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(6, 0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	# Name
	var name_label := Label.new()
	name_label.text = def.display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	# Hotkey label
	var hotkey_lbl := Label.new()
	hotkey_lbl.name = "HotkeyLabel"
	var key_str := _get_hotkey_for(def.id)
	hotkey_lbl.text = "[%s]" % key_str if key_str != "" else ""
	hotkey_lbl.add_theme_font_size_override("font_size", 11)
	hotkey_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hotkey_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hotkey_lbl)

	panel.add_child(row)
	panel.set_meta("building_id", def.id)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_row_gui_input.bind(def.id))
	panel.mouse_entered.connect(_on_row_hovered.bind(def))
	panel.mouse_exited.connect(_on_row_unhovered.bind(panel))

	return panel

func _on_row_gui_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var was_building := _is_building_mode()
			building_selected.emit(id)
			# Only close when entering building mode for the first time
			if not was_building:
				visible = false
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_start_hotkey_assignment(id)
			accept_event()

func _on_row_hovered(def) -> void:
	_show_info(def)

func _on_row_unhovered(panel: PanelContainer) -> void:
	# Only clear if mouse isn't over any row
	pass

func _show_info(def) -> void:
	info_name.text = def.display_name

	var shape_size := _get_shape_size(def)
	var details := "Category: %s\nSize: %dx%d" % [def.category.capitalize(), shape_size.x, shape_size.y]
	if def.description != "":
		details += "\n\n%s" % def.description
	var key_str := _get_hotkey_for(def.id)
	if key_str != "":
		details += "\n\nHotkey: [%s]" % key_str
	else:
		details += "\n\nRMB to assign hotkey"
	info_details.text = details

	# Show build cost
	for child in info_recipes.get_children():
		child.queue_free()
	if not def.build_cost.is_empty():
		var header := Label.new()
		header.text = "Build Cost:"
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		info_recipes.add_child(header)
		for stack in def.build_cost:
			var cost_row := HBoxContainer.new()
			cost_row.add_theme_constant_override("separation", 4)
			cost_row.add_child(ItemIcon.create(stack.item.id, Vector2(16, 16)))
			var cost_label := Label.new()
			cost_label.text = "%dx %s" % [stack.quantity, stack.item.display_name]
			cost_label.add_theme_font_size_override("font_size", 11)
			cost_row.add_child(cost_label)
			info_recipes.add_child(cost_row)

func _clear_info() -> void:
	info_name.text = ""
	info_details.text = "Hover a building to see details"
	for child in info_recipes.get_children():
		child.queue_free()

# ── Hotkey Assignment ────────────────────────────────────────────────────────

func _start_hotkey_assignment(id: StringName) -> void:
	_awaiting_hotkey_for = id
	hotkey_popup.visible = true
	hotkey_label.text = "Press a key (0-9, F1-F4)\nfor %s" % str(id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if _awaiting_hotkey_for != &"" and event is InputEventKey and event.pressed:
		var keycode: int = event.physical_keycode
		var valid := (keycode >= KEY_0 and keycode <= KEY_9) or (keycode >= KEY_F1 and keycode <= KEY_F4)
		if valid:
			# Remove any existing binding for this building
			for existing_key in GameManager.building_hotkeys.keys():
				if GameManager.building_hotkeys[existing_key] == _awaiting_hotkey_for:
					GameManager.building_hotkeys.erase(existing_key)
			GameManager.building_hotkeys[keycode] = _awaiting_hotkey_for
			_awaiting_hotkey_for = &""
			hotkey_popup.visible = false
			_refresh_hotkey_labels()
			AccountManager.save_hotkeys()
		get_viewport().set_input_as_handled()

func _refresh_hotkey_labels() -> void:
	for row in building_list.get_children():
		if row is PanelContainer and row.has_meta("building_id"):
			var bid: StringName = row.get_meta("building_id")
			var hotkey_lbl = row.find_child("HotkeyLabel", true, false)
			if hotkey_lbl:
				var key_str := _get_hotkey_for(bid)
				hotkey_lbl.text = "[⌘%s]" % key_str if key_str != "" else ""

func _get_hotkey_for(building_id: StringName) -> String:
	for keycode in GameManager.building_hotkeys:
		if GameManager.building_hotkeys[keycode] == building_id:
			return OS.get_keycode_string(keycode)
	return ""

func _is_building_mode() -> bool:
	var gw = get_tree().root.get_node_or_null("GameWorld")
	if gw:
		var bs = gw.get_node_or_null("BuildSystem")
		if bs:
			return bs.building_mode
	return false

func _get_shape_size(def) -> Vector2i:
	if def.shape.is_empty():
		return Vector2i(1, 1)
	var min_c := Vector2i(999, 999)
	var max_c := Vector2i(-999, -999)
	for cell in def.shape:
		min_c.x = mini(min_c.x, cell.x)
		min_c.y = mini(min_c.y, cell.y)
		max_c.x = maxi(max_c.x, cell.x)
		max_c.y = maxi(max_c.y, cell.y)
	return max_c - min_c + Vector2i(1, 1)

func _get_building_icon(def: BuildingDef) -> Texture2D:
	if _icon_cache.has(def.id):
		return _icon_cache[def.id]
	var tex := _extract_building_icon(def)
	_icon_cache[def.id] = tex
	return tex

func _extract_building_icon(def: BuildingDef) -> Texture2D:
	if not def.scene:
		return null
	var instance := def.scene.instantiate()
	var container := BuildingDef.get_rotatable(instance)

	# Collect bottom and top sprite nodes
	var bottom: AnimatedSprite2D = container.find_child("SpriteBottom", false, false)
	var top: AnimatedSprite2D = container.find_child("SpriteTop", false, false)
	# Fallback: use any AnimatedSprite2D
	if not bottom:
		for child in container.get_children():
			if child is AnimatedSprite2D:
				bottom = child
				break
	if not bottom or not bottom.sprite_frames:
		instance.free()
		return null

	var anim_name := _pick_anim(bottom.sprite_frames)
	if anim_name == &"":
		instance.free()
		return null

	var bottom_tex := bottom.sprite_frames.get_frame_texture(anim_name, 0)
	if not bottom_tex:
		instance.free()
		return null

	# Get bottom image
	var bottom_img := _get_texture_image(bottom_tex)
	if not bottom_img:
		instance.free()
		return bottom_tex

	# Blend top layer if available
	if top and top.sprite_frames:
		var top_anim := _pick_anim(top.sprite_frames)
		if top_anim != &"":
			var top_tex := top.sprite_frames.get_frame_texture(top_anim, 0)
			if top_tex:
				var top_img := _get_texture_image(top_tex)
				if top_img and top_img.get_size() == bottom_img.get_size():
					bottom_img.blend_rect(top_img, Rect2i(Vector2i.ZERO, top_img.get_size()), Vector2i.ZERO)

	instance.free()
	return ImageTexture.create_from_image(bottom_img)

func _pick_anim(frames: SpriteFrames) -> StringName:
	if frames.has_animation(&"idle"):
		return &"idle"
	var anims := frames.get_animation_names()
	if anims.size() > 0:
		return StringName(anims[0])
	return &""

func _get_texture_image(tex: Texture2D) -> Image:
	if tex is AtlasTexture:
		var atlas_tex: AtlasTexture = tex
		var atlas_img: Image = atlas_tex.atlas.get_image()
		if not atlas_img:
			return null
		var region: Rect2 = atlas_tex.region
		return atlas_img.get_region(Rect2i(int(region.position.x), int(region.position.y), int(region.size.x), int(region.size.y)))
	return tex.get_image()
