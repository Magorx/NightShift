extends Node

var _pass_count: int = 0
var _fail_count: int = 0
var _test_name: String = ""

func run_all() -> Dictionary:
	var results := { "passed": 0, "failed": 0, "errors": [] }
	for method in get_method_list():
		if method.name.begins_with("test_"):
			_test_name = method.name
			if has_method("before_each"):
				call("before_each")
			call(method.name)
			if has_method("after_each"):
				call("after_each")
	results.passed = _pass_count
	results.failed = _fail_count
	return results

func assert_eq(a, b, msg: String = "") -> void:
	if a == b:
		_pass_count += 1
	else:
		_fail_count += 1
		var text = "%s: expected %s == %s" % [_test_name, str(a), str(b)]
		if msg:
			text += " (%s)" % msg
		printerr("  FAIL: " + text)

func assert_true(cond: bool, msg: String = "") -> void:
	assert_eq(cond, true, msg)

func assert_false(cond: bool, msg: String = "") -> void:
	assert_eq(cond, false, msg)

func assert_not_null(val, msg: String = "") -> void:
	if val != null:
		_pass_count += 1
	else:
		_fail_count += 1
		printerr("  FAIL: %s: expected non-null (%s)" % [_test_name, msg])
