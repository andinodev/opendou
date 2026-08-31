class_name TestSpatialAcousticsPhase2
extends RefCounted

const AcousticReflectorEngineClass = preload("res://addons/opendou/runtime/spatial/acoustic_reflector_engine.gd")
const AcousticMaterialRegistryClass = preload("res://addons/opendou/runtime/spatial/acoustic_material_registry.gd")
const EdgeDiffractionEngineClass = preload("res://addons/opendou/runtime/spatial/edge_diffraction_engine.gd")
const RoomCouplingEngineClass = preload("res://addons/opendou/runtime/spatial/room_coupling_engine.gd")

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
	
	# Test 3: EdgeDiffractionEngine shadow angle calculation
	var diffraction = EdgeDiffractionEngineClass.new()
	if diffraction == null:
		failures.append("Test 3 Failed: Could not instantiate EdgeDiffractionEngine")
	else:
		# Straight line (no bend): angle should be ~0 radians
		var angle_straight = diffraction.calculate_shadow_angle(Vector3(-10, 0, 0), Vector3(0, 0, 0), Vector3(10, 0, 0))
		if absf(angle_straight) > 0.01:
			failures.append("Test 3 Failed: Straight line should have 0 shadow angle, got %.3f rad" % angle_straight)
		
		# 90-degree corner bend
		var angle_90 = diffraction.calculate_shadow_angle(Vector3(0, 0, -10), Vector3(0, 0, 0), Vector3(10, 0, 0))
		if absf(angle_90 - (PI / 2.0)) > 0.05:
			failures.append("Test 3 Failed: Expected ~1.571 rad (90 deg) shadow angle, got %.3f rad" % angle_90)
		
		# Test 4: Diffraction filter cutoff & gain curves
		var filter_straight = diffraction.calculate_diffraction_filter(0.0)
		var filter_90 = diffraction.calculate_diffraction_filter(PI / 2.0)
		var filter_160 = diffraction.calculate_diffraction_filter(deg_to_rad(160.0))
		
		if not (filter_160["cutoff_lpf"] < filter_90["cutoff_lpf"] and filter_90["cutoff_lpf"] < filter_straight["cutoff_lpf"]):
			failures.append("Test 4 Failed: Diffraction cutoff LPF should decrease as shadow angle increases (0: %.0f, 90: %.0f, 160: %.0f)" % [
				filter_straight["cutoff_lpf"], filter_90["cutoff_lpf"], filter_160["cutoff_lpf"]
			])
		
		if filter_160["gain"] >= filter_straight["gain"]:
			failures.append("Test 4 Failed: Diffraction gain should decrease into shadow")
		
		# Obstacle corner edge detection
		var edge_pt = diffraction.find_diffraction_edge(Vector3(0, 0, -5), Vector3(0, 0, 5), Vector3(0, 0, 0), Vector3(2, 2, 0.5))
		if edge_pt.distance_to(Vector3(2, 0, 0)) > 0.1 and edge_pt.distance_to(Vector3(-2, 0, 0)) > 0.1:
			failures.append("Test 4 Failed: Expected edge point at (+-2, 0, 0), got %s" % str(edge_pt))
	
	# Test 5: RoomCouplingEngine energy coupling calculation
	var coupling = RoomCouplingEngineClass.new()
	if coupling == null:
		failures.append("Test 5 Failed: Could not instantiate RoomCouplingEngine")
	else:
		# Open portal coupling
		var open_energy = coupling.calculate_coupled_energy(100.0, 4.0, 100.0, 1.0)
		var closed_energy = coupling.calculate_coupled_energy(100.0, 4.0, 100.0, 0.0)
		var half_open_energy = coupling.calculate_coupled_energy(100.0, 4.0, 100.0, 0.5)
		
		if closed_energy != 0.0:
			failures.append("Test 5 Failed: Closed portal (0.0 open) should have 0.0 coupled energy, got %.2f" % closed_energy)
		if open_energy <= half_open_energy:
			failures.append("Test 5 Failed: Fully open portal energy (%.2f) should be > half open energy (%.2f)" % [open_energy, half_open_energy])
		
		# Test 6: Portal sound spread expansion with listener proximity
		var spread_far = coupling.calculate_portal_sound_spread(Vector3(0, 0, 20), Vector3(0, 0, 0), 2.0, 15.0)
		var spread_near = coupling.calculate_portal_sound_spread(Vector3(0, 0, 1), Vector3(0, 0, 0), 2.0, 15.0)
		var spread_mid = coupling.calculate_portal_sound_spread(Vector3(0, 0, 8), Vector3(0, 0, 0), 2.0, 15.0)
		
		if is_equal_approx(spread_far, 15.0) == false:
			failures.append("Test 6 Failed: Distant listener should hear narrow point source (~15 deg spread), got %.1f" % spread_far)
		if is_equal_approx(spread_near, 180.0) == false:
			failures.append("Test 6 Failed: Listener at portal threshold should hear wide wrap (180 deg spread), got %.1f" % spread_near)
		if not (spread_far < spread_mid and spread_mid < spread_near):
			failures.append("Test 6 Failed: Spread should expand smoothly with proximity (far: %.1f, mid: %.1f, near: %.1f)" % [
				spread_far, spread_mid, spread_near
			])
	
	return failures
