class_name ScenarioBase
extends "res://tests/simulation/simulation_base.gd"
## Base class for scripted integration-test scenarios.
##
## Subclasses override three methods:
##   setup_map()      — configure deposits, walls, pre-placed buildings
##   setup_monitors() — register numeric metrics to track
##   run_scenario()   — scripted player instructions + assertions
##
## Default mode is visual at 4x speed (window open, watchable).
## Pass --fast for headless CI, or --screenshot-baseline / --screenshot-compare.

var bot: BotController
var monitor: ScenarioMonitor
var map: ScenarioMap

# Override in subclass to set a human-readable name for logs/screenshots
func scenario_name() -> String:
	return "unnamed_scenario"

const SCENARIO_TIMEOUT := 120.0

func _ready() -> void:
	# Use a small map by default for focused scenarios
	sim_map_size = 32

	# Scenarios need round cycling for build/fight phase behavior
	sim_rounds_enabled = true

	# Override sim_name so screenshots land in the right folder
	sim_name = scenario_name()

	# Use longer timeout for scenarios (set before super._ready() which creates the timer)
	timeout_seconds = SCENARIO_TIMEOUT

	# Call parent _ready which loads game_world, clears walls, etc.
	super._ready()

func run_simulation() -> void:
	# Enable creative mode so the bot can place buildings freely
	GameManager.creative_mode = true

	# Initialize subsystems after game_world is loaded
	map = ScenarioMap.new()
	monitor = ScenarioMonitor.new(self)
	bot = BotController.new(self)

	# Let subclass configure the test environment
	setup_map()
	setup_monitors()

	# Rebuild terrain visuals + collision if heights were modified by setup_map
	_rebuild_terrain()

	# Small settle time for physics/visuals to initialize
	await sim_advance_ticks(10)

	# Position camera on the action area
	_setup_camera()

	# Run the actual scenario
	await run_scenario()

	# Print metric report
	monitor.print_report()

	sim_finish()

# ── Subclass interface ───────────────────────────────────────────────────────

func setup_map() -> void:
	pass

func setup_monitors() -> void:
	pass

func run_scenario() -> void:
	pass

# ── Assertion shorthand ─────────────────────────────────────────────────────

func assert_scenario(condition: bool, msg: String) -> void:
	sim_assert(condition, "[%s] %s" % [scenario_name(), msg])

func assert_eq_scenario(actual, expected, msg: String) -> void:
	var ok: bool = actual == expected
	sim_assert(ok, "[%s] %s (expected %s, got %s)" % [scenario_name(), msg, str(expected), str(actual)])

func assert_gt_scenario(actual: float, threshold: float, msg: String) -> void:
	sim_assert(actual > threshold, "[%s] %s (got %.2f, need > %.2f)" % [scenario_name(), msg, actual, threshold])

# ── Terrain rebuild ─────────────────────────────────────────────────────────

## Rebuild terrain visuals + collision after setup_map() modifies heights.
func _rebuild_terrain() -> void:
	if GameManager.terrain_heights.is_empty():
		return
	# Rebuild visual mesh
	if GameManager.terrain_visual_manager:
		GameManager.terrain_visual_manager.build(
			GameManager.map_size,
			GameManager.terrain_tile_types,
			GameManager.terrain_variants,
			GameManager.terrain_heights
		)
	# Replace terrain collision (remove old one if present)
	var old_col := game_world.get_node_or_null("TerrainCollision")
	if old_col:
		old_col.queue_free()
	if GameManager.terrain_visual_manager:
		var shape: ConcavePolygonShape3D = GameManager.terrain_visual_manager.create_box_collision()
		if shape:
			# Keep ground plane at Y=0 as fallback floor
			var body := StaticBody3D.new()
			body.name = "TerrainCollision"
			body.collision_layer = 4
			body.collision_mask = 0
			var col_shape := CollisionShape3D.new()
			col_shape.shape = shape
			body.add_child(col_shape)
			game_world.add_child(body)

# ── Camera helpers ───────────────────────────────────────────────────────────

func _setup_camera() -> void:
	var cam: GameCamera = game_world.camera
	if not cam:
		return
	# Zoom in for scenario-scale view (32x32 map = tight view)
	cam.size = 15.0
	cam._target_size = 15.0
	# Snap to player position
	if GameManager.player:
		cam.snap_to_3d(GameManager.player.position)
