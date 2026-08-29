class_name TestStudioAdvancedUI
extends RefCounted

const OpenDouStudioMainClass = preload("res://addons/opendou/editor/opendou_studio_main.gd")
const OpenDouMixerDrawerClass = preload("res://addons/opendou/editor/opendou_mixer_drawer.gd")
const OpenDouMusicTimelineClass = preload("res://addons/opendou/editor/opendou_music_timeline.gd")
const OpenDouDialogueGridClass = preload("res://addons/opendou/editor/opendou_dialogue_grid.gd")
const OpenDouConvolutionGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_convolution_graph_node.gd")
const OpenDouGranularGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_granular_graph_node.gd")
const OpenDouBinauralGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_binaural_graph_node.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: OpenDouMixerDrawer
	var drawer = OpenDouMixerDrawerClass.new()
	if not drawer.channel_faders.has(&"Master") or not drawer.channel_faders.has(&"Music"):
		failures.append("Test 1a Failed: Mixer drawer missing Master or Music channel faders")
	drawer.update_telemetry(12.0, 40.0, -12.0, -8.0)
	if not drawer.hdr_window_lbl.text.contains("12.0"):
		failures.append("Test 1b Failed: HDR telemetry label not updated")
	drawer.free()
	
	# Test 2: OpenDouMusicTimeline
	var timeline = OpenDouMusicTimelineClass.new()
	timeline._on_bpm_changed(140.0)
	if timeline.clock.bpm != 140.0:
		failures.append("Test 2a Failed: Music timeline BPM not set to 140")
	timeline._on_intensity_slider_changed(0.85)
	if timeline.active_intensity != 0.85:
		failures.append("Test 2b Failed: Intensity slider value mismatch")
	timeline.free()
	
	# Test 3: OpenDouDialogueGrid
	var dlg_grid = OpenDouDialogueGridClass.new()
	dlg_grid._on_locale_selected(1) # Spanish
	if dlg_grid.dialogue_manager.current_language != "es":
		failures.append("Test 3 Failed: Dialogue grid locale switch to es failed")
	dlg_grid.free()
	
	# Test 4: New DSP Graph Nodes
	var conv_node = OpenDouConvolutionGraphNodeClass.new()
	if conv_node.node_type != OpenDouConvolutionGraphNodeClass.NodeType.TYPE_CONVOLUTION:
		failures.append("Test 4a Failed: Convolution node type mismatch")
	conv_node.free()
	
	var gran_node = OpenDouGranularGraphNodeClass.new()
	if gran_node.node_type != OpenDouGranularGraphNodeClass.NodeType.TYPE_GRANULAR:
		failures.append("Test 4b Failed: Granular node type mismatch")
	gran_node.free()
	
	var bin_node = OpenDouBinauralGraphNodeClass.new()
	bin_node._on_azimuth_changed(90.0)
	if not bin_node.metrics_lbl.text.contains("Shadow"):
		failures.append("Test 4c Failed: Binaural node metrics label not formatted")
	bin_node.free()
	
	# Test 5: OpenDouStudioMain Workspaces Switching
	var studio = OpenDouStudioMainClass.new()
	studio.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_MUSIC_DAW)
	if not studio.music_timeline.visible or studio.graph_editor.visible:
		failures.append("Test 5a Failed: Music DAW workspace mode did not toggle visibility correctly")
		
	studio.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_DIALOGUE_GRID)
	if not studio.dialogue_grid.visible or studio.music_timeline.visible:
		failures.append("Test 5b Failed: Dialogue Grid workspace mode did not toggle visibility correctly")
		
	studio._on_toggle_mixer_toggled(true)
	if not studio.mixer_drawer.visible:
		failures.append("Test 5c Failed: Mixer drawer toggle failed")
		
	studio.free()
	return failures
