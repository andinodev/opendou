extends SceneTree

## Experimento: un tono de -23 dBFS de 1 s en bucle, con loop_end = n y con loop_end = n - 1.
## Mide el pico en 3 s de captura. Si el primero pica y el segundo no, el interpolador de
## AudioStreamWAV lee mas alla del final del bufer en el punto de bucle.

func _sine(peak_db: float, seconds: float, loop_end_offset: int) -> AudioStreamWAV:
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
	wav.loop_end = n + loop_end_offset
	return wav

func _initialize() -> void:
	_run()

func _run() -> void:
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "LoopProbe")
	AudioServer.set_bus_send(idx, "Master")
	var cap := AudioEffectCapture.new()
	cap.buffer_length = 4.0
	AudioServer.add_bus_effect(idx, cap)
	for trial in [["loop_end = n", 0], ["loop_end = n - 1", -1], ["loop_end = n", 0], ["loop_end = n - 1", -1]]:
		var player := AudioStreamPlayer.new()
		player.stream = _sine(-23.0, 1.0, trial[1])
		player.bus = "LoopProbe"
		root.add_child(player)
		player.play()
		var t0: int = Time.get_ticks_msec()
		var peak: float = 0.0
		var when: int = -1
		while Time.get_ticks_msec() - t0 < 3200:
			await process_frame
			var avail: int = cap.get_frames_available()
			if avail > 0:
				for v in cap.get_buffer(avail):
					var m: float = maxf(absf(v.x), absf(v.y))
					if m > peak:
						peak = m
						when = Time.get_ticks_msec() - t0
		player.stop()
		root.remove_child(player)
		player.free()
		await process_frame
		cap.clear_buffer()
		print("%-18s pico %.2f dBFS (a los %d ms)" % [trial[0], linear_to_db(maxf(peak, 1e-9)), when])
	quit(0)
