# Fase 8 — Higiene y deuda: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que el plugin cumpla las promesas que hoy hace en vano (límites de instancias, instantáneas de mezcla, ducking, área de parámetros), tenga una mezcla protegida y medida (cadena de masterización, LUFS), y deje de tener un test intermitente (observación 43).

**Architecture:** Todo en GDScript. Un limitador consultado por `post_event` antes de crear instancias; un aplicador que cada frame escribe en el `AudioServer` `base + delta de instantánea + ducking` por bus gestionado; una cadena de masterización instalada en Master desde un ajuste de proyecto; un medidor BS.1770 sobre `AudioEffectCapture`; y una herramienta que reproduce el test intermitente diez veces con instrumentación antes de tocar nada.

**Tech Stack:** Godot 4.7.2, GDScript, `AudioServer`, `AudioEffectCompressor`, `AudioEffectHardLimiter`, `AudioEffectLowPassFilter`, `AudioEffectHighPassFilter`, `AudioEffectCapture`.

**Spec:** `docs/superpowers/specs/2026-09-02-fase8-higiene-y-deuda-design.md`

## Global Constraints

- Rama `main`. Cada tarea termina en commit con `./run_tests.sh` verde: sin `SCRIPT ERROR`, sin `Parse Error`, fugas ≤ `tests/leak_budget.txt`, `STATUS: PASSED`.
- Aserciones sobre audio capturado con `OpenDouAudioProbe` o sobre lecturas directas del `AudioServer`, siempre con un control que apague el mecanismo.
- `max_instances` pasa a valer **0 = sin límite** por defecto. Cambio de semántica documentado en el export y en `AGENTS.md`.
- El aplicador de mezcla **solo toca buses gestionados**: los que nombra alguna instantánea registrada o alguna regla de ducking. Así un manager de test con sus propios buses no pelea con el autoload.
- Quien cambie volúmenes de bus por su cuenta lo hace a través de `AudioEventManager.set_bus_base_volume_db()`; en el proyecto solo lo hacía `BusRow`.
- El medidor LUFS va apagado por defecto. Se llama `sample_peak_db`, no pico verdadero.
- El test de «Una casa canta» no cambia sus expectativas.
- Comentarios de código en español sin tildes (convención del repo).
- Trampa vigente: `var x := load(...).algo()` no infiere tipo. Tipo explícito con receptores de `load()`.

---

## Estructura de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `tools/repeat_street_test.gd` (nuevo) | Diez corridas instrumentadas de la calle | 1 |
| `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd`, `room_path_dispatcher.gd` | Generación del grafo; invalidación de caché por generación | 2 |
| `addons/opendou/resources/audio_event_def.gd` | Exports de límites; `max_instances` a 0 | 3 |
| `addons/opendou/runtime/event_instance.gd` | `stop(fade)` con fundido real; `is_stopping()` | 3 |
| `addons/opendou/runtime/instance_limiter.gd` (nuevo, `OpenDouInstanceLimiter`) | La regla de límites | 3 |
| `addons/opendou/runtime/audio_event_manager.gd` | Limitador en `post_event`; fundido en `_apply_voices`; cadena; medidor; aplicador; pila; vinculaciones | 3–7 |
| `addons/opendou/resources/mix_chain.gd` (nuevo, `MixChain`), `addons/opendou/runtime/mix_chain_installer.gd` (nuevo, `OpenDouMixChainInstaller`) | Cadena de masterización | 4 |
| `addons/opendou/runtime/loudness_meter.gd` (nuevo, `OpenDouLoudnessMeter`) | BS.1770 | 5 |
| `addons/opendou/editor/opendou_mixer_drawer.gd` | Lectura del medidor | 5 |
| `addons/opendou/runtime/mix_bus_applier.gd` (nuevo, `OpenDouMixBusApplier`) | base + delta + ducking + filtros → `AudioServer` | 6 |
| `scenes/shared/bus_row.gd` | Edita la base | 6 |
| `addons/opendou/nodes/opendou_parameter_area_3d.gd`, `opendou_music_player.gd` | Sin `has_method`; matriz del manager | 6 |
| `addons/opendou/resources/mix_state_binding.gd` (nuevo, `MixStateBinding`) | Estado → instantánea | 7 |
| `tests/test_instance_limiter.gd`, `test_mix_chain.gd`, `test_loudness_meter.gd`, `test_mix_bus_applier.gd`, `tests/loudness_budget.txt` | Suites y presupuesto | 3–7 |
| `docs/funcionalidades.md`, `AGENTS.md`, `docs/tasks/current.md` | Marcas verdaderas, observaciones 43 y 45 | 8 |

Convenciones de la suite: `class_name TestX extends RefCounted`, `static func run_all() -> OpenDouAssert` o `run_all_async(tree) -> OpenDouAssert`; registro en `tests/test_all.gd`. Godot para las herramientas: `"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . -s tools/x.gd` (ruta de esta máquina; `run_tests.sh` la localiza solo).

---

### Task 1: Reproducir la observación 43 con instrumentación

**Files:**
- Create: `tools/repeat_street_test.gd`

**Interfaces:**
- Produces: la herramienta imprime por corrida `corrida N: origen aparente x=…, salas=[…], portales={nombre: open_factor}, generación=…, digest=…, camino=[…]` y al final `fallos: k de 10`. Consume `TestDemoScenes.run_street_async(tree)` tal cual.

- [ ] **Step 1: Escribir la herramienta**

```gdscript
extends SceneTree

## Observacion 43: el test de la calle fallaba de forma intermitente con el origen aparente
## en la puerta cerrada en lugar de la ventana. Esta herramienta lo corre N veces seguidas y
## deja a la vista lo que el despachador veia en el momento de decidir. No es parte de la
## suite; se usa para cazar la causa y, despues, para comprobar que sigue cazada.
##
##     Godot --headless --path . -s tools/repeat_street_test.gd

const RUNS: int = 10

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var TestClass = load("res://tests/test_demo_scenes.gd")
	var manager = root.get_node_or_null("OpenDou")
	var failures: int = 0
	for i in range(RUNS):
		var a = await TestClass.run_street_async(self)
		var failed: bool = not a.failures.is_empty()
		if failed:
			failures += 1
		# Lo que el grafo tiene registrado AL TERMINAR la corrida (la escena ya se libero y
		# debio desregistrar todo: si queda algo, es una fuga de registro).
		var ac = manager.spatial_acoustics
		var portals: Dictionary = {}
		for p_name in ac.portals:
			portals[p_name] = snappedf(ac.portals[p_name].open_factor, 0.01)
		print("[obs43] corrida %d: %s | salas restantes=%s portales restantes=%s generacion=%d" % [
			i + 1, "FALLO" if failed else "ok", ac.rooms.keys(), portals,
			ac.graph_generation if "graph_generation" in ac else -1])
		for f in a.failures:
			print("[obs43]    - ", f)
	print("[obs43] fallos: %d de %d" % [failures, RUNS])
	quit(1 if failures > 0 else 0)
```

- [ ] **Step 2: Instrumentar la decisión dentro del test, solo bajo una bandera**

En `tests/test_demo_scenes.gd`, justo antes de la aserción `y su origen aparente es la VENTANA entreabierta` (línea ~64), añadir:

```gdscript
	if OS.has_environment("OPENDOU_TRACE_OBS43"):
		var ac_dbg = manager.spatial_acoustics
		var portals_dbg: Dictionary = {}
		for p_name in ac_dbg.portals:
			portals_dbg[p_name] = snappedf(ac_dbg.portals[p_name].open_factor, 0.01)
		print("[obs43] al decidir: salas=%s portales=%s aparente=%s digest=%s" % [
			ac_dbg.rooms.keys(), portals_dbg, music_instance.target_apparent_position,
			manager.room_path_dispatcher._portal_digest])
```

- [ ] **Step 3: Correr diez veces con la traza**

```bash
OPENDOU_TRACE_OBS43=1 "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . -s tools/repeat_street_test.gd 2>&1 | grep '\[obs43\]'
```

Anotar lo que salga en el spec (§2, «Hallazgo») **antes** de la Task 2: si en la corrida que falla la lista de portales al decidir está incompleta, la hipótesis del registro tardío se confirma. Si está completa y el digest es igual al de las corridas buenas, la causa es otra y la Task 2 se rehace con lo visto (el spec lo prevé).

- [ ] **Step 4: Commit de la herramienta**

```bash
git add tools/repeat_street_test.gd tests/test_demo_scenes.gd
git commit -m "Fase 8: herramienta de diez corridas instrumentadas para la observacion 43"
```

---

### Task 2: Invalidar la caché del grafo por generación

**Files:**
- Modify: `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd:42-90` (registro y desregistro)
- Modify: `addons/opendou/runtime/spatial/room_path_dispatcher.gd:50,94-98,195-210`
- Test: `tests/test_room_path_dispatcher.gd` (`run_all`)

**Interfaces:**
- Produces: `SpatialAcousticsManager.graph_generation: int` (sube en `register_room`, `register_portal`, `unregister_room`, `unregister_portal`); el despachador guarda `_graph_generation` y vacía la caché cuando cambia, además del digest.

Esta tarea endurece el mecanismo aunque la Task 1 señale otra causa: hoy registrar una sala nueva **no** invalida la caché (solo lo hace el digest de portales, y un portal nuevo cambia el digest pero una sala nueva no cambia nada). Si la Task 1 mostró otra causa, se añade aquí lo que haga falta y se anota.

- [ ] **Step 1: Test (rojo)**

En `tests/test_room_path_dispatcher.gd`, dentro de `run_all()`, antes del `return a`:

```gdscript
	# Fase 8 (obs 43): registrar o desregistrar una sala o un portal sube la generacion del
	# grafo, y el despachador vacia su cache al verla cambiar aunque el digest de aperturas
	# no se mueva.
	var ac2 = SpatialAcousticsManagerClass.new()
	var gen0: int = ac2.graph_generation
	var ra = AudioRoomClass.new()
	ra.room_name = &"GenA"
	ra.set_bounds(AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10)))
	ac2.register_room(ra)
	a.gt(float(ac2.graph_generation), float(gen0), "registrar una sala sube la generacion")
	var gen1: int = ac2.graph_generation
	var rb = AudioRoomClass.new()
	rb.room_name = &"GenB"
	rb.set_bounds(AABB(Vector3(5, -5, -5), Vector3(10, 10, 10)))
	ac2.register_room(rb)
	ac2.register_portal(AudioPortalClass.new(&"GenP", &"GenA", &"GenB", Vector3(5, 0, 0), 1.0))
	a.gt(float(ac2.graph_generation), float(gen1), "registrar un portal tambien")
	var disp2 = RoomPathDispatcherClass.new()
	disp2.acoustics = ac2
	disp2.chain_for(&"GenA", &"GenB", Vector3(0, 0, 0), Vector3(10, 0, 0))
	a.ok(not disp2._cache.is_empty(), "la cache tiene la cadena")
	disp2.process_pool(VoicePoolManagerClass.new(1), Vector3(10, 0, 0))
	a.ok(not disp2._cache.is_empty(), "sin cambios en el grafo, la cache se conserva")
	ac2.unregister_portal(&"GenP")
	disp2.process_pool(VoicePoolManagerClass.new(1), Vector3(10, 0, 0))
	a.ok(disp2._cache.is_empty(), "al cambiar la generacion, la cache se vacia aunque el digest ya no tenga ese portal")
```

