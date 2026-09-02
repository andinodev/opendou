class_name TestAudioMarkers
extends RefCounted

## Fase 9: marcadores autorados en la definicion y leidos del chunk cue de un WAV; la
## instancia emite marker_reached(name) al cruzarlos con su reloj logico, tambien en bucle.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioMarkerClass = preload("res://addons/opendou/resources/audio_marker.gd")
const WavMarkersClass = preload("res://addons/opendou/runtime/wav_markers.gd")
const SynthClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

## WAV minimo de 16 bits con dos cues etiquetados, escrito por el test.
static func _write_wav_with_cues(path: String) -> void:
	var rate: int = 44100
	var frames: int = rate
	var pcm := PackedByteArray()
	pcm.resize(frames * 2)
	var fmt := StreamPeerBuffer.new()
	fmt.put_u16(1)
	fmt.put_u16(1)
	fmt.put_u32(rate)
	fmt.put_u32(rate * 2)
	fmt.put_u16(2)
	fmt.put_u16(16)
	var cue := StreamPeerBuffer.new()
	cue.put_u32(2)
	for entry in [[1, int(rate * 0.25)], [2, int(rate * 0.75)]]:
		cue.put_u32(entry[0])
		cue.put_u32(entry[1])
		cue.put_data("data".to_ascii_buffer())
		cue.put_u32(0)
		cue.put_u32(0)
		cue.put_u32(entry[1])
	var adtl := StreamPeerBuffer.new()
	adtl.put_data("adtl".to_ascii_buffer())
	for entry in [[1, "Golpe"], [2, "Eco"]]:
		var text: PackedByteArray = (entry[1] as String).to_ascii_buffer()
		text.append(0)
		if text.size() % 2 == 1:
			text.append(0)
		adtl.put_data("labl".to_ascii_buffer())
		adtl.put_u32(4 + text.size())
		adtl.put_u32(entry[0])
		adtl.put_data(text)
	var chunks := StreamPeerBuffer.new()
	for c in [["fmt ", fmt.data_array], ["cue ", cue.data_array], ["LIST", adtl.data_array], ["data", pcm]]:
		chunks.put_data((c[0] as String).to_ascii_buffer())
		chunks.put_u32((c[1] as PackedByteArray).size())
		chunks.put_data(c[1])
	var buf := StreamPeerBuffer.new()
	buf.put_data("RIFF".to_ascii_buffer())
	buf.put_u32(4 + chunks.data_array.size())
	buf.put_data("WAVE".to_ascii_buffer())
	buf.put_data(chunks.data_array)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(buf.data_array)
	f.close()

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("audio_markers")
	var path := "user://opendou_cues_test.wav"
	_write_wav_with_cues(path)
	var markers: Array = WavMarkersClass.read_cues(path)
	a.eq(markers.size(), 2, "el WAV generado tiene dos cues")
	if markers.size() == 2:
		a.eq(String(markers[0].name), "Golpe", "el primero se llama Golpe")
		a.approx(markers[0].time_sec, 0.25, "y esta a 0.25 s", 0.001)
		a.eq(String(markers[1].name), "Eco", "el segundo se llama Eco")
		a.approx(markers[1].time_sec, 0.75, "y esta a 0.75 s", 0.001)
	a.eq(WavMarkersClass.read_cues("user://no_existe.wav").size(), 0, "un archivo inexistente da una lista vacia")

	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var def = AudioEventDefClass.new(&"Marked", SynthClass.create_rain_ambient_loop(1.0))
	def.is_looping = true
	def.stream_length = 1.0
	var m := AudioMarkerClass.new()
	m.name = &"Medio"
	m.time_sec = 0.5
	def.markers.append(m)
	manager.register_event_definition(def)
	var hits: Array = []
	var t0: int = Time.get_ticks_msec()
	var inst = manager.post_event(def, null)
	inst.marker_reached.connect(func(n): hits.append([n, Time.get_ticks_msec() - t0]))
	while Time.get_ticks_msec() - t0 < 1700:
		await tree.process_frame
	a.eq(hits.size(), 2, "el marcador de 0.5 s suena dos veces en 1.7 s de bucle de 1 s")
	if hits.size() >= 1:
		a.eq(String(hits[0][0]), "Medio", "con su nombre")
		a.ok(hits[0][1] >= 430 and hits[0][1] <= 650, "la primera vez entre 0.43 y 0.65 s (medido %d ms)" % hits[0][1])
	if hits.size() >= 2:
		a.ok(hits[1][1] >= 1400 and hits[1][1] <= 1700, "la segunda tras envolver el bucle (medido %d ms)" % hits[1][1])
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return a
