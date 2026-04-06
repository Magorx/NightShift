class_name DamageEvent
extends RefCounted

## Lightweight data carrier for damage passing through the pipeline.
## Created by the damage source, delivered to the target's take_damage().

var amount: float
var element: StringName = &""
var source: Node = null

static func create(p_amount: float, p_element: StringName = &"", p_source: Node = null) -> DamageEvent:
	var e := DamageEvent.new()
	e.amount = p_amount
	e.element = p_element
	e.source = p_source
	return e