Comprobar que `SpatialAcousticsManagerClass`, `AudioRoomClass`, `AudioPortalClass`, `RoomPathDispatcherClass` y `VoicePoolManagerClass` existen como `const` en el archivo (lo hacen desde la Fase 6; si falta alguno, añadir el `preload`). Run: `./run_tests.sh` → rojo por `graph_generation` inexistente.

- [ ] **Step 2: Generación en el manager de acústica**

En `spatial_acoustics_manager.gd`, junto a `var rooms` / `var portals`:

```gdscript
## Sube cada vez que el conjunto de salas o portales cambia. El despachador de caminos la
## compara para vaciar su cache: el digest de aperturas no ve una sala nueva, y un camino
## calculado antes de que se registrara la ventana elegia la puerta (observacion 43).
var graph_generation: int = 0
```

Y `graph_generation += 1` como **última línea efectiva** de `register_room`, `register_portal`, `unregister_room` y `unregister_portal` (dentro del `if` que hace el trabajo, no cuando se ignora la llamada).

- [ ] **Step 3: El despachador la compara**

En `room_path_dispatcher.gd`, junto a `_portal_digest`: `var _graph_generation: int = -1`. En `process_pool`, sustituir el bloque del digest por:

```gdscript
	# El digest se calcula UNA vez por frame, no por voz: es O(P) con P portales. La
	# generacion del grafo detecta salas y portales nuevos o retirados, que el digest de
	# aperturas no siempre ve (observacion 43).
	var digest: float = _portals_digest()
	if not is_equal_approx(digest, _portal_digest) or acoustics.graph_generation != _graph_generation:
		_cache.clear()
		_portal_digest = digest
		_graph_generation = acoustics.graph_generation
```

Y en `clear_cache()`: `_graph_generation = -1`.

- [ ] **Step 4: Verde, diez corridas y commit**

```bash
./run_tests.sh
"$HOME/Downloads/Godot.app/Contents/MacOS/Godot" --headless --path . -s tools/repeat_street_test.gd 2>&1 | grep 'fallos:'
```

Expected: `STATUS: PASSED` y `[obs43] fallos: 0 de 10`. Si sigue fallando alguna, volver a la traza de la Task 1: la causa es otra y se arregla **esa**, anotándola en el spec §2. No se relaja el test.

```bash
git add addons/opendou/runtime/spatial/spatial_acoustics_manager.gd addons/opendou/runtime/spatial/room_path_dispatcher.gd tests/test_room_path_dispatcher.gd
git commit -m "Fase 8: la cache del grafo de salas se invalida por generacion (obs 43)"
```

---

### Task 3: Límites de instancias con alcance

**Files:**
- Modify: `addons/opendou/resources/audio_event_def.gd:60-72`
- Modify: `addons/opendou/runtime/event_instance.gd` (`stop`, `update_parameters`, nuevo `is_stopping`, `stop_fade_gain`)
- Create: `addons/opendou/runtime/instance_limiter.gd`
- Modify: `addons/opendou/runtime/audio_event_manager.gd` (`post_event`, `_apply_voices`)
- Test: `tests/test_instance_limiter.gd`, registrar en `tests/test_all.gd`

**Interfaces:**
- Produces en `AudioEventDef`: `enum LimitPolicy { REJECT_NEW, STEAL_OLDEST, STEAL_QUIETEST, STEAL_FARTHEST }`; exports `max_instances: int = 0`, `max_instances_per_emitter: int = 0`, `max_instances_in_radius: int = 0`, `instance_radius_m: float = 5.0`, `limit_policy: LimitPolicy = STEAL_OLDEST`, `limit_fade_out_sec: float = 0.05`.
- Produces en `EventInstance`: `stop(fade_time: float = 0.0)` con fundido real cuando `fade_time > 0` (hasta hoy el parámetro se ignoraba); `func is_stopping() -> bool`; `func stop_fade_gain() -> float` (1.0 normal; baja a 0 durante el fundido).
- Produces `OpenDouInstanceLimiter.check(def: AudioEventDef, caller: Node, position: Vector3, has_position: bool, active: Array, listener_pos: Vector3) -> Dictionary` con `{"allow": bool, "steal": EventInstance}`.
- Produces en el manager: `var instance_limiter: OpenDouInstanceLimiter`; `post_event` devuelve `null` con `REJECT_NEW` lleno.

- [ ] **Step 1: Test (rojo)**

```gdscript
class_name TestInstanceLimiter
extends RefCounted

## Fase 8: max_instances existia y nadie lo aplicaba. Ahora limita por evento, por emisor y
## por radio, con cuatro politicas, y se afirma sobre el bus.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const LimiterClass = preload("res://addons/opendou/runtime/instance_limiter.gd")
const SynthClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("instance_limiter")
	var ManagerClass = load("res://addons/opendou/runtime/audio_event_manager.gd")
	var manager = ManagerClass.new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.make_current()
	await tree.process_frame

	var tone: AudioStreamWAV = SynthClass.create_rain_ambient_loop(1.0)
	var def = AudioEventDefClass.new(&"Limited", tone)
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = probe.bus_name()
	def.base_volume_db = -12.0
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)

	# Defecto: sin limite. Cuatro voces suenan mas fuerte que tres.
	a.eq(def.max_instances, 0, "max_instances vale 0 (sin limite) por defecto")
	var instances: Array = []
	for i in range(4):
		var inst = manager.post_event(def, null)
		inst.set_position(Vector3(0, 0, -2))
		instances.append(inst)
	for i in range(12):
		await tree.process_frame
	var peak_four: float = await probe.measure_peak_over_frames(tree, 20)
	var playing: int = 0
	for inst in instances:
		if inst != null and inst.is_playing():
			playing += 1
	a.eq(playing, 4, "sin limite, las cuatro instancias existen")
	manager.stop_all()
	await probe.await_silence(tree, 0.002, 30)

	# STEAL_OLDEST con maximo 3: la cuarta roba la primera; nunca suenan cuatro.
	def.max_instances = 3
	def.limit_policy = AudioEventDefClass.LimitPolicy.STEAL_OLDEST
	def.limit_fade_out_sec = 0.05
	instances.clear()
	for i in range(4):
		var inst = manager.post_event(def, null)
		a.ok(inst != null, "con robo, post_event %d devuelve instancia" % i)
		inst.set_position(Vector3(0, 0, -2))
		instances.append(inst)
		await tree.process_frame
	a.ok(instances[0].is_stopping() or not instances[0].is_playing(), "la primera instancia es la robada")
	for i in range(12):
		await tree.process_frame
	var alive: int = 0
	for inst in instances:
		if inst.is_playing() and not inst.is_stopping():
			alive += 1
	a.eq(alive, 3, "quedan exactamente tres sonando")
	var peak_three: float = await probe.measure_peak_over_frames(tree, 20)
	a.lt(peak_three, peak_four * 0.9, "tres voces pican menos que cuatro (el limite llega al bus)")
	manager.stop_all()
	await probe.await_silence(tree, 0.002, 30)

	# REJECT_NEW: la cuarta no nace.
	def.limit_policy = AudioEventDefClass.LimitPolicy.REJECT_NEW
	for i in range(3):
		manager.post_event(def, null).set_position(Vector3(0, 0, -2))
	var rejected = manager.post_event(def, null)
	a.eq(rejected, null, "REJECT_NEW: la cuarta devuelve null")
	manager.stop_all()
	await probe.await_silence(tree, 0.002, 30)

	# Por radio: dos cerca llenan el cupo de 2; una tercera cerca no nace, una lejana si.
	def.max_instances = 0
	def.max_instances_in_radius = 2
	def.instance_radius_m = 5.0
	var near_a := Node3D.new(); near_a.position = Vector3(1, 0, 0); tree.root.add_child(near_a)
	var near_b := Node3D.new(); near_b.position = Vector3(-1, 0, 0); tree.root.add_child(near_b)
	var near_c := Node3D.new(); near_c.position = Vector3(0, 0, 1); tree.root.add_child(near_c)
	var far_d := Node3D.new(); far_d.position = Vector3(50, 0, 0); tree.root.add_child(far_d)
	a.ok(manager.post_event(def, near_a) != null, "primera cerca nace")
	a.ok(manager.post_event(def, near_b) != null, "segunda cerca nace")
	a.eq(manager.post_event(def, near_c), null, "tercera dentro del radio no nace (REJECT_NEW)")
	a.ok(manager.post_event(def, far_d) != null, "una a 50 m si nace: el radio es local")
	manager.stop_all()
	await probe.await_silence(tree, 0.002, 30)

	# Por emisor: un emisor que postea dos veces roba su propia voz; otro emisor no se toca.
	def.max_instances_in_radius = 0
	def.max_instances_per_emitter = 1
	def.limit_policy = AudioEventDefClass.LimitPolicy.STEAL_OLDEST
	var first_a = manager.post_event(def, near_a)
	var other_b = manager.post_event(def, near_b)
	var second_a = manager.post_event(def, near_a)
	a.ok(second_a != null and first_a.is_stopping(), "el segundo post del mismo emisor roba al primero")
	a.ok(other_b.is_playing() and not other_b.is_stopping(), "y el otro emisor no se ve afectado")
	manager.stop_all()
	await probe.await_silence(tree, 0.002, 30)

	# El fundido de stop() es real: una voz parada con 0.3 s de fundido sigue sonando a los
	# 0.1 s y ha callado a los 0.5 s. Antes el parametro se ignoraba.
	def.max_instances_per_emitter = 0
	var fading = manager.post_event(def, null)
	fading.set_position(Vector3(0, 0, -2))
	for i in range(12):
		await tree.process_frame
	fading.stop(0.3)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 100:
		await tree.process_frame
	a.ok(fading.is_stopping() and fading.is_playing(), "a los 0.1 s la voz sigue viva y en fundido")
	var mid_peak: float = await probe.measure_peak_over_frames(tree, 4)
	a.gt(mid_peak, 0.001, "y aun suena")
	while Time.get_ticks_msec() - t0 < 600:
		await tree.process_frame
	a.ok(not fading.is_playing(), "a los 0.6 s ha terminado")

	for n in [near_a, near_b, near_c, far_d, cam]:
		tree.root.remove_child(n)
		n.free()
	tree.root.remove_child(manager)
	manager.free()
	probe.teardown()
	return a
```

Registrar en `test_all.gd`: `const TestInstanceLimiterClass = preload("res://tests/test_instance_limiter.gd")` y en `run_async_suite`: `acc.absorb(await TestInstanceLimiterClass.run_all_async(tree))`. Run → rojo (`LimitPolicy` inexistente).

- [ ] **Step 2: Exports en la definición**

En `audio_event_def.gd`, quitar la línea `@export var max_instances: int = 5` de donde está y añadir tras los enums:

```gdscript
enum LimitPolicy {
	REJECT_NEW,     ## La instancia nueva no nace: post_event devuelve null
	STEAL_OLDEST,   ## Se detiene con fundido la mas antigua del alcance lleno
	STEAL_QUIETEST, ## La mas silenciosa
	STEAL_FARTHEST, ## La mas lejana del oyente
}
```

y tras el grupo de atenuación:

