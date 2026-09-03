class_name TestSpatialAcousticsPhase2
extends RefCounted

const AcousticReflectorEngineClass = preload("res://addons/opendou/runtime/spatial/acoustic_reflector_engine.gd")
const AcousticMaterialRegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")
const AcousticLODControllerClass = preload("res://addons/opendou/runtime/spatial/acoustic_lod_controller.gd")

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
	
	# Tests 3-6 (EdgeDiffractionEngine, RoomCouplingEngine): retirados en la Fase 14; la propagacion
	# por sondas de Steam Audio los sustituye.

	# Test 7: AcousticLODController distance evaluation
	var lod_ctrl = AcousticLODControllerClass.new()
	if lod_ctrl == null:
		failures.append("Test 7 Failed: Could not instantiate AcousticLODController")
	else:
		var lod_5m = lod_ctrl.get_lod_level(5.0)
		var lod_18m = lod_ctrl.get_lod_level(18.0)
		var lod_35m = lod_ctrl.get_lod_level(35.0)
		var lod_75m = lod_ctrl.get_lod_level(75.0)
		
		if lod_5m != AcousticLODControllerClass.AcousticLOD.LOD_0_FULL:
			failures.append("Test 7 Failed: 5m should be LOD 0 (Full), got %d" % lod_5m)
		if lod_18m != AcousticLODControllerClass.AcousticLOD.LOD_1_MEDIUM:
			failures.append("Test 7 Failed: 18m should be LOD 1 (Medium), got %d" % lod_18m)
		if lod_35m != AcousticLODControllerClass.AcousticLOD.LOD_2_LOW:
			failures.append("Test 7 Failed: 35m should be LOD 2 (Low), got %d" % lod_35m)
		if lod_75m != AcousticLODControllerClass.AcousticLOD.LOD_3_CULLED:
			failures.append("Test 7 Failed: 75m should be LOD 3 (Culled), got %d" % lod_75m)
		
		# Test 8: LOD feature enablement flags
		var feats_lod0 = lod_ctrl.get_lod_features(AcousticLODControllerClass.AcousticLOD.LOD_0_FULL)
		var feats_lod2 = lod_ctrl.get_lod_features(AcousticLODControllerClass.AcousticLOD.LOD_2_LOW)
		var feats_lod3 = lod_ctrl.get_lod_features(AcousticLODControllerClass.AcousticLOD.LOD_3_CULLED)
		
		if not feats_lod0.get("enable_early_reflections", false) or not feats_lod0.get("enable_mass_law_raycast", false):
			failures.append("Test 8 Failed: LOD 0 must enable early reflections and mass-law raycasting")
		if feats_lod2.get("enable_early_reflections", true) or feats_lod2.get("enable_mass_law_raycast", true):
			failures.append("Test 8 Failed: LOD 2 must disable physics raytracing")
		if not feats_lod3.get("is_culled", false):
			failures.append("Test 8 Failed: LOD 3 must flag is_culled = true")
	
	# Los Tests 9 y 10 cubrian HDRAudioManager, el segundo motor HDR que se elimino
	# al consolidar en AudioHDREngine: eran dos implementaciones duplicadas y ambas
	# quedaban huerfanas. La cobertura del motor consolidado, incluida la ventana y
	# el ducking, esta en tests/test_hdr_voice_gain.gd, y su efecto audible en
	# tests/test_audio_output.gd::run_hdr_ducking_async.

	return failures
