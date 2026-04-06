class_name AimComponent
extends Node

## General-purpose aiming component. Smoothly rotates toward a target position.
## Attach as a child of any Node3D (turret, monster, player) that needs to aim.
##
## API:
##   aim.target_position = Vector3(...)   -- set where to aim
##   aim.update_aim(delta)                -- call from _process/_physics_process
##   aim.get_aim_basis() -> Basis         -- basis looking at target from parent
##   aim.is_aimed_at_target(threshold) -> bool

## Where to aim in world space.
var target_position: Vector3 = Vector3.ZERO

## Rotation speed in radians/sec. High values (10+) give near-instant snap.
var turn_speed: float = 10.0

## Returns a Basis looking from the parent's global position toward target_position.
## Y-up convention; returns identity if parent is not a Node3D or positions overlap.
func get_aim_basis() -> Basis:
	var parent_3d := get_parent() as Node3D
	if not parent_3d:
		return Basis.IDENTITY
	var origin := parent_3d.global_position
	var direction := (target_position - origin)
	# Flatten to XZ plane for turret-style rotation (no pitch).
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return Basis.IDENTITY
	return Basis.looking_at(direction.normalized())

## Smoothly rotate the parent Node3D toward target_position.
func update_aim(delta: float) -> void:
	var parent_3d := get_parent() as Node3D
	if not parent_3d:
		return
	var desired := get_aim_basis()
	if desired == Basis.IDENTITY:
		return
	var current := parent_3d.global_transform.basis
	var current_quat := Quaternion(current).normalized()
	var desired_quat := Quaternion(desired).normalized()
	var t := clampf(turn_speed * delta, 0.0, 1.0)
	var result := current_quat.slerp(desired_quat, t)
	parent_3d.global_transform.basis = Basis(result)

## Returns true if the parent is facing target_position within threshold radians.
func is_aimed_at_target(threshold: float = 0.1) -> bool:
	var parent_3d := get_parent() as Node3D
	if not parent_3d:
		return false
	var origin := parent_3d.global_position
	var to_target := (target_position - origin)
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return true
	var forward := -parent_3d.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return true
	return forward.normalized().angle_to(to_target.normalized()) <= threshold
