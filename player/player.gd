class_name Player
extends CharacterBody3D

signal item_mined(item_id: StringName)

# -- Movement ----------------------------------------------------------------
const BASE_SPEED := 3.0          # 3 tiles/s (1 unit = 1 tile in 3D)
const SPRINT_SPEED := 5.0        # 5 tiles/s
const ACCELERATION := 20.0       # tiles/s^2
const FRICTION := 15.0           # tiles/s^2
const STAMINA_MAX := 3.0         # seconds of sprint
const STAMINA_REGEN := 1.0       # seconds recovered per second

# -- Vertical physics ---------------------------------------------------------
const JUMP_SPEED := 4.0           # world-units/s upward
const JUMP_GRAVITY := 11.0       # world-units/s^2
const JUMP_COOLDOWN := 0.1
const BUILDING_Z_HEIGHT := 1.0   # height of non-ground-level buildings

var _jump_cooldown_timer: float = 0.0

# -- Health -------------------------------------------------------------------
const MAX_HP := 100.0
const REGEN_RATE := 2.0          # HP/s
const REGEN_DELAY := 5.0         # seconds after last damage
const RESPAWN_TIME := 3.0
const INVULN_TIME := 2.0
const DEATH_DROP_DESPAWN := 120.0

var hp: float = MAX_HP
var _regen_timer: float = 0.0    # time since last damage
var _is_dead: bool = false
var _respawn_timer: float = 0.0
var _invuln_timer: float = 0.0
var spawn_position: Vector3 = Vector3.ZERO

# -- Inventory ----------------------------------------------------------------
const INVENTORY_SLOTS := 24
const STACK_SIZE := 16
const PICKUP_RANGE := 1.5        # 1.5 tiles (in world units now)
const DROP_RANGE := 1.0          # 1 tile

# Array of {item_id: StringName, quantity: int} or null for empty slots
var inventory: Array = []
var selected_slot: int = 0

# -- Conveyor push (set by ConveyorBelt ForceZone each physics frame) ---------
var conveyor_push: Vector3 = Vector3.ZERO

# -- Bot control (set by BotController each tick, overrides keyboard input) ----
var bot_input: Vector3 = Vector3.ZERO
var bot_sprint: bool = false

# -- Visual -------------------------------------------------------------------
var facing_direction: Vector3 = Vector3.RIGHT  # XZ plane direction
var stamina: float = STAMINA_MAX

# -- Collision layer constants ------------------------------------------------
const PLAYER_COLLISION_LAYER := 1  # bit 1
const BUILDING_COLLISION_LAYER := 2  # bit 2
const GROUND_COLLISION_LAYER := 3  # bit 4
const ITEM_COLLISION_LAYER := 4  # bit 8

# -- Hand mining --------------------------------------------------------------
const HAND_MINE_TIME := 1.0       # seconds per ore mined by hand
const HAND_MINE_RANGE := 1.5      # max distance from player to deposit (1.5 tiles)
var _mining: bool = false
var _mine_timer: float = 0.0
var _mine_target: Vector2i = Vector2i(-999, -999)
var _mine_item_id: StringName = &""

# -- Conveyor item hover ------------------------------------------------------
const CONV_HOVER_RADIUS := 0.375  # ~12px / 32px per tile

# -- References ---------------------------------------------------------------
@onready var model: Node3D = $Model
@onready var anim_player: AnimationPlayer = $Model/AnimationPlayer
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	# Initialize inventory with empty slots
	inventory.resize(INVENTORY_SLOTS)
	for i in INVENTORY_SLOTS:
		inventory[i] = null
	spawn_position = position

func _physics_process(delta: float) -> void:
	if _is_dead:
		_handle_respawn(delta)
		return

	_handle_invulnerability(delta)
	_handle_vertical_physics(delta)
	_handle_movement(delta)
	conveyor_push = Vector3.ZERO  # reset after movement consumes it
	_handle_health_regen(delta)
	_handle_hand_mining(delta)

	# Apply velocity and move
	move_and_slide()
	_update_collision_for_height()

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

# -- Movement ----------------------------------------------------------------

