class_name TestSplineFlow
extends RefCounted

## Fase 9: el flujo del spline entra en su doppler propio. El spline sigue fuera del sistema
## de voces (observacion 47), asi que esto es todo lo que gana en esta fase.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spline_flow")
	var SplineScript = load("res://addons/opendou/nodes/opendou_spline_emitter_3d.gd")
	var spline = SplineScript.new()
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, 0))
	c.add_point(Vector3(100, 0, 0))   # el rio corre hacia +X
	spline.curve = c
	spline.enable_doppler = true
	spline.auto_play_event = false
	tree.root.add_child(spline)
	spline.reanchor()
	# Oyente pasado el final del rio (+X), con componente a lo largo de la corriente.
	var downstream := Vector3(120, 0, 5)
	spline.flow_speed_mps = 20.0
	var flow: Vector3 = spline.get_flow_velocity_at(downstream)
	a.ok(flow.is_equal_approx(Vector3(20, 0, 0)), "la velocidad de flujo es la tangente por la velocidad")
	a.ok(spline.resolve_flow_velocity(downstream).is_equal_approx(flow), "y es lo que el proveedor entrega a la voz")
	# Fase 15: el doppler ya no lo calcula el nodo sino la voz del pool con flow_velocity del
	# proveedor. Se mide en el backend godot (en steam_audio el retardo por distancia lo hace).
	var previous = ProjectSettings.get_setting("opendou/spatial/backend", "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam: Camera3D = TestParityClass.make_listener_camera(tree)
	cam.global_position = downstream
	manager.set_listener_position(downstream)
	TestParityClass.ensure_bus()
	spline.stream = load("res://tests/test_binaural.gd")._periodic_noise(int(AudioServer.get_mix_rate()))
	spline.bus = String(TestParityClass.BUS)
	spline.max_virtual_distance = 200.0
	spline.set_event_manager(manager)
	spline.play_event()
	var inst = spline.active_instance
	a.ok(inst != null, "el spline publica su voz")
	var pitch_down: float = 1.0
	var pitch_up: float = 1.0
	var pitch_none: float = 1.0
	if inst != null:
		for i in range(40):
			await tree.process_frame
		pitch_down = inst.doppler_pitch
		spline.flow_speed_mps = -20.0
		for i in range(40):
			await tree.process_frame
		pitch_up = inst.doppler_pitch
		spline.flow_speed_mps = 0.0
		for i in range(40):
			await tree.process_frame
		pitch_none = inst.doppler_pitch
	print("[OpenDou] flujo del spline (voz del pool): hacia el oyente %.3f, alejandose %.3f, sin flujo %.3f" % [pitch_down, pitch_up, pitch_none])
	a.gt(pitch_down, 1.02, "el flujo hacia el oyente sube el tono")
	a.lt(pitch_up, 0.98, "el flujo alejandose lo baja")
	a.approx(pitch_none, 1.0, "sin flujo, tono base", 0.02)
	spline.stop_event()
	tree.root.remove_child(spline)
	spline.free()
	manager.stop_all()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a
