class_name TestDirectEffect
extends RefCounted

## Fase 12: el simulador de Steam Audio ve el bake (oclusion, transmision por material, aire).

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

static func _sim(method: String, a1 = null, a2 = null, a3 = null, a4 = null, a5 = null, a6 = null, a7 = null) -> Variant:
	if a1 == null:
		return ClassDB.class_call_static("OpenDouSimulator", method)
	if a2 == null:
		return ClassDB.class_call_static("OpenDouSimulator", method, a1)
	if a4 == null:
		return ClassDB.class_call_static("OpenDouSimulator", method, a1, a2, a3)
	return ClassDB.class_call_static("OpenDouSimulator", method, a1, a2, a3, a4, a5, a6, a7)

static func _scene(method: String) -> Variant:
	return ClassDB.class_call_static("OpenDouAcousticScene", method)

## Escena con un muro de `material` entre la fuente (0,1.5,-6) y el oyente (0,1.5,0).
static func _direct_behind(tree: SceneTree, material: StringName) -> PackedFloat32Array:
	var wall := TestSteamSceneClass.make_wall(tree, Vector3(0, 1.5, -3), material)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	_sim("configure", 8, 16, 2)
	var h: int = int(_sim("create_source"))
	_sim("set_listener", Vector3(0, 1.5, 0), Vector3(0, 0, -1), Vector3.UP)
	_sim("set_source_inputs", h, Vector3(0, 1.5, -6), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5)
	_sim("run_direct")
	var out: PackedFloat32Array = _sim("get_direct", h)
	_sim("release_source", h)
	_sim("shutdown")
	tree.root.remove_child(bake); bake.free()
	tree.root.remove_child(wall); wall.free()
	_scene("clear")
	return out

static func run_simulator_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("direct_simulator")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouSimulator"):
		print("[OpenDou] extension nativa AUSENTE: simulador omitido")
		return a
	var glass: PackedFloat32Array = _direct_behind(tree, &"Glass")
	var concrete: PackedFloat32Array = _direct_behind(tree, &"Concrete")
	print("[OpenDou] efecto directo: tras Glass occl=%.2f tr=(%.3f %.3f %.3f) | tras Concrete occl=%.2f tr=(%.3f %.3f %.3f)" % [glass[0], glass[1], glass[2], glass[3], concrete[0], concrete[1], concrete[2], concrete[3]])
	a.lt(glass[0], 0.3, "el muro de cristal ocluye (occlusion < 0.3)")
	a.lt(concrete[0], 0.3, "y el de hormigon tambien")
	a.gt(glass[1], concrete[1] + 0.02, "el cristal transmite mas graves que el hormigon")
	a.gt(glass[3], concrete[3], "y mas agudos")
	# Sin muro: nada ocluye; a 200 m el aire come la banda alta. Hace falta ALGUNA geometria
	# para que la escena exista: un suelo lejos del camino.
	var floor := TestSteamSceneClass.make_wall(tree, Vector3(0, -20, 0), &"Concrete")
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	_sim("configure", 8, 16, 2)
	var h: int = int(_sim("create_source"))
	_sim("set_listener", Vector3.ZERO, Vector3(0, 0, -1), Vector3.UP)
	_sim("set_source_inputs", h, Vector3(0, 0, -10), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5)
	_sim("run_direct")
	var near: PackedFloat32Array = _sim("get_direct", h)
	_sim("set_source_inputs", h, Vector3(0, 0, -200), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5)
	_sim("run_direct")
	var far: PackedFloat32Array = _sim("get_direct", h)
	print("[OpenDou] aire: 10 m (%.3f %.3f %.3f), 200 m (%.3f %.3f %.3f); occl sin muro %.2f; run_direct %d us" % [near[4], near[5], near[6], far[4], far[5], far[6], near[0], int(_sim("last_run_usec"))])
	a.gt(near[0], 0.95, "sin muro no hay oclusion")
	a.lt(far[6], far[4], "a 200 m el aire absorbe mas la banda alta que la baja")
	a.lt(far[6], near[6], "y mas que a 10 m")
	_sim("release_source", h)
	_sim("shutdown")
	tree.root.remove_child(bake); bake.free()
	tree.root.remove_child(floor); floor.free()
	_scene("clear")
	return a
