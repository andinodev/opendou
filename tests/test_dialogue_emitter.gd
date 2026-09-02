class_name TestDialogueEmitter
extends RefCounted

## Fase 11: una linea con subtitulo, boca (envolvente del WAV), visemas autorados y ducking.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const AudioMarkerClass = preload("res://addons/opendou/resources/audio_marker.gd")
const TableClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_table.gd")
const EmitterScript = preload("res://addons/opendou/nodes/opendou_dialogue_emitter_3d.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

## Tono de 1 s: fuerte la primera mitad, silencio la segunda.
static func _line_wav() -> AudioStreamWAV:
	var rate: int = int(AudioServer.get_mix_rate())
	var bytes := PackedByteArray()
	bytes.resize(rate * 2)
	for i in range(rate):
		var amp: float = 0.5 if i < rate / 2 else 0.0
		bytes.encode_s16(i * 2, int(sin(TAU * 220.0 * i / rate) * amp * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav

static func _wait(tree: SceneTree, ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await tree.process_frame

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("dialogue_emitter")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam := TestParityClass.make_listener_camera(tree)
	for b in ["Voice", "Music"]:
		if AudioServer.get_bus_index(b) < 0:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	var music_idx: int = AudioServer.get_bus_index("Music")
	var music_base: float = AudioServer.get_bus_volume_db(music_idx)
	var table = TableClass.new()
	table.add_entry(&"greet", "es", _line_wav())
	var em = EmitterScript.new()
	em.dialogue_table = table
	em.language = "es"
	em.subtitles = {&"greet": {"es": "Buenas, que le pasa al coche?"}}
	em.duck_bus = &"Music"
	em.duck_db = -12.0
	em.duck_attack_sec = 0.02
	em.duck_release_sec = 0.05
	var mk = AudioMarkerClass.new()
	mk.name = &"viseme:AA"
	mk.time_sec = 0.2
	em.markers.append(mk)
	tree.root.add_child(em)
	em.set_event_manager(manager)
	em.global_position = Vector3(0, 0, -2)
	var subtitles: Array = []
	var visemes: Array = []
	var finished: Array = []
	em.subtitle_changed.connect(func(t): subtitles.append(t))
	em.viseme_changed.connect(func(v): visemes.append(v))
	em.line_finished.connect(func(k): finished.append(k))
	var inst = em.speak(&"greet")
	a.ok(inst != null, "speak devuelve la instancia")
	a.ok(em.is_speaking(), "y el emisor habla")
	a.eq(subtitles.size(), 1, "el subtitulo llega al empezar")
	if subtitles.size() == 1:
		a.eq(String(subtitles[0]), "Buenas, que le pasa al coche?", "con su texto")
	await _wait(tree, 250)
	var mouth_open: float = em.mouth_amplitude
	var music_ducked: float = AudioServer.get_bus_volume_db(music_idx)
	print("[OpenDou] dialogo: boca a 0.25 s %.2f, musica %.1f dB (base %.1f), visemas %s" % [mouth_open, music_ducked, music_base, str(visemes)])
	a.gt(mouth_open, 0.5, "a 0.25 s la boca esta abierta (%.2f)" % mouth_open)
	a.lt(music_ducked, music_base - 10.0, "la musica baja al menos 10 dB durante la linea (%.1f)" % music_ducked)
	a.eq(visemes.size(), 1, "el visema autorado a 0.2 s llego")
	a.eq(String(em.current_viseme), "AA", "y queda como visema actual")
	await _wait(tree, 500)
	var mouth_closed: float = em.mouth_amplitude
	a.lt(mouth_closed, 0.05, "a 0.75 s la boca esta cerrada (%.2f)" % mouth_closed)
	await _wait(tree, 700)
	a.ok(not em.is_speaking(), "la linea termino")
	a.eq(finished.size(), 1, "y lo dijo")
	a.approx(AudioServer.get_bus_volume_db(music_idx), music_base, "la musica vuelve", 0.5)
	tree.root.remove_child(em); em.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a
