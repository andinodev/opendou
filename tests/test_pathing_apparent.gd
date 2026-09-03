class_name TestPathingApparent
extends RefCounted

## Fase 14: los caminos de Steam Audio (sondas) como origen aparente de la voz. La L de
## TestProbesBake: oyente en la sala oeste, voz en la este, tabique entre ambos y hueco al norte.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const TestProbesBakeClass = preload("res://tests/test_probes_bake.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

const GAP := Vector3(0.0, 1.5, 2.0)

static func _angle_deg(a: Vector3, b: Vector3) -> float:
	if a.length() < 1e-6 or b.length() < 1e-6:
		return 180.0
	return rad_to_deg(a.normalized().angle_to(b.normalized()))

## Una corrida: L, sondas, manager steam_audio, voz. Devuelve medidas.
static func _run(tree: SceneTree, listener: Vector3, emitter: Vector3, pathing_on: bool, with_portal: bool) -> Dictionary:
	var TP = load("res://tests/test_backend_parity.gd")
	var TB = load("res://tests/test_binaural.gd")
	var previous_backend = ProjectSettings.get_setting("opendou/spatial/backend", "auto")
	var bodies: Array = TestProbesBakeClass.make_l_rooms(tree)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	bake.auto_load_probes = false
	bake.probe_spacing_m = 1.0
	bake.probes_path = "user://opendou_test_pathing.probes"
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	var probes: Dictionary = bake.bake_probes()
	var manager = TP.make_manager(tree, "steam_audio")
	manager.pathing_enabled = pathing_on
	var cam: Camera3D = TP.make_listener_camera(tree)
	cam.global_position = listener
	TP.ensure_bus()
	if with_portal:
		var AudioRoomClass = load("res://addons/opendou/runtime/spatial/audio_room.gd")
		var AudioPortalClass = load("res://addons/opendou/runtime/spatial/audio_portal.gd")
		var ac = manager.spatial_acoustics
		var west = AudioRoomClass.new()
		west.room_name = &"Oeste"
		west.set_bounds(AABB(Vector3(-6, 0, -3), Vector3(6, 3, 6)))
		ac.register_room(west)
		var east = AudioRoomClass.new()
		east.room_name = &"Este"
		east.set_bounds(AABB(Vector3(0, 0, -3), Vector3(6, 3, 6)))
		ac.register_room(east)
		ac.register_portal(AudioPortalClass.new(&"Hueco", &"Oeste", &"Este", GAP, 1.0))
	manager.set_listener_position(listener)
	var debugger = null
	if pathing_on and not with_portal:
		debugger = load("res://addons/opendou/nodes/opendou_acoustic_debugger_3d.gd").new()
		debugger.show_paths = true
		debugger.show_sound_field_mesh = false
		tree.root.add_child(debugger)
	var probe = load("res://tests/support/audio_probe.gd").new()
	probe.attach_to_existing_bus(TP.BUS, 2.0)
	var def = load("res://addons/opendou/resources/audio_event_def.gd").new(&"PathVoice", TB._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = TP.BUS
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(emitter)
	var out := {"valid": false, "direction": Vector3.ZERO, "sh": PackedFloat32Array(), "eq": Vector3.ONE, "gain": 0.0, "frames": 0, "probes": int(probes.get("probe_count", 0))}
	var ch = null
	for i in range(240):
		await tree.process_frame
		probe.drain()
		out.frames = i + 1
		ch = manager.voice_pool.get_channel(inst.assigned_channel_id) if inst.assigned_channel_id >= 0 else null
		if ch != null and ch.sim_source >= 0 and pathing_on and not with_portal:
			var p: Dictionary = ClassDB.class_call_static("OpenDouSimulator", "get_pathing", ch.sim_source)
			if bool(p.valid) and i >= 30:
				out.valid = true
				out.direction = p.direction
				out.sh = p.sh
				out.eq = p.eq
				out.gain = float(p.gain)
				break
		elif i >= 60:
			break
	# Deja que el destino aparente se asiente y captura el nivel.
	for i in range(20):
		await tree.process_frame
		probe.drain()
	out["direct"] = ch != null and ch.uses_direct_effect()
	out["segments"] = debugger.path_segment_count() if debugger != null else 0
	out["runs"] = int(ClassDB.class_call_static("OpenDouSimulator", "pathing_runs"))
	out["thread"] = bool(ClassDB.class_call_static("OpenDouSimulator", "is_reflections_running"))
	out["target"] = inst.target_apparent_position
	out["pathing_active"] = inst.pathing_active
	out["room_path_active"] = inst.room_path_active
	var cap: Dictionary = await TB._capture(tree, probe)
	out["rms"] = TB._rms_db(cap)
	inst.stop()
	probe.teardown()
	if debugger != null:
		tree.root.remove_child(debugger); debugger.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	tree.root.remove_child(bake); bake.free()
	for b in bodies:
		tree.root.remove_child(b); b.free()
	if ClassDB.class_exists("OpenDouSimulator"):
		ClassDB.class_call_static("OpenDouSimulator", "shutdown")
		ClassDB.class_call_static("OpenDouAcousticScene", "clear")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://opendou_test_pathing.probes"))
	ProjectSettings.set_setting("opendou/spatial/backend", previous_backend)
	return out

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("pathing_apparent")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouSimulator"):
		print("[OpenDou] extension nativa AUSENTE: caminos omitidos")
		return a
	# A la vista, a traves del hueco (B10: la convencion de los coeficientes).
	var l_vis := Vector3(-3, 1.5, 2.5)
	var e_vis := Vector3(3, 1.5, 2.5)
	var vis: Dictionary = await _run(tree, l_vis, e_vis, true, false)
	print("[OpenDou] caminos a la vista: valido %s en %d cuadros, sh %s, dir %s, real %s, eq %s, gain %.3f, rms %.1f dB (sondas %d, corridas %d, hilo %s)" % [str(vis.valid), int(vis.frames), str(vis.sh), str(vis.direction), str((e_vis - l_vis).normalized()), str(vis.eq), float(vis.gain), float(vis.rms), int(vis.probes), int(vis.runs), str(vis.thread)])
	a.ok(bool(vis.direct), "la voz tiene fuente del simulador")
	a.ok(bool(vis.valid), "a la vista hay camino")
	a.lt(_angle_deg(vis.direction, e_vis - l_vis), 10.0, "a la vista, la direccion del camino es la real (B10)")
	# Tras el tabique: el camino sale por el hueco.
	var l_occ := Vector3(-3, 1.5, -2)
	var e_occ := Vector3(3, 1.5, -2)
	var occ: Dictionary = await _run(tree, l_occ, e_occ, true, false)
	var to_gap: Vector3 = GAP - l_occ
	var to_real: Vector3 = e_occ - l_occ
	var apparent: Vector3 = Vector3(occ.target) - l_occ
	print("[OpenDou] caminos tras el tabique: valido %s, dir %s (al hueco %.1f grados, al emisor %.1f), aparente %s (%.1f / %.1f), eq %s, gain %.3f, rms %.1f dB" % [str(occ.valid), str(occ.direction), _angle_deg(occ.direction, to_gap), _angle_deg(occ.direction, to_real), str(occ.target), _angle_deg(apparent, to_gap), _angle_deg(apparent, to_real), str(occ.eq), float(occ.gain), float(occ.rms)])
	a.ok(bool(occ.valid), "tras el tabique hay camino")
	a.ok(bool(occ.pathing_active), "el camino gobierna el origen aparente")
	a.lt(_angle_deg(apparent, to_gap), 25.0, "el origen aparente apunta al hueco")
	a.gt(_angle_deg(apparent, to_real), 30.0, "y no al emisor real")
	a.lt(float(occ.rms), float(vis.rms) - 1.0, "rodeando el tabique llega menos que a la vista")
	print("[OpenDou] caminos en el depurador: %d segmentos" % int(occ.segments))
	a.ok(int(occ.segments) >= 1, "el depurador dibuja al menos un segmento de camino")
	var off: Dictionary = await _run(tree, l_occ, e_occ, false, false)
	print("[OpenDou] caminos apagados: rms %.1f dB, aparente %s, activo %s" % [float(off.rms), str(off.target), str(off.pathing_active)])
	a.ok(not bool(off.pathing_active), "con pathing_enabled = false el origen es el emisor")
	a.gt(float(occ.rms), float(off.rms) + 3.0, "con camino llega mas que con solo la oclusion directa")
	# El grafo autorado manda: con un portal en el hueco, la posicion aparente es la del portal.
	var portal: Dictionary = await _run(tree, l_occ, e_occ, true, true)
	print("[OpenDou] caminos con portal: aparente %s, room_path %s, pathing %s, rms %.1f dB" % [str(portal.target), str(portal.room_path_active), str(portal.pathing_active), float(portal.rms)])
	a.ok(bool(portal.room_path_active) and not bool(portal.pathing_active), "el portal gobierna y las sondas callan")
	a.lt(Vector3(portal.target).distance_to(GAP), 1.0, "el origen aparente es el portal")
	await tree.create_timer(0.3).timeout
	return a
