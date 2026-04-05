class_name PhysicsItem
extends RigidBody3D
## A single physical resource item. One item = one resource, no quantity.
## Items are real rigid bodies that roll, bounce, pile up, and get scattered.
## Replaces the old discrete conveyor slot system.

const DESPAWN_TIME := 120.0
const ITEM_MODEL_SCALE := 4.0
const COLLISION_RADIUS := 0.12
const MODEL_Y := 0.0

# Physics layers
const ITEM_COLLISION_LAYER := 8   # layer 4
const GROUND_COLLISION_LAYER := 3  # bit 4
const ITEM_COLLISION_MASK := 4 | 2 | 8  # ground(4) + buildings(2) + items(8)

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
	angular_damp = 5.0
	physics_material_override = _make_physics_material()

	# Visual model first — collision is derived from its geometry
	_add_model()

	# Collision shape from model convex hull (at original scale, not ITEM_MODEL_SCALE)
	var col := CollisionShape3D.new()
	var model := get_node_or_null("Model")
	if model:
		var scale_xform := Transform3D(Basis.from_scale(Vector3.ONE * ITEM_MODEL_SCALE), Vector3.ZERO)
		var points := _gather_vertices(model, scale_xform)
		if points.size() >= 4:
			var convex := ConvexPolygonShape3D.new()
			convex.points = points
			col.shape = convex
		else:
			col.shape = _fallback_sphere()
			col.position.y = COLLISION_RADIUS
	else:
		col.shape = _fallback_sphere()
		col.position.y = COLLISION_RADIUS
	add_child(col)

func _physics_process(delta: float) -> void:
	_despawn_timer -= delta
	if _despawn_timer <= 0:
		queue_free()
		return

	# Auto-sleep items that have settled (Y near ground and very slow)
	if position.y < -5.0:
		queue_free()

func _add_model() -> void:
	var model := create_item_model(item_id)
	model.name = &"Model"
	model.position.y = MODEL_Y
	add_child(model)

## Create a 3D model node for any item. Shared by PhysicsItem, GroundItem, ItemVisualManager.
static func create_item_model(id: StringName) -> Node3D:
	var scene := _get_cached_model(id)
	if scene:
		var model := scene.instantiate()
		model.scale = Vector3.ONE * ITEM_MODEL_SCALE
		return model
	# Fallback: colored sphere
	var mesh_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.08
	sphere_mesh.height = 0.16
	mesh_inst.mesh = sphere_mesh
	var mat := StandardMaterial3D.new()
	var item_def = GameManager.get_item_def(id)
	mat.albedo_color = item_def.color if item_def else Color.WHITE
	mesh_inst.material_override = mat
	return mesh_inst

static func _get_cached_model(id: StringName) -> PackedScene:
	if _model_cache.has(id):
		return _model_cache[id]
	var path := "res://resources/items/models/%s_item.glb" % str(id)
	var scene: PackedScene = null
	if ResourceLoader.exists(path):
		scene = load(path)
	_model_cache[id] = scene
	return scene

static func _gather_vertices(node: Node, xform: Transform3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	if node is MeshInstance3D and node.mesh:
		var mesh: Mesh = node.mesh
		for si in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(si)
			if arrays and arrays[Mesh.ARRAY_VERTEX]:
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for v in verts:
					points.append(xform * v)
	for child in node.get_children():
		var child_xform := xform
		if child is Node3D:
			child_xform = xform * child.transform
		points.append_array(_gather_vertices(child, child_xform))
	return points

static func _fallback_sphere() -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = COLLISION_RADIUS
	return s

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
	item.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	if GameManager.item_layer:
		GameManager.item_layer.add_child(item)
	else:
		push_warning("PhysicsItem.spawn: no item_layer, adding to root")
		if item.get_tree():
			item.get_tree().current_scene.add_child(item)
	if impulse != Vector3.ZERO:
		item.apply_central_impulse(impulse)
	return item
