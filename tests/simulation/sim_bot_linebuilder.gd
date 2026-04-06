extends "res://tests/bot/bot_player.gd"
## Bot run: line builder.
## Finds deposits with a clear axis, builds drill → conveyor line → sink.
## Produces the most efficient production chains.
##
## Usage:
##   $GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- sim_bot_linebuilder
##   $GODOT --path . --script res://tests/run_simulation.gd -- sim_bot_linebuilder --visual

func _ready() -> void:
	bot_strategy = STRATEGY_LINE_BUILDER
	bot_seed = 42
	bot_duration_seconds = 60.0
	ticks_per_decision = 60
	super._ready()
