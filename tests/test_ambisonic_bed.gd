class_name TestAmbisonicBed
extends RefCounted

## Fase 13: una cama ambisonica rota con la cabeza del oyente. Una fuente codificada al frente
## no tiene ILD; girado el oyente 90 grados, la tiene, con el signo que toca. Sin extension, el
## nodo suena en mono (canal W).

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const AudioClass = preload("res://addons/opendou/resources/ambisonic_audio.gd")
const BedScript = preload("res://addons/opendou/nodes/opendou_ambisonic_bed_3d.gd")
const ListenerScript = preload("res://addons/opendou/nodes/opendou_listener_3d.gd")
const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func _noise_mono(seconds: float) -> PackedFloat32Array:
	var rate: int = int(AudioServer.get_mix_rate())
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var out := PackedFloat32Array()
	out.resize(int(rate * seconds))
	for i in range(out.size()):
		out[i] = rng.randf_range(-0.5, 0.5)
	return out

## WAV de 4 canales de 16 bits escrito por el test para el lector multicanal.
static func _write_quad_wav(path: String, chans: Array, rate: int) -> void:
	var n: int = chans[0].size()
	var pcm := PackedByteArray()
	pcm.resize(n * 4 * 2)
	for f in range(n):
		for c in range(4):
			pcm.encode_s16((f * 4 + c) * 2, int(clampf(chans[c][f], -1.0, 1.0) * 32767.0))
	var fmt := StreamPeerBuffer.new()
	fmt.put_u16(1); fmt.put_u16(4); fmt.put_u32(rate); fmt.put_u32(rate * 8); fmt.put_u16(8); fmt.put_u16(16)
	var buf := StreamPeerBuffer.new()
	buf.put_data("RIFF".to_ascii_buffer()); buf.put_u32(4 + 8 + 16 + 8 + pcm.size()); buf.put_data("WAVE".to_ascii_buffer())
	buf.put_data("fmt ".to_ascii_buffer()); buf.put_u32(16); buf.put_data(fmt.data_array)
	buf.put_data("data".to_ascii_buffer()); buf.put_u32(pcm.size()); buf.put_data(pcm)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(buf.data_array)
	f.close()

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("ambisonic_bed")
	var native: bool = ClassDB.class_exists("OpenDouAmbisonicStream") and bool(ClassDB.class_call_static("OpenDouSpatialStream", "is_native_available"))
	var rate: int = int(AudioServer.get_mix_rate())
	var mono: PackedFloat32Array = _noise_mono(1.0)
	# Lector multicanal: cuatro canales sinteticos, ida y vuelta.
	var path := "user://opendou_quad_test.wav"
	var synth: Array = [mono, mono.duplicate(), mono.duplicate(), mono.duplicate()]
	for i in range(mono.size()):
		synth[1][i] = mono[i] * 0.5
		synth[2][i] = -mono[i] * 0.25
		synth[3][i] = 0.0
	_write_quad_wav(path, synth, rate)
	var read: Dictionary = WavDecoderClass.read_multichannel(path)
	a.eq((read.channels as Array).size(), 4, "el lector multicanal devuelve cuatro canales")
	if (read.channels as Array).size() == 4:
		a.eq(int(read.mix_rate), rate, "con su frecuencia")
		a.approx(read.channels[1][100], mono[100] * 0.5, "y las muestras de cada canal", 0.001)
	var from_file = AudioClass.from_wav_file(path)
	a.ok(from_file != null and from_file.order == 1 and from_file.is_valid(), "el recurso se construye desde el WAV de cuatro canales")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if not native:
		print("[OpenDou] extension nativa AUSENTE: cama ambisonica solo en fallback mono")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "steam_audio" if native else "godot")
	var listener = ListenerScript.new()
	tree.root.add_child(listener)
	manager.register_listener(listener)
	TestParityClass.ensure_bus()
	var bed = BedScript.new()
	bed.autoplay_bed = false
	bed.bus = String(TestParityClass.BUS)
	bed.volume_db = -6.0
	var audio = AudioClass.encode_point(mono, Vector3(0, 0, -1), rate, 1) if native else from_file
	bed.audio = audio
	tree.root.add_child(bed)
	bed.set_event_manager(manager)
	manager.register_ambisonic_bed(bed)
	bed.rebuild_stream()
	bed.play()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(TestParityClass.BUS, 2.0)
	for i in range(20):
		await tree.process_frame
		probe.drain()
	if native:
		a.ok(bed.is_native(), "con extension la cama es el stream nativo")
		var front: Dictionary = await TestBinauralClass._capture(tree, probe)
		var ild_front: float = TestBinauralClass._ild_db(front.left, front.right)
		listener.use_external_orientation = true
		listener.set_external_orientation(Basis(Vector3.UP, PI / 2.0))   # gira a la izquierda: el frente queda a la derecha
		for i in range(10):
			await tree.process_frame
			probe.drain()
		var left_turn: Dictionary = await TestBinauralClass._capture(tree, probe)
		var ild_left_turn: float = TestBinauralClass._ild_db(left_turn.left, left_turn.right)
		listener.set_external_orientation(Basis(Vector3.UP, -PI / 2.0))
		for i in range(10):
			await tree.process_frame
			probe.drain()
		var right_turn: Dictionary = await TestBinauralClass._capture(tree, probe)
		var ild_right_turn: float = TestBinauralClass._ild_db(right_turn.left, right_turn.right)
		print("[OpenDou] cama ambisonica: ILD de frente %.1f dB, oyente girado a la izquierda %.1f dB, a la derecha %.1f dB" % [ild_front, ild_left_turn, ild_right_turn])
		a.lt(absf(ild_front), 1.5, "de frente, sin ILD")
		a.gt(ild_left_turn, 6.0, "girado a la izquierda, la fuente queda a la derecha (ILD positiva)")
		a.lt(ild_right_turn, -6.0, "girado a la derecha, a la izquierda (negativa)")
	else:
		a.ok(not bed.is_native(), "sin extension la cama no es nativa")
		var mono_cap: Dictionary = await TestBinauralClass._capture(tree, probe)
		a.gt(TestBinauralClass._rms_db(mono_cap), -40.0, "y suena el canal W en mono")
	bed.stop()
	probe.teardown()
	manager.unregister_ambisonic_bed(bed)
	tree.root.remove_child(bed); bed.free()
	manager.unregister_listener(listener)
	tree.root.remove_child(listener); listener.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a
