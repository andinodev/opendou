class_name TestRoomReverbModes
extends RefCounted

const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const TestIRRT60Class = preload("res://tests/test_ir_rt60.gd")

## Este test probaba la convolucion IR, que se retiro: 512 taps por muestra en
## GDScript no es viable. Ahora prueba lo que la sustituye: el IR como FUENTE del
## RT60 que alimenta el reverb nativo.
static func run_all() -> Array[String]:
	var failures: Array[String] = []

	var room = OpenDouRoom3DClass.new()

	# El modo por defecto es el calculo geometrico.
	if room.reverb_mode != OpenDouRoom3DClass.ReverbMode.SABINE_RT60:
		failures.append("Test 1 Failed: el modo por defecto deberia ser SABINE_RT60")

	# Sin IR, el modo derivado cae de vuelta al calculo de Sabine.
	room.calculate_sabine_reverb(Vector3(10.0, 4.0, 10.0))
	var sabine: float = room.get_effective_reverb_time()
	room.reverb_mode = OpenDouRoom3DClass.ReverbMode.IR_DERIVED_RT60
	if not is_equal_approx(room.get_effective_reverb_time(), sabine):
		failures.append("Test 2 Failed: sin IR el modo derivado deberia caer a Sabine")

	# Con un IR de RT60 conocido, el modo derivado lo usa.
	room.impulse_response_stream = TestIRRT60Class._make_ir(2.0)
	if room.get_ir_derived_rt60() <= 0.0:
		failures.append("Test 3 Failed: el IR asignado deberia producir un RT60 medible")
	if absf(room.get_effective_reverb_time() - 2.0) > 0.3:
		failures.append("Test 4 Failed: el RT60 efectivo deberia venir del IR, se obtuvo %f" % room.get_effective_reverb_time())

	# Volver al modo geometrico descarta el IR.
	room.reverb_mode = OpenDouRoom3DClass.ReverbMode.SABINE_RT60
	if not is_equal_approx(room.get_effective_reverb_time(), sabine):
		failures.append("Test 5 Failed: volver a SABINE_RT60 deberia descartar el IR")

	# Un tiempo manual tiene prioridad sobre ambos.
	room.custom_reverb_time = 7.5
	room.reverb_mode = OpenDouRoom3DClass.ReverbMode.IR_DERIVED_RT60
	if not is_equal_approx(room.get_effective_reverb_time(), 7.5):
		failures.append("Test 6 Failed: custom_reverb_time deberia tener prioridad")

	room.free()
	return failures
