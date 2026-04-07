class_name MonsterPool
extends RefCounted

## Per-type object pool for monsters. Avoids the per-spawn cost of allocating
## a CharacterBody3D + collision shapes + HealthComponent + HealthBar3D + .glb
## model instance, which were the dominant cost in the fight-phase lag spikes.
##
## Capacity model (one bucket per monster GDScript):
##   - Starts at INITIAL_CAPACITY (8). Lazy-populated; nothing is created until
##     the first acquire() for that type.
##   - When acquire() is called and free is empty AND total < capacity:
##       create a new instance, total += 1.
##   - When acquire() is called and free is empty AND total == capacity AND
##       capacity < HARD_CAP: capacity *= 2 (so 8 -> 16 -> 32 -> 64), then
##       create a new instance.
##   - When capacity == HARD_CAP and free is empty: return null. Caller (the
##       spawner) skips this spawn — budget is preserved and the next tick
##       can retry once a monster has died and returned to the pool.
##
## Pooled instances are kept across rounds so the .glb resources stay loaded
## (this is the whole point — the user spec was "to keep all of its assets in
## place"). The pool itself lives on `MonsterSpawner` so it has a stable owner.
##
## Reuse contract:
##   acquire(script) returns a node that is either fresh (and detached) or has
##     been previously released (and is still parented to the monster_layer
##     but hidden + physics disabled). Caller must add_child() if detached,
##     set its position, and call reset_for_spawn() to clear leftover state.
##     SpawnArea.spawn_monster does all of this in one place.
##   release(monster) does NOT detach from the scene tree — that would force
##     the physics server to deregister and re-register the body next time,
##     which was visible in profiles as a per-spawn cost spike. Instead the
##     monster's prepare_for_pool() hides it, set_physics_process(false)s it,
##     and removes it from the "monsters" group. The node stays parented for
##     fast reactivation.
##
## A monster knows whether it came from the pool via its `_pool` reference;
## if `_pool == null` (legacy path / sims that bypass the pool) it falls back
## to queue_free on death.

const INITIAL_CAPACITY := 8
const HARD_CAP := 64

## bucket schema: { "free": Array[MonsterBase], "total": int, "capacity": int }
var _buckets: Dictionary = {}

# ── Stats (used by sims / debug HUD) ────────────────────────────────────────
var stat_acquires: int = 0
var stat_releases: int = 0
var stat_creates: int = 0
var stat_cap_hits: int = 0

func _bucket(script: GDScript) -> Dictionary:
	var b: Dictionary = _buckets.get(script, {})
	if b.is_empty():
		b = {"free": [], "total": 0, "capacity": INITIAL_CAPACITY}
		_buckets[script] = b
	return b

## Acquire (or create) a monster of the given script type. Returns null when
## the per-type hard cap has been reached and the free list is empty.
func acquire(script: GDScript) -> MonsterBase:
	stat_acquires += 1
	var b: Dictionary = _bucket(script)
	var free: Array = b["free"]
	if not free.is_empty():
		var m: MonsterBase = free.pop_back()
		m._pool = self
		return m
	# Free list empty — try to grow.
	var total: int = b["total"]
	var capacity: int = b["capacity"]
	if total >= capacity:
		if capacity >= HARD_CAP:
			stat_cap_hits += 1
			return null
		capacity = mini(capacity * 2, HARD_CAP)
		b["capacity"] = capacity
	# Allocate a fresh instance. The monster is detached from the scene tree
	# (caller must add_child) and its `_pool` ref is set so _on_died will
	# release back to us instead of queue_free'ing.
	var fresh: MonsterBase = script.new()
	fresh._pool = self
	b["total"] = total + 1
	stat_creates += 1
	return fresh

## Return a monster to its pool's free list. Does NOT detach from scene tree
## — the caller (MonsterBase._on_died) has already called prepare_for_pool()
## which hid the visuals, disabled physics, and removed it from the "monsters"
## group. Keeping the node parented is faster than remove_child + add_child
## because it avoids physics-server body re-registration on next spawn.
func release(monster: MonsterBase) -> void:
	if monster == null:
		return
	stat_releases += 1
	var script: GDScript = monster.get_script()
	var b: Dictionary = _bucket(script)
	b["free"].append(monster)

## Drop ALL pooled instances and free them. Call this when shutting down a
## game world / changing scenes — leaving them around would leak nodes.
func clear() -> void:
	for script in _buckets.keys():
		var b: Dictionary = _buckets[script]
		for m in b["free"]:
			if is_instance_valid(m):
				m.queue_free()
	_buckets.clear()

## Snapshot pool state for diagnostics: { script_path -> {free, total, capacity} }
func snapshot() -> Dictionary:
	var out: Dictionary = {}
	for script in _buckets.keys():
		var b: Dictionary = _buckets[script]
		var key: String = (script as GDScript).resource_path
		out[key] = {
			"free": b["free"].size(),
			"total": b["total"],
			"capacity": b["capacity"],
		}
	return out
