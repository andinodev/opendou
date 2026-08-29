extends Control

const TestAllClass = preload("res://tests/test_all.gd")

@onready var result_label: Label = $Margin/VBox/ResultLabel
@onready var details_text: RichTextLabel = $Margin/VBox/DetailsText

func _ready() -> void:
	run_tests()

func run_tests() -> void:
	var res = TestAllClass.run_suite()
	var total: int = res["total"]
	var passed: int = res["passed"]
	var failures: Array = res["failures"]
	
	if failures.is_empty():
		result_label.text = "✅ SUCCESS: All %d / %d unit tests passed 100%%!" % [passed, total]
		result_label.modulate = Color(0.2, 1.0, 0.4)
		details_text.text = "[color=green]All 25 test suites executed successfully without errors.[/color]"
	else:
		result_label.text = "❌ FAILURE: %d failed out of %d tests" % [failures.size(), total]
		result_label.modulate = Color(1.0, 0.3, 0.3)
		var text = "[color=red]Failed tests:[/color]\n"
		for f in failures:
			text += "- " + str(f) + "\n"
		details_text.text = text
