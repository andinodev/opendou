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
		

	# Fase 7B: la instancia lleva los parametros de atenuacion con los defectos de Godot,
	# y los copia del emisor de nodo cuando lo hay.
	var def7 = AudioEventDef.new(&"Atten")
	var inst7 = EventInstance.new(def7, null)
	if not is_equal_approx(inst7.unit_size, 10.0) or not is_equal_approx(inst7.attenuation_filter_cutoff_hz, 5000.0) or not is_equal_approx(inst7.attenuation_filter_db, -24.0) or inst7.attenuation_model != 0 or not is_equal_approx(inst7.attenuation_max_distance, 0.0):
		failures.append("7B-a: la instancia no arranca con los defectos de atenuacion de Godot")
	def7.unit_size = 4.0
	def7.attenuation_model = 2
	var inst7b = EventInstance.new(def7, null)
	if not is_equal_approx(inst7b.unit_size, 4.0) or inst7b.attenuation_model != 2:
		failures.append("7B-b: la instancia no copia la atenuacion de la definicion")
	var p3 = AudioStreamPlayer3D.new()
	p3.unit_size = 2.5
	p3.max_distance = 30.0
	p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	p3.attenuation_filter_cutoff_hz = 3000.0
	p3.attenuation_filter_db = -12.0
	p3.volume_db = -6.0
	inst7b.copy_attenuation_from_player(p3)
	if not is_equal_approx(inst7b.unit_size, 2.5) or not is_equal_approx(inst7b.attenuation_max_distance, 30.0) or inst7b.attenuation_model != 1 or not is_equal_approx(inst7b.attenuation_filter_cutoff_hz, 3000.0) or not is_equal_approx(inst7b.attenuation_filter_db, -12.0) or not is_equal_approx(inst7b.emitter_volume_db, -6.0):
		failures.append("7B-c: copy_attenuation_from_player no copia los seis valores del nodo")
	if not is_equal_approx(inst7b.max_distance, 100.0):
		failures.append("7B-d: max_distance del robo de voces NO debe cambiar al copiar la atenuacion")
	p3.free()

	return failures
