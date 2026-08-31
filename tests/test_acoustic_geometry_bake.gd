class_name TestAcousticGeometryBakeClass
extends RefCounted

## Unit and Integration Tests for OpenDouAcousticGeometryBake, Inspector Plugin & Gizmos (TASK-056)

const OpenDouAcousticGeometryBakeClass = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")
const OpenDouAcousticGeometryBakeInspectorPluginClass = preload("res://addons/opendou/editor/opendou_acoustic_geometry_bake_inspector.gd")
const OpenDouGizmoPlugin3DClass = preload("res://addons/opendou/editor/gizmos/opendou_gizmo_plugin_3d.gd")
const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	# Test 1: Instantiation and default properties
	var bake_node = OpenDouAcousticGeometryBakeClass.new()
	if bake_node == null:
		failures.append("Test 1 Failed: OpenDouAcousticGeometryBake instantiation failed")
		return failures
	if bake_node.target_group != &"AcousticObstacle" or bake_node.simplification_step != 1:
		failures.append("Test 1 Failed: Default property values mismatch")

	# Test 2: Child Mesh Scanning & Geometry Extraction
	var mesh_child = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(4, 2, 6)
	mesh_child.mesh = box_mesh
	mesh_child.name = "TestObstacleMesh"
	bake_node.add_child(mesh_child)
	
	var res_stats = bake_node.bake_geometry()
	if bake_node.get_baked_triangle_count() < 12: # Box has 12 triangles (36 vertices)
		failures.append("Test 2 Failed: Expected at least 12 triangles from box mesh, got %d" % bake_node.get_baked_triangle_count())

	# Test 3: Group-based Mesh Scanning
	if bake_node.target_group != &"AcousticObstacle":
		failures.append("Test 3 Failed: target_group mismatch")

	# Test 4: Simplification Step Face Sampling
	bake_node.simplification_step = 2
	bake_node.bake_geometry()
	if bake_node.get_baked_triangle_count() != 6: # Half the triangles when step is 2
		failures.append("Test 4 Failed: Simplification step 2 should produce 6 triangles, got %d" % bake_node.get_baked_triangle_count())
	bake_node.simplification_step = 1
	bake_node.bake_geometry()

	# Test 5: Acoustic Material Assignment and Normal Calculation
	var triangles = bake_node.get_baked_triangles()
	if triangles.is_empty():
		failures.append("Test 5 Failed: Baked triangles array is empty")
	else:
		var tri0 = triangles[0]
		if tri0.get("material") != &"Concrete" or not tri0.has("normal") or not tri0.has("center"):
			failures.append("Test 5 Failed: Triangle structure missing material or normal data")

	# Test 6: Möller–Trumbore Raycast Hit Detection
	# Box is at (0,0,0) size (4, 2, 6) (x in [-2, 2], y in [-1, 1], z in [-3, 3])
	var hit_result = bake_node.raycast_baked_geometry(Vector3(0, 5, 0), Vector3(0, -5, 0))
	if not hit_result.get("hit", false):
		failures.append("Test 6 Failed: Raycast directly through box should hit")
	elif not is_equal_approx(hit_result.get("position").y, 1.0):
		failures.append("Test 6 Failed: Raycast hit y should be 1.0, got %.2f" % hit_result.get("position").y)

	# Test 7: Möller–Trumbore Raycast Miss Detection
	var miss_result = bake_node.raycast_baked_geometry(Vector3(50, 50, 50), Vector3(60, 60, 60))
	if miss_result.get("hit", false):
		failures.append("Test 7 Failed: Distant raycast should miss")

	# Test 8: Baked Data Clearing and Reset Stats
	bake_node.clear_baked_data()
	if bake_node.get_baked_triangle_count() != 0 or bake_node.stats.get("triangle_count") != 0:
		failures.append("Test 8 Failed: clear_baked_data did not reset triangles or stats")

	# Test 9: Gizmo Plugin Spatial Nodes Detection
	var room_node = OpenDouRoom3DClass.new()
	if not OpenDouGizmoPlugin3DClass.is_supported_spatial_node(bake_node):
		failures.append("Test 9 Failed: Gizmo plugin should handle OpenDouAcousticGeometryBake")
	if not OpenDouGizmoPlugin3DClass.is_supported_spatial_node(room_node):
		failures.append("Test 9 Failed: Gizmo plugin should handle OpenDouRoom3D")

	# Test 10: Inspector Plugin Object Handling
	if not OpenDouAcousticGeometryBakeInspectorPluginClass.is_supported_bake_node(bake_node):
		failures.append("Test 10 Failed: Inspector plugin should handle OpenDouAcousticGeometryBake")

	# Cleanup
	mesh_child.free()
	bake_node.free()
	room_node.free()

	return failures
