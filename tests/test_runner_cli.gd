extends SceneTree

const TestAllClass = preload("res://tests/test_all.gd")

func _init() -> void:
	var res = TestAllClass.run_suite()
	var total: int = res["total"]
	var passed: int = res["passed"]
	var failures: Array = res["failures"]
	
	var file = FileAccess.open("res://test_results.log", FileAccess.WRITE)
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
		quit(0)
	else:
		quit(1)
