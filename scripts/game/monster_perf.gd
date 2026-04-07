class_name MonsterPerf
extends RefCounted

## Lightweight static perf counters used by sim_monster_attack_perf.gd to
## attribute frame time across the suspect functions in MonsterBase /
## MonsterPathfinding. Disabled by default — flip `enabled` from a sim before
## the section you want to measure.
##
## All counters are class-static so the production code can call into them
## without holding a reference. Cost when disabled = one bool check.

static var enabled: bool = false

# Call counts
static var separation_calls: int = 0
static var find_target_calls: int = 0
static var damage_nearby_calls: int = 0
static var sample_factory_calls: int = 0
static var register_goal_calls: int = 0
static var flush_dirty_calls: int = 0
static var ff_compute_calls: int = 0

# Total microseconds spent inside each function
static var separation_usec: int = 0
static var find_target_usec: int = 0
static var damage_nearby_usec: int = 0
static var sample_factory_usec: int = 0
static var register_goal_usec: int = 0
static var ff_compute_usec: int = 0

# Per-frame totals: how much wall time monsters consumed in their _physics_process
# this frame, plus a sub-bucket for move_and_slide. Read by the sim once per
# physics tick and reset to 0.
static var frame_physics_usec: int = 0
static var frame_move_slide_usec: int = 0
static var frame_attacking_count: int = 0
static var frame_moving_count: int = 0
static var frame_chasing_count: int = 0

static func reset() -> void:
	separation_calls = 0
	find_target_calls = 0
	damage_nearby_calls = 0
	sample_factory_calls = 0
	register_goal_calls = 0
	flush_dirty_calls = 0
	ff_compute_calls = 0
	separation_usec = 0
	find_target_usec = 0
	damage_nearby_usec = 0
	sample_factory_usec = 0
	register_goal_usec = 0
	ff_compute_usec = 0

static func snapshot() -> Dictionary:
	return {
		"separation": separation_calls,
		"find_target": find_target_calls,
		"damage_nearby": damage_nearby_calls,
		"sample_factory": sample_factory_calls,
		"register_goal": register_goal_calls,
		"flush_dirty": flush_dirty_calls,
		"ff_compute": ff_compute_calls,
		"separation_usec": separation_usec,
		"find_target_usec": find_target_usec,
		"damage_nearby_usec": damage_nearby_usec,
		"sample_factory_usec": sample_factory_usec,
		"register_goal_usec": register_goal_usec,
		"ff_compute_usec": ff_compute_usec,
	}