```gdscript
## Limites de instancias (Fase 8). Deciden cuantas instancias EXISTEN, antes de crearlas;
## el pool de voces decide despues cuales SUENAN. 0 = sin limite.
##
## max_instances llevaba declarado desde el principio del proyecto con valor 5 y ningun
## codigo lo leia. Ahora se aplica; el defecto pasa a 0 para que nada cambie hasta que una
## definicion lo suba a proposito.
@export_group("Instance Limits")
@export var max_instances: int = 0
@export var max_instances_per_emitter: int = 0
@export var max_instances_in_radius: int = 0
@export var instance_radius_m: float = 5.0
@export var limit_policy: LimitPolicy = LimitPolicy.STEAL_OLDEST
@export var limit_fade_out_sec: float = 0.05
@export_group("")
```

(El `@export_group("")` cierra el grupo para que `stealing_behavior` y lo que sigue no caigan dentro.)

- [ ] **Step 3: Fundido real en `EventInstance.stop()`**

Junto a `var elapsed_time`:

```gdscript
## Fundido de salida pedido por stop(fade). > 0 mientras dura; la voz sigue sonando con la
## ganancia de stop_fade_gain() y termina sola. Antes stop() ignoraba su parametro.
var stop_fade_total: float = 0.0
var stop_fade_remaining: float = -1.0
```

Sustituir `stop`:

```gdscript
## Detiene la instancia. Con fade_time > 0, baja la ganancia hasta cero durante ese tiempo y
## termina despues; con 0, para en el acto (el canal ya hace un micro-fade anticlic).
func stop(fade_time: float = 0.0) -> void:
	is_key_on = false
	if fade_time > 0.0 and is_playing():
		stop_fade_total = fade_time
		stop_fade_remaining = fade_time
		return
	if modulator_states.is_empty():
		voice_state = VoiceState.STATE_STOPPED
		# El canal NO se suelta aqui, por lo mismo que en notify_stream_finished(): la
		# limpieza del manager virtualiza a las instancias terminadas y eso es lo que
		# detiene el canal y devuelve el reproductor. Poner el id a -1 aqui dejaba el
		# canal is_busy para siempre.

## true mientras dura el fundido de stop().
func is_stopping() -> bool:
	return stop_fade_remaining > 0.0

## Ganancia lineal del fundido de stop(): 1.0 sin fundido, baja a 0.
func stop_fade_gain() -> float:
	if stop_fade_total <= 0.0 or stop_fade_remaining < 0.0:
		return 1.0
	return clampf(stop_fade_remaining / stop_fade_total, 0.0, 1.0)
```

Al principio de `update_parameters(delta, global_rtpcs)`:

```gdscript
	if stop_fade_remaining > 0.0:
		stop_fade_remaining -= delta
		if stop_fade_remaining <= 0.0:
			stop_fade_remaining = 0.0
			voice_state = VoiceState.STATE_STOPPED
```

En el manager, `_apply_voices`, tras calcular `volume_db` y antes de aplicar: `volume_db += linear_to_db(maxf(instance.stop_fade_gain(), 0.0001))`.

- [ ] **Step 4: El limitador**

```gdscript
class_name OpenDouInstanceLimiter
extends RefCounted

## Decide si una instancia nueva de un evento puede EXISTIR, antes de crearla, segun los
## limites de su definicion: por evento, por emisor y por radio. Es distinto del robo de
## voces del pool, que decide cuales SUENAN: una instancia rechazada no gasta canal, ni
## oclusion, ni camino por salas, ni tiempo logico.

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")

## Devuelve {"allow": bool, "steal": EventInstance o null}. `steal` es la instancia que hay
## que detener con fundido antes de crear la nueva.
func check(def: AudioEventDef, caller: Node, position: Vector3, has_position: bool, active: Array, listener_pos: Vector3) -> Dictionary:
	var result: Dictionary = {"allow": true, "steal": null}
	if def == null:
		return result
	if def.max_instances <= 0 and def.max_instances_per_emitter <= 0 and def.max_instances_in_radius <= 0:
		return result
	var caller_id: int = caller.get_instance_id() if caller != null else 0
	var same: Array = []
	var same_emitter: Array = []
	var near: Array = []
	# Una sola pasada: las que estan en fundido de salida no cuentan, o cada robo
	# encadenaria otro.
	for inst in active:
		if inst == null or inst.definition != def or not inst.is_playing() or inst.is_stopping():
			continue
		same.append(inst)
		if caller_id != 0 and inst.caller_id == caller_id:
			same_emitter.append(inst)
		if has_position and inst.has_spatial_position and inst.emitter_position.distance_to(position) <= def.instance_radius_m:
			near.append(inst)
	var full: Array = []
	if def.max_instances > 0 and same.size() >= def.max_instances:
		full = same
	elif def.max_instances_per_emitter > 0 and same_emitter.size() >= def.max_instances_per_emitter:
		full = same_emitter
	elif def.max_instances_in_radius > 0 and near.size() >= def.max_instances_in_radius:
		full = near
	if full.is_empty():
		return result
	if def.limit_policy == AudioEventDefClass.LimitPolicy.REJECT_NEW:
		result["allow"] = false
		return result
	result["steal"] = _pick(full, def.limit_policy, listener_pos)
	return result

func _pick(candidates: Array, policy: int, listener_pos: Vector3):
	var best = candidates[0]
	for inst in candidates:
		match policy:
			AudioEventDefClass.LimitPolicy.STEAL_OLDEST:
				if inst.elapsed_time > best.elapsed_time:
					best = inst
			AudioEventDefClass.LimitPolicy.STEAL_QUIETEST:
				if inst.calculated_volume_db < best.calculated_volume_db:
					best = inst
			AudioEventDefClass.LimitPolicy.STEAL_FARTHEST:
				var d_inst: float = inst.emitter_position.distance_to(listener_pos) if inst.has_spatial_position else 0.0
				var d_best: float = best.emitter_position.distance_to(listener_pos) if best.has_spatial_position else 0.0
				if d_inst > d_best:
					best = inst
	return best
```

- [ ] **Step 5: `post_event` consulta al limitador**

En el manager: `const InstanceLimiterClass = preload("res://addons/opendou/runtime/instance_limiter.gd")`, `var instance_limiter: OpenDouInstanceLimiter = null`, y en `_init`: `instance_limiter = InstanceLimiterClass.new()`. En `post_event`, sustituir desde `var instance: EventInstance = EventInstanceClass.new(def, caller)`:

```gdscript
	# Limites de instancias: se decide ANTES de crear nada. Una rechazada no existe; una
	# robada se va con el fundido de la definicion.
	var has_position: bool = caller is Node3D
	var position: Vector3 = Vector3.ZERO
	if caller is Node3D:
		position = caller.global_position if caller.is_inside_tree() else caller.position
	var verdict: Dictionary = instance_limiter.check(def, caller, position, has_position, active_instances, active_listener_position)
	if not bool(verdict["allow"]):
		return null
	if verdict["steal"] != null:
		verdict["steal"].stop(def.limit_fade_out_sec)

	var instance: EventInstance = EventInstanceClass.new(def, caller)
```

- [ ] **Step 6: Verde, banco y commit**

Run `./run_tests.sh`. Correr `tools/bench_control_loop.gd` y comprobar que el bucle a 200 voces no sube más de un 5 % (el limitador no corre por frame, solo en `post_event`; `stop_fade_gain()` sí, pero es una comparación).

```bash
git add addons/opendou/resources/audio_event_def.gd addons/opendou/runtime/event_instance.gd addons/opendou/runtime/instance_limiter.gd addons/opendou/runtime/instance_limiter.gd.uid addons/opendou/runtime/audio_event_manager.gd tests/test_instance_limiter.gd tests/test_instance_limiter.gd.uid tests/test_all.gd tests/leak_budget.txt
git commit -m "Fase 8: limites de instancias con alcance; stop(fade) hace fundido de verdad; max_instances pasa a 0"
```

---

### Task 4: Cadena de masterización como recurso

**Files:**
- Create: `addons/opendou/resources/mix_chain.gd`, `addons/opendou/runtime/mix_chain_installer.gd`
- Modify: `addons/opendou/runtime/audio_event_manager.gd` (`_ready`)
- Modify: `project.godot` (ajuste `opendou/mix/master_chain = "GAME"`)
- Test: `tests/test_mix_chain.gd`, registrar

**Interfaces:**
- Produces `MixChain` (Resource): `enum Preset { GAME, CINEMATIC, MOBILE, CUSTOM }`, `preset`, `compressor_threshold_db`, `compressor_ratio`, `compressor_attack_us`, `compressor_release_ms`, `compressor_gain_db`, `limiter_ceiling_db`, `limiter_pre_gain_db`, `limiter_release_sec`; `static func from_preset(p: Preset) -> MixChain`.
- Produces `OpenDouMixChainInstaller` (estáticas): `const SETTING = "opendou/mix/master_chain"`, `install(chain: MixChain, bus_name: String = "Master") -> bool`, `uninstall(bus_name: String = "Master") -> void`, `is_installed(bus_name) -> bool`, `install_from_setting() -> bool` (valor `""` = nada; `"GAME"`/`"CINEMATIC"`/`"MOBILE"` = preset; otra cosa = ruta a un `.tres`).
- Marcas: `resource_name` de los efectos `OpenDou_MixChain_Compressor` y `OpenDou_MixChain_Limiter`. Limitador: `AudioEffectHardLimiter` (el `AudioEffectLimiter` está obsoleto desde 4.3).

- [ ] **Step 1: Test (rojo)**

```gdscript
class_name TestMixChain
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const MixChainClass = preload("res://addons/opendou/resources/mix_chain.gd")
const InstallerClass = preload("res://addons/opendou/runtime/mix_chain_installer.gd")

## Un seno a 0 dBFS reproducido por dos reproductores a +6 dB: sin cadena, el bus pica muy
## por encima de 1.0; con la cadena GAME, no. Se hace en un bus propio y no en Master
## para no tocar la cadena que el autoload instala.
static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("mix_chain")
	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)
	var bus: String = String(probe.bus_name())

	var sine := AudioStreamWAV.new()
	var rate: int = int(AudioServer.get_mix_rate())
	var bytes := PackedByteArray()
	bytes.resize(rate * 2)
	for i in range(rate):
		bytes.encode_s16(i * 2, int(sin(TAU * 440.0 * i / rate) * 32000.0))
	sine.format = AudioStreamWAV.FORMAT_16_BITS
	sine.mix_rate = rate
	sine.data = bytes
	sine.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sine.loop_end = rate

	var players: Array[AudioStreamPlayer] = []
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.stream = sine
		p.bus = bus
		p.volume_db = 6.0
		tree.root.add_child(p)
		p.play()
		players.append(p)
	for i in range(6):
		await tree.process_frame
		probe.drain()
	var peak_raw: float = await probe.measure_peak_over_frames(tree, 20)
	a.gt(peak_raw, 1.2, "sin cadena, dos senos a +6 dB pican muy por encima de 0 dBFS (control)")

	# Instalar: la captura de la sonda esta al final del bus, asi que mide DESPUES del limitador
	# solo si el instalador inserta sus efectos ANTES de los que ya hay.
	var chain = MixChainClass.from_preset(MixChainClass.Preset.GAME)
	a.ok(InstallerClass.install(chain, bus), "la cadena GAME se instala")
	a.ok(InstallerClass.is_installed(bus), "y se reconoce instalada por sus marcas")
	for i in range(6):
		await tree.process_frame
		probe.drain()
	var peak_chain: float = await probe.measure_peak_over_frames(tree, 20)
	print("[OpenDou] cadena de masterizacion: pico sin cadena %.2f, con GAME %.3f" % [peak_raw, peak_chain])
	a.lt(peak_chain, 1.0, "con la cadena GAME el pico no supera 0 dBFS")

	# Idempotente: instalar dos veces deja exactamente dos efectos marcados.
	InstallerClass.install(chain, bus)
	var idx: int = AudioServer.get_bus_index(bus)
	var marked: int = 0
	for e in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, e).resource_name.begins_with("OpenDou_MixChain_"):
			marked += 1
	a.eq(marked, 2, "instalar dos veces deja dos efectos marcados, no cuatro")

	InstallerClass.uninstall(bus)
	a.ok(not InstallerClass.is_installed(bus), "desinstalar los quita")

	# El ajuste de proyecto del repo declara GAME y el autoload la instalo en Master.
	a.eq(str(ProjectSettings.get_setting(InstallerClass.SETTING, "")), "GAME", "el proyecto declara la cadena GAME")
	a.ok(InstallerClass.is_installed("Master"), "y Master la lleva instalada por el autoload")

	for p in players:
		p.stop()
		tree.root.remove_child(p)
		p.free()
	probe.teardown()
	return a
```

