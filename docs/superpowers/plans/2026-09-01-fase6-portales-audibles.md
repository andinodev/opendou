# Fase 6 — Los portales se oyen: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Conectar el grafo de salas y portales a la cadena de audio, de forma que cerrar una escotilla se **oiga**, sin que el coste añadido pase del +10 % sobre el bucle actual.

**Architecture:** Una pieza nueva —`OpenDouRoomPathDispatcher`— y un paso nuevo en `AudioEventManager._process()`, colocado **antes** de la oclusión para que la oclusión pueda saltarse las voces que el grafo gobierna. El dispatcher solo mira las voces **físicas** y cachea el recorrido del grafo **por par de salas**, invalidando la caché con un digest de los `open_factor` una vez por frame.

**Tech Stack:** Godot 4.7.2.stable.official.ed1daf0bf, GDScript puro, sin GDExtension.

**Spec:** [`docs/superpowers/specs/2026-09-01-fase6-portales-audibles-design.md`](../specs/2026-09-01-fase6-portales-audibles-design.md)

## Global Constraints

- **Rama `main`.** Este proyecto trabaja en una sola rama; no se crean ramas.
- **Solo voces FÍSICAS.** Una voz virtual no suena: calcular su filtro es trabajo tirado. `voice_state == EventInstance.VoiceState.STATE_PHYSICAL`.
- **Solo voces espaciales.** `has_spatial_position == true`. Música, radio y UI quedan fuera solas.
- **El grafo gobierna entre salas distintas; la oclusión dentro de la misma.** Nunca los dos sobre la misma voz, o el mismo mamparo se cobra dos veces y suena a barro.
- **Sin flag de opt-in por evento.** Las voces que no deben verse afectadas ya quedan fuera por las reglas de arriba.
- **Suelo del divisor de la atenuación: 0.5 m.** Sin él, un oyente plantado en el portal divide por cero y la voz se apaga justo cuando debería oírse mejor.
- **Suelo de la atenuación: −40 dB.**
- **Las guardas de coste cuentan RECORRIDOS, no milisegundos.** Un test de tiempo es frágil entre máquinas.
- **`./run_tests.sh` es la única forma válida de dar algo por hecho.** Trata `SCRIPT ERROR` y `Parse Error` como fatales y lleva el trinquete de fugas.
- **No contar frames fijos para afirmar silencio.** En headless el bucle corre a máxima velocidad. Usa `OpenDouAudioProbe.await_silence()`.
- **Un literal de array sin tipar asignado a un `Array[Vector3]` aborta en tiempo de ejecución.** Usa un local tipado.

---

## File Structure

### Archivos nuevos

| Archivo | Responsabilidad |
|---|---|
| `addons/opendou/runtime/spatial/room_path_dispatcher.gd` | La caché por par de salas, su digest de invalidación, el conteo de recorridos y la traducción camino → valores de voz |
| `tests/test_room_path_dispatcher.gd` | La caché, el digest, el conteo y la aritmética de la atenuación, sin audio |
| `tests/test_portal_audio.gd` | Las cinco aserciones de audio real y de posición aparente |

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `addons/opendou/runtime/event_instance.gd` | Tres campos nuevos y el suavizado de la posición aparente |
| `addons/opendou/runtime/audio_event_manager.gd` | El paso nuevo en el bucle; `_apply_voices()` usa la posición aparente |
| `addons/opendou/runtime/spatial/occlusion_scheduler.gd` | Excluye las instancias gobernadas por el grafo |
| `scenes/demos/keel/keel_demo.gd` | La válvula va a su propio bus, para poder medirla |
| `tests/test_demo_scenes.gd` | Se sustituye la aserción de propiedad de la escotilla |
| `tests/test_all.gd` | Cablea las dos suites nuevas |
| `AGENTS.md` | El techo de voces medido |

---

## Task 1: El dispatcher, su caché y su digest

**Files:**
- Create: `addons/opendou/runtime/spatial/room_path_dispatcher.gd`
- Create: `tests/test_room_path_dispatcher.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouRoomPathDispatcher extends RefCounted` con:
  - `acoustics` (asignable: el `SpatialAcousticsManager`)
  - `traversals_this_frame: int`, `cache_hits_this_frame: int`
  - `min_divisor_meters: float = 0.5`, `max_attenuation_db: float = -40.0`
  - `process(instances: Array, listener_pos: Vector3) -> int` — devuelve cuántas voces gobernó
  - `chain_for(emitter_room: StringName, listener_room: StringName, emitter_pos: Vector3, listener_pos: Vector3) -> Dictionary` — la entrada de caché
  - `attenuation_db_for(virtual_distance: float, exit_pos: Vector3, listener_pos: Vector3) -> float`
  - `clear_cache() -> void`
- Consumes: `SpatialAcousticsManager.rooms`, `.portals`, `.get_room_at_position()`, `.calculate_acoustic_path()`; `AcousticPath.virtual_distance/accumulated_lpf/apparent_origin/portals_traversed`.

**Por qué la caché guarda la cadena y no el camino entero.** El `AcousticPath` que devuelve el grafo incluye `virtual_distance`, que **sí depende de la posición del emisor**: cachearlo tal cual daría a las 200 voces la distancia de la primera. Lo que de verdad depende solo del par de salas es la **cadena de portales**: cuáles son, su corte mínimo, y la suma de distancias entre portales consecutivos. Con eso, la distancia de cada voz es una resta:

```
virtual_distance = dist(emisor, primer_portal) + longitud_de_la_cadena + dist(ultimo_portal, oyente)
```

