class_name Player
extends CharacterBody2D

signal item_mined(item_id: StringName)

const TILE_SIZE := 32

# ── Movement ─────────────────────────────────────────────────────────────────
const BASE_SPEED := 96.0        # 3 tiles/s at 32px/tile
const SPRINT_SPEED := 160.0     # 5 tiles/s
const ACCELERATION := 640.0     # 20 tiles/s^2
const FRICTION := 480.0         # 15 tiles/s^2
const STAMINA_MAX := 3.0        # seconds of sprint
const STAMINA_REGEN := 1.0      # seconds recovered per second

# ── Vertical physics ─────────────────────────────────────────────────────────
const JUMP_SPEED := 8.0          # height-units/s upward
const JUMP_GRAVITY := 22.0       # height-units/s^2
const JUMP_COOLDOWN := 0.1
const BUILDING_Z_HEIGHT := 1.0   # height of non-ground-level buildings

var z_height: float = 0.0        # current height above ground level
var z_velocity: float = 0.0      # vertical speed (positive = up)
var _is_grounded: bool = true
var _jump_cooldown_timer: float = 0.0

# ── Health ───────────────────────────────────────────────────────────────────
const MAX_HP := 100.0
const REGEN_RATE := 2.0         # HP/s
const REGEN_DELAY := 5.0        # seconds after last damage
const RESPAWN_TIME := 3.0
const INVULN_TIME := 2.0
const DEATH_DROP_DESPAWN := 120.0

var hp: float = MAX_HP
var _regen_timer: float = 0.0   # time since last damage
var _is_dead: bool = false
var _respawn_timer: float = 0.0
var _invuln_timer: float = 0.0
var spawn_position: Vector2 = Vector2.ZERO

# ── Inventory ────────────────────────────────────────────────────────────────
const INVENTORY_SLOTS := 24
const STACK_SIZE := 16
const PICKUP_RANGE := 48.0      # 1.5 tiles
const DROP_RANGE := 32.0        # 1 tile

# Array of {item_id: StringName, quantity: int} or null for empty slots
var inventory: Array = []
var selected_slot: int = 0

# ── Conveyor push ────────────────────────────────────────────────────────────
var _conveyor_push: Vector2 = Vector2.ZERO
var _conv_progress: float = 0.0          # 0→1 within current tile
var _conv_entry_point: Vector2 = Vector2.ZERO  # player's actual position when entering tile
var _conv_grid: Vector2i = Vector2i(-999, -999)

# ── Visual ───────────────────────────────────────────────────────────────────
var facing_direction: Vector2 = Vector2.RIGHT
var _walk_bob_timer: float = 0.0
var stamina: float = STAMINA_MAX

# ── Collision layer constants ────────────────────────────────────────────────
const PLAYER_COLLISION_LAYER := 1
const BUILDING_COLLISION_LAYER := 2

# ── Hand mining ─────────────────────────────────────────────────────────────
const HAND_MINE_TIME := 1.0      # seconds per ore mined by hand
const HAND_MINE_RANGE := 48.0    # max distance from player to deposit (1.5 tiles)
var _mining: bool = false
var _mine_timer: float = 0.0
var _mine_target: Vector2i = Vector2i(-999, -999)
var _mine_item_id: StringName = &""

# ── Conveyor item hover ─────────────────────────────────────────────────────
const CONV_HOVER_RADIUS := 12.0
var _hovered_conv = null  # ConveyorBelt or null
var _hovered_conv_item_idx: int = -1
var _conv_highlight: Node2D = null

# ── References ───────────────────────────────────────────────────────────────
@onready var sprite: Node2D = $PlayerSprite
@onready var shadow: Node2D = $Shadow
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Initialize inventory with empty slots
	inventory.resize(INVENTORY_SLOTS)
	for i in INVENTORY_SLOTS:
		inventory[i] = null
	spawn_position = position
	z_index = 5  # GROUNDED z-index: above conveyors, below buildings
	_create_conv_highlight()

