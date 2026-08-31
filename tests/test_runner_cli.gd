extends SceneTree

const TestAllClass = preload("res://tests/test_all.gd")

func _init() -> void:
	var res = TestAllClass.run_suite()
	var total: int = res["total"]
	var passed: int = res["passed"]
	var failures: Array = res["failures"]
	
	var content: String = ""
	if failures.is_empty():
		content = "STATUS: PASSED\nTOTAL: %d\nPASSED: %d\nFAILURES: 0\n" % [total, passed]
	else:
		content = "STATUS: FAILED\nTOTAL: %d\nPASSED: %d\nFAILURES: %d\n" % [total, passed, failures.size()]
		for f in failures:
			content += "- " + str(f) + "\n"

	var paths_to_write: Array[String] = [
		"res://test_results.log",
		ProjectSettings.globalize_path("res://test_results.log"),
		"user://test_results.log"
	]
	
	for path in paths_to_write:
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(content)
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
