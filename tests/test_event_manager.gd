class_name TestEventManager
extends RefCounted

const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const RTPCBindingClass = preload("res://addons/opendou/resources/rtpc_binding.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	var manager = AudioEventManagerClass.new()
	
	# Register an EventDef
	var event_def = AudioEventDefClass.new(&"Footstep")
	event_def.base_volume_db = -3.0
	manager.register_event_definition(event_def)
	
	# Test 1: Post event by name
	var instance = manager.post_event(&"Footstep")
	if instance == null:
		failures.append("Test 1 Failed: Expected EventInstance from post_event, got null")
	elif manager.active_instances.size() != 1:
		failures.append("Test 1 Failed: Active instances size expected 1, got %d" % manager.active_instances.size())
		
	# Test 2: Global parameter registration and update
	manager.set_global_parameter(&"MasterVol", 5.0, true)
	if not is_equal_approx(manager.get_global_parameter(&"MasterVol"), 5.0):
		failures.append("Test 2 Failed: Global parameter expected 5.0, got %f" % manager.get_global_parameter(&"MasterVol"))
		
	# Test 3: Stop all
	manager.stop_all()
	if not manager.active_instances.is_empty():
		failures.append("Test 3 Failed: Active instances should be empty after stop_all()")
		
	return failures