Que es exactamente lo que acumula el BFS, así que el resultado es idéntico al de llamarlo por voz.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_room_path_dispatcher.gd`:

```gdscript
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

	# ---- La cadena entre dos salas.
	var chain: Dictionary = dispatcher.chain_for(&"EngineRoom", &"Corridor",
		Vector3(-4, 1.2, -4), Vector3(14, 1.6, 0))
	a.ok(not chain.is_empty(), "hay cadena entre la sala de maquinas y el pasillo")
	a.eq(chain["portals"].size(), 1, "se cruza un portal")
	a.ok(not bool(chain["sealed"]), "y no esta sellada")
	a.approx(chain["exit_pos"].x, 6.5, "el origen aparente es la escotilla", 0.01)

	# Dos salas mas lejos: dos portales, y la cadena tiene longitud propia.
	var chain2: Dictionary = dispatcher.chain_for(&"EngineRoom", &"FloodedBay",
		Vector3(-4, 1.2, -4), Vector3(28, 1.0, 0))
	a.eq(chain2["portals"].size(), 2, "hasta la bahia se cruzan dos portales")
	a.gt(chain2["chain_length"], 10.0, "la cadena de dos portales tiene longitud propia")
	a.approx(chain["chain_length"], 0.0, "la de un solo portal no", 0.001)

	# ---- LA CACHE. Segunda peticion del mismo par: cero recorridos nuevos.
	dispatcher.traversals_this_frame = 0
	dispatcher.cache_hits_this_frame = 0
	dispatcher.chain_for(&"EngineRoom", &"Corridor", Vector3(-4, 1.2, -4), Vector3(14, 1.6, 0))
	a.eq(dispatcher.traversals_this_frame, 0, "el par ya cacheado no recorre el grafo")
	a.eq(dispatcher.cache_hits_this_frame, 1, "y se contabiliza como acierto de cache")

	# Un par NUEVO si recorre.
	dispatcher.chain_for(&"Corridor", &"FloodedBay", Vector3(14, 1.6, 0), Vector3(28, 1.0, 0))
	a.eq(dispatcher.traversals_this_frame, 1, "un par nuevo recorre el grafo una vez")

	# ---- LA DISTANCIA por voz sale de la cadena, y coincide con el grafo.
	var emitter := Vector3(-4, 1.2, -4)
	var listener := Vector3(14, 1.6, 0)
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
	var physical = _physical_instance(Vector3(-4, 1.2, -4))
	var virtual_inst = _physical_instance(Vector3(-4, 1.2, -4))
	virtual_inst.voice_state = EventInstanceClass.VoiceState.STATE_VIRTUAL
	var non_spatial = _physical_instance(Vector3(-4, 1.2, -4))
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
	var same_room = _physical_instance(Vector3(-4, 1.2, -4))
	dispatcher.process([same_room], Vector3(3.0, 1.2, 3.0))  # oyente en la sala de maquinas
	a.ok(not same_room.room_path_active, "en la misma sala el grafo no gobierna")

	return a
```

Cableala en `tests/test_all.gd` junto a las suites que cuentan aserciones reales:

```gdscript
	var room_path_res = TestRoomPathDispatcherClass.run_all()
	total_tests += room_path_res.assertions_run
	all_failures.append_array(room_path_res.failures)
```

con su `preload` arriba:

```gdscript
const TestRoomPathDispatcherClass = preload("res://tests/test_room_path_dispatcher.gd")
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO por `room_path_dispatcher.gd` inexistente: el `preload` da `Parse Error`, que el runner trata como fatal.

- [ ] **Step 3: Escribe el dispatcher**

Crea `addons/opendou/runtime/spatial/room_path_dispatcher.gd`:

```gdscript
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
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: FALLO todavía, pero **distinto**: las aserciones sobre `room_path_active` y `target_apparent_position` fallan porque esos campos no existen aún en `EventInstance`. Los añade la Tarea 2. Las de la cadena, la caché, el digest y la atenuación **deben pasar ya**.

Si falla `la distancia derivada de la cadena coincide con la del grafo`, la aritmética de `chain_length` está mal: el BFS acumula emisor → p0 → p1 → … → oyente, así que `chain_length` es solo la suma de los tramos **entre** portales.

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/spatial/room_path_dispatcher.gd tests/test_room_path_dispatcher.gd tests/test_all.gd
git commit -m "feat(spatial): add the room path dispatcher with its per-room-pair cache

calculate_acoustic_path() estaba implementado, tenia tests, y se invocaba UNICAMENTE
desde los tests: salas, portales y difraccion de portal estaban calculados y eran
inertes en la cadena de audio. Observacion 35. Esta es la pieza que los conecta.

Dos decisiones sostienen el coste. Solo mira las voces FISICAS, porque una voz virtual
no suena y calcular su filtro es trabajo tirado. Y cachea por PAR DE SALAS: medido, un
recorrido cuesta 2.9 us con un portal, asi que hacerlo por voz y por frame costaria
0.78 ms con 200 voces y duplicaria el coste del motor entero, que son 0.77 ms.

Lo que se cachea es la CADENA de portales y no el camino entero: el AcousticPath incluye
virtual_distance, que depende de la posicion del emisor, y cachearlo tal cual daria a las
200 voces la distancia de la primera. El test comprueba que la distancia derivada de la
cadena coincide con la que devuelve el grafo.

La cache se invalida con un digest de los open_factor calculado UNA vez por frame, no por
voz, y eso cubre tambien que se abra un portal que no estaba en ningun camino cacheado.

La atenuacion acota su divisor a 0.5 m: sin ese suelo, un oyente plantado en el portal
divide por cero y la voz se apaga justo cuando deberia oirse mejor."
```

---
## Task 2: La instancia lleva su posición aparente

**Files:**
- Modify: `addons/opendou/runtime/event_instance.gd`
- Modify: `tests/test_room_path_dispatcher.gd`

