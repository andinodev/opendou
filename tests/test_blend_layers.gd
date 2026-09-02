class_name TestBlendLayers
extends RefCounted

## Fase 11: un AudioBlendContainer cruza capas EN VIVO por RTPC. Hasta esta fase el runtime
## reproducia solo la primera voz resuelta y tiraba los desplazamientos.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioBlendContainerClass = preload("res://addons/opendou/resources/containers/audio_blend_container.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func _ramp(from_db: float, to_db: float) -> Curve:
	var c := Curve.new()
	c.min_value = -60.0
	c.max_value = 0.0
	c.add_point(Vector2(0.0, from_db))
	c.add_point(Vector2(1.0, to_db))
	return c

static func _bands(tree: SceneTree, probe) -> Array:
	probe._capture.clear_buffer()
	var cap := await TestBinauralClass._capture(tree, probe)
	var rate: float = AudioServer.get_mix_rate()
	var low: float = linear_to_db(maxf(TestBinauralClass._band_energy_stereo(cap, rate, 100.0, 400.0), 1e-12))
	var high: float = linear_to_db(maxf(TestBinauralClass._band_energy_stereo(cap, rate, 1500.0, 2500.0), 1e-12))
	return [low, high]

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("blend_layers")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam := TestParityClass.make_listener_camera(tree)
	TestParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(TestParityClass.BUS, 2.0)
	var tone_src = load("res://tests/test_emitter_physics.gd")
	var blend = AudioBlendContainerClass.new(&"Mix", 0.0, 1.0)
	blend.add_layer(AudioPhysicalNodeClass.new(tone_src._tone(200.0, 1.0)), _ramp(0.0, -60.0))
	blend.add_layer(AudioPhysicalNodeClass.new(tone_src._tone(2000.0, 1.0)), _ramp(-60.0, 0.0))
	var def = AudioEventDefClass.new(&"Blend")
	def.root_container = blend
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = TestParityClass.BUS
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(0, 0, -2))
	inst.set_parameter(&"Mix", 0.0, true)
	for i in range(20):
		await tree.process_frame
	a.eq(inst.layer_channel_ids.size(), 1, "la segunda capa tiene su propio canal")
	a.ok(inst.live_blend, "el arbol es determinista: cruce en vivo")
	a.eq(manager.voice_pool.get_active_physical_count(), 2, "dos canales fisicos ocupados")
	var at0: Array = await _bands(tree, probe)
	inst.set_parameter(&"Mix", 1.0, true)
	for i in range(20):
		await tree.process_frame
	var at1: Array = await _bands(tree, probe)
	inst.set_parameter(&"Mix", 0.5, true)
	for i in range(20):
		await tree.process_frame
	var mid: Array = await _bands(tree, probe)
	print("[OpenDou] blend en vivo: Mix 0 -> grave %.1f / agudo %.1f dB; Mix 1 -> %.1f / %.1f; Mix 0.5 -> %.1f / %.1f" % [at0[0], at0[1], at1[0], at1[1], mid[0], mid[1]])
	a.gt(at0[0] - at0[1], 20.0, "con Mix 0 manda la capa grave")
	a.gt(at1[1] - at1[0], 20.0, "con Mix 1 manda la aguda")
	# A 0.5 las dos suenan y las dos bajaron: cada banda queda por encima de su suelo (la
	# capa a -60) y por debajo de su solo. La energia de banda de un tono de 200 Hz y uno de
	# 2 kHz no es comparable entre si (shelf de distancia, ancho de banda).
	a.gt(mid[0], at1[0] + 6.0, "con Mix 0.5 la grave sigue sonando (%.1f sobre su suelo %.1f)" % [mid[0], at1[0]])
	a.gt(mid[1], at0[1] + 6.0, "y la aguda tambien (%.1f sobre su suelo %.1f)" % [mid[1], at0[1]])
	a.lt(mid[0], at0[0] - 15.0, "la grave bajo respecto a su solo")
	a.lt(mid[1], at1[1] - 15.0, "y la aguda tambien")
	inst.stop()
	for i in range(5):
		await tree.process_frame
	a.eq(manager.voice_pool.get_active_physical_count(), 0, "al parar se sueltan los dos canales")
	# Un contenedor aleatorio NO se re-resuelve cada cuadro: sus capas quedan fijas.
	var rnd = AudioRandomContainerClass.new()
	rnd.add_child_node(AudioPhysicalNodeClass.new(tone_src._tone(300.0, 0.5)))
	rnd.add_child_node(AudioPhysicalNodeClass.new(tone_src._tone(600.0, 0.5)))
	var rdef = AudioEventDefClass.new(&"Rnd")
	rdef.root_container = rnd
	rdef.stream_length = 0.5
	rdef.target_bus = TestParityClass.BUS
	manager.register_event_definition(rdef)
	var rinst = manager.post_event(rdef, null)
	rinst.set_position(Vector3(0, 0, -2))
	for i in range(5):
		await tree.process_frame
	a.ok(not rinst.live_blend, "un contenedor aleatorio no cruza en vivo")
	rinst.stop()
	probe.teardown()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a
