extends "res://tests/bot/bot_player.gd"
## BOT.4 — Batch runner: all three strategies back-to-back, then a comparison table.
##
## Each strategy gets 30 seconds of game time. Buildings are cleared between runs.
##
## Usage:
##   $GODOT --headless --fixed-fps 60 --path . --script res://tests/run_simulation.gd -- sim_bot_batch

const RUN_DURATION := 30.0

func _ready() -> void:
	timeout_seconds = 300.0  # three 30s runs + overhead
	super._ready()

func run_simulation() -> void:
	EconomyTracker.creative_mode = true

	var strategies := [
		{name = "RANDOM",       id = STRATEGY_RANDOM},
		{name = "GREEDY",       id = STRATEGY_GREEDY},
		{name = "LINE_BUILDER", id = STRATEGY_LINE_BUILDER},
	]
	var results: Array = []

	for cfg in strategies:
		print("\n[BATCH] ── Running strategy: %s ──" % cfg.name)

		# Fresh deposit layout
		_setup_deposits()
		await sim_advance_ticks(5)

		# Reset player to a known start position
		if GameManager.player:
			GameManager.player.position = Vector3(5.5, 0.1, 5.5)
			GameManager.player.velocity = Vector3.ZERO

		var m := BotMetrics.new()
		var b := BotBrain.new(self, m)
		b.strategy = cfg.id
		b.ticks_per_decision = ticks_per_decision
		b.bot_duration_seconds = RUN_DURATION
		b.bot_seed = bot_seed

		await b.run()
		results.append({name = cfg.name, metrics = m})

		# Clear buildings and economy for the next run
		BuildingRegistry.clear()
		EconomyTracker.clear()
		EconomyTracker.creative_mode = true
		await sim_advance_ticks(10)  # let queue_free() complete

	_print_comparison(results)
	sim_finish()

func _print_comparison(results: Array) -> void:
	print("\n╔══════════════════════════════════════════╗")
	print("║        BOT STRATEGY COMPARISON           ║")
	print("╠══════════════════════════════════════════╣")
	print("║ %-16s %8s %12s ║" % ["Strategy", "Buildings", "Items Del."])
	print("╠══════════════════════════════════════════╣")
	for r in results:
		var m: BotMetrics = r.metrics
		print("║ %-16s %8d %12d ║" % [r.name, m.total_buildings(), m.total_items_delivered()])
	print("╚══════════════════════════════════════════╝")

	for r in results:
		r.metrics.print_report(r.name)
