class_name TestSplineAnchor
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const SplineEmitterClass = preload("res://addons/opendou/nodes/opendou_spline_emitter_3d.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spline_anchor")

	var emitter = SplineEmitterClass.new()
	var curve := Curve3D.new()
	# Una recta de 40 m sobre el eje X, como un rio, DESPLAZADA 5 m en Z respecto
	# al origen del nodo. El desplazamiento es esencial para que la prueba valga:
	# con la curva pasando por el origen del nodo, el punto mas cercano coincide
	# con la posicion del nodo, el lerp no mueve nada y la deriva no se manifiesta.
	curve.add_point(Vector3(-20.0, 0.0, 5.0))
	curve.add_point(Vector3(20.0, 0.0, 5.0))
	emitter.curve = curve
	emitter.max_virtual_distance = 100.0
	tree.root.add_child(emitter)
	await tree.process_frame

	# El oyente esta a 25 m de la recta, frente a su punto medio.
	var listener := Vector3(0.0, 0.0, 30.0)
	var first: Vector3 = emitter.get_closest_virtual_point(listener)
	a.approx(first.z, 5.0, "el punto mas cercano esta sobre la curva, no en el oyente", 0.01)

	# Se simulan 60 frames de acustica. El nodo se movera como cabeza de
	# reproduccion, pero la CURVA debe quedarse donde se autoro.
	for _f in range(60):
		emitter.update_spline_acoustics(listener, Vector3.ZERO, 0.016)
		await tree.process_frame

	var after: Vector3 = emitter.get_closest_virtual_point(listener)
	# Sin ancla, la curva migraba de z=5 a z=101: se pasaba de largo al oyente y
	# seguia acelerando. La deriva medida antes del arreglo era de 96 m.
	a.lt(absf(after.z - first.z), 0.5, "la curva no deriva hacia el oyente")
	a.lt(absf(after.x - first.x), 0.5, "la curva no se desplaza en X")

	# Con el oyente en otro sitio, el punto mas cercano cambia como debe: el
	# emisor sigue reaccionando, lo que no hace es arrastrar la geometria.
	var moved_listener := Vector3(15.0, 0.0, 30.0)
	var at_moved: Vector3 = emitter.get_closest_virtual_point(moved_listener)
	a.gt(at_moved.x, first.x + 5.0, "el punto mas cercano sigue al oyente a lo largo de la curva")

	# reanchor() reubica el marco a proposito, para un rio sobre un vehiculo.
	emitter.global_position = Vector3(0.0, 0.0, 100.0)
	emitter.reanchor()
	var anchored: Vector3 = emitter.get_closest_virtual_point(Vector3(0.0, 0.0, 130.0))
	a.gt(anchored.z, 100.0, "tras reanchor la curva vive en el sitio nuevo")

	tree.root.remove_child(emitter)
	emitter.free()
	return a
