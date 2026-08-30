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
		
	# Test TASK-032: Timeline Automation Curves & Bus Routing
	var t0 = timeline.tracks[0]
	t0.automation_enabled = true
	t0.automation_parameter = 0 # Volume
	t0.automation_points = [Vector2(0.0, 0.0), Vector2(0.5, 1.0), Vector2(1.0, 0.0)]
	var eval_mid = t0.evaluate_automation_value(0.5)
	if absf(eval_mid - 1.0) > 0.01:
		failures.append("Test 2t Failed: Automation evaluation at midpoint should be 1.0")
	var eval_qtr = t0.evaluate_automation_value(0.25)
	if absf(eval_qtr - 0.5) > 0.01:
		failures.append("Test 2u Failed: Automation evaluation at quarter point should be 0.5")
		
	# Test Bus Routing Assignment
	t0.bus_name = &"Music_Pads"
	timeline.stem_players[0].bus = t0.bus_name
	if timeline.stem_players[0].bus != &"Music_Pads":
		failures.append("Test 2v Failed: Stem player bus assignment failed")
		
	# Test TASK-033: Music Playlist Manager & State Hierarchy
	var pl_mgr = timeline.playlist_manager
	if pl_mgr.items.size() != 4:
		failures.append("Test 2w Failed: Expected 4 default playlist items")
	var started_seg = pl_mgr.start_playlist()
	if started_seg != &"Combat_Intro":
		failures.append("Test 2x Failed: Playlist start segment mismatch")
	var next_seg = pl_mgr.advance_loop()
	if next_seg != &"Combat_Loop":
		failures.append("Test 2y Failed: Playlist did not advance from intro to loop")
		
	# Test Playlist Item Reordering & Serialization
	pl_mgr.move_item_up(1)
	if pl_mgr.items[0].segment_name != &"Combat_Loop":
		failures.append("Test 2z Failed: Playlist move item up failed")
	var serialized_pl = pl_mgr.serialize()
	if serialized_pl.size() != 4:
		failures.append("Test 2aa Failed: Playlist serialization item count mismatch")
		
	# Test Playlist Play Toggle in Timeline
	timeline._on_playlist_play_toggled(true)
	if not timeline.is_playlist_mode:
		failures.append("Test 2ab Failed: Timeline playlist mode not toggled on")
	timeline._on_playlist_play_toggled(false)
	
	# Test Add Track Modal Dialog
	var prev_track_count = timeline.tracks.size()
	timeline.open_add_track_dialog()
	timeline._on_add_track_type_selected(2) # Percussion & Drums
	timeline._on_add_track_dialog_confirmed()
	if timeline.tracks.size() != prev_track_count + 1:
		failures.append("Test 2ac Failed: Track was not added via modal dialog")
	if timeline.tracks[timeline.tracks.size() - 1].bus_name != &"Music_Percussion":
		failures.append("Test 2ad Failed: Modal track preset bus assignment mismatch")
		
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
		
	# Test Ducking Matrix in Mixer Drawer
	var mixer = studio.mixer_drawer
	if not mixer.duck_cell_buttons.has("Voice_Music"):
		failures.append("Test 6e1 Failed: Ducking cell buttons missing Voice_Music")
	mixer._open_duck_cell_editor(&"Voice", &"Music")
	mixer.duck_atten_spinbox.value = -16.0
	mixer._on_duck_param_changed(-16.0)
	var r = mixer._find_ducking_rule(&"Voice", &"Music")
	if not r or r.attenuation_db != -16.0:
		failures.append("Test 6e2 Failed: Ducking rule parameter update failed")
		
	# Test Graph compilation from canvas
	studio.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_GRAPH)
	studio.graph_editor.load_event_preset(0)
	var compiled = OpenDouGraphSerializerClass.build_composite_from_graph(studio.graph_editor)
	if compiled.get("root_node") == null and compiled.get("audio_files").is_empty():
		failures.append("Test 6f Failed: Graph serializer failed to compile active graph editor")
		
	# Test AHDSR, LFO and Sequence Node creation
	studio.graph_editor._on_context_menu_id_pressed(9) # AHDSR
	studio.graph_editor._on_context_menu_id_pressed(10) # LFO
	studio.graph_editor._on_context_menu_id_pressed(11) # Sequence
	var found_ahdsr = false
	var found_lfo = false
	var found_seq = false
	for child in studio.graph_editor.get_children():
		if child is OpenDouAHDSRGraphNode:
			found_ahdsr = true
			child._on_test_trigger_pressed()
		elif child is OpenDouLFOGraphNode:
			found_lfo = true
			child.freq_spin.value = 5.0
		elif child is OpenDouSequenceGraphNode:
			found_seq = true
			child._on_audition_pressed()
	if not found_ahdsr:
		failures.append("Test 6i Failed: AHDSR GraphNode was not spawned via context menu")
	if not found_lfo:
		failures.append("Test 6j Failed: LFO GraphNode was not spawned via context menu")
	if not found_seq:
		failures.append("Test 6k Failed: Sequence GraphNode was not spawned via context menu")

	# Test Profiler Panel Session Recording and JSON roundtrip
	var profiler = studio.profiler_panel
	profiler._on_record_session_toggled(true)
	profiler.session_recorder.record_frame(55.0, 4, 120, ["Test_Event"], {}, 2)
	profiler._on_record_session_toggled(false)
	if profiler.session_recorder.frames.is_empty():
		failures.append("Test 6l Failed: Profiler session recorder did not capture frames")
	var exported_json = profiler.session_recorder.export_to_json()
	if not exported_json.contains("Test_Event"):
		failures.append("Test 6m Failed: Profiler session JSON export missing recorded event")
	var new_recorder = ProfilerSessionRecorderClass.new()
	if not new_recorder.import_from_json(exported_json) or new_recorder.frames.size() != profiler.session_recorder.frames.size():
		failures.append("Test 6n Failed: Profiler session JSON import mismatch")
	new_recorder.free()

	# Test Detach Window & Placeholder
	if studio.dock_placeholder == null:
		failures.append("Test 6h Failed: Dock placeholder not initialized")
	studio.toggle_detach_window()
	studio.free()
	
	return failures
