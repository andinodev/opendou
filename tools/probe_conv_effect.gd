extends SceneTree

## Experimento: OpenDouConvolutionReverb en un bus SIN simulador (room_handle -1) debe dejar
## pasar el seco intacto. Mide el pico con y sin el efecto.

func _tone() -> AudioStreamWAV:
	var rate: int = int(AudioServer.get_mix_rate())
	var bytes := PackedByteArray()
	bytes.resize(rate * 2)
	for i in range(rate):
		bytes.encode_s16(i * 2, int(sin(TAU * 1000.0 * i / rate) * 0.5 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = rate - 1
	return wav

func _peak(cap: AudioEffectCapture, ms: int) -> float:
	var peak: float = 0.0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame
		var avail: int = cap.get_frames_available()
		if avail > 0:
			for v in cap.get_buffer(avail):
				peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
	return linear_to_db(maxf(peak, 1e-9))

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "ConvProbe")
	AudioServer.set_bus_send(idx, "Master")
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 2.0
	AudioServer.add_bus_effect(idx, cap)
	var p := AudioStreamPlayer.new()
	p.stream = _tone()
	p.bus = "ConvProbe"
	p.volume_db = -6.0
	root.add_child(p)
	p.play()
	await _peak(cap, 300)
	print("sin efecto: pico %.1f dBFS" % await _peak(cap, 400))
	var fx = ClassDB.instantiate("OpenDouConvolutionReverb")
	fx.dry = 1.0
	fx.wet = 0.5
	fx.room_handle = -1
	AudioServer.add_bus_effect(idx, fx, 0)
	await _peak(cap, 300)
	print("con OpenDouConvolutionReverb (sin IR): pico %.1f dBFS" % await _peak(cap, 400))
	fx.wet = 0.0
	await _peak(cap, 300)
	print("con wet 0: pico %.1f dBFS" % await _peak(cap, 400))
	var g = ClassDB.instantiate("OpenDouGainEffect")
	g.gain_db = 0.0
	AudioServer.remove_bus_effect(idx, 0)
	AudioServer.add_bus_effect(idx, g, 0)
	await _peak(cap, 300)
	print("con OpenDouGainEffect(0): pico %.1f dBFS" % await _peak(cap, 400))
	quit(0)