func _physics_process(delta: float) -> void:
	if _is_dead:
		_handle_respawn(delta)
		return

	_handle_invulnerability(delta)
	_handle_vertical_physics(delta)
	_handle_movement(delta)
	_handle_conveyor_push()
	_handle_health_regen(delta)
	_handle_hand_mining(delta)

	# Apply velocity and move
	move_and_slide()

	# Update visuals
	_update_visuals(delta)
	_update_conv_item_hover()

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return
	# Click on hovered conveyor item to pick up
	if _hovered_conv and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _conv_highlight and position.distance_to(_conv_highlight.position) <= PICKUP_RANGE:
			_pickup_hovered_conv_item()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"player_jump"):
		_try_jump()
	elif event.is_action_pressed(&"player_interact"):
		_try_pickup()
	elif event.is_action_pressed(&"player_drop"):
		_try_drop(event.is_action_pressed(&"player_drop") and Input.is_key_pressed(KEY_SHIFT))
	# Inventory slot selection (1-8)
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key >= KEY_1 and key <= KEY_8:
			selected_slot = key - KEY_1

# ── Movement ─────────────────────────────────────────────────────────────────

func _handle_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed(&"pan_up"):
		input_dir.y -= 1
	if Input.is_action_pressed(&"pan_down"):
		input_dir.y += 1
	if Input.is_action_pressed(&"pan_left"):
		input_dir.x -= 1
	if Input.is_action_pressed(&"pan_right"):
		input_dir.x += 1

	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		facing_direction = input_dir

	# Sprint
	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and stamina > 0 and input_dir != Vector2.ZERO
	var max_speed := SPRINT_SPEED if is_sprinting else BASE_SPEED

	if is_sprinting:
		stamina -= delta
		stamina = maxf(stamina, 0.0)
	else:
		stamina += STAMINA_REGEN * delta
		stamina = minf(stamina, STAMINA_MAX)

	# Apply acceleration/friction
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * max_speed + _conveyor_push, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(_conveyor_push, FRICTION * delta)

# ── Vertical Physics ────────────────────────────────────────────────────────

func _try_jump() -> void:
	if not _is_grounded or _jump_cooldown_timer > 0:
		return
	z_velocity = JUMP_SPEED
	_is_grounded = false
	_jump_cooldown_timer = JUMP_COOLDOWN
	_update_collision_for_height()

func _handle_vertical_physics(delta: float) -> void:
	_jump_cooldown_timer = maxf(_jump_cooldown_timer - delta, 0.0)

	var ground := _get_ground_height()

	if _is_grounded:
		if z_height > ground + 0.01:
			# Walked off an edge — start falling
			_is_grounded = false
			z_velocity = 0.0
			_update_collision_for_height()
		else:
			z_height = ground
		if _is_grounded:
			return

	# Airborne
	z_velocity -= JUMP_GRAVITY * delta
	z_height += z_velocity * delta
	ground = _get_ground_height()
	if z_height <= ground and z_velocity <= 0:
		z_height = ground
		z_velocity = 0.0
		_is_grounded = true
		_on_landed()

func _on_landed() -> void:
	_conveyor_push = Vector2.ZERO
	_update_collision_for_height()

func _get_ground_height() -> float:
	var grid_pos := _get_grid_pos()
	var building = GameManager.get_building_at(grid_pos)
	if not building:
		return 0.0
	var def = GameManager.get_building_def(building.building_id)
	if def and def.is_ground_level:
		return 0.0
	return BUILDING_Z_HEIGHT

func _update_collision_for_height() -> void:
	if _is_grounded and z_height < 0.01:
		collision_mask = (1 << (BUILDING_COLLISION_LAYER - 1))
		z_index = 5
	else:
		collision_mask = 0
		z_index = 15

# ── Conveyor Push (bezier curve, same path as items) ────────────────────────

