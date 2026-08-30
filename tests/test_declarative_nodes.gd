class_name TestDeclarativeNodes
extends RefCounted

const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")
const OpenDouEventPlayer2DClass = preload("res://addons/opendou/nodes/opendou_event_player_2d.gd")
const OpenDouEventPlayerClass = preload("res://addons/opendou/nodes/opendou_event_player.gd")
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

	return failures
