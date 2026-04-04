class_name BuildSystem
extends Node2D

signal building_clicked(building: Node)
signal ground_inspected(grid_pos: Vector2i)

const GHOST_MODULATE := Color(0.8, 0.9, 1.0, 0.55)
const GHOST_INVALID_MODULATE := Color(1.0, 0.5, 0.5, 0.45)
const DESTROY_AREA_COLOR := Color(1.0, 0.2, 0.2, 0.15)
const DESTROY_CURSOR_COLOR := Color(1.0, 0.2, 0.2, 0.25)
const DESTROY_OUTLINE_COLOR := Color(1.0, 0.2, 0.15, 0.85)
const PHASE_AREA_COLOR := Color(0.3, 0.7, 1.0, 0.12)
const PHASE_AREA_OUTLINE_COLOR := Color(0.3, 0.7, 1.0, 0.35)
const SELECT_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const OUTLINE_WIDTH := 2.0
const GHOST_POOL_MAX := 64
const GHOST_POOL_BASELINE := 4


var _destroy_shader: Shader = preload("res://buildings/shared/destroy_highlight.gdshader")

var cursor_grid_pos := Vector2i.ZERO
var selected_building: StringName = &"conveyor"
var current_rotation: int = 0 # 0=right, 1=down, 2=left, 3=up
var rotation_locked: bool = false # when true, drag doesn't auto-set rotation

# Building mode: when false, player is in inspect mode
var building_mode: bool = false

# Destroy mode
var destroy_mode: bool = false
var _destroy_dragging: bool = false
var _destroy_drag_start := Vector2i.ZERO
# Shader highlight tracking: instance_id -> Array of {node, original}
var _highlighted_buildings: Dictionary = {}

# Selection highlight (info panel)
var _selected_building: Node = null
var _select_highlighted: Dictionary = {} # instance_id -> Array of {node, original}


# Drag state (build mode)
var _dragging: bool = false
var _drag_start_pos := Vector2i.ZERO
var _drag_axis: int = -1 # -1=undecided, 0=horizontal, 1=vertical
var _drag_rotation: int = 0
var _blueprints: Array = [] # Array of Vector2i positions (all candidates)
var _placeable_blueprints: Array = [] # subset that don't overlap each other

# Multi-phase placement state (for buildings like tunnels that need 2+ clicks)
var _phase_index: int = -1 # -1 = normal single-phase, 0+ = current phase
var _phase_config: Dictionary = {} # placement_phases entry for current building
var _phase_placements: Array = [] # Array of Arrays of {pos: Vector2i, rotation: int}

# Ghost preview (instantiated building scenes shown under cursor)
var _ghost_nodes: Array = []
var _ghost_building_id: StringName = &""
var _ghost_rotation: int = -1
var _was_drawing: bool = false