**Interfaces:**
- Produces: en `EventInstance`, tres campos nuevos: `room_path_active: bool = false`, `target_apparent_position: Vector3`, `current_apparent_position: Vector3`, más `apparent_smoothing_speed: float = 8.0`.
- Consumes: el dispatcher de la Tarea 1, que escribe `room_path_active` y `target_apparent_position`.

**Por qué se suaviza.** Al cruzar la escotilla, la posición aparente pasa del portal al emisor real. Si salta, se oye el chasquido del paneo. Se interpola con limitación de pendiente, igual que ya se hace con el filtro de oclusión.

**Y por qué el destino se fija también para las voces que el grafo NO gobierna.** El dispatcher solo mira las físicas. Si nadie fijara el destino de las demás, una voz que deja de estar gobernada se quedaría con la posición del portal para siempre. `update_parameters()` lo fija a la posición real cuando `room_path_active` es falso, que es una asignación por voz y por frame: barata y correcta para todas.

- [ ] **Step 1: Escribe el test que falla**

Añade a `tests/test_room_path_dispatcher.gd`, dentro de `run_all()` y antes del `return`:

```gdscript
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
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO por `current_apparent_position` inexistente, que el runner marca como `SCRIPT ERROR` fatal.

- [ ] **Step 3: Añade los campos y el suavizado**

En `addons/opendou/runtime/event_instance.gd`, junto a los campos espaciales, añade:

```gdscript
## True mientras el grafo de salas y portales gobierne esta voz.
##
## Cuando lo esta, la oclusion por raycast NO la toca: el grafo ya sabe que hay un
## mamparo y por donde se rodea, y sumar los dos cobraria dos veces por la misma pared.
var room_path_active: bool = false

## Posicion hacia la que se interpola la posicion aparente.
var target_apparent_position: Vector3 = Vector3.ZERO

## Posicion que se pasa al canal fisico.
##
## Es la del emisor casi siempre. Cuando el grafo gobierna la voz es la del portal por el
## que sale el sonido, que es lo que hace que se oiga VINIENDO de la escotilla en lugar
## de atravesando el mamparo.
var current_apparent_position: Vector3 = Vector3.ZERO

## Velocidad de convergencia de la posicion aparente, en unidades de 1/s.
##
## Existe porque al cruzar el portal la posicion aparente pasa del portal al emisor: si
## saltara, se oiria el chasquido del paneo.
var apparent_smoothing_speed: float = 8.0
```

En `_init()`, tras el bloque que fija `emitter_position`:

```gdscript
	# La posicion aparente arranca donde el emisor. Sin esto cada voz nueva barreria
	# desde el origen del mundo hasta su sitio, y eso se oye.
	target_apparent_position = emitter_position
	current_apparent_position = emitter_position
```

En `set_position()`:

```gdscript
func set_position(pos: Vector3) -> void:
	emitter_position = pos
	has_spatial_position = true
	if not room_path_active:
		target_apparent_position = pos
		current_apparent_position = pos
```

Y en `update_parameters()`, justo después del bloque que actualiza `emitter_position` desde el nodo llamante:

```gdscript
	# El destino se fija aqui para las voces que el grafo NO gobierna: el dispatcher solo
	# mira las fisicas, asi que sin esto una voz que deja de estar gobernada se quedaria
	# con la posicion del portal para siempre.
	if not room_path_active:
		target_apparent_position = emitter_position
	current_apparent_position = current_apparent_position.lerp(
		target_apparent_position,
		clampf(apparent_smoothing_speed * delta, 0.0, 1.0)
	)
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Todas las aserciones de la Tarea 1 y de esta pasan; el grafo todavía no está cableado al bucle, así que las demos no cambian.

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/event_instance.gd tests/test_room_path_dispatcher.gd
git commit -m "feat(runtime): give each voice an apparent position, smoothed

Tres campos nuevos en EventInstance: si el grafo la gobierna, hacia donde se interpola su
posicion aparente, y donde esta ahora.

Se interpola en lugar de saltar porque al cruzar el portal la posicion aparente pasa del
portal al emisor real, y un salto se oye como un chasquido en el paneo.

Arranca en la posicion del emisor y no en el origen del mundo: sin eso, cada voz nueva
barreria desde (0,0,0) hasta su sitio, y eso tambien se oye. Lo comprueba una asercion.

El destino se fija tambien para las voces que el grafo no gobierna, porque el dispatcher
solo mira las fisicas: sin ello, una voz que deja de estar gobernada se quedaria con la
posicion del portal para siempre."
```

---

## Task 3: El paso en el bucle, y la oclusión se aparta

**Files:**
- Modify: `addons/opendou/runtime/audio_event_manager.gd`
- Modify: `addons/opendou/runtime/spatial/occlusion_scheduler.gd`
- Modify: `tests/test_room_path_dispatcher.gd`

**Interfaces:**
- Produces: `AudioEventManager.room_path_dispatcher: OpenDouRoomPathDispatcher` (creado en `_init()`, con `acoustics` ya asignado).
- Consumes: `OpenDouRoomPathDispatcher.process()` (Tarea 1) y los campos de `EventInstance` (Tarea 2).

**El orden importa y no es cosmético.** El paso va **antes** de la oclusión, para que la oclusión pueda saltarse las voces gobernadas. Eso evita cobrar dos veces por el mismo mamparo y, de paso, **libera presupuesto de raycasts** para las voces que sí lo necesitan.

- [ ] **Step 1: Escribe el test que falla**

Añade a `tests/test_room_path_dispatcher.gd` una función nueva, y cableala desde `run_async_suite()` de `tests/test_all.gd`:

```gdscript
## El paso dentro del bucle, y que la oclusion se aparta de las voces gobernadas.
static func run_wiring_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("room_path_wiring")

	var ManagerClass = load("res://addons/opendou/runtime/audio_event_manager.gd")
	var manager = ManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	a.ok(manager.room_path_dispatcher != null, "el manager trae dispatcher de caminos")
	a.ok(manager.room_path_dispatcher.acoustics == manager.spatial_acoustics,
		"y comparte el manager espacial, no una copia")

	# Sin salas registradas, cero recorridos: es el caso de «El monzon».
	var tone := load("res://addons/opendou/runtime/audio_synthesizer.gd").create_tone(300.0, 1.0, 0.6, false)
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
	a.gt(float(manager.room_path_dispatcher.traversals_this_frame), 0.0,
		"y con salas registradas el grafo si se recorre")
	a.approx(inside.target_apparent_position.x, 7.0,
		"su posicion aparente es la del portal", 0.01)

	# La oclusion no la cuenta entre sus candidatas: sin esto, el mismo mamparo se
	# cobraria dos veces y el presupuesto de raycasts se gastaria en voces ya resueltas.
	var scheduler = manager.occlusion_scheduler
	var vp := manager.get_viewport()
	var w3d: World3D = vp.find_world_3d() if vp != null else null
	var raycasts: int = scheduler.process([inside], Vector3(14.0, 1.6, 0.0), w3d)
	a.eq(raycasts, 0, "la oclusion no gasta raycasts en una voz que gobierna el grafo")

	# Y en cuanto deja de estar gobernada, la oclusion vuelve a atenderla.
	inside.room_path_active = false
	var raycasts_again: int = scheduler.process([inside], Vector3(14.0, 1.6, 0.0), w3d)
	a.gt(float(raycasts_again), 0.0, "sin gobierno del grafo, la oclusion la atiende")

	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	return a
