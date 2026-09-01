class_name OpenDouRoomPathDispatcher
extends RefCounted

## Aplica el grafo de salas y portales a las voces que suenan.
##
## Existe porque calculate_acoustic_path() estaba implementado, tenia tests, y se
## invocaba UNICAMENTE desde los tests: salas, portales y difraccion de portal estaban
## calculados y eran inertes en la cadena de audio. Observacion 35.
##
## Dos decisiones sostienen el coste, y sin ellas esto no seria viable:
##
##  1. Solo mira las voces FISICAS. Una voz virtual no suena, asi que calcular su filtro
##     es trabajo tirado: el valor se necesita cuando se vuelve fisica, y ahi se calcula.
##     Con un presupuesto de 32 voces eso son 32 candidatas y no 200.
##  2. Cachea por PAR DE SALAS. Medido: un recorrido cuesta 2.9 us con un portal y 4.0 us
##     con dos, asi que hacerlo por voz y por frame costaria 0.78 ms con 200 voces y
##     DUPLICARIA el coste del motor entero, que son 0.77 ms.
##
## Lo que se cachea es la CADENA de portales, no el camino entero: el AcousticPath
## incluye virtual_distance, que depende de la posicion del emisor, y cachearlo tal cual
## daria a las 200 voces la distancia de la primera.

const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")

## El SpatialAcousticsManager. Se asigna desde fuera.
var acoustics = null

## Recorridos del grafo en la ultima llamada a process(). Es la guarda de coste: un test
## de tiempo seria fragil entre maquinas, un conteo es determinista.
var traversals_this_frame: int = 0

## Aciertos de cache en la ultima llamada.
var cache_hits_this_frame: int = 0

## Suelo del divisor de la atenuacion, en metros.
##
## Sin el, un oyente plantado en el portal divide por cero y la voz se apaga del todo
## justo cuando deberia oirse mejor. 0.5 m es el orden del tamano de una cabeza.
var min_divisor_meters: float = 0.5

## Suelo de la atenuacion extra, en dB.
var max_attenuation_db: float = -40.0

var _cache: Dictionary = {}
var _portal_digest: float = -1.0

## Gobierna las voces que lo necesiten. Devuelve cuantas.
func process(instances: Array, listener_pos: Vector3) -> int:
	traversals_this_frame = 0
	cache_hits_this_frame = 0

	if acoustics == null or acoustics.rooms.is_empty():
		# Sin salas registradas no hay nada que hacer, y ese es el caso de una escena al
		# aire libre: cero coste, y las voces quedan para la oclusion.
		for instance in instances:
			if instance != null:
				instance.room_path_active = false
		return 0

	# El digest se calcula UNA vez por frame, no por voz: es O(P) con P portales.
	var digest: float = _portals_digest()
	if not is_equal_approx(digest, _portal_digest):
		_cache.clear()
		_portal_digest = digest

	# La sala del oyente se resuelve UNA vez, no por voz.
	var listener_room: StringName = &""
	var found_listener = acoustics.get_room_at_position(listener_pos)
	if found_listener != null:
		listener_room = found_listener.room_name

	var governed: int = 0
	for instance in instances:
		if instance == null:
			continue
		if not instance.has_spatial_position:
			instance.room_path_active = false
			continue
		if instance.voice_state != EventInstanceClass.VoiceState.STATE_PHYSICAL:
			instance.room_path_active = false
			continue

		var emitter_room: StringName = &""
		var found_emitter = acoustics.get_room_at_position(instance.emitter_position)
		if found_emitter != null:
			emitter_room = found_emitter.room_name

		# Misma sala, o alguno fuera de toda sala: manda la oclusion.
		if emitter_room.is_empty() or listener_room.is_empty() or emitter_room == listener_room:
			instance.room_path_active = false
			continue

		var chain: Dictionary = chain_for(emitter_room, listener_room,
			instance.emitter_position, listener_pos)
		if chain.is_empty():
			instance.room_path_active = false
			continue

		var exit_pos: Vector3 = chain["exit_pos"] if not bool(chain["sealed"]) else instance.emitter_position
		var virtual_distance: float = instance.emitter_position.distance_to(chain["entry_pos"]) \
			+ float(chain["chain_length"]) + exit_pos.distance_to(listener_pos)

		instance.set_target_lpf(float(chain["lpf"]),
			attenuation_db_for(virtual_distance, exit_pos, listener_pos))
		instance.target_apparent_position = exit_pos
		instance.room_path_active = true
		governed += 1

	return governed

## La cadena de portales entre dos salas. Cacheada por par.
##
## Devuelve un diccionario con:
##   portals       Array[AudioPortal] recorridos
##   lpf           corte acumulado, el minimo de los portales del camino
##   chain_length  suma de distancias entre portales consecutivos
##   entry_pos     posicion del primer portal
##   exit_pos      posicion del ultimo portal: el origen aparente
##   sealed        true si no hay camino de portales entre las dos salas
func chain_for(emitter_room: StringName, listener_room: StringName, emitter_pos: Vector3, listener_pos: Vector3) -> Dictionary:
	var key: String = "%s|%s" % [str(emitter_room), str(listener_room)]
	if _cache.has(key):
		cache_hits_this_frame += 1
		return _cache[key]

	traversals_this_frame += 1
	var path = acoustics.calculate_acoustic_path(emitter_pos, listener_pos, emitter_room, listener_room)
	var portals: Array = path.portals_traversed

	var entry := Vector3.ZERO
	var exit := Vector3.ZERO
	var chain_length: float = 0.0
	var sealed: bool = portals.is_empty()
	if not sealed:
		entry = portals[0].position
		exit = portals[portals.size() - 1].position
		for i in range(portals.size() - 1):
			chain_length += portals[i].position.distance_to(portals[i + 1].position)

	var entry_data: Dictionary = {
		"portals": portals,
		"lpf": path.accumulated_lpf,
		"chain_length": chain_length,
		"entry_pos": entry,
		"exit_pos": exit,
		"sealed": sealed,
	}
	_cache[key] = entry_data
	return entry_data

## Atenuacion que compensa el tramo que Godot no ve.
##
## Con el origen aparente en el portal, Godot atenua por la distancia oyente -> portal.
## El tramo emisor -> portal no lo ve nadie, asi que se cobra aqui.
func attenuation_db_for(virtual_distance: float, exit_pos: Vector3, listener_pos: Vector3) -> float:
	var heard_distance: float = maxf(min_divisor_meters, exit_pos.distance_to(listener_pos))
	var ratio: float = maxf(1.0, virtual_distance / heard_distance)
	return maxf(max_attenuation_db, -20.0 * (log(ratio) / log(10.0)))

## Vacia la cache. La llaman los tests y el registro de salas o portales nuevos.
func clear_cache() -> void:
	_cache.clear()
	_portal_digest = -1.0

## Huella del estado de los portales.
##
## No es criptografica: solo tiene que cambiar cuando cambie algo. El peso por indice
## hace que intercambiar dos aperturas tambien la cambie.
func _portals_digest() -> float:
	var digest: float = float(acoustics.portals.size())
	var i: int = 1
	for portal_name in acoustics.portals:
		digest += acoustics.portals[portal_name].open_factor * float(i)
		i += 1
	return digest