func _handle_conveyor_push() -> void:
	if not _is_grounded or z_height > 0.01:
		_conv_grid = Vector2i(-999, -999)
		return
	_conveyor_push = Vector2.ZERO

	var grid_pos := _get_grid_pos()
	var conv = GameManager.get_conveyor_at(grid_pos)
	if not conv:
		_conv_grid = Vector2i(-999, -999)
		return

	var conv_dir := Vector2(GameManager.DIRECTION_VECTORS[conv.direction])
	var tile_center := Vector2(grid_pos) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5

	# ── Entering a new conveyor tile: record actual position as entry point ──
	if grid_pos != _conv_grid:
		_conv_entry_point = position
		_conv_progress = 0.0
		_conv_grid = grid_pos

	# ── Advance progress and compute bezier push ──
	var dt := get_physics_process_delta_time()
	var old_progress := _conv_progress
	_conv_progress += conv.push_speed * dt

	var exit_point := tile_center + conv_dir * 0.5 * TILE_SIZE

	if _conv_progress >= 1.0:
		# Past the exit edge — push straight in the conveyor direction so we
		# cross the tile boundary and _get_grid_pos detects the next tile.
		_conveyor_push = conv_dir * conv.push_speed * TILE_SIZE
	elif dt > 0:
		var old_pos := _bezier_eval(_conv_entry_point, tile_center, exit_point, old_progress)
		var new_pos := _bezier_eval(_conv_entry_point, tile_center, exit_point, _conv_progress)
		_conveyor_push = (new_pos - old_pos) / dt

static func _bezier_eval(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * u * u + p1 * 2.0 * u * t + p2 * t * t

# ── Health ───────────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if _invuln_timer > 0 or _is_dead:
		return
	hp -= amount
	_regen_timer = 0.0
	if hp <= 0:
		hp = 0
		_die()

func _handle_health_regen(delta: float) -> void:
	if _is_dead:
		return
	_regen_timer += delta
	if _regen_timer >= REGEN_DELAY and hp < MAX_HP:
		hp = minf(hp + REGEN_RATE * delta, MAX_HP)

func _handle_invulnerability(delta: float) -> void:
	if _invuln_timer > 0:
		_invuln_timer -= delta

func _die() -> void:
	_is_dead = true
	_respawn_timer = RESPAWN_TIME
	velocity = Vector2.ZERO
	# Drop inventory items
	_drop_all_inventory()
	visible = false

func _handle_respawn(delta: float) -> void:
	_respawn_timer -= delta
	if _respawn_timer <= 0:
		_respawn()

func _respawn() -> void:
	_is_dead = false
	hp = MAX_HP
	_regen_timer = REGEN_DELAY
	_invuln_timer = INVULN_TIME
	position = spawn_position
	z_height = 0.0
	z_velocity = 0.0
	_is_grounded = true
	_update_collision_for_height()
	visible = true

func _drop_all_inventory() -> void:
	# Drop all items as ground items at death location
	for i in INVENTORY_SLOTS:
		if inventory[i] != null:
			_spawn_ground_item(inventory[i].item_id, inventory[i].quantity, position)
			inventory[i] = null

# ── Hand Mining ─────────────────────────────────────────────────────────────

## Only these ores can be hand-mined (early game bootstrap).
const HAND_MINEABLE := [&"iron_ore", &"copper_ore"]

func _handle_hand_mining(delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_mining()
		return

	# Don't mine while in build/destroy mode
	var build_system = get_parent().get_node_or_null("BuildSystem")
	if build_system and (build_system.building_mode or build_system.destroy_mode or build_system.energy_link_mode):
		_stop_mining()
		return

	# Get the grid cell under the mouse
	var camera := get_viewport().get_camera_2d()
	if not camera:
		_stop_mining()
		return
	var screen_pos := get_viewport().get_mouse_position()
	var viewport_size := get_viewport_rect().size
	var offset := screen_pos - viewport_size / 2.0
	var world_pos: Vector2 = camera.global_position + offset / camera.zoom.x
	var grid_pos := Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))

	# Must be a deposit with no building on it
	if not GameManager.deposits.has(grid_pos) or GameManager.buildings.has(grid_pos):
		_stop_mining()
		return

	# Only hand-mineable ores
	var deposit_item: StringName = GameManager.deposits[grid_pos]
	if deposit_item not in HAND_MINEABLE:
		_stop_mining()
		return

	# Must be in range
	var tile_center := Vector2(grid_pos) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	if position.distance_to(tile_center) > HAND_MINE_RANGE:
		_stop_mining()
		return

	# Start or continue mining
	if not _mining or _mine_target != grid_pos:
		_mining = true
		_mine_timer = 0.0
		_mine_target = grid_pos
		_mine_item_id = deposit_item

	_mine_timer += delta
	if _mine_timer >= HAND_MINE_TIME:
		_mine_timer -= HAND_MINE_TIME
		var leftover := add_item(_mine_item_id, 1)
		if leftover > 0:
			_stop_mining()  # inventory full
		else:
			item_mined.emit(_mine_item_id)
			_spawn_pickup_float(tile_center, _mine_item_id)
	queue_redraw()

