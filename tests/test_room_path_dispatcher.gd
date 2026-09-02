class_name TestRoomPathDispatcher
extends RefCounted

## La cache por par de salas, su digest y la aritmetica de la atenuacion. Sin audio:
## esto es logica pura y se prueba como tal.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const DispatcherClass = preload("res://addons/opendou/runtime/spatial/room_path_dispatcher.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")

## Tres salas en linea unidas por dos portales, como «Bajo la quilla».
static func _build_acoustics():
	var ac = SpatialAcousticsManagerClass.new()
	var specs := [
		{"name": &"EngineRoom", "center": Vector3(0, 2, 0), "size": Vector3(12, 5, 12)},
		{"name": &"Corridor", "center": Vector3(14, 2, 0), "size": Vector3(14, 4, 4)},
		{"name": &"FloodedBay", "center": Vector3(28, 1, 0), "size": Vector3(12, 4, 12)},
	]
	for spec in specs:
		var room = AudioRoomClass.new()
		room.room_name = spec["name"]
		room.set_bounds(AABB(spec["center"] - spec["size"] * 0.5, spec["size"]))
		ac.register_room(room)
	ac.register_portal(AudioPortalClass.new(&"Hatch", &"EngineRoom", &"Corridor", Vector3(6.5, 1.5, 0), 1.0))
	ac.register_portal(AudioPortalClass.new(&"Door", &"Corridor", &"FloodedBay", Vector3(21.5, 1.5, 0), 1.0))
	return ac

