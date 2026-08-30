class_name TestStudioAdvancedUI
extends RefCounted

const OpenDouStudioMainClass = preload("res://addons/opendou/editor/opendou_studio_main.gd")
const OpenDouMixerDrawerClass = preload("res://addons/opendou/editor/opendou_mixer_drawer.gd")
const OpenDouMusicTimelineClass = preload("res://addons/opendou/editor/opendou_music_timeline.gd")
const OpenDouDialogueGridClass = preload("res://addons/opendou/editor/opendou_dialogue_grid.gd")
const OpenDouGameSyncsPanelClass = preload("res://addons/opendou/editor/opendou_game_syncs_panel.gd")
const OpenDouGraphSerializerClass = preload("res://addons/opendou/editor/opendou_graph_serializer.gd")
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
	
	# Test 2: OpenDouMusicTimeline & Track Headers
	var timeline = OpenDouMusicTimelineClass.new()
	timeline._on_bpm_changed(140.0)
	if timeline.clock.bpm != 140.0:
		failures.append("Test 2a Failed: Music timeline BPM not set to 140")
	timeline._on_intensity_slider_changed(0.85)
	if timeline.active_intensity != 0.85:
		failures.append("Test 2b Failed: Intensity slider value mismatch")
	if timeline.tracks.size() != 4:
		failures.append("Test 2c Failed: Expected 4 music stems in DAW timeline")
		
	# Test Track Mute & Solo
	timeline.tracks[0].mute_btn.button_pressed = true
	if timeline.tracks[0].current_gain != 0.0:
		failures.append("Test 2d Failed: Muted track should have 0 gain")
	timeline.tracks[0].mute_btn.button_pressed = false
	
	# Test Metronome click & Stinger Toggle Trigger
	timeline._play_metronome_click(true)
	timeline.btn_stinger_victory.button_pressed = true
	if not timeline.stinger_player.playing:
		failures.append("Test 2d Failed: Stinger player should play when button toggled on")
	timeline.btn_stinger_victory.button_pressed = false
	if timeline.stinger_player.playing:
		failures.append("Test 2e Failed: Stinger player should stop when button toggled off")
	timeline.stop_audition_stinger()
	
	# Test Track CRUD (Add / Delete Track)
	timeline.add_new_custom_track("Layer 5: Choirs")
	if timeline.tracks.size() != 5:
		failures.append("Test 2j Failed: Dynamic add track failed to increase count to 5")
	if not timeline.is_dirty:
		failures.append("Test 2k Failed: Adding track should mark timeline dirty")
		
	# Test Trim handles & audio path assignment
	timeline.tracks[4].left_trim_ratio = 0.1
	timeline.tracks[4].right_trim_ratio = 0.9
	timeline._on_audio_file_selected("res://tests/sample_stream.wav")
	
	timeline.delete_track(timeline.tracks[4])
	if timeline.tracks.size() != 4:
		failures.append("Test 2l Failed: Delete track failed to restore count to 4")
		
	# Test Suite Persistence (save_to_disk & load_from_disk)
	timeline.save_to_disk()
	if timeline.is_dirty:
		failures.append("Test 2m Failed: Save to disk should clear dirty flag")
	if not FileAccess.file_exists("res://opendou_music_suites.json"):
		failures.append("Test 2n Failed: Music suites JSON file was not created on disk")
		
	# Test TASK-031: Structural Cues, Tails & Random Sub-Tracks
	timeline.entry_cue_bar = -0.5
	timeline.exit_cue_bar = 8.0
	timeline.post_exit_tail_sec = 2.5
	if timeline.entry_cue_bar != -0.5 or timeline.post_exit_tail_sec != 2.5:
		failures.append("Test 2q Failed: Structural cues and tail values mismatch")
		
	# Test Sub-track variation adding and random picking
	timeline._on_track_variation_clicked(timeline.tracks[0])
	timeline._on_track_variation_clicked(timeline.tracks[0])
	if timeline.tracks[0].sub_tracks.size() != 3:
		failures.append("Test 2r Failed: Expected 3 sub-track variations on layer 1")
		
	timeline._pick_random_variations_on_loop()
	if timeline.tracks[0].active_sub_index < 0 or timeline.tracks[0].active_sub_index >= 3:
		failures.append("Test 2s Failed: Random variation index out of bounds")
		
	# Test Post-Exit Tail Decayer trigger
	timeline._on_music_play_pressed()
	timeline._on_trigger_transition_pressed()
	timeline._on_music_stop_pressed()
		
	timeline.free()
	
	# Test 3: OpenDouDialogueGrid
	var dlg_grid = OpenDouDialogueGridClass.new()
	dlg_grid._on_locale_selected(1) # Spanish
	if dlg_grid.dialogue_manager.current_language != "es":
		failures.append("Test 3a Failed: Dialogue grid locale switch to es failed")
	dlg_grid.audition_dialogue_key(&"HERO_GREETING_01", "es")
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
	
	# Test 5: Game Syncs Persistence (Disk serialization & deserialization)
	var syncs_panel = OpenDouGameSyncsPanelClass.new()
	syncs_panel._on_add_rtpc_pressed()
	if not syncs_panel.rtpcs.has(&"RTPC_5"):
		failures.append("Test 5a Failed: New RTPC not added to registry")
	syncs_panel.save_syncs_to_disk()
	var reload_syncs = OpenDouGameSyncsPanelClass.new()
	if not reload_syncs.rtpcs.has(&"RTPC_5"):
		failures.append("Test 5b Failed: Persistent syncs not reloaded from disk")
	syncs_panel.free()
	reload_syncs.free()
	
	# Test 6: OpenDouStudioMain Workspaces Context & Live Graph Audition
	var studio = OpenDouStudioMainClass.new()
	studio.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_MUSIC_DAW)
	if not studio.music_timeline.visible or studio.graph_editor.visible:
		failures.append("Test 6a Failed: Music DAW workspace mode did not toggle visibility correctly")
	if studio.game_syncs_panel.visible:
		failures.append("Test 6b Failed: Left Syncs sidebar should auto-collapse in Music DAW mode")
	if not studio.transport_bar.target_event_label.text.contains("Dynamic_Combat_Suite"):
		failures.append("Test 6c Failed: Transport bar did not switch to Music DAW context")
		
	studio.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_DIALOGUE_GRID)
	if not studio.dialogue_grid.visible or studio.music_timeline.visible:
		failures.append("Test 6d Failed: Dialogue Grid workspace mode did not toggle visibility correctly")
		
	studio._on_toggle_mixer_toggled(true)
	if not studio.mixer_drawer.visible:
		failures.append("Test 6e Failed: Mixer drawer toggle failed")
		
	# Test Graph compilation from canvas
	studio.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_GRAPH)
	studio.graph_editor.load_event_preset(0)
	var compiled = OpenDouGraphSerializerClass.build_composite_from_graph(studio.graph_editor)
	if compiled.get("root_node") == null and compiled.get("audio_files").is_empty():
		failures.append("Test 6f Failed: Graph serializer failed to compile active graph editor")
		
	# Test Detach Window & Placeholder
	if studio.dock_placeholder == null:
		failures.append("Test 6h Failed: Dock placeholder not initialized")
	studio.toggle_detach_window()
	studio.free()
	
	return failures