func _stop_mining() -> void:
	if _mining:
		_mining = false
		_mine_timer = 0.0
		queue_redraw()

func get_mine_progress() -> float:
	if not _mining:
		return -1.0
	return _mine_timer / HAND_MINE_TIME

func _spawn_pickup_float(world_pos: Vector2, item_id: StringName) -> void:
	var floater := _PickupFloat.new(item_id)
	floater.position = world_pos
	floater.z_index = 20
	get_parent().add_child(floater)

class _PickupFloat extends Node2D:
	const FLOAT_SPEED := 20.0
	const LIFETIME := 0.8
	var _timer: float = 0.0
	var _icon: AtlasTexture
	func _init(item_id: StringName) -> void:
		_icon = GameManager.get_item_icon(item_id)
	func _process(delta: float) -> void:
		_timer += delta
		position.y -= FLOAT_SPEED * delta
		if _timer >= LIFETIME:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var alpha := 1.0 - (_timer / LIFETIME)
		var s := 16.0
		if _icon:
			draw_texture_rect(_icon, Rect2(-s * 0.5, -s * 0.5, s, s), false, Color(1, 1, 1, alpha))
		# "+1" text
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(s * 0.5 + 1, 2), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.9, 0.9, 0.7, alpha))

func _draw() -> void:
	if not _mining:
		return
	var tile_center := Vector2(_mine_target) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)
	var local_target := tile_center - position
	var progress := _mine_timer / HAND_MINE_TIME

	# Beam line from player to mouse cursor
	var camera := get_viewport().get_camera_2d()
	var cursor_world := Vector2.ZERO
	if camera:
		var screen_pos := get_viewport().get_mouse_position()
		var viewport_size := get_viewport_rect().size
		var offset := screen_pos - viewport_size / 2.0
		cursor_world = camera.global_position + offset / camera.zoom.x
	else:
		cursor_world = tile_center
	var local_cursor := cursor_world - position
	var beam_color := Color(0.9, 0.7, 0.2, 0.4 + progress * 0.4)
	var beam_width := 1.0 + progress * 1.5
	draw_line(Vector2.ZERO, local_cursor, beam_color, beam_width)

	# Sparkle particles at cursor
	var spark_count := 3
	var time := Time.get_ticks_msec() / 1000.0
	for i in spark_count:
		var angle := time * (3.0 + i * 1.7) + i * TAU / spark_count
		var dist := 4.0 + sin(time * 5.0 + i) * 2.0
		var spark_pos := local_cursor + Vector2(cos(angle), sin(angle)) * dist
		var spark_alpha := 0.5 + sin(time * 8.0 + i * 2.0) * 0.3
		draw_circle(spark_pos, 1.0, Color(1.0, 0.9, 0.4, spark_alpha))

	# Progress arc around tile center
	var arc_radius := 10.0
	var arc_segments := 24
	var arc_angle := progress * TAU
	if arc_angle > 0.01:
		var arc_color := Color(0.2, 0.85, 0.3, 0.8)
		var points := PackedVector2Array()
		for j in arc_segments + 1:
			var a := -PI / 2.0 + float(j) / arc_segments * arc_angle
			points.append(local_target + Vector2(cos(a), sin(a)) * arc_radius)
		for j in range(points.size() - 1):
			draw_line(points[j], points[j + 1], arc_color, 2.0)

		# Background arc (full circle, dim)
		var bg_points := PackedVector2Array()
		for j in arc_segments + 1:
			var a := -PI / 2.0 + float(j) / arc_segments * TAU
			bg_points.append(local_target + Vector2(cos(a), sin(a)) * arc_radius)
		for j in range(bg_points.size() - 1):
			draw_line(bg_points[j], bg_points[j + 1], Color(0.3, 0.3, 0.3, 0.3), 1.5)

