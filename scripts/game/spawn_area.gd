class_name SpawnArea
extends Node3D

## A physical area in the world where monsters spawn during a fight phase.
## Has a shape (square or line), a budget, a monster pool, and a spawn logic.

signal budget_exhausted()
signal monster_spawned(monster: MonsterBase)

# ── Shape ───────────────────────────────────────────────────────────────────
enum Shape { SQUARE, LINE }

var shape: Shape = Shape.SQUARE
var cells: Array[Vector2i] = []  # all grid cells this area covers

# ── Budget & Pool ───────────────────────────────────────────────────────────
var budget: int = 0
var monster_pool: Array[GDScript] = []  # scripts extending MonsterBase, instantiated with .new()
var _budget_remaining: int = 0

# ── Logic ───────────────────────────────────────────────────────────────────
var logic: SpawnLogic = null

# ── References ──────────────────────────────────────────────────────────────
var pathfinding: MonsterPathfinding
var monster_layer: Node3D

# ── Visuals ─────────────────────────────────────────────────────────────────
var _particles: GPUParticles3D
var _area_mesh: MeshInstance3D

func _ready() -> void:
	_budget_remaining = budget
	_setup_visuals()
	if logic:
		logic.area = self
		logic.start()

func _physics_process(delta: float) -> void:
	if _budget_remaining <= 0:
		return
	if logic:
		logic.update(delta)

# ── API ─────────────────────────────────────────────────────────────────────

func get_budget_remaining() -> int:
	return _budget_remaining

func spawn_monster() -> MonsterBase:
	if _budget_remaining <= 0 or monster_pool.is_empty():
		return null

	# Pick a random affordable monster from the pool
	var affordable: Array[GDScript] = []
	for script in monster_pool:
		var temp: MonsterBase = script.new()
		if temp.budget_cost <= _budget_remaining:
			affordable.append(script)
		temp.free()
	if affordable.is_empty():
		_budget_remaining = 0
		budget_exhausted.emit()
		return null

	var chosen: GDScript = affordable.pick_random()
	var monster: MonsterBase = chosen.new()
	_budget_remaining -= monster.budget_cost

	# Pick a random cell within the area to spawn at
	var cell: Vector2i = cells.pick_random()
	monster.pathfinding = pathfinding

	if monster_layer:
		monster_layer.add_child(monster)
	else:
		add_child(monster)

	var world_pos := GridUtils.grid_to_world(cell)
	world_pos.y = MapManager.get_terrain_height(cell) + 0.5
	monster.global_position = world_pos
	monster_spawned.emit(monster)

	if _budget_remaining <= 0:
		budget_exhausted.emit()

	return monster

func finish() -> void:
	# Dump all remaining budget immediately
	while _budget_remaining > 0:
		var m := spawn_monster()
		if m == null:
			break

func cleanup() -> void:
	if logic:
		logic.stop()
	# Fade out visuals
	var tween := create_tween()
	if _area_mesh:
		tween.tween_property(_area_mesh, "transparency", 1.0, 1.0)
	if _particles:
		_particles.emitting = false
	tween.tween_callback(queue_free)

# ── Visuals ─────────────────────────────────────────────────────────────────

func _setup_visuals() -> void:
	if cells.is_empty():
		return

	# Compute AABB from cells
	var min_cell := cells[0]
	var max_cell := cells[0]
	for c in cells:
		min_cell = Vector2i(mini(min_cell.x, c.x), mini(min_cell.y, c.y))
		max_cell = Vector2i(maxi(max_cell.x, c.x), maxi(max_cell.y, c.y))

	var center_grid := Vector2(
		(min_cell.x + max_cell.x) / 2.0,
		(min_cell.y + max_cell.y) / 2.0
	)
	var center_world := GridUtils.grid_to_world(Vector2i(roundi(center_grid.x), roundi(center_grid.y)))
	center_world.y = MapManager.get_terrain_height(Vector2i(roundi(center_grid.x), roundi(center_grid.y))) + 0.05
	global_position = center_world

	var size_x := float(max_cell.x - min_cell.x + 1)
	var size_z := float(max_cell.y - min_cell.y + 1)

	# Ground highlight mesh
	_area_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size_x, size_z)
	_area_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.15, 0.05, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	_area_mesh.material_override = mat
	add_child(_area_mesh)

	# Particles
	_particles = GPUParticles3D.new()
	_particles.amount = int(size_x * size_z * 8)
	_particles.lifetime = 1.5
	_particles.visibility_aabb = AABB(Vector3(-size_x / 2.0, 0, -size_z / 2.0), Vector3(size_x, 3.0, size_z))

	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc_mat.emission_box_extents = Vector3(size_x / 2.0, 0.1, size_z / 2.0)
	proc_mat.direction = Vector3(0, 1, 0)
	proc_mat.spread = 15.0
	proc_mat.initial_velocity_min = 0.5
	proc_mat.initial_velocity_max = 1.5
	proc_mat.gravity = Vector3(0, 0.2, 0)
	proc_mat.scale_min = 0.03
	proc_mat.scale_max = 0.08

	var color_ramp := GradientTexture1D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.3, 0.05, 0.9))
	gradient.add_point(0.5, Color(0.9, 0.1, 0.0, 0.6))
	gradient.set_color(1, Color(0.4, 0.0, 0.0, 0.0))
	color_ramp.gradient = gradient
	proc_mat.color_ramp = color_ramp

	_particles.process_material = proc_mat

	# Particle mesh: small sphere
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.albedo_color = Color(1.0, 0.5, 0.1)
	sphere_mat.emission_enabled = true
	sphere_mat.emission = Color(1.0, 0.3, 0.0)
	sphere_mat.emission_energy_multiplier = 3.0
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = sphere_mat
	_particles.draw_pass_1 = sphere

	add_child(_particles)