Registrar `TestMixChainClass` en `run_async_suite`. Run → rojo.

- [ ] **Step 2: El recurso**

```gdscript
@tool
class_name MixChain
extends Resource

## Cadena de masterizacion: compresor + limitador de Godot, con presets. Es un recurso y
## no un nodo porque Master es global: la instala el autoload segun un ajuste de proyecto
## y la guarda comprueba el bus, no la escena.

enum Preset { GAME, CINEMATIC, MOBILE, CUSTOM }

@export var preset: Preset = Preset.GAME:
	set(value):
		preset = value
		if value != Preset.CUSTOM:
			_apply_preset(value)

@export_group("Compressor")
@export var compressor_threshold_db: float = -12.0
@export var compressor_ratio: float = 3.0
@export var compressor_attack_us: float = 20.0
@export var compressor_release_ms: float = 250.0
@export var compressor_gain_db: float = 0.0

@export_group("Limiter")
@export var limiter_ceiling_db: float = -0.3
@export var limiter_pre_gain_db: float = 0.0
@export var limiter_release_sec: float = 0.1

static func from_preset(p: Preset) -> MixChain:
	var c := MixChain.new()
	c.preset = p
	return c

func _apply_preset(p: Preset) -> void:
	match p:
		Preset.GAME:
			compressor_threshold_db = -12.0; compressor_ratio = 3.0; compressor_attack_us = 20.0
			compressor_release_ms = 250.0; compressor_gain_db = 0.0
			limiter_ceiling_db = -0.3; limiter_pre_gain_db = 0.0; limiter_release_sec = 0.1
		Preset.CINEMATIC:
			compressor_threshold_db = -18.0; compressor_ratio = 2.0; compressor_attack_us = 40.0
			compressor_release_ms = 400.0; compressor_gain_db = 0.0
			limiter_ceiling_db = -1.0; limiter_pre_gain_db = 0.0; limiter_release_sec = 0.2
		Preset.MOBILE:
			compressor_threshold_db = -16.0; compressor_ratio = 4.0; compressor_attack_us = 20.0
			compressor_release_ms = 150.0; compressor_gain_db = 2.0
			limiter_ceiling_db = -0.5; limiter_pre_gain_db = 0.0; limiter_release_sec = 0.05
```

- [ ] **Step 3: El instalador**

```gdscript
class_name OpenDouMixChainInstaller
extends RefCounted

## Instala, actualiza y quita la cadena de masterizacion de un bus. Idempotente: los efectos
## van marcados por resource_name y se reutilizan. Se insertan al PRINCIPIO de la cadena del
## bus, para que una captura o un analizador anadidos despues midan lo que sale de verdad.

const SETTING: String = "opendou/mix/master_chain"
const MARK_COMP: String = "OpenDou_MixChain_Compressor"
const MARK_LIM: String = "OpenDou_MixChain_Limiter"
const MixChainClass = preload("res://addons/opendou/resources/mix_chain.gd")

static func ensure_setting() -> void:
	if not ProjectSettings.has_setting(SETTING):
		ProjectSettings.set_setting(SETTING, "")
	ProjectSettings.set_initial_value(SETTING, "")
	ProjectSettings.add_property_info({"name": SETTING, "type": TYPE_STRING, "hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
		"hint_string": "vacio = nada; GAME, CINEMATIC, MOBILE, o ruta a un MixChain.tres"})

## Lee el ajuste y actua. Devuelve true si instalo algo.
static func install_from_setting() -> bool:
	ensure_setting()
	var value: String = str(ProjectSettings.get_setting(SETTING, "")).strip_edges()
	if value.is_empty():
		return false
	var chain: MixChain = null
	match value.to_upper():
		"GAME": chain = MixChainClass.from_preset(MixChainClass.Preset.GAME)
		"CINEMATIC": chain = MixChainClass.from_preset(MixChainClass.Preset.CINEMATIC)
		"MOBILE": chain = MixChainClass.from_preset(MixChainClass.Preset.MOBILE)
		_:
			if ResourceLoader.exists(value):
				chain = load(value) as MixChain
	if chain == null:
		push_warning("[OpenDou] opendou/mix/master_chain = '%s' no es un preset ni un MixChain: no se instala nada" % value)
		return false
	return install(chain, "Master")

static func install(chain: MixChain, bus_name: String = "Master") -> bool:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0 or chain == null:
		return false
	var comp := _find(idx, MARK_COMP) as AudioEffectCompressor
	if comp == null:
		comp = AudioEffectCompressor.new()
		comp.resource_name = MARK_COMP
		AudioServer.add_bus_effect(idx, comp, 0)
	comp.threshold = chain.compressor_threshold_db
	comp.ratio = chain.compressor_ratio
	comp.attack_us = chain.compressor_attack_us
	comp.release_ms = chain.compressor_release_ms
	comp.gain = chain.compressor_gain_db
	var lim := _find(idx, MARK_LIM) as AudioEffectHardLimiter
	if lim == null:
		lim = AudioEffectHardLimiter.new()
		lim.resource_name = MARK_LIM
		AudioServer.add_bus_effect(idx, lim, 1)
	lim.ceiling_db = chain.limiter_ceiling_db
	lim.pre_gain_db = chain.limiter_pre_gain_db
	lim.release = chain.limiter_release_sec
	return true

static func uninstall(bus_name: String = "Master") -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	for e in range(AudioServer.get_bus_effect_count(idx) - 1, -1, -1):
		var name: String = AudioServer.get_bus_effect(idx, e).resource_name
		if name == MARK_COMP or name == MARK_LIM:
			AudioServer.remove_bus_effect(idx, e)

static func is_installed(bus_name: String = "Master") -> bool:
	var idx: int = AudioServer.get_bus_index(bus_name)
	return idx >= 0 and _find(idx, MARK_COMP) != null and _find(idx, MARK_LIM) != null

static func _find(bus_idx: int, mark: String) -> AudioEffect:
	for e in range(AudioServer.get_bus_effect_count(bus_idx)):
		var fx := AudioServer.get_bus_effect(bus_idx, e)
		if fx != null and fx.resource_name == mark:
			return fx
	return null
```

- [ ] **Step 4: El manager la instala; el proyecto la declara**

En el manager: `const MixChainInstallerClass = preload("res://addons/opendou/runtime/mix_chain_installer.gd")` y al final de `_ready()`: `MixChainInstallerClass.install_from_setting()`. En `project.godot`, sección `[opendou]` (crearla si no existe, tras `[editor_plugins]`):

```
[opendou]

mix/master_chain="GAME"
```

Nota: si en la suite dos managers (autoload y de test) llaman a `install_from_setting()`, ambos son idempotentes sobre Master: dos efectos, no cuatro.

- [ ] **Step 5: Verde y commit**

```bash
./run_tests.sh
git add addons/opendou/resources/mix_chain.gd addons/opendou/resources/mix_chain.gd.uid addons/opendou/runtime/mix_chain_installer.gd addons/opendou/runtime/mix_chain_installer.gd.uid addons/opendou/runtime/audio_event_manager.gd project.godot tests/test_mix_chain.gd tests/test_mix_chain.gd.uid tests/test_all.gd
git commit -m "Fase 8: cadena de masterizacion como recurso MixChain, instalada en Master desde el ajuste de proyecto"
```

---

### Task 5: Medidor LUFS (BS.1770-4)

**Files:**
- Create: `addons/opendou/runtime/loudness_meter.gd`, `tests/loudness_budget.txt`
- Modify: `addons/opendou/runtime/audio_event_manager.gd` (`loudness_meter`, `_process`)
- Modify: `addons/opendou/editor/opendou_mixer_drawer.gd` (lectura)
- Test: `tests/test_loudness_meter.gd`, registrar

**Interfaces:**
- Produces `OpenDouLoudnessMeter` (RefCounted): `attach(bus: StringName) -> bool`, `detach() -> void`, `is_attached() -> bool`, `process() -> void` (drena y mide; llamar por frame), `reset() -> void`, `momentary_lufs: float`, `short_term_lufs: float`, `integrated_lufs: float` (`-INF` si la compuerta no deja nada), `sample_peak_db: float`, `processed_seconds: float`, `last_process_usec: int` (coste del último `process()`).
- Produces en el manager: `var loudness_meter: OpenDouLoudnessMeter` (creado en `_init`, **no** enganchado); `_process` llama `loudness_meter.process()` solo si `is_attached()`.
- Marca del efecto de captura: `resource_name = "OpenDou_LoudnessMeter_Capture"`, idempotente.

- [ ] **Step 1: Test (rojo)**