func _handle_movement(delta: float) -> void:
	var input_dir := Vector3.ZERO

	# Bot control override: use external input direction (set by BotController)
	if bot_input != Vector3.ZERO:
		input_dir = bot_input.normalized()
		input_dir.y = 0
	else:
		# Screen-space WASD: project input through the isometric camera orientation.
		# Camera is 45° Y-rotated, so screen-up = world (-X, -Z), screen-right = world (+X, -Z).
		var input_2d := Vector2.ZERO
		if Input.is_action_pressed(&"pan_up"):
			input_2d.y -= 1
		if Input.is_action_pressed(&"pan_down"):
			input_2d.y += 1
		if Input.is_action_pressed(&"pan_left"):
			input_2d.x -= 1
		if Input.is_action_pressed(&"pan_right"):
			input_2d.x += 1
		# Rotate screen input by camera Y angle to get world XZ direction
		var cam := get_viewport().get_camera_3d()
		if cam and input_2d != Vector2.ZERO:
			var cam_basis := cam.global_transform.basis
			var forward := -cam_basis.z
			var right := cam_basis.x
			# Project onto XZ plane and normalize
			forward.y = 0
			right.y = 0
			forward = forward.normalized()
			right = right.normalized()
			input_dir = (right * input_2d.x + forward * -input_2d.y)
			input_dir.y = 0
			if input_dir.length() > 0.01:
				input_dir = input_dir.normalized()

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		facing_direction = input_dir

	# Sprint
	var is_sprinting := (Input.is_key_pressed(KEY_SHIFT) or bot_sprint) and stamina > 0 and input_dir != Vector3.ZERO
	var max_speed := SPRINT_SPEED if is_sprinting else BASE_SPEED

	if is_sprinting:
		stamina -= delta
		stamina = maxf(stamina, 0.0)
	else:
		stamina += STAMINA_REGEN * delta
		stamina = minf(stamina, STAMINA_MAX)

	# Apply acceleration/friction (XZ plane only, preserve Y)
	var target_xz := input_dir * max_speed + conveyor_push
	var current_xz := Vector3(velocity.x, 0.0, velocity.z)
	if input_dir != Vector3.ZERO:
		current_xz = current_xz.move_toward(target_xz, ACCELERATION * delta)
	else:
		current_xz = current_xz.move_toward(conveyor_push, FRICTION * delta)
	velocity.x = current_xz.x
	velocity.z = current_xz.z

# -- Vertical Physics ---------------------------------------------------------

func _try_jump() -> void:
	if not is_on_floor() or _jump_cooldown_timer > 0:
		return
	velocity.y = JUMP_SPEED
	_jump_cooldown_timer = JUMP_COOLDOWN

func _handle_vertical_physics(delta: float) -> void:
	_jump_cooldown_timer = maxf(_jump_cooldown_timer - delta, 0.0)

	if not is_on_floor():
		velocity.y -= JUMP_GRAVITY * delta



func _update_collision_for_height() -> void:
	# Collide with ground, buildings, and items.
	var ground_bit := (1 << (GROUND_COLLISION_LAYER - 1))
	var building_bit := (1 << (BUILDING_COLLISION_LAYER - 1))
	var item_bit := (1 << (ITEM_COLLISION_LAYER - 1))
	collision_mask = ground_bit | building_bit | item_bit

# -- Health -------------------------------------------------------------------

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
	velocity = Vector3.ZERO
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
	velocity.y = 0.0
	_update_collision_for_height()
	visible = true

func _drop_all_inventory() -> void:
	# Drop all items as ground items at death location
	for i in INVENTORY_SLOTS:
		if inventory[i] != null:
			spawn_ground_item(inventory[i].item_id, inventory[i].quantity, position)
			inventory[i] = null

# -- Hand Mining --------------------------------------------------------------

## Only these ores can be hand-mined (early game bootstrap).
const HAND_MINEABLE := [&"pyromite", &"crystalline", &"biovine"]

