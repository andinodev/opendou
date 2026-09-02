class_name TestEarlyReflectionsHRTF
extends RefCounted

const AcousticReflectorClass = preload("res://addons/opendou/core/spatial/acoustic_reflector.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Acoustic Reflector calculation in a box room
	var src = Vector3(0, 1.5, 0)
	var listener = Vector3(2, 1.5, 0)
	var room_min = Vector3(-10, 0, -10)
	var room_max = Vector3(10, 5, 10)
	
	var reflections = AcousticReflectorClass.calculate_box_reflections(src, listener, room_min, room_max, 0.15)
	if reflections.is_empty():
		failures.append("Test 1a Failed: Expected specular early reflections in box room")
	else:
		# Check first reflection properties
		var first = reflections[0]
		if first.delay_ms <= 0.0:
			failures.append("Test 1b Failed: Reflection should have non-zero positive delay relative to direct sound")
		if first.gain_linear <= 0.0 or first.gain_linear > 1.0:
			failures.append("Test 1c Failed: Reflection gain should be between 0.0 and 1.0, got %f" % first.gain_linear)
			
	# Los Tests 2 y 3 (pistas binaurales de Woodworth en GDScript) se retiraron en la Fase
	# 7B: el binaural real es la extension nativa y lo afirma tests/test_binaural.gd.

	return failures
