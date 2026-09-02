extends SceneTree

## Coste del bucle de control por voz, con los dos backends. No es parte de la suite: es la
## medida que fija y revisa el techo de +10 % sobre los 3.9 us por voz de la Fase 6.
##
##     Godot --headless --path . -s tools/bench_control_loop.gd

const ManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const DefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var backends: Array = ["godot"]
	if BackendClass.native_available():
		backends.append("steam_audio")
	# Un reproductor 3D no emite sin oyente; la camara hace que la medida sea la del juego.
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	for backend in backends:
		ProjectSettings.set_setting(BackendClass.SETTING, backend)
		print("\n== backend %s ==" % backend)
		print("instancias | us por _process | us por voz")
		for count in [0, 50, 200, 500]:
			var manager = ManagerClass.new()
			manager.hdr_enabled = false
			root.add_child(manager)
			manager.set_max_physical_voices(64)
			var tone: AudioStreamWAV = load("res://addons/opendou/runtime/audio_synthesizer.gd").create_rain_ambient_loop(1.0)
			var def = DefClass.new(&"Bench", tone)
			def.is_looping = true
			def.stream_length = 1.0
			manager.register_event_definition(def)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in range(count):
				var inst = manager.post_event(def, null)
				if inst != null:
					inst.set_position(Vector3(rng.randf_range(-60, 60), 1.5, rng.randf_range(-60, 60)))
			for i in range(10):
				await process_frame
			# Llamadas DIRECTAS a _process, cronometradas: esperar frames mide el ritmo del bucle
			# principal (~6.9 ms constantes en headless), no el coste del manager.
			var t0: int = Time.get_ticks_usec()
			for i in range(120):
				manager._process(1.0 / 60.0)
			var per_call: float = float(Time.get_ticks_usec() - t0) / 120.0
			print("%10d | %16.1f | %10.2f" % [count, per_call, per_call / maxf(float(count), 1.0)])
			manager.stop_all()
			root.remove_child(manager)
			manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, "auto")
	quit(0)
