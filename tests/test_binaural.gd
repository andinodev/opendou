class_name TestBinaural
extends RefCounted

## Suite binaural de la Fase 7B: el stream nativo sobre Steam Audio, medido en el bus.
## Nacio como el spike 7A (puede una voz salir por Steam Audio, y hace algo el HRTF).
##
## Aserciones de audio REAL sobre el estereo capturado del bus de la voz:
##  - ITD: una fuente a la derecha llega antes al oido derecho (correlacion cruzada L/R). Lo
##    aplica OpenDou con Woodworth, porque la API C de Steam Audio no lo hace (spec 7B, S1).
##  - ILD: el oido lejano recibe menos nivel.
##  - Delante / detras: distinto centroide espectral, que el paneo por amplitud no puede dar.
##  - CONTROL: con el HRTF apagado, ITD = 0 e ILD = 0. Si estas no fallan al apagarlo, las
##    de arriba no afirman nada.
##
## Si la extension nativa no esta cargada, la suite se omite y lo dice: es el doble backend
## funcionando, no un fallo. Pero lo dice, para que nadie crea que se probo.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const ModularSynthEngineClass = preload("res://addons/opendou/runtime/synth/modular_synth_engine.gd")

const BUS: StringName = &"BinauralProbe"
const MAX_LAG: int = 60   # ~1.4 ms a 44.1 kHz; el ITD humano maximo ronda 0.7 ms

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("binaural")

	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite binaural omitida (backend GDScript activo)")
		return a

	var available: bool = ClassDB.class_call_static("OpenDouSpatialStream", "is_native_available") if ClassDB.class_has_method("OpenDouSpatialStream", "is_native_available") else false
	a.ok(available, "Steam Audio se inicializo dentro de Godot")
	if not available:
		return a
	var version: String = str(ClassDB.class_call_static("OpenDouSpatialStream", "get_steam_audio_version"))
	var frame_size: int = int(ClassDB.class_call_static("OpenDouSpatialStream", "get_frame_size"))
	var mix_rate: float = AudioServer.get_mix_rate()
	print("[OpenDou] Steam Audio %s | frameSize %d @ %.0f Hz = %.1f ms de latencia anadida" % [
		version, frame_size, mix_rate, 1000.0 * float(frame_size) / mix_rate])
	a.eq(frame_size, 512, "el frameSize del spike es 512")

	# El estimador de ITD se valida a si mismo con un retardo sintetico de 25 muestras: si
	# no lo recupera, ninguna medida de ITD de abajo significa nada.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var synth_l := PackedFloat32Array()
	var synth_r := PackedFloat32Array()
	var base := PackedFloat32Array()
	for i in range(4096):
		base.append(rng.randf_range(-1.0, 1.0))
	for i in range(4096):
		synth_r.append(base[i])
		synth_l.append(base[i - 25] if i >= 25 else 0.0)   # L va 25 muestras por detras de R
	a.eq(_itd_lag(synth_l, synth_r), 25, "el estimador recupera un retardo sintetico de 25 muestras")

	if AudioServer.get_bus_index(String(BUS)) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, String(BUS))
		AudioServer.set_bus_send(idx, "Master")
	var probe = OpenDouAudioProbeClass.new()
	a.ok(probe.attach_to_existing_bus(BUS, 2.0), "la sonda se engancha al bus binaural")

	# Ruido PERIODICO de exactamente PERIOD muestras: ancho de banda plano para el ITD por
	# correlacion (un tono daria retardos ambiguos), y ademas la magnitud espectral medida en
	# frecuencias alineadas al periodo NO depende de que trozo se capture. Con ruido blanco
	# continuo, la medida delante/detras oscilaba de 2 a 20 % entre corridas segun el segmento
	# capturado; con esto el control sin HRTF tiene que dar practicamente cero.
	var noise: AudioStreamWAV = _periodic_noise(int(mix_rate))

	var stream = ClassDB.instantiate("OpenDouSpatialStream")
	stream.source = noise
	stream.spatialize = true
	stream.spatial_blend = 1.0

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = String(BUS)
	player.volume_db = -6.0
	tree.root.add_child(player)
	player.play()
	for i in range(8):
		await tree.process_frame
		probe.drain()

	# ---- DERECHA: el oido izquierdo va con retraso y recibe menos.
	stream.direction = Vector3(1, 0, 0)
	var right := await _capture(tree, probe)
	a.gt(float(right.left.size()), 4096.0, "se capturo estereo suficiente")
	var lag_right: int = _itd_lag(right.left, right.right)
	var ild_right: float = _ild_db(right.left, right.right)
	var pd: Vector2 = stream.get_last_peak_delays()
	print("[OpenDou] derecha: lag medido=%d muestras (%.2f ms)  ILD=%.1f dB (R-L)  | peakDelays de Steam Audio: L=%.3f ms R=%.3f ms" % [
		lag_right, 1000.0 * lag_right / mix_rate, ild_right, pd.x * 1000.0, pd.y * 1000.0])
	# La Fase 7B aplica el ITD que Steam Audio no renderiza: Woodworth completo, 0.656 ms a
	# 90 grados = ~29 muestras. El spec preveia restar el residuo de peakDelays; medido, ese
	# residuo NO esta en la salida (el retardo medido coincidia con el aplicado en ambos
	# lados) y restarlo dejaba el ITD asimetrico: 0.52 ms a la derecha, 0.27 a la izquierda.
	var expected_lo: int = int(0.55e-3 * mix_rate)
	var expected_hi: int = int(0.75e-3 * mix_rate)
	a.ok(lag_right >= expected_lo and lag_right <= expected_hi,
		"ITD: con la fuente a la derecha, el oido izquierdo va %d-%d muestras por detras (medido %d)" % [expected_lo, expected_hi, lag_right])
	a.gt(pd.x, pd.y, "y Steam Audio sigue reportando el pico izquierdo mas tarde (residuo)")
	a.approx(stream.get_last_applied_itd_ms(), 1000.0 * lag_right / mix_rate, "el retardo aplicado coincide con el medido", 0.08)
	a.gt(ild_right, 3.0, "ILD: con la fuente a la derecha, el oido derecho recibe al menos 3 dB mas")

	# ---- IZQUIERDA: simetrico, y el signo se invierte.
	stream.direction = Vector3(-1, 0, 0)
	var left := await _capture(tree, probe)
	var lag_left: int = _itd_lag(left.left, left.right)
	var ild_left: float = _ild_db(left.left, left.right)
	var pd_left: Vector2 = stream.get_last_peak_delays()
	print("[OpenDou] izquierda: lag=%d muestras  ILD=%.1f dB (R-L) | peakDelays: L=%.3f ms R=%.3f ms" % [
		lag_left, ild_left, pd_left.x * 1000.0, pd_left.y * 1000.0])
	a.ok(lag_left <= -expected_lo and lag_left >= -expected_hi, "ITD: a la izquierda el signo se invierte (medido %d)" % lag_left)
	a.gt(pd_left.y, pd_left.x, "y los retardos de pico se invierten: el DERECHO llega mas tarde")
	a.lt(ild_left, -3.0, "ILD: a la izquierda el oido izquierdo recibe al menos 3 dB mas")

	# ---- DELANTE / DETRAS: el paneo por amplitud no puede distinguirlos; el HRTF si.
	stream.direction = Vector3(0, 0, -1)
	var front := await _capture(tree, probe)
	stream.direction = Vector3(0, 0, 1)
	var back := await _capture(tree, probe)
	var ratio_front: float = _pinna_band_ratio(front, mix_rate)
	var ratio_back: float = _pinna_band_ratio(back, mix_rate)
	var front_back_pct: float = 100.0 * absf(ratio_front - ratio_back) / maxf(ratio_front, 1e-9)
	# El mismo par de medidas con el HRTF APAGADO: la diferencia tiene que desaparecer. Sin
	# este control, un 2 % podria ser ruido de la captura y no el HRTF.
	stream.spatialize = false
	stream.direction = Vector3(0, 0, -1)
	var front_off := await _capture(tree, probe)
	stream.direction = Vector3(0, 0, 1)
	var back_off := await _capture(tree, probe)
	stream.spatialize = true
	var r_off_f: float = _pinna_band_ratio(front_off, mix_rate)
	var r_off_b: float = _pinna_band_ratio(back_off, mix_rate)
	var off_pct: float = 100.0 * absf(r_off_f - r_off_b) / maxf(r_off_f, 1e-9)
	print("[OpenDou] banda del pabellon (5-10 kHz / 1-4 kHz): delante=%.3f detras=%.3f (%.1f %% de diferencia) | HRTF apagado: %.1f %% | centroides %.0f / %.0f Hz" % [
		ratio_front, ratio_back, front_back_pct, off_pct,
		_spectral_centroid_stereo(front, mix_rate), _spectral_centroid_stereo(back, mix_rate)])
	a.gt(front_back_pct, off_pct * 2.0 + 5.0,
		"delante y detras difieren en la banda del pabellon con el HRTF, y esa diferencia se DESVANECE sin el")
	a.ok(absf(_itd_lag(front.left, front.right)) <= 3, "de frente no hay ITD")

	# ---- CONTROL: HRTF apagado. Si esto no falla, lo de arriba no afirma nada.
	stream.direction = Vector3(1, 0, 0)
	stream.spatialize = false
	var off := await _capture(tree, probe)
	var lag_off: int = _itd_lag(off.left, off.right)
	var ild_off: float = _ild_db(off.left, off.right)
	print("[OpenDou] control (HRTF apagado, fuente a la derecha): lag=%d  ILD=%.2f dB" % [lag_off, ild_off])
	a.ok(absf(lag_off) <= 2, "con el HRTF apagado no hay ITD aunque la fuente este a la derecha")
	a.lt(absf(ild_off), 1.0, "ni ILD")

	# spatial_blend = 0 con el HRTF encendido: tampoco.
	stream.spatialize = true
	stream.spatial_blend = 0.0
	var blend0 := await _capture(tree, probe)
	a.lt(absf(_ild_db(blend0.left, blend0.right)), 1.0, "spatial_blend = 0 tampoco produce ILD")


	# ---- LPF de oclusion: la banda alta cae con el corte a 500 Hz.
	stream.spatialize = true
	stream.spatial_blend = 1.0
	stream.direction = Vector3(0, 0, -1)
	stream.cutoff_hz = 20000.0
	var open_cap := await _capture(tree, probe)
	stream.cutoff_hz = 500.0
	var closed_cap := await _capture(tree, probe)
	stream.cutoff_hz = 20000.0
	var open_high: float = _band_energy_stereo(open_cap, mix_rate, 5000.0, 10000.0)
	var closed_high: float = _band_energy_stereo(closed_cap, mix_rate, 5000.0, 10000.0)
	var lpf_drop_db: float = 10.0 * log(maxf(closed_high, 1e-12) / maxf(open_high, 1e-12)) / log(10.0)
	print("[OpenDou] LPF de oclusion: banda 5-10 kHz cae %.1f dB con corte en 500 Hz" % lpf_drop_db)
	a.lt(lpf_drop_db, -20.0, "con cutoff_hz = 500 la banda 5-10 kHz cae mas de 20 dB")

	# ---- Shelf por distancia: -12 dB por encima de 5 kHz, y a 0 dB no hace nada.
	stream.shelf_cutoff_hz = 5000.0
	stream.shelf_db = -12.0
	var shelved := await _capture(tree, probe)
	stream.shelf_db = 0.0
	var flat := await _capture(tree, probe)
	var shelf_drop_db: float = 10.0 * log(maxf(_band_energy_stereo(shelved, mix_rate, 8000.0, 14000.0), 1e-12) / maxf(_band_energy_stereo(flat, mix_rate, 8000.0, 14000.0), 1e-12)) / log(10.0)
	var shelf_low_db: float = 10.0 * log(maxf(_band_energy_stereo(shelved, mix_rate, 500.0, 2000.0), 1e-12) / maxf(_band_energy_stereo(flat, mix_rate, 500.0, 2000.0), 1e-12)) / log(10.0)
	print("[OpenDou] shelf -12 dB @5 kHz: 8-14 kHz cae %.1f dB, 0.5-2 kHz cae %.1f dB" % [shelf_drop_db, shelf_low_db])
	# Semantica de Godot: su high-shelf usa la ganancia lineal donde el cookbook usa la raiz,
	# asi que -12 dB pedidos son ~-24 dB reales por encima del corte. Se replica a proposito.
	a.lt(shelf_drop_db, -16.0, "el shelf de -12 dB (semantica de Godot: el doble) baja la banda alta al menos 16 dB")
	a.gt(shelf_low_db, -3.0, "y deja la banda media casi intacta")

	# ---- Ganancia por distancia: 0.5 lineal son -6 dB en el RMS.
	stream.distance_gain = 1.0
	var full := await _capture(tree, probe)
	stream.distance_gain = 0.5
	var half := await _capture(tree, probe)
	stream.distance_gain = 1.0
	var gain_drop_db: float = _rms_db(half) - _rms_db(full)
	a.approx(gain_drop_db, -6.02, "distance_gain 0.5 baja el nivel 6 dB", 0.6)

	# ---- Altavoces: paneo de potencia constante. ILD si, ITD no, delante = detras.
	stream.output_mode = 1   # OUTPUT_SPEAKERS
	# A 45 grados y no a 90: con paneo de potencia constante, a 90 el canal lejano es
	# exactamente cero y no hay nada que correlacionar.
	stream.direction = Vector3(0.7071, 0, -0.7071)
	var spk_right := await _capture(tree, probe)
	var spk_ild: float = _ild_db(spk_right.left, spk_right.right)
	print("[OpenDou] altavoces a 45 grados: ILD=%.1f dB lag=%d" % [spk_ild, _itd_lag(spk_right.left, spk_right.right)])
	a.gt(spk_ild, 6.0, "altavoces: a 45 grados a la derecha, ILD > 6 dB")
	a.ok(absf(_itd_lag(spk_right.left, spk_right.right)) <= 2, "altavoces: sin ITD")
	stream.direction = Vector3(0, 0, -1)
	var spk_front := await _capture(tree, probe)
	stream.direction = Vector3(0, 0, 1)
	var spk_back := await _capture(tree, probe)
	var spk_fb_pct: float = 100.0 * absf(_pinna_band_ratio(spk_front, mix_rate) - _pinna_band_ratio(spk_back, mix_rate)) / maxf(_pinna_band_ratio(spk_front, mix_rate), 1e-9)
	a.lt(spk_fb_pct, 5.0, "altavoces: delante y detras suenan igual (sin HRTF)")
	a.lt(absf(_ild_db(spk_front.left, spk_front.right)), 1.0, "altavoces: de frente, centrado")
	stream.output_mode = 0

	# ---- Control del ITD: con la mezcla a 0 no hay retardo aunque la fuente este a la derecha.
	stream.direction = Vector3(1, 0, 0)
	stream.spatial_blend = 0.0
	var blend0_right := await _capture(tree, probe)
	a.ok(absf(_itd_lag(blend0_right.left, blend0_right.right)) <= 2, "spatial_blend = 0 tampoco produce ITD")
	stream.spatial_blend = 1.0

	# ---- HRTF conmutable en vivo: 16 voces sonando, se cambia y se vuelve. Sin cortes.
	var extra: Array[AudioStreamPlayer] = []
	for i in range(15):
		var s2 = ClassDB.instantiate("OpenDouSpatialStream")
		s2.source = noise
		s2.direction = Vector3(cos(i * 0.4), 0, sin(i * 0.4))
		var p2 := AudioStreamPlayer.new()
		p2.stream = s2
		p2.bus = String(BUS)
		p2.volume_db = -18.0
		tree.root.add_child(p2)
		p2.play()
		extra.append(p2)
	var gen_before: int = int(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_generation"))
	a.eq(str(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_name")), "default", "el HRTF activo es el incorporado")
	# Un SOFA inexistente NO cambia nada y devuelve false.
	a.eq(bool(ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_sofa", "user://no_existe.sofa")), false, "un SOFA inexistente se rechaza")
	a.eq(int(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_generation")), gen_before, "y la generacion no cambia")
	# Volver al incorporado (aunque ya lo sea) crea una generacion nueva: es el camino que
	# recorre un cambio de verdad, y hay que verlo funcionar con voces sonando.
	var silent_blocks: int = 0
	var inspected_samples: int = 0
	for round_i in range(3):
		a.ok(bool(ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_default")), "set_hrtf_default devuelve true")
		var settled: int = 0
		while settled < 4096:
			await tree.process_frame
			var avail: int = probe._capture.get_frames_available()
			if avail <= 0:
				continue
			var peak: float = 0.0
			for v in probe._capture.get_buffer(avail):
				peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
			settled += avail
			inspected_samples += avail
			if peak < 0.001:
				silent_blocks += 1
	a.gt(float(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_generation")), float(gen_before + 2), "cada cambio de HRTF sube la generacion")
	a.ok(inspected_samples >= 3 * 4096, "se inspecciono al menos 4096 muestras por cada uno de los tres cambios")
	a.eq(silent_blocks, 0, "ningun bloque quedo en silencio al cambiar el HRTF con 16 voces sonando")
	for p2 in extra:
		p2.stop()
		tree.root.remove_child(p2)
		p2.free()

	player.stop()
	tree.root.remove_child(player)
	player.free()
	probe.teardown()
	return a

const PERIOD: int = 1024

## WAV mono de 16 bits con PERIOD muestras de ruido sembrado, en bucle sin costura.
static func _periodic_noise(mix_rate: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var bytes := PackedByteArray()
	bytes.resize(PERIOD * 2)
	for i in range(PERIOD):
		bytes.encode_s16(i * 2, int(rng.randf_range(-0.5, 0.5) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = mix_rate
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = PERIOD
	return wav

## Una voz posteada por el manager con backend steam_audio sale por el stream nativo y se
## lateraliza: ILD con el signo de su lado. Es la primera asercion de la cadena completa
## (manager -> canal -> stream) y no del stream aislado.
static func run_pool_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("binaural_pool")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite binaural_pool omitida")
		return a
	var ParityClass = load("res://tests/test_backend_parity.gd")
	var BackendClass = load("res://addons/opendou/runtime/spatial/spatial_backend.gd")
	var previous: String = str(ProjectSettings.get_setting(BackendClass.SETTING, "auto"))
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	# El anfitrion del pool es un AudioStreamPlayer3D, y un reproductor 3D NO EMITE NADA sin
	# un oyente en el viewport (medido: 0.0000 sin camara, 0.91 con ella).
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var manager = ParityClass.make_manager(tree, "steam_audio")
	await tree.process_frame
	a.eq(manager.spatial_backend, &"steam_audio", "el manager quedo en steam_audio")

	var noise := _periodic_noise(int(AudioServer.get_mix_rate()))
	var def = AudioEventDefClass.new(&"PoolVoice", noise)
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = ParityClass.BUS
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)

	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(10, 0, 0))
	var right := await _capture(tree, probe)
	var ch = manager.voice_pool.get_channel(inst.assigned_channel_id)
	a.ok(ch != null and ch.get_player() is AudioStreamPlayer3D and ch.get_player().stream.get_class() == "OpenDouSpatialStream", "la voz salio por un anfitrion del pool con el stream nativo")
	a.approx(ch.get_player().panning_strength, 0.0, "y el anfitrion no panea")
	a.gt(_ild_db(right.left, right.right), 3.0, "a la derecha del oyente: ILD positivo")
	var lag_r: int = _itd_lag(right.left, right.right)
	a.gt(float(lag_r), 10.0, "y el oido izquierdo va por detras")
	inst.set_position(Vector3(-10, 0, 0))
	var left := await _capture(tree, probe)
	a.lt(_ild_db(left.left, left.right), -3.0, "a la izquierda: ILD negativo")
	# La distancia entra en el stream: a 40 m suena mas bajo que a 10 m.
	inst.set_position(Vector3(0, 0, -10))
	var near := await _capture(tree, probe)
	inst.set_position(Vector3(0, 0, -40))
	var far := await _capture(tree, probe)
	print("[OpenDou] pool binaural: ILD derecha %.1f dB lag %d | 10 m %.1f dB, 40 m %.1f dB" % [_ild_db(right.left, right.right), lag_r, _rms_db(near), _rms_db(far)])
	a.lt(_rms_db(far) - _rms_db(near), -9.0, "a 40 m el nivel cae al menos 9 dB (inversa: -12 dB)")

	inst.stop()
	await probe.await_silence(tree, 0.002, 30)
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous)
	return a

## Un OpenDouEventPlayer3D dentro de una sala, con dos portales en el muro: uno DETRAS del
## oyente y otro DELANTE. Se abre uno u otro y la voz de nodo tiene que sonar desde el que
## esta abierto (coloracion delante/detras distinta): es lo que el spike no podia hacer. Con
## godot el nodo suena el mismo y no se mueve: la limitacion conocida, afirmada para que
## quede escrita.
static func run_node_emitter_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("binaural_node_emitter")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite binaural_node_emitter omitida")
		return a
	var ParityClass = load("res://tests/test_backend_parity.gd")
	var BackendClass = load("res://addons/opendou/runtime/spatial/spatial_backend.gd")
	var AudioRoomClass = load("res://addons/opendou/runtime/spatial/audio_room.gd")
	var AudioPortalClass = load("res://addons/opendou/runtime/spatial/audio_portal.gd")
	var EmitterScript = load("res://addons/opendou/nodes/opendou_event_player_3d.gd")
	var previous: String = str(ProjectSettings.get_setting(BackendClass.SETTING, "auto"))
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var mix_rate: float = AudioServer.get_mix_rate()
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	cam.global_position = Vector3(-6, 1.5, 0)

	for backend in ["steam_audio", "godot"]:
		var manager = ParityClass.make_manager(tree, backend)
		await tree.process_frame
		# Oyente en Fuera (x < 0) en (-6, 1.5, 0) mirando a -Z; emisor en Dentro (x > 0). El
		# muro es x = 0: portal trasero en z = +6 (detras-derecha), delantero en z = -12.
		var ac = manager.spatial_acoustics
		var outside = AudioRoomClass.new()
		outside.room_name = &"Fuera"
		outside.set_bounds(AABB(Vector3(-40, -5, -40), Vector3(40, 10, 80)))
		ac.register_room(outside)
		var inside = AudioRoomClass.new()
		inside.room_name = &"Dentro"
		inside.set_bounds(AABB(Vector3(0, -5, -40), Vector3(40, 10, 80)))
		ac.register_room(inside)
		var back_portal = AudioPortalClass.new(&"Trasero", &"Fuera", &"Dentro", Vector3(0, 1.5, 6), 1.0)
		var front_portal = AudioPortalClass.new(&"Delantero", &"Fuera", &"Dentro", Vector3(0, 1.5, -12), 0.0)
		ac.register_portal(back_portal)
		ac.register_portal(front_portal)
		manager.set_listener_position(Vector3(-6, 1.5, 0))

		var noise := _periodic_noise(int(mix_rate))
		var def = AudioEventDefClass.new(&"NodeVoice", noise)
		def.is_looping = true
		def.stream_length = 1.0
		def.target_bus = ParityClass.BUS
		manager.register_event_definition(def)

		var emitter = EmitterScript.new()
		emitter.event_def = def
		emitter.bus = String(ParityClass.BUS)
		emitter.position = Vector3(6, 1.5, -3)
		tree.root.add_child(emitter)
		emitter.set_event_manager(manager)
		emitter.play_event()
		var inst = emitter.active_instance
		a.ok(inst != null, "%s: el emisor de nodo tiene instancia" % backend)
		if inst != null:
			inst.apparent_smoothing_speed = 200.0
		var cap_back := await _capture(tree, probe)
		a.ok(inst.room_path_active, "%s: la voz esta gobernada por el grafo de salas" % backend)
		a.approx(inst.target_apparent_position.z, 6.0, "%s: el origen aparente es el portal trasero" % backend, 0.05)
		var ch = manager.voice_pool.get_channel(inst.assigned_channel_id)

		# Se cierra el trasero y se abre el delantero: el digest cambia, la cache se invalida.
		back_portal.open_factor = 0.0
		front_portal.open_factor = 1.0
		var cap_front := await _capture(tree, probe)
		a.approx(inst.target_apparent_position.z, -12.0, "%s: ahora el origen aparente es el portal delantero" % backend, 0.05)
		var ratio_back: float = _pinna_band_ratio(cap_back, mix_rate)
		var ratio_front: float = _pinna_band_ratio(cap_front, mix_rate)
		var pct: float = 100.0 * absf(ratio_front - ratio_back) / maxf(ratio_back, 1e-9)
		print("[OpenDou] emisor de nodo (%s): ratio por el portal trasero %.3f | delantero %.3f (%.1f %%)" % [backend, ratio_back, ratio_front, pct])
		if backend == "steam_audio":
			a.ok(ch != null and ch.get_player() != emitter and ch.get_position_node() == emitter, "steam_audio: el nodo aporta posicion y la voz sale por el pool")
			a.ok(not emitter.playing, "steam_audio: el AudioStreamPlayer3D del nodo no suena por si mismo")
			a.gt(pct, 10.0, "steam_audio: la voz de nodo suena distinta desde el portal de detras que desde el de delante")
		else:
			a.ok(ch != null and ch.get_player() == emitter, "godot: el nodo sigue siendo la voz fisica")
			a.approx(emitter.global_position.z, -3.0, "godot: el nodo no se mueve al portal (limitacion conocida)", 0.001)
		emitter.stop_event()
		tree.root.remove_child(emitter)
		emitter.free()
		await probe.await_silence(tree, 0.002, 30)
		manager.stop_all()
		tree.root.remove_child(manager)
		manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous)
	return a

## Los ajustes del jugador llegan en vivo a los streams del pool.
static func run_settings_live_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("binaural_settings_live")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite binaural_settings_live omitida")
		return a
	var ParityClass = load("res://tests/test_backend_parity.gd")
	var BackendClass = load("res://addons/opendou/runtime/spatial/spatial_backend.gd")
	var PoolClass = load("res://addons/opendou/runtime/native_player_pool.gd")
	var previous: String = str(ProjectSettings.get_setting(BackendClass.SETTING, "auto"))
	var manager = ParityClass.make_manager(tree, "steam_audio")
	await tree.process_frame
	var kind: int = PoolClass.PlayerKind.BINAURAL_3D
	var p = manager.player_pool.acquire(kind)
	a.approx(p.stream.spatial_blend, 1.0, "un stream recien creado lleva la mezcla de los ajustes (1.0)")
	manager.spatial_settings.set_blend(0.4)
	a.approx(p.stream.spatial_blend, 0.4, "cambiar la mezcla llega al stream en vivo", 0.001)
	manager.spatial_settings.set_output("speakers")
	a.eq(p.stream.output_mode, 1, "cambiar la salida llega al stream en vivo")
	manager.spatial_settings.set_output("headphones")
	var p2 = manager.player_pool.acquire(kind)
	a.approx(p2.stream.spatial_blend, 0.4, "un stream creado DESPUES nace con los ajustes vigentes", 0.001)
	a.ok(manager.spatial_backend_label().begins_with("Steam Audio"), "la etiqueta del backend nombra a Steam Audio")
	manager.spatial_settings.set_blend(1.0)
	manager.player_pool.release(p)
	manager.player_pool.release(p2)
	tree.root.remove_child(manager)
	manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous)
	return a

## Guarda de coste del DSP nativo: benchmark_block(64) bajo el techo de tests/dsp_budget.txt.
static func run_budget_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("binaural_budget")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite binaural_budget omitida")
		return a
	await tree.process_frame
	var budget_text := FileAccess.get_file_as_string("res://tests/dsp_budget.txt")
	var budget: float = 27.0
	for line in budget_text.split("\n"):
		var t: String = line.strip_edges()
		if not t.begins_with("#") and t.is_valid_float():
			budget = float(t)
			break
	# Cinco medidas y el MINIMO: es una guarda gruesa contra regresiones al doble, no una
	# medida fina (ver tests/dsp_budget.txt). El minimo es lo menos sensible a la carga de
	# la maquina, que es lo que hace oscilar un cronometro de pared dentro de la suite.
	var samples: Array[float] = []
	for i in range(5):
		samples.append(float(ClassDB.class_call_static("OpenDouSpatialStream", "benchmark_block", 64)))
	samples.sort()
	var frame_size: int = int(ClassDB.class_call_static("OpenDouSpatialStream", "get_frame_size"))
	print("[OpenDou] DSP nativo: %.1f us por voz y bloque de %d (minimo de 5; techo %.0f) | desglose: HRTF bilineal %.1f, HRTF vecino %.1f, filtros+ITD %.1f, fuente %.1f" % [
		samples[0], frame_size, budget,
		float(ClassDB.class_call_static("OpenDouSpatialStream", "benchmark_block_mode", 64, 1)),
		float(ClassDB.class_call_static("OpenDouSpatialStream", "benchmark_block_mode", 64, 2)),
		float(ClassDB.class_call_static("OpenDouSpatialStream", "benchmark_block_mode", 64, 3)),
		float(ClassDB.class_call_static("OpenDouSpatialStream", "benchmark_block_mode", 64, 4))])
	a.gt(samples[0], 0.1, "benchmark_block mide algo")
	a.lt(samples[0], budget, "el DSP nativo por voz y bloque queda bajo el techo de tests/dsp_budget.txt")
	return a

## Muestras que se dejan pasar tras cambiar un parametro antes de medir: cubre la latencia
## del anillo (512) mas la del servidor de audio, con margen.
const SETTLE_SAMPLES: int = 6144
## Muestras minimas por captura: 8 periodos de la fuente periodica.
const CAPTURE_SAMPLES: int = 8192

## Captura al menos CAPTURE_SAMPLES muestras del bus y devuelve los dos canales por
## separado, tras asentar SETTLE_SAMPLES.
##
## Se cuenta en MUESTRAS y no en frames: en headless un frame dura ~2 ms, y asentar seis
## frames no cubria ni la latencia del anillo. Con frames, la captura "cerrada" del LPF
## arrastraba audio de antes del cambio y la caida medida oscilaba entre -17 y -44 dB.
static func _capture(tree: SceneTree, probe) -> Dictionary:
	var settled: int = 0
	var guard: int = 0
	while settled < SETTLE_SAMPLES and guard < 4000:
		await tree.process_frame
		settled += probe._capture.get_frames_available()
		probe.drain()
		guard += 1
	var l := PackedFloat32Array()
	var r := PackedFloat32Array()
	guard = 0
	while l.size() < CAPTURE_SAMPLES and guard < 4000:
		await tree.process_frame
		guard += 1
		var avail: int = probe._capture.get_frames_available()
		if avail <= 0:
			continue
		for v in probe._capture.get_buffer(avail):
			l.append(v.x)
			r.append(v.y)
	return {"left": l, "right": r}

## Retardo (en muestras) que maximiza la correlacion L[n] * R[n - k]. Positivo = L va por
## detras de R, que es lo que pasa con una fuente a la derecha.
static func _itd_lag(l: PackedFloat32Array, r: PackedFloat32Array) -> int:
	var n: int = mini(l.size(), r.size())
	if n < 2 * MAX_LAG + 64:
		return 0
	var best_lag: int = 0
	var best: float = -INF
	# Ventana central para que todos los lags tengan el mismo numero de muestras.
	var start: int = MAX_LAG
	var stop: int = n - MAX_LAG
	# Un canal MUDO (paneo duro a un lado) deja la correlacion en cero para todo retardo, y
	# el maximo seria el primer lag del barrido: sin senal en los dos oidos no hay ITD.
	var el: float = 0.0
	var er: float = 0.0
	for i in range(start, stop, 8):
		el += l[i] * l[i]
		er += r[i] * r[i]
	if el < 1e-9 or er < 1e-9:
		return 0
	for k in range(-MAX_LAG, MAX_LAG + 1):
		var acc: float = 0.0
		for i in range(start, stop, 2):   # de dos en dos: mitad de coste, misma respuesta
			acc += l[i] * r[i - k]
		if acc > best:
			best = acc
			best_lag = k
	return best_lag

## Diferencia de nivel R - L en dB sobre el RMS de cada canal.
static func _ild_db(l: PackedFloat32Array, r: PackedFloat32Array) -> float:
	var n: int = mini(l.size(), r.size())
	if n == 0:
		return 0.0
	var el: float = 0.0
	var er: float = 0.0
	for i in range(n):
		el += l[i] * l[i]
		er += r[i] * r[i]
	el = sqrt(el / n) + 1e-9
	er = sqrt(er / n) + 1e-9
	return 20.0 * log(er / el) / log(10.0)

## Relacion de energia entre la banda del pabellon auricular (5-10 kHz), donde las HRTF
## distinguen delante de detras, y la banda media (1-4 kHz). Sobre TODA la captura: con
## cuatro bloques de 1024 el centroide oscilaba de 2 a 6 % entre corridas, que es ruido de
## medida y no HRTF.
static func _pinna_band_ratio(cap: Dictionary, mix_rate: float) -> float:
	var l: PackedFloat32Array = cap["left"]
	var r: PackedFloat32Array = cap["right"]
	var n: int = mini(l.size(), r.size())
	var high: float = 0.0
	var mid: float = 0.0
	var offset: int = 0
	while offset + 1024 <= n:
		var mono := PackedFloat32Array()
		for i in range(offset, offset + 1024):
			mono.append(l[i] + r[i])
		high += _band_energy(mono, mix_rate, 5000.0, 10000.0)
		mid += _band_energy(mono, mix_rate, 1000.0, 4000.0)
		offset += 1024
	return high / maxf(mid, 1e-9)

## Energia en una banda por DFT directa en los armonicos del periodo (uno de cada cuatro)
## dentro de la banda: con la fuente periodica, estas magnitudes no dependen de la fase de
## la captura.
static func _band_energy(x: PackedFloat32Array, mix_rate: float, f_lo: float, f_hi: float) -> float:
	var n: int = x.size()
	var energy: float = 0.0
	var k_lo: int = int(ceil(f_lo * PERIOD / mix_rate))
	var k_hi: int = int(floor(f_hi * PERIOD / mix_rate))
	for k in range(k_lo, k_hi + 1, 4):
		var w: float = TAU * float(k) / float(PERIOD)
		var re: float = 0.0
		var im: float = 0.0
		for i in range(n):
			re += x[i] * cos(w * i)
			im -= x[i] * sin(w * i)
		energy += re * re + im * im
	return energy

## Centroide de los dos canales sumados sobre toda la captura. Solo informativo.
static func _spectral_centroid_stereo(cap: Dictionary, mix_rate: float) -> float:
	var l: PackedFloat32Array = cap["left"]
	var r: PackedFloat32Array = cap["right"]
	var n: int = mini(l.size(), r.size())
	var total: float = 0.0
	var blocks: int = 0
	var offset: int = 0
	while offset + 1024 <= n:
		var mono := PackedFloat32Array()
		for i in range(offset, offset + 1024):
			mono.append(l[i] + r[i])
		total += _spectral_centroid(mono, mix_rate)
		blocks += 1
		offset += 1024
	return total / maxf(float(blocks), 1.0)

## Centroide espectral (Hz) por DFT directa de 1024 muestras en 96 bandas hasta Nyquist.
static func _spectral_centroid(x: PackedFloat32Array, mix_rate: float) -> float:
	var n: int = mini(x.size(), 1024)
	if n < 256:
		return 0.0
	var bins: int = 96
	var num: float = 0.0
	var den: float = 0.0
	for b in range(1, bins):
		var f: float = float(b) / float(bins) * (mix_rate * 0.5)
		var w: float = TAU * f / mix_rate
		var re: float = 0.0
		var im: float = 0.0
		for i in range(n):
			re += x[i] * cos(w * i)
			im -= x[i] * sin(w * i)
		var mag: float = sqrt(re * re + im * im)
		num += f * mag
		den += mag
	return num / maxf(den, 1e-9)

## Energia de una banda sobre la suma L+R de toda la captura, en bloques de PERIOD.
static func _band_energy_stereo(cap: Dictionary, mix_rate: float, f_lo: float, f_hi: float) -> float:
	var l: PackedFloat32Array = cap["left"]
	var r: PackedFloat32Array = cap["right"]
	var n: int = mini(l.size(), r.size())
	var total: float = 0.0
	var offset: int = 0
	while offset + PERIOD <= n:
		var mono := PackedFloat32Array()
		for i in range(offset, offset + PERIOD):
			mono.append(l[i] + r[i])
		total += _band_energy(mono, mix_rate, f_lo, f_hi)
		offset += PERIOD
	return total

## RMS en dB de los dos canales juntos.
static func _rms_db(cap: Dictionary) -> float:
	var l: PackedFloat32Array = cap["left"]
	var r: PackedFloat32Array = cap["right"]
	var n: int = mini(l.size(), r.size())
	var acc: float = 0.0
	for i in range(n):
		acc += 0.5 * (l[i] * l[i] + r[i] * r[i])
	return linear_to_db(sqrt(acc / maxf(float(n), 1.0)) + 1e-9)
