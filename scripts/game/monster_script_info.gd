class_name MonsterScriptInfo
extends RefCounted

## Tiny static cache for per-monster-type metadata that would otherwise force
## us to instantiate a monster just to read a property. Currently caches
## budget_cost (used by SpawnArea before deciding to allocate from the pool).
##
## Cache is populated lazily on first lookup with one throwaway `script.new()`
## per script. After that the value is reused for the lifetime of the process.

static var _cost_cache: Dictionary = {}

## Get the spawn budget cost for a monster type. First call instantiates the
## script once to read its `budget_cost`; subsequent calls hit the cache.
static func get_budget_cost(script: GDScript) -> int:
	if _cost_cache.has(script):
		return _cost_cache[script]
	var temp: MonsterBase = script.new()
	var cost: int = temp.budget_cost
	temp.free()
	_cost_cache[script] = cost
	return cost