static func _physical_instance(pos: Vector3) -> EventInstance:
	var def = AudioEventDefClass.new(&"Probe")
	def.stream_length = 1.0
	var inst = EventInstanceClass.new(def, null)
	inst.set_position(pos)
	inst.voice_state = EventInstanceClass.VoiceState.STATE_PHYSICAL
	return inst

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("room_path_dispatcher")

	var ac = _build_acoustics()
	var dispatcher = DispatcherClass.new()
	dispatcher.acoustics = ac

	var emitter := Vector3(-4, 1.2, -4)
	var listener := Vector3(14, 1.6, 0)

	# ---- La cadena entre dos salas.
	var chain: Dictionary = dispatcher.chain_for(&"EngineRoom", &"Corridor", emitter, listener)
	a.ok(not chain.is_empty(), "hay cadena entre la sala de maquinas y el pasillo")
	a.eq(chain["portals"].size(), 1, "se cruza un portal")
	a.ok(not bool(chain["sealed"]), "y no esta sellada")
	a.approx(chain["exit_pos"].x, 6.5, "el origen aparente es la escotilla", 0.01)

	# Dos salas mas lejos: dos portales, y la cadena tiene longitud propia.
	var chain2: Dictionary = dispatcher.chain_for(&"EngineRoom", &"FloodedBay",
		emitter, Vector3(28, 1.0, 0))
	a.eq(chain2["portals"].size(), 2, "hasta la bahia se cruzan dos portales")
	a.gt(chain2["chain_length"], 10.0, "la cadena de dos portales tiene longitud propia")
	a.approx(chain["chain_length"], 0.0, "la de un solo portal no", 0.001)

	# ---- LA CACHE. Segunda peticion del mismo par: cero recorridos nuevos.
	dispatcher.traversals_this_frame = 0
	dispatcher.cache_hits_this_frame = 0
	dispatcher.chain_for(&"EngineRoom", &"Corridor", emitter, listener)
	a.eq(dispatcher.traversals_this_frame, 0, "el par ya cacheado no recorre el grafo")
	a.eq(dispatcher.cache_hits_this_frame, 1, "y se contabiliza como acierto de cache")

	# Un par NUEVO si recorre.
	dispatcher.chain_for(&"Corridor", &"FloodedBay", listener, Vector3(28, 1.0, 0))
	a.eq(dispatcher.traversals_this_frame, 1, "un par nuevo recorre el grafo una vez")

	# ---- LA DISTANCIA por voz sale de la cadena, y coincide con el grafo.
	var from_chain: float = emitter.distance_to(chain["entry_pos"]) \
		+ float(chain["chain_length"]) + chain["exit_pos"].distance_to(listener)
	var from_graph = ac.calculate_acoustic_path(emitter, listener, &"EngineRoom", &"Corridor")
	a.approx(from_chain, from_graph.virtual_distance,
		"la distancia derivada de la cadena coincide con la del grafo", 0.01)

	# ---- EL DIGEST, afirmado en las DOS direcciones.
	#
	# La primera direccion importa tanto como la segunda: _portal_digest arranca en -1.0,
	# asi que la primera llamada a process() limpia la cache SIEMPRE. Sin afirmar que una
	# segunda llamada sin cambios NO la limpia, este test pasaria con el digest roto.
	dispatcher.process([], listener)          # establece la linea base del digest
	dispatcher.chain_for(&"EngineRoom", &"Corridor", emitter, listener)
	dispatcher.process([], listener)          # nada ha cambiado
	dispatcher.chain_for(&"EngineRoom", &"Corridor", emitter, listener)
	a.eq(dispatcher.traversals_this_frame, 0,
		"sin cambios en los portales la cache SOBREVIVE al frame siguiente")
	a.eq(dispatcher.cache_hits_this_frame, 1, "y sirve su acierto")

	# Y ahora si: cerrar la escotilla la invalida.
	ac.portals[&"Hatch"].open_factor = 0.05
	dispatcher.process([], listener)
	dispatcher.chain_for(&"EngineRoom", &"Corridor", emitter, listener)
	a.eq(dispatcher.traversals_this_frame, 1,
		"cerrar la escotilla invalida la cache y obliga a recorrer de nuevo")

	var closed_chain: Dictionary = dispatcher.chain_for(&"EngineRoom", &"Corridor", emitter, listener)
	a.lt(closed_chain["lpf"], float(chain["lpf"]) * 0.5,
		"y la cadena nueva tiene un corte mucho mas bajo")

	# ---- LA ATENUACION.
	# Con el oyente pegado al portal, el divisor se acota: sin suelo esto seria -infinito
	# y la voz se apagaria justo cuando deberia oirse mejor.
	var glued: float = dispatcher.attenuation_db_for(30.0, Vector3(6.5, 1.5, 0), Vector3(6.5, 1.5, 0))
	a.gt(glued, dispatcher.max_attenuation_db - 0.01, "la atenuacion nunca baja de su suelo")
	a.lt(glued, 0.0, "pero si atenua: el camino es mas largo que el ultimo tramo")

	# Camino igual al ultimo tramo: no hay nada que compensar.
	var none: float = dispatcher.attenuation_db_for(10.0, Vector3(0, 0, 0), Vector3(10, 0, 0))
	a.approx(none, 0.0, "sin tramo oculto no hay atenuacion extra", 0.01)

	# El doble de camino son unos -6 dB.
	var double: float = dispatcher.attenuation_db_for(20.0, Vector3(0, 0, 0), Vector3(10, 0, 0))
	a.approx(double, -6.02, "el doble de camino son -6 dB", 0.1)

	# ---- SOLO FISICAS Y SOLO ESPACIALES.
	dispatcher.clear_cache()
	var physical = _physical_instance(emitter)
	var virtual_inst = _physical_instance(emitter)
	virtual_inst.voice_state = EventInstanceClass.VoiceState.STATE_VIRTUAL
	var non_spatial = _physical_instance(emitter)
	non_spatial.has_spatial_position = false

	var governed: int = dispatcher.process([physical, virtual_inst, non_spatial], listener)
	a.eq(governed, 1, "solo la voz fisica y espacial queda gobernada")
	a.ok(physical.room_path_active, "la fisica esta gobernada")
	a.ok(not virtual_inst.room_path_active, "la virtual no")
	a.ok(not non_spatial.room_path_active, "la no espacial tampoco")

	# ---- SIN SALAS no hay recorridos: es el caso de «El monzon».
	var empty_ac = SpatialAcousticsManagerClass.new()
	var empty_dispatcher = DispatcherClass.new()
	empty_dispatcher.acoustics = empty_ac
	var lonely = _physical_instance(Vector3(5, 1, 5))
	var governed_none: int = empty_dispatcher.process([lonely], Vector3.ZERO)
	a.eq(governed_none, 0, "sin salas registradas no se gobierna ninguna voz")
	a.eq(empty_dispatcher.traversals_this_frame, 0, "y no se recorre el grafo ni una vez")
	a.ok(not lonely.room_path_active, "la voz queda para la oclusion")

	# ---- MISMA SALA: manda la oclusion.
	dispatcher.clear_cache()
	var same_room = _physical_instance(emitter)
	dispatcher.process([same_room], Vector3(3.0, 1.2, 3.0))  # oyente en la sala de maquinas
	a.ok(not same_room.room_path_active, "en la misma sala el grafo no gobierna")

	# ---- Observacion 39: de las salas que contienen el punto, gana la MAS PEQUENA.
	var nested_ac = _build_acoustics()
	var hangar = AudioRoomClass.new()
	hangar.room_name = &"Hangar"
	hangar.set_bounds(AABB(Vector3(-40, -10, -40), Vector3(120, 30, 120)))  # envuelve todo
	nested_ac.register_room(hangar)
	var resolved = nested_ac.get_room_at_position(Vector3(-4, 1.2, -4))
	a.ok(resolved != null, "una posicion dentro de dos salas resuelve a alguna")
	if resolved != null:
		a.eq(str(resolved.room_name), "EngineRoom",
			"y gana la MAS PEQUENA: una sala envolvente no puede tapar a la que contiene")

	# ---- Observacion 38: dar de baja una sala la retira, y con ella sus portales.
	a.eq(nested_ac.rooms.size(), 4, "cuatro salas registradas")
	nested_ac.unregister_room(&"Hangar")
	a.eq(nested_ac.rooms.size(), 3, "dar de baja el hangar lo retira")
	a.eq(nested_ac.portals.size(), 2, "y no toca portales que no le tocaban")

	nested_ac.unregister_room(&"Corridor")
	a.ok(not nested_ac.portals.has(&"Hatch"),
		"dar de baja el pasillo se lleva el portal que lo tocaba")
	a.ok(not nested_ac.portals.has(&"Door"), "y el otro tambien")
	a.eq(nested_ac.rooms[&"EngineRoom"].connected_portals.size(), 0,
		"y los desengancha de la sala que sigue viva: un portal a ninguna parte falsearia el grafo")

	# ---- Observacion 41: entre dos portales hacia la misma sala gana el mas AUDIBLE.
	# Una puerta CERRADA y cercana frente a una ventana ABIERTA y mas lejana: antes
	# ganaba la puerta, por orden de insercion, y la musica "salia" por una puerta
	# cerrada.
	var two_ac = SpatialAcousticsManagerClass.new()
	for spec in [{"n": &"House", "c": Vector3(0, 2, 0), "s": Vector3(8, 4, 8)},
	             {"n": &"Street", "c": Vector3(0, 2, 12), "s": Vector3(30, 4, 16)}]:
		var r = AudioRoomClass.new()
		r.room_name = spec["n"]
		r.set_bounds(AABB(spec["c"] - spec["s"] * 0.5, spec["s"]))
		two_ac.register_room(r)
	# La puerta se registra PRIMERO y esta mas cerca del emisor: es el caso que fallaba.
	two_ac.register_portal(AudioPortalClass.new(&"ClosedDoor", &"House", &"Street", Vector3(-1.0, 1.0, 4.0), 0.0))
	two_ac.register_portal(AudioPortalClass.new(&"OpenWindow", &"House", &"Street", Vector3(3.0, 1.8, 4.0), 1.0))
	var through = two_ac.calculate_acoustic_path(Vector3(-1.5, 1.4, 1.0), Vector3(0.0, 1.6, 9.0), &"House", &"Street")
	a.eq(through.portals_traversed.size(), 1, "el camino cruza un portal")
	if through.portals_traversed.size() == 1:
		a.eq(str(through.portals_traversed[0].portal_name), "OpenWindow",
			"y es la ventana ABIERTA, aunque la puerta cerrada este mas cerca y se registrara antes")
	a.gt(through.accumulated_lpf, 10000.0, "asi que el corte del camino es el de una ventana abierta")

	# Y si la ventana se cierra y la puerta se abre, el camino cambia de portal.
	two_ac.portals[&"OpenWindow"].open_factor = 0.0
	two_ac.portals[&"ClosedDoor"].open_factor = 1.0
	var swapped = two_ac.calculate_acoustic_path(Vector3(-1.5, 1.4, 1.0), Vector3(0.0, 1.6, 9.0), &"House", &"Street")
	if swapped.portals_traversed.size() == 1:
		a.eq(str(swapped.portals_traversed[0].portal_name), "ClosedDoor",
			"al invertir las aperturas el camino cambia de portal")

	# ---- LA POSICION APARENTE arranca en la del emisor y no en el origen.
	# Sin esto, cada voz nueva barreria desde (0,0,0) hasta su sitio y se oiria.
	var fresh = _physical_instance(Vector3(9, 2, -3))
	a.approx(fresh.current_apparent_position.x, 9.0,
		"una instancia nueva arranca con su posicion aparente puesta", 0.01)

	# ---- Se interpola hacia el destino, no salta.
	fresh.room_path_active = true
	fresh.target_apparent_position = Vector3(0, 0, 0)
	fresh.update_parameters(0.016, {})
	a.gt(fresh.current_apparent_position.x, 0.01,
		"un frame no la lleva del todo al destino: se interpola")
	a.lt(fresh.current_apparent_position.x, 9.0,
		"pero si se ha movido hacia el")

	# Con muchos frames converge.
	for i in range(120):
		fresh.update_parameters(0.016, {})
	a.approx(fresh.current_apparent_position.x, 0.0,
		"con tiempo suficiente converge al destino", 0.05)

	# ---- Y al dejar de estar gobernada, vuelve sola a la posicion real.
	fresh.room_path_active = false
	for i in range(120):
		fresh.update_parameters(0.016, {})
	a.approx(fresh.current_apparent_position.x, 9.0,
		"al dejar de gobernarla, la posicion aparente vuelve a la del emisor", 0.05)

	return a


