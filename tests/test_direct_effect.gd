class_name TestDirectEffect
extends RefCounted

## Fase 12: el simulador de Steam Audio ve el bake (oclusion, transmision por material, aire).

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

static func _sim(method: String, a1 = null, a2 = null, a3 = null, a4 = null, a5 = null, a6 = null, a7 = null) -> Variant:
	if a1 == null:
		return ClassDB.class_call_static("OpenDouSimulator", method)
	if a2 == null:
		return ClassDB.class_call_static("OpenDouSimulator", method, a1)
	if a4 == null:
		return ClassDB.class_call_static("OpenDouSimulator", method, a1, a2, a3)
	return ClassDB.class_call_static("OpenDouSimulator", method, a1, a2, a3, a4, a5, a6, a7)

static func _scene(method: String) -> Variant:
	return ClassDB.class_call_static("OpenDouAcousticScene", method)

## Escena con un muro de `material` entre la fuente (0,1.5,-6) y el oyente (0,1.5,0).
static func _direct_behind(tree: SceneTree, material: StringName) -> PackedFloat32Array:
	var wall := TestSteamSceneClass.make_wall(tree, Vector3(0, 1.5, -3), material)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	_sim("configure", 8, 16, 2)
	var h: int = int(_sim("create_source"))
	_sim("set_listener", Vector3(0, 1.5, 0), Vector3(0, 0, -1), Vector3.UP)
	_sim("set_source_inputs", h, Vector3(0, 1.5, -6), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5)
	_sim("run_direct")
	var out: PackedFloat32Array = _sim("get_direct", h)
	_sim("release_source", h)
	_sim("shutdown")
	tree.root.remove_child(bake); bake.free()
	tree.root.remove_child(wall); wall.free()
	_scene("clear")
	return out

static func run_simulator_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("direct_simulator")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouSimulator"):
		print("[OpenDou] extension nativa AUSENTE: simulador omitido")
		return a
	var glass: PackedFloat32Array = _direct_behind(tree, &"Glass")
	var concrete: PackedFloat32Array = _direct_behind(tree, &"Concrete")
	print("[OpenDou] efecto directo: tras Glass occl=%.2f tr=(%.3f %.3f %.3f) | tras Concrete occl=%.2f tr=(%.3f %.3f %.3f)" % [glass[0], glass[1], glass[2], glass[3], concrete[0], concrete[1], concrete[2], concrete[3]])
	a.lt(glass[0], 0.3, "el muro de cristal ocluye (occlusion < 0.3)")
	a.lt(concrete[0], 0.3, "y el de hormigon tambien")
	a.gt(glass[1], concrete[1] + 0.02, "el cristal transmite mas graves que el hormigon")
	a.gt(glass[3], concrete[3], "y mas agudos")
	# Sin muro: nada ocluye; a 200 m el aire come la banda alta. Hace falta ALGUNA geometria
	# para que la escena exista: un suelo lejos del camino.
	var floor := TestSteamSceneClass.make_wall(tree, Vector3(0, -20, 0), &"Concrete")
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	_sim("configure", 8, 16, 2)
	var h: int = int(_sim("create_source"))
	_sim("set_listener", Vector3.ZERO, Vector3(0, 0, -1), Vector3.UP)
	_sim("set_source_inputs", h, Vector3(0, 0, -10), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5)
	_sim("run_direct")
	var near: PackedFloat32Array = _sim("get_direct", h)
	_sim("set_source_inputs", h, Vector3(0, 0, -200), Vector3(0, 0, 1), Vector3.UP, 0.0, 1.0, 0.5)
	_sim("run_direct")
	var far: PackedFloat32Array = _sim("get_direct", h)
	print("[OpenDou] aire: 10 m (%.3f %.3f %.3f), 200 m (%.3f %.3f %.3f); occl sin muro %.2f; run_direct %d us" % [near[4], near[5], near[6], far[4], far[5], far[6], near[0], int(_sim("last_run_usec"))])
	a.gt(near[0], 0.95, "sin muro no hay oclusion")
	a.lt(far[6], far[4], "a 200 m el aire absorbe mas la banda alta que la baja")
	a.lt(far[6], near[6], "y mas que a 10 m")
	_sim("release_source", h)
	_sim("shutdown")
	tree.root.remove_child(bake); bake.free()
	tree.root.remove_child(floor); floor.free()
	_scene("clear")
	return a

