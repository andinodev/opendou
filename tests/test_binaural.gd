class_name TestBinaural
extends RefCounted

## Suite binaural de la Fase 7B: el stream nativo sobre Steam Audio, medido en el bus.
## Nacio como el spike 7A (puede una voz salir por Steam Audio, y hace algo el HRTF).
##
## Aserciones de audio REAL sobre el estereo capturado del bus de la voz:
##  - ITD: una fuente a la derecha llega antes al oido derecho (correlacion cruzada L/R).
##  - ILD: el oido lejano recibe menos nivel.
##  - Delante / detras: distinto centroide espectral, que el paneo por amplitud no puede dar.
##  - CONTROL: con el HRTF apagado, ITD = 0 e ILD = 0. Si estas no fallan al apagarlo, las
##    de arriba no afirman nada.
##
## Si la extension nativa no esta cargada, la suite se omite y lo dice: es el doble backend
## funcionando, no un fallo. Pero lo dice, para que nadie crea que se probo.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
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
	# HALLAZGO DEL SPIKE, afirmado para que 7B no lo suponga al reves: el audio que sale del
	# efecto binaural NO lleva ITD -los picos de las HRIR vienen alineados-, y Steam Audio
	# reporta los retardos de pico por oido en peakDelays para que los aplique quien llama.
	# El estimador SI recupera retardos (autochequeo de arriba), asi que el cero es real.
	# Si una version futura de Steam Audio empieza a hornear el ITD, esta asercion cae y
	# la linea de retardo de 7B pasaria a aplicarlo dos veces.
	a.ok(absf(lag_right) <= 3,
		"el audio binaural sale SIN ITD: los picos vienen alineados (lag medido %d)" % lag_right)
	a.gt(absf(pd.x - pd.y) * 1000.0, 0.05,
		"pero Steam Audio reporta retardos de pico distintos por oido: el ITD hay que aplicarlo aparte")
	a.gt(pd.x, pd.y, "con la fuente a la derecha el pico IZQUIERDO llega mas tarde")
	a.gt(ild_right, 3.0, "ILD: con la fuente a la derecha, el oido derecho recibe al menos 3 dB mas")

	# ---- IZQUIERDA: simetrico, y el signo se invierte.
	stream.direction = Vector3(-1, 0, 0)
	var left := await _capture(tree, probe)
	var lag_left: int = _itd_lag(left.left, left.right)
	var ild_left: float = _ild_db(left.left, left.right)
	var pd_left: Vector2 = stream.get_last_peak_delays()
	print("[OpenDou] izquierda: lag=%d muestras  ILD=%.1f dB (R-L) | peakDelays: L=%.3f ms R=%.3f ms" % [
		lag_left, ild_left, pd_left.x * 1000.0, pd_left.y * 1000.0])
	a.ok(absf(lag_left) <= 3, "a la izquierda tampoco hay ITD en la salida")
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
	a.lt(shelf_drop_db, -8.0, "el shelf de -12 dB baja la banda alta al menos 8 dB")
	a.gt(shelf_low_db, -2.0, "y deja la banda media casi intacta")

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
