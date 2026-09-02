class_name TestWorldBus
extends RefCounted

## Fase 11: la mezcla de un bus como objeto del mundo. Un ruido que suena solo en `Radio`
## aparece en el bus del emisor con la ILD de su posicion; la salida directa esta callada.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const EmitterScript = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("world_bus")
	# El autoload, como las demos: el bus Radio lo gobierna su aplicador de mezcla (el
	# dialogo del taller lo nombra en una regla de ducking) y dos managers pelearian por el.
	var manager = tree.root.get_node_or_null("OpenDou")
	a.ok(manager != null, "el autoload OpenDou existe")
	var backend: String = "steam_audio" if manager.is_steam_audio_backend() else "godot"
	var cam := TestParityClass.make_listener_camera(tree)
	if AudioServer.get_bus_index("Radio") < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Radio")
		AudioServer.set_bus_send(idx, "Master")
	TestParityClass.ensure_bus()
	var radio_idx: int = AudioServer.get_bus_index("Radio")
	AudioServer.set_bus_volume_db(radio_idx, 0.0)
	# El ruido vive solo en Radio.
	var radio := AudioStreamPlayer.new()
	radio.stream = TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate()))
	radio.bus = "Radio"
	radio.volume_db = -6.0
	tree.root.add_child(radio)
	radio.play()
	var speaker = EmitterScript.new()
	speaker.source = EmitterScript.Source.BUS_CAPTURE
	speaker.capture_bus = &"Radio"
	speaker.bus_category = String(TestParityClass.BUS)   # medir sin el compresor de Master
	speaker.cull_distance = 100.0
	tree.root.add_child(speaker)
	speaker.set_event_manager(manager)
	speaker.global_position = Vector3(2, 0, 0)
	speaker.play_event()
	a.ok(speaker.active_instance != null, "el altavoz tiene voz")
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(TestParityClass.BUS, 2.0)
	for i in range(40):
		await tree.process_frame
		probe.drain()
	var right := await TestBinauralClass._capture(tree, probe)
	var rms_right: float = TestBinauralClass._rms_db(right)
	var ild_right: float = TestBinauralClass._ild_db(right.left, right.right)
	speaker.global_position = Vector3(-2, 0, 0)
	for i in range(30):
		await tree.process_frame
		probe.drain()
	var left := await TestBinauralClass._capture(tree, probe)
	var ild_left: float = TestBinauralClass._ild_db(left.left, left.right)
	print("[OpenDou] altavoz de mundo (%s): RMS %.1f dBFS, ILD derecha %.1f dB, izquierda %.1f dB; bus Radio a %.0f dB" % [backend, rms_right, ild_right, ild_left, AudioServer.get_bus_volume_db(radio_idx)])
	a.gt(rms_right, -30.0, "lo que suena en Radio llega al bus del emisor")
	a.gt(ild_right, 3.0, "a la derecha, ILD positiva")
	a.lt(ild_left, -3.0, "a la izquierda, negativa")
	a.approx(AudioServer.get_bus_volume_db(radio_idx), -80.0, "la salida directa del bus Radio esta callada", 0.1)
	speaker.stop_event()
	await tree.process_frame
	a.approx(AudioServer.get_bus_volume_db(radio_idx), 0.0, "al parar, el bus Radio recupera su volumen", 0.1)
	radio.stop()
	probe.teardown()
	tree.root.remove_child(radio); radio.free()
	tree.root.remove_child(speaker); speaker.free()
	tree.root.remove_child(cam); cam.free()
	manager.stop_all()
	return a
