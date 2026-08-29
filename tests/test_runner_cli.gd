extends SceneTree

const TestAllClass = preload("res://tests/test_all.gd")

func _init() -> void:
	var res = TestAllClass.run_suite()
	var total: int = res["total"]
	var passed: int = res["passed"]
	var failures: Array = res["failures"]
	
	var global_path = ProjectSettings.globalize_path("res://test_results.log")
	var file = FileAccess.open(global_path, FileAccess.WRITE)
	
	if failures.is_empty():
		if file:
			file.store_string("STATUS: PASSED\nTOTAL: %d\nPASSED: %d\nFAILURES: 0\n" % [total, passed])
			file.close()
		quit(0)
	else:
		if file:
			file.store_string("STATUS: FAILED\nTOTAL: %d\nPASSED: %d\nFAILURES: %d\n" % [total, passed, failures.size()])
			for f in failures:
				file.store_string("- " + str(f) + "\n")
			file.close()
		quit(1)
