class_name Player
extends CharacterBody2D

const TILE_SIZE := 32

# ── Movement ─────────────────────────────────────────────────────────────────
const BASE_SPEED := 96.0        # 3 tiles/s at 32px/tile
const SPRINT_SPEED := 160.0     # 5 tiles/s
const ACCELERATION := 640.0     # 20 tiles/s^2
const FRICTION := 480.0         # 15 tiles/s^2
const STAMINA_MAX := 3.0        # seconds of sprint
const STAMINA_REGEN := 1.0      # seconds recovered per second

# ── Jump ─────────────────────────────────────────────────────────────────────
const JUMP_DURATION := 0.3
const JUMP_COOLDOWN := 0.1

enum JumpState { GROUNDED, JUMPING, ELEVATED, DROPPING }
var jump_state: JumpState = JumpState.GROUNDED
var _jump_timer: float = 0.0
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
const INVENTORY_SLOTS := 8
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

func _physics_process(delta: float) -> void:
	if _is_dead:
		_handle_respawn(delta)
		return

	_handle_invulnerability(delta)
	_handle_jump(delta)
	_handle_movement(delta)
	_handle_conveyor_push()
	_handle_health_regen(delta)

	# Apply velocity and move
	move_and_slide()

	# Update visuals
	_update_visuals(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
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
	# Mouse scroll for slot cycling
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			selected_slot = (selected_slot - 1 + INVENTORY_SLOTS) % INVENTORY_SLOTS
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			selected_slot = (selected_slot + 1) % INVENTORY_SLOTS

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

# ── Jump State Machine ──────────────────────────────────────────────────────

func _try_jump() -> void:
	if _jump_cooldown_timer > 0:
		return
	if jump_state == JumpState.GROUNDED:
		jump_state = JumpState.JUMPING
		_jump_timer = JUMP_DURATION
		_jump_cooldown_timer = JUMP_COOLDOWN
		_update_collision_mask()

func _handle_jump(delta: float) -> void:
	_jump_cooldown_timer = maxf(_jump_cooldown_timer - delta, 0.0)

	match jump_state:
		JumpState.JUMPING:
			_jump_timer -= delta
			if _jump_timer <= 0:
				jump_state = JumpState.ELEVATED
				_update_collision_mask()
		JumpState.ELEVATED:
			# Check if player moved onto empty ground / ground-level building
			if _is_over_ground_level():
				jump_state = JumpState.DROPPING
				_jump_timer = JUMP_DURATION
		JumpState.DROPPING:
			_jump_timer -= delta
			if _jump_timer <= 0:
				if _is_over_ground_level():
					jump_state = JumpState.GROUNDED
					_update_collision_mask()
				else:
					# Landed on another building — stay elevated
					jump_state = JumpState.ELEVATED

func _is_over_ground_level() -> bool:
	var grid_pos := _get_grid_pos()
	var building = GameManager.get_building_at(grid_pos)
	if not building:
		return true  # Empty tile = ground level
	var def = GameManager.get_building_def(building.building_id)
	if def and def.is_ground_level:
		return true  # Ground-level building (conveyor, etc.)
	return false

func _update_collision_mask() -> void:
	if jump_state == JumpState.GROUNDED:
		collision_mask = (1 << (BUILDING_COLLISION_LAYER - 1))
		z_index = 5
	else:
		collision_mask = 0
		z_index = 15

# ── Conveyor Push (bezier curve, same path as items) ────────────────────────

func _handle_conveyor_push() -> void:
	if jump_state != JumpState.GROUNDED:
		# Airborne — keep the last _conveyor_push as inertia (don't zero it)
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
	jump_state = JumpState.GROUNDED
	_update_collision_mask()
	visible = true

func _drop_all_inventory() -> void:
	# Drop all items as ground items at death location
	for i in INVENTORY_SLOTS:
		if inventory[i] != null:
			_spawn_ground_item(inventory[i].item_id, inventory[i].quantity, position)
			inventory[i] = null

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

func _try_pickup() -> void:
	# Try to pick up the nearest ground item or conveyor item within range
	var picked_up := false

	# Check ground items first
	var ground_items := get_tree().get_nodes_in_group("ground_items")
	var nearest_dist := PICKUP_RANGE + 1.0
	var nearest_item: Node2D = null
	for item in ground_items:
		if not is_instance_valid(item):
			continue
		var dist := position.distance_to(item.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_item = item
	if nearest_item and nearest_dist <= PICKUP_RANGE:
		var remaining := add_item(nearest_item.item_id, nearest_item.quantity)
		if remaining < nearest_item.quantity:
			if remaining <= 0:
				nearest_item.queue_free()
			else:
				nearest_item.quantity = remaining
			picked_up = true

	if picked_up:
		return

	# Check conveyor items
	var grid_pos := _get_grid_pos()
	# Check the player's tile and adjacent tiles
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for offset_v: Vector2i in offsets:
		var check_pos: Vector2i = grid_pos + offset_v
		var tile_center: Vector2 = Vector2(check_pos) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
		if position.distance_to(tile_center) > PICKUP_RANGE:
			continue
		var conv = GameManager.get_conveyor_at(check_pos)
		if conv and conv.has_item():
			var front: Dictionary = conv.get_front_item()
			if front.progress >= 0.5:  # Only pick up items that are at least halfway through
				var item_id: StringName = front.id
				var leftover: int = add_item(item_id, 1)
				if leftover == 0:
					conv.pop_front_item()
					return

func _try_drop(drop_stack: bool) -> void:
	if inventory[selected_slot] == null:
		return
	var quantity: int = inventory[selected_slot].quantity if drop_stack else 1
	var dropped: Dictionary = remove_item_from_slot(selected_slot, quantity)
	if dropped.is_empty():
		return

	# Calculate drop position in front of player
	var drop_pos := position + facing_direction.normalized() * DROP_RANGE

	# Try to place on conveyor if facing one
	if not drop_stack:
		var drop_grid := Vector2i(floori(drop_pos.x / TILE_SIZE), floori(drop_pos.y / TILE_SIZE))
		var conv = GameManager.get_conveyor_at(drop_grid)
		if conv and conv.can_accept():
			conv.place_item(dropped.item_id)
			return

	_spawn_ground_item(dropped.item_id, dropped.quantity, drop_pos)

func _spawn_ground_item(item_id: StringName, quantity: int, pos: Vector2) -> void:
	var ground_item_scene := preload("res://player/ground_item.tscn")
	var item := ground_item_scene.instantiate()
	item.item_id = item_id
	item.quantity = quantity
	item.position = pos
	# Add to the game world's building layer so it renders in world space
	var game_world = get_parent()
	if game_world:
		game_world.add_child(item)

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

	# Jump/elevated scale
	match jump_state:
		JumpState.JUMPING, JumpState.DROPPING:
			var t := _jump_timer / JUMP_DURATION
			var scale_val := lerpf(1.1, 1.2, t) if jump_state == JumpState.JUMPING else lerpf(1.0, 1.1, t)
			sprite.scale = Vector2(scale_val, scale_val)
		JumpState.ELEVATED:
			sprite.scale = Vector2(1.1, 1.1)
		JumpState.GROUNDED:
			sprite.scale = Vector2(1.0, 1.0)

	# Shadow visibility
	if shadow:
		shadow.visible = jump_state != JumpState.GROUNDED
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
		state = JumpState.keys()[jump_state],
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
			inventory[i] = {item_id = StringName(inv_data[i]["item_id"]), quantity = int(inv_data[i]["quantity"])}
		else:
			inventory[i] = null

	# Restore jump state
	var state_name: String = data.get("state", "GROUNDED")
	match state_name:
		"ELEVATED": jump_state = JumpState.ELEVATED
		_: jump_state = JumpState.GROUNDED
	_update_collision_mask()
