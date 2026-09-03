class_name TestReflectionsThread
extends RefCounted

## Fase 13: la IR de la sala del oyente se traza en un hilo y sus RT60 dependen del material.
## Contraste robusto: hormigon (absorbe poco) frente a follaje (absorbe mucho). Metal y madera
## comparten las bandas media y alta en la tabla: no sirven para distinguir.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

## Caja cerrada de 6 x 3 x 6 con seis paredes del material.
static func make_box_room(tree: SceneTree, material: StringName) -> Array:
	var walls: Array = []
	var specs: Array = [[Vector3(0, -0.15, 0), Vector3(6, 0.3, 6)], [Vector3(0, 3.15, 0), Vector3(6, 0.3, 6)], [Vector3(-3.15, 1.5, 0), Vector3(0.3, 3, 6)], [Vector3(3.15, 1.5, 0), Vector3(0.3, 3, 6)], [Vector3(0, 1.5, -3.15), Vector3(6, 3, 0.3)], [Vector3(0, 1.5, 3.15), Vector3(6, 3, 0.3)]]
	for sp in specs:
		var body := StaticBody3D.new()
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = sp[1]
		mi.mesh = box
		mi.add_to_group("AcousticObstacle")
		mi.set_meta("acoustic_material", material)
		body.add_child(mi)
		tree.root.add_child(body)
		body.global_position = sp[0]
		walls.append(body)
	return walls

static func _sim(method: String, a1 = null, a2 = null, a3 = null, a4 = null, a5 = null, a6 = null) -> Variant:
	if a1 == null:
		return ClassDB.class_call_static("OpenDouSimulator", method)
	if a2 == null:
		return ClassDB.class_call_static("OpenDouSimulator", method, a1)
	if a3 == null:
		return ClassDB.class_call_static("OpenDouSimulator", method, a1, a2)
	if a4 == null:
		return ClassDB.class_call_static("OpenDouSimulator", method, a1, a2, a3)
	return ClassDB.class_call_static("OpenDouSimulator", method, a1, a2, a3, a4, a5, a6)

static func rt60_of(tree: SceneTree, material: StringName) -> Vector3:
	var walls: Array = make_box_room(tree, material)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	_sim("configure", 8, 16, 2, true, 2.0, 4096)
	var h: int = int(_sim("create_listener_source"))
	_sim("set_listener", Vector3(0, 1.5, 0), Vector3(0, 0, -1), Vector3.UP)
	_sim("set_listener_source_position", h, Vector3(0, 1.5, 0))
	_sim("start_reflections", 10.0)
	var gen0: int = int(_sim("reflections_generation", h))
	var t0: int = Time.get_ticks_msec()
	while int(_sim("reflections_generation", h)) == gen0 and Time.get_ticks_msec() - t0 < 4000:
		await tree.process_frame
	var ms: int = Time.get_ticks_msec() - t0
	var rt: Vector3 = _sim("get_reverb_times", h)
	_sim("stop_reflections")
	_sim("release_source", h)
	_sim("shutdown")
	tree.root.remove_child(bake); bake.free()
	for w in walls:
		tree.root.remove_child(w); w.free()
	ClassDB.class_call_static("OpenDouAcousticScene", "clear")
	print("[OpenDou] RT60 trazado en caja de %s: %.2f / %.2f / %.2f s (primer resultado a los %d ms)" % [material, rt.x, rt.y, rt.z, ms])
	return rt

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("reflections_thread")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouSimulator"):
		print("[OpenDou] extension nativa AUSENTE: reflexiones omitidas")
		return a
	var concrete: Vector3 = await rt60_of(tree, &"Concrete")
	var foliage: Vector3 = await rt60_of(tree, &"Foliage")
	a.gt(concrete.y, 0.05, "la caja de hormigon tiene RT60 (llego un resultado del hilo)")
	a.gt(concrete.y, foliage.y * 1.5, "y es al menos un 50 %% mas largo que la de follaje (%.2f frente a %.2f)" % [concrete.y, foliage.y])
	a.ok(not bool(_sim("is_reflections_running")), "el hilo se detuvo")
	return a
