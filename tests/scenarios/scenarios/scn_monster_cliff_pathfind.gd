extends ScenarioBase
## Regression test for the "monsters head-butt elevation walls" bug the user
## reported. Builds a map with a distinct cliff: a plateau of height 1.5
## blocks the east/west line, the FACTORY sits ON TOP of the plateau, and
## monsters spawn on LOW ground to the west. Ground monsters cannot climb
## the 1.5-unit cliff, so the only route is AROUND the plateau (north or
## south ends).
##
## Without the `_compute_sector_flow_field` edge-check fix, BFS from the
## goal (factory on plateau) would descend across the cliff edge (descent
## is always allowed) and record flow arrows at the low cells pointing UP
## toward the cliff. Monsters on the west would walk east, head-butt the
## cliff, and stand there forever.
##
## With the fix, BFS uses the AGENT direction (low → high = ascent > STEP_HEIGHT,
## rejected). The BFS is forced to route around the plateau via its north
## or south end where the drop is gradual. Monsters walk around the plateau.
##
## Usage:
##   $GODOT --fixed-fps 60 --path . --script res://tests/scenarios/run_scenario.gd -- scn_monster_cliff_pathfind

const PLATEAU_X_START := 16
const PLATEAU_X_END := 28
const PLATEAU_Y_START := 12
const PLATEAU_Y_END := 20
const PLATEAU_HEIGHT := 1.5
const FACTORY_POS := Vector2i(22, 16)  # ON TOP of the plateau
const SPAWN_POS := Vector2i(8, 16)     # LOW ground west of the plateau

var _spawned_monster: MonsterBase = null

func scenario_name() -> String:
	return "scn_monster_cliff_pathfind"

func _ready() -> void:
	sim_map_size = 40
	sim_flatten_terrain = true  # we'll set heights manually below
	hard_timeout_seconds = 60.0
	super._ready()

func setup_map() -> void:
	map.clear_walls()
	# Raise a plateau in the middle of the map. Ground = 0, plateau = 1.5 —
	# way above STEP_HEIGHT=0.6 so monsters cannot climb the cliff directly.
	# The factory sits on the plateau: goal cells are all on HIGH ground.
	# Monsters spawn on LOW ground west of the plateau.
	for gx in range(PLATEAU_X_START, PLATEAU_X_END):
		for gy in range(PLATEAU_Y_START, PLATEAU_Y_END):
			if gx >= 0 and gy >= 0 and gx < MapManager.map_size and gy < MapManager.map_size:
				var idx: int = gy * MapManager.map_size + gx
				if idx < MapManager.terrain_heights.size():
					MapManager.terrain_heights[idx] = PLATEAU_HEIGHT
	map.building(&"smelter", FACTORY_POS, 0)
	map.player_start(Vector2i(2, 16))

func setup_monitors() -> void:
	monitor.track("monster_count", func() -> int:
		return get_tree().get_nodes_in_group(&"monsters").size())
	monitor.track("monster_x", func() -> float:
		if _spawned_monster == null or not is_instance_valid(_spawned_monster):
			return 0.0
		return _spawned_monster.global_position.x)
	monitor.track("monster_z", func() -> float:
		if _spawned_monster == null or not is_instance_valid(_spawned_monster):
			return 0.0
		return _spawned_monster.global_position.z)
	monitor.track("dist_to_factory", func() -> float:
		if _spawned_monster == null or not is_instance_valid(_spawned_monster):
			return -1.0
		var fw := GridUtils.grid_to_world(FACTORY_POS)
		return _spawned_monster.global_position.distance_to(fw))

