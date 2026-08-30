class_name TestSpatialAcoustics
extends RefCounted

const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var acoustics = SpatialAcousticsManagerClass.new()
	
	var room_a = AudioRoomClass.new(&"Room_A", 1.2, 0.4)
	var room_b = AudioRoomClass.new(&"Room_B", 2.0, 0.6)
	var room_c = AudioRoomClass.new(&"Room_C", 0.8, 0.2)
	
	# Portal 1 connects Room A and Room B at (10, 0, 0)
	var portal_1 = AudioPortalClass.new(&"Portal_AB", &"Room_A", &"Room_B", Vector3(10.0, 0.0, 0.0), 1.0)
	# Portal 2 connects Room B and Room C at (20, 0, 0)
	var portal_2 = AudioPortalClass.new(&"Portal_BC", &"Room_B", &"Room_C", Vector3(20.0, 0.0, 0.0), 0.5)
	
	acoustics.register_room(room_a)
	acoustics.register_room(room_b)
	acoustics.register_room(room_c)
	acoustics.register_portal(portal_1)
	acoustics.register_portal(portal_2)
	
	# Test 1: Direct Line of Sight (Same room)
	var emitter_pos = Vector3(0.0, 0.0, 0.0)
	var listener_pos = Vector3(5.0, 0.0, 0.0)
	var path_same = acoustics.calculate_acoustic_path(emitter_pos, listener_pos, &"Room_A", &"Room_A")
	
	if not path_same.is_direct_los or not is_equal_approx(path_same.virtual_distance, 5.0):
		failures.append("Test 1a Failed: Same-room direct path expected dist 5.0, got %f" % path_same.virtual_distance)
	if not is_equal_approx(path_same.accumulated_lpf, 20000.0):
		failures.append("Test 1b Failed: Same-room LPF expected 20000Hz, got %f" % path_same.accumulated_lpf)
		
	# Test 2: Adjacent Rooms Diffraction (Room A -> Room B)
	# Emitter at (0, 0, 0) in Room A, Portal 1 at (10, 0, 0), Listener at (10, 10, 0) in Room B
	# Distance: dist(E, P) = 10, dist(P, L) = 10 -> Total = 20
	var listener_b = Vector3(10.0, 10.0, 0.0)
	var path_ab = acoustics.calculate_acoustic_path(emitter_pos, listener_b, &"Room_A", &"Room_B")
	
	if path_ab.is_direct_los:
		failures.append("Test 2a Failed: Inter-room path should NOT be direct line of sight")
	if not is_equal_approx(path_ab.virtual_distance, 20.0):
		failures.append("Test 2b Failed: Expected zig-zag distance 20.0, got %f" % path_ab.virtual_distance)
	if path_ab.apparent_origin != Vector3(10.0, 0.0, 0.0):
		failures.append("Test 2c Failed: Apparent origin should be Portal 1 position (10,0,0), got %s" % str(path_ab.apparent_origin))
		
	# Test 3: Multi-Room Chaining & LPF Filtering (Room A -> Room B -> Room C)
	# Emitter at (0,0,0) in Room A, Listener at (30,0,0) in Room C
	# Segment 1: (0,0,0) to P1(10,0,0) = 10
	# Segment 2: P1(10,0,0) to P2(20,0,0) = 10
	# Segment 3: P2(20,0,0) to L(30,0,0) = 10 -> Total = 30
	# Portal 2 has open_factor = 0.5 -> LPF = lerp(200, 20000, 0.5) = 10100 Hz
	var listener_c = Vector3(30.0, 0.0, 0.0)
	var path_ac = acoustics.calculate_acoustic_path(emitter_pos, listener_c, &"Room_A", &"Room_C")
	
	if not is_equal_approx(path_ac.virtual_distance, 30.0):
		failures.append("Test 3a Failed: Multi-room distance expected 30.0, got %f" % path_ac.virtual_distance)
	if path_ac.apparent_origin != Vector3(20.0, 0.0, 0.0):
		failures.append("Test 3b Failed: Apparent origin should be Portal 2 entering Room C (20,0,0), got %s" % str(path_ac.apparent_origin))
	if not is_equal_approx(path_ac.accumulated_lpf, 10100.0):
		failures.append("Test 3c Failed: Accumulated LPF expected 10100Hz, got %f" % path_ac.accumulated_lpf)

	# Test 4: detect_surface_at() - Room with floor_surface = &"Metal"
	var metal_room = AudioRoomClass.new(&"Metal_Room", 0.5, 0.3)
	metal_room.floor_surface = &"Metal"
	metal_room.set_bounds(AABB(Vector3(-5.0, 0.0, -5.0), Vector3(10.0, 5.0, 10.0)))
	var acoustics2 = SpatialAcousticsManagerClass.new()
	acoustics2.register_room(metal_room)

	var inside_pos = Vector3(0.0, 1.0, 0.0)
	var detected = acoustics2.detect_surface_at(inside_pos)
	if detected != &"Metal":
		failures.append("Test 4a Failed: detect_surface_at inside Metal_Room expected &\"Metal\", got %s" % str(detected))

	# Test 5: detect_surface_at() - No room contains point -> fallback &"Concrete"
	var outside_pos = Vector3(100.0, 1.0, 100.0)
	var fallback = acoustics2.detect_surface_at(outside_pos)
	if fallback != &"Concrete":
		failures.append("Test 5a Failed: detect_surface_at outside any room expected &\"Concrete\", got %s" % str(fallback))

	# Test 6: detect_surface_at() - world_3d is null, no room -> fallback &"Concrete"
	var acoustics3 = SpatialAcousticsManagerClass.new()
	var null_world_fallback = acoustics3.detect_surface_at(Vector3(999.0, 0.0, 999.0), null)
	if null_world_fallback != &"Concrete":
		failures.append("Test 6a Failed: detect_surface_at with null world and no room expected &\"Concrete\", got %s" % str(null_world_fallback))

	return failures
