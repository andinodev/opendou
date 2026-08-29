class_name TestBankPanel
extends RefCounted

const OpenDouBankPanelClass = preload("res://addons/opendou/editor/opendou_bank_panel.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var panel = OpenDouBankPanelClass.new()
	
	# Test 1: Adding streams to list
	panel._on_add_stream_pressed()
	panel._on_add_stream_pressed()
	if panel.file_list.item_count != 2:
		failures.append("Test 1 Failed: Expected 2 items in file list, got %d" % panel.file_list.item_count)
		
	# Test 2: Compiling soundbank from UI
	panel.bank_name_edit.text = "UITestBank"
	panel.output_path_edit.text = "user://ui_test.bank"
	panel.prefetch_spin.value = 16.0
	
	var success = panel.compile_soundbank()
	if not success or not FileAccess.file_exists("user://ui_test.bank"):
		failures.append("Test 2 Failed: Bank compilation from UI panel failed")
		
	return failures
