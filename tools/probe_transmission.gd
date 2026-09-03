extends SceneTree
## Sondeo: transmision del efecto directo por material, en el stream, banda 100-700 Hz.
const TB = preload("res://tests/test_binaural.gd")
func _init() -> void:
	await process_frame
	var probe = load("res://tests/support/audio_probe.gd").new()
	var bus := &"TrProbe"
	var idx: int = AudioServer.bus_count; AudioServer.add_bus(idx); AudioServer.set_bus_name(idx, String(bus)); AudioServer.set_bus_send(idx, "Master")
	probe.attach_to_existing_bus(bus, 2.0)
	var stream = ClassDB.instantiate("OpenDouSpatialStream")
	stream.source = TB._periodic_noise(int(AudioServer.get_mix_rate()))
	stream.spatialize = true; stream.spatial_blend = 0.0; stream.direction = Vector3(0, 0, -1)
	var player := AudioStreamPlayer.new(); player.stream = stream; player.bus = String(bus); root.add_child(player); player.play()
	var rate: float = AudioServer.get_mix_rate()
	for i in range(20): await process_frame
	var cases = [["libre", false, 1.0, Vector3.ONE], ["occl 0.5 sin tr", true, 0.5, Vector3.ONE], ["cristal", true, 0.0, Vector3(0.06, 0.044, 0.011)], ["hormigon", true, 0.0, Vector3(0.015, 0.002, 0.001)], ["metal", true, 0.0, Vector3(0.2, 0.025, 0.01)], ["tr 0.5 plano", true, 0.0, Vector3(0.5, 0.5, 0.5)], ["tr 0.1 plano", true, 0.0, Vector3(0.1, 0.1, 0.1)]]
	for c in cases:
		stream.set_direct_params(c[1], c[2], c[3], Vector3.ONE, 1.0)
		probe.drain()
		var cap: Dictionary = await TB._capture(self, probe)
		print("%-16s lo(100-700) %.1f  mid(1-4k) %.1f  hi(9-15k) %.1f dB" % [c[0], linear_to_db(maxf(TB._band_energy_stereo(cap, rate, 100.0, 700.0), 1e-12)), linear_to_db(maxf(TB._band_energy_stereo(cap, rate, 1000.0, 4000.0), 1e-12)), linear_to_db(maxf(TB._band_energy_stereo(cap, rate, 9000.0, 15000.0), 1e-12))])
	quit()