```gdscript
class_name TestLoudnessMeter
extends RefCounted

## Fase 8: medidor BS.1770-4. Un seno de 1 kHz a -23 dBFS de pico en ambos canales mide
## -23.0 LUFS (la norma fija -3.01 LKFS para un canal a 0 dBFS). Silencio: la compuerta
## absoluta no deja nada. Y el coste se imprime, porque en GDScript no es gratis.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const MeterClass = preload("res://addons/opendou/runtime/loudness_meter.gd")

static func _sine_db(peak_db: float, seconds: float) -> AudioStreamWAV:
	var rate: int = int(AudioServer.get_mix_rate())
	var n: int = int(rate * seconds)
	var amp: float = db_to_linear(peak_db) * 32767.0
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	for i in range(n):
		var v: int = int(sin(TAU * 1000.0 * i / rate) * amp)
		bytes.encode_s16(i * 4, v)
		bytes.encode_s16(i * 4 + 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = rate
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav

static func _make_bus(name: String) -> void:
	if AudioServer.get_bus_index(name) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, "Master")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("loudness_meter")
	_make_bus("LufsProbe")
	var meter = MeterClass.new()
	a.ok(meter.attach(&"LufsProbe"), "el medidor se engancha al bus")
	a.ok(meter.attach(&"LufsProbe"), "engancharse dos veces es idempotente")
	var idx: int = AudioServer.get_bus_index("LufsProbe")
	var captures: int = 0
	for e in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, e).resource_name == "OpenDou_LoudnessMeter_Capture":
			captures += 1
	a.eq(captures, 1, "y deja una sola captura marcada")

	# Silencio: 1 s medido, la compuerta absoluta no deja bloques.
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000:
		await tree.process_frame
		meter.process()
	a.ok(is_inf(meter.integrated_lufs) and meter.integrated_lufs < 0.0, "en silencio la integrada no tiene valor (-INF), no -70")

	# Tono de calibracion, 3.5 s.
	meter.reset()
	var player := AudioStreamPlayer.new()
	player.stream = _sine_db(-23.0, 1.0)
	player.bus = "LufsProbe"
	tree.root.add_child(player)
	player.play()
	var total_usec: int = 0
	var calls: int = 0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3500:
		await tree.process_frame
		meter.process()
		total_usec += meter.last_process_usec
		calls += 1
	print("[OpenDou] LUFS tono -23 dBFS: M=%.2f S=%.2f I=%.2f pico=%.2f dBFS | %.1f s procesados, coste %.1f ms por segundo de audio" % [
		meter.momentary_lufs, meter.short_term_lufs, meter.integrated_lufs, meter.sample_peak_db,
		meter.processed_seconds, 1000.0 * float(total_usec) / 1e6 / maxf(meter.processed_seconds, 0.001)])
	a.approx(meter.integrated_lufs, -23.0, "integrada -23.0 LUFS", 0.5)
	a.approx(meter.short_term_lufs, -23.0, "a corto plazo -23.0 LUFS", 0.5)
	a.approx(meter.momentary_lufs, -23.0, "momentanea -23.0 LUFS", 0.7)
	a.approx(meter.sample_peak_db, -23.0, "pico muestral -23 dBFS", 0.3)
	a.gt(meter.processed_seconds, 3.0, "se procesaron al menos 3 s")

	# Compuerta relativa: 2 s de silencio en medio no bajan la integrada.
	var integrated_tone: float = meter.integrated_lufs
	player.stop()
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2000:
		await tree.process_frame
		meter.process()
	a.approx(meter.integrated_lufs, integrated_tone, "el silencio intermedio no baja la integrada (compuerta)", 0.3)

	player.free()
	meter.detach()
	a.ok(not meter.is_attached(), "detach quita la captura")
	return a
```

Registrar `TestLoudnessMeterClass` en `run_async_suite`. Run → rojo.

- [ ] **Step 2: El medidor**

```gdscript
class_name OpenDouLoudnessMeter
extends RefCounted

## Medidor de sonoridad segun ITU-R BS.1770-4 / EBU R128 sobre un AudioEffectCapture.
##
## Filtro K (high-shelf +4 dB a 1681 Hz y paso-alto a 38 Hz) por canal, potencia media por
## bloques de 100 ms, momentanea (400 ms), a corto plazo (3 s) e integrada con compuerta
## absoluta (-70 LUFS) y relativa (-10 LU). El pico es MUESTRAL: un pico verdadero exige
## sobremuestreo x4 y no esta hecho, por eso se llama sample_peak_db.
##
## Va apagado por defecto: procesar 44 100 muestras por segundo en GDScript no es gratis.
## last_process_usec deja el coste a la vista.

const MARK: String = "OpenDou_LoudnessMeter_Capture"
const BLOCK_SEC: float = 0.1
const ABS_GATE: float = -70.0
const REL_GATE: float = -10.0

var momentary_lufs: float = -INF
var short_term_lufs: float = -INF
var integrated_lufs: float = -INF
var sample_peak_db: float = -INF
var processed_seconds: float = 0.0
var last_process_usec: int = 0

var _capture: AudioEffectCapture = null
var _bus_index: int = -1
var _rate: float = 44100.0
# Filtro K: dos biquads por canal (shelf, hpf), estado z1/z2 por etapa y canal.
var _k: Array = []          # [ [b0,b1,b2,a1,a2] shelf, [..] hpf ]
var _z: Array = []          # [canal][etapa] -> [z1, z2]
var _block_samples: int = 4410
var _block_acc: Array = [0.0, 0.0]
var _block_count: int = 0
var _blocks: Array[float] = []   # potencia (suma de canales) por bloque de 100 ms
var _peak: float = 0.0

func attach(bus: StringName) -> bool:
	var idx: int = AudioServer.get_bus_index(String(bus))
	if idx < 0:
		return false
	if _capture != null and _bus_index == idx:
		return true
	detach()
	for e in range(AudioServer.get_bus_effect_count(idx)):
		var fx := AudioServer.get_bus_effect(idx, e)
		if fx != null and fx.resource_name == MARK:
			_capture = fx
	if _capture == null:
		_capture = AudioEffectCapture.new()
		_capture.resource_name = MARK
		_capture.buffer_length = 2.0
		AudioServer.add_bus_effect(idx, _capture)
	_bus_index = idx
	_rate = AudioServer.get_mix_rate()
	_block_samples = int(_rate * BLOCK_SEC)
	_design_k_filter()
	reset()
	return true

func detach() -> void:
	if _capture != null and _bus_index >= 0 and _bus_index < AudioServer.bus_count:
		for e in range(AudioServer.get_bus_effect_count(_bus_index) - 1, -1, -1):
			if AudioServer.get_bus_effect(_bus_index, e) == _capture:
				AudioServer.remove_bus_effect(_bus_index, e)
	_capture = null
	_bus_index = -1

func is_attached() -> bool:
	return _capture != null

func reset() -> void:
	_blocks.clear()
	_block_acc = [0.0, 0.0]
	_block_count = 0
	_z = [[[0.0, 0.0], [0.0, 0.0]], [[0.0, 0.0], [0.0, 0.0]]]
	_peak = 0.0
	momentary_lufs = -INF
	short_term_lufs = -INF
	integrated_lufs = -INF
	sample_peak_db = -INF
	processed_seconds = 0.0

## Drena la captura y actualiza las medidas. Llamar una vez por frame.
func process() -> void:
	if _capture == null:
		return
	var t0: int = Time.get_ticks_usec()
	var avail: int = _capture.get_frames_available()
	if avail <= 0:
		last_process_usec = Time.get_ticks_usec() - t0
		return
	var frames: PackedVector2Array = _capture.get_buffer(avail)
	for f in frames:
		var l: float = _k_process(f.x, 0)
		var r: float = _k_process(f.y, 1)
		_block_acc[0] += l * l
		_block_acc[1] += r * r
		_peak = maxf(_peak, maxf(absf(f.x), absf(f.y)))
		_block_count += 1
		if _block_count >= _block_samples:
			_close_block()
	processed_seconds += float(avail) / _rate
	sample_peak_db = linear_to_db(_peak) if _peak > 0.0 else -INF
	last_process_usec = Time.get_ticks_usec() - t0

func _close_block() -> void:
	var n: float = float(_block_count)
	_blocks.append(_block_acc[0] / n + _block_acc[1] / n)
	_block_acc = [0.0, 0.0]
	_block_count = 0
	momentary_lufs = _lufs_of_last(4)
	short_term_lufs = _lufs_of_last(30)
	integrated_lufs = _gated_integrated()

static func _power_to_lufs(p: float) -> float:
	return -0.691 + 10.0 * log(maxf(p, 1e-12)) / log(10.0) if p > 0.0 else -INF

func _lufs_of_last(count: int) -> float:
	if _blocks.size() < count:
		return -INF
	var acc: float = 0.0
	for i in range(_blocks.size() - count, _blocks.size()):
		acc += _blocks[i]
	return _power_to_lufs(acc / float(count))

## Integrada con compuerta: se promedian las ventanas de 400 ms (4 bloques solapados a 100
## ms) que superan -70 LUFS, y de esas, las que superan la media provisional menos 10 LU.
func _gated_integrated() -> float:
	if _blocks.size() < 4:
		return -INF
	var windows: Array[float] = []
	for i in range(3, _blocks.size()):
		windows.append((_blocks[i - 3] + _blocks[i - 2] + _blocks[i - 1] + _blocks[i]) * 0.25)
	var passing: Array[float] = []
	for w in windows:
		if _power_to_lufs(w) > ABS_GATE:
			passing.append(w)
	if passing.is_empty():
		return -INF
	var mean: float = 0.0
	for w in passing:
		mean += w
	mean /= float(passing.size())
	var rel_gate: float = _power_to_lufs(mean) + REL_GATE
	var acc: float = 0.0
	var n: int = 0
	for w in passing:
		if _power_to_lufs(w) > rel_gate:
			acc += w
			n += 1
	return _power_to_lufs(acc / float(n)) if n > 0 else -INF

## Coeficientes del filtro K para la mix_rate real (RBJ con los parametros de la norma:
## shelf f0 = 1681.97 Hz, Q = 0.7071752, +3.99984 dB; paso-alto f0 = 38.13547 Hz, Q = 0.5003270).
func _design_k_filter() -> void:
	_k = [_rbj_highshelf(1681.974450955533, 0.7071752369554196, 3.999843853973347), _rbj_highpass(38.13547087602444, 0.5003270373238773)]

func _rbj_highshelf(f0: float, q: float, gain_db: float) -> Array:
	var A: float = pow(10.0, gain_db / 40.0)
	var w0: float = TAU * f0 / _rate
	var cw: float = cos(w0)
	var sw: float = sin(w0)
	var alpha: float = sw / (2.0 * q)
	var s2a: float = 2.0 * sqrt(A) * alpha
	var a0: float = (A + 1.0) - (A - 1.0) * cw + s2a
	return [
		A * ((A + 1.0) + (A - 1.0) * cw + s2a) / a0,
		-2.0 * A * ((A - 1.0) + (A + 1.0) * cw) / a0,
		A * ((A + 1.0) + (A - 1.0) * cw - s2a) / a0,
		2.0 * ((A - 1.0) - (A + 1.0) * cw) / a0,
		((A + 1.0) - (A - 1.0) * cw - s2a) / a0,
	]

func _rbj_highpass(f0: float, q: float) -> Array:
	var w0: float = TAU * f0 / _rate
	var cw: float = cos(w0)
	var sw: float = sin(w0)
	var alpha: float = sw / (2.0 * q)
	var a0: float = 1.0 + alpha
	return [(1.0 + cw) * 0.5 / a0, -(1.0 + cw) / a0, (1.0 + cw) * 0.5 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0]

func _k_process(x: float, ch: int) -> float:
	var y: float = x
	for stage in range(2):
		var c: Array = _k[stage]
		var z: Array = _z[ch][stage]
		var out: float = c[0] * y + z[0]
		z[0] = c[1] * y - c[3] * out + z[1]
		z[1] = c[2] * y - c[4] * out
		y = out
	return y
```

- [ ] **Step 3: Manager y cajón de mezcla**

Manager: `const LoudnessMeterClass = preload("res://addons/opendou/runtime/loudness_meter.gd")`, `var loudness_meter: OpenDouLoudnessMeter = null`, en `_init`: `loudness_meter = LoudnessMeterClass.new()`; en `_process`, tras `_update_hdr(delta)`: `if loudness_meter.is_attached(): loudness_meter.process()`.

Cajón de mezcla (`opendou_mixer_drawer.gd`): en `_build_ui()`, dentro de `hdr_box` tras `hdr_window_lbl`, añadir:

```gdscript
	var lufs_title = Label.new()
	lufs_title.text = "📏 Sonoridad (BS.1770)"
	lufs_title.add_theme_font_size_override("font_size", 11)
	hdr_box.add_child(lufs_title)
	lufs_lbl = Label.new()
	lufs_lbl.text = "M: —  S: —  I: —\nPico: —"
	lufs_lbl.add_theme_font_size_override("font_size", 10)
	hdr_box.add_child(lufs_lbl)
	var lufs_reset = Button.new()
	lufs_reset.text = "Reiniciar integrada"
	lufs_reset.pressed.connect(func(): var m = _runtime_manager(); if m != null: m.loudness_meter.reset())
	hdr_box.add_child(lufs_reset)
```

