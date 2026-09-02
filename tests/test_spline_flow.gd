class_name TestSplineFlow
extends RefCounted

## Fase 9: el flujo del spline entra en su doppler propio. El spline sigue fuera del sistema
## de voces (observacion 47), asi que esto es todo lo que gana en esta fase.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")

static func run_all(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spline_flow")
	var SplineScript = load("res://addons/opendou/nodes/opendou_spline_emitter_3d.gd")
	var spline = SplineScript.new()
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, 0))
	c.add_point(Vector3(100, 0, 0))   # el rio corre hacia +X
	spline.curve = c
	spline.enable_doppler = true
	spline.base_pitch_scale = 1.0
	tree.root.add_child(spline)
	spline.reanchor()
	# Oyente pasado el final del rio (+X), con componente a lo largo de la corriente.
	var downstream := Vector3(120, 0, 5)
	spline.flow_speed_mps = 20.0
	var flow: Vector3 = spline.get_flow_velocity_at(downstream)
	a.ok(flow.is_equal_approx(Vector3(20, 0, 0)), "la velocidad de flujo es la tangente por la velocidad")
	for i in range(12):
		spline.update_spline_acoustics(downstream, Vector3.ZERO, 0.016)
	var pitch_down: float = spline.pitch_scale
	spline.flow_speed_mps = -20.0
	for i in range(12):
		spline.update_spline_acoustics(downstream, Vector3.ZERO, 0.016)
	var pitch_up: float = spline.pitch_scale
	spline.flow_speed_mps = 0.0
	for i in range(12):
		spline.update_spline_acoustics(downstream, Vector3.ZERO, 0.016)
	var pitch_none: float = spline.pitch_scale
	print("[OpenDou] flujo del spline: hacia el oyente %.3f, alejandose %.3f, sin flujo %.3f" % [pitch_down, pitch_up, pitch_none])
	a.gt(pitch_down, 1.02, "el flujo hacia el oyente sube el tono")
	a.lt(pitch_up, 0.98, "el flujo alejandose lo baja")
	a.approx(pitch_none, 1.0, "sin flujo, tono base", 0.02)
	tree.root.remove_child(spline)
	spline.free()
	return a
