class_name HealthComponent
extends Node

## General-purpose HP node. Attach to any entity that can take damage:
## buildings, monsters, player, destructibles.

signal damaged(amount: float, current: float)
signal healed(amount: float, current: float)
signal died()

@export var max_hp: float = 100.0

var current_hp: float:
	get:
		return current_hp
	set(value):
		current_hp = clampf(value, 0.0, max_hp)

var is_dead: bool:
	get:
		return current_hp <= 0.0

func _ready() -> void:
	current_hp = max_hp

func damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var prev := current_hp
	current_hp -= amount
	damaged.emit(prev - current_hp, current_hp)
	if current_hp <= 0.0:
		died.emit()

func revive(hp_amount: float = -1.0) -> void:
	var prev := current_hp
	current_hp = hp_amount if hp_amount > 0.0 else max_hp
	# Emit healed so HealthBar3D and other listeners refresh — without this,
	# pooled monsters returning from death would still show an empty bar.
	healed.emit(current_hp - prev, current_hp)

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	var prev := current_hp
	current_hp += amount
	healed.emit(current_hp - prev, current_hp)

func get_hp_fraction() -> float:
	if max_hp <= 0.0:
		return 0.0
	return current_hp / max_hp

## Visual damage state: 0 = healthy, 1 = light cracks, 2 = scarred, 3 = heavy damage.
func get_damage_state() -> int:
	var frac := get_hp_fraction()
	if frac > 0.75:
		return 0
	elif frac > 0.50:
		return 1
	elif frac > 0.25:
		return 2
	return 3