## El paso dentro del bucle, y que la oclusion se aparta de las voces gobernadas.
## Fase 8 (obs 43): registrar o desregistrar una sala o un portal sube la generacion del
## grafo, y el despachador vacia su cache al verla cambiar aunque el digest de aperturas no
## se mueva; y con el grafo vacio la cache tambien se vacia.
static func run_generation() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("room_path_generation")
	var AcousticsClass = load("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
	var RoomClass = load("res://addons/opendou/runtime/spatial/audio_room.gd")
	var PortalClass = load("res://addons/opendou/runtime/spatial/audio_portal.gd")
	var DispatcherClass = load("res://addons/opendou/runtime/spatial/room_path_dispatcher.gd")
	var PoolClass = load("res://addons/opendou/runtime/voice_pool_manager.gd")
	var ac2 = AcousticsClass.new()
	var gen0: int = ac2.graph_generation
	var ra = RoomClass.new()
	ra.room_name = &"GenA"
	ra.set_bounds(AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10)))
	ac2.register_room(ra)
	a.gt(float(ac2.graph_generation), float(gen0), "registrar una sala sube la generacion")
	var gen1: int = ac2.graph_generation
	var rb = RoomClass.new()
	rb.room_name = &"GenB"
	rb.set_bounds(AABB(Vector3(5, -5, -5), Vector3(10, 10, 10)))
	ac2.register_room(rb)
	ac2.register_portal(PortalClass.new(&"GenP", &"GenA", &"GenB", Vector3(5, 0, 0), 1.0))
	a.gt(float(ac2.graph_generation), float(gen1), "registrar un portal tambien")
	var disp2 = DispatcherClass.new()
	disp2.acoustics = ac2
	var pool = PoolClass.new(1)
	disp2.process_pool(pool, Vector3(10, 0, 0))
	disp2.chain_for(&"GenA", &"GenB", Vector3(0, 0, 0), Vector3(10, 0, 0))
	a.ok(not disp2._cache.is_empty(), "la cache tiene la cadena")
	disp2.process_pool(pool, Vector3(10, 0, 0))
	a.ok(not disp2._cache.is_empty(), "sin cambios en el grafo, la cache se conserva")
	ac2.unregister_portal(&"GenP")
	disp2.process_pool(pool, Vector3(10, 0, 0))
	a.ok(disp2._cache.is_empty(), "al cambiar la generacion, la cache se vacia")
	ac2.register_portal(PortalClass.new(&"GenP", &"GenA", &"GenB", Vector3(5, 0, 0), 1.0))
	disp2.process_pool(pool, Vector3(10, 0, 0))
	disp2.chain_for(&"GenA", &"GenB", Vector3(0, 0, 0), Vector3(10, 0, 0))
	ac2.unregister_room(&"GenA")
	ac2.unregister_room(&"GenB")
	disp2.process_pool(pool, Vector3(10, 0, 0))
	a.ok(disp2._cache.is_empty(), "con el grafo vacio la cache tambien se vacia (antes se conservaba)")
	return a

