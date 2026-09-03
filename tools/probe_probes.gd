extends SceneTree

## Sondeo: L de dos salas, sondas y bake de caminos paso a paso, para aislar un crash nativo.

const TestProbesBake = preload("res://tests/test_probes_bake.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

func _init() -> void:
	await process_frame
	var bodies: Array = TestProbesBake.make_l_rooms(self)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	bake.auto_load_probes = false
	root.add_child(bake)
	bake.bake_geometry(root)
	print("escena lista: ", ClassDB.class_call_static("OpenDouAcousticScene", "is_ready"), " tri ", ClassDB.class_call_static("OpenDouAcousticScene", "triangle_count"))
	var bounds: AABB = bake.get_baked_bounds()
	print("bounds ", bounds)
	var spacing: float = float(OS.get_cmdline_user_args()[2]) if OS.get_cmdline_user_args().size() > 2 else 2.0
	var n: int = int(ClassDB.class_call_static("OpenDouAcousticScene", "generate_probes", spacing, 1.5, bounds))
	print("sondas ", n)
	var args: Array = OS.get_cmdline_user_args()
	var threads: int = int(args[0]) if args.size() > 0 else 1
	var samples: int = int(args[1]) if args.size() > 1 else 1
	print("bake threads=%d samples=%d ..." % [threads, samples])
	var t0: int = Time.get_ticks_msec()
	var ok: bool = bool(ClassDB.class_call_static("OpenDouAcousticScene", "bake_paths", samples, 1.0, 0.1, 50.0, 100.0, threads))
	print("bake ok=%s en %d ms" % [str(ok), Time.get_ticks_msec() - t0])
	var saved: bool = bool(ClassDB.class_call_static("OpenDouAcousticScene", "save_probes", "user://probe_probes.probes"))
	print("guardado ", saved, " bytes ", FileAccess.get_file_as_bytes("user://probe_probes.probes").size())
	ClassDB.class_call_static("OpenDouAcousticScene", "clear_probes")
	root.remove_child(bake); bake.free()
	for b in bodies:
		root.remove_child(b); b.free()
	quit()
