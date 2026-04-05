class_name ScenarioMap
extends RefCounted
## Quick map setup helpers for integration-test scenarios.
## Call these in setup_map() to configure deposits, walls, and pre-placed buildings.

# ── Deposits ─────────────────────────────────────────────────────────────────

## Place a single deposit at a grid position.
func deposit(pos: Vector2i, item_id: StringName, stock: int = -1) -> void:
	GameManager.deposits[pos] = item_id
	if stock > 0:
		GameManager.deposit_stocks[pos] = stock
	else:
		GameManager.deposit_stocks[pos] = -1  # infinite

## Place a rectangular cluster of deposits.
func deposit_cluster(center: Vector2i, item_id: StringName, radius: int = 1, stock: int = -1) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			deposit(center + Vector2i(dx, dy), item_id, stock)

## Place a line of deposits.
func deposit_line(from: Vector2i, to: Vector2i, item_id: StringName, stock: int = -1) -> void:
	var diff := to - from
	var steps := maxi(absi(diff.x), absi(diff.y))
	if steps == 0:
		deposit(from, item_id, stock)
		return
	var step := Vector2i(signi(diff.x), signi(diff.y))
	for i in range(steps + 1):
		deposit(from + step * i, item_id, stock)

# ── Walls ────────────────────────────────────────────────────────────────────

## Place a single wall tile.
func wall(pos: Vector2i) -> void:
	GameManager.walls[pos] = 1

## Place a rectangular wall border.
func wall_border(top_left: Vector2i, bottom_right: Vector2i) -> void:
	for x in range(top_left.x, bottom_right.x + 1):
		wall(Vector2i(x, top_left.y))
		wall(Vector2i(x, bottom_right.y))
	for y in range(top_left.y + 1, bottom_right.y):
		wall(Vector2i(top_left.x, y))
		wall(Vector2i(bottom_right.x, y))

## Place a solid wall rectangle.
func wall_rect(top_left: Vector2i, bottom_right: Vector2i) -> void:
	for x in range(top_left.x, bottom_right.x + 1):
		for y in range(top_left.y, bottom_right.y + 1):
			wall(Vector2i(x, y))

## Clear all walls.
func clear_walls() -> void:
	GameManager.walls.clear()

# ── Buildings (pre-placed) ───────────────────────────────────────────────────

## Pre-place a building (instant, no player involvement).
func building(building_id: StringName, pos: Vector2i, rotation: int = 0) -> bool:
	var result = GameManager.place_building(building_id, pos, rotation)
	return result != null

## Pre-place a line of conveyors.
func conveyor_line(from: Vector2i, to: Vector2i) -> int:
	var placed := 0
	var diff := to - from
	var steps := maxi(absi(diff.x), absi(diff.y))
	if steps == 0:
		if building(&"conveyor", from, 0):
			placed += 1
		return placed
	var step := Vector2i(signi(diff.x), signi(diff.y))
	# Auto-detect rotation from direction
	var rot := 0
	if step == Vector2i.RIGHT:
		rot = 0
	elif step == Vector2i.DOWN:
		rot = 1
	elif step == Vector2i.LEFT:
		rot = 2
	elif step == Vector2i.UP:
		rot = 3
	for i in range(steps + 1):
		var pos := from + step * i
		if building(&"conveyor", pos, rot):
			placed += 1
	return placed

# ── Items ────────────────────────────────────────────────────────────────────

## Spawn a physics item at a grid position.
func spawn_item(pos: Vector2i, item_id: StringName) -> void:
	var world_pos := GridUtils.grid_to_world(pos)
	world_pos.y = 0.3  # above ground so it falls naturally
	PhysicsItem.spawn(item_id, world_pos, Vector3.ZERO)

# ── Player ───────────────────────────────────────────────────────────────────

## Set the player's starting position for this scenario.
func player_start(pos: Vector2i) -> void:
	var player: Player = GameManager.player
	if player:
		var world_pos := GridUtils.grid_to_world(pos)
		player.position = Vector3(world_pos.x, 0.0, world_pos.z)
		player.spawn_position = player.position
		player.velocity = Vector3.ZERO