static func run_stream_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("direct_stream")
	if not TestSteamSceneClass._native():
		return a
	var TB = load("res://tests/test_binaural.gd")
	var probe = load("res://tests/support/audio_probe.gd").new()
	var bus := &"DirectProbe"
	if AudioServer.get_bus_index(String(bus)) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, String(bus))
		AudioServer.set_bus_send(idx, "Master")
	probe.attach_to_existing_bus(bus, 2.0)
	var stream = ClassDB.instantiate("OpenDouSpatialStream")
	stream.source = TB._periodic_noise(int(AudioServer.get_mix_rate()))
	# spatialize = false salta toda la cadena (tambien el efecto): se pasa por ella con la mezcla
	# HRTF a 0, que no colorea, y la misma direccion en todas las medidas.
	stream.spatialize = true
	stream.spatial_blend = 0.0
	stream.direction = Vector3(0, 0, -1)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = String(bus)
	player.volume_db = -6.0
	tree.root.add_child(player)
	player.play()
	var rate: float = AudioServer.get_mix_rate()
	for i in range(20):
		await tree.process_frame
		probe.drain()
	var base: Dictionary = await TB._capture(tree, probe)
	var base_hi: float = linear_to_db(maxf(TB._band_energy_stereo(base, rate, 4000.0, 8000.0), 1e-12))
	var base_lo: float = linear_to_db(maxf(TB._band_energy_stereo(base, rate, 200.0, 800.0), 1e-12))
	# Cristal: oclusion parcial, y de lo que pasa, pasa mas la banda alta que en el hormigon.
	stream.set_direct_params(true, 0.2, Vector3(0.06, 0.044, 0.5), Vector3(1, 1, 1), 1.0)
	var glass: Dictionary = await TB._capture(tree, probe)
	var glass_hi: float = linear_to_db(maxf(TB._band_energy_stereo(glass, rate, 4000.0, 8000.0), 1e-12))
	var glass_lo: float = linear_to_db(maxf(TB._band_energy_stereo(glass, rate, 200.0, 800.0), 1e-12))
	stream.set_direct_params(true, 0.2, Vector3(0.015, 0.002, 0.001), Vector3(1, 1, 1), 1.0)
	var concrete: Dictionary = await TB._capture(tree, probe)
	var concrete_hi: float = linear_to_db(maxf(TB._band_energy_stereo(concrete, rate, 4000.0, 8000.0), 1e-12))
	stream.set_direct_params(false, 1.0, Vector3(1, 1, 1), Vector3(1, 1, 1), 1.0)
	var off: Dictionary = await TB._capture(tree, probe)
	var off_hi: float = linear_to_db(maxf(TB._band_energy_stereo(off, rate, 4000.0, 8000.0), 1e-12))
	print("[OpenDou] efecto directo en el stream: base %.1f/%.1f, cristal %.1f/%.1f, hormigon agudos %.1f, apagado %.1f" % [base_lo, base_hi, glass_lo, glass_hi, concrete_hi, off_hi])
	a.lt(glass_hi, base_hi - 3.0, "tras el cristal (occl 0.2) cae la banda alta")
	a.gt(glass_hi, concrete_hi + 6.0, "el cristal deja pasar al menos 6 dB mas de agudos que el hormigon")
	a.approx(off_hi, base_hi, "apagado, igual que sin efecto", 1.0)
	player.stop()
	tree.root.remove_child(player); player.free()
	probe.teardown()
	return a

