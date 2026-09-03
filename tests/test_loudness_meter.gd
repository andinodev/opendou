class_name TestLoudnessMeter
extends RefCounted

## Fase 8: medidor BS.1770-4. Un seno de 1 kHz a -23 dBFS de pico en ambos canales mide
## -23.0 LUFS (la norma fija -3.01 LKFS para un canal a 0 dBFS). Silencio: la compuerta
## absoluta no deja nada. Y el coste se imprime, porque en GDScript no es gratis.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const MeterClass = preload("res://addons/opendou/runtime/loudness_meter.gd")

static func _sine_db(peak_db: float, seconds: float) -> AudioStreamWAV:
	var rate: int = int(AudioServer.get_mix_rate())
	var n: int = int(rate * seconds)
	var amp: float = db_to_linear(peak_db) * 32767.0
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	for i in range(n):
		var v: int = int(sin(TAU * 1000.0 * i / rate) * amp)
		bytes.encode_s16(i * 4, v)
		bytes.encode_s16(i * 4 + 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = rate
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n - 1
	return wav

static func _make_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, "Master")

static func _wait_ms(tree: SceneTree, ms: int, meter) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await tree.process_frame
		if meter != null:
			meter.process()

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("loudness_meter")
	_make_bus("LufsProbe")
	var meter = MeterClass.new()
	a.ok(meter.attach(&"LufsProbe"), "el medidor se engancha al bus")
	a.ok(meter.attach(&"LufsProbe"), "engancharse dos veces es idempotente")
	var idx: int = AudioServer.get_bus_index("LufsProbe")
	var captures: int = 0
	for e in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, e).resource_name == "OpenDou_LoudnessMeter_Capture":
			captures += 1
	a.eq(captures, 1, "y deja una sola captura marcada")

	# Silencio: 1 s medido, la compuerta absoluta no deja bloques.
	await _wait_ms(tree, 1000, meter)
	a.ok(is_inf(meter.integrated_lufs) and meter.integrated_lufs < 0.0, "en silencio la integrada no tiene valor (-INF), no -70")

	# Tono de calibracion, 3.5 s.
	meter.reset()
	var player := AudioStreamPlayer.new()
	# 4 s sin bucle: el WAV de 1 s en bucle daba un pico espurio de -5 a -7 dBFS justo en el
	# punto de bucle (el interpolador lee mas alla del final del bufer); cinco corridas en
	# dos fases lo confirmaron a los 1001 ms exactos.
	player.stream = _sine_db(-23.0, 4.0)
	player.bus = "LufsProbe"
	tree.root.add_child(player)
	player.play()
	var total_usec: int = 0
	var t0: int = Time.get_ticks_msec()
	# Se espera por AUDIO procesado (3.4 s), no por reloj: el driver headless corre mas lento
	# que el reloj bajo carga, y con 3.5 s de reloj la ventana de 3 s del corto plazo no llenaba.
	while meter.processed_seconds < 3.4 and Time.get_ticks_msec() - t0 < 6000:
		await tree.process_frame
		meter.process()
		total_usec += meter.last_process_usec
	print("[OpenDou] LUFS tono -23 dBFS: M=%.2f S=%.2f I=%.2f pico=%.2f dBFS | %.1f s procesados, coste %.1f ms por segundo de audio" % [
		meter.momentary_lufs, meter.short_term_lufs, meter.integrated_lufs, meter.sample_peak_db,
		meter.processed_seconds, float(total_usec) / 1000.0 / maxf(meter.processed_seconds, 0.001)])
	a.approx(meter.integrated_lufs, -23.0, "integrada -23.0 LUFS", 0.5)
	a.approx(meter.short_term_lufs, -23.0, "a corto plazo -23.0 LUFS", 0.5)
	a.approx(meter.momentary_lufs, -23.0, "momentanea -23.0 LUFS", 0.7)
	a.approx(meter.sample_peak_db, -23.0, "pico muestral -23 dBFS", 0.3)
	a.gt(meter.processed_seconds, 3.0, "se procesaron al menos 3 s")

	# Compuerta relativa: 2 s de silencio en medio no bajan la integrada.
	var integrated_tone: float = meter.integrated_lufs
	player.stop()
	await _wait_ms(tree, 2000, meter)
	a.approx(meter.integrated_lufs, integrated_tone, "el silencio intermedio no baja la integrada (compuerta)", 0.3)

	tree.root.remove_child(player)
	player.free()
	meter.detach()
	a.ok(not meter.is_attached(), "detach quita la captura")
	return a

## Presupuesto de sonoridad por demo (tests/loudness_budget.txt). Lo llaman los tests de las
## demos al terminar, con el medidor del autoload enganchado a Master durante la escena: asi
## no se instancian las demos dos veces (cada instanciacion retiene objetos del servidor).
static func check_budget(a: OpenDouAssert, key: String, lufs: float) -> void:
	var budget: Dictionary = {}
	for line in FileAccess.get_file_as_string("res://tests/loudness_budget.txt").split("\n"):
		var t: String = line.strip_edges()
		if t.is_empty() or t.begins_with("#"):
			continue
		var parts: PackedStringArray = t.split(" ", false)
		if parts.size() == 3:
			budget[parts[0]] = [float(parts[1]), float(parts[2])]
	print("[OpenDou] sonoridad de %s: %.1f LUFS (rango %s)" % [key, lufs, str(budget.get(key, "sin rango"))])
	if budget.has(key):
		a.ok(lufs >= budget[key][0] and lufs <= budget[key][1], "%s dentro de su rango de sonoridad [%s, %s]: %.1f LUFS" % [key, budget[key][0], budget[key][1], lufs])

## Engancha el medidor del autoload a Master y lo reinicia. Devuelve el medidor o null.
static func start_master_meter(tree: SceneTree):
	var m = tree.root.get_node_or_null("OpenDou")
	if m == null or not ("loudness_meter" in m):
		return null
	m.loudness_meter.attach(&"Master")
	m.loudness_meter.reset()
	return m.loudness_meter

## Lee la integrada y suelta el medidor.
static func finish_master_meter(meter) -> float:
	if meter == null:
		return -INF
	var lufs: float = meter.integrated_lufs
	meter.detach()
	return lufs
