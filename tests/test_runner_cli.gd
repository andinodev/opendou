extends SceneTree

const TestAllClass = preload("res://tests/test_all.gd")

func _init() -> void:
	var res = TestAllClass.run_suite()
	var total: int = res["total"]
	var passed: int = res["passed"]
	var failures: Array = res["failures"]
	
	var log_path: String = ProjectSettings.globalize_path("res://test_results.log")
	var file = FileAccess.open(log_path, FileAccess.WRITE)
	if file:
		if failures.is_empty():
			file.store_string("STATUS: PASSED\nTOTAL: %d\nPASSED: %d\nFAILURES: 0\n" % [total, passed])
		else:
			file.store_string("STATUS: FAILED\nTOTAL: %d\nPASSED: %d\nFAILURES: %d\n" % [total, passed, failures.size()])
			for f in failures:
				file.store_string("- " + str(f) + "\n")
		file.flush()
		file.close()
	
	if failures.is_empty():
		print("STATUS: PASSED | TOTAL: %d | PASSED: %d | FAILURES: 0" % [total, passed])
		quit(0)
	else:
		print("STATUS: FAILED | TOTAL: %d | PASSED: %d | FAILURES: %d" % [total, passed, failures.size()])
		for f in failures:
			print("- " + str(f))
		quit(1)
