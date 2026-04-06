class_name SpawnLogicAllTogether
extends SpawnLogic

## Spawns monsters in evenly-spaced batches.
## All budget is spent by 1/3 of the fight duration.

const MIN_BATCHES := 2
const MAX_BATCHES := 5

var _batch_count: int = 0
var _batches_done: int = 0
var _monsters_per_batch: int = 0
var _batch_interval: float = 0.0
var _timer: float = 0.0

func start() -> void:
	# Decide batch count: scale with budget
	_batch_count = clampi(area.budget / 6, MIN_BATCHES, MAX_BATCHES)

	# Budget per batch (in terms of monster count, assuming cost ~2)
	_monsters_per_batch = maxi(ceili(float(area.budget) / 2.0 / float(_batch_count)), 1)

	# Space batches evenly across the first 1/3 of the fight
	var spawn_window := fight_duration / 3.0
	_batch_interval = spawn_window / float(_batch_count)
	_timer = 0.5  # small initial delay
	_batches_done = 0

func update(delta: float) -> void:
	if area.get_budget_remaining() <= 0 or _batches_done >= _batch_count:
		return

	_timer -= delta
	if _timer <= 0.0:
		_spawn_batch()
		_batches_done += 1
		_timer = _batch_interval

		# On last batch, dump any leftover
		if _batches_done >= _batch_count:
			area.finish()

func _spawn_batch() -> void:
	for i in _monsters_per_batch:
		if area.get_budget_remaining() <= 0:
			break
		area.spawn_monster()
