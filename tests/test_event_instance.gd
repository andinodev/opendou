class_name TestEventInstance
extends RefCounted

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const RTPCBindingClass = preload("res://addons/opendou/resources/rtpc_binding.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const RTPCValueClass = preload("res://addons/opendou/runtime/rtpc_value.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Setup EventDef with RTPC bindings
	var event_def = AudioEventDefClass.new(&"Test_Gunshot")
	event_def.base_volume_db = 0.0
	event_def.base_pitch_scale = 1.0
	
	var vol_binding = RTPCBindingClass.new(&"Distance_Atten", &"volume_db", null, RTPCBindingClass.Operation.ADD)
	event_def.add_rtpc_binding(vol_binding)
	
	var instance = EventInstanceClass.new(event_def)
	
	# Test 1: Playback states
	instance.play()
	if not instance.is_playing():
		failures.append("Test 1a Failed: Instance should be playing after play()")
		
	instance.pause()
	if instance.is_playing():
		failures.append("Test 1b Failed: Instance should not be playing after pause()")
		
	instance.resume()
	if not instance.is_playing():
		failures.append("Test 1c Failed: Instance should be playing after resume()")
		
	# Test 2: Local parameter precedence over global
	instance.set_parameter(&"Distance_Atten", -12.0, true) # Set immediately
	var global_rtpcs: Dictionary = {
		&"Distance_Atten": RTPCValueClass.new(-6.0)
	}
	
	instance.update_parameters(0.1, global_rtpcs)
	if not is_equal_approx(instance.calculated_volume_db, -12.0):
		failures.append("Test 2 Failed: Local parameter should take precedence (-12.0), got %f" % instance.calculated_volume_db)
		
	# Test 3: Fallback to global parameter
	var instance_global = EventInstanceClass.new(event_def)
	instance_global.update_parameters(0.1, global_rtpcs)
	if not is_equal_approx(instance_global.calculated_volume_db, -6.0):
		failures.append("Test 3 Failed: Should fallback to global (-6.0), got %f" % instance_global.calculated_volume_db)
		
	# Test 4: Stop lifecycle
	instance.stop()
	if not instance.is_finished() or instance.is_playing():
		failures.append("Test 4 Failed: Instance should be finished after stop()")
		
	return failures
