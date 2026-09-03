class_name TestProbesBake
extends RefCounted

## Fase 14: sondas generadas sobre el bake, caminos precocinados, archivo .probes que se
## guarda y recarga con el mismo numero de sondas.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

## Dos habitaciones en L (12 x 6 m, 3 m de alto) sin portal: un tabique deja la esquina.
static func make_l_rooms(tree: SceneTree) -> Array:
	var bodies: Array = []
	var specs: Array = [
		[Vector3(0, -0.15, 0), Vector3(12, 0.3, 6)],
		[Vector3(0, 3.15, 0), Vector3(12, 0.3, 6)],
		[Vector3(-6.15, 1.5, 0), Vector3(0.3, 3, 6)],
		[Vector3(6.15, 1.5, 0), Vector3(0.3, 3, 6)],
		[Vector3(0, 1.5, -3.15), Vector3(12, 3, 0.3)],
		[Vector3(0, 1.5, 3.15), Vector3(12, 3, 0.3)],
		[Vector3(0, 1.5, -1.0), Vector3(0.3, 3, 4.0)],   # tabique: hueco en z de +1 a +3
	]
	for sp in specs:
		var body := StaticBody3D.new()
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = sp[1]
		mi.mesh = box
		mi.add_to_group("AcousticObstacle")
		mi.set_meta("acoustic_material", &"Concrete")
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sp[1]
		cs.shape = sh
		body.add_child(cs)
		tree.root.add_child(body)
		body.global_position = sp[0]
		bodies.append(body)
	return bodies

static func _scene(method: String, a1 = null) -> Variant:
	return ClassDB.class_call_static("OpenDouAcousticScene", method) if a1 == null else ClassDB.class_call_static("OpenDouAcousticScene", method, a1)

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("probes_bake")
	if not TestSteamSceneClass._native():
		print("[OpenDou] extension nativa AUSENTE: sondas omitidas")
		return a
	var bodies: Array = make_l_rooms(tree)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	bake.auto_load_probes = false
	bake.probe_spacing_m = 2.0
	bake.probe_height_m = 1.5
	bake.probes_path = "user://opendou_test_l.probes"
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	a.ok(bool(_scene("is_ready")), "la L es una escena nativa")
	print("[OpenDou] sondas: tri %d, reflexiones corriendo %s, mgr autoload %s" % [int(_scene("triangle_count")), str(ClassDB.class_call_static("OpenDouSimulator", "is_reflections_running")), str(tree.root.get_node_or_null("OpenDou"))])
	print("[OpenDou] sondas: bounds %s" % str(bake.get_baked_bounds()))
	var progress: Array = []
	bake.probe_bake_progress.connect(func(f): progress.append(f))
	var t0: int = Time.get_ticks_msec()
	var result: Dictionary = bake.bake_probes()
	var ms: int = Time.get_ticks_msec() - t0
	print("[OpenDou] sondas: %d generadas, %d bytes, %d ms, progreso %s" % [int(result.get("probe_count", 0)), int(result.get("bytes", 0)), ms, str(progress)])
	a.ok(int(result.get("probe_count", 0)) >= 8 and int(result.get("probe_count", 0)) <= 40, "a 2 m salen entre 8 y 40 sondas (%d)" % int(result.get("probe_count", 0)))
	a.gt(float(result.get("bytes", 0)), 0.0, "el archivo tiene datos")
	a.lt(float(ms), 5000.0, "el bake de caminos baja de 5 s")
	a.ok(FileAccess.file_exists(bake.probes_path), "el .probes existe")
	var n: int = int(result.get("probe_count", 0))
	_scene("clear_probes")
	a.ok(not bool(_scene("has_probes")), "sin sondas tras limpiar")
	a.ok(bake.load_probes(), "el .probes se recarga")
	a.eq(int(_scene("probe_count")), n, "con el mismo numero de sondas")
	_scene("clear_probes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bake.probes_path))
	tree.root.remove_child(bake); bake.free()
	for b in bodies:
		tree.root.remove_child(b); b.free()
	return a
