class_name TestAcousticVolume
extends RefCounted

## Fase 10: el entorno como volumen + recurso (medio, viento, oclusion parcial, descarte,
## superficie).

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EnvClass = preload("res://addons/opendou/resources/acoustic_environment.gd")
const VolumeScript = preload("res://addons/opendou/nodes/opendou_acoustic_volume_3d.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func make_box_volume(tree: SceneTree, center: Vector3, size: Vector3, env) -> Node:
	var v = VolumeScript.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	v.add_child(shape)
	v.environment = env
	tree.root.add_child(v)
	v.global_position = center
	return v

static func _settle(tree: SceneTree, sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await tree.process_frame

static func _rms_db_of(cap: Dictionary) -> float:
	return TestBinauralClass._rms_db(cap)

static func _max_applied_itd(manager) -> float:
	if manager.player_pool == null or not ClassDB.class_exists("OpenDouSpatialStream"):
		return 0.0
	var best: Array = [0.0]
	manager.player_pool.for_each_spatial_stream(func(s): best[0] = maxf(best[0], s.get_last_applied_itd_ms()))
	return best[0]

static func run_geometry(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_volume_geometry")
	var v = make_box_volume(tree, Vector3(10, 0, 0), Vector3(4, 4, 4), EnvClass.new())
	a.ok(v.contains_point(Vector3(10, 1, 1)), "contiene un punto dentro de la caja")
	a.ok(not v.contains_point(Vector3(13, 0, 0)), "no contiene uno fuera")
	a.approx(v.segment_length_inside(Vector3(0, 0, 0), Vector3(20, 0, 0)), 4.0, "un segmento que la cruza mide su lado", 0.001)
	a.approx(v.segment_length_inside(Vector3(0, 0, 0), Vector3(10, 0, 0)), 2.0, "hasta el centro, la mitad", 0.001)
	a.approx(v.segment_length_inside(Vector3(0, 10, 0), Vector3(20, 10, 0)), 0.0, "por fuera, nada", 0.001)
	v.rotate_y(PI / 4.0)
	a.ok(v.contains_point(Vector3(10, 0, 0)), "girada sigue conteniendo el centro")
	a.ok(not v.contains_point(Vector3(12, 0, 2)), "y ya no la esquina original, que quedo fuera")
	tree.root.remove_child(v); v.free()
	var s = VolumeScript.new()
	var sh := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	sh.shape = sphere
	s.add_child(sh)
	tree.root.add_child(s)
	a.approx(s.segment_length_inside(Vector3(-5, 0, 0), Vector3(5, 0, 0)), 4.0, "una esfera de radio 2 cruzada por el centro mide 4", 0.001)
	a.approx(s.segment_length_inside(Vector3(-5, 1, 0), Vector3(5, 1, 0)), 2.0 * sqrt(3.0), "a 1 m del centro, la cuerda", 0.001)
	tree.root.remove_child(s); s.free()
	return a

static func run_medium_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_volume_medium")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var backend: String = "steam_audio" if BackendClass.native_available() else "godot"
	var manager = TestParityClass.make_manager(tree, backend)
	var cam := TestParityClass.make_listener_camera(tree)
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var noise = TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate()))
	var def = AudioEventDefClass.new(&"MediumVoice", noise)
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(2, 0, 0))
	var air := await TestBinauralClass._capture(tree, probe)
	var rate: float = AudioServer.get_mix_rate()
	var air_high: float = TestBinauralClass._band_energy_stereo(air, rate, 4000.0, 8000.0)
	var itd_air: float = _max_applied_itd(manager)
	var env = EnvClass.new()
	env.medium_enabled = true
	env.speed_of_sound_mps = 1480.0
	env.medium_lowpass_hz = 800.0
	var water = make_box_volume(tree, Vector3.ZERO, Vector3(10, 10, 10), env)
	manager.register_acoustic_volume(water)
	for i in range(30):
		await tree.process_frame
	a.approx(manager.environment.speed_of_sound, 1480.0, "con el oyente dentro, el medio es agua", 0.01)
	a.approx(manager.voice_pool.speed_of_sound, 1480.0, "y el pool lo sabe", 0.01)
	a.approx(manager.spatial_acoustics.speed_of_sound, 1480.0, "y el doppler tambien", 0.01)
	var wet := await TestBinauralClass._capture(tree, probe)
	var wet_high: float = TestBinauralClass._band_energy_stereo(wet, rate, 4000.0, 8000.0)
	var drop: float = linear_to_db(maxf(wet_high, 1e-12)) - linear_to_db(maxf(air_high, 1e-12))
	var itd_wet: float = _max_applied_itd(manager)
	print("[OpenDou] medio agua (%s): banda 4-8 kHz %.1f dB; ITD aire %.3f ms, agua %.3f ms" % [backend, drop, itd_air, itd_wet])
	a.lt(drop, -12.0, "la banda alta cae al menos 12 dB bajo el agua")
	if backend == "steam_audio":
		a.lt(itd_wet / maxf(itd_air, 1e-6), 0.25, "el ITD cae a menos de un cuarto")
	water.global_position = Vector3(100, 0, 0)
	for i in range(30):
		await tree.process_frame
	a.approx(manager.environment.speed_of_sound, 343.0, "al salir, aire", 0.01)
	var back := await TestBinauralClass._capture(tree, probe)
	var back_high: float = TestBinauralClass._band_energy_stereo(back, rate, 4000.0, 8000.0)
	a.approx(linear_to_db(maxf(back_high, 1e-12)) - linear_to_db(maxf(air_high, 1e-12)), 0.0, "y la banda alta vuelve", 1.5)
	inst.stop()
	manager.unregister_acoustic_volume(water)
	tree.root.remove_child(water); water.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a
