extends SceneTree
## Sondeo: ruido por un sub-bus (X -> Master); paso-bajo en Master; captura despues. Filtra?
const TB = preload("res://tests/test_binaural.gd")
func _cap(cap: AudioEffectCapture) -> Dictionary:
	cap.clear_buffer()
	var l := PackedFloat32Array(); var r := PackedFloat32Array()
	while l.size() < 8192:
		await process_frame
		var n: int = cap.get_frames_available()
		if n > 0:
			for v in cap.get_buffer(n):
				l.append(v.x); r.append(v.y)
	return {"left": l, "right": r}
func _init() -> void:
	await process_frame
	var idx: int = AudioServer.get_bus_index("Master")
	var bi: int = AudioServer.bus_count; AudioServer.add_bus(bi); AudioServer.set_bus_name(bi, "X"); AudioServer.set_bus_send(bi, "Master")
	var cap := AudioEffectCapture.new(); cap.buffer_length = 2.0; AudioServer.add_bus_effect(idx, cap)
	var p := AudioStreamPlayer.new(); p.stream = TB._periodic_noise(int(AudioServer.get_mix_rate())); p.bus = "X"; root.add_child(p); p.play()
	for i in range(20): await process_frame
	var rate: float = AudioServer.get_mix_rate()
	var dry: Dictionary = await _cap(cap)
	var lpf := AudioEffectLowPassFilter.new(); lpf.cutoff_hz = 600.0; AudioServer.add_bus_effect(idx, lpf, 0)
	for i in range(20): await process_frame
	var wet: Dictionary = await _cap(cap)
	for c in [["seco via X", dry], ["600 Hz via X", wet]]:
		print("%s: agudos %.1f graves %.1f" % [c[0], linear_to_db(maxf(TB._band_energy_stereo(c[1], rate, 2000.0, 8000.0), 1e-12)), linear_to_db(maxf(TB._band_energy_stereo(c[1], rate, 100.0, 400.0), 1e-12))])
	var names: Array = []
	for e in range(AudioServer.get_bus_effect_count(idx)): names.append(AudioServer.get_bus_effect(idx, e).get_class())
	print("Master: ", names)
	quit()
