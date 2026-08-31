class_name TestSpatialAcousticsPhase2
extends RefCounted

const AcousticReflectorEngineClass = preload("res://addons/opendou/runtime/spatial/acoustic_reflector_engine.gd")
const AcousticMaterialRegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: AcousticReflectorEngine 6-direction ray generation & delay calculation
	var reflector = AcousticReflectorEngineClass.new()
	if reflector == null:
		failures.append("Test 1 Failed: Could not instantiate AcousticReflectorEngine")
		return failures
	
	var rays = reflector.get_orthogonal_probe_directions()
	if rays.size() != 6:
		failures.append("Test 1 Failed: Expected 6 orthogonal ray directions, got %d" % rays.size())
	
	# Delay calculation: Emitter at (0,0,0), Hit surface at (5,0,0), Listener at (0,0,0) -> Total distance = 10m
	# Delay = 10.0 / 343.0 = ~0.02915 s
	var delay_10m = reflector.calculate_reflection_delay(Vector3(0, 0, 0), Vector3(5, 0, 0), Vector3(0, 0, 0))
	var expected_delay = 10.0 / 343.0
	if absf(delay_10m - expected_delay) > 0.001:
		failures.append("Test 1 Failed: Expected delay %.4f s for 10m roundtrip, got %.4f s" % [expected_delay, delay_10m])
	
	# Virtual image source point calculation:
	# Emitter at (2,0,0), Surface at (5,0,0) with normal (-1,0,0)
	# Image source should be at (8,0,0)
	var image_src = reflector.calculate_image_source_position(Vector3(2, 0, 0), Vector3(5, 0, 0), Vector3(-1, 0, 0))
	if image_src.distance_to(Vector3(8, 0, 0)) > 0.01:
		failures.append("Test 1 Failed: Expected virtual image source at (8,0,0), got %s" % str(image_src))
	
	# Test 2: Material absorption and reflection gain/LPF
	var metal_response = reflector.calculate_surface_reflection_response(&"Metal", 10.0)
	var foliage_response = reflector.calculate_surface_reflection_response(&"Foliage", 10.0)
	
	if not (metal_response.has("gain") and metal_response.has("cutoff_lpf")):
		failures.append("Test 2 Failed: Reflection response missing gain or cutoff_lpf")
	else:
		if metal_response["gain"] <= foliage_response["gain"]:
			failures.append("Test 2 Failed: Metal reflection gain (%.2f) should be > Foliage reflection gain (%.2f)" % [
				metal_response["gain"], foliage_response["gain"]
			])
		if metal_response["cutoff_lpf"] <= 500.0:
			failures.append("Test 2 Failed: Metal reflection cutoff LPF should be > 500 Hz, got %.1f" % metal_response["cutoff_lpf"])
	
	return failures
