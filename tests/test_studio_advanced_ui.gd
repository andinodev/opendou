class_name TestStudioAdvancedUI
extends RefCounted

const OpenDouStudioMainClass = preload("res://addons/opendou/editor/opendou_studio_main.gd")
const OpenDouMixerDrawerClass = preload("res://addons/opendou/editor/opendou_mixer_drawer.gd")
const OpenDouMusicTimelineClass = preload("res://addons/opendou/editor/opendou_music_timeline.gd")
const OpenDouDialogueGridClass = preload("res://addons/opendou/editor/opendou_dialogue_grid.gd")
const OpenDouGraphEditorClass = preload("res://addons/opendou/editor/opendou_graph_editor.gd")
const OpenDouGameSyncsPanelClass = preload("res://addons/opendou/editor/opendou_game_syncs_panel.gd")
const OpenDouGraphSerializerClass = preload("res://addons/opendou/editor/opendou_graph_serializer.gd")
const OpenDouConvolutionGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_convolution_graph_node.gd")
const OpenDouGranularGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_granular_graph_node.gd")
const OpenDouBinauralGraphNodeClass = preload("res://addons/opendou/editor/nodes/opendou_binaural_graph_node.gd")
const OpenDouTransportBarClass = preload("res://addons/opendou/editor/opendou_transport_bar.gd")
const ProfilerSessionRecorderClass = preload("res://addons/opendou/core/telemetry/profiler_session_recorder.gd")

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
	if timeline.stinger_player.stream == null:
		failures.append("Test 2d Failed: Stinger player should play when button toggled on")
	timeline.btn_stinger_victory.button_pressed = false
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
	if t0.bus_name != &"Music_Pads":
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
	conv_node.room_len_spin.value = 20.0
	conv_node._recalculate_room_acoustics()
	if conv_node.calculated_rt60 <= 0.1:
		failures.append("Test 4a1 Failed: Convolution room designer RT60 calculation failed")
	conv_node._on_mode_selected(1)
	if conv_node.room_box.visible or not conv_node.ir_file_box.visible:
		failures.append("Test 4a2 Failed: Convolution node mode toggle visibility failed")
	conv_node.free()
	
	var gran_node = OpenDouGranularGraphNodeClass.new()
	if gran_node.node_type != OpenDouGranularGraphNodeClass.NodeType.TYPE_GRANULAR:
		failures.append("Test 4b Failed: Granular node type mismatch")
	gran_node.free()
	
	var bin_node = OpenDouBinauralGraphNodeClass.new()
	bin_node._on_azimuth_changed(90.0)
	# Fase 7B: la etiqueta ya no ensena una formula de Woodworth sino el backend real.
	if not bin_node.metrics_lbl.text.contains("Backend"):
		failures.append("Test 4c Failed: Binaural node metrics label not formatted")
	bin_node.free()
	
	# Test 5: Game Syncs Persistence (Disk serialization & deserialization)
	# La ruta va a user://: escribir en res:// inyectaba entradas RTPC en el JSON
	# versionado del proyecto y ensuciaba el arbol de git en cada ejecucion.
	const TEST_SYNCS_PATH := "user://opendou_syncs_test.json"
	if FileAccess.file_exists(TEST_SYNCS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SYNCS_PATH))
	var syncs_panel = OpenDouGameSyncsPanelClass.new(TEST_SYNCS_PATH)
	if syncs_panel.syncs_file_path != TEST_SYNCS_PATH:
		failures.append("Test 5-0 Failed: la ruta de syncs no es inyectable")
	syncs_panel._on_add_rtpc_pressed()
	if not syncs_panel.rtpcs.has(&"RTPC_5"):
		failures.append("Test 5a Failed: New RTPC not added to registry")
	syncs_panel.save_syncs_to_disk()
	var reload_syncs = OpenDouGameSyncsPanelClass.new(TEST_SYNCS_PATH)
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

	# Test Spatial Radar Tab in Profiler
	if profiler.radar_view == null:
		failures.append("Test 6o Failed: Profiler spatial radar view was not initialized")
	else:
		profiler.radar_view.update_radar_data([{ "event_name": "Test_Step", "world_position": Vector3(5, 0, 5), "is_virtual": false, "volume_db": 0.0 }])
		profiler.radar_view.update_telemetry_metrics(8, 64, 0.02, 2048)

	# Test Floating Tool Window Modals & Zero-Waste Center Layout (Task 2)
	studio.open_hdr_mixer_modal()
	studio.open_syncs_modal()
	studio.open_profiler_modal()
	studio.open_banks_modal()
	if studio.mixer_dialog == null or not (studio.mixer_dialog is Window):
		failures.append("Test 6p1 Failed: mixer_dialog must be an initialized Window")
	elif not studio.mixer_dialog.title.contains("HDR Mixing Console") or studio.mixer_dialog.size != Vector2i(780, 460):
		failures.append("Test 6p2 Failed: mixer_dialog title or size mismatch")
	elif studio.mixer_drawer.size != Vector2(780, 460) or studio.mixer_drawer.position != Vector2.ZERO:
		failures.append("Test 6p2b Failed: mixer_drawer did not synchronize size with mixer_dialog")
	
	if studio.syncs_dialog == null or not (studio.syncs_dialog is Window):
		failures.append("Test 6p3 Failed: syncs_dialog must be an initialized Window")
	elif not studio.syncs_dialog.title.contains("Game Syncs") or studio.syncs_dialog.size != Vector2i(460, 480):
		failures.append("Test 6p4 Failed: syncs_dialog title or size mismatch")
	elif studio.syncs_dialog.get_child_count() == 0 or studio.syncs_dialog.get_child(0).size != Vector2(460, 480):
		failures.append("Test 6p4b Failed: syncs_dialog child did not synchronize size with syncs_dialog")
		
	if studio.profiler_dialog == null or not (studio.profiler_dialog is Window):
		failures.append("Test 6p5 Failed: profiler_dialog must be an initialized Window")
	elif not studio.profiler_dialog.title.contains("Live Profiler & SoundBanks") or studio.profiler_dialog.size != Vector2i(840, 540):
		failures.append("Test 6p6 Failed: profiler_dialog title or size mismatch")
	elif studio.profiler_dialog.get_node("TabContainer").size != Vector2(840, 540):
		failures.append("Test 6p6b Failed: profiler_dialog TabContainer did not synchronize size with profiler_dialog")
		
	# Test dynamic modal resize
	studio.mixer_dialog.size = Vector2i(920, 600)
	studio.mixer_dialog.size_changed.emit()
	if studio.mixer_drawer.size != Vector2(920, 600):
		failures.append("Test 6p6c Failed: mixer_drawer failed to dynamically adapt to mixer_dialog resizing")
		
	if studio.center_workspace_box.get_parent() != studio.center_right_hsplit:
		failures.append("Test 6p7 Failed: center_workspace_box should be direct child of center_right_hsplit without vertical splitter")

	# Test Detach Window & Placeholder (Auto-maximized & Zero-Waste Root Layout)
	if studio.dock_placeholder == null:
		failures.append("Test 6h Failed: Dock placeholder not initialized")
	studio.detach_and_maximize()
	if not studio.is_detached:
		failures.append("Test 6h1 Failed: Studio is_detached flag should be true after detach_and_maximize()")
	if studio.detached_window == null or studio.detached_window.mode != Window.MODE_MAXIMIZED:
		failures.append("Test 6h2 Failed: Detached window mode should be Window.MODE_MAXIMIZED")
	if studio.content_container.anchors_preset != Control.PRESET_FULL_RECT:
		failures.append("Test 6h3 Failed: content_container anchors_preset should be PRESET_FULL_RECT")
	if studio.content_container.size_flags_vertical != Control.SIZE_EXPAND_FILL:
		failures.append("Test 6h4 Failed: content_container size_flags_vertical should be SIZE_EXPAND_FILL")
	if not studio.content_container.clip_contents:
		failures.append("Test 6h4b Failed: content_container must have clip_contents enabled")
		
	# Test window size synchronization
	studio.detached_window.size = Vector2i(1280, 720)
	studio._on_detached_window_resized()
	if studio.content_container.size != Vector2(1280, 720) or studio.content_container.position != Vector2.ZERO:
		failures.append("Test 6h4c Failed: content_container failed to synchronize dimensions to detached_window size")
		
	studio.reattach_to_dock()
	if studio.is_detached:
		failures.append("Test 6h5 Failed: Studio is_detached flag should be false after reattach_to_dock()")
	studio.free()
	
	# Test 7: Reactive Context-Aware Bottom Transport Bar (Task 3)
	var tb = OpenDouTransportBarClass.new()
	
	# 7a: Mode 0 (Graph Mode)
	tb.set_workspace_context(0)
	if tb.current_workspace_mode != 0:
		failures.append("Test 7a1 Failed: Transport bar current_workspace_mode should be 0 for Graph")
	if not tb.target_event_label.text.contains("Audition:"):
		failures.append("Test 7a2 Failed: Target event label missing Audition prefix")
	if not tb.current_simulation_rtpcs.has(&"Distance") or not tb.current_simulation_rtpcs.has(&"RPM") or not tb.current_simulation_rtpcs.has(&"Pitch Jitter"):
		failures.append("Test 7a3 Failed: Graph mode missing default simulation RTPCs (Distance, RPM, Pitch Jitter)")
	if not tb.play_btn or not tb.pause_btn or not tb.stop_btn:
		failures.append("Test 7a4 Failed: Master transport buttons missing")
	if not tb.master_vol_slider or not tb.master_vol_spin or not tb.vu_meter_rect:
		failures.append("Test 7a5 Failed: Master volume section and VU meter missing")
		
	# Two-way binding on Master volume controls
	tb._on_master_slider_changed(-12.0)
	if not is_equal_approx(tb.master_vol_spin.value, -12.0):
		failures.append("Test 7a6 Failed: Master volume slider to spinbox two-way binding failed")
	tb._on_master_spin_changed(-4.5)
	if not is_equal_approx(tb.master_vol_slider.value, -4.5):
		failures.append("Test 7a7 Failed: Master volume spinbox to slider two-way binding failed")
		
	# Dynamic RTPC Fader addition
	var rtpc_flags = {"emitted": false}
	tb.rtpc_changed.connect(func(param_name: StringName, val: float):
		if param_name == &"TestSpeed" and is_equal_approx(val, 25.0):
			rtpc_flags["emitted"] = true
	)
	tb.add_rtpc_fader(&"TestSpeed", 0.0, 50.0, 10.0)
	if not tb.current_simulation_rtpcs.has(&"TestSpeed") or not is_equal_approx(tb.current_simulation_rtpcs[&"TestSpeed"], 10.0):
		failures.append("Test 7a8 Failed: Dynamic RTPC fader was not registered in simulation dictionary")
	tb.set_simulation_rtpc(&"TestSpeed", 25.0)
	if not rtpc_flags["emitted"]:
		failures.append("Test 7a9 Failed: RTPC change signal emission failed")
		
	# 7b: Mode 1 (Music DAW Mode)
	tb.set_workspace_context(1)
	if tb.current_workspace_mode != 1:
		failures.append("Test 7b1 Failed: Transport bar current_workspace_mode should be 1 for Music DAW")
	if tb.current_simulation_rtpcs.has(&"Distance"):
		failures.append("Test 7b2 Failed: SFX Distance faders must be cleared in Music DAW mode")
	if tb.beat_counter_lbl == null or not tb.beat_counter_lbl.text.contains("Bar 1 : Beat 1.0"):
		failures.append("Test 7b3 Failed: Real-Time Beat/Bar counter not initialized in Music DAW mode")
	if tb.bpm_spin == null or not is_equal_approx(tb.bpm_spin.value, 120.0):
		failures.append("Test 7b4 Failed: BPM SpinBox not initialized to 120.0 in Music DAW mode")
	if tb.intensity_slider == null:
		failures.append("Test 7b5 Failed: Combat Intensity slider not initialized in Music DAW mode")
	if tb.quantize_opt == null or tb.quantize_opt.get_item_count() != 3:
		failures.append("Test 7b6 Failed: Quantize selector missing or item count mismatch")
	if tb.dirty_marker_lbl == null or tb.dirty_marker_lbl.visible:
		failures.append("Test 7b7 Failed: Dirty marker should initially be hidden in Music DAW mode")
		
	# Real-Time Clock and Dirty State update
	tb.update_music_clock(4, 3.5, true)
	if not tb.beat_counter_lbl.text.contains("Bar 4 : Beat 3.5") or not tb.dirty_marker_lbl.visible:
		failures.append("Test 7b8 Failed: update_music_clock did not update beat counter or dirty marker")
		
	# 7c: Mode 2 (Dialogue / Voice Mode)
	tb.set_workspace_context(2)
	if tb.current_workspace_mode != 2:
		failures.append("Test 7c1 Failed: Transport bar current_workspace_mode should be 2 for Dialogue/Voice")
	if tb.vocal_rms_lbl == null or not tb.vocal_rms_lbl.text.contains("RMS:"):
		failures.append("Test 7c2 Failed: Vocal RMS meter label not initialized in Voice mode")
	if tb.voice_locale_opt == null or tb.voice_locale_opt.get_item_count() != 4:
		failures.append("Test 7c3 Failed: Voice locale selector missing or options count mismatch")
	if tb.raw_direct_btn == null or not tb.raw_direct_btn.button_pressed:
		failures.append("Test 7c4 Failed: Raw 2D direct audition button missing or not pressed by default")
	if tb.voice_audition_btn == null:
		failures.append("Test 7c5 Failed: Voice line audition button missing in Voice mode")
		
	tb.update_vocal_telemetry(-14.2, false)
	if not tb.vocal_rms_lbl.text.contains("-14.2"):
		failures.append("Test 7c6 Failed: Vocal RMS telemetry update failed")
		
	tb.free()
	
	# 7d: Context switching via OpenDouStudioMain
	var studio_test = OpenDouStudioMainClass.new()
	studio_test.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_GRAPH)
	if studio_test.transport_bar.current_workspace_mode != 0 or not studio_test.transport_bar.current_simulation_rtpcs.has(&"Distance"):
		failures.append("Test 7d1 Failed: Studio Graph mode failed to configure transport bar")
		
	studio_test.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_MUSIC_DAW)
	if studio_test.transport_bar.current_workspace_mode != 1 or studio_test.transport_bar.beat_counter_lbl == null:
		failures.append("Test 7d2 Failed: Studio Music mode failed to configure transport bar")
		
	studio_test.set_workspace_mode(OpenDouStudioMainClass.WorkspaceMode.MODE_DIALOGUE_GRID)
	if studio_test.transport_bar.current_workspace_mode != 2 or studio_test.transport_bar.vocal_rms_lbl == null:
		failures.append("Test 7d3 Failed: Studio Voice mode failed to configure transport bar")
		
	studio_test.free()
	
	# Test 8: Workspace Canvas Polish & Sizing Verification (Task 4)
	var tl_test = OpenDouMusicTimelineClass.new()
	if tl_test.size_flags_horizontal != Control.SIZE_EXPAND_FILL or tl_test.size_flags_vertical != Control.SIZE_EXPAND_FILL:
		failures.append("Test 8a Failed: Music timeline root container must have SIZE_EXPAND_FILL flags")
	if not tl_test.clip_contents:
		failures.append("Test 8a2 Failed: Music timeline must have clip_contents enabled")
	if tl_test.tracks.is_empty() or tl_test.tracks[0].header_panel == null or tl_test.tracks[0].header_panel.custom_minimum_size.x != 280.0:
		failures.append("Test 8b Failed: Music timeline track header width must be 280px")
	if tl_test.tracks[0].var_btn == null or not tl_test.tracks[0].var_btn.text.contains("Var:"):
		failures.append("Test 8c Failed: Music timeline variation badge should display variation count")
	if tl_test.entry_cue_bar != 0.0 or tl_test.exit_cue_bar != 8.0:
		failures.append("Test 8d Failed: Music timeline default entry/exit cue bars mismatch")
		
	# Test ruler and waveform draw routines with cues and multiple variations
	tl_test._on_track_variation_clicked(tl_test.tracks[0])
	if tl_test.ruler_canvas:
		tl_test.ruler_canvas.size = Vector2(800, 34)
		tl_test._on_draw_timeline_ruler()
	if not tl_test.tracks.is_empty() and tl_test.tracks[0].waveform_canvas:
		tl_test.tracks[0].waveform_canvas.size = Vector2(520, 60)
		tl_test._on_draw_track_waveform(tl_test.tracks[0], tl_test.tracks[0].waveform_canvas)
	tl_test.free()
	
	var dlg_test = OpenDouDialogueGridClass.new()
	if dlg_test.size_flags_horizontal != Control.SIZE_EXPAND_FILL or dlg_test.size_flags_vertical != Control.SIZE_EXPAND_FILL:
		failures.append("Test 8e Failed: Dialogue grid root container must have SIZE_EXPAND_FILL flags")
	if not dlg_test.clip_contents:
		failures.append("Test 8e2 Failed: Dialogue grid must have clip_contents enabled")
	if dlg_test.grid_tree == null or dlg_test.grid_tree.columns != 6:
		failures.append("Test 8f Failed: Dialogue grid must have 6 columns")
	if dlg_test.grid_tree.get_column_title(0) != "Dialogue ID Key" or dlg_test.grid_tree.get_column_title(5) != "Audition":
		failures.append("Test 8g Failed: Dialogue grid column titles mismatch")
	if dlg_test.grid_tree.size_flags_vertical != Control.SIZE_EXPAND_FILL or dlg_test.grid_tree.size_flags_horizontal != Control.SIZE_EXPAND_FILL:
		failures.append("Test 8h Failed: Dialogue grid tree must have horizontal and vertical SIZE_EXPAND_FILL")
	dlg_test.free()
	
	var ge_test = OpenDouGraphEditorClass.new()
	if not ge_test.clip_contents:
		failures.append("Test 8i Failed: Graph editor must have clip_contents enabled")
	ge_test.free()
	
	# Test 9: Synth Presets Builder Rack in Game Syncs Panel (Task 3)
	var syncs_p = OpenDouGameSyncsPanelClass.new()
	if syncs_p.tab_container == null or syncs_p.tab_container.get_tab_count() < 4:
		failures.append("Test 9a Failed: OpenDouGameSyncsPanel missing Tab 4 for Synth Presets")
	else:
		var tab4_name = syncs_p.tab_container.get_tab_title(3)
		if not tab4_name.contains("Presets"):
			failures.append("Test 9b Failed: Tab 4 title should contain 'Presets', got: %s" % tab4_name)
			
	if syncs_p.preset_tree == null:
		failures.append("Test 9c Failed: preset_tree not initialized on OpenDouGameSyncsPanel")
	else:
		var root = syncs_p.preset_tree.get_root()
		if root == null or root.get_child_count() == 0:
			failures.append("Test 9d Failed: preset_tree is empty; should populate from SynthPresetRegistry")
		else:
			# Verify selecting an item populates rack fields
			var first_item = root.get_first_child()
			syncs_p.preset_tree.set_selected(first_item, 0)
			syncs_p._on_preset_selected()
			if syncs_p.active_preset_name.is_empty():
				failures.append("Test 9e Failed: active_preset_name not set on preset selection")
			if syncs_p.preset_name_edit == null or syncs_p.preset_name_edit.text != str(syncs_p.active_preset_name):
				failures.append("Test 9f Failed: preset_name_edit text does not match active_preset_name")
				
	# Verify rack components exist
	if syncs_p.gen_type_opt == null or syncs_p.gen_type_opt.get_item_count() < 9:
		failures.append("Test 9g Failed: gen_type_opt missing or does not contain all 9 generator types")
	if syncs_p.base_freq_spin == null or syncs_p.base_freq_var_spin == null:
		failures.append("Test 9h Failed: Frequency spinboxes not initialized")
	if syncs_p.env_attack_spin == null or syncs_p.env_decay_spin == null or syncs_p.env_sustain_spin == null or syncs_p.env_release_spin == null:
		failures.append("Test 9i Failed: ADSR Envelope spinboxes not initialized")
	if syncs_p.pitch_decay_spin == null or syncs_p.pitch_amount_spin == null:
		failures.append("Test 9j Failed: Pitch envelope spinboxes not initialized")
	if syncs_p.lfo_wave_opt == null or syncs_p.lfo_rate_spin == null or syncs_p.lfo_depth_spin == null or syncs_p.lfo_target_opt == null:
		failures.append("Test 9k Failed: LFO controls not initialized")
	if syncs_p.filter_type_opt == null or syncs_p.filter_cutoff_spin == null or syncs_p.filter_q_spin == null:
		failures.append("Test 9l Failed: Filter controls not initialized")
	if syncs_p.drive_type_opt == null or syncs_p.drive_amount_spin == null:
		failures.append("Test 9m Failed: Drive controls not initialized")
	if syncs_p.waveform_visualizer == null:
		failures.append("Test 9n Failed: waveform_visualizer not initialized")
	if syncs_p.audition_player == null:
		failures.append("Test 9o Failed: audition_player not initialized")
		
	# Test audition play and stop
	syncs_p._on_audition_play_pressed()
	if syncs_p.audition_player.stream == null:
		failures.append("Test 9p Failed: Audition play did not generate audio stream")
	syncs_p._on_audition_stop_pressed()
	if syncs_p.audition_player.playing:
		failures.append("Test 9q Failed: Audition stop failed to stop player")
		
	# Test Add, Edit, Save, Delete preset workflow
	var initial_count = syncs_p.preset_tree.get_root().get_child_count() if syncs_p.preset_tree and syncs_p.preset_tree.get_root() else 0
	syncs_p._on_add_preset_pressed()
	var new_count = syncs_p.preset_tree.get_root().get_child_count() if syncs_p.preset_tree and syncs_p.preset_tree.get_root() else 0
	if new_count != initial_count + 1:
		failures.append("Test 9r Failed: Add preset did not increment preset count")
	var added_name = syncs_p.active_preset_name
	syncs_p.base_freq_spin.value = 550.0
	syncs_p._on_rack_control_changed()
	var updated_dict = SynthPresetRegistry.get_singleton().get_preset(added_name)
	if is_zero_approx(updated_dict.get("base_freq", 0.0) - 550.0) == false:
		failures.append("Test 9s Failed: Changing rack control did not update SynthPresetRegistry")
	
	# Los presets se guardan en user:// por la misma razon que los syncs.
	syncs_p.presets_file_path = "user://opendou_synth_presets_test.json"
	syncs_p._on_save_presets_pressed()
	syncs_p._on_delete_preset_pressed()
	var after_delete_count = syncs_p.preset_tree.get_root().get_child_count() if syncs_p.preset_tree and syncs_p.preset_tree.get_root() else 0
	if after_delete_count != initial_count:
		failures.append("Test 9t Failed: Delete preset did not restore preset count")
		
	syncs_p.free()
	
	# Test 11: Mode 3 (Modular Synth Rack Workstation) Integration in OpenDouStudioMain & OpenDouTransportBar (Task 4)
	var studio_synth = OpenDouStudioMainClass.new()
	if studio_synth.synth_workspace == null:
		failures.append("Test 11a Failed: synth_workspace not initialized on OpenDouStudioMain")
	elif studio_synth.synth_workspace.visible:
		failures.append("Test 11b Failed: synth_workspace should initially be hidden in Graph mode")
		
	if studio_synth.btn_mode_synth == null:
		failures.append("Test 11c Failed: btn_mode_synth not found in header bar")
		
	# Switch to Mode 3
	studio_synth.set_workspace_mode(3)
	if studio_synth.synth_workspace == null or not studio_synth.synth_workspace.visible:
		failures.append("Test 11d Failed: synth_workspace should be visible when switched to Mode 3")
	if studio_synth.graph_editor.visible or studio_synth.music_timeline.visible or studio_synth.dialogue_grid.visible:
		failures.append("Test 11e Failed: Graph, Music and Voice workspaces must be hidden in Mode 3")
	if studio_synth.locale_selector.visible or studio_synth.snap_selector.visible:
		failures.append("Test 11f Failed: Contextual selectors (locale, snap) should be hidden in Mode 3")
	if studio_synth.btn_mode_synth and not studio_synth.btn_mode_synth.button_pressed:
		failures.append("Test 11g Failed: btn_mode_synth should be pressed in Mode 3")
	if studio_synth.transport_bar.current_workspace_mode != 3:
		failures.append("Test 11h Failed: Transport bar current_workspace_mode should be 3 in Mode 3")
	if not studio_synth.transport_bar.target_event_label.text.contains("Synth Preset Studio"):
		failures.append("Test 11i Failed: Transport bar target event label does not contain 'Synth Preset Studio'")
		
	# Switch back to Mode 0, 1, 2
	studio_synth.set_workspace_mode(0)
	if studio_synth.synth_workspace.visible:
		failures.append("Test 11j Failed: synth_workspace should be hidden when switching back to Mode 0")
	studio_synth.set_workspace_mode(1)
	if studio_synth.synth_workspace.visible:
		failures.append("Test 11k Failed: synth_workspace should be hidden when switching to Mode 1")
	studio_synth.set_workspace_mode(2)
	if studio_synth.synth_workspace.visible:
		failures.append("Test 11l Failed: synth_workspace should be hidden when switching to Mode 2")
		
	# Direct Transport Bar Mode 3 test
	var tb_synth = OpenDouTransportBarClass.new()
	tb_synth.set_workspace_context(3)
	if tb_synth.current_workspace_mode != 3:
		failures.append("Test 11m Failed: Transport bar set_workspace_context(3) did not set current_workspace_mode to 3")
	if not tb_synth.target_event_label.text.contains("Synth Preset Studio"):
		failures.append("Test 11n Failed: Transport bar target_event_label mismatch for Mode 3")
	tb_synth.free()
	studio_synth.free()
	
	# Test 12: Pro DAW Add Track Modal with Live Synth Browser, Audition & Debouncing (TASK-050)
	var tl_add = OpenDouMusicTimelineClass.new()
	tl_add.open_add_track_dialog()
	
	# 12a: Modal Dialog size >= 800x550px
	if tl_add.add_track_dialog == null:
		failures.append("Test 12a1 Failed: add_track_dialog not initialized on music timeline")
	elif tl_add.add_track_dialog.size.x < 800 or tl_add.add_track_dialog.size.y < 550:
		failures.append("Test 12a2 Failed: add_track_dialog min size must be >= 800x550px, got: %s" % str(tl_add.add_track_dialog.size))
		
	# 12b: Source toggling between Synth Preset and File
	if tl_add.btn_toggle_source_synth == null or tl_add.btn_toggle_source_file == null:
		failures.append("Test 12b1 Failed: Source toggle buttons not initialized")
	elif not tl_add.btn_toggle_source_synth.button_pressed or not tl_add.add_track_synth_box.visible or tl_add.add_track_file_box.visible:
		failures.append("Test 12b2 Failed: Default source mode should be Synth Preset (synth box visible, file box hidden)")
		
	tl_add._set_source_mode(1) # Switch to File mode
	if tl_add.btn_toggle_source_synth.button_pressed or not tl_add.btn_toggle_source_file.button_pressed or tl_add.add_track_synth_box.visible or not tl_add.add_track_file_box.visible:
		failures.append("Test 12b3 Failed: Switching to File source mode failed")
		
	tl_add._set_source_mode(0) # Switch back to Synth mode
	if not tl_add.btn_toggle_source_synth.button_pressed or not tl_add.add_track_synth_box.visible or tl_add.add_track_file_box.visible:
		failures.append("Test 12b4 Failed: Switching back to Synth source mode failed")
		
	# 12c: Category filtering and live search matching
	if tl_add.add_track_synth_item_list == null or tl_add.add_track_synth_search_edit == null:
		failures.append("Test 12c1 Failed: Synth item list or search LineEdit not initialized")
	else:
		tl_add._filter_synth_presets("Leads", "")
		var leads_count = tl_add.add_track_synth_item_list.get_item_count()
		if leads_count == 0:
			failures.append("Test 12c2 Failed: Category filtering for 'Leads' returned 0 items")
		for i in range(leads_count):
			var p_name = StringName(tl_add.add_track_synth_item_list.get_item_text(i))
			var cat = SynthPresetRegistry.get_singleton().get_preset_category(p_name)
			if cat != "Leads":
				failures.append("Test 12c3 Failed: Category filter 'Leads' returned non-lead preset: %s (%s)" % [p_name, cat])
				break
				
		# Search filter matching
		tl_add._filter_synth_presets("All", "Hornet")
		if tl_add.add_track_synth_item_list.get_item_count() != 1 or tl_add.add_track_synth_item_list.get_item_text(0) != "Cyber_Hornet":
			failures.append("Test 12c4 Failed: Search query 'Hornet' did not match only Cyber_Hornet")
			
	# 12d: Predictive Auto-Fill for Leads (Cyber_Hornet)
	tl_add._select_synth_preset(&"Cyber_Hornet")
	var next_idx = tl_add.tracks.size() + 1
	if not tl_add.add_track_name_edit.text.contains("Cyber_Hornet") or not tl_add.add_track_name_edit.text.contains(str(next_idx)):
		failures.append("Test 12d1 Failed: Predictive name auto-fill for Cyber_Hornet failed, got: %s" % tl_add.add_track_name_edit.text)
	if tl_add.add_track_color_picker.color != Color("fa3860"):
		failures.append("Test 12d2 Failed: Predictive color for Cyber_Hornet should be #fa3860, got: %s" % tl_add.add_track_color_picker.color.to_html())
	if tl_add.add_track_bus_opt.get_item_text(tl_add.add_track_bus_opt.selected) != "Music_Leads":
		failures.append("Test 12d3 Failed: Predictive audio bus for Cyber_Hornet should be Music_Leads, got: %s" % tl_add.add_track_bus_opt.get_item_text(tl_add.add_track_bus_opt.selected))
	if not is_equal_approx(tl_add.add_track_min_spin.value, 0.6) or not is_equal_approx(tl_add.add_track_max_spin.value, 1.0):
		failures.append("Test 12d4 Failed: Predictive intensity range for Leads should be [0.6, 1.0]")
		
	# Predictive Auto-Fill for Nature/Ambience (Wind_Canopy)
	tl_add._select_synth_preset(&"Wind_Canopy")
	if not tl_add.add_track_name_edit.text.contains("Wind_Canopy"):
		failures.append("Test 12d5 Failed: Predictive name auto-fill for Wind_Canopy failed")
	if tl_add.add_track_color_picker.color != Color("2ce8b8"):
		failures.append("Test 12d6 Failed: Predictive color for Wind_Canopy should be #2ce8b8, got: %s" % tl_add.add_track_color_picker.color.to_html())
	if tl_add.add_track_bus_opt.get_item_text(tl_add.add_track_bus_opt.selected) != "Music_Pads":
		failures.append("Test 12d7 Failed: Predictive audio bus for Wind_Canopy should be Music_Pads, got: %s" % tl_add.add_track_bus_opt.get_item_text(tl_add.add_track_bus_opt.selected))
	if not is_equal_approx(tl_add.add_track_min_spin.value, 0.0) or not is_equal_approx(tl_add.add_track_max_spin.value, 0.5):
		failures.append("Test 12d8 Failed: Predictive intensity range for Ambience should be [0.0, 0.5]")
		
	# 12e: Audition & Debounce Timer
	if tl_add.audition_player == null or tl_add.btn_audition_play == null or tl_add.btn_audition_stop == null:
		failures.append("Test 12e1 Failed: Audition player or buttons not initialized")
	else:
		tl_add._on_add_track_audition_play_pressed()
		if tl_add.audition_player.stream == null:
			failures.append("Test 12e2 Failed: Audition play did not generate stream for active synth preset")
		tl_add._on_add_track_audition_stop_pressed()
		
	# Debounce timer test
	if tl_add.add_track_debounce_timer == null or not is_equal_approx(tl_add.add_track_debounce_timer.wait_time, 0.15):
		failures.append("Test 12e3 Failed: add_track_debounce_timer should have 150ms wait_time")
	tl_add._on_add_track_debounce_timeout()
	
	# 12f: Instant creation on item activation / double click
	var prev_tracks = tl_add.tracks.size()
	tl_add._select_synth_preset(&"Cyber_Hornet")
	tl_add._on_synth_preset_item_activated(0)
	if tl_add.tracks.size() != prev_tracks + 1:
		failures.append("Test 12f1 Failed: Double-click item activation did not instantiate new track")
	else:
		var new_track = tl_add.tracks[tl_add.tracks.size() - 1]
		if new_track.synth_preset != &"Cyber_Hornet":
			failures.append("Test 12f2 Failed: Created track synth_preset mismatch, expected Cyber_Hornet, got: %s" % new_track.synth_preset)
		if new_track.bus_name != &"Music_Leads":
			failures.append("Test 12f3 Failed: Created track bus_name mismatch, expected Music_Leads, got: %s" % new_track.bus_name)
		if not new_track.audio_file_path.is_empty():
			failures.append("Test 12f4 Failed: Synth preset track should have empty audio_file_path")
			
	# 12g: Resource lifecycle & Memory teardown
	tl_add._on_add_track_dialog_closed()
	if tl_add.audition_player.stream != null:
		failures.append("Test 12g1 Failed: Closing dialog should clear audition_player stream")
		
	tl_add.free()
	
	return failures

