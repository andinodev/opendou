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
			# OPENDOU_BENCH_VOLUMES=n registra n volumenes de entorno (Fase 10) con viento y
			# oclusion parcial activos: mide lo que cuesta el entorno en el bucle de control.
			var volumes: Array = []
			var n_vol: int = int(OS.get_environment("OPENDOU_BENCH_VOLUMES")) if OS.get_environment("OPENDOU_BENCH_VOLUMES") != "" else 0
			for v_i in range(n_vol):
				var env = load("res://addons/opendou/resources/acoustic_environment.gd").new()
				env.wind_enabled = true
				env.wind_velocity = Vector3(10, 0, 0)
				env.occluder_enabled = true
				var vol = load("res://addons/opendou/nodes/opendou_acoustic_volume_3d.gd").new()
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(10, 10, 10)
				cs.shape = box
				vol.add_child(cs)
				vol.environment = env
				root.add_child(vol)
				vol.global_position = Vector3(-40 + 12 * v_i, 0, 0) if v_i > 0 else Vector3.ZERO
				manager.register_acoustic_volume(vol)
				volumes.append(vol)
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
			for vol in volumes:
				root.remove_child(vol)
				vol.free()
	ProjectSettings.set_setting(BackendClass.SETTING, "auto")
	quit(0)
