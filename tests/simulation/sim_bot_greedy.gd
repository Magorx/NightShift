extends "res://tests/bot/bot_player.gd"
## Bot run: greedy builder.
## Seeks deposits, drills them, routes conveyor→sink chains for each.
##
## Usage:
##   $GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- sim_bot_greedy
##   $GODOT --path . --script res://tests/run_simulation.gd -- sim_bot_greedy --visual

func _ready() -> void:
	bot_strategy = STRATEGY_GREEDY
	bot_seed = 42
	bot_duration_seconds = 60.0
	ticks_per_decision = 60
	super._ready()
