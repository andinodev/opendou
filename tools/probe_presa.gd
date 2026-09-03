extends SceneTree
## Sondeo de la presa: medio subacuatico, fuentes simuladas y oido del vigilante, en aislamiento.
const TB = preload("res://tests/test_binaural.gd")
const ProbeClass = preload("res://tests/support/audio_probe.gd")
func _init() -> void:
	await process_frame
	var manager = root.get_node_or_null("OpenDou")
	var demo = load("res://scenes/demos/presa/presa_demo.tscn").instantiate()
	demo.rubble_interval_sec = 0.0
	root.add_child(demo)
	await process_frame; await physics_frame; await process_frame
	var none: Array[Vector3] = []
	for gd in demo.guards: gd.waypoints = none
	var rate: float = AudioServer.get_mix_rate()
	# --- fuentes simuladas junto al aliviadero
	demo.player.global_position = Vector3(36, -15.5, 13.5)
	for i in range(40): await process_frame
	print("simulador: listo %s, capacidad %d, fuentes %d, simuladas %d, alcance %.0f" % [str(ClassDB.class_call_static("OpenDouSimulator", "is_ready")), int(ClassDB.class_call_static("OpenDouSimulator", "capacity")), int(ClassDB.class_call_static("OpenDouSimulator", "source_count")), manager.occlusion_scheduler.simulated_this_frame, manager.occlusion_scheduler.lod_controller.direct_simulation_max_distance()])
	for inst in manager.active_instances:
		if inst == null or inst.definition == null or not inst.has_spatial_position: continue
		var ch = manager.voice_pool.get_channel(inst.assigned_channel_id) if inst.assigned_channel_id >= 0 else null
		print("  voz %-14s dist %5.1f canal %2d sim %2d room_path %s sala %s" % [String(inst.definition.event_name), inst.emitter_position.distance_to(manager.active_listener_position), inst.assigned_channel_id, ch.sim_source if ch != null else -9, str(inst.room_path_active), str(manager.spatial_acoustics.get_room_at_position(inst.emitter_position).room_name) if manager.spatial_acoustics.get_room_at_position(inst.emitter_position) != null else "-"])
	# --- cristal frente a hormigon: parametros directos de la turbina 0 en tres posiciones
	for pos in [Vector3(-16, -15.5, 11), Vector3(-21, -15.5, 11), Vector3(-21, -15.5, 5.5)]:
		demo.player.global_position = pos
		for i in range(30): await process_frame
		var tinst = demo.turbines[0].active_instance
		var tch = manager.voice_pool.get_channel(tinst.assigned_channel_id) if tinst != null and tinst.assigned_channel_id >= 0 else null
		var td = ClassDB.class_call_static("OpenDouSimulator", "get_direct", tch.sim_source) if tch != null and tch.sim_source >= 0 else PackedFloat32Array()
		print("turbina desde %s: sim %d, directo %s, sala %s" % [str(pos), tch.sim_source if tch != null else -9, str(td), str(manager.spatial_acoustics.get_room_at_position(manager.active_listener_position).room_name) if manager.spatial_acoustics.get_room_at_position(manager.active_listener_position) != null else "-"])
	# --- goteo tras el codo: por que no entra en el planificador
	demo.player.global_position = Vector3(24, -15.5, 11.5)
	for i in range(60): await process_frame
	var dinst = demo.drip.active_instance
	var dch = manager.voice_pool.get_channel(dinst.assigned_channel_id) if dinst != null and dinst.assigned_channel_id >= 0 else null
	var lr = manager.spatial_acoustics.get_room_at_position(manager.active_listener_position)
	var er = manager.spatial_acoustics.get_room_at_position(dinst.emitter_position) if dinst != null else null
	print("pathing: manager %s, planificador %s, sondas listas %s, adjuntas %s, fuentes con caminos %d, corridas %d, hilo %s" % [str(manager.pathing_enabled), str(manager.occlusion_scheduler.pathing_enabled), str(manager.occlusion_scheduler.probes_ready), str(ClassDB.class_call_static("OpenDouSimulator", "probes_attached")), int(ClassDB.class_call_static("OpenDouSimulator", "pathing_source_count")), int(ClassDB.class_call_static("OpenDouSimulator", "pathing_runs")), str(ClassDB.class_call_static("OpenDouSimulator", "is_reflections_running"))])
	print("goteo: voz %s canal %d sim %d room_path %s culled %s estado %s | oyente %s en %s | emisor %s en %s | camino %s" % [str(dinst != null and dinst.is_playing()), dinst.assigned_channel_id if dinst != null else -9, dch.sim_source if dch != null else -9, str(dinst.room_path_active) if dinst != null else "-", str(dinst.culled) if dinst != null else "-", str(dinst.voice_state) if dinst != null else "-", str(manager.active_listener_position), str(lr.room_name) if lr != null else "ninguna", str(dinst.emitter_position) if dinst != null else "-", str(er.room_name) if er != null else "ninguna", str(ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source).valid) if dch != null and dch.sim_source >= 0 else "-"])
	print("datos de caminos en el lote cargado: %d bytes, sondas %d" % [int(ClassDB.class_call_static("OpenDouAcousticScene", "baked_path_data_size")), int(ClassDB.class_call_static("OpenDouAcousticScene", "probe_count"))])
	print("get_pathing goteo: ", ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else "-")
	# Experimento: rehornear los caminos en tiempo de ejecucion y volver a mirar.
	var t0b: int = Time.get_ticks_msec()
	var rebaked: bool = bool(ClassDB.class_call_static("OpenDouAcousticScene", "bake_paths", 1, 1.0, 0.1, 50.0, 100.0, 1))
	print("rebake en runtime: %s en %d ms, datos %d bytes" % [str(rebaked), Time.get_ticks_msec() - t0b, int(ClassDB.class_call_static("OpenDouAcousticScene", "baked_path_data_size"))])
	for i in range(60): await process_frame
	dinst = demo.drip.active_instance
	dch = manager.voice_pool.get_channel(dinst.assigned_channel_id) if dinst != null and dinst.assigned_channel_id >= 0 else null
	print("goteo tras rebake: ", ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else "-", " corridas ", ClassDB.class_call_static("OpenDouSimulator", "pathing_runs"))
	# Experimentos de caminos: (a) a la vista en el tramo A; (b) sondas a 1 m solo en la galeria.
	var S = "OpenDouAcousticScene"
	demo.drip.global_position = Vector3(36, -14.5, 11.5)
	demo.player.global_position = Vector3(30, -15.5, 11.5)
	for i in range(60): await process_frame
	dinst = demo.drip.active_instance
	dch = manager.voice_pool.get_channel(dinst.assigned_channel_id) if dinst != null and dinst.assigned_channel_id >= 0 else null
	print("(a) goteo A LA VISTA a 6 m: ", ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else "-")
	for bounds in [AABB(Vector3(18, -16, 10), Vector3(22, 3.4, 3)), AABB(Vector3(37, -16, -10), Vector3(3, 3.4, 20))]:
		var n2: int = int(ClassDB.class_call_static(S, "generate_probes", 2.0, 1.5, bounds))
		var n1: int = int(ClassDB.class_call_static(S, "generate_probes", 1.0, 1.5, bounds))
		print("(c) sondas en %s: %d a 2 m, %d a 1 m" % [str(bounds), n2, n1])
	var nall: int = int(ClassDB.class_call_static(S, "generate_probes", 1.0, 1.5, AABB(Vector3(17, -16, -11), Vector3(24, 3.4, 25))))
	var okb: bool = bool(ClassDB.class_call_static(S, "bake_paths", 1, 1.0, 0.1, 50.0, 100.0, 1))
	print("(b) sondas a 1 m en toda la galeria: %d, bake %s" % [nall, str(okb)])
	demo.drip.global_position = Vector3(38.5, -14.5, -2)
	demo.player.global_position = Vector3(24, -15.5, 11.5)
	for i in range(80): await process_frame
	dinst = demo.drip.active_instance
	dch = manager.voice_pool.get_channel(dinst.assigned_channel_id) if dinst != null and dinst.assigned_channel_id >= 0 else null
	print("(b) goteo tras el codo con sondas a 1 m: ", ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else "-", " adjuntas ", ClassDB.class_call_static("OpenDouSimulator", "probes_attached"), " corridas ", ClassDB.class_call_static("OpenDouSimulator", "pathing_runs"))
	# (d) evolucion en el tiempo tras el codo, con y sin validacion.
	for validate in [true, false]:
		ClassDB.class_call_static("OpenDouSimulator", "set_path_validation", validate)
		for k in range(4):
			for i in range(30): await process_frame
			dinst = demo.drip.active_instance
			dch = manager.voice_pool.get_channel(dinst.assigned_channel_id) if dinst != null and dinst.assigned_channel_id >= 0 else null
			var pth = ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else {}
			print("(d) validacion %s, +%d cuadros: gen %d, valido %s, dir %s, gain %.3f | goteo en %s, oyente %s, sim %d" % [str(validate), (k + 1) * 30, int(ClassDB.class_call_static("OpenDouSimulator", "pathing_generation", dch.sim_source)) if dch != null and dch.sim_source >= 0 else -1, str(pth.get("valid")), str(pth.get("direction")), float(pth.get("gain", 0.0)), str(dinst.emitter_position) if dinst != null else "-", str(manager.active_listener_position), dch.sim_source if dch != null else -9])
	ClassDB.class_call_static("OpenDouSimulator", "set_path_validation", true)
	# (e) a la vista, moviendo al oyente: cambia la salida?
	demo.drip.global_position = Vector3(36, -14.5, 11.5)
	for lp in [Vector3(30, -15.5, 11.5), Vector3(33, -15.5, 11.5), Vector3(27, -15.5, 11.5)]:
		demo.player.global_position = lp
		for i in range(60): await process_frame
		dinst = demo.drip.active_instance
		dch = manager.voice_pool.get_channel(dinst.assigned_channel_id) if dinst != null and dinst.assigned_channel_id >= 0 else null
		var pe = ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else {}
		print("(e) oyente %s -> gain %.3f (esperado %.3f), dir %s, eq %s" % [str(lp), float(pe.get("gain", 0.0)), 1.0 / (36.0 - lp.x), str(pe.get("direction")), str(pe.get("eq"))])
	# (f) el goteo en el tramo B pero VISIBLE desde el codo: oyente en (38.5, 11.5) mirando al tramo B
	demo.drip.global_position = Vector3(38.5, -14.5, -2)
	demo.player.global_position = Vector3(38.5, -15.5, 11.0)
	for i in range(80): await process_frame
	var pf = ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else {}
	print("(f) oyente en el codo, goteo a 13 m en linea recta -> %s" % str(pf))
	demo.player.global_position = Vector3(34, -15.5, 11.5)
	for i in range(80): await process_frame
	pf = ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else {}
	print("(f) oyente 4.5 m antes del codo -> %s" % str(pf))
	# (g) segmentos de camino que ve el depurador, en tres configuraciones
	ClassDB.class_call_static("OpenDouSimulator", "set_path_visualization", true)
	for cfg in [[Vector3(30, -15.5, 11.5), Vector3(36, -14.5, 11.5), "A la vista tramo A"], [Vector3(38.5, -15.5, 11.0), Vector3(38.5, -14.5, -2), "codo -> tramo B recto"], [Vector3(38.5, -15.5, 5.0), Vector3(38.5, -14.5, -2), "dentro del tramo B, 7 m"], [Vector3(24, -15.5, 11.5), Vector3(38.5, -14.5, -2), "tras el codo"]]:
		demo.player.global_position = cfg[0]
		demo.drip.global_position = cfg[1]
		for i in range(80): await process_frame
		var segs: PackedVector3Array = ClassDB.class_call_static("OpenDouSimulator", "get_path_segments")
		var pg = ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else {}
		var first: Array = []
		for i in range(0, mini(segs.size(), 8), 2):
			first.append("%s->%s" % [str(segs[i].snapped(Vector3(0.1, 0.1, 0.1))), str(segs[i + 1].snapped(Vector3(0.1, 0.1, 0.1)))])
		print("(g) %s: %d segmentos %s | gain %.3f dir %s" % [cfg[2], segs.size() / 2, str(first), float(pg.get("gain", 0.0)), str(pg.get("direction"))])
	ClassDB.class_call_static("OpenDouSimulator", "set_path_visualization", false)
	# (i) longitud del camino: el goteo cada vez mas adentro del tramo B; sondas a 2 m / 1.5 m
	ClassDB.class_call_static(S, "generate_probes", 2.0, 1.5, AABB(Vector3(17, -16, -11), Vector3(24, 3.4, 25)))
	ClassDB.class_call_static(S, "bake_paths", 1, 1.0, 0.1, 50.0, 100.0, 1)
	demo.player.global_position = Vector3(30, -15.5, 11.5)
	for dz in [9.0, 5.0, 0.0, -5.0]:
		demo.drip.global_position = Vector3(38.5, -14.5, dz)
		for i in range(80): await process_frame
		dinst = demo.drip.active_instance
		dch = manager.voice_pool.get_channel(dinst.assigned_channel_id) if dinst != null and dinst.assigned_channel_id >= 0 else null
		var pi_ = ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else {}
		print("(i) goteo en z=%.0f (camino ~%.0f m): gain %.3f dir %s eq %s" % [dz, 8.5 + (11.5 - dz), float(pi_.get("gain", 0.0)), str(pi_.get("direction")), str(pi_.get("eq"))])
	# (j) sondas a 2.0 m de altura (entre la fuente y el oido)
	ClassDB.class_call_static(S, "generate_probes", 2.0, 2.0, AABB(Vector3(17, -16, -11), Vector3(24, 3.4, 25)))
	ClassDB.class_call_static(S, "bake_paths", 1, 1.0, 0.1, 50.0, 100.0, 1)
	demo.drip.global_position = Vector3(38.5, -14.5, 5.0)
	for i in range(80): await process_frame
	var pj = ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else {}
	print("(j) sondas a 2.0 m, goteo en z=5: gain %.3f dir %s" % [float(pj.get("gain", 0.0)), str(pj.get("direction"))])
	# (h) altura de las sondas = altura del oido (2.5 m): cambia algo?
	for cfg in [[2.0, 2.5], [1.0, 2.5], [2.0, 1.5]]:
		var nh: int = int(ClassDB.class_call_static(S, "generate_probes", cfg[0], cfg[1], AABB(Vector3(17, -16, -11), Vector3(24, 3.4, 25))))
		ClassDB.class_call_static(S, "bake_paths", 1, 1.0, 0.1, 50.0, 100.0, 1)
		demo.player.global_position = Vector3(24, -15.5, 11.5)
		demo.drip.global_position = Vector3(38.5, -14.5, -2)
		for i in range(90): await process_frame
		dinst = demo.drip.active_instance
		dch = manager.voice_pool.get_channel(dinst.assigned_channel_id) if dinst != null and dinst.assigned_channel_id >= 0 else null
		var ph = ClassDB.class_call_static("OpenDouSimulator", "get_pathing", dch.sim_source) if dch != null and dch.sim_source >= 0 else {}
		print("(h) espaciado %.0f m altura %.1f m: %d sondas -> gain %.3f dir %s" % [cfg[0], cfg[1], nh, float(ph.get("gain", 0.0)), str(ph.get("direction"))])
	# --- compuerta: oclusion directa del aliviadero abierta/cerrada
	demo.player.global_position = Vector3(41.1, -15.5, 10)
	for open_state in [true, false, true]:
		demo.set_gate_open(open_state, true)
		for i in range(4): await physics_frame
		for i in range(30): await process_frame
		var sinst = demo.spillway.active_instance
		var sch = manager.voice_pool.get_channel(sinst.assigned_channel_id) if sinst != null and sinst.assigned_channel_id >= 0 else null
		var d = ClassDB.class_call_static("OpenDouSimulator", "get_direct", sch.sim_source) if sch != null and sch.sim_source >= 0 else PackedFloat32Array()
		print("compuerta abierta=%s: gate y %.1f, aliviadero canal %d sim %d occl %s, recomits %d, instancias %d" % [str(open_state), demo.gate.global_position.y, sinst.assigned_channel_id if sinst != null else -9, sch.sim_source if sch != null else -9, ("%.2f" % d[0]) if d.size() > 0 else "-", demo.get_node("AcousticBake").dynamic_update_count, int(ClassDB.class_call_static("OpenDouAcousticScene", "instanced_count"))])
	# --- medio subacuatico
	var probe = ProbeClass.new(); probe.attach_to_existing_bus(&"Master", 2.0)
	demo.player.global_position = Vector3(31, -15.5, 11.5)
	for i in range(30): await process_frame
	probe.drain(); var dry: Dictionary = await TB._capture(self, probe)
	demo.player.global_position = Vector3(31, -18.5, 17)
	for i in range(40): await process_frame
	var midx: int = AudioServer.get_bus_index("Master"); var chain: Array = []
	for e in range(AudioServer.get_bus_effect_count(midx)):
		var fx = AudioServer.get_bus_effect(midx, e); chain.append("%s%s%s" % [fx.get_class(), "*" if fx == probe._capture else "", (" %.0f" % fx.cutoff_hz) if fx is AudioEffectLowPassFilter else ""])
	print("Master antes de capturar sumergido: ", chain, " oyente ", manager.active_listener_position, " lpf medio ", manager.environment.medium_lowpass_hz)
	probe.drain(); var wet: Dictionary = await TB._capture(self, probe)
	for c in [["seco", dry], ["sumergido", wet]]:
		print("%s: agudos %.1f graves %.1f" % [c[0], linear_to_db(maxf(TB._band_energy_stereo(c[1], rate, 2000.0, 8000.0), 1e-12)), linear_to_db(maxf(TB._band_energy_stereo(c[1], rate, 100.0, 400.0), 1e-12))])
	print("efecto 0 activo: %s; db del filtro %d, resonancia %.2f, ganancia %.2f" % [str(AudioServer.is_bus_effect_enabled(midx, 0)), AudioServer.get_bus_effect(midx, 0).db, AudioServer.get_bus_effect(midx, 0).resonance, AudioServer.get_bus_effect(midx, 0).gain])
	# Experimento: un paso-bajo propio de 300 Hz a 24 dB/oct en la posicion 0 y otra medida.
	var mine := AudioEffectLowPassFilter.new(); mine.cutoff_hz = 300.0; mine.db = AudioEffectFilter.FILTER_24DB
	AudioServer.add_bus_effect(midx, mine, 0)
	for i in range(10): await process_frame
	probe.drain(); var wet2: Dictionary = await TB._capture(self, probe)
	print("con paso-bajo propio 300/24: agudos %.1f graves %.1f" % [linear_to_db(maxf(TB._band_energy_stereo(wet2, rate, 2000.0, 8000.0), 1e-12)), linear_to_db(maxf(TB._band_energy_stereo(wet2, rate, 100.0, 400.0), 1e-12))])
	# Y una captura NUEVA justo despues del filtro del medio (indice 2).
	var cap2 := AudioEffectCapture.new(); cap2.buffer_length = 2.0
	AudioServer.add_bus_effect(midx, cap2, 2)
	for i in range(10): await process_frame
	cap2.clear_buffer()
	var l := PackedFloat32Array(); var r := PackedFloat32Array()
	while l.size() < 8192:
		await process_frame
		var n: int = cap2.get_frames_available()
		if n > 0:
			for v in cap2.get_buffer(n):
				l.append(v.x); r.append(v.y)
	var wet3 := {"left": l, "right": r}
	print("captura en indice 2: agudos %.1f graves %.1f" % [linear_to_db(maxf(TB._band_energy_stereo(wet3, rate, 2000.0, 8000.0), 1e-12)), linear_to_db(maxf(TB._band_energy_stereo(wet3, rate, 100.0, 400.0), 1e-12))])
	# Que buses suenan: pico por bus.
	var peaks: Array = []
	for b in range(AudioServer.bus_count):
		var pk: float = AudioServer.get_bus_peak_volume_left_db(b, 0)
		if pk > -60.0: peaks.append("%s %.0f" % [AudioServer.get_bus_name(b), pk])
	print("buses sonando: ", peaks)
	probe.teardown()
	print("pico reverb nave: %.1f dB (bus %s)" % [AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index(String(demo.rooms[&"Nave"].get_assigned_reverb_bus())), 0), String(demo.rooms[&"Nave"].get_assigned_reverb_bus())])
	# --- oido del vigilante: rayo y sonoridad
	var yard = demo.get_node("GuardYard"); yard.global_position = Vector3(0, -15.5, 27)
	var ear: Vector3 = yard.get_node("Ear").global_position
	for pos in [Vector3(4, -15.5, 27), Vector3(12, -15.5, 8), Vector3(-22, -15.5, 27)]:
		demo.player.global_position = pos
		for i in range(3): await process_frame
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.1, 0), ear, 1)
		var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(q)
		demo.player.rig.step()
		await process_frame
		var found: String = "-"
		for e in manager.get_loudness_at(ear, root.get_world_3d()):
			if e.event_name == &"Footstep":
				found = "%.1f dB" % e.loudness_db
		print("jugador en %s: rayo choca %s; pisada oida a %s" % [str(pos), str(hit.get("collider").name) if not hit.is_empty() else "nada", found])
	manager.stop_all(); root.remove_child(demo); demo.free()
	quit()
