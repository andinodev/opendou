class_name TestEmitterPhysics
extends RefCounted

## Fase 9: el emisor completo, medido en el bus con un control por mecanismo.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const ParityClass = preload("res://tests/test_backend_parity.gd")
const BinauralClass = preload("res://tests/test_binaural.gd")

static func _tone(freq: float, seconds: float, peak_db: float = -6.0) -> AudioStreamWAV:
	var rate: int = int(AudioServer.get_mix_rate())
	var n: int = int(rate * seconds)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var amp: float = db_to_linear(peak_db) * 32767.0
	for i in range(n):
		bytes.encode_s16(i * 2, int(sin(TAU * freq * i / rate) * amp))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav

## Frecuencia por cruces por cero de la suma L+R. Solo vale para un tono puro.
static func _estimate_frequency_hz(cap: Dictionary, rate: float) -> float:
	var l: PackedFloat32Array = cap["left"]
	var r: PackedFloat32Array = cap["right"]
	var n: int = mini(l.size(), r.size())
	if n < 1024:
		return 0.0
	var crossings: int = 0
	var prev: float = l[0] + r[0]
	for i in range(1, n):
		var v: float = l[i] + r[i]
		if (prev < 0.0 and v >= 0.0) or (prev > 0.0 and v <= 0.0):
			crossings += 1
		prev = v
	return float(crossings) * 0.5 * rate / float(n)

static func _wait_ms(tree: SceneTree, ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await tree.process_frame

static func _backend_setting() -> String:
	return str(ProjectSettings.get_setting("opendou/spatial/backend", "auto"))

## Un tono de 1 kHz que se acerca a 30 m/s sube a ~1096 Hz; alejandose baja a ~920 Hz; con el
## doppler apagado, 1000 Hz. En el backend godot (pitch_scale) y en steam_audio.
static func run_doppler_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("doppler")
	var previous: String = _backend_setting()
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var rate: float = AudioServer.get_mix_rate()
	for backend in ["godot", "steam_audio"]:
		if backend == "steam_audio" and not ClassDB.class_exists("OpenDouSpatialStream"):
			print("[OpenDou] extension nativa AUSENTE: doppler en steam_audio omitido")
			continue
		var manager = ParityClass.make_manager(tree, backend)
		await tree.process_frame
		var def = AudioEventDefClass.new(&"DopplerTone", _tone(1000.0, 1.0))
		def.is_looping = true
		def.stream_length = 1.0
		def.target_bus = ParityClass.BUS
		def.attenuation_model = 3
		manager.register_event_definition(def)
		manager.set_listener_position(Vector3.ZERO)
		for enabled in [true, false]:
			def.doppler_enabled = enabled
			for direction in [-1.0, 1.0]:
				var inst = manager.post_event(def, null)
				var z: float = -40.0 if direction < 0.0 else -10.0
				inst.set_position(Vector3(0, 0, z))
				await _wait_ms(tree, 200)
				probe.drain()
				var l := PackedFloat32Array()
				var r := PackedFloat32Array()
				var t0: int = Time.get_ticks_msec()
				var last: int = t0
				while Time.get_ticks_msec() - t0 < 600:
					await tree.process_frame
					var now: int = Time.get_ticks_msec()
					var dt: float = float(now - last) / 1000.0
					last = now
					z += -direction * 30.0 * dt
					inst.set_position(Vector3(0, 0, z))
					var avail: int = probe._capture.get_frames_available()
					if avail > 0 and now - t0 > 150:
						for v in probe._capture.get_buffer(avail):
							l.append(v.x)
							r.append(v.y)
					elif avail > 0:
						probe._capture.get_buffer(avail)
				var f: float = _estimate_frequency_hz({"left": l, "right": r}, rate)
				var label: String = "%s, doppler %s, %s" % [backend, "on" if enabled else "off", "acercandose" if direction < 0.0 else "alejandose"]
				print("[OpenDou] %s: %.0f Hz" % [label, f])
				if enabled and direction < 0.0:
					a.ok(f > 1050.0 and f < 1140.0, label + ": sube a ~1096 Hz (medido %.0f)" % f)
				elif enabled:
					a.ok(f > 880.0 and f < 960.0, label + ": baja a ~920 Hz (medido %.0f)" % f)
				else:
					a.ok(f > 980.0 and f < 1020.0, label + ": se queda en 1000 Hz (medido %.0f)" % f)
				inst.stop()
				await probe.await_silence(tree, 0.002, 30)
		manager.stop_all()
		tree.root.remove_child(manager)
		manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a

## Directividad dipolo: de frente 0 dB, de lado el suelo; con peso 0, igual en todas partes.
static func run_directivity_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("directivity")
	var previous: String = _backend_setting()
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var manager = ParityClass.make_manager(tree, "godot")
	await tree.process_frame
	var def = AudioEventDefClass.new(&"DirTone", BinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = ParityClass.BUS
	def.attenuation_model = 3
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)
	var levels: Dictionary = {}
	for weight in [1.0, 0.5, 0.0]:
		def.directivity_dipole_weight = weight
		def.directivity_power = 1.0
		for facing in ["front", "side", "back"]:
			var inst = manager.post_event(def, null)
			# El emisor esta en -Z; el oyente queda en +Z respecto a el.
			inst.set_position(Vector3(0, 0, -5))
			match facing:
				"front":
					inst.set_orientation(Vector3(0, 0, 1))
				"side":
					inst.set_orientation(Vector3(1, 0, 0))
				"back":
					inst.set_orientation(Vector3(0, 0, -1))
			await _wait_ms(tree, 250)
			probe.drain()
			var cap := await BinauralClass._capture(tree, probe)
			levels["%s_%s" % [weight, facing]] = BinauralClass._rms_db(cap)
			inst.stop()
			await probe.await_silence(tree, 0.002, 30)
	print("[OpenDou] directividad: ", levels)
	a.lt(levels["1.0_side"] - levels["1.0_front"], -20.0, "peso 1: de lado cae al menos 20 dB respecto a de frente")
	a.approx(levels["1.0_back"], levels["1.0_front"], "peso 1 (dipolo): de espaldas suena como de frente", 1.0)
	a.lt(levels["0.5_back"] - levels["0.5_front"], -20.0, "peso 0.5 (cardioide): de espaldas cae al menos 20 dB")
	a.approx(levels["0.0_side"], levels["0.0_front"], "peso 0: omnidireccional (control)", 0.5)
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a