# ── Inventory ────────────────────────────────────────────────────────────────

func add_item(item_id: StringName, quantity: int = 1) -> int:
	## Try to add items to inventory. Returns the number that couldn't fit.
	var remaining := quantity
	# First, try to stack with existing slots
	for i in INVENTORY_SLOTS:
		if remaining <= 0:
			break
		if inventory[i] != null and inventory[i].item_id == item_id:
			var space: int = STACK_SIZE - inventory[i].quantity
			var to_add: int = mini(remaining, space)
			inventory[i].quantity += to_add
			remaining -= to_add
	# Then, try empty slots
	for i in INVENTORY_SLOTS:
		if remaining <= 0:
			break
		if inventory[i] == null:
			var to_add: int = mini(remaining, STACK_SIZE)
			inventory[i] = {item_id = item_id, quantity = to_add}
			remaining -= to_add
	return remaining

func remove_item_from_slot(slot: int, quantity: int = 1) -> Dictionary:
	## Remove up to quantity items from a slot. Returns {item_id, quantity} removed.
	if slot < 0 or slot >= INVENTORY_SLOTS or inventory[slot] == null:
		return {}
	var item = inventory[slot]
	var to_remove: int = mini(quantity, item.quantity)
	item.quantity -= to_remove
	var result := {item_id = item.item_id, quantity = to_remove}
	if item.quantity <= 0:
		inventory[slot] = null
	return result

func has_items() -> bool:
	for slot in inventory:
		if slot != null:
			return true
	return false

## Count total quantity of an item across all inventory slots.
func count_item(item_id: StringName) -> int:
	var total := 0
	for slot in inventory:
		if slot != null and slot.item_id == item_id:
			total += slot.quantity
	return total

## Remove up to quantity of an item from inventory (any slots). Returns amount actually removed.
func remove_item(item_id: StringName, quantity: int = 1) -> int:
	var remaining := quantity
	for i in INVENTORY_SLOTS:
		if remaining <= 0:
			break
		if inventory[i] != null and inventory[i].item_id == item_id:
			var to_remove: int = mini(remaining, inventory[i].quantity)
			inventory[i].quantity -= to_remove
			remaining -= to_remove
			if inventory[i].quantity <= 0:
				inventory[i] = null
	return quantity - remaining

func _try_pickup() -> void:
	# Try to pick up the nearest ground item or conveyor item within range
	var picked_up := false

	# Check ground items — only pick up the one the mouse is hovering
	var ground_items := get_tree().get_nodes_in_group("ground_items")
	var nearest_item: Node2D = null
	for item in ground_items:
		if not is_instance_valid(item) or not item._hovered:
			continue
		if position.distance_to(item.position) <= PICKUP_RANGE:
			nearest_item = item
			break
	if nearest_item:
		var remaining := add_item(nearest_item.item_id, nearest_item.quantity)
		if remaining < nearest_item.quantity:
			if remaining <= 0:
				nearest_item.queue_free()
			else:
				nearest_item.quantity = remaining
			picked_up = true

	if picked_up:
		return

	# Check hovered conveyor item
	if _hovered_conv and _conv_highlight and position.distance_to(_conv_highlight.position) <= PICKUP_RANGE:
		_pickup_hovered_conv_item()

