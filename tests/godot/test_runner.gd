extends SceneTree

const TestCoreLogicScript = preload("res://tests/godot/test_core_logic.gd")
const TestUIAndViewsScript = preload("res://tests/godot/test_ui_and_views.gd")


func _init() -> void:
	var host: Control = Control.new()
	root.add_child(host)

	var core_tests: RefCounted = TestCoreLogicScript.new()
	core_tests.call("run_all")

	var ui_tests: RefCounted = TestUIAndViewsScript.new()
	ui_tests.call("run_all", host)

	var core_passed: int = int(core_tests.get("passed_count"))
	var ui_passed: int = int(ui_tests.get("passed_count"))
	var core_failed: int = int(core_tests.get("failed_count"))
	var ui_failed: int = int(ui_tests.get("failed_count"))

	var total_passed: int = core_passed + ui_passed
	var total_failed: int = core_failed + ui_failed

	var core_msgs: Array[String] = core_tests.get("failure_messages")
	for msg: String in core_msgs:
		print(msg)
	var ui_msgs: Array[String] = ui_tests.get("failure_messages")
	for msg: String in ui_msgs:
		print(msg)

	print("==========================================")
	print("GODOT UNIT TESTS SUMMARY: %d passed, %d failed" % [total_passed, total_failed])
	print("==========================================")

	host.free()
	quit(0 if total_failed == 0 else 1)