```

Añade sus dos `preload` al principio del archivo si no están: `AudioRoomClass` y `AudioPortalClass` ya lo están de la Tarea 1.

En `tests/test_all.gd`:

```gdscript
	acc.absorb(await TestRoomPathDispatcherClass.run_wiring_async(tree))
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `el manager trae dispatcher de caminos`, y `SCRIPT ERROR` en la línea siguiente por acceder a `.acoustics` sobre `null`.

- [ ] **Step 3: Crea el dispatcher en el manager**

En `addons/opendou/runtime/audio_event_manager.gd`, añade el `preload` junto a los demás:

```gdscript
const RoomPathDispatcherClass = preload("res://addons/opendou/runtime/spatial/room_path_dispatcher.gd")
```

Un campo, junto a `occlusion_scheduler`:

```gdscript
## Aplica el grafo de salas y portales a las voces fisicas.
##
## Antes de esto, salas y portales se calculaban y no llegaban a ninguna voz.
var room_path_dispatcher: OpenDouRoomPathDispatcher = null
```

Y en `_init()`, tras crear `occlusion_scheduler`:

```gdscript
	room_path_dispatcher = RoomPathDispatcherClass.new()
	room_path_dispatcher.acoustics = spatial_acoustics
```

- [ ] **Step 4: Mete el paso en el bucle, antes de la oclusión**

En `_process()`, **antes** del bloque de la oclusión, añade:

```gdscript
	# 3b. Camino por salas y portales. Va ANTES de la oclusion para que la oclusion pueda
	# saltarse las voces que el grafo gobierna: sin eso, el mismo mamparo se cobraria dos
	# veces y el presupuesto de raycasts se gastaria en voces ya resueltas.
	if room_path_dispatcher != null:
		room_path_dispatcher.process(active_instances, active_listener_position)
```

Y en `_apply_voices()`, sustituye la posición que se pasa al canal:

```gdscript
		ch.apply(
			volume_db,
			instance.calculated_pitch_scale,
			cutoff,
			instance.current_apparent_position
		)
```

`current_apparent_position` es igual a `emitter_position` salvo cuando el grafo gobierna la voz, así que no hace falta ninguna rama aquí.

- [ ] **Step 5: La oclusión se aparta**

En `addons/opendou/runtime/spatial/occlusion_scheduler.gd`, dentro del bucle de elegibles:

```gdscript
	for inst in instances:
		if inst == null or not inst.has_spatial_position:
			continue
		# Las voces que gobierna el grafo de salas ya tienen su filtro y su atenuacion:
		# volver a calcularlas cobraria dos veces por el mismo mamparo, y gastaria
		# raycasts que otras voces si necesitan.
		if inst.room_path_active:
			continue
		var lod: int = lod_controller.get_lod_level(inst.emitter_position.distance_to(listener_pos))
```

- [ ] **Step 6: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK.

Si falla `su posicion aparente es la del portal`, comprueba que `set_listener_position()` se llamó **antes** de los frames de espera: el dispatcher usa `active_listener_position`, que el paso 1 del bucle resuelve cada frame y que un override fija.

Si alguna suite de audio preexistente empieza a fallar, mira si su escena tiene salas registradas: una voz que antes gobernaba la oclusión puede haber pasado a gobernarla el grafo. **Eso es el arreglo funcionando**, y lo que hay que revisar es la aserción, no el motor.

- [ ] **Step 7: Commit**

```bash
git add addons/opendou/runtime/audio_event_manager.gd addons/opendou/runtime/spatial/occlusion_scheduler.gd tests/test_room_path_dispatcher.gd tests/test_all.gd
git commit -m "feat(runtime): wire the room path into the frame loop

El paso va ANTES de la oclusion, y el orden no es cosmetico: asi la oclusion puede
saltarse las voces que el grafo gobierna. Sin eso, el mismo mamparo se cobraria dos veces
-una por el raycast y otra por el portal- y sonaria a barro, y ademas se gastarian
raycasts en voces ya resueltas. Ahora ese presupuesto queda para las que si lo necesitan,
y un test lo comprueba en las dos direcciones.

_apply_voices() pasa al canal la posicion aparente en lugar de la del emisor. No hace
falta ninguna rama: la aparente es igual a la real salvo cuando el grafo gobierna la voz.

Con cero salas registradas el grafo no se recorre ni una vez, que es el caso de una escena
al aire libre y esta afirmado."
```

