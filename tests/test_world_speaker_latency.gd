class_name TestWorldSpeakerLatency
extends RefCounted

## Fase 15 (C5): latencia del altavoz de mundo (OpenDouEventPlayer3D.source = BUS_CAPTURE).
## Clicks en el bus origen; sonda en el bus destino de la voz del altavoz; la latencia es la
## diferencia entre el primer pico de cada click en ambas capturas, alineadas al mismo cuadro.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const EventPlayer3DScript = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")

const SRC_BUS := &"WorldSrc"

## Tren de clicks: una muestra a 0 dBFS cada `period` s, `seconds` de largo.
static func _clicks(rate: int, period: float, seconds: float) -> AudioStreamWAV:
	var n: int = int(rate * seconds)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var step: int = int(rate * period)
	for i in range(n):
		bytes.encode_s16(i * 2, 32767 if (i % step) == 0 and i > 0 else 0)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav

## Indices de los picos (muestras que superan `thr` veces el maximo) separados al menos 0.2 s.
static func _peaks(frames: PackedVector2Array, rate: int, thr: float) -> Array[int]:
	var mx: float = 0.0
	for f in frames:
		mx = maxf(mx, maxf(absf(f.x), absf(f.y)))
	var out: Array[int] = []
	var last: int = -int(rate * 0.2)
	for i in range(frames.size()):
		var v: float = maxf(absf(frames[i].x), absf(frames[i].y))
		if v >= thr * mx and i - last > int(rate * 0.2):
			out.append(i)
			last = i
	return out

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("world_speaker_latency")
	var manager = tree.root.get_node_or_null("OpenDou")
	a.ok(manager != null, "el autoload OpenDou existe")
	if manager == null:
		return a
	if AudioServer.get_bus_index(String(SRC_BUS)) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, String(SRC_BUS))
		AudioServer.set_bus_send(idx, "Master")
	TestParityClass.ensure_bus()
	var cam: Camera3D = TestParityClass.make_listener_camera(tree)
	cam.global_position = Vector3.ZERO
	var rate: int = int(AudioServer.get_mix_rate())
	# Sonda del origen ANTES del altavoz (su captura y su -80 dB van despues).
	var src_probe = OpenDouAudioProbeClass.new()
	src_probe.attach_to_existing_bus(SRC_BUS, 4.0)
	var dst_probe = OpenDouAudioProbeClass.new()
	dst_probe.attach_to_existing_bus(TestParityClass.BUS, 4.0)
	var speaker = EventPlayer3DScript.new()
	speaker.source = EventPlayer3DScript.Source.BUS_CAPTURE
	speaker.capture_bus = SRC_BUS
	speaker.bus_category = String(TestParityClass.BUS)
	speaker.unit_size = 4.0
	speaker.auto_play_event = false
	tree.root.add_child(speaker)
	speaker.global_position = Vector3(0, 0, -1)
	speaker.play_event()
	a.ok(speaker.active_instance != null and speaker.active_instance.is_playing(), "el altavoz tiene voz")
	# Cebado: dos cuadros para que el generador tenga su colchon y la voz arranque.
	for i in range(3):
		await tree.process_frame
	var player := AudioStreamPlayer.new()
	player.stream = _clicks(rate, 0.5, 2.5)
	player.bus = String(SRC_BUS)
	tree.root.add_child(player)
	src_probe.drain()
	dst_probe.drain()
	player.play()
	var src := PackedVector2Array()
	var dst := PackedVector2Array()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3200:
		await tree.process_frame
		var a1: int = src_probe._capture.get_frames_available()
		if a1 > 0:
			src.append_array(src_probe._capture.get_buffer(a1))
		var a2: int = dst_probe._capture.get_frames_available()
		if a2 > 0:
			dst.append_array(dst_probe._capture.get_buffer(a2))
	var sp: Array[int] = _peaks(src, rate, 0.5)
	var dp: Array[int] = _peaks(dst, rate, 0.3)
	var lat_ms: Array[float] = []
	for k in range(mini(sp.size(), dp.size())):
		lat_ms.append(1000.0 * float(dp[k] - sp[k]) / float(rate))
	print("[OpenDou] altavoz de mundo: %d clicks en origen, %d en destino; latencias %s ms (capturas %d/%d muestras)" % [sp.size(), dp.size(), str(lat_ms), src.size(), dst.size()])
	a.ok(sp.size() >= 3, "el origen tiene al menos 3 clicks (%d)" % sp.size())
	a.ok(dp.size() >= 3, "el destino tambien (%d)" % dp.size())
	if lat_ms.size() >= 3:
		var mn: float = lat_ms[0]
		var mx: float = lat_ms[0]
		for v in lat_ms:
			mn = minf(mn, v)
			mx = maxf(mx, v)
		a.gt(mn, 0.0, "la latencia es positiva")
		a.lt(mx, 250.0, "y menor de 250 ms (peor %.0f ms)" % mx)
		a.lt(mx - mn, 20.0, "y estable entre clicks (+-%.0f ms)" % ((mx - mn) / 2.0))
	player.stop()
	speaker.stop_event()
	tree.root.remove_child(player); player.free()
	tree.root.remove_child(speaker); speaker.free()
	src_probe.teardown()
	dst_probe.teardown()
	tree.root.remove_child(cam); cam.free()
	await tree.create_timer(0.3).timeout
	return a
