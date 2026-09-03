class_name TestSteamScene
extends RefCounted

## Fase 12: la geometria del bake se convierte en la escena de Steam Audio.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

static func _native() -> bool:
	return ClassDB.class_exists("OpenDouAcousticScene") and ClassDB.class_exists("OpenDouSpatialStream") and bool(ClassDB.class_call_static("OpenDouSpatialStream", "is_native_available"))

## Un muro de `material` de 4 x 3 x thickness en `pos`, en el grupo del bake.
static func make_wall(tree: SceneTree, pos: Vector3, material: StringName, thickness: float = 0.3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("surface_type", material)
	body.set_meta("acoustic_material", material)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 3, thickness)
	mi.mesh = box
	mi.add_to_group("AcousticObstacle")
	mi.set_meta("acoustic_material", material)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	body.add_child(cs)
	tree.root.add_child(body)
	body.global_position = pos
	return body

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("steam_scene")
	if not _native():
		print("[OpenDou] extension nativa AUSENTE: escena de Steam Audio omitida")
		return a
	var wall := make_wall(tree, Vector3(0, 1.5, -3), &"Glass")
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	bake.feed_steam_audio = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	a.eq(bake.get_baked_triangle_count(), 12, "una caja son 12 triangulos")
	a.ok(bake.export_to_native(), "la escena nativa se construye")
	a.ok(bool(ClassDB.class_call_static("OpenDouAcousticScene", "is_ready")), "y esta lista")
	a.eq(int(ClassDB.class_call_static("OpenDouAcousticScene", "triangle_count")), bake.get_baked_triangle_count(), "con el mismo numero de triangulos que el bake")
	a.eq(int(ClassDB.class_call_static("OpenDouAcousticScene", "material_count")), 1, "y un material")
	for i in range(100):
		bake.export_to_native()
	a.eq(int(ClassDB.class_call_static("OpenDouAcousticScene", "triangle_count")), 12, "reconstruir cien veces no acumula mallas")
	ClassDB.class_call_static("OpenDouAcousticScene", "clear")
	a.ok(not bool(ClassDB.class_call_static("OpenDouAcousticScene", "is_ready")), "clear la deja vacia")
	tree.root.remove_child(bake); bake.free()
	tree.root.remove_child(wall); wall.free()
	return a
