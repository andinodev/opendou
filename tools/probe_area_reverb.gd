extends SceneTree

## Experimento: un reproductor 3D dentro de un Area3D con reverb_bus. Que llega a su propio
## bus (seco) y que al bus de reverb, con un WAV plano y con OpenDouSpatialStream.
##
##     Godot --headless --path . -s tools/probe_area_reverb.gd

func _bus(name: String) -> int:
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, name)
	AudioServer.set_bus_send(idx, "Master")
	return idx

func _tone() -> AudioStreamWAV:
	var rate: int = int(AudioServer.get_mix_rate())
	var n: int = rate
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		bytes.encode_s16(i * 2, int(sin(TAU * 440.0 * i / rate) * 0.3 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n - 1
	return wav

func _initialize() -> void:
	_run()

func _run() -> void:
	var d_idx: int = _bus("D")
	var r_idx: int = _bus("R")
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 10, 20)
	cs.shape = box
	area.add_child(cs)
	area.reverb_bus_enabled = true
	area.reverb_bus_name = "R"
	area.reverb_bus_amount = 0.5
	area.reverb_bus_uniformity = 0.5
	root.add_child(area)
	for variant in ["wav plano", "OpenDouSpatialStream"]:
		for mask in [1, 0]:
			var p := AudioStreamPlayer3D.new()
			if variant == "wav plano":
				p.stream = _tone()
			else:
				var s = ClassDB.instantiate("OpenDouSpatialStream")
				s.source = _tone()
				p.stream = s
				p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
				p.panning_strength = 0.0
			p.bus = "D"
			p.area_mask = mask
			root.add_child(p)
			p.global_position = Vector3(0, 0, -2)
			p.play()
			for i in range(40):
				await process_frame
			print("%-22s area_mask=%d -> seco D: %.1f dB | reverb R: %.1f dB" % [variant, mask, AudioServer.get_bus_peak_volume_left_db(d_idx, 0), AudioServer.get_bus_peak_volume_left_db(r_idx, 0)])
			p.stop()
			root.remove_child(p)
			p.free()
			for i in range(20):
				await process_frame
	quit(0)
