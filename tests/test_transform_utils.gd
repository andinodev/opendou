class_name TestTransformUtils
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TransformUtilsClass = preload("res://addons/opendou/runtime/spatial/transform_utils.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("transform_utils")

	# Fuera del arbol, un hijo bajo un padre ROTADO 90 grados en Y.
	# Sumar posiciones daria (1,0,0)+(5,0,0) = (6,0,0); lo correcto es que la
	# rotacion del padre gire el offset del hijo hasta (5,0,-1).
	var parent := Node3D.new()
	parent.position = Vector3(5.0, 0.0, 0.0)
	parent.rotation = Vector3(0.0, PI * 0.5, 0.0)
	var child := Node3D.new()
	child.position = Vector3(1.0, 0.0, 0.0)
	parent.add_child(child)

	var pos: Vector3 = TransformUtilsClass.world_position_of(child)
	a.approx(pos.x, 5.0, "la rotacion del padre no desplaza X", 0.001)
	a.approx(pos.z, -1.0, "la rotacion del padre gira el offset a Z", 0.001)

	# Escala del padre: un offset de 2 bajo escala 3 son 6 unidades.
	var scaler := Node3D.new()
	scaler.scale = Vector3(3.0, 3.0, 3.0)
	var kid := Node3D.new()
	kid.position = Vector3(2.0, 0.0, 0.0)
	scaler.add_child(kid)
	a.approx(TransformUtilsClass.world_position_of(kid).x, 6.0, "la escala del padre multiplica el offset", 0.001)

	# Un nodo sin padre devuelve su propia posicion.
	var lonely := Node3D.new()
	lonely.position = Vector3(7.0, 8.0, 9.0)
	a.approx(TransformUtilsClass.world_position_of(lonely).y, 8.0, "sin padre devuelve su propia posicion", 0.001)

	# null no revienta.
	a.eq(TransformUtilsClass.world_position_of(null), Vector3.ZERO, "null devuelve el origen")

	# AABB envolvente de una caja unitaria rotada 45 grados en Y: su extension
	# en X y Z pasa de 1 a sqrt(2), porque un AABB no puede representar una caja
	# rotada y tiene que envolverla.
	var rot := Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3.ZERO)
	var box := TransformUtilsClass.enclosing_aabb(rot, Vector3.ONE)
	a.approx(box.size.x, sqrt(2.0), "el AABB envuelve la caja rotada en X", 0.01)
	a.approx(box.size.z, sqrt(2.0), "el AABB envuelve la caja rotada en Z", 0.01)
	a.approx(box.size.y, 1.0, "el eje sin rotar no crece", 0.01)
	a.approx(box.get_center().length(), 0.0, "el AABB queda centrado en el origen", 0.01)

	# Con traslacion, el AABB se mueve con ella.
	var moved := Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	a.approx(TransformUtilsClass.enclosing_aabb(moved, Vector3.ONE).get_center().x, 10.0,
		"el AABB sigue la traslacion", 0.001)

	kid.free(); scaler.free()
	child.free(); parent.free()
	lonely.free()
	return a
