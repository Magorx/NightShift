class_name Projectile
extends Area3D

## Simple projectile that moves in a straight line and damages on contact.
## Created by TurretBehavior; self-destructs after lifetime expires or on hit.
##
## Collision setup: layer 0 (no own layer), mask = layer 5 (monsters).
## The projectile creates its own CollisionShape3D and MeshInstance3D in _ready.

var velocity: Vector3 = Vector3.ZERO
var event: DamageEvent
var lifetime: float = 3.0

var _age: float = 0.0

func _ready() -> void:
	# Collision: no own layer, detect layer 5 (monsters).
	collision_layer = 0
	collision_mask = 16  # bit 5 = value 16

	# CollisionShape3D -- small sphere.
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	col.shape = shape
	add_child(col)

	# MeshInstance3D -- visible sphere.
	var mesh_inst := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	mesh_inst.mesh = sphere_mesh
	# Simple unlit material so it is visible.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2)  # warm yellow default
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# Connect body_entered for monster hits.
	body_entered.connect(_on_body_entered)

	# Also detect Area3D targets (some monsters may be Area3D).
	area_entered.connect(_on_area_entered)

	# Enable contact monitoring.
	monitoring = true
	monitorable = false

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	_try_damage(body)
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	_try_damage(area)
	queue_free()

func _try_damage(target: Node) -> void:
	if event and target.has_method("take_damage"):
		target.take_damage(event)
