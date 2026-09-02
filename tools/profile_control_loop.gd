extends SceneTree

## Perfil por etapas del bucle de control con 200 voces estaticas, en los dos backends.
## Replica el orden de AudioEventManager._process llamando a cada etapa por separado y
## cronometrandola. No es parte de la suite; sirve para pagar la deuda de coste por voz.
##
##     Godot --headless --path . -s tools/profile_control_loop.gd

const ManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const DefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var backends: Array = ["godot"]
	if BackendClass.native_available():
		backends.append("steam_audio")
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	for backend in backends:
		ProjectSettings.set_setting(BackendClass.SETTING, backend)
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
		for i in range(200):
			var inst = manager.post_event(def, null)
			if inst != null:
				inst.set_position(Vector3(rng.randf_range(-60, 60), 1.5, rng.randf_range(-60, 60)))
		for i in range(10):
			await process_frame
		var delta: float = 1.0 / 60.0
		var w3d: World3D = root.find_world_3d()
		var acc: Dictionary = {}
		var order: Array = ["oyente+entorno", "syncs", "grafo salas", "oclusion", "parametros instancia", "hdr+meter+mix", "descarte", "robo de voces", "aplicar voces", "reflexiones"]
		for k in order:
			acc[k] = 0
		var reps: int = 120
		for r in range(reps):
			var t: int = Time.get_ticks_usec()
			manager._update_listener()
			manager._update_environment(delta)
			acc["oyente+entorno"] += Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			if manager.sync_manager:
				manager.sync_manager.process(delta)
			acc["syncs"] += Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			manager.room_path_dispatcher.process_pool(manager.voice_pool, manager.active_listener_position)
			acc["grafo salas"] += Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			manager.occlusion_scheduler.process(manager.active_instances, manager.active_listener_position, w3d, manager.acoustic_volumes)
			acc["oclusion"] += Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			var global_rtpcs = manager.sync_manager.global_rtpcs if manager.sync_manager else {}
			for inst in manager.active_instances:
				inst.interpolate_locals(delta)
				inst.update_parameters(delta, global_rtpcs)
				inst.refresh_playback_context(global_rtpcs, manager.sync_manager)
			acc["parametros instancia"] += Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			manager._update_hdr(delta)
			if manager.mix != null:
				manager.mix.apply(delta)
			acc["hdr+meter+mix"] += Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			acc["descarte"] += Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			manager.voice_pool.resolve_voice_stealing(manager.active_instances, manager.active_listener_position, delta)
			acc["robo de voces"] += Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			manager._apply_voices(delta)
			acc["aplicar voces"] += Time.get_ticks_usec() - t; t = Time.get_ticks_usec()
			manager._dispatch_reflections()
			acc["reflexiones"] += Time.get_ticks_usec() - t
		var t_all: int = Time.get_ticks_usec()
		for r in range(reps):
			manager._process(delta)
		var total: float = float(Time.get_ticks_usec() - t_all) / reps
		print("\n== backend %s: 200 voces, us por llamada (por voz) ==" % backend)
		var sum: float = 0.0
		for k in order:
			var v: float = float(acc[k]) / reps
			sum += v
			print("%-22s %8.1f  (%.3f)" % [k, v, v / 200.0])
		print("%-22s %8.1f" % ["suma de etapas", sum])
		print("%-22s %8.1f  (%.3f)" % ["_process completo", total, total / 200.0])
		manager.stop_all()
		root.remove_child(manager)
		manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, "auto")
	quit(0)