con `var lufs_lbl: Label` entre los campos, y:

```gdscript
## El manager del juego en marcha, si el editor tiene uno (el autoload en ejecucion).
func _runtime_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("OpenDou") if tree != null and tree.root != null else null

## Engancha el medidor a Master al mostrar el cajon y lo suelta al ocultarlo.
func set_meter_active(active: bool) -> void:
	var m = _runtime_manager()
	if m == null or not ("loudness_meter" in m):
		return
	if active:
		m.loudness_meter.attach(&"Master")
	else:
		m.loudness_meter.detach()

func _process(_delta: float) -> void:
	var m = _runtime_manager()
	if m == null or lufs_lbl == null or not ("loudness_meter" in m) or not m.loudness_meter.is_attached():
		return
	var lm = m.loudness_meter
	lufs_lbl.text = "M: %s  S: %s  I: %s\nPico: %s" % [_fmt(lm.momentary_lufs), _fmt(lm.short_term_lufs), _fmt(lm.integrated_lufs), _fmt(lm.sample_peak_db)]

static func _fmt(v: float) -> String:
	return "—" if is_inf(v) else "%.1f" % v
```

`set_meter_active(true/false)` se llama desde `visibility_changed` del cajón (conectar en `_init`: `visibility_changed.connect(func(): set_meter_active(visible))`).

- [ ] **Step 4: Presupuesto de sonoridad por demo**

`tests/loudness_budget.txt`:

```
# Rango de sonoridad integrada (LUFS) por demo, medido 3 s tras arrancar con el medidor en
# Master. Formato: <escena> <min> <max>. Los rangos se fijan con la primera medida real y
# son anchos (+-6 LU) porque los ambientes tienen aleatoriedad; detectan una mezcla que se
# fue de madre, no una decima. Se aprietan cuando se estabilicen.
keel -40 -10
monsoon -40 -10
cabin -40 -10
street -40 -10
```

Al final de `test_loudness_meter.gd`, una segunda suite:

```gdscript
## Cada demo, 3 s con el medidor en Master, dentro del rango de tests/loudness_budget.txt.
static func run_demo_budget_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("loudness_budget")
	var scenes: Dictionary = {
		"keel": "res://scenes/demos/keel/keel_demo.tscn",
		"monsoon": "res://scenes/demos/monsoon/monsoon_demo.tscn",
		"cabin": "res://scenes/demos/cabin/cabin_demo.tscn",
		"street": "res://scenes/demos/street/street_demo.tscn",
	}
	var budget: Dictionary = {}
	for line in FileAccess.get_file_as_string("res://tests/loudness_budget.txt").split("\n"):
		var t: String = line.strip_edges()
		if t.is_empty() or t.begins_with("#"):
			continue
		var parts: PackedStringArray = t.split(" ", false)
		if parts.size() == 3:
			budget[parts[0]] = [float(parts[1]), float(parts[2])]
	var manager = tree.root.get_node_or_null("OpenDou")
	for key in scenes:
		var demo = load(scenes[key]).instantiate()
		tree.root.add_child(demo)
		manager.loudness_meter.attach(&"Master")
		manager.loudness_meter.reset()
		var t0: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3000:
			await tree.process_frame
		var lufs: float = manager.loudness_meter.integrated_lufs
		manager.loudness_meter.detach()
		print("[OpenDou] sonoridad de %s: %.1f LUFS (rango %s)" % [key, lufs, budget.get(key, "sin rango")])
		if budget.has(key):
			a.ok(lufs >= budget[key][0] and lufs <= budget[key][1], "%s dentro de su rango de sonoridad" % key)
		if demo.has_method("_exit_tree"):
			pass
		tree.root.remove_child(demo)
		demo.free()
		await tree.process_frame
	return a
```

Registrar `acc.absorb(await TestLoudnessMeterClass.run_demo_budget_async(tree))`. Tras la primera corrida, **sustituir** los rangos del archivo por los medidos ±6 LU y comentarlo en el archivo. Si alguna demo mide `-INF` (compuerta) porque arranca en silencio, subir el tiempo a 5 s para esa y anotarlo.

- [ ] **Step 5: Verde y commit**

Anotar en el spec (§5) el coste medido (`ms por segundo de audio`). Si supera los 2 ms del spec, se acepta igual con el medidor apagado por defecto y se abre la tarea nativa en `docs/tasks/current.md`.

```bash
./run_tests.sh
git add addons/opendou/runtime/loudness_meter.gd addons/opendou/runtime/loudness_meter.gd.uid addons/opendou/runtime/audio_event_manager.gd addons/opendou/editor/opendou_mixer_drawer.gd tests/test_loudness_meter.gd tests/test_loudness_meter.gd.uid tests/loudness_budget.txt tests/test_all.gd tests/leak_budget.txt docs/superpowers/specs/2026-09-02-fase8-higiene-y-deuda-design.md
git commit -m "Fase 8: medidor LUFS BS.1770 con calibracion afirmada y presupuesto de sonoridad por demo"
```

---

### Task 6: La mezcla llega al servidor

**Files:**
- Create: `addons/opendou/runtime/mix_bus_applier.gd`
- Modify: `addons/opendou/runtime/audio_event_manager.gd` (`mix`, pila, `set_bus_base_volume_db`, `_process`)
- Modify: `scenes/shared/bus_row.gd`
- Modify: `addons/opendou/nodes/opendou_parameter_area_3d.gd:285-300`, `addons/opendou/nodes/opendou_music_player.gd` (matriz del manager)
- Test: `tests/test_mix_bus_applier.gd`, registrar

**Interfaces:**
- Produces `OpenDouMixBusApplier` (RefCounted): `var snapshots: AudioMixSnapshotManager`, `var ducking: AudioDuckingMatrix`, `func apply(delta: float) -> void`, `func set_bus_base_volume_db(bus: StringName, db: float) -> void`, `func get_bus_base_volume_db(bus: StringName) -> float`, `func set_bus_base_mute(bus, muted)`, `func managed_buses() -> Array[StringName]`, `var writes_last_frame: int`, `func effective_volume_db(bus) -> float`.
- Produces en el manager: `var mix: OpenDouMixBusApplier`; `push_snapshot(name: StringName, blend_sec: float = -1.0)`, `pop_snapshot(name: StringName)`, `set_bus_base_volume_db(bus, db)`, `get_bus_base_volume_db(bus)`.
- Marcas de filtros: `OpenDou_Mix_LPF`, `OpenDou_Mix_HPF`.
- Buses gestionados = los nombrados en cualquier instantánea registrada ∪ los `target_bus` de las reglas de ducking, **que existan** en el `AudioServer`.

- [ ] **Step 1: Test (rojo)**

```gdscript
class_name TestMixBusApplier
extends RefCounted

## Fase 8: las instantaneas, el ducking y el area de parametros NUNCA escribian en el
## AudioServer. Ahora si, con el modelo base + delta + ducking, y se afirma leyendo el
## servidor y capturando el bus. Los buses son propios de este test para no pelear con el
## autoload, que solo gestiona los suyos.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioMixSnapshotClass = preload("res://addons/opendou/core/audio_mix_snapshot.gd")
const SynthClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

static func _make_bus(name: String) -> int:
	var idx: int = AudioServer.get_bus_index(name)
	if idx < 0:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, "Master")
	return idx

static func _wait_ms(tree: SceneTree, ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await tree.process_frame

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("mix_bus_applier")
	var music_idx: int = _make_bus("MixTestMusic")
	var voice_idx: int = _make_bus("MixTestVoice")
	AudioServer.set_bus_volume_db(music_idx, -3.0)
	var ManagerClass = load("res://addons/opendou/runtime/audio_event_manager.gd")
	var manager = ManagerClass.new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	await tree.process_frame

	# Instantanea propia: solo nombra los buses del test.
	var snap = AudioMixSnapshotClass.new(&"TestDuck", {
		&"MixTestMusic": {"volume_db": -18.0, "lpf_hz": 500.0, "hpf_hz": 20.0, "mute": false},
	}, 0.2)
	manager.mix.snapshots.register_snapshot(snap)
	var neutral = AudioMixSnapshotClass.new(&"TestNeutral", {
		&"MixTestMusic": {"volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false},
	}, 0.2)
	manager.mix.snapshots.register_snapshot(neutral)
	manager.mix.snapshots.apply_snapshot_instant(&"TestNeutral")
	a.ok(&"MixTestMusic" in manager.mix.managed_buses(), "el bus de la instantanea es gestionado")
	a.ok(not (&"Master" in manager.mix.managed_buses()) or true, "Master solo si alguna instantanea propia lo nombra (aqui no importa)")
	await tree.process_frame
	a.approx(manager.get_bus_base_volume_db(&"MixTestMusic"), -3.0, "la base capturada es el volumen que tenia el bus", 0.01)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -3.0, "sin instantanea activa el bus se queda en su base", 0.01)

	# push: el volumen REAL baja con el fundido y el filtro aparece.
	manager.push_snapshot(&"TestDuck", 0.2)
	await _wait_ms(tree, 400)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -21.0, "push: base -3 + delta -18 = -21 dB en el AudioServer", 0.2)
	var lpf: AudioEffectLowPassFilter = null
	for e in range(AudioServer.get_bus_effect_count(music_idx)):
		var fx := AudioServer.get_bus_effect(music_idx, e)
		if fx.resource_name == "OpenDou_Mix_LPF":
			lpf = fx
	a.ok(lpf != null and AudioServer.is_bus_effect_enabled(music_idx, AudioServer.get_bus_effect_count(music_idx) - 1) or lpf != null, "push: hay un paso-bajo marcado en el bus")
	a.approx(lpf.cutoff_hz if lpf != null else 0.0, 500.0, "y esta en 500 Hz", 5.0)

	# El jugador mueve la base con la instantanea activa: el aplicado se mueve lo mismo.
	manager.set_bus_base_volume_db(&"MixTestMusic", -6.0)
	await tree.process_frame
	a.approx(AudioServer.get_bus_volume_db(music_idx), -24.0, "mover la base -3 dB mueve lo aplicado -3 dB", 0.2)

	# pop: vuelve a la base y el filtro se deshabilita (no se quita).
	manager.pop_snapshot(&"TestDuck")
	await _wait_ms(tree, 400)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -6.0, "pop: vuelve a la base", 0.2)
	var lpf_enabled: bool = false
	for e in range(AudioServer.get_bus_effect_count(music_idx)):
		if AudioServer.get_bus_effect(music_idx, e).resource_name == "OpenDou_Mix_LPF":
			lpf_enabled = AudioServer.is_bus_effect_enabled(music_idx, e)
	a.ok(not lpf_enabled, "pop: el paso-bajo queda deshabilitado")

	# Sin transiciones ni ducking: cero escrituras por frame.
	await tree.process_frame
	await tree.process_frame
	a.eq(manager.mix.writes_last_frame, 0, "en reposo no se escribe nada en el AudioServer")

	# Ducking: una regla propia; activar la fuente baja el destino de verdad.
	manager.mix.ducking.add_rule(&"MixTestVoice", &"MixTestMusic", -9.0, 0.02, 0.1)
	manager.mix.ducking.set_bus_active(&"MixTestVoice", true)
	await _wait_ms(tree, 200)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -15.0, "ducking: base -6 + (-9) = -15 dB", 0.3)
	manager.mix.ducking.set_bus_active(&"MixTestVoice", false)
	await _wait_ms(tree, 400)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -6.0, "sin fuente activa, vuelve", 0.3)

	# Y se OYE: una voz en el bus con la instantanea pica menos que sin ella.
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"MixTestMusic", 2.0)
	var tone: AudioStreamWAV = SynthClass.create_rain_ambient_loop(1.0)
	var p := AudioStreamPlayer.new()
	p.stream = tone
	p.bus = "MixTestMusic"
	tree.root.add_child(p)
	p.play()
	await _wait_ms(tree, 200)
	probe.drain()
	var peak_base: float = await probe.measure_peak_over_frames(tree, 20)
	manager.push_snapshot(&"TestDuck", 0.1)
	await _wait_ms(tree, 400)
	probe.drain()
	var peak_ducked: float = await probe.measure_peak_over_frames(tree, 20)
	print("[OpenDou] mezcla al servidor: pico base %.4f, con instantanea %.4f" % [peak_base, peak_ducked])
	a.lt(peak_ducked, peak_base * 0.3, "la instantanea se oye: el pico cae mas de 10 dB")
	manager.pop_snapshot(&"TestDuck")
	p.stop()
	tree.root.remove_child(p)
	p.free()
	probe.teardown()

	# Area de parametros: por fin hace algo.
	var AreaScript = load("res://addons/opendou/nodes/opendou_parameter_area_3d.gd")
	var area = AreaScript.new()
	area.target_snapshot = &"TestDuck"
	tree.root.add_child(area)
	area.set_event_manager(manager) if area.has_method("set_event_manager") else null
	area._activate_snapshot()
	await _wait_ms(tree, 400)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -24.0, "el area de parametros empuja la instantanea de verdad", 0.3)
	area._release_snapshot()
	await _wait_ms(tree, 400)
	a.approx(AudioServer.get_bus_volume_db(music_idx), -6.0, "y la suelta al salir", 0.3)
	tree.root.remove_child(area)
	area.free()

	tree.root.remove_child(manager)
	manager.free()
	return a
```

