class_name TestEarlyReflectionsHRTF
extends RefCounted

const AcousticReflectorClass = preload("res://addons/opendou/core/spatial/acoustic_reflector.gd")
const AudioSpatialBinauralClass = preload("res://addons/opendou/core/spatial/audio_spatial_binaural.gd")

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
			
	# Test 2: Binaural HRTF Cues for Sound on Right (+90 degrees azimuth)
	var source_right = Vector3(10, 0, 0)
	var listener_tf = Transform3D.IDENTITY
	
	var cues_right = AudioSpatialBinauralClass.calculate_binaural_cues(source_right, listener_tf)
	if not is_equal_approx(cues_right.azimuth_deg, 90.0):
		failures.append("Test 2a Failed: Expected 90.0 deg azimuth for source on right, got %f" % cues_right.azimuth_deg)
		
	if cues_right.left_ear_delay_ms <= 0.0 or cues_right.right_ear_delay_ms != 0.0:
		failures.append("Test 2b Failed: Left ear should have positive ITD delay for right-side sound")
		
	if cues_right.left_ear_gain_db >= 0.0:
		failures.append("Test 2c Failed: Left ear should have negative head shadowing attenuation")
		
	# Test 3: Binaural HRTF Cues for Sound in Front (0 degrees azimuth)
	var source_front = Vector3(0, 0, -5)
	var cues_front = AudioSpatialBinauralClass.calculate_binaural_cues(source_front, listener_tf)
	if not is_equal_approx(cues_front.azimuth_deg, 0.0):
		failures.append("Test 3a Failed: Expected 0.0 deg azimuth for sound straight ahead, got %f" % cues_front.azimuth_deg)
	if not is_equal_approx(cues_front.left_ear_delay_ms, 0.0) or not is_equal_approx(cues_front.right_ear_delay_ms, 0.0):
		failures.append("Test 3b Failed: Frontal sound should have 0.0 ITD between ears")
		
	return failures