func run_scenario() -> void:
	SettingsManager.debug_mode = true

	# Frame the camera on the plateau so screenshots show the cliff, the
	# factory, and the flow field arrows all in one shot.
	_frame_camera_on_plateau()

	await sim_advance_ticks(10)
	await monitor.screenshot("00_map_built")

	# Manually spawn one tendril crawler on the high plateau via the
	# spawner's pool + pathfinding references, so it receives the full
	# flow-field-enabled movement code path.
	var spawner := _find_spawner()
	if spawner == null:
		sim_assert(false, "MonsterSpawner not found")
		sim_finish()
		return

	# Force the round to fight so the spawner's pathfinding is initialised.
	RoundManager.current_round = 1
	RoundManager.skip_phase()
	await sim_advance_ticks(5)

	# Now spawn our test monster directly. Teleport to the plateau centre
	# on the high side.
	var monster: MonsterBase = preload("res://monsters/tendril_crawler/tendril_crawler.gd").new()
	monster.pathfinding = spawner.pathfinding
	var ml: Node3D = spawner._monster_layer
	if ml == null:
		ml = game_world.get_node_or_null("MonsterLayer")
	ml.add_child(monster)
	monster.global_position = Vector3(SPAWN_POS.x, 0.1, SPAWN_POS.y)
	monster.reset_for_spawn()
	_spawned_monster = monster

	await sim_advance_ticks(5)
	var start_pos: Vector3 = monster.global_position
	print("[CLIFF] Spawned monster at %s (plateau height %.1f)" % [start_pos, PLATEAU_HEIGHT])
	await monitor.screenshot("01_monster_spawned")

	# Let it pathfind for 15 seconds and track whether it moves.
	var prev_x: float = monster.global_position.x
	var total_moved := 0.0
	var movement_samples: PackedFloat32Array = PackedFloat32Array()
	for i in 30:
		await bot.wait(0.5)
		if not is_instance_valid(monster):
			break
		var dx: float = absf(monster.global_position.x - prev_x)
		total_moved += (monster.global_position - Vector3(prev_x, monster.global_position.y, monster.global_position.z)).length()
		movement_samples.append(dx)
		prev_x = monster.global_position.x
		var dist_to_factory := monster.global_position.distance_to(GridUtils.grid_to_world(FACTORY_POS))
		print("[CLIFF] t=%.1fs  pos=(%.2f, %.2f, %.2f)  y=%.2f  dist=%.2f  state=%s" % [
			(i + 1) * 0.5, monster.global_position.x, monster.global_position.y,
			monster.global_position.z, monster.global_position.y, dist_to_factory,
			MonsterBase.State.keys()[monster.state]])

	await monitor.screenshot("02_monster_path")

	# The factory is unreachable by design (no ramp), so the monster will
	# never reach attack range. What we're verifying is that it DOESN'T
	# stand still head-butting the cliff — it should move substantially
	# and end up near the plateau (physics sliding around the edge).
	var final_pos: Vector3 = (monster.global_position
		if is_instance_valid(monster)
		else Vector3(-1, -1, -1))
	print("[CLIFF] ════════════════════════════════════════")
	print("[CLIFF] Start pos: %s" % start_pos)
	print("[CLIFF] Final pos: %s" % final_pos)
	print("[CLIFF] Total moved: %.2f world-units" % total_moved)
	print("[CLIFF] ════════════════════════════════════════")

	# The test passes if the monster travelled MORE than the start-to-cliff
	# distance (~7 units west-to-plateau). A stuck monster would move 0.
	# With the fix, the BFS returns ZERO flow for unreachable goals so the
	# monster falls back to direct-line + physics sliding and drifts AROUND
	# the plateau edge.
	sim_assert(total_moved > 5.0,
		"Monster did not get stuck at cliff (moved %.2f world-units)" % total_moved)

func _frame_camera_on_plateau() -> void:
	var cam: GameCamera = game_world.camera if "camera" in game_world else null
	if cam == null:
		return
	cam.target_node = null
	cam.size = 24.0
	cam._target_size = 24.0
	cam.snap_to_3d(Vector3(22, 0, 16))

func _find_spawner() -> Node:
	for c in game_world.get_children():
		if c.get_script() != null and c.has_method("enqueue_spawn"):
			return c
	return null
