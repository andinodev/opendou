extends SceneTree
## Sondeo: nivel del bus Turbines en tres posiciones, con las dos turbinas y con solo la 0.
const TB = preload("res://tests/test_binaural.gd")
const ProbeClass = preload("res://tests/support/audio_probe.gd")
func _init() -> void:
	await process_frame
	var manager = root.get_node_or_null("OpenDou")
	var demo = load("res://scenes/demos/presa/presa_demo.tscn").instantiate()
	demo.rubble_interval_sec = 0.0; demo.auto_lightning = false
	root.add_child(demo)
	await process_frame; await physics_frame; await process_frame
	var none: Array[Vector3] = []
	for gd in demo.guards: gd.waypoints = none
	manager.pathing_enabled = false
	var rate: float = AudioServer.get_mix_rate()
	var probe = ProbeClass.new(); probe.attach_to_existing_bus(&"Turbines", 2.0)
	for both in [true, false]:
		if not both:
			demo.turbines[1].stop_event()
		var out: Array = []
		for pos in [Vector3(-14, -15.5, 11), Vector3(-21, -15.5, 11), Vector3(-21, -15.5, 5.5)]:
			demo.player.global_position = pos
			for i in range(40): await process_frame
			probe.drain()
			var cap: Dictionary = await TB._capture(self, probe)
			var t0 = demo.turbines[0].active_instance
			var ch = manager.voice_pool.get_channel(t0.assigned_channel_id) if t0 != null and t0.assigned_channel_id >= 0 else null
			var d = ClassDB.class_call_static("OpenDouSimulator", "get_direct", ch.sim_source) if ch != null and ch.sim_source >= 0 else PackedFloat32Array()
			var layers: Array = []
			for lid in t0.layer_channel_ids:
				var lch = manager.voice_pool.get_channel(lid)
				layers.append("c%d sim %d busy %s" % [lid, lch.sim_source if lch != null else -9, str(lch.is_busy) if lch != null else "-"])
			out.append("%s: lo %.1f (occl %s tr %s, offsets %s, capas %s, rtpc %.2f)" % [str(pos), linear_to_db(maxf(TB._band_energy_stereo_windowed(cap, rate, 100.0, 700.0), 1e-12)), ("%.2f" % d[0]) if d.size() > 0 else "-", ("%.3f" % d[1]) if d.size() > 1 else "-", str(t0.voice_offsets_db), str(layers), float(manager.global_rtpcs.get(&"TurbineLoad", -1.0)) if "global_rtpcs" in manager else -2.0])
		print("turbinas %s: %s" % ["ambas" if both else "solo la 0", str(out)])
	manager.stop_all(); root.remove_child(demo); demo.free()
	quit()
