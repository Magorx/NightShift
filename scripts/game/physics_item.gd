class_name PhysicsItem
extends RigidBody3D
## A single physical resource item. One item = one resource, no quantity.
## Items are real rigid bodies that roll, bounce, pile up, and get scattered.
## Replaces the old discrete conveyor slot system.

const DESPAWN_TIME := 120.0
const MODEL_SCALE := 2.0
const COLLISION_RADIUS := 0.12
const MODEL_Y := 0.0

# Physics layers
const ITEM_COLLISION_LAYER := 8   # layer 4
const ITEM_COLLISION_MASK := 1 | 2 | 8  # ground(1) + buildings(2) + items(8)

var item_id: StringName = &""
var _despawn_timer: float = DESPAWN_TIME

static var _model_cache: Dictionary = {}

func _ready() -> void:
	add_to_group(&"physics_items")

	# Physics config
	collision_layer = ITEM_COLLISION_LAYER
	collision_mask = ITEM_COLLISION_MASK
	mass = 0.3
	gravity_scale = 1.0
	continuous_cd = true
	physics_material_override = _make_physics_material()

	# Don't collide with player
	if GameManager.player and is_instance_valid(GameManager.player):
		add_collision_exception_with(GameManager.player)

	# Collision shape
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = COLLISION_RADIUS
	col.shape = sphere
	col.position.y = COLLISION_RADIUS
	add_child(col)

	# Visual model
	_add_model()

func _physics_process(delta: float) -> void:
	_despawn_timer -= delta
	if _despawn_timer <= 0:
		queue_free()
		return

	# Auto-sleep items that have settled (Y near ground and very slow)
	if position.y < -5.0:
		queue_free()

func _add_model() -> void:
	var scene := _get_cached_model(item_id)
	if scene:
		var model := scene.instantiate()
		model.name = &"Model"
		model.scale = Vector3(MODEL_SCALE, MODEL_SCALE, MODEL_SCALE)
		model.position.y = MODEL_Y
		add_child(model)
		var anim: AnimationPlayer = model.get_node_or_null("AnimationPlayer")
		if anim and anim.has_animation(&"idle"):
			anim.play(&"idle")
	else:
		# Fallback: colored sphere
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = &"Model"
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.08
		sphere_mesh.height = 0.16
		mesh_inst.mesh = sphere_mesh
		mesh_inst.position.y = MODEL_Y
		var mat := StandardMaterial3D.new()
		var item_def = GameManager.get_item_def(item_id)
		mat.albedo_color = item_def.color if item_def else Color.WHITE
		mesh_inst.material_override = mat
		add_child(mesh_inst)

static func _get_cached_model(id: StringName) -> PackedScene:
	if _model_cache.has(id):
		return _model_cache[id]
	var path := "res://resources/items/models/%s_item.glb" % str(id)
	var scene: PackedScene = null
	if ResourceLoader.exists(path):
		scene = load(path)
	_model_cache[id] = scene
	return scene

static func _make_physics_material() -> PhysicsMaterial:
	var mat := PhysicsMaterial.new()
	mat.friction = 0.6
	mat.bounce = 0.15
	return mat

## Spawn a physics item at the given position with optional impulse.
## Must be called after item_layer is available in GameManager.
static func spawn(id: StringName, pos: Vector3, impulse: Vector3 = Vector3.ZERO) -> PhysicsItem:
	var item := PhysicsItem.new()
	item.item_id = id
	item.position = pos
	if GameManager.item_layer:
		GameManager.item_layer.add_child(item)
	else:
		push_warning("PhysicsItem.spawn: no item_layer, adding to root")
		item.get_tree().current_scene.add_child(item) if item.get_tree() else null
	if impulse != Vector3.ZERO:
		item.apply_central_impulse(impulse)
	return item
