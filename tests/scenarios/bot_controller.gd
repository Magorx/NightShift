class_name BotController
extends RefCounted
## Scripted player controller for integration-test scenarios.
##
## Moves the real CharacterBody3D player physically through the world,
## places buildings via GameManager API (player positioned nearby),
## and triggers player actions (mine, pickup, drop, jump).
##
## All commands are async (use await) and wait for completion.

var _sim: Node  # ScenarioBase (has sim_advance_* helpers)
var _player: Player
var _log_enabled: bool = true

const ARRIVE_THRESHOLD := 0.3  # world units — close enough to target
const MOVE_TIMEOUT := 600  # ticks before giving up on walk_to
const MINE_TIMEOUT := 120  # ticks for a single mine action

func _init(sim: Node) -> void:
	_sim = sim
	_player = GameManager.player
	if not _player:
		printerr("[BOT] No player found in GameManager!")

# ── Movement ─────────────────────────────────────────────────────────────────

## Walk the player physically to a grid position.
## Sets velocity each frame toward the target until arrival.
func walk_to(pos: Vector2i) -> bool:
	var target := GridUtils.grid_to_world(pos)
	_log("walk_to %s (world %.1f, %.1f)" % [str(pos), target.x, target.z])

	@warning_ignore("untyped_declaration")
	var arrived = await _sim.sim_advance_until(func() -> bool:
		var diff := Vector3(target.x - _player.position.x, 0.0, target.z - _player.position.z)
		var dist := diff.length()
		if dist < ARRIVE_THRESHOLD:
			_player.bot_input = Vector3.ZERO
			return true
		# Set bot_input direction — player._handle_movement() uses this
		_player.bot_input = diff.normalized()
		# Auto-jump when facing a terrain step
		_auto_jump_if_step()
		return false
	, MOVE_TIMEOUT)

	_player.bot_input = Vector3.ZERO
	if not arrived:
		_log("FAILED walk_to %s (stuck at %.1f, %.1f)" % [
			str(pos), _player.position.x, _player.position.z])
	return arrived

## Teleport the player instantly to a grid position (no physics traversal).
func teleport_to(pos: Vector2i) -> void:
	var wpos := GridUtils.grid_to_world(pos)
	var terrain_y: float = MapManager.get_terrain_height(pos)
	_player.position = Vector3(wpos.x, terrain_y + 0.1, wpos.z)
	_player.velocity = Vector3.ZERO
	_log("teleport_to %s (terrain_y=%.2f)" % [str(pos), terrain_y])
	await _sim.sim_advance_ticks(5)  # let physics settle

## Sprint to a grid position (faster, drains stamina).
## Auto-jump when the bot is on the floor and the terrain ahead is higher.
## Uses bot_input direction (not velocity, which may be zeroed by step-block).
func _auto_jump_if_step() -> void:
	if not _player.is_on_floor():
		return
	var move_dir := _player.bot_input
	if move_dir.length_squared() < 0.01:
		return
	var look_ahead := _player.position + Vector3(move_dir.x, 0.0, move_dir.z).normalized() * 0.6
	var ahead_grid := GridUtils.world_to_grid(look_ahead)
	var current_grid := GridUtils.world_to_grid(_player.position)
	if ahead_grid == current_grid:
		return
	var h_ahead: float = MapManager.get_terrain_height(ahead_grid)
	var h_current: float = MapManager.get_terrain_height(current_grid)
	if h_ahead > h_current + 0.25:
		_player._try_jump()

func sprint_to(pos: Vector2i) -> bool:
	var target := GridUtils.grid_to_world(pos)
	_log("sprint_to %s" % str(pos))

	_player.bot_sprint = true
	@warning_ignore("untyped_declaration")
	var arrived = await _sim.sim_advance_until(func() -> bool:
		var diff := Vector3(target.x - _player.position.x, 0.0, target.z - _player.position.z)
		if diff.length() < ARRIVE_THRESHOLD:
			_player.bot_input = Vector3.ZERO
			_player.bot_sprint = false
			return true
		_player.bot_input = diff.normalized()
		_auto_jump_if_step()
		return false
	, MOVE_TIMEOUT)
	_player.bot_input = Vector3.ZERO
	_player.bot_sprint = false
	return arrived

# ── Building ─────────────────────────────────────────────────────────────────

## Place a building at a grid position. Bot walks nearby first for realism,
## then calls GameManager.place_building.
func place(building_id: StringName, pos: Vector2i, rotation: int = 0) -> bool:
	# Walk near the build location (1 tile away)
	var approach_pos := pos + Vector2i(-1, 0)
	await walk_to(approach_pos)

	var result = BuildingRegistry.place_building(building_id, pos, rotation)
	var ok := result != null
	_log("place %s at %s rot=%d -> %s" % [building_id, str(pos), rotation, "OK" if ok else "FAIL"])
	await _sim.sim_advance_ticks(5)  # settle
	return ok

## Place a building instantly without walking (for batch setup).
func place_at(building_id: StringName, pos: Vector2i, rotation: int = 0) -> bool:
	var result = BuildingRegistry.place_building(building_id, pos, rotation)
	var ok := result != null
	_log("place_at %s at %s rot=%d -> %s" % [building_id, str(pos), rotation, "OK" if ok else "FAIL"])
	return ok