func _process(_delta: float) -> void:
	var prev_grid_pos := cursor_grid_pos
	cursor_grid_pos = _get_grid_pos_under_mouse()
	if _dragging:
		_update_blueprints()
	if _selected_building and not is_instance_valid(_selected_building):
		clear_select_highlight()
	_update_select_highlight_uvs()
	if destroy_mode:
		_update_destroy_highlights()
	elif not _highlighted_buildings.is_empty():
		_clear_all_highlights()
	_update_ghosts()
	# Only redraw when there's something to draw and cursor moved
	var needs_draw := destroy_mode or (_phase_index > 0 and not _phase_placements.is_empty())
	if needs_draw or _was_drawing:
		queue_redraw()
	_was_drawing = needs_draw

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if building_mode:
				if event.pressed:
					_start_drag(cursor_grid_pos)
				else:
					_commit_drag()
			elif destroy_mode:
				if event.pressed:
					_destroy_dragging = true
					_destroy_drag_start = cursor_grid_pos
				else:
					_commit_destroy()
			else:
				# Inspect mode
				if event.pressed:
					_try_inspect(cursor_grid_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if building_mode:
				if _phase_index > 0:
					# In a later phase — cancel everything (remove prior placements)
					if _dragging:
						_cancel_drag()
					_cancel_multiphase()
					exit_building_mode()
				elif _dragging:
					_cancel_drag()
				else:
					exit_building_mode()
			elif destroy_mode:
				if _destroy_dragging:
					_destroy_dragging = false
				else:
					exit_destroy_mode()
			else:
				# Inspect mode RMB: pick building under cursor
				_try_pick_building(cursor_grid_pos)
	elif event.is_action_pressed(&"rotate_building"):
		if building_mode:
			current_rotation = (current_rotation + 1) % 4
			if _dragging:
				_drag_rotation = current_rotation
	elif event.is_action_pressed(&"destroy_mode_toggle"):
		if destroy_mode:
			exit_destroy_mode()
		else:
			enter_destroy_mode()
	elif event.is_action_pressed(&"lock_rotation"):
		rotation_locked = not rotation_locked
	elif event.is_action_pressed(&"debug_spawn_item"):
		_debug_spawn_item(cursor_grid_pos)
	elif event.is_action_pressed(&"build_mode_toggle"):
		if building_mode:
			exit_building_mode()
		else:
			if destroy_mode:
				exit_destroy_mode()
			enter_building_mode(GameManager.last_selected_building)

# ── Mode management ──────────────────────────────────────────────────────────

func enter_building_mode(building_id: StringName) -> void:
	if destroy_mode:
		exit_destroy_mode()
	clear_select_highlight()
	_cancel_multiphase()
	selected_building = building_id
	building_mode = true
	GameManager.last_selected_building = building_id
	# Check for multi-phase placement config
	if GameManager.placement_phases.has(building_id):
		_phase_config = GameManager.placement_phases[building_id]
		_phase_index = 0
		_phase_placements.clear()
		selected_building = _phase_config.phases[0].building_id
	else:
		_phase_index = -1
		_phase_config = {}

func exit_building_mode() -> void:
	building_mode = false
	if _dragging:
		_cancel_drag()
	_cancel_multiphase()
	_clear_ghosts()

func enter_destroy_mode() -> void:
	if building_mode:
		exit_building_mode()
	clear_select_highlight()
	destroy_mode = true

func exit_destroy_mode() -> void:
	destroy_mode = false
	_destroy_dragging = false
	_clear_all_highlights()

func select_building(id: StringName) -> void:
	enter_building_mode(id)

# ── Inspect ──────────────────────────────────────────────────────────────────

func _try_inspect(pos: Vector2i) -> void:
	var building = GameManager.get_building_at(pos)
	if building and is_instance_valid(building):
		_set_select_highlight(building)
		building_clicked.emit(building)
	else:
		# Clicked empty space — dismiss info panel
		clear_select_highlight()
		building_clicked.emit(null)

func _try_pick_building(pos: Vector2i) -> void:
	var building = GameManager.get_building_at(pos)
	if building and is_instance_valid(building):
		var bid: StringName = building.building_id
		if bid != &"" and GameManager.building_defs.has(bid):
			enter_building_mode(bid)
			return
	# No building — show ground info instead
	ground_inspected.emit(pos)

func _try_ground_info(pos: Vector2i) -> void:
	var building = GameManager.get_building_at(pos)
	if building and is_instance_valid(building):
		return  # Building here — RMB doesn't show ground info
	ground_inspected.emit(pos)

# ── Build drag ───────────────────────────────────────────────────────────────

func _start_drag(pos: Vector2i) -> void:
	_dragging = true
	_drag_start_pos = pos
	_drag_axis = -1
	_drag_rotation = current_rotation
	_blueprints = [pos]

func _cancel_drag() -> void:
	_dragging = false
	_drag_axis = -1
	_blueprints.clear()
	_placeable_blueprints.clear()
	_trim_ghosts()

func _commit_drag() -> void:
	if not _dragging:
		return
	if _phase_index >= 0:
		_commit_phase_drag()
		return
	# Place only non-overlapping blueprints that pass validation, are in range, and are affordable
	var placed_any := false
	for pos in _placeable_blueprints:
		if not GameManager.can_afford_building(selected_building):
			break
		if GameManager.can_place_building(selected_building, pos, GameManager.map_size, _drag_rotation):
			GameManager.place_building(selected_building, pos, _drag_rotation)
			placed_any = true
	# Show failure reason on single-click (not drag) when nothing was placed
	if not placed_any and _blueprints.size() == 1:
		var reason := _get_placement_fail_reason(selected_building, _blueprints[0], _drag_rotation)
		if not reason.is_empty():
			_show_floating_text(reason)
	_dragging = false
	_drag_axis = -1
	_blueprints.clear()
	_placeable_blueprints.clear()
	_trim_ghosts()
	# Keep the drag rotation as the current rotation for convenience
	current_rotation = _drag_rotation

# ── Multi-phase placement ─────────────────────────────────────────────────

func _commit_phase_drag() -> void:
	var phase_def: Dictionary = _phase_config.phases[_phase_index]
	var bid: StringName = phase_def.building_id
	var placed: Array = []

	for pos in _placeable_blueprints:
		if not GameManager.can_afford_building(bid):
			break
		if _can_place_phase(pos, _drag_rotation, placed.size()):
			GameManager.place_building(bid, pos, _drag_rotation)
			placed.append({pos = pos, rotation = _drag_rotation})

	_dragging = false
	_drag_axis = -1
	_blueprints.clear()
	_placeable_blueprints.clear()
	_trim_ghosts()
	current_rotation = _drag_rotation

	if placed.is_empty():
		# Show failure reason on single-click when nothing was placed
		if _blueprints.size() == 1:
			var phase_bid: StringName = _phase_config.phases[_phase_index].building_id
			var reason := _get_placement_fail_reason(phase_bid, _blueprints[0], _drag_rotation)
			if not reason.is_empty():
				_show_floating_text(reason)
		return

	_phase_placements.append(placed)
	_phase_index += 1

	if _phase_index >= _phase_config.phases.size():
		_complete_multiphase()
	else:
		# Advance to next phase's building
		selected_building = _phase_config.phases[_phase_index].building_id

## Check if a building can be placed in the current phase at pos with index.
func _can_place_phase(pos: Vector2i, rot: int, index: int) -> bool:
	var phase_def: Dictionary = _phase_config.phases[_phase_index]
	var bid: StringName = phase_def.building_id
	if not GameManager.can_place_building(bid, pos, GameManager.map_size, rot):
		return false
	if _phase_index == 0:
		return true
	var prev_placements: Array = _phase_placements[_phase_placements.size() - 1]
	# Count match: don't allow more placements than prior phase
	if phase_def.get("count_match", false):
		if index >= prev_placements.size():
			return false
	# Max distance: check against corresponding prior placement
	var max_dist: int = phase_def.get("max_distance", 0)
	if max_dist > 0 and index < prev_placements.size():
		var prev_pos: Vector2i = prev_placements[index].pos
		var dist := absi(pos.x - prev_pos.x) + absi(pos.y - prev_pos.y)
		if dist > max_dist:
			return false
	return true

func _complete_multiphase() -> void:
	if _phase_config.has("link_fn"):
		GameManager.call(_phase_config.link_fn, _phase_placements)
	# Restart at phase 0 so the player can keep building more of the same
	_phase_index = 0
	_phase_placements.clear()
	selected_building = _phase_config.phases[0].building_id

## Cancel multi-phase placement, removing buildings placed in prior phases.
func _cancel_multiphase() -> void:
	if _phase_index <= 0:
		_phase_index = -1
		_phase_config = {}
		_phase_placements.clear()
		return
	for phase_placed in _phase_placements:
		for entry in phase_placed:
			GameManager.remove_building(entry.pos)
	_phase_index = -1
	_phase_config = {}
	_phase_placements.clear()

func _update_blueprints() -> void:
	var raw_pos := _get_grid_pos_under_mouse()

	# Determine axis once mouse moves to a different tile
	if _drag_axis == -1:
		if raw_pos != _drag_start_pos:
			var diff := raw_pos - _drag_start_pos
			if abs(diff.x) >= abs(diff.y):
				_drag_axis = 0
				if not rotation_locked:
					_drag_rotation = 0 if diff.x > 0 else 2
			else:
				_drag_axis = 1
				if not rotation_locked:
					_drag_rotation = 1 if diff.y > 0 else 3

	# Build the line of positions from start to cursor, locked to axis
	var end_pos := raw_pos
	if _drag_axis == 0:
		end_pos.y = _drag_start_pos.y
	elif _drag_axis == 1:
		end_pos.x = _drag_start_pos.x

	cursor_grid_pos = end_pos

	# Generate positions along the line
	_blueprints.clear()
	if _drag_axis == -1:
		# Still undecided — just the start tile
		_blueprints = [_drag_start_pos]
		_drag_rotation = current_rotation
		_filter_placeable_blueprints()
		return

	var start := _drag_start_pos
	var step: Vector2i
	var count: int
	if _drag_axis == 0:
		var dx := end_pos.x - start.x
		step = Vector2i(signi(dx), 0)
		count = absi(dx) + 1
	else:
		var dy := end_pos.y - start.y
		step = Vector2i(0, signi(dy))
		count = absi(dy) + 1

	for i in range(count):
		_blueprints.append(start + step * i)

	_filter_placeable_blueprints()

	# If only one blueprint is visible, unlock axis so direction can change
	if _placeable_blueprints.size() <= 1:
		_drag_axis = -1
		_blueprints = [_drag_start_pos]
		current_rotation = _drag_rotation
		_filter_placeable_blueprints()

## Filter blueprints to only include those that don't overlap earlier ones.
func _filter_placeable_blueprints() -> void:
	_placeable_blueprints.clear()
	var def = GameManager.get_building_def(selected_building)
	if not def:
		return
	var rotated_shape = def.get_rotated_shape(_drag_rotation)
	var claimed_cells: Dictionary = {} # Vector2i -> true
	# Multi-phase count limit: don't show more blueprints than prior phase placed
	var max_count := 999999
	if _phase_index > 0:
		var phase_def: Dictionary = _phase_config.phases[_phase_index]
		if phase_def.get("count_match", false) and _phase_placements.size() > 0:
			max_count = _phase_placements[_phase_placements.size() - 1].size()
	for pos in _blueprints:
		if _placeable_blueprints.size() >= max_count:
			break
		# Check if any cell of this blueprint overlaps a cell claimed by a prior blueprint
		var overlaps := false
		var cells: Array = []
		for cell in rotated_shape:
			var world_cell: Vector2i = pos + cell
			cells.append(world_cell)
			if claimed_cells.has(world_cell):
				overlaps = true
				break
		if not overlaps:
			_placeable_blueprints.append(pos)
			for c in cells:
				claimed_cells[c] = true

# ── Ghost preview ─────────────────────────────────────────────────────────────

func _create_ghost_node(building_id: StringName, rotation: int) -> Node2D:
	var def = GameManager.get_building_def(building_id)
	if not def or not def.scene:
		return null
	var ghost: Node2D = def.scene.instantiate()
	# Hide direction arrow
	var arrow = ghost.find_child("Arrow", true, false)
	if arrow:
		arrow.visible = false
	add_child(ghost)
	# Disable processing after add_child to override any _ready re-enables
	_disable_processing_recursive(ghost)
	# Apply all visual rotation after add_child so _ready defaults are overridden
	def.apply_rotation(ghost, rotation)
	return ghost

func _disable_processing_recursive(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_disable_processing_recursive(child)

func _update_ghosts() -> void:
	if not building_mode:
		if not _ghost_nodes.is_empty():
			_clear_ghosts()
		return

	var rotation := _drag_rotation if _dragging else current_rotation
	var def = GameManager.get_building_def(selected_building)
	if not def:
		_clear_ghosts()
		return

	# Rebuild ghosts if building or rotation changed
	if selected_building != _ghost_building_id or rotation != _ghost_rotation:
		_clear_ghosts()
		_ghost_building_id = selected_building
		_ghost_rotation = rotation

	var can_afford := GameManager.can_afford_building(selected_building)

	if _dragging:
		var count := _placeable_blueprints.size()
		# Grow pool as needed (capped)
		while _ghost_nodes.size() < count and _ghost_nodes.size() < GHOST_POOL_MAX:
			var ghost = _create_ghost_node(selected_building, rotation)
			if ghost:
				_ghost_nodes.append(ghost)
			else:
				break
		# Position and tint active ghosts
		for i in range(mini(count, _ghost_nodes.size())):
			var pos: Vector2i = _placeable_blueprints[i]
			var can_place: bool
			if _phase_index >= 0:
				can_place = _can_place_phase(pos, _drag_rotation, i)
			else:
				can_place = GameManager.can_place_building(selected_building, pos, GameManager.map_size, _drag_rotation)
			can_place = can_place and can_afford
			var world_3d := GridUtils.grid_to_world(pos - def.anchor_cell)
			_ghost_nodes[i].position = Vector2(world_3d.x, world_3d.z)
			_ghost_nodes[i].modulate = GHOST_MODULATE if can_place else GHOST_INVALID_MODULATE
			_ghost_nodes[i].visible = true
			_update_ghost_conveyor_variant(_ghost_nodes[i], pos, rotation, _placeable_blueprints)
		# Hide excess
		for i in range(count, _ghost_nodes.size()):
			_ghost_nodes[i].visible = false
	else:
		# Single cursor ghost
		if _ghost_nodes.is_empty():
			var ghost = _create_ghost_node(selected_building, rotation)
			if ghost:
				_ghost_nodes.append(ghost)
		if not _ghost_nodes.is_empty():
			var can_place: bool
			if _phase_index >= 0:
				can_place = _can_place_phase(cursor_grid_pos, current_rotation, 0)
			else:
				can_place = GameManager.can_place_building(selected_building, cursor_grid_pos, GameManager.map_size, current_rotation)
			can_place = can_place and can_afford
			var world_3d := GridUtils.grid_to_world(cursor_grid_pos - def.anchor_cell)
			_ghost_nodes[0].position = Vector2(world_3d.x, world_3d.z)
			_ghost_nodes[0].modulate = GHOST_MODULATE if can_place else GHOST_INVALID_MODULATE
			_ghost_nodes[0].visible = true
			_update_ghost_conveyor_variant(_ghost_nodes[0], cursor_grid_pos, rotation, [])
			for i in range(1, _ghost_nodes.size()):
				_ghost_nodes[i].visible = false

## Trim ghost pool back to baseline, freeing excess nodes.
func _trim_ghosts() -> void:
	while _ghost_nodes.size() > GHOST_POOL_BASELINE:
		var ghost = _ghost_nodes.pop_back()
		if is_instance_valid(ghost):
			ghost.queue_free()

func _update_ghost_conveyor_variant(ghost: Node2D, grid_pos: Vector2i, rot: int, blueprint_positions: Array) -> void:
	if selected_building != &"conveyor":
		return
	var sprite = ghost.find_child("ConveyorSprite", true, false)
	if not sprite or not (sprite is AnimatedSprite2D):
		return

	var dir_vec: Vector2i = GameManager.DIRECTION_VECTORS[rot]
	var back := -dir_vec
	var right_side := Vector2i(-dir_vec.y, dir_vec.x)
	var left_side := Vector2i(dir_vec.y, -dir_vec.x)

	var has_back: bool = _ghost_has_feeder(grid_pos, back, blueprint_positions, rot)
	var has_right: bool = _ghost_has_feeder(grid_pos, right_side, blueprint_positions, rot)
	var has_left: bool = _ghost_has_feeder(grid_pos, left_side, blueprint_positions, rot)

	var variant: StringName = &"start"
	var flip := false

	if has_right and has_left and has_back:
		variant = &"crossroad"
	elif has_right and has_left:
		variant = &"dual_side_input"
	elif has_back and has_right:
		variant = &"side_input"
	elif has_back and has_left:
		variant = &"side_input"
		flip = true
	elif has_right and not has_back:
		variant = &"turn"
	elif has_left and not has_back:
		variant = &"turn"
		flip = true
	elif has_back:
		variant = &"straight"

	sprite.animation = variant
	sprite.flip_v = flip

func _ghost_has_feeder(grid_pos: Vector2i, dir_offset: Vector2i, blueprint_positions: Array, drag_rotation: int) -> bool:
	# Check existing buildings
	var dir_idx: int
	if dir_offset == Vector2i.RIGHT: dir_idx = 0
	elif dir_offset == Vector2i.DOWN: dir_idx = 1
	elif dir_offset == Vector2i.LEFT: dir_idx = 2
	elif dir_offset == Vector2i.UP: dir_idx = 3
	else: return false

	if GameManager.has_output_at(grid_pos, dir_idx):
		return true

	# Check if another blueprint in the drag would feed this position
	var neighbor_pos := grid_pos + dir_offset
	if neighbor_pos in blueprint_positions:
		var neighbor_output: Vector2i = neighbor_pos + Vector2i(GameManager.DIRECTION_VECTORS[drag_rotation])
		if neighbor_output == grid_pos:
			return true

	return false

func _clear_ghosts() -> void:
	for ghost in _ghost_nodes:
		if is_instance_valid(ghost):
			ghost.queue_free()
	_ghost_nodes.clear()
	_ghost_building_id = &""
	_ghost_rotation = -1

# ── Destroy ──────────────────────────────────────────────────────────────────

func _commit_destroy() -> void:
	if not _destroy_dragging:
		return

	var min_pos := Vector2i(
		mini(_destroy_drag_start.x, cursor_grid_pos.x),
		mini(_destroy_drag_start.y, cursor_grid_pos.y))
	var max_pos := Vector2i(
		maxi(_destroy_drag_start.x, cursor_grid_pos.x),
		maxi(_destroy_drag_start.y, cursor_grid_pos.y))

	# Collect unique buildings in the area (within range), including linked buildings
	var to_remove: Array = []
	var seen: Dictionary = {}
	for x in range(min_pos.x, max_pos.x + 1):
		for y in range(min_pos.y, max_pos.y + 1):
			var pos := Vector2i(x, y)
			var building = GameManager.get_building_at(pos)
			if building and is_instance_valid(building):
				_collect_building_and_linked(building, seen, to_remove)

	_clear_all_highlights()

	for pos in to_remove:
		GameManager.remove_building(pos)

	_destroy_dragging = false

# ── Destroy shader highlights ────────────────────────────────────────────────

func _update_destroy_highlights() -> void:
	# Compute which buildings should be highlighted
	var new_set: Dictionary = {} # instance_id -> Node2D
	if _destroy_dragging:
		var min_pos := Vector2i(
			mini(_destroy_drag_start.x, cursor_grid_pos.x),
			mini(_destroy_drag_start.y, cursor_grid_pos.y))
		var max_pos := Vector2i(
			maxi(_destroy_drag_start.x, cursor_grid_pos.x),
			maxi(_destroy_drag_start.y, cursor_grid_pos.y))
		for x in range(min_pos.x, max_pos.x + 1):
			for y in range(min_pos.y, max_pos.y + 1):
				var building = GameManager.get_building_at(Vector2i(x, y))
				if building and is_instance_valid(building):
					new_set[building.get_instance_id()] = building
	else:
		var building = GameManager.get_building_at(cursor_grid_pos)
		if building and is_instance_valid(building):
			new_set[building.get_instance_id()] = building

	# Expand to include linked buildings (e.g. tunnel partners)
	var expanded: Dictionary = {}
	for nid in new_set:
		for bld in GameManager.get_building_group(new_set[nid]):
			expanded[bld.get_instance_id()] = bld
	for nid in expanded:
		if not new_set.has(nid):
			new_set[nid] = expanded[nid]

	# Remove highlights no longer needed
	for nid in _highlighted_buildings.keys():
		if not new_set.has(nid):
			_remove_highlight(nid)

	# Add new highlights
	for nid in new_set:
		if not _highlighted_buildings.has(nid):
			_apply_highlight(new_set[nid])

	# Update frame UV bounds for animated sprites (frame changes each tick)
	for nid in _highlighted_buildings:
		var entries: Array = _highlighted_buildings[nid].entries
		for entry in entries:
			if is_instance_valid(entry.node) and entry.node is AnimatedSprite2D:
				var bounds := _get_frame_uv_bounds(entry.node)
				entry.node.material.set_shader_parameter("frame_uv_min", bounds.position)
				entry.node.material.set_shader_parameter("frame_uv_max", bounds.position + bounds.size)

func _apply_highlight(building: Node) -> void:
	# Conveyors use MultiMesh rendering — highlight via the visual manager
	if building.logic is ConveyorBelt and GameManager.conveyor_visual_manager:
		GameManager.conveyor_visual_manager.set_highlight(building.logic.grid_pos, true)
		_highlighted_buildings[building.get_instance_id()] = {entries = [], building = building}
		return
	var entries: Array = []
	for node in _get_visual_nodes(building):
		var orig = node.material
		var mat := ShaderMaterial.new()
		mat.shader = _destroy_shader
		mat.set_shader_parameter("enabled", true)
		mat.set_shader_parameter("darken", 0.3)
		var bounds := _get_frame_uv_bounds(node)
		mat.set_shader_parameter("frame_uv_min", bounds.position)
		mat.set_shader_parameter("frame_uv_max", bounds.position + bounds.size)
		node.material = mat
		entries.append({node = node, original = orig})
	_highlighted_buildings[building.get_instance_id()] = {entries = entries, building = building}

## Get the UV bounds of the current frame within the atlas texture.
func _get_frame_uv_bounds(node: CanvasItem) -> Rect2:
	if node is AnimatedSprite2D:
		var frame_tex = node.sprite_frames.get_frame_texture(node.animation, node.frame)
		if frame_tex is AtlasTexture:
			var atlas_size: Vector2 = frame_tex.atlas.get_size()
			var region: Rect2 = frame_tex.region
			return Rect2(region.position / atlas_size, region.size / atlas_size)
	elif node is Sprite2D and node.region_enabled:
		var tex_size: Vector2 = node.texture.get_size()
		return Rect2(node.region_rect.position / tex_size, node.region_rect.size / tex_size)
	return Rect2(0, 0, 1, 1)

func _remove_highlight(nid: int) -> void:
	if not _highlighted_buildings.has(nid):
		return
	var data: Dictionary = _highlighted_buildings[nid]
	var entries: Array = data.entries
	for entry in entries:
		if is_instance_valid(entry.node):
			entry.node.material = entry.original
	if is_instance_valid(data.building):
		# Clear conveyor multimesh highlight
		if data.building.logic is ConveyorBelt and GameManager.conveyor_visual_manager:
			GameManager.conveyor_visual_manager.set_highlight(data.building.logic.grid_pos, false)
	_highlighted_buildings.erase(nid)

func _clear_all_highlights() -> void:
	for nid in _highlighted_buildings.keys():
		_remove_highlight(nid)

# ── Selection highlight (info panel) ─────────────────────────────────────────

func _set_select_highlight(building: Node) -> void:
	if _selected_building == building:
		return
	clear_select_highlight()
	_selected_building = building
	for bld in GameManager.get_building_group(building):
		var entries: Array = []
		for node in _get_visual_nodes(bld):
			var orig = node.material
			var mat := ShaderMaterial.new()
			mat.shader = _destroy_shader
			mat.set_shader_parameter("enabled", true)
			mat.set_shader_parameter("outline_color", SELECT_OUTLINE_COLOR)
			mat.set_shader_parameter("stripe_color", Color(0, 0, 0, 0))
			var bounds := _get_frame_uv_bounds(node)
			mat.set_shader_parameter("frame_uv_min", bounds.position)
			mat.set_shader_parameter("frame_uv_max", bounds.position + bounds.size)
			node.material = mat
			entries.append({node = node, original = orig})
		_select_highlighted[bld.get_instance_id()] = entries

func _update_select_highlight_uvs() -> void:
	for nid in _select_highlighted:
		var entries: Array = _select_highlighted[nid]
		for entry in entries:
			if is_instance_valid(entry.node) and entry.node is AnimatedSprite2D:
				var bounds := _get_frame_uv_bounds(entry.node)
				entry.node.material.set_shader_parameter("frame_uv_min", bounds.position)
				entry.node.material.set_shader_parameter("frame_uv_max", bounds.position + bounds.size)

func clear_select_highlight() -> void:
	for nid in _select_highlighted.keys():
		var entries: Array = _select_highlighted[nid]
		for entry in entries:
			if is_instance_valid(entry.node):
				entry.node.material = entry.original
	_select_highlighted.clear()
	_selected_building = null

## Find visual children of a building to apply the destroy shader to.
func _get_visual_nodes(building: Node) -> Array:
	var result: Array = []
	var rotatable = building.find_child("Rotatable", false, false)
	var container = rotatable if rotatable else building
	# Shape ColorRects
	var shape_node = container.find_child("Shape", false, false)
	if shape_node:
		for child in shape_node.get_children():
			if child is ColorRect:
				result.append(child)
	# Sprite2D and AnimatedSprite2D inside Rotatable
	for child in container.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			result.append(child)
	return result

# ── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	# TODO 3D.11: Rewrite overlays for 3D (ImmediateMesh or CanvasLayer projection).
	# The 2D _draw() calls (draw_colored_polygon, draw_line) don't render correctly
	# in the 3D scene. Stubbed until the grid overlay card.
	pass

## Get the grid cells occupied by a building, using its BuildingDef shape.
func _get_building_visual_cells(building: Node) -> Array:
	var cells: Array = []
	var def = GameManager.get_building_def(building.building_id)
	if def:
		for cell in def.get_rotated_shape(building.rotation_index):
			cells.append(building.grid_pos + cell)
	else:
		cells.append(building.grid_pos)
	return cells

# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_grid_pos_under_mouse() -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Vector2i.ZERO
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	# Intersect with Y=0 ground plane
	if absf(ray_dir.y) < 0.0001:
		return Vector2i.ZERO
	var t := -ray_origin.y / ray_dir.y
	var hit := ray_origin + ray_dir * t
	return GridUtils.world_to_grid(hit)

func _try_remove(pos: Vector2i) -> void:
	GameManager.remove_building(pos)

## Collect a building and all its linked buildings into to_remove, deduplicating by instance id.
func _collect_building_and_linked(building: Node, seen: Dictionary, to_remove: Array) -> void:
	for bld in GameManager.get_building_group(building):
		var nid: int = bld.get_instance_id()
		if seen.has(nid):
			continue
		seen[nid] = true
		to_remove.append(bld.grid_pos)

func _debug_spawn_item(pos: Vector2i) -> void:
	var conv = GameManager.get_conveyor_at(pos)
	if conv and conv.can_accept():
		conv.place_item(&"pyromite")

# ── Placement fail reason ───────────────────────────────────────────────────

func _get_placement_fail_reason(id: StringName, grid_pos: Vector2i, rotation: int) -> String:
	if not GameManager.can_afford_building(id):
		return "Not enough resources"
	var def = GameManager.get_building_def(id)
	if not def:
		return ""
	var rotated_shape: Array = def.get_rotated_shape(rotation)
	for cell in rotated_shape:
		var check_pos: Vector2i = grid_pos + Vector2i(cell)
		if check_pos.x < 0 or check_pos.y < 0 or check_pos.x >= GameManager.map_size or check_pos.y >= GameManager.map_size:
			return "Out of bounds"
		if GameManager.walls.has(check_pos):
			return "Blocked by terrain"
		if GameManager.buildings.has(check_pos):
			return "Space is occupied"
	var building_error: String = def.get_placement_error(grid_pos, rotation)
	if building_error != "":
		return building_error
	return ""

# ── Floating text ───────────────────────────────────────────────────────────

func _show_floating_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size.x = 250
	label.size.x = 250
	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ui_layer: CanvasLayer = get_parent().get_node("UI")
	ui_layer.add_child(label)

	var screen_pos: Vector2 = get_viewport().get_mouse_position()
	var start_y: float = screen_pos.y - 30
	label.position = Vector2(screen_pos.x - 125, start_y)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", start_y - 40, 2.0).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_IN).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)

