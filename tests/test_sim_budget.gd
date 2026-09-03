class_name TestSimBudget
extends RefCounted

## Fase 12: coste de run_direct() con 64 fuentes sobre la escena de la quilla. El techo vive
## en tests/sim_budget.txt (minimo de cinco corridas x 2, como el presupuesto DSP).

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")

static func _budget() -> int:
	if not FileAccess.file_exists("res://tests/sim_budget.txt"):
		return -1
	for line in FileAccess.get_file_as_string("res://tests/sim_budget.txt").split("\n"):
		var t: String = line.strip_edges()
		if t.is_empty() or t.begins_with("#"):
			continue
		var parts: PackedStringArray = t.split(" ", false)
		if parts.size() == 2 and parts[0] == "run_direct_usec_64":
			return int(parts[1])
	return -1

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("sim_budget")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouSimulator"):
		print("[OpenDou] extension nativa AUSENTE: presupuesto de simulacion omitido")
		return a
	var manager = tree.root.get_node_or_null("OpenDou")
	a.ok(manager != null, "el autoload OpenDou existe")
	var packed: PackedScene = load("res://scenes/demos/keel/keel_demo.tscn")
	var demo = packed.instantiate()
	tree.root.add_child(demo)
	await tree.process_frame
	await tree.physics_frame
	a.ok(bool(ClassDB.class_call_static("OpenDouAcousticScene", "is_ready")), "el bake de la quilla alimento la escena nativa")
	var def = AudioEventDefClass.new(&"SimBudgetVoice", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var listener: Vector3 = manager.active_listener_position
	for i in range(64):
		var inst = manager.post_event(def, null)
		inst.max_distance = 200.0
		inst.set_position(listener + Vector3(rng.randf_range(-8, 8), rng.randf_range(0.5, 2.5), rng.randf_range(-8, 8)))
	for i in range(10):
		await tree.process_frame
	var samples: Array = []
	for i in range(5):
		await tree.process_frame
		samples.append(int(ClassDB.class_call_static("OpenDouSimulator", "last_run_usec")))
	samples.sort()
	var min_usec: int = samples[0]
	var sources: int = int(ClassDB.class_call_static("OpenDouSimulator", "source_count"))
	var budget: int = _budget()
	print("[OpenDou] simulacion directa: %d fuentes, run_direct minimo %d us (corridas %s), techo %d" % [sources, min_usec, str(samples), budget])
	a.gt(float(sources), 8.0, "las voces cercanas tienen fuente (%d)" % sources)
	if budget > 0:
		a.lt(float(min_usec), float(budget), "run_direct con %d fuentes baja del techo de %d us" % [sources, budget])
	manager.stop_all()
	# Como en test_demo_scenes: la camara Y el oyente del jugador quedaron current; sin
	# soltarlos el viewport los sigue referenciando y la escena entera se fuga.
	load("res://tests/test_demo_scenes.gd")._release_current(demo)
	tree.root.remove_child(demo)
	demo.free()
	# El hilo de audio suelta los playbacks parados en su siguiente mezcla: si el proceso
	# termina antes (este es el ultimo test), quedan como fugas. Se le da tiempo.
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 300:
		await tree.process_frame
	return a
