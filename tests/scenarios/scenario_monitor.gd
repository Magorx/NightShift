class_name ScenarioMonitor
extends RefCounted
## Tracks numeric metrics over scenario lifetime and captures screenshots
## at key moments. Prints a summary report at the end.

var _sim: Node  # ScenarioBase
var _metrics: Dictionary = {}  # name -> {getter: Callable, history: Array[{tick, value}]}
var _screenshots: Array = []  # Array of {label: String, tick: int}
var _assertions: Array = []  # Array of {passed: bool, msg: String}

func _init(sim: Node) -> void:
	_sim = sim

# ── Metric tracking ─────────────────────────────────────────────────────────

## Register a named metric with a getter callable.
## The getter is polled when sample() is called.
func track(metric_name: String, getter: Callable) -> void:
	_metrics[metric_name] = {
		getter = getter,
		history = [],
	}

## Sample all tracked metrics at the current tick.
func sample() -> void:
	for name in _metrics:
		var entry: Dictionary = _metrics[name]
		var value = entry.getter.call()
		entry.history.append({tick = _sim.tick_count, value = value})

## Sample a specific metric.
func sample_one(metric_name: String) -> void:
	if not _metrics.has(metric_name):
		return
	var entry: Dictionary = _metrics[metric_name]
	var value = entry.getter.call()
	entry.history.append({tick = _sim.tick_count, value = value})

## Get the latest value of a metric, or null if never sampled.
func get_value(metric_name: String):
	if not _metrics.has(metric_name):
		return null
	var history: Array = _metrics[metric_name].history
	if history.is_empty():
		# Auto-sample if never sampled
		sample_one(metric_name)
		history = _metrics[metric_name].history
		if history.is_empty():
			return null
	return history.back().value

## Get the full history of a metric.
func get_history(metric_name: String) -> Array:
	if not _metrics.has(metric_name):
		return []
	return _metrics[metric_name].history

# ── Metric assertions ───────────────────────────────────────────────────────

## Assert a metric equals an expected value.
func assert_eq(metric_name: String, expected, msg: String = "") -> bool:
	var actual = get_value(metric_name)
	var passed: bool = actual == expected
	var full_msg := "%s: %s == %s" % [metric_name if msg == "" else msg, str(actual), str(expected)]
	_record_assertion(passed, full_msg)
	return passed

## Assert a metric is greater than a threshold.
func assert_gt(metric_name: String, threshold: float, msg: String = "") -> bool:
	var actual = get_value(metric_name)
	if actual == null:
		_record_assertion(false, "%s: no value (need > %.2f)" % [metric_name, threshold])
		return false
	var passed: bool = float(actual) > threshold
	var full_msg := "%s: %.2f > %.2f" % [metric_name if msg == "" else msg, float(actual), threshold]
	_record_assertion(passed, full_msg)
	return passed

## Assert a metric is less than a threshold.
func assert_lt(metric_name: String, threshold: float, msg: String = "") -> bool:
	var actual = get_value(metric_name)
	if actual == null:
		_record_assertion(false, "%s: no value (need < %.2f)" % [metric_name, threshold])
		return false
	var passed: bool = float(actual) < threshold
	var full_msg := "%s: %.2f < %.2f" % [metric_name if msg == "" else msg, float(actual), threshold]
	_record_assertion(passed, full_msg)
	return passed

## Assert a metric is within a range [min_val, max_val].
func assert_between(metric_name: String, min_val: float, max_val: float, msg: String = "") -> bool:
	var actual = get_value(metric_name)
	if actual == null:
		_record_assertion(false, "%s: no value (need %.2f..%.2f)" % [metric_name, min_val, max_val])
		return false
	var v := float(actual)
	var passed := v >= min_val and v <= max_val
	var full_msg := "%s: %.2f in [%.2f, %.2f]" % [metric_name if msg == "" else msg, v, min_val, max_val]
	_record_assertion(passed, full_msg)
	return passed

func _record_assertion(passed: bool, msg: String) -> void:
	_assertions.append({passed = passed, msg = msg})
	if passed:
		print("[MONITOR OK] %s" % msg)
	else:
		printerr("[MONITOR FAIL] %s" % msg)
		_sim._failed = true

# ── Screenshots ──────────────────────────────────────────────────────────────

## Capture a named screenshot at the current simulation state.
func screenshot(label: String) -> void:
	_screenshots.append({label = label, tick = _sim.tick_count})
	await _sim.sim_capture_screenshot(label)
	print("[MONITOR] Screenshot: %s (tick %d)" % [label, _sim.tick_count])

# ── Report ───────────────────────────────────────────────────────────────────

## Print a summary of all tracked metrics and assertion results.
func print_report() -> void:
	# Sample all metrics one final time
	sample()

	print("")
	print("╔══════════════════════════════════════════════════════════════╗")
	print("║  SCENARIO REPORT: %s" % _sim.scenario_name())
	print("╠══════════════════════════════════════════════════════════════╣")

	# Metrics summary
	if not _metrics.is_empty():
		print("║  METRICS:")
		for name in _metrics:
			var history: Array = _metrics[name].history
			if history.is_empty():
				print("║    %s: (no samples)" % name)
			else:
				var first = history.front().value
				var last = history.back().value
				var samples := history.size()
				print("║    %s: %s (start: %s, samples: %d)" % [name, str(last), str(first), samples])

	# Assertions summary
	if not _assertions.is_empty():
		var passed := 0
		var failed := 0
		for a in _assertions:
			if a.passed:
				passed += 1
			else:
				failed += 1
		print("║  ASSERTIONS: %d passed, %d failed" % [passed, failed])
		for a in _assertions:
			if not a.passed:
				print("║    FAIL: %s" % a.msg)

	# Screenshots
	if not _screenshots.is_empty():
		print("║  SCREENSHOTS: %d captured" % _screenshots.size())
		for s in _screenshots:
			print("║    [tick %d] %s" % [s.tick, s.label])

	print("║  TOTAL TICKS: %d" % _sim.tick_count)
	print("╚══════════════════════════════════════════════════════════════╝")
	print("")
