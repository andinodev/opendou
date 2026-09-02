class_name OpenDouDistanceModel
extends RefCounted

## Las formulas de atenuacion por distancia de AudioStreamPlayer3D (Godot 4.7,
## scene/3d/audio_stream_player_3d.cpp), escritas aqui para que el backend nativo suene
## igual que el de Godot y para poder afirmarlas con numeros.

const MODEL_INVERSE: int = 0
const MODEL_INVERSE_SQUARE: int = 1
const MODEL_LOGARITHMIC: int = 2
const MODEL_DISABLED: int = 3
const MAX_DB: float = 3.0
const EPS: float = 0.00001   # CMP_EPSILON de Godot

## Solo el modelo: sin volumen ni tope. Es _get_attenuation_db antes de sumar volume_db.
static func attenuation_db(distance: float, model: int, unit_size: float) -> float:
	var u: float = maxf(unit_size, 0.001)
	match model:
		MODEL_INVERSE:
			return linear_to_db(1.0 / ((distance / u) + EPS))
		MODEL_INVERSE_SQUARE:
			var d: float = distance / u
			return linear_to_db(1.0 / (d * d + EPS))
		MODEL_LOGARITHMIC:
			return -20.0 * log(distance / u + EPS)
		_:
			return 0.0

## Multiplicador lineal completo de Godot: modelo + volumen, tope max_db, y la rampa de
## max_distance. Cero mas alla del maximo.
static func multiplier(distance: float, model: int, unit_size: float, volume_db: float, max_db: float, attenuation_max_distance: float) -> float:
	var att: float = attenuation_db(distance, model, unit_size) + volume_db
	att = minf(att, max_db)
	var mult: float = db_to_linear(att)
	if attenuation_max_distance > 0.0:
		if distance > attenuation_max_distance:
			return 0.0
		mult *= maxf(0.0, 1.0 - distance / attenuation_max_distance)
	return mult

## Lo que se manda al stream nativo, en dB: el multiplicador SIN el volumen, porque el
## volumen (con el fade) va al reproductor. Equivale a min(att + V, 3) - V.
static func gain_db_for_stream(distance: float, model: int, unit_size: float, volume_db: float, attenuation_max_distance: float) -> float:
	var mult: float = multiplier(distance, model, unit_size, volume_db, MAX_DB, attenuation_max_distance)
	if mult <= 0.0:
		return -80.0
	return linear_to_db(mult) - volume_db

## Profundidad del high-shelf de Godot: (1 - min(1, mult)) * attenuation_filter_db.
static func shelf_db(mult: float, attenuation_filter_db: float) -> float:
	return (1.0 - minf(1.0, mult)) * attenuation_filter_db

## Direccion unitaria del oyente a la fuente, en el espacio del oyente. La base del
## oyente es ortonormal, asi que su inversa es la transpuesta.
static func listener_direction(source: Vector3, listener_position: Vector3, listener_basis: Basis) -> Vector3:
	var rel: Vector3 = source - listener_position
	if rel.length_squared() < 0.000001:
		return Vector3(0, 0, -1)
	return (listener_basis.transposed() * rel).normalized()

## Directividad tipo dipolo con la formula del efecto directo de Steam Audio, para que la
## version nativa (Fase 12) la sustituya sin cambiar la autoria:
##   g = |(1 - w) + w * cos(theta)| ^ p ;  dB = 20 log10(max(g, 0.001))
## w = 0: omnidireccional (0 dB). w = 1: dipolo (0 dB delante y detras, suelo de lado).
## w = 0.5: cardioide (0 dB delante, suelo detras).
static func directivity_db(forward: Vector3, to_listener: Vector3, dipole_weight: float, power: float) -> float:
	if dipole_weight <= 0.0 or forward.length_squared() < 0.000001 or to_listener.length_squared() < 0.000001:
		return 0.0
	var cos_theta: float = forward.normalized().dot(to_listener.normalized())
	var g: float = pow(absf((1.0 - dipole_weight) + dipole_weight * cos_theta), maxf(power, 0.01))
	return 20.0 * log(maxf(g, 0.001)) / log(10.0)
