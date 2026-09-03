class_name TestPositionProvider
extends RefCounted

## Fase 15 (C3): spline y multiposicion entran al sistema de voces como proveedores de posicion.
## La voz es del pool (no el nodo) y suena en el punto mas cercano al oyente, en ambos backends.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const SplineScript = preload("res://addons/opendou/nodes/opendou_spline_emitter_3d.gd")
const MultiScript = preload("res://addons/opendou/nodes/opendou_multi_position_emitter_3d.gd")

static func _settle(tree: SceneTree, frames: int) -> void:
	for i in range(frames):
		await tree.process_frame

static func _run_backend(tree: SceneTree, a: OpenDouAssert, backend: String) -> void:
	var previous = ProjectSettings.get_setting("opendou/spatial/backend", "auto")
	var manager = TestParityClass.make_manager(tree, backend)
	var cam: Camera3D = TestParityClass.make_listener_camera(tree)
	TestParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(TestParityClass.BUS, 2.0)
	var noise: AudioStreamWAV = TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate()))
	# Spline recto de (-20, 0, -3) a (20, 0, -3), nodo en el origen, oyente en el origen.
	var spline = SplineScript.new()
	var curve := Curve3D.new()
	curve.add_point(Vector3(-20, 0, -3))
	curve.add_point(Vector3(20, 0, -3))
	spline.curve = curve
	spline.stream = noise
	spline.bus = String(TestParityClass.BUS)
	spline.max_virtual_distance = 60.0
	spline.set_event_manager(manager)
	tree.root.add_child(spline)
	cam.global_position = Vector3.ZERO
	manager.set_listener_position(Vector3.ZERO)
	await _settle(tree, 10)
	var inst = spline.active_instance
	a.ok(inst != null and inst.is_playing(), "%s: el spline publica una voz por el manager" % backend)
	if inst != null:
		var ch = manager.voice_pool.get_channel(inst.assigned_channel_id) if inst.assigned_channel_id >= 0 else null
		a.ok(ch != null and ch.get_player() != spline, "%s: la voz es del pool, no el nodo" % backend)
		a.ok(not spline.playing, "%s: el nodo no suena por su cuenta" % backend)
		a.lt(inst.emitter_position.distance_to(Vector3(0, 0, -3)), 0.2, "%s: suena en el punto mas cercano de la curva (%s)" % [backend, str(inst.emitter_position)])
		cam.global_position = Vector3(10, 0, 0)
		manager.set_listener_position(Vector3(10, 0, 0))
		await _settle(tree, 10)
		a.lt(inst.emitter_position.distance_to(Vector3(10, 0, -3)), 0.2, "%s: y sigue al oyente a lo largo de la curva (%s)" % [backend, str(inst.emitter_position)])
		probe.drain()
		var cap: Dictionary = await TestBinauralClass._capture(tree, probe)
		var rms: float = TestBinauralClass._rms_db(cap)
		print("[OpenDou] proveedor (%s): spline en %s, RMS %.1f dB" % [backend, str(inst.emitter_position), rms])
		a.gt(rms, -40.0, "%s: la voz del spline se oye en su bus" % backend)
	spline.stop_event()
	tree.root.remove_child(spline); spline.free()
	# Multiposicion: dos puntos, oyente cerca del segundo.
	var multi = MultiScript.new()
	var pts: Array[Vector3] = [Vector3(-5, 0, -5), Vector3(5, 0, -5)]
	multi.emission_points = pts
	multi.smooth_position_lag = 0.0
	multi.stream = noise
	multi.bus = String(TestParityClass.BUS)
	multi.set_event_manager(manager)
	tree.root.add_child(multi)
	cam.global_position = Vector3(4, 0, 0)
	manager.set_listener_position(Vector3(4, 0, 0))
	await _settle(tree, 10)
	var minst = multi.active_instance
	a.ok(minst != null and minst.is_playing(), "%s: el multiposicion publica una voz" % backend)
	if minst != null:
		a.lt(minst.emitter_position.distance_to(Vector3(5, 0, -5)), 0.2, "%s: suena en el punto mas cercano (%s)" % [backend, str(minst.emitter_position)])
		a.lt(multi.global_position.length(), 0.01, "%s: el nodo no se mueve" % backend)
	multi.stop_event()
	tree.root.remove_child(multi); multi.free()
	await _settle(tree, 3)
	probe.teardown()
	manager.stop_all()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("position_provider")
	await _run_backend(tree, a, "godot")
	if ClassDB.class_exists("OpenDouSpatialStream"):
		await _run_backend(tree, a, "steam_audio")
	await tree.create_timer(0.3).timeout
	return a
