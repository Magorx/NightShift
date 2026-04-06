extends "res://tests/bot/bot_player.gd"
## Bot run: random walk + weighted random building placement.
##
## Usage:
##   # Fast (headless):
##   $GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- sim_bot_random
##
##   # Visual (watch the bot build at 2x speed):
##   $GODOT --path . --script res://tests/run_simulation.gd -- sim_bot_random --visual

func _ready() -> void:
	bot_strategy = STRATEGY_RANDOM
	bot_seed = 42
	bot_duration_seconds = 60.0
	ticks_per_decision = 60
	super._ready()
