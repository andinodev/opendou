class_name TestDeclarativeNodes
extends RefCounted

const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")
const OpenDouEventPlayer2DClass = preload("res://addons/opendou/nodes/opendou_event_player_2d.gd")
const OpenDouEventPlayerClass = preload("res://addons/opendou/nodes/opendou_event_player.gd")
const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const OpenDouPortal3DClass = preload("res://addons/opendou/nodes/opendou_portal_3d.gd")
const OpenDouReflector3DClass = preload("res://addons/opendou/nodes/opendou_reflector_3d.gd")
const OpenDouMusicPlayerClass = preload("res://addons/opendou/nodes/opendou_music_player.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: OpenDouEventPlayer3D inheritance & default properties
	var p3d = OpenDouEventPlayer3DClass.new()
	if not (p3d is AudioStreamPlayer3D):
		failures.append("Test 1 Failed: OpenDouEventPlayer3D must extend AudioStreamPlayer3D")
	if p3d.event_name != &"":
		failures.append("Test 1 Failed: event_name default should be empty StringName")
	if p3d.event_def != null:
		failures.append("Test 1 Failed: event_def default should be null")
	if p3d.auto_play_event != false:
		failures.append("Test 1 Failed: auto_play_event default should be false")
	if p3d.stop_on_tree_exit != true:
		failures.append("Test 1 Failed: stop_on_tree_exit default should be true")
	if not p3d.enable_binaural_hrtf or not p3d.enable_early_reflections or not p3d.enable_dynamic_occlusion:
		failures.append("Test 1 Failed: spatial acoustics flags should default to true")
	if p3d.occlusion_collision_mask != 1:
		failures.append("Test 1 Failed: occlusion_collision_mask should default to 1")
	if not is_equal_approx(p3d.occlusion_refresh_interval, 0.05):
		failures.append("Test 1 Failed: occlusion_refresh_interval should default to 0.05")
	if not is_equal_approx(p3d.base_priority, 50.0):
		failures.append("Test 1 Failed: base_priority should default to 50.0")
	if p3d.virtualization_mode != 0:
		failures.append("Test 1 Failed: virtualization_mode should default to 0")
	if not is_equal_approx(p3d.cull_distance, 35.0):
		failures.append("Test 1 Failed: cull_distance should default to 35.0")
	if p3d.bus_category != "SFX":
		failures.append("Test 1 Failed: bus_category should default to SFX")
	p3d.free()

	# Test 2: OpenDouEventPlayer3D public methods & playback
	var manager = AudioEventManagerClass.new()
	var test_def = AudioEventDefClass.new(&"Test3DEvent")
	test_def.base_volume_db = -2.0
	manager.register_event_definition(test_def)
	
	p3d = OpenDouEventPlayer3DClass.new()
	p3d.event_def = test_def
	p3d.set_event_manager(manager)
	
	p3d.set_rtpc(&"DistanceGain", 0.75)
	if not p3d.rtpc_bindings.has(&"DistanceGain") or not is_equal_approx(p3d.rtpc_bindings[&"DistanceGain"], 0.75):
		failures.append("Test 2 Failed: set_rtpc did not update rtpc_bindings correctly")
		
	p3d.set_switch(&"Surface", &"Wood")
	if p3d.switch_group != &"Surface" or p3d.active_switch != &"Wood":
		failures.append("Test 2 Failed: set_switch did not update switch properties")
		
	p3d.set_state(&"CombatState", &"Alert")
	if p3d.state_group != &"CombatState" or p3d.active_state != &"Alert":
		failures.append("Test 2 Failed: set_state did not update state properties")
		
	if not is_equal_approx(p3d.get_calculated_occlusion(), 0.0):
		failures.append("Test 2 Failed: initial get_calculated_occlusion should be 0.0")
		
	p3d.play_event()
	if p3d.active_instance == null or not p3d.active_instance.is_playing():
		failures.append("Test 2 Failed: play_event() did not start active_instance")
	p3d.free()

	# Test 3: OpenDouEventPlayer2D inheritance & default properties
	var p2d = OpenDouEventPlayer2DClass.new()
	if not (p2d is AudioStreamPlayer2D):
		failures.append("Test 3 Failed: OpenDouEventPlayer2D must extend AudioStreamPlayer2D")
	if p2d.event_name != &"" or p2d.event_def != null or p2d.auto_play_event != false:
		failures.append("Test 3 Failed: OpenDouEventPlayer2D default event parameters mismatch")
	if p2d.bus_category != "SFX" or not is_equal_approx(p2d.base_priority, 50.0):
		failures.append("Test 3 Failed: OpenDouEventPlayer2D default mixing/voice parameters mismatch")
	p2d.free()

	# Test 4: OpenDouEventPlayer2D public methods
	p2d = OpenDouEventPlayer2DClass.new()
	p2d.set_event_manager(manager)
	p2d.event_name = &"Test3DEvent"
	p2d.set_rtpc(&"Speed", 120.0)
	if not p2d.rtpc_bindings.has(&"Speed") or not is_equal_approx(p2d.rtpc_bindings[&"Speed"], 120.0):
		failures.append("Test 4 Failed: 2D set_rtpc failed")
	p2d.play_event()
	if p2d.active_instance == null or not p2d.active_instance.is_playing():
		failures.append("Test 4 Failed: 2D play_event() failed")
	p2d.free()

	# Test 5: OpenDouEventPlayer (Global) inheritance & methods
	var p_global = OpenDouEventPlayerClass.new()
	if not (p_global is AudioStreamPlayer):
		failures.append("Test 5 Failed: OpenDouEventPlayer must extend AudioStreamPlayer")
	p_global.set_event_manager(manager)
	p_global.event_def = test_def
	p_global.set_state(&"MusicState", &"Boss")
	if p_global.state_group != &"MusicState" or p_global.active_state != &"Boss":
		failures.append("Test 5 Failed: Global player set_state failed")
	p_global.play_event()
	if p_global.active_instance == null or not p_global.active_instance.is_playing():
		failures.append("Test 5 Failed: Global player play_event() failed")
	p_global.free()

	# Test 6: Tree lifecycle stop_on_tree_exit
	var test_tree_player = OpenDouEventPlayerClass.new()
	test_tree_player.set_event_manager(manager)
	test_tree_player.event_def = test_def
	test_tree_player.stop_on_tree_exit = true
	test_tree_player.play_event()
	var inst = test_tree_player.active_instance
	if inst == null or not inst.is_playing():
		failures.append("Test 6 Failed: Expected playing instance prior to tree exit")
	test_tree_player._notification(Node.NOTIFICATION_EXIT_TREE)
	if inst != null and inst.is_playing():
		failures.append("Test 6 Failed: stop_on_tree_exit did not stop instance on exit tree")
	test_tree_player.free()

	# Test 7: OpenDouRoom3D inheritance, properties & Sabine RT60 formula
	var room = OpenDouRoom3DClass.new()
	if not (room is Area3D):
		failures.append("Test 7 Failed: OpenDouRoom3D must extend Area3D")
	if room.room_name != &"Room":
		failures.append("Test 7 Failed: default room_name should be 'Room'")
	if room.material_preset != "Concrete":
		failures.append("Test 7 Failed: default material_preset should be 'Concrete'")
	if not is_equal_approx(room.absorption_coefficient, 0.15):
		failures.append("Test 7 Failed: default absorption_coefficient should be 0.15")
	if not is_equal_approx(room.custom_reverb_time, 0.0):
		failures.append("Test 7 Failed: default custom_reverb_time should be 0.0")
	if not is_equal_approx(room.calculated_rt60, 0.0):
		failures.append("Test 7 Failed: default calculated_rt60 should be 0.0")
	if room.snapshot_on_enter != &"":
		failures.append("Test 7 Failed: default snapshot_on_enter should be empty StringName")

	var dims = Vector3(10.0, 4.0, 10.0) # V = 400, S = 360
	# Concrete (alpha = 0.05) -> 0.161 * 400 / (360 * 0.05) = 64.4 / 18.0 = 3.577778
	var rt60_concrete = room.calculate_sabine_reverb(dims)
	if not is_equal_approx(rt60_concrete, 3.577778) or not is_equal_approx(room.calculated_rt60, 3.577778):
		failures.append("Test 7 Failed: Sabine RT60 Concrete preset mismatch, got %f" % rt60_concrete)

	# Wood (alpha = 0.15) -> 64.4 / (360 * 0.15) = 64.4 / 54.0 = 1.192593
	room.material_preset = "Wood"
	var rt60_wood = room.calculate_sabine_reverb(dims)
	if not is_equal_approx(rt60_wood, 1.192593):
		failures.append("Test 7 Failed: Sabine RT60 Wood preset mismatch, got %f" % rt60_wood)

	# Glass (alpha = 0.03) -> 64.4 / (360 * 0.03) = 64.4 / 10.8 = 5.962963
	room.material_preset = "Glass"
	var rt60_glass = room.calculate_sabine_reverb(dims)
	if not is_equal_approx(rt60_glass, 5.962963):
		failures.append("Test 7 Failed: Sabine RT60 Glass preset mismatch, got %f" % rt60_glass)

	# Curtains (alpha = 0.60) -> 64.4 / (360 * 0.60) = 64.4 / 216.0 = 0.298148
	room.material_preset = "Curtains"
	var rt60_curtains = room.calculate_sabine_reverb(dims)
	if not is_equal_approx(rt60_curtains, 0.298148):
		failures.append("Test 7 Failed: Sabine RT60 Curtains preset mismatch, got %f" % rt60_curtains)

	# Custom (alpha = 0.50) -> 64.4 / (360 * 0.50) = 64.4 / 180.0 = 0.357778
	room.material_preset = "Custom"
	room.absorption_coefficient = 0.50
	var rt60_custom = room.calculate_sabine_reverb(dims)
	if not is_equal_approx(rt60_custom, 0.357778):
		failures.append("Test 7 Failed: Sabine RT60 Custom preset mismatch, got %f" % rt60_custom)

	# Clamping min (0.05) & max (12.0)
	var rt60_min = room.calculate_sabine_reverb(Vector3(0.1, 0.1, 0.1))
	if not is_equal_approx(rt60_min, 0.05):
		failures.append("Test 7 Failed: Sabine RT60 minimum clamp to 0.05 failed, got %f" % rt60_min)
	room.material_preset = "Glass"
	var rt60_max = room.calculate_sabine_reverb(Vector3(200.0, 100.0, 200.0))
	if not is_equal_approx(rt60_max, 12.0):
		failures.append("Test 7 Failed: Sabine RT60 maximum clamp to 12.0 failed, got %f" % rt60_max)
	room.free()

	# Test 8: OpenDouRoom3D child BoxShape3D auto-detection and registration
	var room_auto = OpenDouRoom3DClass.new()
	room_auto.room_name = &"AutoRoom"
	room_auto.material_preset = "Concrete"
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(8.0, 3.0, 6.0) # V = 144, S = 2*(24+48+18) = 180 -> RT60 = 64.4 * (144/400) / 9.0 = 23.184 / 9 = 2.576
	col_shape.shape = box_shape
	room_auto.add_child(col_shape)
	room_auto._ready()
	if not is_equal_approx(room_auto.calculated_rt60, 2.576):
		failures.append("Test 8 Failed: Auto-detection of BoxShape3D failed, expected 2.576, got %f" % room_auto.calculated_rt60)
	if room_auto.runtime_room == null or not room_auto.runtime_room.has_bounds:
		failures.append("Test 8 Failed: AutoRoom runtime_room bounds not set properly")
	col_shape.free()
	room_auto.free()

	# Test 9: OpenDouPortal3D inheritance, properties & diffraction LPF calculation
	var portal = OpenDouPortal3DClass.new()
	if not (portal is Node3D):
		failures.append("Test 9 Failed: OpenDouPortal3D must extend Node3D")
	if portal.portal_name != &"Portal":
		failures.append("Test 9 Failed: default portal_name should be 'Portal'")
	if not is_equal_approx(portal.open_factor, 1.0):
		failures.append("Test 9 Failed: default open_factor should be 1.0")
	if portal.portal_size != Vector2(2.0, 3.0):
		failures.append("Test 9 Failed: default portal_size should be Vector2(2.0, 3.0)")
	if not is_equal_approx(portal.get_diffraction_lpf(), 20000.0):
		failures.append("Test 9 Failed: open_factor 1.0 expected 20000.0 Hz, got %f" % portal.get_diffraction_lpf())
	portal.open_factor = 0.0
	if not is_equal_approx(portal.get_diffraction_lpf(), 300.0):
		failures.append("Test 9 Failed: open_factor 0.0 expected 300.0 Hz, got %f" % portal.get_diffraction_lpf())
	portal.set_open_factor(0.5)
	if not is_equal_approx(portal.get_diffraction_lpf(), 10150.0):
		failures.append("Test 9 Failed: open_factor 0.5 expected 10150.0 Hz, got %f" % portal.get_diffraction_lpf())
	portal.set_open_factor(0.25)
	if not is_equal_approx(portal.get_diffraction_lpf(), 5225.0):
		failures.append("Test 9 Failed: open_factor 0.25 expected 5225.0 Hz, got %f" % portal.get_diffraction_lpf())
	portal.free()

	# Test 10: OpenDouReflector3D inheritance, properties & image source calculation
	var reflector = OpenDouReflector3DClass.new()
	if not (reflector is Node3D):
		failures.append("Test 10 Failed: OpenDouReflector3D must extend Node3D")
	if reflector.reflector_name != &"Reflector":
		failures.append("Test 10 Failed: default reflector_name should be 'Reflector'")
	if reflector.plane_normal != Vector3.FORWARD:
		failures.append("Test 10 Failed: default plane_normal should be Vector3.FORWARD")
	if not is_equal_approx(reflector.absorption, 0.1):
		failures.append("Test 10 Failed: default absorption should be 0.1")
	reflector.position = Vector3(0.0, 0.0, 10.0)
	reflector.plane_normal = Vector3(0.0, 0.0, -1.0)
	var refl_pt = reflector.get_reflected_point(Vector3(0.0, 0.0, 0.0))
	if not refl_pt.is_equal_approx(Vector3(0.0, 0.0, 20.0)):
		failures.append("Test 10 Failed: Reflected point expected (0, 0, 20), got %s" % str(refl_pt))
	var refl_pt2 = reflector.get_reflected_point(Vector3(5.0, 2.0, 8.0))
	if not refl_pt2.is_equal_approx(Vector3(5.0, 2.0, 12.0)):
		failures.append("Test 10 Failed: Reflected point 2 expected (5, 2, 12), got %s" % str(refl_pt2))
	reflector.free()

	# Test 11: End-to-end Declarative Spatial Acoustics Graph Integration
	var acoustics_mgr = SpatialAcousticsManagerClass.new()
	var d_room_a = OpenDouRoom3DClass.new()
	d_room_a.room_name = &"RoomA"
	d_room_a.position = Vector3(0.0, 0.0, 0.0)
	d_room_a.calculate_sabine_reverb(Vector3(10.0, 4.0, 10.0))
	d_room_a.set_acoustics_manager(acoustics_mgr)
	d_room_a.register_in_manager(acoustics_mgr)

	var d_room_b = OpenDouRoom3DClass.new()
	d_room_b.room_name = &"RoomB"
	d_room_b.position = Vector3(20.0, 0.0, 0.0)
	d_room_b.calculate_sabine_reverb(Vector3(10.0, 4.0, 10.0))
	d_room_b.set_acoustics_manager(acoustics_mgr)
	d_room_b.register_in_manager(acoustics_mgr)

	var d_portal = OpenDouPortal3DClass.new()
	d_portal.portal_name = &"PortalAB"
	d_portal.room_a_name = &"RoomA"
	d_portal.room_b_name = &"RoomB"
	d_portal.position = Vector3(10.0, 0.0, 0.0)
	d_portal.open_factor = 0.5
	d_portal.register_in_manager(acoustics_mgr)

	var d_path = acoustics_mgr.calculate_acoustic_path(Vector3(0.0, 0.0, 0.0), Vector3(20.0, 0.0, 0.0), &"RoomA", &"RoomB")
	if d_path.is_direct_los:
		failures.append("Test 11 Failed: Declarative path should not be direct line of sight")
	if not is_equal_approx(d_path.virtual_distance, 20.0):
		failures.append("Test 11 Failed: Declarative path distance expected 20.0, got %f" % d_path.virtual_distance)
	if d_path.apparent_origin != Vector3(10.0, 0.0, 0.0):
		failures.append("Test 11 Failed: Declarative apparent origin expected (10, 0, 0), got %s" % str(d_path.apparent_origin))
	if not is_equal_approx(d_path.accumulated_lpf, 10150.0):
		failures.append("Test 11 Failed: Declarative accumulated LPF expected 10150.0, got %f" % d_path.accumulated_lpf)

	d_room_a.free()
	d_room_b.free()
	d_portal.free()

	# Test 12: OpenDouMusicPlayer inheritance & default properties
	var mp = OpenDouMusicPlayerClass.new()
	if not (mp is Node):
		failures.append("Test 12 Failed: OpenDouMusicPlayer must extend Node")
	if mp.suite_name != &"Exploration_Ambient_Theme.tres":
		failures.append("Test 12 Failed: default suite_name should be 'Exploration_Ambient_Theme.tres'")
	if mp.auto_play != true:
		failures.append("Test 12 Failed: default auto_play should be true")
	if mp.auto_loop != true:
		failures.append("Test 12 Failed: default auto_loop should be true")
	if not is_equal_approx(mp.combat_intensity, 0.0):
		failures.append("Test 12 Failed: default combat_intensity should be 0.0")
	if mp.master_bus != &"Music":
		failures.append("Test 12 Failed: default master_bus should be 'Music'")
	if mp.enable_ducking != true:
		failures.append("Test 12 Failed: default enable_ducking should be true")
	mp.free()

	# Test 13: OpenDouMusicPlayer default suite loading and suite switching
	var mp_suite = OpenDouMusicPlayerClass.new()
	mp_suite.load_suite()
	if mp_suite.get_stem_count() != 2:
		failures.append("Test 13 Failed: Exploration_Ambient_Theme expected 2 stems, got %d" % mp_suite.get_stem_count())
	for p in mp_suite.stem_players:
		if p == null or p.stream == null:
			failures.append("Test 13 Failed: Stem player or stream is null")
			
	mp_suite.load_suite(&"Dynamic_Combat_Suite.tres")
	if mp_suite.suite_name != &"Dynamic_Combat_Suite.tres":
		failures.append("Test 13 Failed: suite_name not updated to Dynamic_Combat_Suite.tres")
	if mp_suite.get_stem_count() != 4:
		failures.append("Test 13 Failed: Dynamic_Combat_Suite expected 4 stems, got %d" % mp_suite.get_stem_count())
	mp_suite.free()

	# Test 14: Dynamic combat intensity modulation and track level fading
	var mp_intensity = OpenDouMusicPlayerClass.new()
	mp_intensity.load_suite(&"Dynamic_Combat_Suite.tres")
	mp_intensity.set_combat_intensity(0.0)
	if mp_intensity.stem_players[0].volume_db < -10.0:
		failures.append("Test 14 Failed: Layer 1 should be audible at intensity 0.0, got %f" % mp_intensity.stem_players[0].volume_db)
	if mp_intensity.stem_players[3].volume_db > -50.0:
		failures.append("Test 14 Failed: Layer 4 should be muted at intensity 0.0, got %f" % mp_intensity.stem_players[3].volume_db)
		
	mp_intensity.set_combat_intensity(0.85)
	if not is_equal_approx(mp_intensity.combat_intensity, 0.85):
		failures.append("Test 14 Failed: combat_intensity not updated to 0.85")
	if mp_intensity.stem_players[0].volume_db > -50.0:
		failures.append("Test 14 Failed: Layer 1 should be muted at intensity 0.85, got %f" % mp_intensity.stem_players[0].volume_db)
	if mp_intensity.stem_players[3].volume_db < -10.0:
		failures.append("Test 14 Failed: Layer 4 should be audible at intensity 0.85, got %f" % mp_intensity.stem_players[3].volume_db)
	mp_intensity.free()

	# Test 15: OpenDouMusicPlayer playback controls & stinger trigger
	var mp_play = OpenDouMusicPlayerClass.new()
	mp_play.load_suite(&"Exploration_Ambient_Theme.tres")
	mp_play.play()
	if not mp_play.is_playing():
		failures.append("Test 15 Failed: is_playing() expected true after play()")
		
	mp_play.pause()
	if not mp_play.is_paused():
		failures.append("Test 15 Failed: is_paused() expected true after pause()")
		
	mp_play.stop()
	if mp_play.is_playing():
		failures.append("Test 15 Failed: is_playing() expected false after stop()")
		
	var child_count_before = mp_play.get_child_count()
	mp_play.trigger_stinger(&"Victory_Fanfare")
	var child_count_after = mp_play.get_child_count()
	if child_count_after <= child_count_before:
		failures.append("Test 15 Failed: trigger_stinger did not spawn stinger audio stream player")
	mp_play.free()

	return failures