---
## Task 4: Que se oiga, afirmado con audio real

**Files:**
- Create: `tests/test_portal_audio.gd`
- Modify: `scenes/demos/keel/keel_demo.gd`
- Modify: `tests/test_demo_scenes.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `KeelDemo.VALVE_BUS: StringName = &"KeelValve"` y `KeelDemo.valve_bus: StringName`.
- Consumes: todo lo anterior.

**Esta tarea es la que cierra el criterio 1 del spec**, y también borra una deuda propia: la aserción que la Fase 5 escribió para la escotilla comprobaba que `get_diffraction_lpf()` devolvía otro número. Es una aserción de propiedad — comprobaba que un cálculo cambiaba, no que el sonido cambiara. **Se sustituye, no se conserva «por si acaso».**

**El tono del test controlado es agudo a propósito.** El corte del portal cerrado baja a 200 Hz; con un zumbido grave, filtrarlo no quitaría casi energía y la aserción sería débil. Con un tono de 3000 Hz la caída es decisiva.

- [ ] **Step 1: La válvula necesita su propio bus**

En `scenes/demos/keel/keel_demo.gd`, añade el `preload` de `DemoAudio` si no está —ya está— y la constante junto a las demás:

```gdscript
## Bus de la valvula. Existe para poder MEDIRLA: en Master se mezcla con las pisadas y
## el resto, y la asercion de la escotilla no distinguiria su caida.
const VALVE_BUS: StringName = &"KeelValve"
```

Un campo junto a los demás:

```gdscript
var valve_bus: StringName = VALVE_BUS
```

Y en `_build_valve()`, antes de registrar la definición:

```gdscript
	valve_bus = DemoAudioClass.ensure_bus(VALVE_BUS)
	def.target_bus = valve_bus
```

- [ ] **Step 2: Escribe el test que falla**

Crea `tests/test_portal_audio.gd`:

```gdscript
class_name TestPortalAudio
extends RefCounted

## Que cerrar un portal se OIGA, con geometria controlada.
##
## Sustituye a la asercion que la Fase 5 escribio para la escotilla, que comprobaba que
## get_diffraction_lpf() devolvia otro numero: una asercion de propiedad, que comprobaba
## que un calculo cambiaba y no que el sonido cambiara.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")

## Dos salas contiguas unidas por un portal, y un oyente real.
##
## El tono es AGUDO a proposito: el corte del portal cerrado baja a 200 Hz, y con un
## zumbido grave filtrarlo no quitaria casi energia y la asercion seria debil.
static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("portal_audio")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	var ac = manager.spatial_acoustics
	var specs := [
		{"name": &"RoomA", "center": Vector3(0, 2, 0), "size": Vector3(12, 5, 12)},
		{"name": &"RoomB", "center": Vector3(14, 2, 0), "size": Vector3(12, 5, 12)},
	]
	for spec in specs:
		var room = AudioRoomClass.new()
		room.room_name = spec["name"]
		room.set_bounds(AABB(spec["center"] - spec["size"] * 0.5, spec["size"]))
		ac.register_room(room)
	var portal = AudioPortalClass.new(&"Gap", &"RoomA", &"RoomB", Vector3(7.0, 1.5, 0.0), 1.0)
	ac.register_portal(portal)

	# Un AudioStreamPlayer3D sin oyente activo no emite nada, asi que hace falta uno de
	# verdad y no solo un override de posicion.
	var camera := Camera3D.new()
	camera.position = Vector3(14.0, 1.6, 0.0)  # RoomB
	tree.root.add_child(camera)
	camera.make_current()
	var listener := AudioListener3D.new()
	listener.position = Vector3(14.0, 1.6, 0.0)
	tree.root.add_child(listener)
	listener.make_current()
	await tree.process_frame

	var tone := AudioSynthesizerClass.create_tone(3000.0, 2.0, 0.9, false)
	var def = AudioEventDefClass.new(&"PortalTone", tone)
	def.is_looping = true
	def.stream_length = 2.0
	def.base_volume_db = 0.0
	def.target_bus = probe.bus_name()
	manager.register_event_definition(def)

	var instance = manager.post_event(&"PortalTone", null)
	instance.set_position(Vector3(-3.0, 1.5, 0.0))  # RoomA
	instance.max_distance = 200.0
	for i in range(8):
		await tree.process_frame

	# ---- 1. Portal ABIERTO: se oye a traves del hueco.
	portal.open_factor = 1.0
	for i in range(12):
		await tree.process_frame
	probe.drain()
	var peak_open: float = await probe.measure_peak_over_frames(tree, 40)
	a.gt(peak_open, 0.001, "con el portal abierto el tono se oye desde la otra sala")
	a.ok(instance.room_path_active, "y la voz esta gobernada por el grafo")

	# ---- 2. Portal CERRADO: cae al menos a la mitad.
	portal.open_factor = 0.02
	# El filtro se suaviza, asi que hay que dejarlo converger: contar dos frames medirian
	# el valor viejo.
	for i in range(40):
		await tree.process_frame
	probe.drain()
	var peak_closed: float = await probe.measure_peak_over_frames(tree, 40)
	a.lt(peak_closed, peak_open * 0.5, "cerrar el portal hunde el tono a la mitad o menos")

	# ---- 4. La posicion aparente esta MAS CERCA DEL PORTAL que del emisor.
	portal.open_factor = 1.0
	for i in range(40):
		await tree.process_frame
	var dist_to_portal: float = instance.current_apparent_position.distance_to(Vector3(7.0, 1.5, 0.0))
	var dist_to_emitter: float = instance.current_apparent_position.distance_to(Vector3(-3.0, 1.5, 0.0))
	a.lt(dist_to_portal, dist_to_emitter,
		"la posicion que llega al canal esta mas cerca del portal que del emisor")

	# ---- 3 y 5. MISMA SALA: el grafo no gobierna y el portal no cambia nada.
	# Es la asercion que impide que 1 y 2 pasen con una implementacion que apague todo
	# indiscriminadamente.
	camera.position = Vector3(-1.0, 1.6, 0.0)   # RoomA, con el emisor
	listener.position = Vector3(-1.0, 1.6, 0.0)
	for i in range(40):
		await tree.process_frame
	a.ok(not instance.room_path_active, "en la misma sala el grafo no gobierna la voz")
	a.approx(instance.current_apparent_position.x, -3.0,
		"y la posicion que llega al canal es la del emisor", 0.2)

	probe.drain()
	var same_open: float = await probe.measure_peak_over_frames(tree, 40)
	portal.open_factor = 0.02
	for i in range(40):
		await tree.process_frame
	probe.drain()
	var same_closed: float = await probe.measure_peak_over_frames(tree, 40)
	a.gt(same_open, 0.001, "en la misma sala el tono se oye")
	a.lt(absf(same_closed - same_open), same_open * 0.2,
		"y cerrar el portal lo deja dentro de un 20 %: el grafo no gobierna donde no debe")

	manager.stop_all()
	probe.teardown()
	listener.clear_current()
	camera.clear_current()
	tree.root.remove_child(listener); listener.free()
	tree.root.remove_child(camera); camera.free()
	tree.root.remove_child(manager); manager.free()
	return a