## Place a line of conveyors from start to end (inclusive).
func place_conveyor_line(from: Vector2i, to: Vector2i, rotation: int = 0) -> int:
	var placed := 0
	var diff := to - from
	var steps := maxi(absi(diff.x), absi(diff.y))
	var step := Vector2i(signi(diff.x), signi(diff.y))
	# Auto-detect rotation from direction
	var auto_rot := rotation
	if step == Vector2i.RIGHT:
		auto_rot = 0
	elif step == Vector2i.DOWN:
		auto_rot = 1
	elif step == Vector2i.LEFT:
		auto_rot = 2
	elif step == Vector2i.UP:
		auto_rot = 3

	for i in range(steps + 1):
		var pos := from + step * i
		if place_at(&"conveyor", pos, auto_rot):
			placed += 1
	_log("conveyor_line %s -> %s: %d placed" % [str(from), str(to), placed])
	await _sim.sim_advance_ticks(5)
	return placed

## Remove a building at a grid position.
func remove(pos: Vector2i) -> void:
	BuildingRegistry.remove_building(pos)
	_log("remove at %s" % str(pos))
	await _sim.sim_advance_ticks(5)

# ── Mining ───────────────────────────────────────────────────────────────────

## Mine ore at a grid position by walking there and calling mine logic directly.
## Returns true if ore was collected.
func mine_at(pos: Vector2i) -> bool:
	await walk_to(pos)

	var deposit_id: StringName = MapManager.get_deposit_at(pos)
	if deposit_id == null or deposit_id == &"":
		_log("mine_at %s -> no deposit" % str(pos))
		return false

	# Simulate hand mining: directly add the item (bypasses mouse-based mining input)
	var leftover := _player.add_item(deposit_id, 1)
	var ok := leftover == 0
	_log("mine_at %s (%s) -> %s" % [str(pos), deposit_id, "OK" if ok else "inventory full"])
	if ok:
		_player.item_mined.emit(deposit_id)
	await _sim.sim_advance_ticks(int(Player.HAND_MINE_TIME * 60))  # wait mining duration
	return ok

## Mine N ores from a deposit position.
func mine_n(pos: Vector2i, count: int) -> int:
	var mined := 0
	for i in count:
		if await mine_at(pos):
			mined += 1
		else:
			break
	return mined

# ── Inventory ────────────────────────────────────────────────────────────────

## Pick up the nearest physics item within range.
func pickup() -> bool:
	_player._try_pickup()
	var before_count := _count_total_items()
	await _sim.sim_advance_ticks(5)
	var after_count := _count_total_items()
	var ok := after_count > before_count
	_log("pickup -> %s (items: %d -> %d)" % ["OK" if ok else "nothing", before_count, after_count])
	return ok

## Drop an item from the selected slot.
func drop(drop_stack: bool = false) -> void:
	_player._try_drop(drop_stack)
	_log("drop (stack=%s)" % str(drop_stack))
	await _sim.sim_advance_ticks(5)

## Give items directly to player inventory (test setup helper).
func give_item(item_id: StringName, quantity: int = 1) -> int:
	var leftover := _player.add_item(item_id, quantity)
	_log("give_item %s x%d (leftover=%d)" % [item_id, quantity, leftover])
	return leftover

## Select an inventory slot.
func select_slot(slot: int) -> void:
	_player.selected_slot = slot

# ── Actions ──────────────────────────────────────────────────────────────────

## Make the player jump. Advances only 1 tick so caller can observe the arc.
func jump() -> bool:
	if not _player.is_on_floor():
		_log("jump -> not on floor")
		return false
	_player._try_jump()
	_log("jump")
	await _sim.sim_advance_ticks(1)
	return true

## Take damage (for testing health/death scenarios).
func take_damage(amount: float) -> void:
	_player.take_damage(amount)
	_log("take_damage %.0f (hp=%.0f)" % [amount, _player.hp])

## Face a specific direction.
func face(direction: Vector3) -> void:
	_player.facing_direction = direction.normalized()

## Face toward a grid position.
func face_toward(pos: Vector2i) -> void:
	var target := GridUtils.grid_to_world(pos)
	var diff := Vector3(target.x - _player.position.x, 0.0, target.z - _player.position.z)
	if diff.length() > 0.01:
		_player.facing_direction = diff.normalized()

# ── Time ─────────────────────────────────────────────────────────────────────

## Wait for N seconds of game time.
func wait(seconds: float) -> void:
	_log("wait %.1fs (%d ticks)" % [seconds, int(seconds * 60)])
	await _sim.sim_advance_seconds(seconds)

## Wait until a condition is met or timeout.
func wait_until(condition: Callable, timeout_seconds: float = 10.0) -> bool:
	@warning_ignore("untyped_declaration")
	var result = await _sim.sim_advance_until(condition, int(timeout_seconds * 60))
	return result

## Advance exactly N ticks.
func tick(count: int) -> void:
	await _sim.sim_advance_ticks(count)

# ── Queries ──────────────────────────────────────────────────────────────────

## Get the player's current grid position.
func get_grid_pos() -> Vector2i:
	return GridUtils.world_to_grid(_player.global_position)

## Get the player's world position.
func get_world_pos() -> Vector3:
	return _player.position

## Get the player's HP.
func get_hp() -> float:
	return _player.hp

## Check if the player is alive.
func is_alive() -> bool:
	return not _player._is_dead

## Get item count in player inventory.
func item_count(item_id: StringName) -> int:
	return _player.count_item(item_id)

## Get total items across all slots.
func _count_total_items() -> int:
	var total := 0
	for slot in _player.inventory:
		if slot != null:
			total += slot.quantity
	return total

# ── Logging ──────────────────────────────────────────────────────────────────

func _log(msg: String) -> void:
	if _log_enabled:
		print("[BOT] tick=%d %s" % [_sim.tick_count, msg])
