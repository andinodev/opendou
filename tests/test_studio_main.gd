class_name TestStudioMain
extends RefCounted

const OpenDouStudioMainClass = preload("res://addons/opendou/editor/opendou_studio_main.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var studio = OpenDouStudioMainClass.new()
	
	# Test 1: Sub-panel initializations
	if not studio.graph_editor or not studio.radar_view or not studio.bank_panel or not studio.transport_bar:
		failures.append("Test 1 Failed: Sub-panels in OpenDouStudioMain not instantiated correctly")
		
	if studio.tab_container.get_tab_count() != 3:
		failures.append("Test 2 Failed: Expected 3 tabs in studio main, got %d" % studio.tab_container.get_tab_count())
		
	# Test 3: Window detachment toggle
	studio.toggle_detach_window()
	if not studio.is_detached or not studio.detached_window:
		failures.append("Test 3a Failed: Detach window did not set detached state")
		
	studio.toggle_detach_window()
	if studio.is_detached or studio.detached_window != null:
		failures.append("Test 3b Failed: Re-embedding window did not restore state")
		
	return failures
