extends SceneTree

## Sondeo: una hoja (malla local) como instancia, movida solo con update_instanced_transform.

const TestSteamScene = preload("res://tests/test_steam_scene.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

func _occ(h: int) -> float:
	ClassDB.class_call_static("OpenDouSimulator", "run_direct")
	var d: PackedFloat32Array = ClassDB.class_call_static("OpenDouSimulator", "get_direct", h)
	return d[0]

func _init() -> void:
	await process_frame
	var floor := TestSteamScene.make_wall(self, Vector3(0, -20, 0), &"Concrete")
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	root.add_child(bake)
	bake.bake_geometry(root)
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 2.2, 0.05)
	var faces: PackedVector3Array = box.get_faces()
	var verts := PackedVector3Array()
	var tris := PackedInt32Array()
	var idx := PackedInt32Array()
	for i in range(0, faces.size(), 3):
		for k in range(3):
			tris.append(verts.size())
			verts.append(faces[i + k])
		idx.append(0)
	var mats: Array = [PackedFloat32Array([0.11, 0.07, 0.06, 0.05, 0.07, 0.014, 0.005])]
	var S = "OpenDouAcousticScene"
	var id: int = int(ClassDB.class_call_static(S, "add_instanced", verts, tris, idx, mats, Transform3D(Basis.IDENTITY, Vector3(0, 1.1, -2))))
	ClassDB.class_call_static(S, "commit")
	print("instancia ", id, " instancias ", ClassDB.class_call_static(S, "instanced_count"), " escena lista ", ClassDB.class_call_static(S, "is_ready"))
	ClassDB.class_call_static("OpenDouSimulator", "configure", 8, 16, 2)
	var h: int = int(ClassDB.class_call_static("OpenDouSimulator", "create_source"))
	ClassDB.class_call_static("OpenDouSimulator", "set_listener", Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3.UP)
	ClassDB.class_call_static("OpenDouSimulator", "set_source_inputs", h, Vector3(0, 1, -4), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5)
	print("cerrada en la linea: occl %.2f" % _occ(h))
	ClassDB.class_call_static(S, "update_instanced_transform", id, Transform3D(Basis.IDENTITY, Vector3(10, 1.1, -2)))
	ClassDB.class_call_static(S, "commit")
	print("movida 10 m: occl %.2f" % _occ(h))
	ClassDB.class_call_static(S, "update_instanced_transform", id, Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(-0.8, 1.1, -2)))
	ClassDB.class_call_static(S, "commit")
	print("girada 90 en la bisagra: occl %.2f" % _occ(h))
	ClassDB.class_call_static(S, "remove_instanced", id)
	ClassDB.class_call_static(S, "commit")
	print("quitada: occl %.2f, instancias %d" % [_occ(h), int(ClassDB.class_call_static(S, "instanced_count"))])
	ClassDB.class_call_static("OpenDouSimulator", "shutdown")
	root.remove_child(bake); bake.free()
	root.remove_child(floor); floor.free()
	ClassDB.class_call_static(S, "clear")
	quit()
