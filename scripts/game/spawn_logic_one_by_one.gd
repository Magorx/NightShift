class_name SpawnLogicOneByOne
extends SpawnLogic

## Slowly spawns monsters one at a time with random intervals.
## Aims to spend the budget by mid-night, then dumps whatever is left.

var _timer: float = 0.0
var _elapsed: float = 0.0
var _base_interval: float = 0.0  # computed at start
var _rng := RandomNumberGenerator.new()

func start() -> void:
	_rng.randomize()
	_elapsed = 0.0
	# Target: spend budget over the first half of the fight
	var half_duration := fight_duration * 0.5
	var estimated_spawns := maxi(area.budget / 2, 1)  # rough estimate (cost ~2 each)
	_base_interval = half_duration / float(estimated_spawns)
	_base_interval = clampf(_base_interval, 0.5, 5.0)
	_timer = _rng.randf_range(0.3, _base_interval)

func update(delta: float) -> void:
	if area.get_budget_remaining() <= 0:
		return

	_elapsed += delta
	_timer -= delta

	# Past midpoint — dump everything
	if _elapsed >= fight_duration * 0.5:
		area.finish()
		return

	if _timer <= 0.0:
		# Even the OneByOne spawner goes through the staggered queue: it
		# normally only enqueues 1/spawn so the cost is identical to direct
		# spawning, but it inherits the spawner's hard cap on per-frame work
		# in case multiple areas all hit the same tick.
		if area.spawner != null and area.spawner.has_method("enqueue_spawn"):
			area.spawner.call("enqueue_spawn", Callable(area, "spawn_monster"))
		else:
			area.spawn_monster()
		# Randomize next interval: 50%-150% of base
		_timer = _base_interval * _rng.randf_range(0.5, 1.5)
