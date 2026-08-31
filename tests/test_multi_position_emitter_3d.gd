class_name TestMultiPositionEmitter3DClass
extends RefCounted

## Unit and Integration Tests for OpenDouMultiPositionEmitter3D (TASK-055 - Task 2)

const OpenDouMultiPositionEmitter3DClass = preload("res://addons/opendou/nodes/opendou_multi_position_emitter_3d.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	var emitter = OpenDouMultiPositionEmitter3DClass.new()
	if emitter == null:
		failures.append("Test 1 Failed: OpenDouMultiPositionEmitter3D instantiation failed")
		return failures

	# Test 1: Closest Point Tracking
	var pts: Array[Vector3] = [Vector3(0, 0, 0), Vector3(20, 0, 0), Vector3(40, 0, 0)]
	emitter.set_emission_points(pts)
	emitter.rendering_mode = 0 # CLOSEST_POINT_TRACKING
	var closest = emitter.get_closest_point_to(Vector3(18, 0, 0))
	if closest != Vector3(20, 0, 0):
		failures.append("Test 1 Failed: Closest point to (18, 0, 0) should be (20, 0, 0), got %s" % str(closest))

	# Test 2: Multi-Point Blended Position & Weights
	emitter.set_emission_points([Vector3(0, 0, 0), Vector3(20, 0, 0)])
	emitter.rendering_mode = 1 # MULTI_POINT_BLENDED
	emitter.cull_distance = 50.0
	var blended = emitter.calculate_blended_position(Vector3(10, 0, 0))
	if not is_equal_approx(blended.x, 10.0):
		failures.append("Test 2 Failed: Symmetrical blended position between 0 and 20 should be ~10.0, got %.2f" % blended.x)

	# Test 3: Envelopment Transition inside AABB
	emitter.envelopment_on_inside = true
	var is_inside = emitter.is_position_inside_emission_volume(Vector3(10, 0, 0))
	if not is_inside:
		failures.append("Test 3 Failed: Position (10, 0, 0) should be inside emission volume AABB")
	var is_outside = emitter.is_position_inside_emission_volume(Vector3(100, 0, 0))
	if is_outside:
		failures.append("Test 3 Failed: Position (100, 0, 0) should be outside emission volume AABB")

	# Test 4: Dynamic Vertices API (add, remove, clear, set)
	emitter.clear_emission_points()
	if emitter.emission_points.size() != 0:
		failures.append("Test 4 Failed: clear_emission_points did not empty array")
	emitter.add_emission_point(Vector3(5, 5, 5))
	emitter.add_emission_point(Vector3(15, 5, 5))
	if emitter.emission_points.size() != 2:
		failures.append("Test 4 Failed: add_emission_point size mismatch")
	emitter.remove_emission_point(0)
	if emitter.emission_points.size() != 1 or emitter.emission_points[0] != Vector3(15, 5, 5):
		failures.append("Test 4 Failed: remove_emission_point failed")

	# Test 5: Dynamic Points Extraction from MeshInstance3D
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(10, 2, 4)
	mesh_inst.mesh = box
	emitter.update_points_from_mesh(mesh_inst, 1)
	if emitter.emission_points.size() < 4:
		failures.append("Test 5 Failed: update_points_from_mesh extracted insufficient vertices: %d" % emitter.emission_points.size())
	mesh_inst.free()

	# Test 6: Comb-Filtering Random Phase Offset Generation
	emitter.random_phase_offset = true
	var offset1 = emitter.get_vertex_micro_phase_offset(0)
	var offset2 = emitter.get_vertex_micro_phase_offset(1)
	if is_equal_approx(offset1, offset2):
		failures.append("Test 6 Failed: Vertex phase offsets should be distinct to prevent comb filtering")

	# Test 7: Vertex Occlusion Raycast Origin
	emitter.set_emission_points([Vector3(5, 5, 5), Vector3(15, 5, 5)])
	emitter.vertex_occlusion = true
	var occ_origin = emitter.get_occlusion_raycast_origin(Vector3(18, 0, 0))
	if occ_origin != Vector3(15, 5, 5): # active vertex
		failures.append("Test 7 Failed: Occlusion raycast origin should be the active closest vertex (15, 5, 5), got %s" % str(occ_origin))

	# Test 8: Cull Distance Boundary
	var should_cull = emitter.should_cull_at_distance(Vector3(200, 0, 0))
	if not should_cull:
		failures.append("Test 8 Failed: Position at 200m should be culled with cull_distance 50m")

	emitter.free()
	return failures
