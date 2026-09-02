class_name TestAcousticVolume
extends RefCounted

## Fase 10: el entorno como volumen + recurso (medio, viento, oclusion parcial, descarte,
## superficie). Viento y oclusion se miden en el bus de sonda: Master lleva el compresor de la
## cadena GAME y aplasta las diferencias (un -12 dB en la voz sale como -4).

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



## Captura tras vaciar el bufer: si no, la primera medida arrastra el silencio anterior al
## arranque de la voz y sale varios dB por debajo (trampa de la Fase 10).
static func _cap(tree: SceneTree, probe) -> Dictionary:
	probe._capture.clear_buffer()
	return await TestBinauralClass._capture(tree, probe)

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
	var air := await _cap(tree, probe)
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
	var wet := await _cap(tree, probe)
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
	var back := await _cap(tree, probe)
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

static func run_wind_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_volume_wind")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam := TestParityClass.make_listener_camera(tree)
	TestParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(TestParityClass.BUS, 2.0)
	var noise = TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate()))
	var def = AudioEventDefClass.new(&"WindVoice", noise)
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = TestParityClass.BUS
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.max_distance = 500.0
	inst.set_position(Vector3(0, 0, -60))
	for i in range(20):
		await tree.process_frame
	var calm := await _cap(tree, probe)
	var env = EnvClass.new()
	env.wind_enabled = true
	env.wind_velocity = Vector3(0, 0, -15)   # sopla del oyente hacia el emisor: en contra del sonido
	env.wind_min_distance_m = 20.0
	var zone = make_box_volume(tree, Vector3.ZERO, Vector3(10, 10, 10), env)
	manager.register_acoustic_volume(zone)
	for i in range(20):
		await tree.process_frame
	var head := await _cap(tree, probe)
	env.wind_velocity = Vector3(0, 0, 15)    # a favor
	for i in range(20):
		await tree.process_frame
	var tail := await _cap(tree, probe)
	env.wind_velocity = Vector3.ZERO
	for i in range(20):
		await tree.process_frame
	var none := await _cap(tree, probe)
	var rate: float = AudioServer.get_mix_rate()
	var hi_head: float = linear_to_db(maxf(TestBinauralClass._band_energy_stereo(head, rate, 2000.0, 8000.0), 1e-12))
	var hi_tail: float = linear_to_db(maxf(TestBinauralClass._band_energy_stereo(tail, rate, 2000.0, 8000.0), 1e-12))
	print("[OpenDou] viento a 60 m: en contra %.1f dB, a favor %.1f dB, sin viento %.1f dB, sin volumen %.1f dB (RMS); banda 2-8 kHz en contra %.1f / a favor %.1f dB" % [
		_rms_db_of(head), _rms_db_of(tail), _rms_db_of(none), _rms_db_of(calm), hi_head, hi_tail])
	a.lt(_rms_db_of(head), _rms_db_of(tail) - 3.0, "viento en contra: al menos 3 dB menos que a favor")
	a.lt(hi_head, hi_tail - 3.0, "y la banda alta cae mas que el conjunto")
	a.approx(_rms_db_of(none), _rms_db_of(calm), "sin viento, igual que sin volumen", 0.5)
	a.approx(_rms_db_of(tail), _rms_db_of(calm), "a favor no se anade nada", 0.5)
	inst.stop()
	manager.unregister_acoustic_volume(zone)
	tree.root.remove_child(zone); zone.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a

static func run_occluder_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_volume_occluder")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam := TestParityClass.make_listener_camera(tree)
	TestParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(TestParityClass.BUS, 2.0)
	var tone = load("res://tests/test_emitter_physics.gd")._tone(1000.0, 1.0)
	var def = AudioEventDefClass.new(&"OccluderVoice", tone)
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = TestParityClass.BUS
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(0, 0, -8))
	await _settle(tree, 1.2)
	var clear_db: float = _rms_db_of(await _cap(tree, probe))
	var env = EnvClass.new()
	env.occluder_enabled = true
	env.occluder_db_per_m = 3.0
	env.occluder_cutoff_hz_per_m = 2000.0
	var hedge = make_box_volume(tree, Vector3(0, 0, -4), Vector3(6, 6, 4), env)   # 4 m de follaje en el camino
	manager.register_acoustic_volume(hedge)
	await _settle(tree, 1.2)
	var hedge4_db: float = _rms_db_of(await _cap(tree, probe))
	hedge.get_child(0).shape.size = Vector3(6, 6, 2)                                 # 2 m
	await _settle(tree, 1.2)
	var hedge2_db: float = _rms_db_of(await _cap(tree, probe))
	print("[OpenDou] oclusion parcial: sin volumen %.1f dB, 4 m %.1f dB, 2 m %.1f dB; rayos por cuadro %d" % [clear_db, hedge4_db, hedge2_db, manager.occlusion_scheduler.raycasts_this_frame])
	a.approx(hedge4_db - clear_db, -12.0, "4 m a 3 dB/m: -12 dB", 1.5)
	a.approx(hedge2_db - clear_db, -6.0, "2 m: -6 dB", 1.5)
	a.gt(float(manager.occlusion_scheduler.raycasts_this_frame), 0.0, "la oclusion parcial viaja en el rayo que ya se lanza")
	inst.stop()
	manager.unregister_acoustic_volume(hedge)
	tree.root.remove_child(hedge); hedge.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a
