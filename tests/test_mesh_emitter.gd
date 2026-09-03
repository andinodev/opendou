class_name TestMeshEmitter
extends RefCounted

## Fase 11: el punto mas cercano SOBRE los triangulos de una malla, con BVH, contra la fuerza
## bruta; y el emisor multiposicion en modo MESH lo sigue.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const BVHClass = preload("res://addons/opendou/runtime/spatial/triangle_bvh.gd")
const EmitterScript = preload("res://addons/opendou/nodes/opendou_multi_position_emitter_3d.gd")

static func _plane() -> PlaneMesh:
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	pm.subdivide_width = 21
	pm.subdivide_depth = 21   # 22 x 22 celdas x 2 = 968 triangulos
	return pm

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("mesh_emitter")
	var faces: PackedVector3Array = _plane().get_faces()
	var bvh = BVHClass.new()
	bvh.build(faces)
	a.ok(bvh.triangle_count() >= 900, "el plano tiene ~1000 triangulos (%d)" % bvh.triangle_count())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var worst: float = 0.0
	var times: Array = []
	for i in range(20):
		var p := Vector3(rng.randf_range(-30, 30), rng.randf_range(0.5, 6.0), rng.randf_range(-30, 30))
		var t0: int = Time.get_ticks_usec()
		var q: Vector3 = bvh.closest_point(p)
		times.append(Time.get_ticks_usec() - t0)
		var best_d: float = INF
		for t in range(0, faces.size(), 3):
			var c: Vector3 = BVHClass.closest_point_on_triangle(p, faces[t], faces[t + 1], faces[t + 2])
			best_d = minf(best_d, c.distance_squared_to(p))
		worst = maxf(worst, absf(sqrt(best_d) - q.distance_to(p)))
	times.sort()
	print("[OpenDou] BVH de %d triangulos: peor error %.4f m, consulta mediana %d us" % [bvh.triangle_count(), worst, times[times.size() / 2]])
	a.lt(worst, 0.01, "la distancia al punto del BVH coincide con la fuerza bruta a 1 cm")
	a.lt(float(times[times.size() / 2]), 150.0, "la consulta mediana baja de 150 us")

	# El emisor en modo MESH sigue al oyente sobre el plano.
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = _plane()
	tree.root.add_child(mesh_node)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(7.3, 2.0, -4.1)
	var em = EmitterScript.new()
	em.source_mode = EmitterScript.SourceMode.MESH
	em.smooth_position_lag = 0.0
	tree.root.add_child(em)
	em.mesh_path = em.get_path_to(mesh_node)
	em.rebuild_mesh()
	# Fase 15: el nodo ya no se mueve; el punto que suena lo da resolve_emitter_position() a la
	# voz del pool. Se afirma sobre ese punto.
	for i in range(5):
		await tree.process_frame
	var p1: Vector3 = em.resolve_emitter_position(cam.global_position)
	a.ok(p1.is_equal_approx(Vector3(7.3, 0.0, -4.1)), "el punto que suena es el del plano bajo el oyente (%s)" % str(p1))
	var p2: Vector3 = em.resolve_emitter_position(Vector3(7.4, 2.0, -4.1))   # 10 cm: dentro de la histeresis
	a.ok(p2.is_equal_approx(Vector3(7.3, 0.0, -4.1)), "10 cm no lo mueven (histeresis 0.25 m)")
	var p3: Vector3 = em.resolve_emitter_position(Vector3(12.0, 2.0, -4.1))
	a.ok(p3.is_equal_approx(Vector3(12.0, 0.0, -4.1)), "5 m si (%s)" % str(p3))
	a.ok(em.global_position.is_zero_approx(), "el nodo no se mueve (%s)" % str(em.global_position))
	tree.root.remove_child(em); em.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(mesh_node); mesh_node.free()
	return a
