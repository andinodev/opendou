class_name OpenDouReflectionDispatcher
extends RefCounted

## Convierte las reflexiones tempranas calculadas por AcousticReflectorEngine en
## voces reales del pool anonimo.
##
## El motor de reflexiones ya calculaba posicion de fuente imagen, retardo,
## ganancia y cutoff, y estaba completo y probado; lo unico que faltaba era que
## alguien convirtiera sus resultados en sonido. `enable_early_reflections` era un
## interruptor que no se leia en ninguna parte.
##
## Cada reflexion de 1er orden se emite como una voz colocada en la posicion
## espejo, que es como se hacen las reflexiones baratas en produccion.
##
## Presupuestado en tres niveles, porque trazar 6 rayos por voz y por frame seria
## inaceptable: techo por voz, techo global e intervalo minimo entre trazados de
## la misma instancia.

const AcousticReflectorEngineClass = preload("res://addons/opendou/runtime/spatial/acoustic_reflector_engine.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")

## Reflexiones como maximo por voz directa.
var max_reflections_per_voice: int = 2

## Reflexiones simultaneas como maximo en total.
var max_total_reflections: int = 16

## Segundos minimos entre dos trazados de la misma instancia.
var min_retrace_interval_sec: float = 0.25

## Capa fisica contra la que se trazan las reflexiones.
var collision_mask: int = 1

var reflector_engine: AcousticReflectorEngine = null
var player_pool: OpenDouNativePlayerPool = null

## Voces de reflexion actualmente sonando.
var active_reflection_count: int = 0

var _active_players: Array = []
var _last_trace_msec: Dictionary = {}

func _init() -> void:
	reflector_engine = AcousticReflectorEngineClass.new()

## Inyecta el pool de reproductores anonimos.
func set_player_pool(pool: OpenDouNativePlayerPool) -> void:
	player_pool = pool

## Emite las reflexiones tempranas de una instancia. Devuelve cuantas emitio.
func dispatch(instance, listener_pos: Vector3, world_3d: World3D) -> int:
	if player_pool == null or world_3d == null or instance == null:
		return 0
	if active_reflection_count >= max_total_reflections:
		return 0

	var stream: AudioStream = instance.definition.base_stream if instance.definition else null
	if stream == null:
		return 0

	# Limite de frecuencia de trazado por instancia.
	var key: int = instance.get_instance_id() if instance is Object else 0
	var now_msec: int = Time.get_ticks_msec()
	if min_retrace_interval_sec > 0.0 and _last_trace_msec.has(key):
		var elapsed: float = float(now_msec - int(_last_trace_msec[key])) / 1000.0
		if elapsed < min_retrace_interval_sec:
			return 0
	_last_trace_msec[key] = now_msec

	var reflections: Array[Dictionary] = reflector_engine.trace_early_reflections(
		instance.emitter_position, listener_pos, world_3d, collision_mask
	)
	if reflections.is_empty():
		return 0

	# Las reflexiones mas fuertes primero: si el presupuesto recorta, que recorte
	# las que menos se oyen.
	reflections.sort_custom(func(x, y): return float(x["gain"]) > float(y["gain"]))

	var emitted: int = 0
	for refl in reflections:
		if emitted >= max_reflections_per_voice:
			break
		if active_reflection_count >= max_total_reflections:
			break

		var player = player_pool.acquire(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)
		if player == null:
			break

		player.stream = stream
		player.global_position = refl["image_source_pos"]
		# La ganancia que devuelve el motor es lineal; el reproductor espera dB.
		player.volume_db = clampf(linear_to_db(maxf(float(refl["gain"]), 0.0001)), -80.0, 0.0)
		player.attenuation_filter_cutoff_hz = clampf(float(refl["cutoff_lpf"]), 20.0, 20000.0)
		var bus_name: String = String(instance.definition.target_bus) if instance.definition else "Master"
		if AudioServer.get_bus_index(bus_name) != -1:
			player.bus = bus_name
		# El retardo de llegada no se puede expresar como offset negativo, asi que
		# se aproxima arrancando la reflexion mas adelante en el propio stream.
		var length: float = float(stream.get_length())
		var offset: float = 0.0
		if length > 0.0:
			offset = clampf(float(refl["delay_seconds"]), 0.0, maxf(0.0, length - 0.001))
		player.play(offset)

		_active_players.append(player)
		active_reflection_count += 1
		emitted += 1

	return emitted

## Devuelve al pool las voces de reflexion que ya terminaron.
func collect_finished() -> void:
	for i in range(_active_players.size() - 1, -1, -1):
		var p = _active_players[i]
		if not is_instance_valid(p) or not p.playing:
			if is_instance_valid(p) and player_pool != null:
				player_pool.release(p)
			_active_players.remove_at(i)
			active_reflection_count = maxi(0, active_reflection_count - 1)

## Devuelve al pool todas las voces de reflexion, sonando o no.
func release_all() -> void:
	for p in _active_players:
		if is_instance_valid(p) and player_pool != null:
			player_pool.release(p)
	_active_players.clear()
	active_reflection_count = 0
