extends SceneTree

const TestSteamScene = preload("res://tests/test_steam_scene.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

func _occ(h: int) -> float:
	ClassDB.class_call_static("OpenDouSimulator", "run_direct")
	var d: PackedFloat32Array = ClassDB.class_call_static("OpenDouSimulator", "get_direct", h)
	return d[0]

func _init() -> void:
	await process_frame
	var floor := TestSteamScene.make_wall(self, Vector3(0, -20, 0), &"Concrete")
	var pivot := Node3D.new()
	root.add_child(pivot)
	pivot.global_position = Vector3(-0.8, 0, -2)
	var leaf := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 2.2, 0.05)
	leaf.mesh = box
	leaf.position = Vector3(0.8, 1.1, 0)
	leaf.add_to_group("AcousticObstacleDynamic")
	pivot.add_child(leaf)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	root.add_child(bake)
	bake.bake_geometry(root)
	print("dinamicos ", bake._dynamic, " stats ", bake.stats)
	ClassDB.class_call_static("OpenDouSimulator", "configure", 8, 16, 2)
	var h: int = int(ClassDB.class_call_static("OpenDouSimulator", "create_source"))
	ClassDB.class_call_static("OpenDouSimulator", "set_listener", Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3.UP)
	ClassDB.class_call_static("OpenDouSimulator", "set_source_inputs", h, Vector3(0, 1, -4), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5)
	print("cerrada: occl %.2f  leaf %s" % [_occ(h), str(leaf.global_transform)])
	pivot.rotation.y = deg_to_rad(90.0)
	print("tras girar (sin fisica): leaf %s" % str(leaf.global_transform))
	for i in range(3):
		await physics_frame
	print("tras 3 physics_frame: occl %.2f, recomits %d, xform guardada %s" % [_occ(h), bake.dynamic_update_count, str(bake._dynamic[0].xform)])
	ClassDB.class_call_static("OpenDouAcousticScene", "update_instanced_transform", int(bake._dynamic[0].id), leaf.global_transform)
	ClassDB.class_call_static("OpenDouAcousticScene", "commit")
	print("actualizacion manual: occl %.2f" % _occ(h))
	await process_frame
	print("tras process_frame: occl %.2f" % _occ(h))
	ClassDB.class_call_static("OpenDouSimulator", "shutdown")
	root.remove_child(bake); bake.free()
	root.remove_child(pivot); pivot.free()
	root.remove_child(floor); floor.free()
	ClassDB.class_call_static("OpenDouAcousticScene", "clear")
	quit()
