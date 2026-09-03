extends SceneTree

## Sondeo: reproduce el estado de la suite antes del bake de caminos (simulador configurado,
## hilo de reflexiones que corrio, efecto de convolucion en un bus del pool) y hornea 6 veces.

const TestProbesBake = preload("res://tests/test_probes_bake.gd")
const TestConv = preload("res://tests/test_convolution_reverb.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

func _init() -> void:
	await process_frame
	var heavy: bool = OS.get_cmdline_user_args().size() > 0 and OS.get_cmdline_user_args()[0] == "heavy"
	if heavy:
		print("preparando: sala de convolucion y manager...")
		var r: Dictionary = await TestConv._measure(self, "steam_audio", &"Concrete", 1.0)
		print("convolucion previa: ", r)
	for k in range(6):
		var bodies: Array = TestProbesBake.make_l_rooms(self)
		var bake = BakeScript.new()
		bake.auto_bake_on_ready = false
		bake.auto_load_probes = false
		bake.probes_path = "user://probe_probes_suite.probes"
		root.add_child(bake)
		bake.bake_geometry(root)
		var res: Dictionary = bake.bake_probes()
		print("ronda %d: sim %s refl %s -> %s" % [k, str(ClassDB.class_call_static("OpenDouSimulator", "is_ready")), str(ClassDB.class_call_static("OpenDouSimulator", "is_reflections_running")), str(res)])
		ClassDB.class_call_static("OpenDouAcousticScene", "clear_probes")
		root.remove_child(bake); bake.free()
		for b in bodies:
			root.remove_child(b); b.free()
		await process_frame
	quit()
