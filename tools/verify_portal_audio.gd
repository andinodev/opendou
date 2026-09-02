extends SceneTree

## Verificacion AUDIBLE de que cerrar un portal hunde el sonido.
##
## No forma parte de la suite. Vive aparte por la observacion 40:
## OpenDouAudioProbe.teardown() borra su bus, AudioServer.remove_bus() desplaza los
## indices siguientes, y Godot resuelve el bus de una voz por INDICE al arrancar la
## reproduccion. Dentro de una suite que crea y borra buses constantemente, voces ajenas
## acaban vertiendo en el bus que estas midiendo: esta comparacion fallaba entre una y
## tres de cada cinco corridas con picos de 5 a 9 sobre una senal que no pasa de 0.12.
##
## Aislado es estable. Medido en la maquina de desarrollo:
##
##     portal abierto : 0.1196
##     portal cerrado : 0.0011      -> una caida de 108x
##
## Ejecutalo con:
##
##     Godot --headless --path . -s tools/verify_portal_audio.gd
##
## La suite afirma en su lugar los valores que llegan al mezclador -el corte, el origen
## aparente y quien gobierna cada voz-, que son deterministas.

const ProbeClass = preload("res://tests/support/audio_probe.gd")
const ManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const DefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const SynthClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const RoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const PortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var bus_name: StringName = &"PortalVerify"
	if AudioServer.get_bus_index(String(bus_name)) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, String(bus_name))
		AudioServer.set_bus_send(idx, "Master")
	var probe = ProbeClass.new()
	probe.attach_to_existing_bus(bus_name, 2.0)

	var manager = ManagerClass.new()
	manager.hdr_enabled = false
	root.add_child(manager)
	await process_frame

	var ac = manager.spatial_acoustics
	for spec in [{"n": &"RoomA", "c": Vector3(0, 2, 0), "s": Vector3(12, 5, 12)},
	             {"n": &"RoomB", "c": Vector3(14, 2, 0), "s": Vector3(12, 5, 12)}]:
		var room = RoomClass.new()
		room.room_name = spec["n"]
		room.set_bounds(AABB(spec["c"] - spec["s"] * 0.5, spec["s"]))
		ac.register_room(room)
	var portal = PortalClass.new(&"Gap", &"RoomA", &"RoomB", Vector3(7, 1.5, 0), 1.0)
	ac.register_portal(portal)

	# Un AudioStreamPlayer3D sin oyente activo no emite nada.
	var camera := Camera3D.new(); camera.position = Vector3(14, 1.6, 0)
	root.add_child(camera); camera.make_current()
	var listener := AudioListener3D.new(); listener.position = Vector3(14, 1.6, 0)
	root.add_child(listener); listener.make_current()
	await process_frame

	# Tono AGUDO: el corte del portal cerrado baja a 200 Hz, y con un zumbido grave
	# filtrarlo no quitaria casi energia.
	var tone := SynthClass.create_tone(3000.0, 2.0, 0.9, false)
	# create_tone no pone loop_mode, y un evento con is_looping = true cuyo WAV no loopea
	# muere tras una pasada. Observacion 37.
	tone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	tone.loop_begin = 0
	tone.loop_end = tone.data.size() / 2
	var def = DefClass.new(&"PortalTone", tone)
	def.is_looping = true
	def.stream_length = 2.0
	def.base_volume_db = -12.0
	def.target_bus = bus_name
	manager.register_event_definition(def)

	var instance = manager.post_event(&"PortalTone", null)
	instance.set_position(Vector3(-3, 1.5, 0))
	instance.max_distance = 200.0
	instance.occlusion_smoothing_speed = 60.0
	instance.apparent_smoothing_speed = 60.0
	for i in range(60):
		await process_frame
		probe.drain()

	var results: Array = []
	for factor in [1.0, 0.0]:
		portal.open_factor = factor
		for i in range(120):
			await process_frame
			probe.drain()
		var peak: float = 0.0
		for i in range(40):
			await process_frame
			peak = maxf(peak, probe.drain_peak())
		results.append(peak)
		print("portal %s | gobernada=%s | corte=%8.1f Hz | atenuacion=%6.2f dB | aparente.x=%5.1f | PICO=%.4f" % [
			"abierto" if factor > 0.5 else "cerrado ", str(instance.room_path_active),
			instance.current_spatial_lpf, instance.occlusion_attenuation_db,
			instance.current_apparent_position.x, peak])

	var ratio: float = results[1] / maxf(results[0], 0.000001)
	print("")
	print("caida al cerrar: %.1fx  (%.1f %% del original)" % [1.0 / maxf(ratio, 0.000001), ratio * 100.0])
	if ratio < 0.5:
		print("RESULTADO: OK — cerrar el portal hunde el sonido a la mitad o menos.")
	else:
		print("RESULTADO: FALLO — cerrar el portal no hundio el sonido.")

	manager.stop_all()
	probe.teardown()
	listener.clear_current(); camera.clear_current()
	quit()
