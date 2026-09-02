class_name TestDistanceModel
extends RefCounted

## Fase 7B: las formulas de atenuacion de AudioStreamPlayer3D, afirmadas con numeros.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const DM = preload("res://addons/opendou/runtime/spatial/distance_model.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("distance_model")
	# Inversa: a dos unidades de distancia, la mitad de amplitud = -6.02 dB.
	a.approx(DM.attenuation_db(20.0, DM.MODEL_INVERSE, 10.0), -6.0206, "inversa a 20 m con unit 10", 0.01)
	a.approx(DM.attenuation_db(10.0, DM.MODEL_INVERSE, 10.0), 0.0, "inversa a la unidad = 0 dB", 0.01)
	a.approx(DM.attenuation_db(20.0, DM.MODEL_INVERSE_SQUARE, 10.0), -12.0412, "inversa cuadratica a 20 m", 0.01)
	a.approx(DM.attenuation_db(20.0, DM.MODEL_LOGARITHMIC, 10.0), -13.8629, "logaritmica a 20 m = -20 ln 2", 0.01)
	a.approx(DM.attenuation_db(20.0, DM.MODEL_DISABLED, 10.0), 0.0, "desactivada = 0 dB", 0.0001)

	# El tope de +3 dB se aplica a la SUMA con el volumen, como en Godot.
	a.approx(DM.multiplier(5.0, DM.MODEL_INVERSE, 10.0, 0.0, 3.0, 0.0), db_to_linear(3.0), "a 5 m la inversa daria +6 dB pero el tope es +3", 0.001)
	a.approx(DM.multiplier(5.0, DM.MODEL_INVERSE, 10.0, -6.0206, 3.0, 0.0), 1.0, "con volumen -6.02, la suma es 0 dB y no toca el tope", 0.001)
	# La ganancia que va al stream excluye el volumen (que va al reproductor).
	a.approx(DM.gain_db_for_stream(5.0, DM.MODEL_INVERSE, 10.0, -6.0, 0.0), 6.0206, "stream: att sin tope porque la suma no lo alcanza", 0.01)
	a.approx(DM.gain_db_for_stream(5.0, DM.MODEL_INVERSE, 10.0, 0.0, 0.0), 3.0, "stream: att recortada a 3 - 0", 0.01)
	a.approx(DM.gain_db_for_stream(20.0, DM.MODEL_INVERSE, 10.0, 0.0, 0.0), -6.0206, "stream: a 20 m -6 dB", 0.01)

	# attenuation_max_distance: rampa lineal hasta el silencio, y silencio pasado el limite.
	a.approx(DM.multiplier(20.0, DM.MODEL_INVERSE, 10.0, 0.0, 3.0, 40.0), 0.5 * 0.5, "a mitad del maximo el multiplicador se reduce a la mitad", 0.001)
	a.approx(DM.multiplier(41.0, DM.MODEL_INVERSE, 10.0, 0.0, 3.0, 40.0), 0.0, "pasado el maximo, cero", 0.0001)
	a.approx(DM.gain_db_for_stream(41.0, DM.MODEL_INVERSE, 10.0, 0.0, 40.0), -80.0, "pasado el maximo, -80 dB")

	# Shelf: profundidad proporcional a lo atenuada que esta la voz.
	a.approx(DM.shelf_db(1.0, -24.0), 0.0, "sin atenuacion, sin shelf")
	a.approx(DM.shelf_db(1.4, -24.0), 0.0, "por encima de 1 tampoco (min con 1)")
	a.approx(DM.shelf_db(0.5, -24.0), -12.0, "a la mitad, -12 dB")
	a.approx(DM.shelf_db(0.0, -24.0), -24.0, "en silencio, todo el shelf")

	# Direccion en el espacio del oyente.
	a.ok(DM.listener_direction(Vector3(5, 0, 0), Vector3.ZERO, Basis.IDENTITY).is_equal_approx(Vector3(1, 0, 0)), "fuente a la derecha con oyente identidad")
	var looking_minus_x := Basis(Vector3.UP, PI / 2.0)   # el oyente mira hacia -X
	a.ok(DM.listener_direction(Vector3(-5, 0, 0), Vector3.ZERO, looking_minus_x).is_equal_approx(Vector3(0, 0, -1)), "lo que esta en -X queda DELANTE de quien mira a -X")
	# Quien mira hacia -X tiene su +X local (derecha) apuntando a -Z del mundo.
	a.ok(DM.listener_direction(Vector3(0, 0, -5), Vector3.ZERO, looking_minus_x).is_equal_approx(Vector3(1, 0, 0)), "y lo que esta en -Z queda a su DERECHA")
	a.ok(DM.listener_direction(Vector3(3, 2, 1), Vector3(3, 2, 1), Basis.IDENTITY).is_equal_approx(Vector3(0, 0, -1)), "a distancia cero, delante")
	a.ok(DM.listener_direction(Vector3(10, 4, -2), Vector3(1, 1, 1), Basis.IDENTITY).is_normalized(), "siempre unitario")

	# Fase 9: modelo CURVE, en dB sobre 0..curve_distance.
	var c := Curve.new()
	c.min_value = -80.0
	c.max_value = 6.0
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.5, 0.0))
	c.add_point(Vector2(0.6, -40.0))
	c.add_point(Vector2(1.0, -40.0))
	a.approx(DM.attenuation_db(5.0, DM.MODEL_CURVE, 10.0, c, 10.0), 0.0, "curva: a 5 m (0.5) vale 0 dB", 0.5)
	a.approx(DM.attenuation_db(6.0, DM.MODEL_CURVE, 10.0, c, 10.0), -40.0, "curva: a 6 m (0.6) vale -40 dB", 0.5)
	a.approx(DM.attenuation_db(50.0, DM.MODEL_CURVE, 10.0, c, 10.0), -40.0, "curva: mas alla del alcance se acota al ultimo punto", 0.5)
	a.approx(DM.attenuation_db(5.0, DM.MODEL_CURVE, 10.0, null, 10.0), 0.0, "curva nula: como desactivada", 0.0001)
	a.approx(DM.attenuation_db(5.5, DM.MODEL_CURVE, 10.0, c, 10.0), c.sample(0.55), "curva: entre puntos devuelve lo que Godot interpola", 0.001)
	return a
