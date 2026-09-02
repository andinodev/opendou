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

## La misma curva da el mismo nivel en los dos backends: a 5.5 m cae ~20 dB respecto a 5 m.
static func run_curve_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("attenuation_curve")
	var previous: String = _backend_setting()
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var c := Curve.new()
	c.min_value = -80.0
	c.max_value = 6.0
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.5, 0.0))
	c.add_point(Vector2(0.6, -40.0))
	c.add_point(Vector2(1.0, -40.0))
	var drops: Dictionary = {}
	for backend in ["godot", "steam_audio"]:
		if backend == "steam_audio" and not ClassDB.class_exists("OpenDouSpatialStream"):
			print("[OpenDou] extension nativa AUSENTE: curva en steam_audio omitida")
			continue
		var manager = ParityClass.make_manager(tree, backend)
		await tree.process_frame
		var def = AudioEventDefClass.new(&"CurveTone", BinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
		def.is_looping = true
		def.stream_length = 1.0
		def.target_bus = ParityClass.BUS
		def.attenuation_model = 4
		def.attenuation_curve = c
		def.attenuation_curve_distance_m = 10.0
		manager.register_event_definition(def)
		manager.set_listener_position(Vector3.ZERO)
		var levels: Dictionary = {}
		for d in [5.0, 5.5]:
			var inst = manager.post_event(def, null)
			inst.set_position(Vector3(0, 0, -d))
			await _wait_ms(tree, 250)
			probe.drain()
			levels[d] = BinauralClass._rms_db(await BinauralClass._capture(tree, probe))
			inst.stop()
			await probe.await_silence(tree, 0.002, 30)
		# El nivel sigue a la curva TAL COMO GODOT LA INTERPOLA: la referencia es c.sample(), no
		# una interpolacion lineal supuesta (Curve usa Hermite y a 0.55 no da -20 dB sino ~-30).
		# El multiplicador de la curva alimenta ademas el shelf por distancia (en ambos backends,
		# porque el de Godot incluye volume_db): sobre ruido de banda ancha eso resta unos 10 dB
		# mas. Por eso se afirma "al menos la curva" y la paridad, no la igualdad con la curva.
		var expected_drop: float = c.sample(0.55) - c.sample(0.5)
		var drop: float = levels[5.5] - levels[5.0]
		drops[backend] = drop
		print("[OpenDou] curva (%s): 5 m %.1f dB, 5.5 m %.1f dB; la curva dice %.1f" % [backend, levels[5.0], levels[5.5], expected_drop])
		a.lt(drop, expected_drop + 1.0, "%s: el nivel cae al menos lo que dice la curva (medido %.1f, curva %.1f)" % [backend, drop, expected_drop])
		manager.stop_all()
		tree.root.remove_child(manager)
		manager.free()
	if drops.has("godot") and drops.has("steam_audio"):
		a.lt(absf(drops["godot"] - drops["steam_audio"]), 1.5, "la curva cae lo mismo en los dos backends (%.1f frente a %.1f)" % [drops["godot"], drops["steam_audio"]])
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a

## Spread: a 1 m con radio 10 la voz colapsa hacia el centro (ILD e ITD ~0); a 20 m, no.
static func run_spread_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spread")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite spread omitida")
		return a
	var previous: String = _backend_setting()
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var manager = ParityClass.make_manager(tree, "steam_audio")
	await tree.process_frame
	var def = AudioEventDefClass.new(&"SpreadNoise", BinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = ParityClass.BUS
	def.attenuation_model = 3
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)
	var results: Dictionary = {}
	for radius in [10.0, 0.0]:
		def.spread_radius_m = radius
		for d in [1.0, 20.0]:
			var inst = manager.post_event(def, null)
			inst.set_position(Vector3(d, 0, 0))
			await _wait_ms(tree, 250)
			probe.drain()
			var cap := await BinauralClass._capture(tree, probe)
			results["%s_%s" % [radius, d]] = {"ild": BinauralClass._ild_db(cap.left, cap.right), "lag": BinauralClass._itd_lag(cap.left, cap.right)}
			inst.stop()
			await probe.await_silence(tree, 0.002, 30)
	print("[OpenDou] spread: ", results)
	# Spread 0.9 deja un 10 % de HRTF: la ILD no es cero, pero cae a menos de un cuarto.
	a.lt(absf(results["10.0_1.0"]["ild"]), 0.25 * results["10.0_20.0"]["ild"], "radio 10 a 1 m: la ILD cae a menos de un cuarto de la de 20 m (spread 0.9)")
	a.ok(absf(results["10.0_1.0"]["lag"]) <= 4, "y el ITD tambien")
	a.gt(results["10.0_20.0"]["ild"], 6.0, "radio 10 a 20 m: ILD normal")
	a.gt(results["0.0_1.0"]["ild"], 6.0, "radio 0 (apagado) a 1 m: ILD normal (control)")
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a

## Campo cercano: a 0.2 m con distancia 0.5 suben los graves y crece la ILD; a 1 m, no.
static func run_near_field_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("near_field")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite near_field omitida")
		return a
	var previous: String = _backend_setting()
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var manager = ParityClass.make_manager(tree, "steam_audio")
	await tree.process_frame
	var rate: float = AudioServer.get_mix_rate()
	var def = AudioEventDefClass.new(&"NearNoise", BinauralClass._periodic_noise(int(rate)))
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = ParityClass.BUS
	def.attenuation_model = 3
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)
	var res: Dictionary = {}
	for nfd in [0.5, 0.0]:
		def.near_field_distance_m = nfd
		for d in [0.2, 1.0]:
			var inst = manager.post_event(def, null)
			inst.set_position(Vector3(d, 0, 0))
			await _wait_ms(tree, 250)
			probe.drain()
			var cap := await BinauralClass._capture(tree, probe)
			res["%s_%s" % [nfd, d]] = {"bass": BinauralClass._band_energy_stereo(cap, rate, 60.0, 200.0), "ild": BinauralClass._ild_db(cap.left, cap.right)}
			inst.stop()
			await probe.await_silence(tree, 0.002, 30)
	var bass_gain_db: float = 10.0 * log(res["0.5_0.2"]["bass"] / maxf(res["0.5_1.0"]["bass"], 1e-12)) / log(10.0)
	var bass_ctrl_db: float = 10.0 * log(res["0.0_0.2"]["bass"] / maxf(res["0.0_1.0"]["bass"], 1e-12)) / log(10.0)
	print("[OpenDou] campo cercano: graves +%.1f dB (control %.1f), ILD %.1f frente a %.1f dB" % [bass_gain_db, bass_ctrl_db, res["0.5_0.2"]["ild"], res["0.5_1.0"]["ild"]])
	# A 0.2 m con distancia 0.5 la cercania es 0.6: se piden 3.6 dB de graves y 3.6 de ILD.
	a.approx(bass_gain_db, 3.6, "a 0.2 m los graves suben lo pedido (0.6 x 6 dB)", 1.0)
	a.lt(absf(bass_ctrl_db), 1.0, "con la distancia en 0, los graves no cambian (control)")
	a.gt(res["0.5_0.2"]["ild"] - res["0.5_1.0"]["ild"], 2.5, "y la ILD crece al menos 2.5 dB (pedidos 3.6)")
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a
