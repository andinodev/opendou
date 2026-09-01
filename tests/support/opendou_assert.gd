class_name OpenDouAssert
extends RefCounted

## Acumulador de aserciones para la suite de OpenDou.
## Cuenta las aserciones realmente ejecutadas en lugar de confiar en un total
## escrito a mano, y registra cada fallo con su etiqueta y valores observados.

var failures: Array[String] = []
var assertions_run: int = 0

var _context: String = ""

func _init(p_context: String = "") -> void:
	_context = p_context

func _fail(msg: String) -> void:
	if _context.is_empty():
		failures.append(msg)
	else:
		failures.append("[%s] %s" % [_context, msg])

## Afirma que una condición es verdadera.
func ok(condition: bool, label: String) -> bool:
	assertions_run += 1
	if not condition:
		_fail("%s: se esperaba verdadero" % label)
		return false
	return true

## Afirma igualdad exacta.
func eq(actual: Variant, expected: Variant, label: String) -> bool:
	assertions_run += 1
	if actual != expected:
		_fail("%s: se esperaba %s, se obtuvo %s" % [label, str(expected), str(actual)])
		return false
	return true

## Afirma igualdad de flotantes con tolerancia.
func approx(actual: float, expected: float, label: String, tolerance: float = 0.0001) -> bool:
	assertions_run += 1
	if absf(actual - expected) > tolerance:
		_fail("%s: se esperaba %f +/- %f, se obtuvo %f" % [label, expected, tolerance, actual])
		return false
	return true

## Afirma que un valor supera un umbral.
func gt(actual: float, threshold: float, label: String) -> bool:
	assertions_run += 1
	if actual <= threshold:
		_fail("%s: se esperaba > %f, se obtuvo %f" % [label, threshold, actual])
		return false
	return true

## Afirma que un valor queda por debajo de un umbral.
func lt(actual: float, threshold: float, label: String) -> bool:
	assertions_run += 1
	if actual >= threshold:
		_fail("%s: se esperaba < %f, se obtuvo %f" % [label, threshold, actual])
		return false
	return true

## Afirma que un objeto NO expone una propiedad. Para verificar retiradas.
func has_no_property(obj: Object, prop_name: String, label: String) -> bool:
	assertions_run += 1
	if obj == null:
		_fail("%s: objeto nulo" % label)
		return false
	for p in obj.get_property_list():
		if String(p["name"]) == prop_name:
			_fail("%s: la propiedad '%s' deberia haber sido retirada" % [label, prop_name])
			return false
	return true

## Fusiona el resultado de otro acumulador (para suites compuestas).
func absorb(other: OpenDouAssert) -> void:
	if other == null:
		return
	assertions_run += other.assertions_run
	failures.append_array(other.failures)