## Voz completa en steam_audio: bake en el arbol, muro entre voz y oyente, medida en el bus de sonda.
static func _voice_band(tree: SceneTree, wall_material: StringName, bake_on: bool, dipole: float = 0.0, forward: Vector3 = Vector3(0, 0, 1)) -> Dictionary:
	var TP = load("res://tests/test_backend_parity.gd")
	var TB = load("res://tests/test_binaural.gd")
	var previous_backend = ProjectSettings.get_setting("opendou/spatial/backend", "auto")
	var manager = TP.make_manager(tree, "steam_audio")
	var cam: Camera3D = TP.make_listener_camera(tree)
	TP.ensure_bus()
	var wall = null
	if wall_material != &"":
		wall = TestSteamSceneClass.make_wall(tree, Vector3(0, 0, -3), wall_material)
	# Con bake pero sin muro hace falta ALGUNA geometria para que exista la escena: un suelo lejos.
	var floor = TestSteamSceneClass.make_wall(tree, Vector3(0, -20, 0), &"Concrete") if bake_on else null
	var bake = null
	if bake_on:
		bake = BakeScript.new()
		bake.auto_bake_on_ready = false
		tree.root.add_child(bake)
		bake.bake_geometry(tree.root)
	var probe = load("res://tests/support/audio_probe.gd").new()
	probe.attach_to_existing_bus(TP.BUS, 2.0)
	var def = load("res://addons/opendou/resources/audio_event_def.gd").new(&"DirectVoice", TB._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = TP.BUS
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(0, 0, -6))
	inst.set_orientation(forward)
	inst.directivity_dipole_weight = dipole
	inst.directivity_power = 1.0
	for i in range(40):
		await tree.process_frame
		probe.drain()
	var ch = manager.voice_pool.get_channel(inst.assigned_channel_id) if inst.assigned_channel_id >= 0 else null
	var cap: Dictionary = await TB._capture(tree, probe)
	var rate: float = AudioServer.get_mix_rate()
	var out := {
		"hi": linear_to_db(maxf(TB._band_energy_stereo(cap, rate, 4000.0, 8000.0), 1e-12)),
		"lo": linear_to_db(maxf(TB._band_energy_stereo(cap, rate, 200.0, 800.0), 1e-12)),
		"rms": TB._rms_db(cap),
		"direct": ch != null and ch.uses_direct_effect(),
		"simulated": manager.occlusion_scheduler.simulated_this_frame,
	}
	inst.stop()
	probe.teardown()
	if bake != null:
		tree.root.remove_child(bake); bake.free()
	if wall != null:
		tree.root.remove_child(wall); wall.free()
	if floor != null:
		tree.root.remove_child(floor); floor.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	if ClassDB.class_exists("OpenDouSimulator"):
		ClassDB.class_call_static("OpenDouSimulator", "shutdown")
		ClassDB.class_call_static("OpenDouAcousticScene", "clear")
	ProjectSettings.set_setting("opendou/spatial/backend", previous_backend)
	return out

static func run_voice_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("direct_voice")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouSimulator"):
		return a
	var glass: Dictionary = await _voice_band(tree, &"Glass", true)
	var concrete: Dictionary = await _voice_band(tree, &"Concrete", true)
	var open_bake: Dictionary = await _voice_band(tree, &"", true)
	var no_bake: Dictionary = await _voice_band(tree, &"", false)
	print("[OpenDou] voz con efecto directo: cristal hi %.1f lo %.1f | hormigon hi %.1f lo %.1f | sin muro %.1f/%.1f (fuente %s, simuladas %d) | sin bake %.1f/%.1f (fuente %s)" % [glass.hi, glass.lo, concrete.hi, concrete.lo, open_bake.hi, open_bake.lo, str(open_bake.direct), int(open_bake.simulated), no_bake.hi, no_bake.lo, str(no_bake.direct)])
	a.ok(glass.direct and concrete.direct, "las voces cercanas tienen fuente del simulador")
	a.eq(int(open_bake.simulated), 1, "una fuente simulada por cuadro")
	a.gt(glass.hi, concrete.hi + 6.0, "tras el cristal pasan al menos 6 dB mas de agudos que tras el hormigon")
	a.lt(glass.hi, open_bake.hi - 3.0, "y menos que sin muro")
	a.ok(not no_bake.direct, "sin bake no hay fuente: rayo de Godot como siempre")
	# Sin bake, el muro fisico ocluye por rayo; sin muro ni bake, igual que sin muro con bake (+-1.5 dB).
	a.approx(open_bake.hi, no_bake.hi, "sin muro, con y sin escena suenan igual", 2.0)
	# Directividad nativa (cardioide, w = 0.5): de espaldas al menos 10 dB menos; de lado ~-6 dB,
	# no -12: la GDScript no se suma encima.
	var front: Dictionary = await _voice_band(tree, &"", true, 0.5, Vector3(0, 0, 1))
	var back: Dictionary = await _voice_band(tree, &"", true, 0.5, Vector3(0, 0, -1))
	var side: Dictionary = await _voice_band(tree, &"", true, 0.5, Vector3(1, 0, 0))
	print("[OpenDou] directividad nativa (cardioide): frente %.1f dB, lado %.1f dB, espalda %.1f dB" % [front.rms, side.rms, back.rms])
	a.lt(back.rms, front.rms - 10.0, "de espaldas, al menos 10 dB menos")
	a.ok(front.rms - side.rms > 4.0 and front.rms - side.rms < 9.5, "de lado, unos 6 dB menos (una sola directividad, no dos): %.1f" % (front.rms - side.rms))
	return a
