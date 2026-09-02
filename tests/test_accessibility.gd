class_name TestAccessibility
extends RefCounted

## Fase 10: mono, modo noche e indicador de sonidos. Mono y modo noche se miden en Master a
## proposito: ahi viven.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const SettingsClass = preload("res://addons/opendou/runtime/spatial/spatial_settings.gd")
const ApplierClass = preload("res://addons/opendou/runtime/accessibility_applier.gd")
const InstallerClass = preload("res://addons/opendou/runtime/mix_chain_installer.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func run_settings() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("accessibility_settings")
	var path := "user://opendou_audio_access_test.cfg"
	var s = SettingsClass.new()
	a.eq(s.mono, false, "mono apagado por defecto")
	a.eq(s.night_mode, false, "modo noche apagado por defecto")
	var n: Array[int] = [0]
	s.changed.connect(func(): n[0] += 1)
	s.set_mono(true)
	s.set_night_mode(true)
	a.eq(n[0], 2, "cada ajuste emite changed")
	s.save_to_disk(path)
	var s2 = SettingsClass.new()
	s2.load_from_disk(path)
	a.ok(s2.mono and s2.night_mode, "los dos se recargan")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return a

static func _ild_on_master(tree: SceneTree) -> float:
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var cap := await TestBinauralClass._capture(tree, probe)
	probe.teardown()
	return TestBinauralClass._ild_db(cap.left, cap.right)

static func run_mono_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("accessibility_mono")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var backend: String = "steam_audio" if BackendClass.native_available() else "godot"
	var manager = TestParityClass.make_manager(tree, backend)
	var cam := TestParityClass.make_listener_camera(tree)
	var def = AudioEventDefClass.new(&"MonoVoice", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(2, 0, 0))
	for i in range(10):
		await tree.process_frame
	# La sonda se engancha DESPUES de cada cambio: un efecto anadido tras la captura no se ve.
	var ild_stereo: float = await _ild_on_master(tree)
	manager.spatial_settings.set_mono(true)
	a.ok(ApplierClass.is_mono_installed(), "mono instala su efecto en Master")
	var ild_mono: float = await _ild_on_master(tree)
	manager.spatial_settings.set_mono(false)
	a.ok(not ApplierClass.is_mono_installed(), "apagado, lo quita")
	var ild_back: float = await _ild_on_master(tree)
	print("[OpenDou] mono (%s): ILD estereo %.1f dB, mono %.2f dB, de vuelta %.1f dB" % [backend, ild_stereo, ild_mono, ild_back])
	a.gt(ild_stereo, 3.0, "una fuente a la derecha tiene ILD")
	a.lt(absf(ild_mono), 0.5, "con mono, ILD cero")
	a.gt(ild_back, 3.0, "sin mono, vuelve")
	inst.stop()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a

static func _peak_db_of_tone(tree: SceneTree, probe, level_db: float) -> float:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://tests/test_emitter_physics.gd")._tone(1000.0, 2.0)
	player.volume_db = level_db
	player.bus = "Master"
	tree.root.add_child(player)
	player.play()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 400:
		await tree.process_frame
		probe.drain()
	var peak: float = await probe.measure_peak_db_over_frames(tree, 30)
	player.stop()
	tree.root.remove_child(player); player.free()
	await probe.await_silence(tree, 0.002, 30)
	return peak

static func run_night_mode_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("accessibility_night")
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	await tree.process_frame
	a.ok(InstallerClass.is_installed(), "la cadena GAME esta en Master")
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var loud_game: float = await _peak_db_of_tone(tree, probe, -6.0)
	var quiet_game: float = await _peak_db_of_tone(tree, probe, -30.0)
	manager.spatial_settings.set_night_mode(true)
	var loud_night: float = await _peak_db_of_tone(tree, probe, -6.0)
	var quiet_night: float = await _peak_db_of_tone(tree, probe, -30.0)
	manager.spatial_settings.set_night_mode(false)
	var range_game: float = loud_game - quiet_game
	var range_night: float = loud_night - quiet_night
	print("[OpenDou] modo noche: rango GAME %.1f dB (%.1f / %.1f), NIGHT %.1f dB (%.1f / %.1f)" % [range_game, loud_game, quiet_game, range_night, loud_night, quiet_night])
	a.lt(range_night, range_game - 6.0, "el rango pico-valle baja al menos 6 dB")
	a.gt(quiet_night, quiet_game + 2.0, "y lo bajo sube")
	probe.teardown()
	tree.root.remove_child(manager); manager.free()
	return a

static func run_indicator_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("accessibility_indicator")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam := TestParityClass.make_listener_camera(tree)
	var def = AudioEventDefClass.new(&"Campana", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(5, 0, 0))
	var indicator = load("res://addons/opendou/nodes/opendou_sound_indicator.gd").new()
	indicator.poll_interval = 0.01
	indicator.set_manager(manager)   # en la suite existe el autoload /root/OpenDou, vacio
	tree.root.add_child(indicator)
	for i in range(10):
		await tree.process_frame
	var items: Array = indicator.get_indicators()
	a.ok(items.size() >= 1, "hay un indicador")
	if items.size() >= 1:
		a.eq(String(items[0].event_name), "Campana", "con el nombre del evento")
		a.approx(items[0].angle_rad, PI / 2.0, "a la derecha del oyente (+pi/2)", 0.2)
	inst.stop()
	tree.root.remove_child(indicator); indicator.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a
