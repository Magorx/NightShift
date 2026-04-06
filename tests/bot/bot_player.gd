extends "res://tests/simulation/simulation_base.gd"
## Autonomous bot that plays the game by itself.
##
## Not runnable directly — subclass in tests/simulation/sim_bot_*.gd and set bot_strategy.
## The BotBrain inner class makes one decision per ticks_per_decision frames:
##   - Moves one grid cell toward its current target (cardinal only, skips walls)
##   - Tries to place a building in an adjacent empty cell
##
## Strategies:
##   RANDOM      — random walk + weighted random placement (BOT.1)
##   GREEDY      — seeks deposits, drill→conveyor→sink chains (BOT.3)
##   LINE_BUILDER — finds deposit + clear axis, builds long production lines (BOT.3)

# Strategy constants (used by sims and BotBrain)
const STRATEGY_RANDOM := 0
const STRATEGY_GREEDY := 1
const STRATEGY_LINE_BUILDER := 2

# ── Configuration ─────────────────────────────────────────────────────────────

var bot_strategy: int = STRATEGY_RANDOM
var bot_seed: int = 42
var bot_duration_seconds: float = 60.0
var ticks_per_decision: int = 60  # 1 decision/sec at 60fps

# ── Runtime ───────────────────────────────────────────────────────────────────

var brain: BotBrain
var metrics: BotMetrics

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	sim_map_size = 32
	sim_rounds_enabled = false
	timeout_seconds = 180.0  # bot sims can place many buildings; give them time
	super._ready()

func run_simulation() -> void:
	EconomyTracker.creative_mode = true

	_setup_deposits()
	await sim_advance_ticks(10)  # let physics settle

	metrics = BotMetrics.new()
	brain = BotBrain.new(self, metrics)
	brain.strategy = bot_strategy
	brain.ticks_per_decision = ticks_per_decision
	brain.bot_duration_seconds = bot_duration_seconds
	brain.bot_seed = bot_seed

	await brain.run()

	metrics.print_report(sim_name)
	sim_finish()

func _setup_deposits() -> void:
	# Clear world-generated deposits so the bot works with a controlled set
	MapManager.deposits.clear()
	MapManager.deposit_stocks.clear()

	var pyromite_positions := [
		Vector2i(10, 10), Vector2i(20, 10), Vector2i(10, 20), Vector2i(20, 20),
		Vector2i(15, 7),  Vector2i(7, 15),  Vector2i(24, 15),
	]
	for pos in pyromite_positions:
		MapManager.deposits[pos] = &"pyromite"
	MapManager.deposits[Vector2i(12, 4)] = &"crystalline"
	MapManager.deposits[Vector2i(25, 18)] = &"crystalline"

# ── BotBrain ──────────────────────────────────────────────────────────────────

