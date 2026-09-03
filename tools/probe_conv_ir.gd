extends SceneTree

## Experimento: caja de hormigon, simulador con reflexiones, fuente de oyente, y el efecto de
## convolucion en un bus con un tono corto. Mide tono y cola. Sin manager ni salas.

const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

func _tone(sec: float) -> AudioStreamWAV:
	var rate: int = int(AudioServer.get_mix_rate())
	var n: int = int(rate * sec)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		bytes.encode_s16(i * 2, int(sin(TAU * 1000.0 * i / rate) * 0.5 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav

func _rms_db(frames: PackedVector2Array, from: int, to: int) -> float:
	var acc: float = 0.0
	var n: int = 0
	var nans: int = 0
	for i in range(maxi(from, 0), mini(to, frames.size())):
		if is_nan(frames[i].x) or is_nan(frames[i].y):
			nans += 1
			continue
		acc += 0.5 * (frames[i].x * frames[i].x + frames[i].y * frames[i].y)
		n += 1
	if nans > 0:
		print("  (NaN en %d muestras)" % nans)
	return linear_to_db(maxf(sqrt(acc / maxf(float(n), 1.0)), 1e-9))

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var specs: Array = [[Vector3(0, -0.15, 0), Vector3(6, 0.3, 6)], [Vector3(0, 3.15, 0), Vector3(6, 0.3, 6)], [Vector3(-3.15, 1.5, 0), Vector3(0.3, 3, 6)], [Vector3(3.15, 1.5, 0), Vector3(0.3, 3, 6)], [Vector3(0, 1.5, -3.15), Vector3(6, 3, 0.3)], [Vector3(0, 1.5, 3.15), Vector3(6, 3, 0.3)]]
	for sp in specs:
		var body := StaticBody3D.new()
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = sp[1]
		mi.mesh = box
		mi.add_to_group("AcousticObstacle")
		mi.set_meta("acoustic_material", &"Concrete")
		body.add_child(mi)
		root.add_child(body)
		body.global_position = sp[0]
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	root.add_child(bake)
	bake.bake_geometry(root)
	print("escena lista: %s" % str(OpenDouAcousticScene.is_ready()))
	OpenDouSimulator.configure(8, 16, 2, true, 2.0, 4096)
	var h: int = OpenDouSimulator.create_listener_source()
	OpenDouSimulator.set_listener(Vector3(0, 1.5, 0), Vector3(0, 0, -1), Vector3.UP)
	OpenDouSimulator.set_listener_source_position(h, Vector3(0, 1.5, 0))
	OpenDouSimulator.start_reflections(10.0)
	var t0: int = Time.get_ticks_msec()
	while OpenDouSimulator.reflections_generation(h) == 0 and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	print("RT60 %s tras %d ms" % [str(OpenDouSimulator.get_reverb_times(h)), Time.get_ticks_msec() - t0])
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "ConvIR")
	AudioServer.set_bus_send(idx, "Master")
	var fx = OpenDouConvolutionReverb.new()
	fx.dry = 1.0
	fx.wet = 1.0
	fx.room_handle = h
	AudioServer.add_bus_effect(idx, fx)
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 3.0
	AudioServer.add_bus_effect(idx, cap)
	var p := AudioStreamPlayer.new()
	p.stream = _tone(0.2)
	p.bus = "ConvIR"
	p.volume_db = -6.0
	root.add_child(p)
	await process_frame
	cap.clear_buffer()
	p.play()
	var frames := PackedVector2Array()
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1400:
		await process_frame
		var avail: int = cap.get_frames_available()
		if avail > 0:
			frames.append_array(cap.get_buffer(avail))
	var rate: int = int(AudioServer.get_mix_rate())
	var shape: String = ""
	for w in range(0, 10):
		shape += " %.2f-%.2f:%.1f" % [w * 0.1, (w + 1) * 0.1, _rms_db(frames, int(rate * w * 0.1), int(rate * (w + 1) * 0.1))]
	print("tono 0.05-0.2 s: %.1f dB | muestras %d | forma (dB por 100 ms):%s" % [_rms_db(frames, int(rate * 0.05), int(rate * 0.2)), frames.size(), shape])
	fx.wet = 0.0
	cap.clear_buffer()
	p.play()
	frames = PackedVector2Array()
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1400:
		await process_frame
		var avail: int = cap.get_frames_available()
		if avail > 0:
			frames.append_array(cap.get_buffer(avail))
	print("wet 0: tono %.1f dB | cola %.1f dB" % [_rms_db(frames, int(rate * 0.05), int(rate * 0.2)), _rms_db(frames, int(rate * 0.5), int(rate * 0.8))])
	OpenDouSimulator.shutdown()
	OpenDouAcousticScene.clear()
	quit(0)