func _try_drop(drop_stack: bool) -> void:
	if inventory[selected_slot] == null:
		return
	var quantity: int = inventory[selected_slot].quantity if drop_stack else 1
	var dropped: Dictionary = remove_item_from_slot(selected_slot, quantity)
	if dropped.is_empty():
		return

	# Calculate drop position in front of player (slightly closer so it stays within pickup range)
	var drop_pos := position + facing_direction.normalized() * (DROP_RANGE - 4.0)
	var drop_grid := Vector2i(floori(drop_pos.x / TILE_SIZE), floori(drop_pos.y / TILE_SIZE))

	# Try to insert into building at drop position
	var building = GameManager.get_building_at(drop_grid)
	if building and building.logic:
		var leftover: int = building.logic.try_insert_item(dropped.item_id, dropped.quantity)
		if leftover <= 0:
			return
		# Drop the remainder that didn't fit
		dropped.quantity = leftover

	# Drop on top of the building so it can consume from the stack later
	var ground_pos := drop_pos
	if building:
		ground_pos = Vector2(drop_grid) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	_spawn_ground_item(dropped.item_id, dropped.quantity, ground_pos)

func _spawn_ground_item(item_id: StringName, quantity: int, pos: Vector2) -> void:
	# Merge with nearby existing ground item of same type
	for existing in get_tree().get_nodes_in_group("ground_items"):
		if is_instance_valid(existing) and existing.item_id == item_id and existing.position.distance_to(pos) < GroundItem.MERGE_RANGE:
			existing.quantity += quantity
			return
	var ground_item_scene := preload("res://player/ground_item.tscn")
	var item := ground_item_scene.instantiate()
	item.item_id = item_id
	item.quantity = quantity
	item.position = pos
	var game_world = get_parent()
	if game_world:
		game_world.add_child(item)

# ── Conveyor item hover ─────────────────────────────────────────────────────

func _create_conv_highlight() -> void:
	_conv_highlight = Node2D.new()
	_conv_highlight.z_index = 15
	_conv_highlight.visible = false
	_conv_highlight.draw.connect(_draw_conv_highlight)
	get_parent().add_child.call_deferred(_conv_highlight)

func _draw_conv_highlight() -> void:
	_conv_highlight.draw_rect(Rect2(-8, -8, 16, 16), Color(1, 1, 1, 0.85), false, 1.5)

func _update_conv_item_hover() -> void:
	_hovered_conv = null
	_hovered_conv_item_idx = -1
	if _is_dead or not _conv_highlight:
		if _conv_highlight:
			_conv_highlight.visible = false
		return

	if get_viewport().gui_get_hovered_control() != null:
		_conv_highlight.visible = false
		return

	var mouse_world := get_global_mouse_position()
	var mouse_grid := Vector2i(floori(mouse_world.x / TILE_SIZE), floori(mouse_world.y / TILE_SIZE))

	for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var check: Vector2i = mouse_grid + offset
		var conv = GameManager.get_conveyor_at(check)
		if not conv or conv.buffer.is_empty():
			continue
		for i in conv.buffer.items.size():
			var item = conv.buffer.items[i]
			if item.visual and mouse_world.distance_to(item.visual.position) < CONV_HOVER_RADIUS:
				_hovered_conv = conv
				_hovered_conv_item_idx = i
				_conv_highlight.visible = true
				_conv_highlight.position = item.visual.position
				_conv_highlight.queue_redraw()
				return

	_conv_highlight.visible = false