static func run_wiring_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("room_path_wiring")

	var ManagerClass = load("res://addons/opendou/runtime/audio_event_manager.gd")
	var manager = ManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	a.ok(manager.room_path_dispatcher != null, "el manager trae dispatcher de caminos")
	if manager.room_path_dispatcher != null:
		a.ok(manager.room_path_dispatcher.acoustics == manager.spatial_acoustics,
			"y comparte el manager espacial, no una copia")

	# Sin salas registradas, cero recorridos: es el caso de «El monzon».
	# El tipo va explicito: load() devuelve Variant y := no puede inferir.
	var tone: AudioStreamWAV = load("res://addons/opendou/runtime/audio_synthesizer.gd").create_tone(300.0, 1.0, 0.6, false)
	var def = AudioEventDefClass.new(&"WiringProbe", tone)
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)

	for i in range(20):
		var inst = manager.post_event(def, null)
		if inst != null:
			inst.set_position(Vector3(float(i) * 3.0, 1.0, 0.0))
	for i in range(6):
		await tree.process_frame
	a.eq(manager.room_path_dispatcher.traversals_this_frame, 0,
		"sin salas registradas el grafo no se recorre ni una vez")

	# Ahora con salas: las voces de otra sala quedan gobernadas y la oclusion las salta.
	var ac = manager.spatial_acoustics
	var room_specs := [
		{"name": &"RoomA", "center": Vector3(0, 2, 0), "size": Vector3(12, 5, 12)},
		{"name": &"RoomB", "center": Vector3(14, 2, 0), "size": Vector3(12, 5, 12)},
	]
	for spec in room_specs:
		var room = AudioRoomClass.new()
		room.room_name = spec["name"]
		room.set_bounds(AABB(spec["center"] - spec["size"] * 0.5, spec["size"]))
		ac.register_room(room)
	ac.register_portal(AudioPortalClass.new(&"Gap", &"RoomA", &"RoomB", Vector3(7.0, 1.5, 0), 1.0))

	manager.stop_all()
	var inside = manager.post_event(def, null)
	inside.set_position(Vector3(-3.0, 1.0, 0.0))          # RoomA
	manager.set_listener_position(Vector3(14.0, 1.6, 0.0)) # RoomB
	for i in range(6):
		await tree.process_frame

	a.ok(inside.room_path_active, "una voz de otra sala queda gobernada por el grafo")
	a.approx(inside.target_apparent_position.x, 7.0,
		"su posicion aparente es la del portal", 0.01)

	# En regimen la CACHE sirve el camino y el contador de recorridos de ESTE frame es
	# cero: leerlo tras varios frames y esperar un recorrido seria afirmar que la cache
	# no funciona.
	a.gt(float(manager.room_path_dispatcher.cache_hits_this_frame), 0.0,
		"en regimen la cache sirve el camino sin recorrer el grafo")

	# Y que el grafo se recorre de verdad se comprueba forzandolo: cache limpia, un
	# frame, un recorrido.
	manager.room_path_dispatcher.clear_cache()
	await tree.process_frame
	a.gt(float(manager.room_path_dispatcher.traversals_this_frame), 0.0,
		"con la cache limpia el grafo si se recorre")

	# La oclusion no la cuenta entre sus candidatas: sin esto, el mismo mamparo se
	# cobraria dos veces y el presupuesto de raycasts se gastaria en voces ya resueltas.
	var scheduler = manager.occlusion_scheduler
	var vp: Viewport = manager.get_viewport()
	var w3d: World3D = vp.find_world_3d() if vp != null else null
	var raycasts: int = scheduler.process([inside], Vector3(14.0, 1.6, 0.0), w3d)
	a.eq(raycasts, 0, "la oclusion no gasta raycasts en una voz que gobierna el grafo")

	# Y en cuanto deja de estar gobernada, la oclusion vuelve a atenderla.
	inside.room_path_active = false
	var raycasts_again: int = scheduler.process([inside], Vector3(14.0, 1.6, 0.0), w3d)
	a.gt(float(raycasts_again), 0.0, "sin gobierno del grafo, la oclusion la atiende")

	# ---- Observacion 38 con NODOS: liberar una escena da de baja sus salas.
	var Room3DClass = load("res://addons/opendou/nodes/opendou_room_3d.gd")
	var stray = Room3DClass.new()
	stray.room_name = &"StrayRoom"
	var stray_shape := CollisionShape3D.new()
	var stray_box := BoxShape3D.new()
	stray_box.size = Vector3(8, 4, 8)
	stray_shape.shape = stray_box
	stray.add_child(stray_shape)
	tree.root.add_child(stray)
	await tree.process_frame

	var autoload_node = tree.root.get_node_or_null("OpenDou")
	a.ok(autoload_node != null, "el autoload OpenDou existe")
	if autoload_node != null:
		var autoload_ac = autoload_node.spatial_acoustics
		a.ok(autoload_ac.rooms.has(&"StrayRoom"), "un Room3D en el arbol se registra")
		tree.root.remove_child(stray)
		stray.free()
		await tree.process_frame
		a.ok(not autoload_ac.rooms.has(&"StrayRoom"),
			"y al liberarlo se da de baja: sin esto el grafo crece para siempre y una sala muerta tapa el nivel nuevo")
	else:
		tree.root.remove_child(stray)
		stray.free()

	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	return a


