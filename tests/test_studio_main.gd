class_name TestStudioMain
extends RefCounted

const OpenDouStudioMainClass = preload("res://addons/opendou/editor/opendou_studio_main.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var studio = OpenDouStudioMainClass.new()
	
	# Test 1: Sub-panel initializations
	if not studio.graph_editor or not studio.bank_panel or not studio.transport_bar or not studio.profiler_panel:
		failures.append("Test 1 Failed: Sub-panels in OpenDouStudioMain not instantiated correctly")
		
	# Test 2: Mode switching
	studio.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_GRAPH)
	if not studio.graph_editor.visible:
		failures.append("Test 2a Failed: Graph workspace mode not visible")
	studio.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_MUSIC_DAW)
	if not studio.music_timeline.visible:
		failures.append("Test 2b Failed: Music timeline workspace mode not visible")
	studio.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_DIALOGUE_GRID)
	if not studio.dialogue_grid.visible:
		failures.append("Test 2c Failed: Dialogue grid workspace mode not visible")
		
	# Test 3: Window detachment toggle
	studio.toggle_detach_window()
	if not studio.is_detached or not studio.detached_window:
		failures.append("Test 3a Failed: Detach window did not set detached state")
		
	studio.toggle_detach_window()
	if studio.is_detached or studio.detached_window != null:
		failures.append("Test 3b Failed: Re-embedding window did not restore state")
		
	studio.free()
	return failures