```

Cableala en `run_async_suite()` de `tests/test_all.gd` con su `preload`.

- [ ] **Step 3: Sustituye la aserción de propiedad de la Fase 5**

En `tests/test_demo_scenes.gd`, dentro de `run_keel_async()`, **borra** este bloque:

```gdscript
	# Cerrar la escotilla baja el corte de difraccion del camino directo.
	demo.hatch_open_factor = 1.0
	var lpf_open: float = demo.hatch.get_diffraction_lpf()
	demo.hatch_open_factor = 0.05
	var lpf_closed: float = demo.hatch.get_diffraction_lpf()
	a.lt(lpf_closed, lpf_open * 0.5, "cerrar la escotilla baja el corte de difraccion")
	a.approx(demo.hatch.runtime_portal.open_factor, 0.05,
		"asignar hatch_open_factor propaga al portal en runtime", 0.001)
```

y pon en su lugar:

```gdscript
	# LA ESCOTILLA, oida de verdad. La version anterior de esta asercion comprobaba que
	# get_diffraction_lpf() devolvia otro numero: comprobaba que un calculo cambiaba, no
	# que el sonido cambiara, y por eso pulsar E no se oia y los tests pasaban.
	#
	# El jugador se lleva al pasillo, que es la otra sala: es donde la escotilla importa.
	var keel_player = demo.get_node_or_null("Player")
	a.ok(keel_player != null, "la demo trae jugador con oyente")
	keel_player.global_position = Vector3(14.0, 1.0, 0.0)
	await tree.physics_frame

	var valve_probe = OpenDouAudioProbeClass.new()
	a.ok(valve_probe.attach_to_existing_bus(demo.valve_bus, 2.0),
		"la sonda se engancha al bus de la valvula")

	demo.hatch_open_factor = 1.0
	for i in range(40):
		await tree.process_frame
	valve_probe.drain()
	var hatch_open_peak: float = await valve_probe.measure_peak_over_frames(tree, 40)
	a.gt(hatch_open_peak, 0.001, "con la escotilla abierta la valvula se oye desde el pasillo")

	demo.hatch_open_factor = 0.02
	for i in range(40):
		await tree.process_frame
	valve_probe.drain()
	var hatch_closed_peak: float = await valve_probe.measure_peak_over_frames(tree, 40)
	a.lt(hatch_closed_peak, hatch_open_peak * 0.5,
		"y cerrarla la hunde a la mitad o menos: la tecla E se OYE")

	a.approx(demo.hatch.runtime_portal.open_factor, 0.02,
		"asignar hatch_open_factor propaga al portal en runtime", 0.001)
	valve_probe.teardown()
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK.

Diagnóstico por aserción, si alguna falla:

- `con el portal abierto el tono se oye desde la otra sala` en cero → no hay oyente activo, o la voz no llegó a física. Comprueba `instance.assigned_channel_id >= 0`.
- `y la voz esta gobernada por el grafo` en falso → las salas no tienen `bounds`. `AudioRoom.contains_point()` devuelve `false` mientras `has_bounds` sea falso, así que `set_bounds()` es obligatorio.
- `cerrar el portal hunde el tono a la mitad o menos` sin caída → mira si el suavizado del filtro llegó a converger; sube los frames de espera antes de medir, nunca bajes el umbral.
- `cerrar el portal lo deja dentro de un 20 %` fallando → el grafo está gobernando una voz de la misma sala. Es el bug que esa aserción existe para cazar.
- En la demo, `con la escotilla abierta la valvula se oye desde el pasillo` en cero → comprueba que el bus `KeelValve` existe y que `def.target_bus` se fijó **antes** de registrar la definición.

- [ ] **Step 5: Commit**

