class_name TestDynamicOccluder
extends RefCounted

## Fase 14: una hoja de puerta del grupo AcousticObstacleDynamic ocluye al simulador segun su
## angulo, sin rehacer el bake: cerrada tapa, a 45 grados a medias, abierta deja pasar.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

static func _sim(method: String, a1 = null, a2 = null, a3 = null, a4 = null, a5 = null, a6 = null, a7 = null) -> Variant:
	var args: Array = []
	for v in [a1, a2, a3, a4, a5, a6, a7]:
		if v != null:
			args.append(v)
	return ClassDB.class_call_static("OpenDouSimulator", method) if args.is_empty() else ClassDB.class_call_static("OpenDouSimulator", method, args[0]) if args.size() == 1 else ClassDB.class_call_static("OpenDouSimulator", method, args[0], args[1]) if args.size() == 2 else ClassDB.class_call_static("OpenDouSimulator", method, args[0], args[1], args[2]) if args.size() == 3 else ClassDB.class_call_static("OpenDouSimulator", method, args[0], args[1], args[2], args[3]) if args.size() == 4 else ClassDB.class_call_static("OpenDouSimulator", method, args[0], args[1], args[2], args[3], args[4]) if args.size() == 5 else ClassDB.class_call_static("OpenDouSimulator", method, args[0], args[1], args[2], args[3], args[4], args[5]) if args.size() == 6 else ClassDB.class_call_static("OpenDouSimulator", method, args[0], args[1], args[2], args[3], args[4], args[5], args[6])

static func _occlusion(h: int) -> float:
	_sim("run_direct")
	var d: PackedFloat32Array = _sim("get_direct", h)
	return d[0]

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("dynamic_occluder")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouSimulator"):
		print("[OpenDou] extension nativa AUSENTE: ocluidores dinamicos omitidos")
		return a
	var floor := TestSteamSceneClass.make_wall(tree, Vector3(0, -20, 0), &"Concrete")
	# Bisagra en x = -0.8: cerrada, la hoja (1.6 x 2.2) cubre x en [-1.6+0.8, 0.8] = [-0.8, 0.8]
	# sobre la linea fuente-oyente (x = 0); abierta (90 grados) queda a 0.8 m de la linea.
	var pivot := Node3D.new()
	tree.root.add_child(pivot)
	pivot.global_position = Vector3(-0.8, 0, -2)
	var leaf := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 2.2, 0.05)
	leaf.mesh = box
	leaf.position = Vector3(0.8, 1.1, 0)
	leaf.set_meta("acoustic_material", &"Wood")
	leaf.add_to_group("AcousticObstacleDynamic")
	pivot.add_child(leaf)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	a.eq(int(bake.stats.get("dynamic_count", 0)), 1, "la hoja es un ocluidor dinamico")
	a.eq(int(ClassDB.class_call_static("OpenDouAcousticScene", "instanced_count")), 1, "y una instancia en la escena nativa")
	_sim("configure", 8, 16, 2)
	var h: int = int(_sim("create_source"))
	_sim("set_listener", Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3.UP)
	_sim("set_source_inputs", h, Vector3(0, 1, -4), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5)
	var closed: float = _occlusion(h)
	# A 45 grados la hoja aun cubre toda la esfera de muestreo de la fuente (radio 0.5): ocluye
	# del todo. A 60 su borde cae en x = 0 a la altura de la fuente y parte la esfera por la mitad.
	pivot.rotation.y = deg_to_rad(60.0)
	for i in range(3):
		await tree.physics_frame
	var half: float = _occlusion(h)
	var updates_half: int = bake.dynamic_update_count
	pivot.rotation.y = deg_to_rad(90.0)
	for i in range(3):
		await tree.physics_frame
	var open: float = _occlusion(h)
	var updates_open: int = bake.dynamic_update_count
	for i in range(60):
		await tree.physics_frame
	var updates_still: int = bake.dynamic_update_count
	print("[OpenDou] puerta dinamica: oclusion cerrada %.2f, 60 grados %.2f, abierta %.2f; recomits %d/%d/%d" % [closed, half, open, updates_half, updates_open, updates_still])
	a.lt(closed, 0.3, "cerrada, la hoja tapa la fuente")
	a.ok(half > 0.25 and half < 0.8, "a 60 grados tapa a medias (%.2f)" % half)
	a.gt(open, 0.8, "abierta deja pasar")
	a.ok(updates_half >= 1 and updates_open > updates_half, "cada giro recomitea la escena")
	a.eq(updates_still, updates_open, "quieta 60 cuadros, no recomitea")
	_sim("release_source", h)
	_sim("shutdown")
	tree.root.remove_child(bake); bake.free()
	a.eq(int(ClassDB.class_call_static("OpenDouAcousticScene", "instanced_count")), 0, "al irse el bake no queda ninguna instancia")
	tree.root.remove_child(pivot); pivot.free()
	tree.root.remove_child(floor); floor.free()
	ClassDB.class_call_static("OpenDouAcousticScene", "clear")
	return a