func _handle_hand_mining(delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_stop_mining()
		return

	# Don't mine while in build/destroy mode
	var build_system = get_parent().get_node_or_null("BuildSystem")
	if build_system and (build_system.building_mode or build_system.destroy_mode):
		_stop_mining()
		return

	# Get the grid cell under the mouse -- terrain-aware raycast
	var grid_pos: Vector2i = GridUtils.raycast_mouse_to_grid(get_viewport())

	# Must be a deposit with no building on it
	if not GameManager.deposits.has(grid_pos) or GameManager.buildings.has(grid_pos):
		_stop_mining()
		return

	# Only hand-mineable ores
	var deposit_item: StringName = GameManager.deposits[grid_pos]
	if deposit_item not in HAND_MINEABLE:
		_stop_mining()
		return

	# Must be in range (XZ distance only)
	var tile_center := GridUtils.grid_to_world(grid_pos)
	var dist_xz := Vector2(position.x - tile_center.x, position.z - tile_center.z).length()
	if dist_xz > HAND_MINE_RANGE:
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
			# TODO 3D.11: spawn pickup float in 3D

func _stop_mining() -> void:
	if _mining:
		_mining = false
		_mine_timer = 0.0

func get_mine_progress() -> float:
	if not _mining:
		return -1.0
	return _mine_timer / HAND_MINE_TIME

# TODO 3D.11: _draw() mining laser/highlight needs 3D equivalent
# The old 2D _draw() calls (beam line, sparkle particles, progress arc)
# will be reimplemented as 3D visuals or overlay in a later card.

# -- Inventory ----------------------------------------------------------------

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
	var nearest_phys: PhysicsItem = _find_nearest_physics_item()
	if nearest_phys:
		var remaining := add_item(nearest_phys.item_id, 1)
		if remaining <= 0:
			nearest_phys.queue_free()

func _find_nearest_physics_item() -> PhysicsItem:
	var best: PhysicsItem = null
	var best_dist := PICKUP_RANGE + 1.0
	for item in get_tree().get_nodes_in_group(&"physics_items"):
		if not is_instance_valid(item):
			continue
		var dist_xz := Vector2(position.x - item.position.x, position.z - item.position.z).length()
		if dist_xz < best_dist:
			best_dist = dist_xz
			best = item
	return best

func _try_drop(drop_stack: bool) -> void:
	if inventory[selected_slot] == null:
		return
	var quantity: int = inventory[selected_slot].quantity if drop_stack else 1
	var dropped: Dictionary = remove_item_from_slot(selected_slot, quantity)
	if dropped.is_empty():
		return

	# Calculate drop position in front of player (XZ plane)
	var drop_dir := facing_direction.normalized()
	var drop_pos := position + drop_dir * (DROP_RANGE - 0.125)
	drop_pos.y = 0.0  # ground level
	var drop_grid := GridUtils.world_to_grid(drop_pos)

	# Try to insert into building at drop position
	var building = GameManager.get_building_at(drop_grid)
	if building and building.logic:
		var leftover: int = building.logic.try_insert_item(dropped.item_id, dropped.quantity)
		if leftover <= 0:
			return
		# Drop the remainder that didn't fit
		dropped.quantity = leftover

	# Spawn as PhysicsItems (single objects, no quantity stacking)
	var spawn_pos := drop_pos
	if building:
		spawn_pos = GridUtils.grid_to_world(drop_grid)
	spawn_pos.y = GameManager.get_terrain_height(drop_grid) + 0.3
	var impulse := drop_dir * 1.0
	for i in dropped.quantity:
		var offset := Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
		PhysicsItem.spawn(dropped.item_id, spawn_pos + offset, impulse)

func spawn_ground_item(item_id: StringName, quantity: int, pos) -> void:
	# pos can be Vector3 or Vector2 (backward compat for UI callers)
	var pos_3d: Vector3
	if pos is Vector3:
		pos_3d = pos
	elif pos is Vector2:
		pos_3d = Vector3(pos.x, 0.0, pos.y)
	else:
		pos_3d = position
	var drop_grid := GridUtils.world_to_grid(pos_3d)
	pos_3d.y = GameManager.get_terrain_height(drop_grid) + 0.3

	# Spawn each item as an individual PhysicsItem
	for i in quantity:
		var offset := Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
		PhysicsItem.spawn(item_id, pos_3d + offset)

# -- Visuals ------------------------------------------------------------------

func _update_visuals(_delta: float) -> void:
	if not model:
		return

	# Direction rotation (rotate around Y axis)
	model.rotation.y = atan2(facing_direction.x, facing_direction.z)

	# Animation state
	var speed_xz := Vector2(velocity.x, velocity.z).length()
	var target_anim: StringName
	if speed_xz > SPRINT_SPEED * 0.8:
		target_anim = &"run"
	elif speed_xz > 0.3 and _has_movement_input():
		target_anim = &"walk"
	else:
		target_anim = &"idle"
	if anim_player and anim_player.current_animation != target_anim:
		anim_player.play(target_anim)

	# Invulnerability flicker
	if _invuln_timer > 0:
		model.visible = fmod(_invuln_timer, 0.2) > 0.1
	else:
		model.visible = true

# -- Helpers ------------------------------------------------------------------

func _get_grid_pos() -> Vector2i:
	return GridUtils.world_to_grid(global_position)

func _has_movement_input() -> bool:
	return bot_input != Vector3.ZERO \
		or Input.is_action_pressed(&"pan_up") or Input.is_action_pressed(&"pan_down") \
		or Input.is_action_pressed(&"pan_left") or Input.is_action_pressed(&"pan_right")

# -- Serialization ------------------------------------------------------------

func serialize() -> Dictionary:
	var inv_data: Array = []
	for slot in inventory:
		if slot == null:
			inv_data.append(null)
		else:
			inv_data.append({item_id = str(slot.item_id), quantity = slot.quantity})
	return {
		position_x = position.x,
		position_y = position.z,  # save grid Y as world Z (backward compat key name)
		position_y_height = position.y,  # actual 3D height
		health = hp,
		stamina = stamina,
		inventory = inv_data,
		is_grounded = is_on_floor(),
		selected_slot = selected_slot,
	}

func deserialize(data: Dictionary) -> void:
	# Backward compat: position_x was world X in 2D (screen), position_y was screen Y
	# In 3D: position_x -> world X, position_y -> world Z (grid Y axis)
	var px: float = data.get("position_x", spawn_position.x)
	var pz: float = data.get("position_y", spawn_position.z)
	var py: float = data.get("position_y_height", data.get("z_height", 0.0))
	position = Vector3(px, py, pz)

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
	velocity.y = data.get("z_velocity", 0.0)
	_update_collision_for_height()