func _pickup_hovered_conv_item() -> void:
	if not _hovered_conv or _hovered_conv_item_idx < 0:
		return
	if _hovered_conv_item_idx >= _hovered_conv.buffer.items.size():
		return
	var item = _hovered_conv.buffer.items[_hovered_conv_item_idx]
	var item_id: StringName = item.id
	var leftover: int = add_item(item_id, 1)
	if leftover == 0:
		_hovered_conv.buffer.free_visual(item)
		_hovered_conv.buffer.items.remove_at(_hovered_conv_item_idx)
		_hovered_conv = null
		_hovered_conv_item_idx = -1

# ── Visuals ──────────────────────────────────────────────────────────────────

func _update_visuals(delta: float) -> void:
	if not sprite:
		return

	# Walk bob — only when actively walking (input held), perpendicular to facing
	var is_walking: bool = velocity.length() > 10 and _has_movement_input()
	if is_walking:
		_walk_bob_timer += delta
		var bob: float = sin(_walk_bob_timer * 8.0) * 1.0
		# Perpendicular to facing direction
		var perp := Vector2(-facing_direction.y, facing_direction.x).normalized()
		sprite.position = perp * bob
	else:
		sprite.position = sprite.position.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))
		if sprite.position.length() < 0.1:
			_walk_bob_timer = 0.0

	# Direction indicator rotation
	sprite.rotation = facing_direction.angle()

	# Height-based scale
	var scale_val := 1.0 + z_height * 0.13
	sprite.scale = Vector2(scale_val, scale_val)

	# Shadow visibility
	if shadow:
		shadow.visible = z_height > 0.01
		if shadow.visible:
			shadow.modulate.a = 0.3

	# Invulnerability flicker
	if _invuln_timer > 0:
		sprite.visible = fmod(_invuln_timer, 0.2) > 0.1
	else:
		sprite.visible = true

# ── Helpers ──────────────────────────────────────────────────────────────────

func _get_grid_pos() -> Vector2i:
	return Vector2i(floori(position.x / TILE_SIZE), floori(position.y / TILE_SIZE))

func _has_movement_input() -> bool:
	return Input.is_action_pressed(&"pan_up") or Input.is_action_pressed(&"pan_down") \
		or Input.is_action_pressed(&"pan_left") or Input.is_action_pressed(&"pan_right")

# ── Serialization ────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var inv_data: Array = []
	for slot in inventory:
		if slot == null:
			inv_data.append(null)
		else:
			inv_data.append({item_id = str(slot.item_id), quantity = slot.quantity})
	return {
		position_x = position.x,
		position_y = position.y,
		health = hp,
		stamina = stamina,
		inventory = inv_data,
		z_height = z_height,
		z_velocity = z_velocity,
		is_grounded = _is_grounded,
		selected_slot = selected_slot,
	}

func deserialize(data: Dictionary) -> void:
	position = Vector2(data.get("position_x", spawn_position.x), data.get("position_y", spawn_position.y))
	hp = data.get("health", MAX_HP)
	stamina = data.get("stamina", STAMINA_MAX)
	selected_slot = data.get("selected_slot", 0)

	# Restore inventory
	var inv_data: Array = data.get("inventory", [])
	for i in INVENTORY_SLOTS:
		if i < inv_data.size() and inv_data[i] != null:
			var iid := StringName(inv_data[i]["item_id"])
			if GameManager.is_valid_item_id(iid):
				inventory[i] = {item_id = iid, quantity = int(inv_data[i]["quantity"])}
			else:
				GameLogger.warn("Player inventory slot %d: skipped invalid item '%s'" % [i, iid])
				inventory[i] = null
		else:
			inventory[i] = null

	# Restore vertical state
	z_height = data.get("z_height", 0.0)
	z_velocity = data.get("z_velocity", 0.0)
	_is_grounded = data.get("is_grounded", true)
	_update_collision_for_height()