class BotBrain:
	## Decision-making AI. One instance per bot run.
	##
	## Each decision tick (every ticks_per_decision frames):
	##   1. Move one grid cell toward current target
	##   2. If at target, pick a new target
	##   3. Try to place a building adjacent to current cell

	var sim: Node           # parent BotPlayer (SimulationBase)
	var metrics: RefCounted # BotMetrics

	var strategy: int = 0   # STRATEGY_* constants from outer script
	var ticks_per_decision: int = 60
	var bot_duration_seconds: float = 60.0
	var bot_seed: int = 42

	var _rng: RandomNumberGenerator
	var _pos: Vector2i          # bot's current grid position
	var _move_target: Vector2i  # destination
	var _known_deposits: Array  # Array of Vector2i
	var _drilled_deposits: Dictionary  # Vector2i -> true (already drilled)

	func _init(p_sim: Node, p_metrics: RefCounted) -> void:
		sim = p_sim
		metrics = p_metrics
		_rng = RandomNumberGenerator.new()
		_known_deposits = []
		_drilled_deposits = {}
		_move_target = Vector2i(-1, -1)

	func run() -> void:
		_rng.seed = bot_seed
		_scan_deposits()

		# Start at player position
		if GameManager.player:
			_pos = GridUtils.world_to_grid(GameManager.player.position)
		else:
			_pos = Vector2i(5, 5)

		_move_target = _pos
		_teleport_player()

		var total_decisions := int(bot_duration_seconds * 60.0 / ticks_per_decision)

		for _i in total_decisions:
			_decide()
			metrics.decisions_made += 1
			await sim.sim_advance_ticks(ticks_per_decision)

	# ── Decision dispatch ─────────────────────────────────────────────────

	func _decide() -> void:
		match strategy:
			0:  # STRATEGY_RANDOM
				_decide_random()
			1:  # STRATEGY_GREEDY
				_decide_greedy()
			2:  # STRATEGY_LINE_BUILDER
				_decide_line_builder()
			_:
				_decide_random()

	# ── Random strategy ───────────────────────────────────────────────────

	func _decide_random() -> void:
		# Move toward target (or pick new one if arrived)
		if _pos == _move_target:
			_move_target = _pick_random_target()
		_step_toward_target()
		# Try placing a building adjacent to current position
		_try_build_adjacent_random()

	# ── Greedy strategy ───────────────────────────────────────────────────

	func _decide_greedy() -> void:
		var nearest := _nearest_undrilled_deposit()
		if nearest == Vector2i(-1, -1):
			_decide_random()  # all deposits drilled — fall back
			return

		# Move toward deposit
		_move_target = nearest
		_step_toward_target()

		# When adjacent to deposit, build drill + route
		if _pos.distance_squared_to(nearest) <= 2:
			_try_place_drill(nearest)
			if _drilled_deposits.has(nearest):
				_route_conveyor_from_drill(nearest)

	# ── Line builder strategy ─────────────────────────────────────────────

	func _decide_line_builder() -> void:
		var deposit := _find_deposit_with_clear_axis()
		if deposit == Vector2i(-1, -1):
			_decide_random()
			return

		# Walk toward deposit
		_move_target = deposit
		_step_toward_target()

		# Build full line when close enough
		if _pos.distance_squared_to(deposit) <= 2:
			_build_production_line(deposit)

	# ── Movement helpers ──────────────────────────────────────────────────

	func _step_toward_target() -> void:
		if _pos == _move_target:
			return

		var diff := _move_target - _pos
		var step := Vector2i.ZERO
		if absi(diff.x) >= absi(diff.y):
			step.x = signi(diff.x)
		else:
			step.y = signi(diff.y)

		var next := _pos + step
		if _is_walkable(next):
			_pos = next
		else:
			# Try perpendicular axis to get unstuck
			if step.x != 0:
				var alt_y: int = signi(diff.y) if diff.y != 0 else 1
				var alt := _pos + Vector2i(0, alt_y)
				if _is_walkable(alt):
					_pos = alt
			else:
				var alt_x: int = signi(diff.x) if diff.x != 0 else 1
				var alt := _pos + Vector2i(alt_x, 0)
				if _is_walkable(alt):
					_pos = alt

		_teleport_player()

	func _pick_random_target() -> Vector2i:
		for _attempt in 30:
			var ox := _rng.randi_range(-10, 10)
			var oy := _rng.randi_range(-10, 10)
			var t := _pos + Vector2i(ox, oy)
			if _is_walkable(t):
				return t
		return _pos

	func _teleport_player() -> void:
		if not GameManager.player:
			return
		var wpos: Vector3 = GridUtils.grid_to_world(_pos)
		GameManager.player.position = Vector3(wpos.x, 0.1, wpos.z)
		GameManager.player.velocity = Vector3.ZERO

	func _is_walkable(pos: Vector2i) -> bool:
		var ms := MapManager.map_size
		if pos.x < 0 or pos.x >= ms or pos.y < 0 or pos.y >= ms:
			return false
		return not MapManager.walls.has(pos)

	func _can_build_at(pos: Vector2i) -> bool:
		var ms := MapManager.map_size
		if pos.x < 0 or pos.x >= ms or pos.y < 0 or pos.y >= ms:
			return false
		if MapManager.walls.has(pos):
			return false
		if BuildingRegistry.buildings.has(pos):
			return false
		return true

	# ── Random build helpers ──────────────────────────────────────────────

	func _try_build_adjacent_random() -> void:
		# Shuffle 4 directions using Fisher-Yates
		var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
		var order: Array[int] = [0, 1, 2, 3]
		for i in range(3, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp: int = order[i]
			order[i] = order[j]
			order[j] = tmp

		for idx in order:
			var adj := _pos + dirs[idx]
			if not _can_build_at(adj):
				continue

			var roll := _rng.randf()
			var building_id := _weighted_building(adj, roll)
			if building_id == &"":
				continue

			var rot := _rng.randi_range(0, 3)
			if _do_place(building_id, adj, rot):
				# 30% chance to chain more conveyors in same direction
				if building_id == &"conveyor" and _rng.randf() < 0.3:
					_chain_conveyors(adj, dirs[idx], rot, _rng.randi_range(1, 4))
				return  # one build per decision tick

	func _weighted_building(pos: Vector2i, roll: float) -> StringName:
		var deposit = MapManager.get_deposit_at(pos)

		# Drill: only on fresh deposits, 15% weight
		if deposit != null and deposit != &"" and not _drilled_deposits.has(pos) and roll < 0.15:
			return &"drill"

		# Conveyor: 50%
		if roll < 0.65:
			return &"conveyor"
		# Smelter: 15%
		if roll < 0.80:
			return &"smelter"
		# Splitter: 10%
		if roll < 0.90:
			return &"splitter"
		# Source: 5%
		if roll < 0.95:
			return &"source"
		# Sink: 5%
		return &"sink"

	func _do_place(building_id: StringName, pos: Vector2i, rot: int) -> bool:
		var result = BuildingRegistry.place_building(building_id, pos, rot)
		if result:
			metrics.record_building(building_id)
			print("[BOT] tick=%d action=place_building type=%s pos=(%d,%d) rot=%d" % [
				sim.tick_count, building_id, pos.x, pos.y, rot])
			if building_id == &"drill" and MapManager.deposits.has(pos):
				_drilled_deposits[pos] = true
			return true
		return false

	func _chain_conveyors(start: Vector2i, dir: Vector2i, rot: int, count: int) -> void:
		var pos := start
		for _i in count:
			pos += dir
			if not _can_build_at(pos):
				break
			_do_place(&"conveyor", pos, rot)

	# ── Greedy helpers ────────────────────────────────────────────────────

	func _nearest_undrilled_deposit() -> Vector2i:
		var best := Vector2i(-1, -1)
		var best_dist := 999999
		for dep in _known_deposits:
			if _drilled_deposits.has(dep):
				continue
			var d := _pos.distance_squared_to(dep)
			if d < best_dist:
				best_dist = d
				best = dep
		return best

	func _try_place_drill(deposit_pos: Vector2i) -> void:
		if _drilled_deposits.has(deposit_pos):
			return
		if BuildingRegistry.buildings.has(deposit_pos):
			_drilled_deposits[deposit_pos] = true  # occupied, mark to skip
			return
		for rot in 4:
			if _do_place(&"drill", deposit_pos, rot):
				return

	func _route_conveyor_from_drill(drill_pos: Vector2i) -> void:
		var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
		for dir in dirs:
			var pos: Vector2i = drill_pos + dir
			if not _can_build_at(pos):
				continue
			var rot := _dir_to_rotation(dir)
			# Place 4 conveyors
			for _i in 4:
				if not _can_build_at(pos):
					break
				_do_place(&"conveyor", pos, rot)
				pos += dir
			# Sink at end
			if _can_build_at(pos):
				_do_place(&"sink", pos, rot)
			return  # done routing this drill

	# ── Line builder helpers ──────────────────────────────────────────────

	func _find_deposit_with_clear_axis() -> Vector2i:
		var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
		for dep in _known_deposits:
			if _drilled_deposits.has(dep):
				continue
			for dir in dirs:
				var ok := true
				var cur: Vector2i = dep + dir
				for _i in 5:
					if not _can_build_at(cur):
						ok = false
						break
					cur += dir
				if ok:
					return dep
		return Vector2i(-1, -1)

	func _build_production_line(deposit: Vector2i) -> void:
		if _drilled_deposits.has(deposit):
			return

		# Find direction with most free space
		var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
		var best_dir := Vector2i.RIGHT
		var best_len := 0
		for dir in dirs:
			var length := 0
			var cur: Vector2i = deposit + dir
			while _can_build_at(cur) and length < 8:
				length += 1
				cur += dir
			if length > best_len:
				best_len = length
				best_dir = dir

		if best_len < 2:
			_drilled_deposits[deposit] = true  # no room, skip this deposit
			return

		var rot := _dir_to_rotation(best_dir)

		# Place drill
		_do_place(&"drill", deposit, rot)

		# Place conveyor line (up to 5 tiles)
		var line_len := mini(best_len - 1, 5)
		var place_pos: Vector2i = deposit + best_dir
		for _i in line_len:
			if not _can_build_at(place_pos):
				break
			_do_place(&"conveyor", place_pos, rot)
			place_pos += best_dir

		# Sink at the end
		if _can_build_at(place_pos):
			_do_place(&"sink", place_pos, rot)

	# ── Utilities ─────────────────────────────────────────────────────────

	func _dir_to_rotation(dir: Vector2i) -> int:
		if dir == Vector2i.RIGHT: return 0
		if dir == Vector2i.DOWN:  return 1
		if dir == Vector2i.LEFT:  return 2
		if dir == Vector2i.UP:    return 3
		return 0

	func _scan_deposits() -> void:
		_known_deposits.clear()
		for pos in MapManager.deposits.keys():
			_known_deposits.append(pos)
		print("[BOT] Found %d deposits" % _known_deposits.size())


# ── BotMetrics ────────────────────────────────────────────────────────────────

class BotMetrics:
	extends RefCounted
	## Tracks what the bot did during a run.

	var buildings_placed: Dictionary = {}  # StringName -> int
	var decisions_made: int = 0

	func record_building(id: StringName) -> void:
		buildings_placed[id] = buildings_placed.get(id, 0) + 1

	func total_buildings() -> int:
		var n := 0
		for k in buildings_placed:
			n += buildings_placed[k]
		return n

	func total_items_delivered() -> int:
		var n := 0
		for _k in EconomyTracker.items_delivered:
			n += EconomyTracker.items_delivered[_k]
		return n

	func print_report(label: String = "") -> void:
		var tag := (" [%s]" % label) if label != "" else ""
		print("=== BOT RUN SUMMARY%s ===" % tag)
		print("  Decisions:       %d" % decisions_made)
		print("  Total buildings: %d" % total_buildings())
		for id in buildings_placed:
			print("    %-16s %d" % [id, buildings_placed[id]])
		print("  Items delivered: %d" % total_items_delivered())
		for id in EconomyTracker.items_delivered:
			print("    %-16s %d" % [id, EconomyTracker.items_delivered[id]])
		print("===================================")