```bash
git add tests/test_portal_audio.gd scenes/demos/keel/keel_demo.gd tests/test_demo_scenes.gd tests/test_all.gd
git commit -m "test(spatial): assert that closing a portal is AUDIBLE

Cinco aserciones que sustituyen a la de propiedad que la Fase 5 escribio para la
escotilla. Esa comprobaba que get_diffraction_lpf() devolvia otro numero: comprobaba que
un calculo cambiaba, no que el sonido cambiara, y por eso pulsar E no se oia mientras los
tests pasaban en verde. Se sustituye, no se conserva por si acaso.

Con geometria controlada -dos salas, un portal, un oyente real-: con el portal abierto el
tono se oye desde la otra sala, cerrarlo lo hunde a la mitad o menos, y la posicion que
llega al canal esta mas cerca del portal que del emisor.

Y la asercion que impide que las dos primeras pasen con una implementacion que apague
todo indiscriminadamente: con el oyente en la MISMA sala que el emisor, cerrar el portal
deja el pico dentro de un 20 % y la posicion que llega al canal es la del emisor.

El tono del test es agudo a proposito: el corte del portal cerrado baja a 200 Hz, y con un
zumbido grave filtrarlo no quitaria casi energia y la asercion seria debil.

La valvula de «Bajo la quilla» pasa a tener su propio bus, porque en Master se mezcla con
las pisadas y la caida no se distinguiria."
```

---

## Task 5: El coste medido y el techo escrito

**Files:**
- Modify: `tests/test_room_path_dispatcher.gd`
- Modify: `tests/test_demo_scenes.gd`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: todo lo anterior.

**Cierra los criterios 5 y 7 del spec.** La guarda cuenta recorridos y no milisegundos: un test de tiempo sería frágil entre máquinas, y lo que hay que impedir es que la versión ingenua vuelva a colarse, que es exactamente lo que un conteo detecta.

- [ ] **Step 1: Escribe la guarda que falla**

Añade a `tests/test_room_path_dispatcher.gd` y cableala en `run_async_suite()`:

```gdscript
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

	var tone := load("res://addons/opendou/runtime/audio_synthesizer.gd").create_tone(500.0, 1.0, 0.5, false)
	var def = AudioEventDefClass.new(&"BudgetProbe", tone)
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)

	# 200 voces repartidas por las tres salas.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in range(200):
		var inst = manager.post_event(def, null)
		if inst == null:
			break
		var room_index: int = i % 3
		inst.set_position(Vector3(
			float(room_index) * 22.0 + rng.randf_range(-8.0, 8.0),
			1.5,
			rng.randf_range(-8.0, 8.0)
		))
	for i in range(10):
		await tree.process_frame

	a.gt(float(manager.active_instances.size()), 150.0, "hay mas de 150 instancias activas")

	# LA GUARDA. Con tres salas hay nueve pares ordenados como techo absoluto.
	var max_traversals: int = 0
	for i in range(30):
		await tree.process_frame
		max_traversals = maxi(max_traversals, manager.room_path_dispatcher.traversals_this_frame)
	a.lt(float(max_traversals), 10.0,
		"con 200 voces y tres salas el grafo se recorre como mucho 9 veces por frame")

	# Y no es cero por accidente: la cache tiene que estar sirviendo aciertos.
	a.gt(float(manager.room_path_dispatcher.cache_hits_this_frame), 0.0,
		"la cache esta sirviendo aciertos, asi que el conteo bajo no es porque no se use")

	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	return a
```

- [ ] **Step 2: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Si `el grafo se recorre como mucho 9 veces por frame` falla con un número cercano al de voces gobernadas, la caché no está funcionando: comprueba que la clave es el **par de salas** y no incluye la posición.

- [ ] **Step 3: Mide el coste añadido**

Escribe `tests/_bench_fase6.gd` **temporalmente** (no se commitea) y ejecútalo:

```gdscript
extends SceneTree

const ManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const DefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const SynthClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const RoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const PortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	for with_rooms in [false, true]:
		var manager = ManagerClass.new()
		root.add_child(manager)
		await process_frame
		if with_rooms:
			var ac = manager.spatial_acoustics
			var specs := [
				{"n": &"R1", "c": Vector3(0, 2, 0), "s": Vector3(20, 6, 20)},
				{"n": &"R2", "c": Vector3(22, 2, 0), "s": Vector3(20, 6, 20)},
				{"n": &"R3", "c": Vector3(44, 2, 0), "s": Vector3(20, 6, 20)},
			]
			for spec in specs:
				var room = RoomClass.new()
				room.room_name = spec["n"]
				room.set_bounds(AABB(spec["c"] - spec["s"] * 0.5, spec["s"]))
				ac.register_room(room)
			ac.register_portal(PortalClass.new(&"P12", &"R1", &"R2", Vector3(11, 1.5, 0), 1.0))
			ac.register_portal(PortalClass.new(&"P23", &"R2", &"R3", Vector3(33, 1.5, 0), 1.0))

		var tone := SynthClass.create_tone(500.0, 1.0, 0.5, false)
		var def = DefClass.new(&"Bench", tone)
		def.is_looping = true
		def.stream_length = 1.0
		manager.register_event_definition(def)

		var rng := RandomNumberGenerator.new()
		rng.seed = 31
		for i in range(200):
			var inst = manager.post_event(def, null)
			if inst == null:
				break
			inst.set_position(Vector3(float(i % 3) * 22.0 + rng.randf_range(-8, 8), 1.5, rng.randf_range(-8, 8)))
		for i in range(10):
			await process_frame

		var iters: int = 20
		var t0: int = Time.get_ticks_usec()
		for i in range(iters):
			manager._process(0.016)
		var per_call: float = float(Time.get_ticks_usec() - t0) / float(iters)
		print("%s | %d instancias | %.3f ms por frame" % [
			"con salas " if with_rooms else "sin salas ", manager.active_instances.size(), per_call / 1000.0])

		manager.stop_all()
		root.remove_child(manager)
		manager.free()
		await process_frame
	quit()
```

Ejecútalo con:

```bash
/Users/Daniel/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/_bench_fase6.gd
```

y bórralo después. Apunta los dos números.

**Criterio 5 del spec:** si el coste con salas supera el **+10 %** sobre el coste sin salas, la implementación está mal y hay que revisar la caché **antes** de seguir. La referencia medida antes de esta fase es 0.77 ms con 200 voces.