## La guarda de coste: con muchas voces, el grafo se recorre un punado de veces.
##
## Cuenta RECORRIDOS y no milisegundos. Un test de tiempo seria fragil entre maquinas, y
## lo que hay que impedir es que vuelva la version ingenua -un recorrido por voz y por
## frame-, que es exactamente lo que un conteo detecta.
static func run_budget_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("room_path_budget")

	var ManagerClass = load("res://addons/opendou/runtime/audio_event_manager.gd")
	var manager = ManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	# Tres salas: como mucho nueve pares ordenados, y en la practica muchos menos.
	var ac = manager.spatial_acoustics
	var specs := [
		{"name": &"R1", "center": Vector3(0, 2, 0), "size": Vector3(20, 6, 20)},
		{"name": &"R2", "center": Vector3(22, 2, 0), "size": Vector3(20, 6, 20)},
		{"name": &"R3", "center": Vector3(44, 2, 0), "size": Vector3(20, 6, 20)},
	]
	for spec in specs:
		var room = AudioRoomClass.new()
		room.room_name = spec["name"]
		room.set_bounds(AABB(spec["center"] - spec["size"] * 0.5, spec["size"]))
		ac.register_room(room)
	ac.register_portal(AudioPortalClass.new(&"P12", &"R1", &"R2", Vector3(11.0, 1.5, 0), 1.0))
	ac.register_portal(AudioPortalClass.new(&"P23", &"R2", &"R3", Vector3(33.0, 1.5, 0), 1.0))

	# Presupuesto pequeno: con 64 voces fisicas el pool crea 64 reproductores y la suite
	# se llena de retenciones del servidor de audio sin que la guarda gane nada.
	manager.set_max_physical_voices(16)

	var tone: AudioStreamWAV = load("res://addons/opendou/runtime/audio_synthesizer.gd").create_rain_ambient_loop(1.0)
	var def = AudioEventDefClass.new(&"BudgetProbe", tone)
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)

	# 200 voces, casi todas en las salas VECINAS a la del oyente.
	#
	# El reparto importa y la primera version lo tenia mal: con un tercio en cada sala y
	# el oyente en la primera, las voces de su propia sala ganaban todas las plazas
	# fisicas por cercania, ninguna quedaba gobernada, y la guarda contaba cero
	# recorridos y pasaba sin probar nada. Lo cazo la asercion de aciertos de cache, que
	# esta justo para eso.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in range(200):
		var inst = manager.post_event(def, null)
		if inst == null:
			break
		# Una de cada veinte en la sala del oyente; el resto repartidas en las otras dos.
		var room_index: int = 1 if i % 20 == 0 else (0 if i % 2 == 0 else 2)
		inst.set_position(Vector3(
			float(room_index) * 22.0 + rng.randf_range(-8.0, 8.0),
			1.5,
			rng.randf_range(-8.0, 8.0)
		))
	manager.set_listener_position(Vector3(22.0, 1.6, 0.0))  # sala del medio
	for i in range(10):
		await tree.process_frame

	a.gt(float(manager.active_instances.size()), 150.0, "hay mas de 150 instancias activas")

	# LA GUARDA. Con tres salas hay nueve pares ordenados como techo absoluto.
	var max_traversals: int = 0
	var saw_hits: bool = false
	for i in range(30):
		await tree.process_frame
		max_traversals = maxi(max_traversals, manager.room_path_dispatcher.traversals_this_frame)
		if manager.room_path_dispatcher.cache_hits_this_frame > 0:
			saw_hits = true
	a.lt(float(max_traversals), 10.0,
		"con 200 voces y tres salas el grafo se recorre como mucho 9 veces por frame")

	# Y no es cero por accidente: la cache tiene que estar sirviendo aciertos.
	a.ok(saw_hits,
		"la cache sirve aciertos, asi que el conteo bajo no es porque el grafo no se use")

	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	return a