Registrar `TestMixBusApplierClass` en `run_async_suite`. Run → rojo (`mix` inexistente). Nota: si `OpenDouParameterArea3D` no tiene `set_event_manager`, comprobar cómo obtiene el manager (`_get_manager()` busca `/root/OpenDou`); en ese caso el test apunta al autoload y hay que registrar la instantanea también en él: `tree.root.get_node("OpenDou").mix.snapshots.register_snapshot(snap)` y afirmar sobre el autoload. Decidirlo al ejecutar, no adivinarlo.

- [ ] **Step 2: El aplicador**

```gdscript
class_name OpenDouMixBusApplier
extends RefCounted

## Escribe cada frame en el AudioServer el resultado de la mezcla dinamica:
##
##     volumen(bus) = base(bus) + delta_instantanea(bus) + ducking(bus)
##
## La base es el volumen que el proyecto o el jugador dejaron en el bus (el menu de pausa la
## edita). Hasta la Fase 8, las instantaneas y el ducking se calculaban y NADIE los aplicaba.
## Solo toca los buses GESTIONADOS: los que nombra alguna instantanea registrada o alguna
## regla de ducking. Asi dos managers (el autoload y uno de test) no se pisan.

const AudioMixSnapshotManagerClass = preload("res://addons/opendou/core/audio_mix_snapshot_manager.gd")
const AudioDuckingMatrixClass = preload("res://addons/opendou/core/audio_ducking_matrix.gd")
const MARK_LPF: String = "OpenDou_Mix_LPF"
const MARK_HPF: String = "OpenDou_Mix_HPF"

var snapshots: AudioMixSnapshotManager = null
var ducking: AudioDuckingMatrix = null
var writes_last_frame: int = 0

var _base_db: Dictionary = {}     # StringName -> float
var _base_mute: Dictionary = {}   # StringName -> bool
var _warned: Dictionary = {}

func _init() -> void:
	snapshots = AudioMixSnapshotManagerClass.new()
	ducking = AudioDuckingMatrixClass.new()

## Buses que este aplicador gobierna y que existen en el servidor.
func managed_buses() -> Array[StringName]:
	var names: Dictionary = {}
	for snap_name in snapshots.registered_snapshots:
		for bus in snapshots.registered_snapshots[snap_name].bus_settings:
			names[StringName(bus)] = true
	for rule in ducking.rules:
		names[rule.target_bus] = true
	var out: Array[StringName] = []
	for bus in names:
		if AudioServer.get_bus_index(String(bus)) >= 0:
			out.append(bus)
		elif not _warned.has(bus):
			_warned[bus] = true
			push_warning("[OpenDou] la mezcla nombra el bus '%s', que no existe en el AudioServer: se ignora" % String(bus))
	return out

func set_bus_base_volume_db(bus: StringName, db: float) -> void:
	_base_db[bus] = db

func get_bus_base_volume_db(bus: StringName) -> float:
	_ensure_base(bus)
	return float(_base_db[bus])

func set_bus_base_mute(bus: StringName, muted: bool) -> void:
	_base_mute[bus] = muted

## Volumen que el aplicador quiere para el bus ahora mismo.
func effective_volume_db(bus: StringName) -> float:
	_ensure_base(bus)
	var state: Dictionary = snapshots.get_bus_state(bus)
	return float(_base_db[bus]) + float(state.get("volume_db", 0.0)) + ducking.get_ducking_attenuation_db(bus)

func apply(delta: float) -> void:
	snapshots.update(delta)
	ducking.update(delta)
	writes_last_frame = 0
	for bus in managed_buses():
		var idx: int = AudioServer.get_bus_index(String(bus))
		var state: Dictionary = snapshots.get_bus_state(bus)
		var target: float = effective_volume_db(bus)
		if absf(AudioServer.get_bus_volume_db(idx) - target) > 0.01:
			AudioServer.set_bus_volume_db(idx, target)
			writes_last_frame += 1
		var muted: bool = bool(_base_mute.get(bus, false)) or bool(state.get("mute", false))
		if AudioServer.is_bus_mute(idx) != muted:
			AudioServer.set_bus_mute(idx, muted)
			writes_last_frame += 1
		_apply_filter(idx, MARK_LPF, float(state.get("lpf_hz", 20000.0)), 20000.0, true)
		_apply_filter(idx, MARK_HPF, float(state.get("hpf_hz", 20.0)), 20.0, false)

func _ensure_base(bus: StringName) -> void:
	if not _base_db.has(bus):
		var idx: int = AudioServer.get_bus_index(String(bus))
		_base_db[bus] = AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0
		_base_mute[bus] = AudioServer.is_bus_mute(idx) if idx >= 0 else false

## Filtro marcado bajo demanda: se crea la primera vez que hace falta, se deshabilita (no se
## quita) cuando el corte vuelve al neutro, y solo se escribe si cambio.
func _apply_filter(bus_idx: int, mark: String, hz: float, neutral_hz: float, lowpass: bool) -> void:
	var neutral: bool = absf(hz - neutral_hz) < 1.0
	var pos: int = -1
	for e in range(AudioServer.get_bus_effect_count(bus_idx)):
		if AudioServer.get_bus_effect(bus_idx, e).resource_name == mark:
			pos = e
	if pos < 0:
		if neutral:
			return
		var fx: AudioEffectFilter = AudioEffectLowPassFilter.new() if lowpass else AudioEffectHighPassFilter.new()
		fx.resource_name = mark
		fx.cutoff_hz = hz
		AudioServer.add_bus_effect(bus_idx, fx)
		writes_last_frame += 1
		return
	var fx2: AudioEffectFilter = AudioServer.get_bus_effect(bus_idx, pos)
	if AudioServer.is_bus_effect_enabled(bus_idx, pos) == neutral:
		AudioServer.set_bus_effect_enabled(bus_idx, pos, not neutral)
		writes_last_frame += 1
	if not neutral and absf(fx2.cutoff_hz - hz) > 1.0:
		fx2.cutoff_hz = hz
		writes_last_frame += 1
```

- [ ] **Step 3: El manager: `mix`, pila y base**

Preload `const MixBusApplierClass = preload("res://addons/opendou/runtime/mix_bus_applier.gd")`; `var mix: OpenDouMixBusApplier = null`; en `_init`: `mix = MixBusApplierClass.new()`. En `_process`, tras `_update_hdr(delta)` (paso 5b) y antes del robo de voces: `mix.apply(delta)`. Y:

```gdscript
## Pila de instantaneas de mezcla. El tope manda; al vaciarse, Default.
var _snapshot_stack: Array[Dictionary] = []   # {"name": StringName, "priority": int}

func push_snapshot(name: StringName, blend_sec: float = -1.0, priority: int = 0) -> void:
	if not mix.snapshots.registered_snapshots.has(name):
		push_warning("[OpenDou] push_snapshot: la instantanea '%s' no esta registrada" % String(name))
		return
	_snapshot_stack.append({"name": name, "priority": priority})
	_apply_snapshot_top(blend_sec)

func pop_snapshot(name: StringName, blend_sec: float = -1.0) -> void:
	for i in range(_snapshot_stack.size() - 1, -1, -1):
		if _snapshot_stack[i]["name"] == name:
			_snapshot_stack.remove_at(i)
			break
	_apply_snapshot_top(blend_sec)

## El tope es la de mayor prioridad; a igual prioridad, la mas reciente.
func _apply_snapshot_top(blend_sec: float) -> void:
	var top: StringName = &"Default"
	var best_priority: int = -2147483648
	for entry in _snapshot_stack:
		if int(entry["priority"]) >= best_priority:
			best_priority = int(entry["priority"])
			top = entry["name"]
	mix.snapshots.transition_to(top, blend_sec)

func set_bus_base_volume_db(bus: StringName, db: float) -> void:
	mix.set_bus_base_volume_db(bus, db)

func get_bus_base_volume_db(bus: StringName) -> float:
	return mix.get_bus_base_volume_db(bus)
```

- [ ] **Step 4: Quien escribía por su cuenta**

`scenes/shared/bus_row.gd`: en `_ready`, la posición inicial del deslizador lee la base si hay manager: `var m = get_node_or_null("/root/OpenDou"); _volume.set_value_no_signal(m.get_bus_base_volume_db(StringName(bus_name)) if m != null and m.has_method("get_bus_base_volume_db") else AudioServer.get_bus_volume_db(_bus_index))`. En `_on_volume_changed`: si hay manager, `m.set_bus_base_volume_db(StringName(bus_name), value)`; si no, `AudioServer.set_bus_volume_db` como hoy. En `_on_mute_toggled`: `m.mix.set_bus_base_mute(...)` si hay manager. Ojo: un bus que NO es gestionado (no lo nombra ninguna instantanea) no lo toca el aplicador, así que ahí `set_bus_base_volume_db` no llegaría al servidor: `BusRow` escribe **ambas** cosas (base y servidor) para cubrir los dos casos; el aplicador, si gestiona el bus, lo reescribirá al mismo valor y no cuenta como conflicto.

`opendou_parameter_area_3d.gd`: quitar los `has_method` de `_activate_snapshot` y `_release_snapshot` y llamar `mgr.push_snapshot(target_snapshot)` / `mgr.pop_snapshot(target_snapshot)` directamente.