- [ ] **Step 4: Comprueba que «El monzón» no cambió (criterio 4 del spec)**

La demo del monzón no registra ninguna sala, así que el paso nuevo no debe tocarla ni
costarle nada. Añade la aserción a `run_monsoon_async()` en `tests/test_demo_scenes.gd`,
justo después del bloque de la telemetría:

```gdscript
	# Criterio 4 de la Fase 6: la escena no registra salas, asi que el grafo de portales
	# no puede tocarla. Si algun dia alguien le anade un Room3D, esta asercion cae y hay
	# que decidirlo a proposito en lugar de descubrirlo por el coste.
	a.eq(manager.room_path_dispatcher.traversals_this_frame, 0,
		"«El monzon» no registra salas, asi que el grafo no se recorre ni una vez")
	var governed_count: int = 0
	for inst in manager.active_instances:
		if inst != null and inst.room_path_active:
			governed_count += 1
	a.eq(governed_count, 0, "y ninguna de sus voces queda gobernada por el grafo")
```

- [ ] **Step 5: Escribe el techo en `AGENTS.md`**

En la sección `## 5b. Trampas del motor descubiertas en la Fase 5`, añade al final:

```markdown
**El techo de voces, medido (Fase 6).** El bucle de OpenDou cuesta **3.9 µs por voz y
frame** en la máquina de desarrollo. Mantenerlo por debajo de 1 ms son **~256 voces**;
por debajo de 2 ms, **~512**. En una máquina 3–5× más lenta esas cifras se dividen
igual. «Cientos de voces» se sostiene con margen; **«miles» no, y no debe afirmarse en
la documentación.** El techo no lo pone ninguna feature: lo pone que el motor sea
GDScript.

Antes de añadir trabajo por voz y por frame, mídelo. La regla que salió de la Fase 6:
**solo las voces físicas** —una voz virtual no suena, así que calcular su filtro es
trabajo tirado— y **cachea por lo que de verdad varía**, no por voz. Esas dos decisiones
bajaron el paso del grafo de salas de un +100 % a un +3 %.
```

- [ ] **Step 6: Ejecuta la suite completa y commitea**

Run: `./run_tests.sh`

Expected: OK.

```bash
git add tests/test_room_path_dispatcher.gd tests/test_demo_scenes.gd AGENTS.md
git commit -m "test(spatial): guard the room path cost by counting traversals, and record the ceiling

La guarda cuenta RECORRIDOS y no milisegundos: un test de tiempo seria fragil entre
maquinas, y lo que hay que impedir es que vuelva la version ingenua -un recorrido por voz
y por frame-, que es exactamente lo que un conteo detecta. Con 200 voces y tres salas el
grafo se recorre como mucho nueve veces por frame, y se afirma tambien que la cache sirve
aciertos, para que un conteo bajo no pueda venir de que no se use.

Queda escrito en AGENTS.md el techo real del plugin, que el proyecto no tenia anotado en
ninguna parte: 3.9 us por voz y frame, ~256 voces por debajo de 1 ms, ~512 por debajo de
2 ms, y en maquina 3-5x mas lenta divididas igual. "Cientos de voces" se sostiene;
"miles" no, y no debe afirmarse en la documentacion.

Y la regla que salio de esta fase: antes de anadir trabajo por voz y por frame, midelo.
Solo las voces fisicas, y cachea por lo que de verdad varia. Esas dos decisiones bajaron
este paso de un +100 % a un +3 %."
```

---

## Notas para quien ejecute el plan

**El orden de las cinco tareas no es negociable.** La 1 y la 2 construyen las piezas sin
tocar el bucle, así que la suite sigue verde y las demos no cambian. La 3 las conecta. La
4 es la única que puede afirmar que se oye. La 5 mide y escribe.

**Lo que se aprendió antes y aplica aquí:**

- Un `AudioStreamPlayer3D` sin `Camera3D` ni `AudioListener3D` activo **no emite nada**.
  Un override de posición de oyente sirve al motor de OpenDou, **no a Godot**: para medir
  audio hace falta un oyente de verdad.
- Una cámara con `make_current()` sigue referenciada por el viewport: `clear_current()`
  antes de liberarla o queda una fuga que el trinquete cuenta.
- **No contar frames fijos para afirmar silencio.** En headless el bucle corre a máxima
  velocidad; usa `await_silence()`, y sube su `consecutive` si mides contra una cola.
- **`AudioRoom.contains_point()` devuelve `false` mientras `has_bounds` sea falso.**
  `set_bounds()` es obligatorio, y es lo primero que hay que mirar si una voz no queda
  gobernada.
- Una aserción de audio puede pasar sin probar lo que dice. **Muta el código y comprueba
  que falla.** Si no falla, no afirma lo que crees. En esta fase, las mutaciones que
  importan son: quitar la aplicación del filtro (deben fallar las aserciones 1-2 y
  sobrevivir la 3) y quitar la caché (debe fallar la guarda de recorridos).

**Dos cosas que este plan deja anotadas y NO arregla**, para que no se cuelen:

1. **El acoplamiento de reverb entre salas** (`reverb_send_factor` de
   `evaluate_acoustic_path`): que un sonido de otra sala alimente el reverb de la sala del
   oyente a través del portal. Toca los buses de reverb del pool y merece su fase.
2. **`EdgeDiffractionEngine`** es otro subsistema igualmente inerte: está implementado,
   nadie lo invoca desde el runtime. Es la observación 36 y no se toca aquí.

**Qué queda pendiente después de esta fase:** los puntos 1, 2 y 4 acordados con el
usuario —recomponer las cuatro escenas como árboles de nodos, la regla de composición con
su guarda, y el HUD de controles y cobertura—, que van sin spec ni plan por decisión suya.
Y la Fase 4B, el prefijado con `OpenDou`.
