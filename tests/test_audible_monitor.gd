class_name TestAudibleMonitor
extends RefCounted

## Unit tests for AudibleVoiceMonitor and AudibleVoiceInfo.

const AudibleVoiceMonitorClass = preload("res://addons/opendou/runtime/audible_voice_monitor.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const OpenDouAudibleMonitorClass = preload("res://addons/opendou/nodes/opendou_audible_monitor.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Class loading and instantiation of AudibleVoiceMonitor & AudibleVoiceInfo
	if AudibleVoiceMonitorClass == null:
		failures.append("Test 1a Failed: audible_voice_monitor.gd failed to load")
		return failures
		
	var info = AudibleVoiceMonitorClass.AudibleVoiceInfo.new(
		&"Player",
		&"Footstep",
		&"SFX",
		-12.5,
		-3.0,
		-6.0,
		0.5,
		-3.5,
		5.0,
		true,
		60.0
	)
	if info.emitter_name != &"Player" or info.event_name != &"Footstep" or info.bus_category != &"SFX":
		failures.append("Test 1b Failed: AudibleVoiceInfo properties not initialized correctly")
	if not is_equal_approx(info.effective_db, -12.5):
		failures.append("Test 1c Failed: AudibleVoiceInfo effective_db mismatch, expected -12.5, got %f" % info.effective_db)
	if not is_equal_approx(info.occlusion_factor, 0.5) or not info.is_3d or not is_equal_approx(info.priority, 60.0):
		failures.append("Test 1d Failed: AudibleVoiceInfo metadata mismatch")
		
	var default_info = AudibleVoiceMonitorClass.AudibleVoiceInfo.new()
	if default_info.effective_db != -60.0 or default_info.bus_category != &"SFX" or default_info.priority != 50.0:
		failures.append("Test 1e Failed: AudibleVoiceInfo default parameters mismatch")
		
	# Test 2: Distance attenuation calculation (near vs far, beyond max_distance, unconstrained)
	var atten_close = AudibleVoiceMonitorClass.calculate_distance_attenuation_db(1.0, 2.5, 15.0)
	var atten_far = AudibleVoiceMonitorClass.calculate_distance_attenuation_db(10.0, 2.5, 15.0)
	
	if atten_close < atten_far:
		failures.append("Test 2a Failed: Closer distance (%f dB) should be louder than farther (%f dB)" % [atten_close, atten_far])
	if not is_equal_approx(atten_close, 0.0):
		failures.append("Test 2b Failed: Distance within unit_size should clamp to 0.0 dB, got %f" % atten_close)
		
	var expected_far = linear_to_db(2.5 / 10.0) # -12.0412 dB
	if not is_equal_approx(atten_far, expected_far):
		failures.append("Test 2c Failed: Expected %f dB for distance 10.0m, got %f dB" % [expected_far, atten_far])
		
	var atten_beyond = AudibleVoiceMonitorClass.calculate_distance_attenuation_db(20.0, 2.5, 15.0)
	if atten_beyond > -80.0:
		failures.append("Test 2d Failed: Distance beyond max_distance should be culled (<= -80 dB), got %f dB" % atten_beyond)
		
	var atten_unbounded = AudibleVoiceMonitorClass.calculate_distance_attenuation_db(10000.0, 1.0, 0.0)
	if not is_equal_approx(atten_unbounded, -60.0):
		failures.append("Test 2e Failed: Extremely far distance without max_distance should clamp to -60.0 dB, got %f dB" % atten_unbounded)
		
	# Test 3: Occlusion attenuation calculation
	var occ_none = AudibleVoiceMonitorClass.calculate_occlusion_attenuation_db(0.0)
	var occ_half = AudibleVoiceMonitorClass.calculate_occlusion_attenuation_db(0.5)
	var occ_full = AudibleVoiceMonitorClass.calculate_occlusion_attenuation_db(1.0)
	
	if not is_equal_approx(occ_none, 0.0):
		failures.append("Test 3a Failed: Unoccluded attenuation expected 0.0 dB, got %f dB" % occ_none)
	if not is_equal_approx(occ_half, -3.0):
		failures.append("Test 3b Failed: Half-occluded attenuation expected -3.0 dB, got %f dB" % occ_half)
	if not is_equal_approx(occ_full, -6.0):
		failures.append("Test 3c Failed: Fully-occluded attenuation expected -6.0 dB, got %f dB" % occ_full)
		
	var occ_clamped_neg = AudibleVoiceMonitorClass.calculate_occlusion_attenuation_db(-0.5)
	var occ_clamped_high = AudibleVoiceMonitorClass.calculate_occlusion_attenuation_db(2.0)
	if not is_equal_approx(occ_clamped_neg, 0.0) or not is_equal_approx(occ_clamped_high, -6.0):
		failures.append("Test 3d Failed: Occlusion factor clamping out of [0, 1] range failed")
		
	# Test 4: Voice sorting in descending order of effective_db
	var tree = SceneTree.new()
	var root_node = Node.new()
	tree.root.add_child(root_node)
	
	var manager = AudioEventManagerClass.new()
	manager.name = "OpenDou"
	tree.root.add_child(manager)
	
	var def_loud = AudioEventDefClass.new(&"LoudExplosion")
	def_loud.base_volume_db = 0.0
	var inst_loud = manager.post_event(def_loud)
	inst_loud.set_position(Vector3(1.0, 0.0, 0.0))
	
	var def_mid = AudioEventDefClass.new(&"Gunshot")
	def_mid.base_volume_db = -10.0
	var inst_mid = manager.post_event(def_mid)
	inst_mid.set_position(Vector3(5.0, 0.0, 0.0))
	
	var def_quiet = AudioEventDefClass.new(&"Whisper")
	def_quiet.base_volume_db = -30.0
	var inst_quiet = manager.post_event(def_quiet)
	inst_quiet.set_position(Vector3(2.0, 0.0, 0.0))
	
	var voices = AudibleVoiceMonitorClass.collect_audible_voices(tree, Vector3.ZERO, null, -60.0)
	if voices.size() < 3:
		failures.append("Test 4a Failed: Expected at least 3 audible voices, got %d" % voices.size())
	else:
		if voices[0].event_name != &"LoudExplosion":
			failures.append("Test 4b Failed: First sorted voice should be LoudExplosion, got %s (dB: %f)" % [str(voices[0].event_name), voices[0].effective_db])
		if voices[1].event_name != &"Gunshot":
			failures.append("Test 4c Failed: Second sorted voice should be Gunshot, got %s (dB: %f)" % [str(voices[1].event_name), voices[1].effective_db])
		if voices[2].event_name != &"Whisper":
			failures.append("Test 4d Failed: Third sorted voice should be Whisper, got %s (dB: %f)" % [str(voices[2].event_name), voices[2].effective_db])
		if voices[0].effective_db < voices[1].effective_db or voices[1].effective_db < voices[2].effective_db:
			failures.append("Test 4e Failed: Voices are not sorted in strict descending order: [%f, %f, %f]" % [voices[0].effective_db, voices[1].effective_db, voices[2].effective_db])
			
	# Test 5: Inaudible voice threshold culling & stopped voices
	var def_inaudible = AudioEventDefClass.new(&"TinyDust")
	def_inaudible.base_volume_db = -50.0
	var inst_inaudible = manager.post_event(def_inaudible)
	inst_inaudible.set_position(Vector3(50.0, 0.0, 0.0)) # Large distance puts it below -60 dB
	
	var def_stopped = AudioEventDefClass.new(&"StoppedSound")
	def_stopped.base_volume_db = 0.0
	var inst_stopped = manager.post_event(def_stopped)
	inst_stopped.stop()
	
	var ducking = AudioDuckingMatrixClass.new()
	# Apply sidechain ducking to SFX
	ducking.add_rule(&"Voice", &"SFX", -15.0, 0.01, 0.1)
	ducking.set_bus_active(&"Voice", true)
	ducking.update(0.1)
	
	var culled_voices = AudibleVoiceMonitorClass.collect_audible_voices(tree, Vector3.ZERO, ducking, -35.0)
	
	for v in culled_voices:
		if v.effective_db < -35.0:
			failures.append("Test 5a Failed: Found voice with effective_db (%f) below threshold (-35.0)" % v.effective_db)
		if v.event_name == &"TinyDust":
			failures.append("Test 5b Failed: TinyDust should have been culled by min_db_threshold")
		if v.event_name == &"StoppedSound":
			failures.append("Test 5c Failed: StoppedSound should not be collected as audible")
			
	# Clean up test nodes
	manager.free()
	root_node.free()
	tree.free()
	
	# Test 6: OpenDouAudibleMonitor node instantiation, default properties, and UI generation
	var monitor = OpenDouAudibleMonitorClass.new()
	if not (monitor is CanvasLayer):
		failures.append("Test 6a Failed: OpenDouAudibleMonitor must extend CanvasLayer")
	if monitor.enabled != true:
		failures.append("Test 6b Failed: enabled default should be true")
	if monitor.is_overlay_visible != true:
		failures.append("Test 6c Failed: is_overlay_visible default should be true")
	if monitor.toggle_key != KEY_F8:
		failures.append("Test 6d Failed: toggle_key default should be KEY_F8")
	if monitor.max_items_displayed != 8:
		failures.append("Test 6e Failed: max_items_displayed default should be 8")
	if not is_equal_approx(monitor.min_db_threshold, -55.0):
		failures.append("Test 6f Failed: min_db_threshold default should be -55.0")
	if not is_equal_approx(monitor.poll_interval, 0.05):
		failures.append("Test 6g Failed: poll_interval default should be 0.05")
	if monitor.listener_node_path != NodePath(""):
		failures.append("Test 6h Failed: listener_node_path default should be empty NodePath")
		
	var test_tree = SceneTree.new()
	var test_root = Node.new()
	test_tree.root.add_child(test_root)
	test_root.add_child(monitor)
	monitor._ready()
	
	if monitor.panel_container == null or not is_instance_valid(monitor.panel_container):
		failures.append("Test 6i Failed: OpenDouAudibleMonitor did not create panel_container on _ready")
	if monitor.items_vbox == null or not is_instance_valid(monitor.items_vbox):
		failures.append("Test 6j Failed: OpenDouAudibleMonitor did not create items_vbox on _ready")
		
	# Test visibility toggle & unhandled input
	var ev_f8 = InputEventKey.new()
	ev_f8.pressed = true
	ev_f8.keycode = KEY_F8
	monitor._unhandled_input(ev_f8)
	if monitor.is_overlay_visible != false or (monitor.panel_container != null and monitor.panel_container.visible != false):
		failures.append("Test 6k Failed: F8 input event failed to hide overlay")
		
	monitor._unhandled_input(ev_f8)
	if monitor.is_overlay_visible != true or (monitor.panel_container != null and monitor.panel_container.visible != true):
		failures.append("Test 6l Failed: F8 input event failed to show overlay")
		
	# Test dynamic voice rendering in HUD
	var test_mgr = AudioEventManagerClass.new()
	test_mgr.name = "OpenDou"
	test_tree.root.add_child(test_mgr)
	
	var hud_def = AudioEventDefClass.new(&"HUDVoiceTest")
	hud_def.target_bus = &"SFX"
	hud_def.base_volume_db = -6.0
	var hud_inst = test_mgr.post_event(hud_def)
	hud_inst.set_position(Vector3(2.0, 0.0, 0.0))
	
	monitor.refresh_now(test_tree)
	if monitor.get_displayed_voices_count() < 1:
		failures.append("Test 6m Failed: Expected displayed voice count >= 1, got %d" % monitor.get_displayed_voices_count())
	if monitor.items_vbox != null and monitor.items_vbox.get_child_count() < 1:
		failures.append("Test 6n Failed: Expected items_vbox to contain at least 1 voice row widget")
		
	# Cleanup
	monitor.queue_free()
	test_mgr.free()
	test_root.free()
	test_tree.free()
	
	# Test 7: plugin.gd custom type registration and SVG icon loading
	var script_path = "res://addons/opendou/nodes/opendou_audible_monitor.gd"
	var icon_path = "res://addons/opendou/icons/icon_audible_monitor.svg"
	
	var scr = ResourceLoader.load(script_path)
	if scr == null:
		failures.append("Test 7a Failed: Script resource missing for OpenDouAudibleMonitor at %s" % script_path)
	var icon_res = ResourceLoader.load(icon_path)
	if icon_res == null:
		failures.append("Test 7b Failed: Icon resource missing for OpenDouAudibleMonitor at %s" % icon_path)
		
	var plugin_code = FileAccess.get_file_as_string("res://addons/opendou/plugin.gd")
	if plugin_code.is_empty():
		failures.append("Test 7c Failed: Could not read addons/opendou/plugin.gd")
	else:
		# El registro por add_custom_type se retiro: duplicaba las entradas del
		# dialogo "Crear nodo", y los nodos anadidos asi pierden su tipo al
		# guardar la escena. Lo que importa es estar en el registro global con
		# icono, que es de donde el dialogo los toma.
		var _reg_ok := false
		for _e in ProjectSettings.get_global_class_list():
			if str(_e.get("class", "")) == "OpenDouAudibleMonitor":
				_reg_ok = not str(_e.get("icon", "")).is_empty()
				break
		if not _reg_ok:
			failures.append("Test 7d Failed: %s no esta en el registro global con icono" % "OpenDouAudibleMonitor")
		# El registro por add_custom_type se retiro: duplicaba las entradas del
		# dialogo "Crear nodo". Lo que importa ahora es que la clase este en el
		# registro global CON su icono, que es de donde el dialogo las toma.
		var monitor_registered := false
		for entry in ProjectSettings.get_global_class_list():
			if str(entry.get("class", "")) == "OpenDouAudibleMonitor":
				monitor_registered = not str(entry.get("icon", "")).is_empty()
				break
		if not monitor_registered:
			failures.append("Test 7e Failed: OpenDouAudibleMonitor no esta en el registro global con icono")
			
	return failures