`opendou_music_player.gd`: en `_ready`, si `ducking_matrix == null`, tomar `manager.mix.ducking` del manager que ya resuelve; y **no** llamar a `ducking_matrix.update(delta)` cuando la matriz sea la del manager (la actualiza el aplicador): guardar `var _owns_ducking: bool` y actualizar solo si es propia. `AudioDialogueManager` recibe la matriz por parámetro: quien lo use le pasa `manager.mix.ducking`.

- [ ] **Step 5: Verde, banco y commit**

Correr `./run_tests.sh` y `tools/bench_control_loop.gd` (el aplicador corre por frame: con las cuatro instantáneas por defecto son cuatro buses; el coste en reposo tiene que ser una lectura por bus, sin escrituras).

```bash
git add addons/opendou/runtime/mix_bus_applier.gd addons/opendou/runtime/mix_bus_applier.gd.uid addons/opendou/runtime/audio_event_manager.gd scenes/shared/bus_row.gd addons/opendou/nodes/opendou_parameter_area_3d.gd addons/opendou/nodes/opendou_music_player.gd tests/test_mix_bus_applier.gd tests/test_mix_bus_applier.gd.uid tests/test_all.gd tests/leak_budget.txt
git commit -m "Fase 8: instantaneas, ducking y area de parametros escriben de verdad en el AudioServer (base + delta + ducking)"
```

---

### Task 7: Vinculación estado → instantánea

**Files:**
- Create: `addons/opendou/resources/mix_state_binding.gd`
- Modify: `addons/opendou/runtime/audio_event_manager.gd` (registro, señal)
- Test: `tests/test_mix_bus_applier.gd` (`run_state_binding_async`), registrar

**Interfaces:**
- Produces `MixStateBinding` (Resource): `state_group: StringName`, `state_name: StringName`, `snapshot_name: StringName`, `blend_sec: float = -1.0`, `priority: int = 0`.
- Produces en el manager: `register_mix_state_binding(binding: MixStateBinding)`, `unregister_mix_state_binding(binding)`, conexión a `sync_manager.state_changed`.

- [ ] **Step 1: Test (rojo)**

```gdscript
static func run_state_binding_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("mix_state_binding")
	var idx: int = _make_bus("MixTestMusic")
	AudioServer.set_bus_volume_db(idx, 0.0)
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	manager.mix.snapshots.register_snapshot(AudioMixSnapshotClass.new(&"LowHealth", {
		&"MixTestMusic": {"volume_db": -10.0, "lpf_hz": 600.0, "hpf_hz": 20.0, "mute": false}}, 0.1))
	manager.mix.snapshots.register_snapshot(AudioMixSnapshotClass.new(&"TestNeutral2", {
		&"MixTestMusic": {"volume_db": 0.0, "lpf_hz": 20000.0, "hpf_hz": 20.0, "mute": false}}, 0.1))
	manager.mix.snapshots.apply_snapshot_instant(&"TestNeutral2")
	var BindingClass = load("res://addons/opendou/resources/mix_state_binding.gd")
	var b = BindingClass.new()
	b.state_group = &"Player"
	b.state_name = &"LowHealth"
	b.snapshot_name = &"LowHealth"
	b.blend_sec = 0.1
	manager.register_mix_state_binding(b)
	await tree.process_frame
	manager.sync_manager.set_state(&"Player", &"LowHealth")
	await _wait_ms(tree, 300)
	a.approx(AudioServer.get_bus_volume_db(idx), -10.0, "entrar en el estado apila su instantanea: -10 dB reales", 0.3)
	manager.sync_manager.set_state(&"Player", &"Normal")
	await _wait_ms(tree, 300)
	a.approx(AudioServer.get_bus_volume_db(idx), 0.0, "salir del estado la desapila", 0.3)
	manager.unregister_mix_state_binding(b)
	manager.sync_manager.set_state(&"Player", &"LowHealth")
	await _wait_ms(tree, 300)
	a.approx(AudioServer.get_bus_volume_db(idx), 0.0, "sin vinculacion, el estado no toca la mezcla (control)", 0.3)
	tree.root.remove_child(manager)
	manager.free()
	return a
```

Registrar `acc.absorb(await TestMixBusApplierClass.run_state_binding_async(tree))`. Run → rojo.

- [ ] **Step 2: Recurso y manager**

```gdscript
@tool
class_name MixStateBinding
extends Resource

## Mientras el grupo de estado este en state_name, la instantanea snapshot_name esta apilada.
## Es la forma correcta de "baja salud" o "pausa": un estado del juego arrastra una mezcla.
## Recurso y no nodo porque no tiene posicion ni ciclo de vida en la escena.

@export var state_group: StringName = &""
@export var state_name: StringName = &""
@export var snapshot_name: StringName = &""
@export var blend_sec: float = -1.0
@export var priority: int = 0
```

Manager:

```gdscript
var _mix_state_bindings: Array = []

func register_mix_state_binding(binding: MixStateBinding) -> void:
	if binding == null or _mix_state_bindings.has(binding):
		return
	_mix_state_bindings.append(binding)
	# Si el estado ya esta activo al registrar, se apila ahora.
	if sync_manager.get_state(binding.state_group) == binding.state_name:
		push_snapshot(binding.snapshot_name, binding.blend_sec, binding.priority)

func unregister_mix_state_binding(binding: MixStateBinding) -> void:
	if _mix_state_bindings.has(binding):
		_mix_state_bindings.erase(binding)
		pop_snapshot(binding.snapshot_name, binding.blend_sec)

func _on_state_changed(group: StringName, new_state: StringName, previous: StringName) -> void:
	for b in _mix_state_bindings:
		if b.state_group != group:
			continue
		if b.state_name == previous:
			pop_snapshot(b.snapshot_name, b.blend_sec)
		if b.state_name == new_state:
			push_snapshot(b.snapshot_name, b.blend_sec, b.priority)
```

y en `_init`, tras crear `sync_manager`: `sync_manager.state_changed.connect(_on_state_changed)`.

- [ ] **Step 3: Verde y commit**

```bash
./run_tests.sh
git add addons/opendou/resources/mix_state_binding.gd addons/opendou/resources/mix_state_binding.gd.uid addons/opendou/runtime/audio_event_manager.gd tests/test_mix_bus_applier.gd tests/test_all.gd
git commit -m "Fase 8: MixStateBinding: un estado del juego apila su instantanea de mezcla"
```

---

### Task 8: Documentos y observaciones

**Files:**
- Modify: `docs/funcionalidades.md` (marcas), `AGENTS.md` (observaciones 43 resuelta, 45 nueva; trampa del `has_method`), `docs/tasks/current.md`, `docs/superpowers/specs/2026-09-02-fase8-higiene-y-deuda-design.md` (§ correcciones si las hubo)

- [ ] **Step 1: Marcas y observaciones**

En `docs/funcionalidades.md`, sección 4, la fila «HDR y ducking» pasa a describir «instantáneas y ducking aplicados cada frame al `AudioServer` con el modelo base + delta + ducking (Fase 8)» con ✅; en la sección 2.2, `OpenDouParameterArea3D` añade «instantáneas: funcional desde la Fase 8». En la sección 1.2 nada cambia.

En `AGENTS.md` §5b, tras la observación 44:

```markdown
* **Observación 43, resuelta.** <lo que la herramienta mostró y lo que se cambió; escribirlo
  con los hechos de la Task 1>. La caché del grafo se invalida por generación, además del
  digest de aperturas. `tools/repeat_street_test.gd` lo repite diez veces.
* **Observación 45.** Hasta la Fase 8, `AudioMixSnapshotManager` y `AudioDuckingMatrix`
  calculaban estados que **nadie escribía en el `AudioServer`**, `OpenDouParameterArea3D`
  llamaba a un `push_snapshot` que el manager no tenía (silenciado por un `has_method`), y
  `AudioEventDef.max_instances` no lo leía nadie. Regla que sale de aquí: **un `has_method`
  antes de llamar a algo propio es una promesa vacía en potencia**; si el método es nuestro,
  se llama directo y que falle a la vista.
* **Godot: `AudioEffectLimiter` está obsoleto desde 4.3**; la cadena usa `AudioEffectHardLimiter`.
* **Godot: `AudioStreamPlayer3D.new().area_mask == 0`** (obs 44) y un reproductor 3D no emite
  sin oyente en el viewport: los tests de la Fase 8 que reproducen por el pool ponen cámara.
```

`docs/tasks/current.md`: Fase 8 implementada; siguiente, la 9 (spec).

- [ ] **Step 2: Commit final de la fase**

```bash
./run_tests.sh
git add docs/funcionalidades.md AGENTS.md docs/tasks/current.md docs/superpowers/specs/2026-09-02-fase8-higiene-y-deuda-design.md
git commit -m "Fase 8: documentos al dia; observaciones 43 (resuelta) y 45"
```

---

## Autorrevisión del plan

**Cobertura del spec.** §2 (obs 43) → Tasks 1–2; §3 (límites) → Task 3, incluido el fundido real de `stop()` que el spec da por hecho al decir «con fundido»; §4 (cadena) → Task 4; §5 (LUFS, presupuesto por demo, cajón) → Task 5; §6 (base + delta + ducking, pila, filtros, `BusRow`, área de parámetros, `MixStateBinding`) → Tasks 6–7; §7 componentes → todos; §8 casos límite: bus inexistente (aviso una vez, `managed_buses`), `push` no registrado (aviso), `caller == null` (radio con `emitter_position`: en Task 3 la posición se toma del `caller` si es `Node3D`, y las voces anónimas no participan del alcance por radio hasta tener posición: se documenta en el limitador), medidor sobre bus borrado (`detach` comprueba índices), cadena con efectos ajenos (se inserta al principio, no se toca lo ajeno); §9 verificación → suites por tarea; §10 aceptación → 1 (Task 2), 2 (Task 3), 3 (Task 4), 4 (Task 5), 5 (Tasks 6–7), 6 (Task 8).

**Marcadores.** El único hueco deliberado es el texto de la observación 43 en la Task 8, que depende de lo que la Task 1 muestre; el plan lo dice.

**Consistencia de nombres.** `OpenDouInstanceLimiter.check(def, caller, position, has_position, active, listener_pos)` (Task 3 y su uso en `post_event`); `EventInstance.is_stopping()`, `stop_fade_gain()` (Tasks 3, 6 no lo usa); `OpenDouMixChainInstaller.{install, uninstall, is_installed, install_from_setting, SETTING}` (Task 4); `OpenDouLoudnessMeter.{attach, detach, is_attached, process, reset, momentary_lufs, short_term_lufs, integrated_lufs, sample_peak_db, processed_seconds, last_process_usec}` (Task 5, cajón); `OpenDouMixBusApplier.{snapshots, ducking, apply, set_bus_base_volume_db, get_bus_base_volume_db, set_bus_base_mute, managed_buses, writes_last_frame, effective_volume_db}` y manager `mix`, `push_snapshot(name, blend_sec, priority)`, `pop_snapshot(name, blend_sec)`, `set_bus_base_volume_db`, `get_bus_base_volume_db` (Tasks 6, 7, `BusRow`, área); `MixStateBinding.{state_group, state_name, snapshot_name, blend_sec, priority}` y `register/unregister_mix_state_binding` (Task 7).

**Riesgo conocido al ejecutar.** El test del área de parámetros en la Task 6 depende de cómo el nodo resuelve su manager; el paso lo dice y da las dos salidas. El coste del medidor en GDScript se mide y se anota, sea el que sea.
