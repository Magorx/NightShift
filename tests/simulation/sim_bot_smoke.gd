extends "res://tests/bot/bot_player.gd"
## BOT.6 — smoke test: short random bot run, verifies it places buildings without crashing.
##
## Usage:
##   $GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- sim_bot_smoke

func _ready() -> void:
	bot_strategy = STRATEGY_RANDOM
	bot_seed = 123
	bot_duration_seconds = 30.0   # 30 seconds — fast smoke test
	ticks_per_decision = 60
	super._ready()

func run_simulation() -> void:
	await super.run_simulation()
	# run_simulation() calls sim_finish() which quits — assertions below run before that

# Override sim_finish to inject assertions before exit
func sim_finish() -> void:
	var total := BuildingRegistry.unique_buildings.size()
	sim_assert(total >= 3,
		"Bot placed at least 3 buildings (got %d)" % total)
	sim_assert(metrics.decisions_made > 0,
		"Bot made at least one decision (got %d)" % metrics.decisions_made)
	super.sim_finish()
