# Fase 7B — Binaural para todas las voces: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que toda voz física 3D de OpenDou salga por un panner propio sobre Steam Audio (HRTF + ITD esférico + filtros de oclusión y distancia) cuando la extensión nativa está presente, y por el panner de Godot corregido cuando no lo está.

**Architecture:** El plano de control (eventos, pool, robo, HDR, grafo de salas, oclusión) no cambia. El canal físico calcula cada frame dirección en el espacio del oyente, atenuación y filtros con las fórmulas de Godot, y las empuja o bien a un `AudioStreamPlayer` estéreo con un `OpenDouSpatialStream` nativo (backend `steam_audio`), o bien al `AudioStreamPlayer3D` de siempre (backend `godot`). Los emisores de nodo dejan de sonar por sí mismos en `steam_audio` y aportan posición.

**Tech Stack:** Godot 4.7.2 (GDScript), godot-cpp `master` @ `26fb7ab` (API 4.7), Steam Audio 4.8.1 binario (Apache 2.0), CMake ≥ 3.22, Apple clang, macOS arm64.

**Spec:** `docs/superpowers/specs/2026-09-02-fase7b-binaural-todas-las-voces-design.md`

## Global Constraints

- Una sola rama: `main`. Cada tarea termina en commit.
- `./run_tests.sh` verde antes de cada commit: sin `SCRIPT ERROR`, sin `Parse Error`, fugas ≤ `tests/leak_budget.txt`, `STATUS: PASSED`. Si un test nuevo reproduce audio y sube las fugas, se mide aislado y se justifica en `leak_budget.txt` como hace el historial del archivo.
- Toda aserción de audio se hace sobre audio capturado del bus con `OpenDouAudioProbe`, con un control que apaga el mecanismo. La fuente de los tests binaurales es el ruido **periódico de 1024 muestras** de `test_binaural_spike.gd` (`_periodic_noise`).
- Si la extensión no está compilada, las suites binaurales se omiten **y lo imprimen**: `[OpenDou] extension nativa AUSENTE: suite <nombre> omitida`.
- Escenas: la estructura vive en el `.tscn`; el script solo conecta (`.agents/rules/04_scene_composition.md`). Ningún `.play(` fuera de receptores tipados OpenDou.
- Valores por defecto de Godot copiados de `scene/3d/audio_stream_player_3d.{h,cpp}` de la rama 4.7: `unit_size = 10.0`, `max_db = 3.0`, `max_distance = 0.0`, `attenuation_model = INVERSE_DISTANCE`, `attenuation_filter_cutoff_hz = 5000.0`, `attenuation_filter_db = -24.0`.
- Ejes: +X derecha, +Y arriba, −Z adelante (Godot y Steam Audio coinciden).
- ITD: `r = 0.0875 m`, `c = 343 m/s`, `ITD_esfera = (r/c)·(θ + sin θ)·cos φ`; se aplica `max(0, ITD_esfera − residuo)` al oído lejano; línea de retardo de 2 ms máx.
- Bloque nativo: `opendou/spatial/frame_size` ∈ {256, 512, 1024}, 512 por defecto.
- Compilación nativa: `cd native && ./build.sh` (Task 14) o, hasta entonces, `cmake -S native -B native/build/ext -DCMAKE_BUILD_TYPE=Release && cmake --build native/build/ext --parallel`.
- Comentarios y mensajes en español, sin tildes en los comentarios de código (convención del repo), con tildes en los documentos.
- Sin CI, sin doppler, sin efecto directo: fuera de alcance (spec §12).

---

## Estructura de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `addons/opendou/runtime/audio_event_manager.gd` | Elegir y exponer `spatial_backend`; pasar oyente al canal | 1, 9 |
| `addons/opendou/runtime/spatial/spatial_backend.gd` (nuevo, `OpenDouSpatialBackend`) | Leer el ajuste de proyecto y decidir el backend | 1 |
| `addons/opendou/resources/audio_event_def.gd` | Exports de atenuación por defecto | 2 |
| `addons/opendou/runtime/event_instance.gd` | Campos de atenuación de la voz | 2 |
| `addons/opendou/nodes/opendou_event_player_3d.gd` | Rellenar la instancia con sus exports de Godot | 2 |
| `addons/opendou/runtime/spatial/spatial_settings.gd` (nuevo, `OpenDouSpatialSettings`) | `user://opendou_audio.cfg` | 3 |
| `addons/opendou/runtime/spatial/distance_model.gd` (nuevo, `OpenDouDistanceModel`) | Fórmulas de Godot: atenuación, multiplicador, shelf, dirección | 4 |
| `addons/opendou/runtime/physical_voice_channel.gd` | `apply()` con oyente; obs 42; empuje al stream nativo | 5, 9 |
| `native/src/steam_audio_context.{h,cpp}` | HRTF con generación; frame_size configurable | 8 |
| `native/src/dsp.h` (nuevo) | Biquad LPF, high-shelf, línea de retardo fraccionaria, Woodworth | 6, 7 |
| `native/src/spatial_stream.{h,cpp}` | Propiedades nuevas, cadena de proceso, `benchmark_block` | 6, 7, 8 |
| `addons/opendou/runtime/native_player_pool.gd` | `PlayerKind.BINAURAL_3D` | 9 |
| `addons/opendou/runtime/voice_pool_manager.gd` | Enrutar por backend; nodos como fuente de posición | 9, 10 |
| `scenes/shared/pause_menu.{tscn,gd}` | Bloque «Espacialización» | 12 |
| `scenes/shared/demo_hud.gd` | Línea con el backend activo | 12 |
| `tests/test_spatial_backend.gd`, `tests/test_distance_model.gd`, `tests/test_spatial_settings.gd`, `tests/test_binaural.gd`, `tests/test_backend_parity.gd` | Suites nuevas | varias |
| `tests/test_binaural_spike.gd` → `tests/test_binaural.gd` | Renombrado y ampliado | 6 |
| `tools/bench_control_loop.gd`, `tests/dsp_budget.txt` | Guardas de coste | 15 |
| `native/build.sh`, `addons/opendou/THIRD_PARTY_NOTICES.md`, `README.md`, `AGENTS.md`, `docs/architecture/gdextension_api.md`, `docs/tasks/current.md` | Compilación y documentos | 14 |
| `addons/opendou/core/spatial/audio_spatial_binaural.gd` | Se retira | 13 |
| `addons/opendou/editor/nodes/opendou_binaural_graph_node.gd` | Reescritura | 13 |

Convenciones de la suite: cada `tests/test_x.gd` es `class_name TestX extends RefCounted` con `static func run_all() -> OpenDouAssert` (síncrono) o `static func run_all_async(tree: SceneTree) -> OpenDouAssert`, y se registra en `tests/test_all.gd` con `acc.absorb(...)` o `total_tests += res.assertions_run`.

---

### Task 1: El backend espacial se elige al arrancar y se expone

**Files:**
- Create: `addons/opendou/runtime/spatial/spatial_backend.gd`
- Modify: `addons/opendou/runtime/audio_event_manager.gd:82-95` (`_init`)
- Test: `tests/test_spatial_backend.gd`, registrar en `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouSpatialBackend.SETTING: String = "opendou/spatial/backend"`, `OpenDouSpatialBackend.GODOT: StringName = &"godot"`, `OpenDouSpatialBackend.STEAM_AUDIO: StringName = &"steam_audio"`, `static func resolve(setting_value: String, native_available: bool) -> StringName`, `static func read_setting() -> String`, `static func native_available() -> bool`. En el manager: `var spatial_backend: StringName` (solo lectura por convención) y `func is_steam_audio_backend() -> bool`.

- [ ] **Step 1: Test de la regla de decisión (puro, sin audio)**

```gdscript
class_name TestSpatialBackend
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spatial_backend")
	# auto: depende de si la extension esta.
	a.eq(BackendClass.resolve("auto", true), &"steam_audio", "auto con extension -> steam_audio")
	a.eq(BackendClass.resolve("auto", false), &"godot", "auto sin extension -> godot")
	# forzado a godot: ignora la extension.
	a.eq(BackendClass.resolve("godot", true), &"godot", "godot forzado aunque haya extension")
	# forzado a steam_audio sin extension: cae a godot (y lo dice por consola).
	a.eq(BackendClass.resolve("steam_audio", false), &"godot", "steam_audio sin extension cae a godot")
	a.eq(BackendClass.resolve("steam_audio", true), &"steam_audio", "steam_audio con extension")
	# valores raros: como auto.
	a.eq(BackendClass.resolve("lo_que_sea", false), &"godot", "valor desconocido se trata como auto")
	# El ajuste de proyecto existe con su defecto.
	a.eq(BackendClass.read_setting(), "auto", "el ajuste de proyecto vale auto por defecto")

	# El manager lo expone y coincide con la regla.
	var ManagerClass = load("res://addons/opendou/runtime/audio_event_manager.gd")
	var manager = ManagerClass.new()
	var expected: StringName = BackendClass.resolve(BackendClass.read_setting(), BackendClass.native_available())
	a.eq(manager.spatial_backend, expected, "el manager expone el backend resuelto")
	a.eq(manager.is_steam_audio_backend(), expected == &"steam_audio", "is_steam_audio_backend coincide")
	manager.free()
	return a
```

- [ ] **Step 2: Registrar en `tests/test_all.gd` y ver fallar**

Añadir `const TestSpatialBackendClass = preload("res://tests/test_spatial_backend.gd")` junto a los demás preloads y, antes del `return {` de `run_suite()`:

```gdscript
	var backend_res = TestSpatialBackendClass.run_all()
	total_tests += backend_res.assertions_run
	all_failures.append_array(backend_res.failures)
```

Run: `./run_tests.sh`
Expected: FALLO con `Parse Error` por `spatial_backend.gd` inexistente (el runner lo trata como fatal). Es el rojo esperado.

- [ ] **Step 3: Implementar `spatial_backend.gd`**

```gdscript
class_name OpenDouSpatialBackend
extends RefCounted

## Decide UNA vez, al arrancar, quien convierte las voces 3D en estereo.
##
## `godot`: el AudioStreamPlayer3D de siempre. `steam_audio`: un AudioStreamPlayer estereo
## con OpenDouSpatialStream (HRTF + ITD) por canal. No hay cambio en caliente: los
## reproductores del pool se crean por tipo, y el conmutador audifonos/altavoces ya es en
## vivo sin necesidad de cambiar de backend.

const SETTING: String = "opendou/spatial/backend"
const GODOT: StringName = &"godot"
const STEAM_AUDIO: StringName = &"steam_audio"

## Registra el ajuste de proyecto con su defecto si no existe. Idempotente.
static func ensure_setting() -> void:
	if not ProjectSettings.has_setting(SETTING):
		ProjectSettings.set_setting(SETTING, "auto")
	ProjectSettings.set_initial_value(SETTING, "auto")
	ProjectSettings.add_property_info({
		"name": SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "auto,godot,steam_audio",
	})

static func read_setting() -> String:
	ensure_setting()
	return str(ProjectSettings.get_setting(SETTING, "auto"))

## true si la extension esta cargada Y Steam Audio se inicializo.
static func native_available() -> bool:
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		return false
	if not ClassDB.class_has_method("OpenDouSpatialStream", "is_native_available"):
		return false
	return bool(ClassDB.class_call_static("OpenDouSpatialStream", "is_native_available"))

## La regla, separada de sus entradas para poder afirmarla sin extension.
static func resolve(setting_value: String, p_native_available: bool) -> StringName:
	match setting_value:
		"godot":
			return GODOT
		"steam_audio":
			if p_native_available:
				return STEAM_AUDIO
			push_error("[OpenDou] opendou/spatial/backend = steam_audio pero la extension nativa no esta cargada: se usa el backend de Godot")
			return GODOT
		_:
			return STEAM_AUDIO if p_native_available else GODOT
```

- [ ] **Step 4: Exponerlo en el manager**

En `audio_event_manager.gd`, junto a los preloads: `const SpatialBackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")`. Junto a `var active_listener_position`:

```gdscript
## Quien convierte las voces 3D en estereo: &"godot" o &"steam_audio". Se decide una vez
## en _init y no cambia en caliente. Lo leen el pool de voces, el menu, el HUD y la suite.
var spatial_backend: StringName = &"godot"
```

Al principio de `_init()`:

```gdscript
	spatial_backend = SpatialBackendClass.resolve(SpatialBackendClass.read_setting(), SpatialBackendClass.native_available())
```

Y el método:

```gdscript
func is_steam_audio_backend() -> bool:
	return spatial_backend == SpatialBackendClass.STEAM_AUDIO
```

- [ ] **Step 5: Verde y commit**

Run: `./run_tests.sh`
Expected: `STATUS: PASSED`, 7 aserciones más.

```bash
git add addons/opendou/runtime/spatial/spatial_backend.gd addons/opendou/runtime/spatial/spatial_backend.gd.uid addons/opendou/runtime/audio_event_manager.gd tests/test_spatial_backend.gd tests/test_spatial_backend.gd.uid tests/test_all.gd
git commit -m "Fase 7B: el backend espacial se elige al arrancar y se expone en el manager"
```

---

### Task 2: Los parámetros de atenuación viajan en la instancia

**Files:**
- Modify: `addons/opendou/resources/audio_event_def.gd:56-58` (exports)
- Modify: `addons/opendou/runtime/event_instance.gd:49` (campos) y `:112-118` (`_init`)
- Modify: `addons/opendou/nodes/opendou_event_player_3d.gd:130-136` (tras `bind_player(self)`)
- Test: `tests/test_event_instance.gd` (añadir aserciones; su `run_all()` devuelve `Array[String]` y `test_all.gd` cuenta 5: se sube a 8)

**Interfaces:**
- Produces en `AudioEventDef`: `@export var unit_size: float = 10.0`, `@export var attenuation_max_distance: float = 0.0`, `@export_enum("Inverse", "Inverse Square", "Logarithmic", "Disabled") var attenuation_model: int = 0`, `@export var attenuation_filter_cutoff_hz: float = 5000.0`, `@export var attenuation_filter_db: float = -24.0`.
- Produces en `EventInstance`: los mismos cinco campos más `var emitter_volume_db: float = 0.0`, y `func copy_attenuation_from_player(player: AudioStreamPlayer3D) -> void`.
- Los enteros del modelo coinciden con `AudioStreamPlayer3D.AttenuationModel`: 0 inversa, 1 inversa cuadrática, 2 logarítmica, 3 desactivada.

- [ ] **Step 1: Test**

Al final de `run_all()` en `tests/test_event_instance.gd`, antes del `return failures`:

```gdscript
	# Fase 7B: la instancia lleva los parametros de atenuacion con los defectos de Godot,
	# y los copia del emisor de nodo cuando lo hay.
	var def7 = AudioEventDef.new(&"Atten")
	var inst7 = EventInstance.new(def7, null)
	if not is_equal_approx(inst7.unit_size, 10.0) or not is_equal_approx(inst7.attenuation_filter_cutoff_hz, 5000.0) or not is_equal_approx(inst7.attenuation_filter_db, -24.0) or inst7.attenuation_model != 0 or not is_equal_approx(inst7.attenuation_max_distance, 0.0):
		failures.append("7B-a: la instancia no arranca con los defectos de atenuacion de Godot")
	def7.unit_size = 4.0
	def7.attenuation_model = 2
	var inst7b = EventInstance.new(def7, null)
	if not is_equal_approx(inst7b.unit_size, 4.0) or inst7b.attenuation_model != 2:
		failures.append("7B-b: la instancia no copia la atenuacion de la definicion")
	var p3 = AudioStreamPlayer3D.new()
	p3.unit_size = 2.5
	p3.max_distance = 30.0
	p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
	p3.attenuation_filter_cutoff_hz = 3000.0
	p3.attenuation_filter_db = -12.0
	p3.volume_db = -6.0
	inst7b.copy_attenuation_from_player(p3)
	if not is_equal_approx(inst7b.unit_size, 2.5) or not is_equal_approx(inst7b.attenuation_max_distance, 30.0) or inst7b.attenuation_model != 1 or not is_equal_approx(inst7b.attenuation_filter_cutoff_hz, 3000.0) or not is_equal_approx(inst7b.attenuation_filter_db, -12.0) or not is_equal_approx(inst7b.emitter_volume_db, -6.0):
		failures.append("7B-c: copy_attenuation_from_player no copia los seis valores del nodo")
	if not is_equal_approx(inst7b.max_distance, 100.0):
		failures.append("7B-d: max_distance del robo de voces NO debe cambiar al copiar la atenuacion")
	p3.free()
```

En `tests/test_all.gd` cambiar el contador de `TestEventInstanceClass` de `total_tests += 5` a `total_tests += 9`.

- [ ] **Step 2: Rojo**

Run: `./run_tests.sh`
Expected: FALLO con `SCRIPT ERROR` (propiedad `unit_size` inexistente en `EventInstance`).

- [ ] **Step 3: Exports en la definición**

En `audio_event_def.gd`, tras `@export var base_priority: float = 50.0`:

```gdscript
## Atenuacion por distancia con los DEFECTOS DE GODOT (AudioStreamPlayer3D), para que
## cambiar de backend espacial no cambie el volumen. Un emisor de nodo los pisa con los
## suyos; una voz anonima usa estos.
@export_group("Distance Attenuation")
@export var unit_size: float = 10.0
## 0 = sin limite. Distinto de max_distance (robo de voces): unificarlos rompia la paridad.
@export var attenuation_max_distance: float = 0.0
@export_enum("Inverse", "Inverse Square", "Logarithmic", "Disabled") var attenuation_model: int = 0
@export var attenuation_filter_cutoff_hz: float = 5000.0
@export var attenuation_filter_db: float = -24.0
```

- [ ] **Step 4: Campos en la instancia y copia desde el nodo**

En `event_instance.gd`, tras `var max_distance: float = 100.0`:

```gdscript
# Atenuacion por distancia (Fase 7B). Con los defectos de Godot; ver AudioEventDef.
var unit_size: float = 10.0
var attenuation_max_distance: float = 0.0
var attenuation_model: int = 0
var attenuation_filter_cutoff_hz: float = 5000.0
var attenuation_filter_db: float = -24.0
## volume_db del emisor de nodo; 0 en las voces anonimas.
var emitter_volume_db: float = 0.0
```

En `_init`, dentro de `if definition:` tras `virtualization_mode = definition.virtualization_mode`:

```gdscript
		unit_size = definition.unit_size
		attenuation_max_distance = definition.attenuation_max_distance
		attenuation_model = definition.attenuation_model
		attenuation_filter_cutoff_hz = definition.attenuation_filter_cutoff_hz
		attenuation_filter_db = definition.attenuation_filter_db
```

Nuevo método, junto a `set_position`:

```gdscript
## Copia la atenuacion de un reproductor 3D de Godot: es lo que hace que un emisor de nodo
## suene igual en los dos backends. No toca max_distance, que es del robo de voces.
func copy_attenuation_from_player(player: AudioStreamPlayer3D) -> void:
	if player == null:
		return
	unit_size = player.unit_size
	attenuation_max_distance = player.max_distance
	attenuation_model = int(player.attenuation_model)
	attenuation_filter_cutoff_hz = player.attenuation_filter_cutoff_hz
	attenuation_filter_db = player.attenuation_filter_db
	emitter_volume_db = player.volume_db
```

En `opendou_event_player_3d.gd`, justo después de `active_instance.bind_player(self)`:

```gdscript
		active_instance.copy_attenuation_from_player(self)
```

- [ ] **Step 5: Verde y commit**

Run: `./run_tests.sh` → `STATUS: PASSED`.

```bash
git add addons/opendou/resources/audio_event_def.gd addons/opendou/runtime/event_instance.gd addons/opendou/nodes/opendou_event_player_3d.gd tests/test_event_instance.gd tests/test_all.gd
git commit -m "Fase 7B: la instancia lleva la atenuacion por distancia con los defectos de Godot"
```

---

### Task 3: Ajustes del jugador en `user://opendou_audio.cfg`

**Files:**
- Create: `addons/opendou/runtime/spatial/spatial_settings.gd`
- Test: `tests/test_spatial_settings.gd`, registrar en `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouSpatialSettings` con `const PATH = "user://opendou_audio.cfg"`, `var hrtf: String = "default"`, `var blend: float = 1.0`, `var output: String = "headphones"`, `func load_from_disk(path: String = PATH) -> void`, `func save_to_disk(path: String = PATH) -> Error`, `func set_hrtf(value: String) -> void`, `func set_blend(value: float) -> void`, `func set_output(value: String) -> void`, `signal changed`. Aplicarlos al pool es de la Task 12; aquí solo persistencia y validación.

- [ ] **Step 1: Test**

```gdscript
class_name TestSpatialSettings
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const SettingsClass = preload("res://addons/opendou/runtime/spatial/spatial_settings.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spatial_settings")
	var path := "user://opendou_audio_test.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var s = SettingsClass.new()
	a.eq(s.hrtf, "default", "HRTF por defecto")
	a.approx(s.blend, 1.0, "mezcla por defecto 1.0")
	a.eq(s.output, "headphones", "salida por defecto audifonos")

	# Cargar sin archivo deja los defectos y no falla.
	s.load_from_disk(path)
	a.eq(s.output, "headphones", "cargar sin archivo conserva los defectos")

	var changes: int = 0
	s.changed.connect(func(): changes += 1)
	s.set_blend(0.35)
	s.set_output("speakers")
	s.set_hrtf("user://mi_cabeza.sofa")
	a.eq(changes, 3, "cada cambio emite changed")
	a.eq(s.save_to_disk(path), OK, "guarda en disco")

	var s2 = SettingsClass.new()
	s2.load_from_disk(path)
	a.approx(s2.blend, 0.35, "recarga la mezcla")
	a.eq(s2.output, "speakers", "recarga la salida")
	a.eq(s2.hrtf, "user://mi_cabeza.sofa", "recarga el HRTF")

	# Valores invalidos se saneen: la mezcla se acota, la salida vuelve a audifonos.
	s2.set_blend(7.0)
	a.approx(s2.blend, 1.0, "la mezcla se acota a 1")
	s2.set_output("subwoofer")
	a.eq(s2.output, "headphones", "una salida desconocida vuelve a audifonos")
	s2.set_hrtf("")
	a.eq(s2.hrtf, "default", "un HRTF vacio vuelve a default")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return a
```

Registrar en `test_all.gd` (`const TestSpatialSettingsClass = preload(...)`; en `run_suite()` tras el bloque de Task 1):

```gdscript
	var settings_res = TestSpatialSettingsClass.run_all()
	total_tests += settings_res.assertions_run
	all_failures.append_array(settings_res.failures)
```

- [ ] **Step 2: Rojo** — `./run_tests.sh` falla por `Parse Error` (archivo inexistente).

- [ ] **Step 3: Implementar**

```gdscript
class_name OpenDouSpatialSettings
extends RefCounted

## Ajustes de espacializacion DEL JUGADOR: HRTF, mezcla y salida. Persisten en user://.
##
## Es el primer almacen de ajustes de usuario del plugin. Solo persiste y valida; aplicarlos
## a los streams del pool lo hace el AudioEventManager al recibir `changed`.

signal changed

const PATH: String = "user://opendou_audio.cfg"
const SECTION: String = "spatial"
const OUTPUTS: PackedStringArray = ["headphones", "speakers"]

var hrtf: String = "default"
var blend: float = 1.0
var output: String = "headphones"

func set_hrtf(value: String) -> void:
	hrtf = value if not value.is_empty() else "default"
	changed.emit()

func set_blend(value: float) -> void:
	blend = clampf(value, 0.0, 1.0)
	changed.emit()

func set_output(value: String) -> void:
	output = value if OUTPUTS.has(value) else "headphones"
	changed.emit()

## Lee el archivo si existe. Sin archivo, conserva los defectos y no emite nada.
func load_from_disk(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	hrtf = str(cfg.get_value(SECTION, "hrtf", "default"))
	if hrtf.is_empty():
		hrtf = "default"
	blend = clampf(float(cfg.get_value(SECTION, "blend", 1.0)), 0.0, 1.0)
	output = str(cfg.get_value(SECTION, "output", "headphones"))
	if not OUTPUTS.has(output):
		output = "headphones"

func save_to_disk(path: String = PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "hrtf", hrtf)
	cfg.set_value(SECTION, "blend", blend)
	cfg.set_value(SECTION, "output", output)
	return cfg.save(path)
```

- [ ] **Step 4: Verde y commit**

```bash
git add addons/opendou/runtime/spatial/spatial_settings.gd addons/opendou/runtime/spatial/spatial_settings.gd.uid tests/test_spatial_settings.gd tests/test_spatial_settings.gd.uid tests/test_all.gd
git commit -m "Fase 7B: ajustes de espacializacion del jugador en user://"
```

---

### Task 4: El modelo de distancia de Godot como funciones puras

**Files:**
- Create: `addons/opendou/runtime/spatial/distance_model.gd`
- Test: `tests/test_distance_model.gd`, registrar en `tests/test_all.gd`

**Interfaces:**
- Produces `OpenDouDistanceModel` (todo `static`):
  - `attenuation_db(distance: float, model: int, unit_size: float) -> float` — solo el modelo, sin volumen ni tope.
  - `multiplier(distance: float, model: int, unit_size: float, volume_db: float, max_db: float, attenuation_max_distance: float) -> float` — lineal; 0 si `attenuation_max_distance > 0 and distance > attenuation_max_distance`.
  - `gain_db_for_stream(distance, model, unit_size, volume_db, attenuation_max_distance) -> float` — `linear_to_db(multiplier)` con `max_db = 3.0`, **sin** el volumen (que va al reproductor): `min(att + V, 3) − V`, y el factor de `attenuation_max_distance`; −80 si el multiplicador es 0.
  - `shelf_db(mult: float, attenuation_filter_db: float) -> float` — `(1 − min(1, mult)) · attenuation_filter_db`.
  - `listener_direction(source: Vector3, listener_position: Vector3, listener_basis: Basis) -> Vector3` — unitario en el espacio del oyente; `(0, 0, −1)` si la distancia es < 1 mm.
- Constantes: `MODEL_INVERSE = 0`, `MODEL_INVERSE_SQUARE = 1`, `MODEL_LOGARITHMIC = 2`, `MODEL_DISABLED = 3`, `MAX_DB = 3.0`.

- [ ] **Step 1: Test con los números de Godot**

```gdscript
class_name TestDistanceModel
extends RefCounted

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
	a.approx(DM.multiplier(5.0, DM.MODEL_INVERSE, 10.0, -6.0, 3.0, 0.0), db_to_linear(0.0), "con volumen -6, +6-6 = 0 dB no toca el tope", 0.001)
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
	a.ok(DM.listener_direction(Vector3(0, 0, -5), Vector3.ZERO, looking_minus_x).is_equal_approx(Vector3(-1, 0, 0)), "y lo que esta en -Z queda a su IZQUIERDA")
	a.ok(DM.listener_direction(Vector3(3, 2, 1), Vector3(3, 2, 1), Basis.IDENTITY).is_equal_approx(Vector3(0, 0, -1)), "a distancia cero, delante")
	a.ok(DM.listener_direction(Vector3(10, 4, -2), Vector3(1, 1, 1), Basis.IDENTITY).is_normalized(), "siempre unitario")
	return a
```

Registrar en `test_all.gd` como las anteriores (`distance_res`).

- [ ] **Step 2: Rojo** — `./run_tests.sh` falla por `Parse Error`.

- [ ] **Step 3: Implementar**

```gdscript
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
```

- [ ] **Step 4: Verde y commit**

```bash
git add addons/opendou/runtime/spatial/distance_model.gd addons/opendou/runtime/spatial/distance_model.gd.uid tests/test_distance_model.gd tests/test_distance_model.gd.uid tests/test_all.gd
git commit -m "Fase 7B: modelo de distancia de Godot como funciones puras"
```

---

### Task 5: El canal recibe al oyente y corrige la observación 42 en el backend de Godot

**Files:**
- Modify: `addons/opendou/runtime/physical_voice_channel.gd:91-113`
- Modify: `addons/opendou/runtime/audio_event_manager.gd:301-324` (`_apply_voices`) y `_update_listener`
- Test: `tests/test_backend_parity.gd` (nuevo; en esta tarea solo la parte de Godot), registrar en `run_async_suite`

**Interfaces:**
- Produces en `PhysicalVoiceChannel`: `func apply_spatial(instance: EventInstance, volume_db: float, pitch: float, cutoff_hz: float, listener_position: Vector3, listener_basis: Basis) -> void`. `apply()` se conserva para las voces sin posición.
- Produces en el manager: `var active_listener_basis: Basis = Basis.IDENTITY`, actualizada en `_update_listener()` desde `listener_resolver.basis`.

- [ ] **Step 1: Test asíncrono con audio real (backend Godot forzado)**

```gdscript
class_name TestBackendParity
extends RefCounted

## Paridad entre backends y correccion de la observacion 42. La parte binaural se anade en
## la Task 11; aqui solo el backend de Godot, que existe siempre.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")
const SpikeClass = preload("res://tests/test_binaural_spike.gd")   # por _periodic_noise y _band_energy

const BUS: StringName = &"ParityProbe"

## Crea un manager con el backend pedido. Restaura el ajuste al salir del test.
static func make_manager(tree: SceneTree, backend: String) -> Node:
	ProjectSettings.set_setting(BackendClass.SETTING, backend)
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	return manager

static func ensure_bus() -> void:
	if AudioServer.get_bus_index(String(BUS)) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, String(BUS))
		AudioServer.set_bus_send(idx, "Master")

## Nivel RMS y relacion de banda alta (>5 kHz / 1-4 kHz) de una voz posteada a `distance`
## metros delante del oyente, tras asentarse.
static func measure_voice(tree: SceneTree, manager: Node, probe, distance: float) -> Dictionary:
	var noise := SpikeClass._periodic_noise(int(AudioServer.get_mix_rate()))
	var def = AudioEventDefClass.new(&"ParityVoice", noise)
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = BUS
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(0, 0, -distance))
	for i in range(10):
		await tree.process_frame
		probe.drain()
	var l := PackedFloat32Array()
	var r := PackedFloat32Array()
	for i in range(30):
		await tree.process_frame
		var avail: int = probe._capture.get_frames_available()
		if avail > 0:
			for v in probe._capture.get_buffer(avail):
				l.append(v.x)
				r.append(v.y)
	inst.stop()
	await probe.await_silence(tree, 0.002, 30)
	var rms: float = 0.0
	var n: int = mini(l.size(), r.size())
	for i in range(n):
		rms += 0.5 * (l[i] * l[i] + r[i] * r[i])
	rms = sqrt(rms / maxf(float(n), 1.0))
	return {"rms_db": linear_to_db(maxf(rms, 1e-9)), "high_ratio": SpikeClass._pinna_band_ratio({"left": l, "right": r}, AudioServer.get_mix_rate()), "samples": n}

static func run_godot_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("backend_godot")
	var previous: String = str(ProjectSettings.get_setting(BackendClass.SETTING, "auto"))
	ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(BUS, 2.0)
	var manager = make_manager(tree, "godot")
	await tree.process_frame
	a.eq(manager.spatial_backend, &"godot", "el manager quedo en el backend de Godot")

	var near := await measure_voice(tree, manager, probe, 10.0)
	var far := await measure_voice(tree, manager, probe, 40.0)
	a.gt(float(near.samples), 4096.0, "se capturo audio a 10 m")
	# Observacion 42: a 40 m con unit_size 10 el multiplicador es 0.25 y el shelf de Godot
	# vale -18 dB por encima de 5 kHz. Antes de la correccion, OpenDou pisaba el corte con
	# 20 kHz y la banda alta NO caia.
	a.lt(far.high_ratio, near.high_ratio * 0.5, "a 40 m la banda alta cae al menos a la mitad respecto a 10 m (obs 42 corregida)")
	# Nivel: inversa a la distancia, 10 -> 40 m son -12 dB, con margen por el shelf.
	a.lt(far.rms_db - near.rms_db, -9.0, "a 40 m el nivel cae al menos 9 dB")
	print("[OpenDou] godot: 10 m %.1f dB ratio %.3f | 40 m %.1f dB ratio %.3f" % [near.rms_db, near.high_ratio, far.rms_db, far.high_ratio])

	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous)
	return a
```

En `test_all.gd`, `run_async_suite`: `acc.absorb(await TestBackendParityClass.run_godot_async(tree))` tras el spike, con su `const`.

- [ ] **Step 2: Rojo** — `./run_tests.sh`: falla `a.lt(far.high_ratio, ...)` porque el corte se pisa con 20 kHz.

- [ ] **Step 3: `apply_spatial` y la corrección**

En `physical_voice_channel.gd`, junto a los preloads: `const DistanceModelClass = preload("res://addons/opendou/runtime/spatial/distance_model.gd")`. Tras `apply()`:

```gdscript
## Version espacial de apply(): recibe la instancia y el oyente, y decide por tipo de
## reproductor. Con AudioStreamPlayer3D (backend godot) Godot atenua y filtra por su
## cuenta; lo unico que OpenDou fija es el corte del filtro.
##
## Observacion 42: antes se escribia el corte de oclusion tal cual, y sin oclusion vale
## 20 000 Hz, lo que dejaba el shelf de distancia de Godot por encima del oido. Ahora se
## escribe el MINIMO entre el corte de oclusion y el de la instancia (5 kHz por defecto),
## asi que Godot vuelve a oscurecer con la distancia y la oclusion baja desde ahi.
func apply_spatial(instance: EventInstance, volume_db: float, pitch: float, cutoff_hz: float, listener_position: Vector3, listener_basis: Basis) -> void:
	var player := get_player()
	if player == null or not is_busy or instance == null:
		return
	var gain_db: float = linear_to_db(maxf(current_fade_gain, 0.0001))
	player.pitch_scale = clampf(pitch, 0.01, 4.0)

	if player is AudioStreamPlayer3D:
		player.volume_db = clampf(volume_db + gain_db, -80.0, 24.0)
		player.attenuation_filter_cutoff_hz = clampf(minf(cutoff_hz, instance.attenuation_filter_cutoff_hz), 20.0, 20000.0)
		if not owned_by_node:
			player.global_position = instance.current_apparent_position
	elif player is AudioStreamPlayer2D:
		player.volume_db = clampf(volume_db + gain_db, -80.0, 24.0)
		if not owned_by_node:
			player.global_position = Vector2(instance.current_apparent_position.x, instance.current_apparent_position.y)
	else:
		# Reproductor estereo plano: sin stream nativo (Task 9) suena centrado y sin
		# atenuacion. La Task 9 anade la rama del OpenDouSpatialStream aqui.
		player.volume_db = clampf(volume_db + gain_db, -80.0, 24.0)
```

En `audio_event_manager.gd`: junto a `active_listener_position`, `var active_listener_basis: Basis = Basis.IDENTITY`; en `_update_listener()` tras `active_listener_position = listener_resolver.position`: `active_listener_basis = listener_resolver.basis`. En `_apply_voices()`, sustituir la llamada `ch.apply(...)`:

```gdscript
		if instance.has_spatial_position:
			ch.apply_spatial(instance, volume_db, instance.calculated_pitch_scale, cutoff, active_listener_position, active_listener_basis)
		else:
			ch.apply(volume_db, instance.calculated_pitch_scale, cutoff, instance.current_apparent_position)
```

- [ ] **Step 4: Verde, fugas y commit**

Run: `./run_tests.sh`. Si las fugas suben por el WAV nuevo, medir aislado (comentar el `absorb` y comparar) y anotar en `tests/leak_budget.txt` con la misma forma que las entradas anteriores.

```bash
git add addons/opendou/runtime/physical_voice_channel.gd addons/opendou/runtime/audio_event_manager.gd tests/test_backend_parity.gd tests/test_backend_parity.gd.uid tests/test_all.gd tests/leak_budget.txt
git commit -m "Fase 7B: el canal recibe al oyente; obs 42: Godot vuelve a oscurecer con la distancia"
```

---

### Task 6: El stream nativo gana ganancia, LPF de oclusión, shelf por distancia y modo altavoces

**Files:**
- Create: `native/src/dsp.h`
- Modify: `native/src/spatial_stream.h`, `native/src/spatial_stream.cpp`
- Rename: `tests/test_binaural_spike.gd` → `tests/test_binaural.gd` (`class_name TestBinaural`), actualizar `tests/test_all.gd` y el `preload` de `tests/test_backend_parity.gd`
- Test: aserciones nuevas en `tests/test_binaural.gd`

**Interfaces:**
- Produces en `OpenDouSpatialStream` (propiedades con setter/getter, atómicas): `distance_gain: float` (lineal, [0, 2], 1.0), `cutoff_hz: float` ([20, 20000], 20000), `shelf_db: float` ([−80, 0], 0), `shelf_cutoff_hz: float` ([100, 20000], 5000), `output_mode: int` (0 = `OUTPUT_HEADPHONES`, 1 = `OUTPUT_SPEAKERS`; constantes enlazadas con `BIND_ENUM_CONSTANT`).
- Produces en `dsp.h` (namespace `opendou::dsp`): `struct Biquad { float b0,b1,b2,a1,a2, z1=0, z2=0; void set_lowpass(float fs, float fc, float q); void set_highshelf(float fs, float fc, float gain_db); float process(float x); void reset(); }`, `struct FractionalDelay { void init(int max_samples); void set_target(float samples); float process(float x); void reset(); }` (la Task 7 la usa), `inline float woodworth_itd_seconds(float dir_x, float dir_y, float dir_z)` (Task 7).
- Orden del bloque: entrada mono → `distance_gain` → LPF (`cutoff_hz`) → shelf → HRTF o paneo → anillo.

- [ ] **Step 1: Renombrar el test y añadir las aserciones (rojo)**

```bash
git mv tests/test_binaural_spike.gd tests/test_binaural.gd
git mv tests/test_binaural_spike.gd.uid tests/test_binaural.gd.uid
sed -i '' 's/class_name TestBinauralSpike/class_name TestBinaural/' tests/test_binaural.gd
sed -i '' 's#test_binaural_spike.gd#test_binaural.gd#; s/TestBinauralSpikeClass/TestBinauralClass/g' tests/test_all.gd tests/test_backend_parity.gd
```

En `tests/test_binaural.gd`, la cabecera pasa de «Spike 7A» a «Suite binaural de la Fase 7B». Cambiar `OpenDouAssertClass.new("binaural_spike")` por `"binaural"` y el mensaje de omisión a `suite binaural omitida`. Añadir tras el bloque «control (HRTF apagado)» y antes de `player.stop()`:

```gdscript
	# ---- LPF de oclusion: la banda alta cae con el corte a 500 Hz.
	stream.spatialize = true
	stream.spatial_blend = 1.0
	stream.direction = Vector3(0, 0, -1)
	stream.cutoff_hz = 20000.0
	var open_cap := await _capture(tree, probe)
	stream.cutoff_hz = 500.0
	var closed_cap := await _capture(tree, probe)
	stream.cutoff_hz = 20000.0
	var open_high: float = _band_energy_stereo(open_cap, mix_rate, 5000.0, 10000.0)
	var closed_high: float = _band_energy_stereo(closed_cap, mix_rate, 5000.0, 10000.0)
	var lpf_drop_db: float = 10.0 * log(maxf(closed_high, 1e-12) / maxf(open_high, 1e-12)) / log(10.0)
	print("[OpenDou] LPF de oclusion: banda 5-10 kHz cae %.1f dB con corte en 500 Hz" % lpf_drop_db)
	a.lt(lpf_drop_db, -20.0, "con cutoff_hz = 500 la banda 5-10 kHz cae mas de 20 dB")

	# ---- Shelf por distancia: -12 dB por encima de 5 kHz, y a 0 dB no hace nada.
	stream.shelf_cutoff_hz = 5000.0
	stream.shelf_db = -12.0
	var shelved := await _capture(tree, probe)
	stream.shelf_db = 0.0
	var flat := await _capture(tree, probe)
	var shelf_drop_db: float = 10.0 * log(maxf(_band_energy_stereo(shelved, mix_rate, 8000.0, 14000.0), 1e-12) / maxf(_band_energy_stereo(flat, mix_rate, 8000.0, 14000.0), 1e-12)) / log(10.0)
	var shelf_low_db: float = 10.0 * log(maxf(_band_energy_stereo(shelved, mix_rate, 500.0, 2000.0), 1e-12) / maxf(_band_energy_stereo(flat, mix_rate, 500.0, 2000.0), 1e-12)) / log(10.0)
	print("[OpenDou] shelf -12 dB @5 kHz: 8-14 kHz cae %.1f dB, 0.5-2 kHz cae %.1f dB" % [shelf_drop_db, shelf_low_db])
	a.lt(shelf_drop_db, -8.0, "el shelf de -12 dB baja la banda alta al menos 8 dB")
	a.gt(shelf_low_db, -2.0, "y deja la banda media casi intacta")

	# ---- Ganancia por distancia: 0.5 lineal son -6 dB en el RMS.
	stream.distance_gain = 1.0
	var full := await _capture(tree, probe)
	stream.distance_gain = 0.5
	var half := await _capture(tree, probe)
	stream.distance_gain = 1.0
	var gain_drop_db: float = _rms_db(half) - _rms_db(full)
	a.approx(gain_drop_db, -6.02, "distance_gain 0.5 baja el nivel 6 dB", 0.6)

	# ---- Altavoces: paneo de potencia constante. ILD si, ITD no, delante = detras.
	stream.output_mode = 1   # OUTPUT_SPEAKERS
	stream.direction = Vector3(1, 0, 0)
	var spk_right := await _capture(tree, probe)
	a.gt(_ild_db(spk_right.left, spk_right.right), 6.0, "altavoces: a la derecha, ILD > 6 dB")
	a.ok(absf(_itd_lag(spk_right.left, spk_right.right)) <= 2, "altavoces: sin ITD")
	stream.direction = Vector3(0, 0, -1)
	var spk_front := await _capture(tree, probe)
	stream.direction = Vector3(0, 0, 1)
	var spk_back := await _capture(tree, probe)
	var spk_fb_pct: float = 100.0 * absf(_pinna_band_ratio(spk_front, mix_rate) - _pinna_band_ratio(spk_back, mix_rate)) / maxf(_pinna_band_ratio(spk_front, mix_rate), 1e-9)
	a.lt(spk_fb_pct, 5.0, "altavoces: delante y detras suenan igual (sin HRTF)")
	a.lt(absf(_ild_db(spk_front.left, spk_front.right)), 1.0, "altavoces: de frente, centrado")
	stream.output_mode = 0
```

Y los dos ayudantes al final del archivo:

```gdscript
## Energia de una banda sobre la suma L+R de toda la captura, en bloques de PERIOD.
static func _band_energy_stereo(cap: Dictionary, mix_rate: float, f_lo: float, f_hi: float) -> float:
	var l: PackedFloat32Array = cap["left"]
	var r: PackedFloat32Array = cap["right"]
	var n: int = mini(l.size(), r.size())
	var total: float = 0.0
	var offset: int = 0
	while offset + PERIOD <= n:
		var mono := PackedFloat32Array()
		for i in range(offset, offset + PERIOD):
			mono.append(l[i] + r[i])
		total += _band_energy(mono, mix_rate, f_lo, f_hi)
		offset += PERIOD
	return total

## RMS en dB de los dos canales juntos.
static func _rms_db(cap: Dictionary) -> float:
	var l: PackedFloat32Array = cap["left"]
	var r: PackedFloat32Array = cap["right"]
	var n: int = mini(l.size(), r.size())
	var acc: float = 0.0
	for i in range(n):
		acc += 0.5 * (l[i] * l[i] + r[i] * r[i])
	return linear_to_db(sqrt(acc / maxf(float(n), 1.0)) + 1e-9)
```

Run: `./run_tests.sh` → FALLO con `SCRIPT ERROR` (propiedad `cutoff_hz` inexistente en el stream).

- [ ] **Step 2: `native/src/dsp.h`**

```cpp
// DSP de la extension: biquads RBJ, linea de retardo fraccionaria y el modelo de cabeza
// esferica de Woodworth. Sin dependencias de Godot ni de Steam Audio: se puede leer y
// probar solo.
#pragma once

#include <algorithm>
#include <cmath>
#include <vector>

namespace opendou::dsp {

constexpr float kPi = 3.14159265358979323846f;

// Biquad en forma directa II transpuesta, coeficientes del "Audio EQ Cookbook" de RBJ.
struct Biquad {
	float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f, a1 = 0.0f, a2 = 0.0f;
	float z1 = 0.0f, z2 = 0.0f;

	void reset() { z1 = z2 = 0.0f; }

	void set_identity() {
		b0 = 1.0f; b1 = b2 = a1 = a2 = 0.0f;
	}

	// Paso-bajo de 2.o orden. q = 0.7071 es Butterworth.
	void set_lowpass(float fs, float fc, float q) {
		fc = std::clamp(fc, 10.0f, fs * 0.45f);
		const float w0 = 2.0f * kPi * fc / fs;
		const float cw = std::cos(w0), sw = std::sin(w0);
		const float alpha = sw / (2.0f * q);
		const float a0 = 1.0f + alpha;
		b0 = ((1.0f - cw) * 0.5f) / a0;
		b1 = (1.0f - cw) / a0;
		b2 = b0;
		a1 = (-2.0f * cw) / a0;
		a2 = (1.0f - alpha) / a0;
	}

	// High-shelf: ganancia gain_db por encima de fc, 0 dB por debajo. Es el filtro que
	// Godot aplica por distancia (set_playback_highshelf_params).
	void set_highshelf(float fs, float fc, float gain_db) {
		fc = std::clamp(fc, 10.0f, fs * 0.45f);
		const float A = std::pow(10.0f, gain_db / 40.0f);
		const float w0 = 2.0f * kPi * fc / fs;
		const float cw = std::cos(w0), sw = std::sin(w0);
		const float alpha = sw / 2.0f * std::sqrt(2.0f);   // S = 1
		const float sqA2a = 2.0f * std::sqrt(A) * alpha;
		const float a0 = (A + 1.0f) - (A - 1.0f) * cw + sqA2a;
		b0 = (A * ((A + 1.0f) + (A - 1.0f) * cw + sqA2a)) / a0;
		b1 = (-2.0f * A * ((A - 1.0f) + (A + 1.0f) * cw)) / a0;
		b2 = (A * ((A + 1.0f) + (A - 1.0f) * cw - sqA2a)) / a0;
		a1 = (2.0f * ((A - 1.0f) - (A + 1.0f) * cw)) / a0;
		a2 = ((A + 1.0f) - (A - 1.0f) * cw - sqA2a) / a0;
	}

	inline float process(float x) {
		const float y = b0 * x + z1;
		z1 = b1 * x - a1 * y + z2;
		z2 = b2 * x - a2 * y;
		return y;
	}
};

// Linea de retardo fraccionaria con interpolacion lineal. El retardo objetivo se fija por
// bloque y el actual se acerca en rampa muestra a muestra: girar la cabeza no hace clic.
struct FractionalDelay {
	std::vector<float> buf;
	size_t write = 0;
	float current = 0.0f;
	float target = 0.0f;
	float step = 0.0f;

	void init(int max_samples) {
		buf.assign(static_cast<size_t>(std::max(max_samples, 4)) + 4, 0.0f);
		reset();
	}
	void reset() {
		std::fill(buf.begin(), buf.end(), 0.0f);
		write = 0;
		current = target = step = 0.0f;
	}
	// Retardo en muestras a alcanzar al final de un bloque de block_samples.
	void set_target(float samples, int block_samples) {
		const float max_delay = static_cast<float>(buf.size()) - 3.0f;
		target = std::clamp(samples, 0.0f, max_delay);
		step = (target - current) / static_cast<float>(std::max(block_samples, 1));
	}
	inline float process(float x) {
		buf[write] = x;
		current += step;
		if ((step > 0.0f && current > target) || (step < 0.0f && current < target)) {
			current = target;
		}
		const float read_pos = static_cast<float>(write) - current;
		const size_t n = buf.size();
		float rp = read_pos;
		while (rp < 0.0f) rp += static_cast<float>(n);
		const size_t i0 = static_cast<size_t>(rp) % n;
		const size_t i1 = (i0 + 1) % n;
		const float frac = rp - std::floor(rp);
		// Lectura hacia atras: la muestra "siguiente" en el tiempo es la anterior en indice.
		const float y = buf[i1] * (1.0f - frac) + buf[i0] * frac;
		write = (write + 1) % n;
		return y;
	}
};

// Woodworth: ITD de una cabeza esferica de radio r para una direccion unitaria en el
// espacio del oyente (+X derecha, +Y arriba, -Z delante). Devuelve segundos, siempre >= 0;
// el signo (que oido se retrasa) lo decide dir_x.
inline float woodworth_itd_seconds(float dir_x, float dir_y, float dir_z) {
	constexpr float r = 0.0875f;
	constexpr float c = 343.0f;
	float theta = std::atan2(dir_x, -dir_z);        // azimut en (-pi, pi]
	theta = std::fabs(theta);
	if (theta > kPi * 0.5f) {
		theta = kPi - theta;                           // detras se refleja a su espejo delantero
	}
	const float phi = std::asin(std::clamp(dir_y, -1.0f, 1.0f));
	return (r / c) * (theta + std::sin(theta)) * std::cos(phi);
}

// Paneo estereo de potencia constante a partir de dir_x en [-1, 1].
inline void constant_power_pan(float dir_x, float &gain_l, float &gain_r) {
	const float x = std::clamp(dir_x, -1.0f, 1.0f);
	const float angle = (x + 1.0f) * kPi * 0.25f;   // 0 = todo izquierda, pi/2 = todo derecha
	gain_l = std::cos(angle);
	gain_r = std::sin(angle);
}

} // namespace opendou::dsp
```

- [ ] **Step 3: Propiedades y cadena en `spatial_stream.h/.cpp`**

En la clase `OpenDouSpatialStream` (cabecera), tras `set_spatialize/is_spatialize`:

```cpp
	enum OutputMode { OUTPUT_HEADPHONES = 0, OUTPUT_SPEAKERS = 1 };

	void set_distance_gain(float p_gain);   float get_distance_gain() const;
	void set_cutoff_hz(float p_hz);         float get_cutoff_hz() const;
	void set_shelf_db(float p_db);          float get_shelf_db() const;
	void set_shelf_cutoff_hz(float p_hz);   float get_shelf_cutoff_hz() const;
	void set_output_mode(int p_mode);       int get_output_mode() const;
```

y en los miembros privados:

```cpp
	std::atomic<float> distance_gain_{ 1.0f };
	std::atomic<float> cutoff_hz_{ 20000.0f };
	std::atomic<float> shelf_db_{ 0.0f };
	std::atomic<float> shelf_cutoff_hz_{ 5000.0f };
	std::atomic<int> output_mode_{ 0 };
```

Después de la clase, fuera del namespace: `VARIANT_ENUM_CAST(opendou::OpenDouSpatialStream::OutputMode);` (requiere `#include <godot_cpp/core/binder_common.hpp>`).

En `OpenDouSpatialStreamPlayback` (cabecera), `#include "dsp.h"` y miembros privados:

```cpp
	dsp::Biquad lpf_;
	dsp::Biquad shelf_;
	float lpf_applied_hz_ = -1.0f;
	float shelf_applied_db_ = 1.0f;      // imposible a proposito: fuerza el primer calculo
	float shelf_applied_hz_ = -1.0f;
	std::vector<float> mono_;            // bloque mono ya filtrado y con ganancia
```

En `_bind_methods()` del stream, añadir:

```cpp
	ClassDB::bind_method(D_METHOD("set_distance_gain", "gain"), &OpenDouSpatialStream::set_distance_gain);
	ClassDB::bind_method(D_METHOD("get_distance_gain"), &OpenDouSpatialStream::get_distance_gain);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "distance_gain", PROPERTY_HINT_RANGE, "0,2,0.001"), "set_distance_gain", "get_distance_gain");
	ClassDB::bind_method(D_METHOD("set_cutoff_hz", "hz"), &OpenDouSpatialStream::set_cutoff_hz);
	ClassDB::bind_method(D_METHOD("get_cutoff_hz"), &OpenDouSpatialStream::get_cutoff_hz);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "cutoff_hz", PROPERTY_HINT_RANGE, "20,20000,1"), "set_cutoff_hz", "get_cutoff_hz");
	ClassDB::bind_method(D_METHOD("set_shelf_db", "db"), &OpenDouSpatialStream::set_shelf_db);
	ClassDB::bind_method(D_METHOD("get_shelf_db"), &OpenDouSpatialStream::get_shelf_db);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shelf_db", PROPERTY_HINT_RANGE, "-80,0,0.1"), "set_shelf_db", "get_shelf_db");
	ClassDB::bind_method(D_METHOD("set_shelf_cutoff_hz", "hz"), &OpenDouSpatialStream::set_shelf_cutoff_hz);
	ClassDB::bind_method(D_METHOD("get_shelf_cutoff_hz"), &OpenDouSpatialStream::get_shelf_cutoff_hz);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shelf_cutoff_hz", PROPERTY_HINT_RANGE, "100,20000,1"), "set_shelf_cutoff_hz", "get_shelf_cutoff_hz");
	ClassDB::bind_method(D_METHOD("set_output_mode", "mode"), &OpenDouSpatialStream::set_output_mode);
	ClassDB::bind_method(D_METHOD("get_output_mode"), &OpenDouSpatialStream::get_output_mode);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "output_mode", PROPERTY_HINT_ENUM, "Headphones,Speakers"), "set_output_mode", "get_output_mode");
	BIND_ENUM_CONSTANT(OUTPUT_HEADPHONES);
	BIND_ENUM_CONSTANT(OUTPUT_SPEAKERS);
```

Setters/getters (todos con `std::clamp`):

```cpp
void OpenDouSpatialStream::set_distance_gain(float p_gain) { distance_gain_.store(std::clamp(p_gain, 0.0f, 2.0f)); }
float OpenDouSpatialStream::get_distance_gain() const { return distance_gain_.load(); }
void OpenDouSpatialStream::set_cutoff_hz(float p_hz) { cutoff_hz_.store(std::clamp(p_hz, 20.0f, 20000.0f)); }
float OpenDouSpatialStream::get_cutoff_hz() const { return cutoff_hz_.load(); }
void OpenDouSpatialStream::set_shelf_db(float p_db) { shelf_db_.store(std::clamp(p_db, -80.0f, 0.0f)); }
float OpenDouSpatialStream::get_shelf_db() const { return shelf_db_.load(); }
void OpenDouSpatialStream::set_shelf_cutoff_hz(float p_hz) { shelf_cutoff_hz_.store(std::clamp(p_hz, 100.0f, 20000.0f)); }
float OpenDouSpatialStream::get_shelf_cutoff_hz() const { return shelf_cutoff_hz_.load(); }
void OpenDouSpatialStream::set_output_mode(int p_mode) { output_mode_.store(p_mode == OUTPUT_SPEAKERS ? OUTPUT_SPEAKERS : OUTPUT_HEADPHONES); }
int OpenDouSpatialStream::get_output_mode() const { return output_mode_.load(); }
```

En `create_effect()`, tras reservar `interleaved_`: `mono_.assign(static_cast<size_t>(audio.frameSize), 0.0f); lpf_.reset(); shelf_.reset();`. En `_stop()`: `lpf_.reset(); shelf_.reset();`.

Reescribir `render_block()`:

```cpp
bool OpenDouSpatialStreamPlayback::render_block(float p_rate_scale) {
	const IPLAudioSettings &audio = SteamAudioContext::audio_settings();
	const int frame_size = audio.frameSize;
	const float fs = static_cast<float>(audio.samplingRate);
	// mix_audio devuelve un PackedVector2Array nuevo: reserva en el hilo de audio. La API de
	// GDExtension no ofrece otro camino para tirar de un stream interno. Documentado en el
	// spec (S3); medido con benchmark_block (Task 8).
	PackedVector2Array src = inner_->mix_audio(p_rate_scale, frame_size);
	const int got = static_cast<int>(src.size());
	if (got <= 0) {
		return false;
	}
	const Vector2 *s = src.ptr();

	// 1. Filtros: se recalculan solo si el parametro cambio de verdad (mas de 1 %).
	const float cutoff = stream_->cutoff_hz_.load();
	if (std::fabs(cutoff - lpf_applied_hz_) > 0.01f * std::max(cutoff, 1.0f)) {
		lpf_.set_lowpass(fs, cutoff, 0.70710678f);
		lpf_applied_hz_ = cutoff;
	}
	const float shelf_db = stream_->shelf_db_.load();
	const float shelf_hz = stream_->shelf_cutoff_hz_.load();
	if (std::fabs(shelf_db - shelf_applied_db_) > 0.05f || std::fabs(shelf_hz - shelf_applied_hz_) > 0.01f * shelf_hz) {
		if (shelf_db > -0.05f) {
			shelf_.set_identity();
		} else {
			shelf_.set_highshelf(fs, shelf_hz, shelf_db);
		}
		shelf_applied_db_ = shelf_db;
		shelf_applied_hz_ = shelf_hz;
	}
	const bool lpf_active = cutoff < 19000.0f;

	// 2. Mono + ganancia + filtros.
	const float gain = stream_->distance_gain_.load();
	float *mono = in_buffer_.data[0];
	for (int i = 0; i < frame_size; i++) {
		float x = (i < got) ? 0.5f * (s[i].x + s[i].y) * gain : 0.0f;
		if (lpf_active) {
			x = lpf_.process(x);
		}
		x = shelf_.process(x);
		mono[i] = x;
	}

	const float dx = stream_->dir_x_.load(), dy = stream_->dir_y_.load(), dz = stream_->dir_z_.load();

	// 3a. Altavoces: paneo de potencia constante, sin HRTF ni ITD.
	if (stream_->output_mode_.load() == OpenDouSpatialStream::OUTPUT_SPEAKERS) {
		float gl, gr;
		dsp::constant_power_pan(dx, gl, gr);
		for (int i = 0; i < frame_size; i++) {
			interleaved_[2 * i] = mono[i] * gl;
			interleaved_[2 * i + 1] = mono[i] * gr;
		}
	} else {
		// 3b. Audifonos: HRTF de Steam Audio.
		IPLBinauralEffectParams params = {};
		params.direction = IPLVector3{ dx, dy, dz };
		params.interpolation = IPL_HRTFINTERPOLATION_BILINEAR;
		params.spatialBlend = stream_->spatial_blend_.load();
		params.hrtf = SteamAudioContext::hrtf();
		params.peakDelays = peak_delays_;
		iplBinauralEffectApply(effect_, &params, &in_buffer_, &out_buffer_);
		stream_->peak_left_.store(peak_delays_[0]);
		stream_->peak_right_.store(peak_delays_[1]);
		iplAudioBufferInterleave(SteamAudioContext::context(), &out_buffer_, interleaved_.data());
	}

	// 4. Al anillo.
	const size_t cap = ring_.size();
	size_t write = (ring_read_ + ring_available_) % cap;
	for (int i = 0; i < frame_size; i++) {
		ring_[write] = AudioFrame{ interleaved_[2 * i], interleaved_[2 * i + 1] };
		write = (write + 1) % cap;
	}
	ring_available_ += static_cast<size_t>(frame_size);
	return true;
}
```

Nota: el bloque de altavoces sigue pasando por el anillo para que la latencia sea la misma en ambos modos y el conmutador en vivo no salte.

- [ ] **Step 4: Compilar, verde y commit**

Run:
```bash
cmake -S native -B native/build/ext -DCMAKE_BUILD_TYPE=Release && cmake --build native/build/ext --parallel && ./run_tests.sh
```
Expected: compila sin avisos nuevos; `STATUS: PASSED`; las líneas `[OpenDou] LPF de oclusion`, `shelf` y las de altavoces impresas con valores dentro de los umbrales.

```bash
git add native/src/dsp.h native/src/spatial_stream.h native/src/spatial_stream.cpp tests/test_binaural.gd tests/test_binaural.gd.uid tests/test_all.gd tests/test_backend_parity.gd
git commit -m "Fase 7B: el stream nativo gana ganancia, LPF de oclusion, shelf por distancia y modo altavoces"
```

---

### Task 7: ITD por cabeza esférica en la salida

**Files:**
- Modify: `native/src/spatial_stream.h`, `native/src/spatial_stream.cpp`
- Test: `tests/test_binaural.gd` (voltear las aserciones de ITD del spike)

**Interfaces:**
- Consumes: `dsp::FractionalDelay`, `dsp::woodworth_itd_seconds` (Task 6).
- Produces: la salida binaural con `output_mode == OUTPUT_HEADPHONES` lleva un retardo en el oído lejano de `max(0, ITD_esfera − residuo)`, con `residuo = |peakDelay_lejano − peakDelay_cercano|` del bloque anterior. Con `spatial_blend == 0` el retardo es 0. Nuevo método de solo lectura para la suite: `get_last_applied_itd_ms() -> float`.

- [ ] **Step 1: Voltear las aserciones del spike (rojo)**

En `tests/test_binaural.gd`, el bloque «DERECHA» pasa a:

```gdscript
	# La Fase 7B aplica el ITD que Steam Audio no renderiza: Woodworth menos el residuo que
	# el dataset ya trae. A 90 grados: 0.656 ms - ~0.136 ms = ~0.52 ms = ~23 muestras.
	var expected_lo: int = int(0.45e-3 * mix_rate)
	var expected_hi: int = int(0.75e-3 * mix_rate)
	a.ok(lag_right >= expected_lo and lag_right <= expected_hi,
		"ITD: con la fuente a la derecha, el oido izquierdo va %d-%d muestras por detras (medido %d)" % [expected_lo, expected_hi, lag_right])
	a.gt(pd.x, pd.y, "y Steam Audio sigue reportando el pico izquierdo mas tarde (residuo)")
	a.approx(stream.get_last_applied_itd_ms(), 1000.0 * lag_right / mix_rate, "el retardo aplicado coincide con el medido", 0.08)
	a.gt(ild_right, 3.0, "ILD: con la fuente a la derecha, el oido derecho recibe al menos 3 dB mas")
```

Bloque «IZQUIERDA»:

```gdscript
	a.ok(lag_left <= -expected_lo and lag_left >= -expected_hi, "ITD: a la izquierda el signo se invierte (medido %d)" % lag_left)
	a.lt(ild_left, -3.0, "ILD: a la izquierda el oido izquierdo recibe al menos 3 dB mas")
```

El «de frente no hay ITD» se conserva. Añadir tras el bloque de altavoces (que ya afirma `lag == 0` en ese modo):

```gdscript
	# Control del ITD: con la mezcla a 0 no hay retardo aunque la fuente este a la derecha.
	stream.output_mode = 0
	stream.direction = Vector3(1, 0, 0)
	stream.spatial_blend = 0.0
	var blend0_right := await _capture(tree, probe)
	a.ok(absf(_itd_lag(blend0_right.left, blend0_right.right)) <= 2, "spatial_blend = 0 tampoco produce ITD")
	stream.spatial_blend = 1.0
```

Actualizar el comentario de cabecera del test: «ITD: una fuente a la derecha llega antes al oido derecho; lo aplica OpenDou con Woodworth porque la API C de Steam Audio no lo hace (spec 7B, S1)». Run: `./run_tests.sh` → las tres aserciones de ITD fallan con lag 0.

- [ ] **Step 2: Línea de retardo por oído en el playback**

Cabecera, miembros privados del playback:

```cpp
	dsp::FractionalDelay delay_l_;
	dsp::FractionalDelay delay_r_;
	float last_itd_seconds_ = 0.0f;
```

Stream: `std::atomic<float> applied_itd_{ 0.0f };`, método `float get_last_applied_itd_ms() const { return applied_itd_.load() * 1000.0f; }` enlazado en `_bind_methods()` con `ClassDB::bind_method(D_METHOD("get_last_applied_itd_ms"), &OpenDouSpatialStream::get_last_applied_itd_ms);`.

En `create_effect()`: `const int max_delay = static_cast<int>(0.002f * audio.samplingRate) + 2; delay_l_.init(max_delay); delay_r_.init(max_delay);`. En `_stop()`: `delay_l_.reset(); delay_r_.reset();`.

En `render_block()`, dentro de la rama de audífonos, después de `iplAudioBufferInterleave(...)`:

```cpp
		// ITD esferico. peak_delays_ trae los picos de ESTE bloque; el residuo que el dataset
		// ya aporta se resta para no retrasar dos veces. Con blend 0 no hay espacializacion y
		// tampoco retardo.
		const float blend = params.spatialBlend;
		const float sphere = dsp::woodworth_itd_seconds(dx, dy, dz) * blend;
		const float residual = std::fabs(peak_delays_[0] - peak_delays_[1]);
		const float itd = std::max(0.0f, sphere - residual);
		const float itd_samples = itd * fs;
		// dx > 0: fuente a la derecha, se retrasa el oido IZQUIERDO.
		if (dx >= 0.0f) {
			delay_l_.set_target(itd_samples, frame_size);
			delay_r_.set_target(0.0f, frame_size);
		} else {
			delay_l_.set_target(0.0f, frame_size);
			delay_r_.set_target(itd_samples, frame_size);
		}
		for (int i = 0; i < frame_size; i++) {
			interleaved_[2 * i] = delay_l_.process(interleaved_[2 * i]);
			interleaved_[2 * i + 1] = delay_r_.process(interleaved_[2 * i + 1]);
		}
		last_itd_seconds_ = itd;
		stream_->applied_itd_.store(itd);
```

- [ ] **Step 3: Compilar, verde y commit**

```bash
cmake --build native/build/ext --parallel && ./run_tests.sh
```
Expected: `[OpenDou] derecha: lag medido=2x muestras ...` dentro de [19, 33] a 44.1 kHz; `STATUS: PASSED`. Si el lag cae fuera por poco, revisar primero el signo de la lectura en `FractionalDelay::process` (la interpolación lee `buf[i1]·(1−frac) + buf[i0]·frac` porque el índice crece hacia el pasado) antes de tocar los umbrales.

```bash
git add native/src/spatial_stream.h native/src/spatial_stream.cpp tests/test_binaural.gd
git commit -m "Fase 7B: ITD por cabeza esferica en la salida binaural, restando el residuo del HRTF"
```

---

### Task 8: HRTF conmutable en vivo, tamaño de bloque configurable y `benchmark_block`

**Files:**
- Modify: `native/src/steam_audio_context.h`, `native/src/steam_audio_context.cpp`
- Modify: `native/src/spatial_stream.h`, `native/src/spatial_stream.cpp`
- Modify: `addons/opendou/runtime/spatial/spatial_backend.gd` (ajuste `frame_size`)
- Test: `tests/test_binaural.gd` (bloque HRTF en vivo + frame_size), `tests/test_spatial_backend.gd` (ajuste)

**Interfaces:**
- Produces estáticas en `OpenDouSpatialStream`: `set_hrtf_default() -> bool`, `set_hrtf_sofa(path: String) -> bool`, `get_hrtf_name() -> String`, `get_hrtf_generation() -> int`, `benchmark_block(voices: int) -> float` (µs por voz y bloque), `configure(frame_size: int) -> bool` (solo antes de crear el contexto; después devuelve `false` y avisa).
- Produces en `SteamAudioContext`: `struct HrtfSlot { IPLHRTF hrtf; std::atomic<int> refs; }`, `static IPLHRTF acquire_hrtf(int &out_generation)` / `static void release_hrtf(int generation)`, `static int generation()`, `static bool set_hrtf_default()`, `static bool set_hrtf_sofa(const std::string &path)`, `static std::string hrtf_name()`, `static bool configure_frame_size(int)`.
- Produces en `OpenDouSpatialBackend`: `const FRAME_SIZE_SETTING = "opendou/spatial/frame_size"`, `static func read_frame_size() -> int` (256/512/1024; otro valor → 512 con aviso). El manager llama `OpenDouSpatialStream.configure(read_frame_size())` en `_init` **antes** de `native_available()`.

- [ ] **Step 1: Tests (rojo)**

En `tests/test_spatial_backend.gd`, antes del bloque del manager:

```gdscript
	a.eq(BackendClass.read_frame_size(), 512, "frame_size vale 512 por defecto")
	ProjectSettings.set_setting(BackendClass.FRAME_SIZE_SETTING, 333)
	a.eq(BackendClass.read_frame_size(), 512, "un frame_size invalido vuelve a 512")
	ProjectSettings.set_setting(BackendClass.FRAME_SIZE_SETTING, 256)
	a.eq(BackendClass.read_frame_size(), 256, "256 es valido")
	ProjectSettings.set_setting(BackendClass.FRAME_SIZE_SETTING, 512)
```

En `tests/test_binaural.gd`, tras el control de `spatial_blend = 0` de la Task 7 y antes de `player.stop()`:

```gdscript
	# ---- HRTF conmutable en vivo: 16 voces sonando, se cambia y se vuelve. Sin cortes.
	var extra: Array[AudioStreamPlayer] = []
	for i in range(15):
		var s2 = ClassDB.instantiate("OpenDouSpatialStream")
		s2.source = noise
		s2.direction = Vector3(cos(i * 0.4), 0, sin(i * 0.4))
		var p2 := AudioStreamPlayer.new()
		p2.stream = s2
		p2.bus = String(BUS)
		p2.volume_db = -18.0
		tree.root.add_child(p2)
		p2.play()
		extra.append(p2)
	var gen_before: int = int(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_generation"))
	a.eq(str(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_name")), "default", "el HRTF activo es el incorporado")
	# Un SOFA inexistente NO cambia nada y devuelve false.
	a.eq(bool(ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_sofa", "user://no_existe.sofa")), false, "un SOFA inexistente se rechaza")
	a.eq(int(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_generation")), gen_before, "y la generacion no cambia")
	# Volver al incorporado (aunque ya lo sea) crea una generacion nueva: es el camino que
	# recorre un cambio de verdad, y hay que verlo funcionar con voces sonando.
	var silent_blocks: int = 0
	var checked_blocks: int = 0
	for round_i in range(3):
		a.ok(bool(ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_default")), "set_hrtf_default devuelve true")
		for i in range(6):
			await tree.process_frame
			var avail: int = probe._capture.get_frames_available()
			if avail <= 0:
				continue
			var peak: float = 0.0
			for v in probe._capture.get_buffer(avail):
				peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
			checked_blocks += 1
			if peak < 0.001:
				silent_blocks += 1
	a.gt(int(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_generation")), gen_before + 2, "cada cambio de HRTF sube la generacion")
	a.gt(float(checked_blocks), 8.0, "se inspeccionaron bloques durante el cambio")
	a.eq(silent_blocks, 0, "ningun bloque quedo en silencio al cambiar el HRTF con 16 voces sonando")
	for p2 in extra:
		p2.stop()
		tree.root.remove_child(p2)
		p2.free()

	# ---- benchmark_block: existe, devuelve microsegundos por voz, y no es cero.
	var us_per_voice: float = float(ClassDB.class_call_static("OpenDouSpatialStream", "benchmark_block", 64))
	print("[OpenDou] DSP nativo: %.1f us por voz y bloque de %d (64 voces)" % [us_per_voice, frame_size])
	a.gt(us_per_voice, 0.1, "benchmark_block mide algo")
```

Run: `./run_tests.sh` → `SCRIPT ERROR` por métodos estáticos inexistentes y fallo de `read_frame_size`.

- [ ] **Step 2: `spatial_backend.gd`**

```gdscript
const FRAME_SIZE_SETTING: String = "opendou/spatial/frame_size"
const FRAME_SIZES: Array[int] = [256, 512, 1024]

static func ensure_frame_size_setting() -> void:
	if not ProjectSettings.has_setting(FRAME_SIZE_SETTING):
		ProjectSettings.set_setting(FRAME_SIZE_SETTING, 512)
	ProjectSettings.set_initial_value(FRAME_SIZE_SETTING, 512)
	ProjectSettings.add_property_info({
		"name": FRAME_SIZE_SETTING, "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "256:256,512:512,1024:1024",
	})

## Tamano de bloque del DSP nativo. Se lee UNA vez al crear el contexto: cambiarlo exige
## reiniciar. 512 = 11.6 ms a 44.1 kHz (medido en el spike); 256 baja la latencia y sube la CPU.
static func read_frame_size() -> int:
	ensure_frame_size_setting()
	var v: int = int(ProjectSettings.get_setting(FRAME_SIZE_SETTING, 512))
	if not FRAME_SIZES.has(v):
		push_warning("[OpenDou] opendou/spatial/frame_size = %d no es 256, 512 ni 1024: se usa 512" % v)
		return 512
	return v
```

Y `native_available()` llama antes `ClassDB.class_call_static("OpenDouSpatialStream", "configure", read_frame_size())` si el método existe.

- [ ] **Step 3: Contexto con generación de HRTF**

`steam_audio_context.h`:

```cpp
#pragma once
#include <phonon.h>
#include <atomic>
#include <mutex>
#include <string>

namespace opendou {

class SteamAudioContext {
public:
	static bool configure_frame_size(int frame_size);   // false si el contexto ya existe
	static bool ensure(int sampling_rate);
	static void shutdown();
	static bool is_ready() { return context_ != nullptr && current_.load() != nullptr; }
	static IPLContext context() { return context_; }
	static const IPLAudioSettings &audio_settings() { return audio_; }

	// HRTF con generacion. El hilo de audio toma el HRTF actual con acquire_hrtf() al
	// empezar cada bloque y lo suelta con release_hrtf() al terminar; si mientras tanto el
	// hilo principal cambio el HRTF, el viejo se libera cuando su cuenta llega a cero.
	struct HrtfSlot {
		IPLHRTF hrtf = nullptr;
		std::atomic<int> refs{ 0 };
		std::atomic<bool> retired{ false };
		int generation = 0;
	};
	static HrtfSlot *acquire_hrtf();
	static void release_hrtf(HrtfSlot *slot);
	static int generation() { return generation_.load(); }
	static bool set_hrtf_default();
	static bool set_hrtf_sofa(const std::string &path);
	static std::string hrtf_name();

private:
	static bool install_hrtf(IPLHRTFSettings &settings, const std::string &name);
	static void collect_retired();

	static IPLContext context_;
	static IPLAudioSettings audio_;
	static int requested_frame_size_;
	static std::atomic<HrtfSlot *> current_;
	static HrtfSlot *retired_[8];
	static std::mutex swap_mutex_;
	static std::atomic<int> generation_;
	static std::string name_;
};

} // namespace opendou
```

`steam_audio_context.cpp` (partes nuevas; `steam_audio_log` se conserva):

```cpp
IPLContext SteamAudioContext::context_ = nullptr;
IPLAudioSettings SteamAudioContext::audio_ = { 44100, 512 };
int SteamAudioContext::requested_frame_size_ = 512;
std::atomic<SteamAudioContext::HrtfSlot *> SteamAudioContext::current_{ nullptr };
SteamAudioContext::HrtfSlot *SteamAudioContext::retired_[8] = {};
std::mutex SteamAudioContext::swap_mutex_;
std::atomic<int> SteamAudioContext::generation_{ 0 };
std::string SteamAudioContext::name_ = "default";

bool SteamAudioContext::configure_frame_size(int frame_size) {
	if (context_ != nullptr) {
		return requested_frame_size_ == frame_size;
	}
	if (frame_size != 256 && frame_size != 512 && frame_size != 1024) {
		return false;
	}
	requested_frame_size_ = frame_size;
	return true;
}

bool SteamAudioContext::ensure(int sampling_rate) {
	if (is_ready()) {
		return true;
	}
	audio_.samplingRate = sampling_rate;
	audio_.frameSize = requested_frame_size_;
	if (context_ == nullptr) {
		IPLContextSettings settings = {};
		settings.version = STEAMAUDIO_VERSION;
		settings.logCallback = steam_audio_log;
		settings.simdLevel = IPL_SIMDLEVEL_AVX2;
		if (iplContextCreate(&settings, &context_) != IPL_STATUS_SUCCESS) {
			godot::UtilityFunctions::push_error("[OpenDou/SteamAudio] no se pudo crear el contexto");
			context_ = nullptr;
			return false;
		}
	}
	return set_hrtf_default();
}

bool SteamAudioContext::install_hrtf(IPLHRTFSettings &settings, const std::string &name) {
	if (context_ == nullptr) {
		return false;
	}
	settings.volume = 1.0f;
	settings.normType = IPL_HRTFNORMTYPE_NONE;
	IPLHRTF hrtf = nullptr;
	if (iplHRTFCreate(context_, &audio_, &settings, &hrtf) != IPL_STATUS_SUCCESS || hrtf == nullptr) {
		godot::UtilityFunctions::push_error("[OpenDou/SteamAudio] no se pudo crear el HRTF: ", name.c_str());
		return false;
	}
	std::lock_guard<std::mutex> lock(swap_mutex_);
	collect_retired();
	HrtfSlot *slot = new HrtfSlot();
	slot->hrtf = hrtf;
	slot->generation = generation_.load() + 1;
	HrtfSlot *old = current_.exchange(slot);
	generation_.store(slot->generation);
	name_ = name;
	if (old != nullptr) {
		old->retired.store(true);
		bool parked = false;
		for (auto &r : retired_) {
			if (r == nullptr) { r = old; parked = true; break; }
		}
		if (!parked) {
			// Ocho cambios sin que ningun bloque los soltara: no pasa en la practica. Se
			// libera el mas antiguo tras esperar a que sus lectores terminen.
			while (retired_[0]->refs.load() > 0) {}
			iplHRTFRelease(&retired_[0]->hrtf);
			delete retired_[0];
			retired_[0] = old;
		}
	}
	return true;
}

// Libera los HRTF retirados que ya nadie lee. Se llama con swap_mutex_ tomado.
void SteamAudioContext::collect_retired() {
	for (auto &r : retired_) {
		if (r != nullptr && r->refs.load() == 0) {
			iplHRTFRelease(&r->hrtf);
			delete r;
			r = nullptr;
		}
	}
}

bool SteamAudioContext::set_hrtf_default() {
	IPLHRTFSettings s = {};
	s.type = IPL_HRTFTYPE_DEFAULT;
	return install_hrtf(s, "default");
}

bool SteamAudioContext::set_hrtf_sofa(const std::string &path) {
	IPLHRTFSettings s = {};
	s.type = IPL_HRTFTYPE_SOFA;
	s.sofaFileName = path.c_str();
	const std::string name = path.substr(path.find_last_of("/\\") + 1);
	return install_hrtf(s, name);
}

std::string SteamAudioContext::hrtf_name() { return name_; }

SteamAudioContext::HrtfSlot *SteamAudioContext::acquire_hrtf() {
	HrtfSlot *slot = current_.load();
	if (slot != nullptr) {
		slot->refs.fetch_add(1);
		// Si justo ahora lo cambiaron, este slot esta retirado pero sigue vivo: refs > 0
		// impide que collect_retired lo libere hasta que este bloque termine.
	}
	return slot;
}

void SteamAudioContext::release_hrtf(HrtfSlot *slot) {
	if (slot != nullptr) {
		slot->refs.fetch_sub(1);
	}
}

void SteamAudioContext::shutdown() {
	std::lock_guard<std::mutex> lock(swap_mutex_);
	HrtfSlot *cur = current_.exchange(nullptr);
	if (cur != nullptr) {
		iplHRTFRelease(&cur->hrtf);
		delete cur;
	}
	for (auto &r : retired_) {
		if (r != nullptr) { iplHRTFRelease(&r->hrtf); delete r; r = nullptr; }
	}
	if (context_ != nullptr) {
		iplContextRelease(&context_);
		context_ = nullptr;
	}
}
```

Los `ensure(rate, 512)` del spike pasan a `ensure(rate)`. En el playback, `create_effect()` usa `settings.hrtf = SteamAudioContext::acquire_hrtf()->hrtf` … no: el efecto se crea con el HRTF actual solo como referencia de configuración; guardar el slot no hace falta porque `iplBinauralEffectApply` recibe el HRTF en `params`. En `render_block()` la rama de audífonos pasa a:

```cpp
		SteamAudioContext::HrtfSlot *slot = SteamAudioContext::acquire_hrtf();
		params.hrtf = slot != nullptr ? slot->hrtf : nullptr;
		iplBinauralEffectApply(effect_, &params, &in_buffer_, &out_buffer_);
		SteamAudioContext::release_hrtf(slot);
```

- [ ] **Step 4: Estáticas del stream**

En `spatial_stream.h`: `static bool configure(int frame_size); static bool set_hrtf_default(); static bool set_hrtf_sofa(const godot::String &path); static godot::String get_hrtf_name(); static int get_hrtf_generation(); static float benchmark_block(int voices);`. Enlazar con `ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD(...), ...)` cada una.

```cpp
bool OpenDouSpatialStream::configure(int frame_size) { return SteamAudioContext::configure_frame_size(frame_size); }
bool OpenDouSpatialStream::set_hrtf_default() { return SteamAudioContext::set_hrtf_default(); }
bool OpenDouSpatialStream::set_hrtf_sofa(const String &path) {
	const String global = ProjectSettings::get_singleton()->globalize_path(path);
	if (!FileAccess::file_exists(global)) {
		UtilityFunctions::push_error("[OpenDou/SteamAudio] SOFA no encontrado: ", global);
		return false;
	}
	return SteamAudioContext::set_hrtf_sofa(std::string(global.utf8().get_data()));
}
String OpenDouSpatialStream::get_hrtf_name() { return String(SteamAudioContext::hrtf_name().c_str()); }
int OpenDouSpatialStream::get_hrtf_generation() { return SteamAudioContext::generation(); }

// Renderiza `voices` bloques sincronamente con la cadena completa (filtros, HRTF, ITD) y
// devuelve microsegundos por voz. Existe porque el hilo de audio no se puede cronometrar
// desde fuera en headless; es la guarda de coste del DSP (tests/dsp_budget.txt).
float OpenDouSpatialStream::benchmark_block(int voices) {
	const int rate = static_cast<int>(AudioServer::get_singleton()->get_mix_rate());
	if (voices <= 0 || !SteamAudioContext::ensure(rate)) {
		return 0.0f;
	}
	const IPLAudioSettings audio = SteamAudioContext::audio_settings();
	IPLBinauralEffectSettings settings = {};
	SteamAudioContext::HrtfSlot *slot = SteamAudioContext::acquire_hrtf();
	settings.hrtf = slot->hrtf;
	IPLBinauralEffect effect = nullptr;
	IPLAudioBuffer in = {}, out = {};
	iplBinauralEffectCreate(SteamAudioContext::context(), const_cast<IPLAudioSettings *>(&audio), &settings, &effect);
	iplAudioBufferAllocate(SteamAudioContext::context(), 1, audio.frameSize, &in);
	iplAudioBufferAllocate(SteamAudioContext::context(), 2, audio.frameSize, &out);
	dsp::Biquad lpf, shelf;
	lpf.set_lowpass(static_cast<float>(audio.samplingRate), 8000.0f, 0.7071f);
	shelf.set_highshelf(static_cast<float>(audio.samplingRate), 5000.0f, -12.0f);
	dsp::FractionalDelay dl, dr;
	dl.init(static_cast<int>(0.002f * audio.samplingRate) + 2);
	dr.init(static_cast<int>(0.002f * audio.samplingRate) + 2);
	std::vector<float> inter(static_cast<size_t>(audio.frameSize) * 2);
	float peaks[2] = { 0, 0 };
	const uint64_t t0 = Time::get_singleton()->get_ticks_usec();
	for (int v = 0; v < voices; v++) {
		for (int i = 0; i < audio.frameSize; i++) {
			in.data[0][i] = shelf.process(lpf.process(std::sin(0.01f * i * (v + 1))));
		}
		IPLBinauralEffectParams params = {};
		params.direction = IPLVector3{ 0.7f, 0.0f, -0.7f };
		params.interpolation = IPL_HRTFINTERPOLATION_BILINEAR;
		params.spatialBlend = 1.0f;
		params.hrtf = slot->hrtf;
		params.peakDelays = peaks;
		iplBinauralEffectApply(effect, &params, &in, &out);
		iplAudioBufferInterleave(SteamAudioContext::context(), &out, inter.data());
		dl.set_target(20.0f, audio.frameSize);
		for (int i = 0; i < audio.frameSize; i++) {
			inter[2 * i] = dl.process(inter[2 * i]);
			inter[2 * i + 1] = dr.process(inter[2 * i + 1]);
		}
	}
	const uint64_t t1 = Time::get_singleton()->get_ticks_usec();
	iplAudioBufferFree(SteamAudioContext::context(), &in);
	iplAudioBufferFree(SteamAudioContext::context(), &out);
	iplBinauralEffectRelease(&effect);
	SteamAudioContext::release_hrtf(slot);
	return static_cast<float>(t1 - t0) / static_cast<float>(voices);
}
```

Includes necesarios: `<godot_cpp/classes/time.hpp>`, `<godot_cpp/classes/project_settings.hpp>`, `<godot_cpp/classes/file_access.hpp>`.

- [ ] **Step 5: Compilar, verde y commit**

```bash
cmake --build native/build/ext --parallel && ./run_tests.sh
```
Expected: `STATUS: PASSED`; impresa la línea `[OpenDou] DSP nativo: N us por voz y bloque de 512`. Apuntar N: es el dato de la Task 15.

```bash
git add native/src addons/opendou/runtime/spatial/spatial_backend.gd tests/test_binaural.gd tests/test_spatial_backend.gd
git commit -m "Fase 7B: HRTF conmutable en vivo por generacion, frame_size configurable y benchmark_block"
```

---

### Task 9: Pool con `BINAURAL_3D` y el canal empujando al stream nativo

**Files:**
- Modify: `addons/opendou/runtime/native_player_pool.gd`
- Modify: `addons/opendou/runtime/voice_pool_manager.gd:20-26` (campo backend), `:224-229` (`_kind_for_instance`)
- Modify: `addons/opendou/runtime/physical_voice_channel.gd` (`apply_spatial`, rama del stream nativo)
- Modify: `addons/opendou/runtime/audio_event_manager.gd:82-95` (`voice_pool.spatial_backend = spatial_backend`)
- Test: `tests/test_native_player_pool.gd`, `tests/test_binaural.gd` (nuevo `run_pool_async`)

**Interfaces:**
- Produces en `OpenDouNativePlayerPool`: `PlayerKind.BINAURAL_3D = 3`; `acquire(BINAURAL_3D)` devuelve un `AudioStreamPlayer` cuyo `stream` es un `OpenDouSpatialStream` permanente (creado con `ClassDB.instantiate`); `release()` deja `stream.source = null` en lugar de `stream = null`; `_kind_of()` distingue `BINAURAL_3D` de `NON_SPATIAL` por el tipo del stream; `func for_each_spatial_stream(callable: Callable) -> void` recorre los streams de todos los reproductores binaurales (libres y ocupados) para los ajustes en vivo (Task 12).
- Produces en `VoicePoolManager`: `var spatial_backend: StringName = &"godot"`; `_kind_for_instance` devuelve `BINAURAL_3D` para voces con posición cuando `spatial_backend == &"steam_audio"`.
- Produces en `PhysicalVoiceChannel.play_stream`: si el reproductor lleva un `OpenDouSpatialStream`, el stream de la voz se asigna a `player.stream.source` y no a `player.stream`.
- `apply_spatial` rama estéreo plano: `stream.direction`, `stream.distance_gain`, `stream.cutoff_hz`, `stream.shelf_db`, `stream.shelf_cutoff_hz` desde `OpenDouDistanceModel`.

- [ ] **Step 1: Tests (rojo)**

En `tests/test_native_player_pool.gd`, antes de `pool.free()`:

```gdscript
	# Fase 7B: el tipo binaural existe siempre (el enum), pero solo produce reproductores
	# si la extension esta cargada. Sin ella devuelve null y lo dice, y el resto del pool
	# no se entera.
	var b1 = pool.acquire(K.BINAURAL_3D)
	if ClassDB.class_exists("OpenDouSpatialStream"):
		a.ok(b1 is AudioStreamPlayer and b1.stream != null and b1.stream.get_class() == "OpenDouSpatialStream", "acquire binaural devuelve un AudioStreamPlayer con OpenDouSpatialStream")
		var pool_stream = b1.stream
		var fake := AudioStreamWAV.new()
		b1.stream.source = fake
		pool.release(b1)
		a.eq(b1.stream, pool_stream, "al liberar, el stream nativo se conserva")
		a.eq(b1.stream.source, null, "y se suelta solo la fuente")
		a.eq(pool.busy_count(K.BINAURAL_3D), 0, "el tipo binaural lleva su propia cuenta")
		var visited: int = 0
		pool.for_each_spatial_stream(func(s): visited += 1)
		a.eq(visited, 1, "for_each_spatial_stream recorre los streams del pool")
	else:
		a.eq(b1, null, "sin extension, acquire binaural devuelve null")
		print("[OpenDou] extension nativa AUSENTE: parte binaural de native_player_pool omitida")
```

Nuevo bloque en `tests/test_binaural.gd`:

```gdscript
## Una voz posteada por el manager con backend steam_audio sale por el stream nativo y se
## lateraliza: ILD con el signo de su lado. Es la primera aserción de la cadena completa
## (manager -> canal -> stream) y no del stream aislado.
static func run_pool_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("binaural_pool")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite binaural_pool omitida")
		return a
	var ParityClass = load("res://tests/test_backend_parity.gd")
	var BackendClass = load("res://addons/opendou/runtime/spatial/spatial_backend.gd")
	var previous: String = str(ProjectSettings.get_setting(BackendClass.SETTING, "auto"))
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var manager = ParityClass.make_manager(tree, "steam_audio")
	await tree.process_frame
	a.eq(manager.spatial_backend, &"steam_audio", "el manager quedo en steam_audio")

	var noise := _periodic_noise(int(AudioServer.get_mix_rate()))
	var def = AudioEventDefClass.new(&"PoolVoice", noise)
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = ParityClass.BUS
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)

	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(10, 0, 0))
	var right := await _capture(tree, probe)
	var ch = manager.voice_pool.get_channel(inst.assigned_channel_id)
	a.ok(ch != null and ch.get_player() is AudioStreamPlayer and not (ch.get_player() is AudioStreamPlayer3D), "la voz salio por un AudioStreamPlayer estereo del pool")
	a.gt(_ild_db(right.left, right.right), 3.0, "a la derecha del oyente: ILD positivo")
	var lag_r: int = _itd_lag(right.left, right.right)
	a.gt(float(lag_r), 10.0, "y el oido izquierdo va por detras")
	inst.set_position(Vector3(-10, 0, 0))
	var left := await _capture(tree, probe)
	a.lt(_ild_db(left.left, left.right), -3.0, "a la izquierda: ILD negativo")
	# La distancia entra en el stream: a 40 m suena mas bajo que a 10 m.
	inst.set_position(Vector3(0, 0, -10))
	var near := await _capture(tree, probe)
	inst.set_position(Vector3(0, 0, -40))
	var far := await _capture(tree, probe)
	a.lt(_rms_db(far) - _rms_db(near), -9.0, "a 40 m el nivel cae al menos 9 dB (inversa: -12 dB)")

	inst.stop()
	await probe.await_silence(tree, 0.002, 30)
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous)
	return a
```

Registrar en `run_async_suite`: `acc.absorb(await TestBinauralClass.run_pool_async(tree))`. Run → rojo (`K.BINAURAL_3D` no existe).

- [ ] **Step 2: Pool**

`native_player_pool.gd`:

```gdscript
enum PlayerKind {
	NON_SPATIAL, ## AudioStreamPlayer: UI, musica, narracion
	SPATIAL_2D,  ## AudioStreamPlayer2D
	SPATIAL_3D,  ## AudioStreamPlayer3D (backend godot)
	BINAURAL_3D, ## AudioStreamPlayer estereo con OpenDouSpatialStream (backend steam_audio)
}
```

En `_init`, el bucle de tipos incluye `PlayerKind.BINAURAL_3D`. En `_instantiate`:

```gdscript
		PlayerKind.BINAURAL_3D:
			if not ClassDB.class_exists("OpenDouSpatialStream"):
				push_error("[OpenDou] se pidio un reproductor binaural sin la extension nativa cargada")
				return null
			var p := AudioStreamPlayer.new()
			# El stream nativo es PERMANENTE: por voz solo cambia su fuente. Crear uno por voz
			# seria crear y destruir efectos de Steam Audio a cada disparo.
			p.stream = ClassDB.instantiate("OpenDouSpatialStream")
			return p
```

`acquire()` devuelve `null` si `_instantiate` devolvió `null` (sin añadir hijo). `release()`:

```gdscript
	if player.has_method("stop"):
		player.stop()
	if _is_binaural(player):
		player.stream.source = null
	else:
		player.stream = null
```

Ayudantes:

```gdscript
static func _is_binaural(player: Node) -> bool:
	return player is AudioStreamPlayer and player.stream != null and player.stream.get_class() == "OpenDouSpatialStream"

func _kind_of(player: Node) -> int:
	if player is AudioStreamPlayer3D:
		return PlayerKind.SPATIAL_3D
	if player is AudioStreamPlayer2D:
		return PlayerKind.SPATIAL_2D
	if _is_binaural(player):
		return PlayerKind.BINAURAL_3D
	if player is AudioStreamPlayer:
		return PlayerKind.NON_SPATIAL
	return -1

## Recorre los streams nativos de todos los reproductores binaurales, libres y ocupados.
## Es lo que aplica en vivo la mezcla, la salida y el HRTF (ajustes del jugador).
func for_each_spatial_stream(callable: Callable) -> void:
	for p in (_free[PlayerKind.BINAURAL_3D] as Array) + (_busy[PlayerKind.BINAURAL_3D] as Array):
		if is_instance_valid(p) and p.stream != null:
			callable.call(p.stream)
```

- [ ] **Step 3: Enrutado por backend**

`voice_pool_manager.gd`, junto a `player_pool`:

```gdscript
## Backend espacial del manager. Decide que tipo de reproductor piden las voces con
## posicion: SPATIAL_3D con godot, BINAURAL_3D con steam_audio.
var spatial_backend: StringName = &"godot"
```

```gdscript
func _kind_for_instance(instance: EventInstance) -> int:
	if instance.has_spatial_position:
		if spatial_backend == &"steam_audio":
			return NativePlayerPoolClass.PlayerKind.BINAURAL_3D
		return NativePlayerPoolClass.PlayerKind.SPATIAL_3D
	return NativePlayerPoolClass.PlayerKind.NON_SPATIAL
```

En el manager, `_init`, tras `voice_pool.set_player_pool(player_pool)`: `voice_pool.spatial_backend = spatial_backend`. Y en `set_max_physical_voices()` (que crea un `VoicePoolManager` nuevo) volver a asignarlo.

- [ ] **Step 4: El canal**

En `play_stream()` sustituir `player.stream = stream` por:

```gdscript
	if player is AudioStreamPlayer and player.stream != null and player.stream.get_class() == "OpenDouSpatialStream":
		# Backend steam_audio: el stream del reproductor es el envoltorio nativo permanente.
		player.stream.source = stream
	else:
		player.stream = stream
```

En `apply_spatial()`, la rama `else` (estéreo plano) pasa a:

```gdscript
	elif player is AudioStreamPlayer and player.stream != null and player.stream.get_class() == "OpenDouSpatialStream":
		# Backend steam_audio: OpenDou calcula lo que Godot calculaba por su cuenta, con las
		# mismas formulas (OpenDouDistanceModel), y lo empuja al stream nativo.
		var s = player.stream
		var p: Vector3 = instance.current_apparent_position
		var distance: float = p.distance_to(listener_position)
		var v_total: float = volume_db + instance.emitter_volume_db
		player.volume_db = clampf(v_total + gain_db, -80.0, 24.0)
		s.direction = DistanceModelClass.listener_direction(p, listener_position, listener_basis)
		s.distance_gain = db_to_linear(DistanceModelClass.gain_db_for_stream(distance, instance.attenuation_model, instance.unit_size, v_total, instance.attenuation_max_distance))
		var mult: float = DistanceModelClass.multiplier(distance, instance.attenuation_model, instance.unit_size, v_total, DistanceModelClass.MAX_DB, instance.attenuation_max_distance)
		s.shelf_db = DistanceModelClass.shelf_db(mult, instance.attenuation_filter_db)
		s.shelf_cutoff_hz = instance.attenuation_filter_cutoff_hz
		s.cutoff_hz = clampf(cutoff_hz, 20.0, 20000.0)
	else:
		player.volume_db = clampf(volume_db + gain_db, -80.0, 24.0)
```

- [ ] **Step 5: Verde, fugas y commit**

Run: `./run_tests.sh`. Las voces binaurales del pool retienen objetos del servidor de audio igual que las 3D: si el techo sube, medir aislado y anotar en `leak_budget.txt`.

```bash
git add addons/opendou/runtime/native_player_pool.gd addons/opendou/runtime/voice_pool_manager.gd addons/opendou/runtime/physical_voice_channel.gd addons/opendou/runtime/audio_event_manager.gd tests/test_native_player_pool.gd tests/test_binaural.gd tests/test_all.gd tests/leak_budget.txt
git commit -m "Fase 7B: las voces del pool salen por el stream nativo con direccion y distancia de OpenDou"
```

---

### Task 10: Los emisores de nodo aportan posición y el origen aparente los relocaliza

**Files:**
- Modify: `addons/opendou/runtime/voice_pool_manager.gd:118-180` (`devirtualize`)
- Modify: `addons/opendou/runtime/physical_voice_channel.gd` (`position_node_ref`)
- Modify: `addons/opendou/runtime/audio_event_manager.gd` (`_apply_voices`: leer la posición del nodo)
- Modify: `addons/opendou/nodes/opendou_event_player_3d.gd:151-156` (`stop_event` no llama a `stop()` nativo si el nodo no suena)
- Test: `tests/test_binaural.gd` (`run_node_emitter_async`)

**Interfaces:**
- Produces en `PhysicalVoiceChannel`: `var position_node_ref: WeakRef = null`, `func get_position_node() -> Node3D`.
- En `devirtualize`, con `spatial_backend == &"steam_audio"` y un reproductor vinculado que es `AudioStreamPlayer3D`: se adquiere un `BINAURAL_3D` del pool, `owned_by_node = false`, `ch.position_node_ref = weakref(nodo)`, y se copia la atenuación (`instance.copy_attenuation_from_player(nodo)`) y el bus del nodo (`bus_name = StringName(nodo.bus)`). El `AudioStreamPlayer3D` del nodo no recibe stream.
- En `_apply_voices`, antes de aplicar: si `ch.get_position_node() != null`, `instance.set_position(node.global_position)`.

- [ ] **Step 1: Test (rojo)**

```gdscript
## Un OpenDouEventPlayer3D dentro de una sala, con el portal a un lado del oyente: en
## steam_audio la voz sale POR EL PORTAL (ILD con el signo del portal), que es lo que el
## spike no podia hacer. Con godot, el nodo suena el mismo y el ILD sigue al emisor: es la
## limitacion conocida, y se afirma para que quede escrita.
static func run_node_emitter_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("binaural_node_emitter")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite binaural_node_emitter omitida")
		return a
	var ParityClass = load("res://tests/test_backend_parity.gd")
	var BackendClass = load("res://addons/opendou/runtime/spatial/spatial_backend.gd")
	var AudioRoomClass = load("res://addons/opendou/runtime/spatial/audio_room.gd")
	var AudioPortalClass = load("res://addons/opendou/runtime/spatial/audio_portal.gd")
	var EmitterScene = load("res://addons/opendou/nodes/opendou_event_player_3d.gd")
	var previous: String = str(ProjectSettings.get_setting(BackendClass.SETTING, "auto"))
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)

	for backend in ["steam_audio", "godot"]:
		var manager = ParityClass.make_manager(tree, backend)
		await tree.process_frame
		# Dos salas: el oyente en Fuera (x<0), el emisor en Dentro (x>0). El unico portal
		# esta a la DERECHA del oyente (x=0, z=-6) mientras el emisor queda de FRENTE (z=-6,
		# x=+12)... no: el emisor se pone DELANTE-IZQUIERDA para que el portal y el emisor
		# esten en lados opuestos y el signo del ILD diga quien gobierna.
		var ac = manager.spatial_acoustics
		var outside = AudioRoomClass.new(); outside.room_name = &"Fuera"
		outside.set_bounds(AABB(Vector3(-40, -5, -40), Vector3(40, 10, 80))); ac.register_room(outside)
		var inside = AudioRoomClass.new(); inside.room_name = &"Dentro"
		inside.set_bounds(AABB(Vector3(0, -5, -40), Vector3(40, 10, 80))); ac.register_room(inside)
		ac.register_portal(AudioPortalClass.new(&"Puerta", &"Fuera", &"Dentro", Vector3(0, 1.5, 6), 1.0))   # detras-derecha del oyente
		manager.set_listener_position(Vector3(-6, 1.5, 0))

		var noise := _periodic_noise(int(AudioServer.get_mix_rate()))
		var def = AudioEventDefClass.new(&"NodeVoice", noise)
		def.is_looping = true
		def.stream_length = 1.0
		def.target_bus = ParityClass.BUS
		manager.register_event_definition(def)

		var emitter = EmitterScene.new()
		emitter.event_def = def
		emitter.bus = String(ParityClass.BUS)
		emitter.position = Vector3(6, 1.5, -12)   # dentro, DELANTE-DERECHA del oyente; el portal queda DETRAS-DERECHA
		tree.root.add_child(emitter)
		emitter.set_event_manager(manager)
		emitter.play_event()
		for i in range(20):
			await tree.process_frame
			probe.drain()
		var inst = emitter.active_instance
		a.ok(inst != null and inst.room_path_active, "%s: la voz esta gobernada por el grafo de salas" % backend)
		var cap := await _capture(tree, probe)
		var ch = manager.voice_pool.get_channel(inst.assigned_channel_id)
		if backend == "steam_audio":
			a.ok(ch.get_player() != emitter and ch.get_position_node() == emitter, "steam_audio: el nodo aporta posicion y la voz sale por el pool")
			a.ok(not emitter.playing, "steam_audio: el AudioStreamPlayer3D del nodo no suena por si mismo")
			# El portal esta DETRAS del oyente y el emisor DELANTE: la coloracion delante/detras
			# es la pista que dice de donde viene. Se compara contra la misma voz SIN grafo.
			var ratio_portal: float = _pinna_band_ratio(cap, AudioServer.get_mix_rate())
			inst.room_path_active = false
			inst.set_position(emitter.global_position)
			var cap_direct := await _capture(tree, probe)
			var ratio_direct: float = _pinna_band_ratio(cap_direct, AudioServer.get_mix_rate())
			print("[OpenDou] origen aparente: ratio por el portal %.3f | directo %.3f" % [ratio_portal, ratio_direct])
			a.gt(100.0 * absf(ratio_portal - ratio_direct) / maxf(ratio_direct, 1e-9), 10.0, "steam_audio: la voz de nodo suena distinta viniendo del portal (detras) que del emisor (delante)")
		else:
			a.ok(ch.get_player() == emitter, "godot: el nodo sigue siendo la voz fisica")
			a.approx(emitter.global_position.x, 6.0, "godot: el nodo no se mueve al portal (limitacion conocida)", 0.001)
		emitter.stop_event()
		tree.root.remove_child(emitter)
		emitter.free()
		await probe.await_silence(tree, 0.002, 30)
		manager.stop_all()
		tree.root.remove_child(manager)
		manager.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous)
	return a
```

Registrar: `acc.absorb(await TestBinauralClass.run_node_emitter_async(tree))`. Run → rojo (`get_position_node` no existe; el nodo suena).

- [ ] **Step 2: Canal y `devirtualize`**

`physical_voice_channel.gd`, junto a `owned_by_node`:

```gdscript
## Nodo 3D cuya posicion global es la de la voz cada frame, sin ser su reproductor. Es
## como suenan los OpenDouEventPlayer3D en steam_audio: el nodo dice DONDE, el pool dice
## COMO. Null en las voces anonimas y en el backend godot.
var position_node_ref: WeakRef = null

func get_position_node() -> Node3D:
	if position_node_ref == null:
		return null
	var n = position_node_ref.get_ref()
	return n if n != null and is_instance_valid(n) and n is Node3D and n.is_inside_tree() else null
```

`bind()` limpia `position_node_ref = null`. En `voice_pool_manager.devirtualize()`, sustituir desde `var player: Node = instance.get_bound_player()` hasta el bucle de doble vinculación por:

```gdscript
	var player: Node = instance.get_bound_player()
	var position_node: Node3D = null
	var bus_override: StringName = &""
	# Backend steam_audio: un emisor de nodo 3D NO es la voz fisica. Aporta posicion, bus y
	# atenuacion, y la voz sale por un reproductor binaural del pool. Asi el origen aparente
	# del grafo de salas relocaliza tambien a las voces de nodo.
	if spatial_backend == &"steam_audio" and player is AudioStreamPlayer3D:
		position_node = player
		bus_override = StringName(player.bus)
		instance.copy_attenuation_from_player(player)
		player = null
	var owned_by_node: bool = player != null
```

Tras `ch.bind(player, owned_by_node)`: `ch.position_node_ref = weakref(position_node) if position_node != null else null`. Y el bus: `var bus_name: StringName = bus_override if not bus_override.is_empty() else (instance.definition.target_bus if instance.definition else &"Master")`.

- [ ] **Step 3: Manager y nodo**

En `_apply_voices()`, tras obtener `ch` y antes de calcular `volume_db`:

```gdscript
		var pos_node: Node3D = ch.get_position_node()
		if pos_node != null:
			instance.set_position(pos_node.global_position)
```

(`set_position` respeta `room_path_active`: solo mueve el objetivo aparente si el grafo no gobierna.) En `opendou_event_player_3d.gd`, `stop_event()` ya comprueba `playing` antes de `stop()`, así que no hace falta cambio; verificar que `_notification(EXIT_TREE)` solo llama `active_instance.stop()`.

- [ ] **Step 4: Verde y commit**

```bash
./run_tests.sh
git add addons/opendou/runtime/voice_pool_manager.gd addons/opendou/runtime/physical_voice_channel.gd addons/opendou/runtime/audio_event_manager.gd tests/test_binaural.gd tests/test_all.gd tests/leak_budget.txt
git commit -m "Fase 7B: los emisores de nodo aportan posicion en steam_audio y el origen aparente los relocaliza"
```

---

### Task 11: Paridad de nivel entre los dos backends

**Files:**
- Test: `tests/test_backend_parity.gd` (`run_parity_async`), registrar en `run_async_suite`

**Interfaces:**
- Consumes: `measure_voice()`, `make_manager()`, `ensure_bus()` de la Task 5; backend `steam_audio` de las Tasks 9–10.

- [ ] **Step 1: Test**

```gdscript
## El mismo evento, a la misma distancia, con los dos backends: menos de 1 dB de diferencia.
## Es lo que permite prometer que cambiar de backend no cambia la mezcla.
static func run_parity_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("backend_parity")
	if not BackendClass.native_available():
		print("[OpenDou] extension nativa AUSENTE: suite backend_parity omitida")
		return a
	var previous: String = str(ProjectSettings.get_setting(BackendClass.SETTING, "auto"))
	ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(BUS, 2.0)
	var levels: Dictionary = {}
	for backend in ["godot", "steam_audio"]:
		var manager = make_manager(tree, backend)
		await tree.process_frame
		var near := await measure_voice(tree, manager, probe, 2.0)
		var mid := await measure_voice(tree, manager, probe, 16.0)
		levels[backend] = {"near": near.rms_db, "mid": mid.rms_db}
		manager.stop_all()
		tree.root.remove_child(manager)
		manager.free()
	print("[OpenDou] paridad: godot 2 m %.2f dB / 16 m %.2f dB | steam_audio 2 m %.2f dB / 16 m %.2f dB" % [
		levels["godot"].near, levels["godot"].mid, levels["steam_audio"].near, levels["steam_audio"].mid])
	# De frente, el HRTF de Steam Audio no es transparente en nivel: la suma L+R de una fuente
	# frontal binaural puede diferir del paneo centrado de Godot en 1-2 dB por la ganancia
	# del propio HRTF. Por eso la paridad se afirma sobre la CAIDA entre distancias, que es
	# lo que la formula compartida gobierna, y el nivel absoluto se afirma con 2 dB.
	var drop_godot: float = levels["godot"].mid - levels["godot"].near
	var drop_steam: float = levels["steam_audio"].mid - levels["steam_audio"].near
	a.lt(absf(drop_godot - drop_steam), 1.0, "la caida de 2 a 16 m difiere menos de 1 dB entre backends")
	a.lt(absf(levels["godot"].near - levels["steam_audio"].near), 2.0, "el nivel absoluto a 2 m difiere menos de 2 dB")
	a.lt(drop_godot, -12.0, "y la caida es la de la distancia inversa: al menos -12 dB (esperado -18)")
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous)
	return a
```

Nota para el ejecutor: el spec pide «< 1 dB en cada distancia». Al escribir el plan se anticipa que el HRTF añade una ganancia frontal propia que la fórmula compartida no puede igualar; si al medir la diferencia absoluta a 2 m es < 1 dB, apretar la tolerancia a 1.0 y anotarlo. Si es mayor de 2 dB, no relajar: investigar (el candidato es la normalización del HRTF, `IPL_HRTFNORMTYPE_RMS` en `install_hrtf`).

- [ ] **Step 2: Registrar, correr y commit**

`acc.absorb(await TestBackendParityClass.run_parity_async(tree))`. Run: `./run_tests.sh` → verde (o investigar según la nota).

```bash
git add tests/test_backend_parity.gd tests/test_all.gd tests/leak_budget.txt
git commit -m "Fase 7B: paridad de nivel entre los backends godot y steam_audio"
```

---

### Task 12: Ajustes en vivo, bloque «Espacialización» en el menú y backend en el HUD

**Files:**
- Modify: `addons/opendou/runtime/audio_event_manager.gd` (propiedad `spatial_settings`, aplicación en vivo)
- Modify: `scenes/shared/pause_menu.tscn`, `scenes/shared/pause_menu.gd`
- Modify: `scenes/shared/demo_hud.gd:32-38`
- Modify: `tests/test_scene_guards.gd:79` (`min_nodes` del menú)
- Test: `tests/test_demo_scenes.gd` (`run_pause_menu_async`, ampliar), `tests/test_binaural.gd` (`run_settings_live_async`)

**Interfaces:**
- Produces en el manager: `var spatial_settings: OpenDouSpatialSettings` (creado en `_init`, `load_from_disk()` en `_ready`, conectado a `changed` → `_apply_spatial_settings()`), `func _apply_spatial_settings() -> void`, `func spatial_backend_label() -> String` («Steam Audio 4.8.1 · HRTF: default» o «Godot»).
- Produces en `PauseMenu`: `func spatial_controls() -> Dictionary` con las referencias `{"backend": Label, "blend": HSlider, "output": CheckButton, "sofa": Button, "reset": Button}` para la suite.
- Nodos nuevos bajo `Root/Center/Panel/Margin/Column/SoundPanel`, antes de `Back`: `SpatialTitle` (Label, SectionLabel), `BackendLabel` (Label, MutedLabel), `BlendRow` (HBoxContainer) con `BlendLabel` (Label, «Mezcla HRTF») y `BlendSlider` (HSlider, min 0, max 1, step 0.01, `size_flags_horizontal = 3`), `OutputToggle` (CheckButton, text «Altavoces (apagado = audífonos)»), `SofaRow` (HBoxContainer) con `SofaButton` (Button, «Cargar HRTF .sofa…») y `SofaResetButton` (Button, GhostButton, «HRTF incorporado»), `SofaDialog` (FileDialog, `access = 2` (filesystem), `file_mode = 0`, `filters = PackedStringArray("*.sofa ; SOFA HRTF")`).

- [ ] **Step 1: Tests (rojo)**

En `tests/test_demo_scenes.gd`, dentro de `run_pause_menu_async` tras las aserciones existentes:

```gdscript
	# Fase 7B: el bloque de espacializacion existe como nodos y refleja el backend.
	var sc: Dictionary = menu.spatial_controls()
	a.ok(sc.backend is Label and sc.blend is HSlider and sc.output is CheckButton and sc.sofa is Button and sc.reset is Button, "el bloque de espacializacion esta compuesto en la escena")
	var manager = DemoAudio.manager(menu)
	var native: bool = manager != null and manager.is_steam_audio_backend()
	a.eq(sc.blend.editable, native, "el deslizador de mezcla solo se edita con steam_audio")
	a.eq(sc.output.disabled, not native, "el conmutador de salida se deshabilita con godot")
	a.ok(sc.backend.text.contains("Steam Audio") == native, "la etiqueta dice el backend real")
```

Y en `test_scene_guards.gd` la entrada del menú pasa a `"min_nodes": 24`.

En `tests/test_binaural.gd`:

```gdscript
## Los ajustes del jugador llegan en vivo a los streams del pool.
static func run_settings_live_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("binaural_settings_live")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite binaural_settings_live omitida")
		return a
	var ParityClass = load("res://tests/test_backend_parity.gd")
	var BackendClass = load("res://addons/opendou/runtime/spatial/spatial_backend.gd")
	var previous: String = str(ProjectSettings.get_setting(BackendClass.SETTING, "auto"))
	var manager = ParityClass.make_manager(tree, "steam_audio")
	await tree.process_frame
	var p = manager.player_pool.acquire(manager.player_pool.PlayerKind.BINAURAL_3D)
	a.approx(p.stream.spatial_blend, 1.0, "un stream recien creado lleva la mezcla de los ajustes (1.0)")
	manager.spatial_settings.set_blend(0.4)
	a.approx(p.stream.spatial_blend, 0.4, "cambiar la mezcla llega al stream en vivo", 0.001)
	manager.spatial_settings.set_output("speakers")
	a.eq(p.stream.output_mode, 1, "cambiar la salida llega al stream en vivo")
	manager.spatial_settings.set_output("headphones")
	var p2 = manager.player_pool.acquire(manager.player_pool.PlayerKind.BINAURAL_3D)
	a.approx(p2.stream.spatial_blend, 0.4, "un stream creado DESPUES nace con los ajustes vigentes", 0.001)
	a.ok(manager.spatial_backend_label().begins_with("Steam Audio"), "la etiqueta del backend nombra a Steam Audio")
	manager.spatial_settings.set_blend(1.0)
	manager.player_pool.release(p)
	manager.player_pool.release(p2)
	tree.root.remove_child(manager)
	manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous)
	return a
```

Registrar `acc.absorb(await TestBinauralClass.run_settings_live_async(tree))`. Run → rojo.

- [ ] **Step 2: Manager**

Preload `const SpatialSettingsClass = preload("res://addons/opendou/runtime/spatial/spatial_settings.gd")`. Campo `var spatial_settings: OpenDouSpatialSettings`. En `_init`, al final: `spatial_settings = SpatialSettingsClass.new(); spatial_settings.changed.connect(_apply_spatial_settings)`. En `_ready`, tras añadir el pool: `spatial_settings.load_from_disk(); _apply_spatial_settings()`.

```gdscript
## Aplica los ajustes del jugador a todos los streams nativos, en vivo. Con backend godot
## no hay streams y no hace nada; el menu lo muestra deshabilitado.
func _apply_spatial_settings() -> void:
	if spatial_settings == null or not is_steam_audio_backend():
		return
	var mode: int = 1 if spatial_settings.output == "speakers" else 0
	var blend: float = spatial_settings.blend
	if player_pool != null:
		player_pool.for_each_spatial_stream(func(s): s.spatial_blend = blend; s.output_mode = mode)
		player_pool.default_spatial_blend = blend
		player_pool.default_output_mode = mode
	if spatial_settings.hrtf == "default":
		if str(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_name")) != "default":
			ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_default")
	elif not bool(ClassDB.class_call_static("OpenDouSpatialStream", "set_hrtf_sofa", spatial_settings.hrtf)):
		push_warning("[OpenDou] el HRTF %s no se pudo cargar: se vuelve al incorporado" % spatial_settings.hrtf)
		spatial_settings.hrtf = "default"
	spatial_settings.save_to_disk()

func spatial_backend_label() -> String:
	if not is_steam_audio_backend():
		return "Godot"
	return "Steam Audio %s · HRTF: %s" % [str(ClassDB.class_call_static("OpenDouSpatialStream", "get_steam_audio_version")), str(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_name"))]
```

En `native_player_pool.gd`: `var default_spatial_blend: float = 1.0` y `var default_output_mode: int = 0`, aplicados al stream en `_instantiate(BINAURAL_3D)` justo tras crearlo. (Un stream nuevo nace con los ajustes vigentes.)

- [ ] **Step 3: Escena y script del menú**

Añadir a `pause_menu.tscn`, antes de `[node name="Back" ...]`, con `parent="Root/Center/Panel/Margin/Column/SoundPanel"` para los de primer nivel:

```
[node name="SpatialTitle" type="Label" parent="Root/Center/Panel/Margin/Column/SoundPanel"]
layout_mode = 2
theme_type_variation = &"SectionLabel"
text = "ESPACIALIZACIÓN — cómo se ubican los sonidos 3D"

[node name="BackendLabel" type="Label" parent="Root/Center/Panel/Margin/Column/SoundPanel"]
layout_mode = 2
theme_type_variation = &"MutedLabel"
text = "Backend: —"

[node name="BlendRow" type="HBoxContainer" parent="Root/Center/Panel/Margin/Column/SoundPanel"]
layout_mode = 2
theme_override_constants/separation = 12

[node name="BlendLabel" type="Label" parent="Root/Center/Panel/Margin/Column/SoundPanel/BlendRow"]
custom_minimum_size = Vector2(140, 0)
layout_mode = 2
text = "Mezcla HRTF"

[node name="BlendSlider" type="HSlider" parent="Root/Center/Panel/Margin/Column/SoundPanel/BlendRow"]
layout_mode = 2
size_flags_horizontal = 3
size_flags_vertical = 4
max_value = 1.0
step = 0.01
value = 1.0

[node name="OutputToggle" type="CheckButton" parent="Root/Center/Panel/Margin/Column/SoundPanel"]
layout_mode = 2
text = "Altavoces (apagado = audífonos)"

[node name="SofaRow" type="HBoxContainer" parent="Root/Center/Panel/Margin/Column/SoundPanel"]
layout_mode = 2
theme_override_constants/separation = 10

[node name="SofaButton" type="Button" parent="Root/Center/Panel/Margin/Column/SoundPanel/SofaRow"]
custom_minimum_size = Vector2(0, 38)
layout_mode = 2
size_flags_horizontal = 3
text = "Cargar HRTF .sofa…"

[node name="SofaResetButton" type="Button" parent="Root/Center/Panel/Margin/Column/SoundPanel/SofaRow"]
custom_minimum_size = Vector2(0, 38)
layout_mode = 2
theme_type_variation = &"GhostButton"
text = "HRTF incorporado"

[node name="SofaDialog" type="FileDialog" parent="Root/Center/Panel/Margin/Column/SoundPanel"]
title = "Elegir un archivo SOFA"
size = Vector2i(720, 480)
access = 2
file_mode = 0
filters = PackedStringArray("*.sofa ; SOFA HRTF")
```

`pause_menu.gd`: `@onready` para los seis nodos (`_backend_label`, `_blend`, `_output`, `_sofa`, `_sofa_reset`, `_sofa_dialog`) con sus rutas; en `_ready`:

```gdscript
	_blend.value_changed.connect(func(v): var m = _manager(); if m: m.spatial_settings.set_blend(v))
	_output.toggled.connect(func(on): var m = _manager(); if m: m.spatial_settings.set_output("speakers" if on else "headphones"))
	_sofa.pressed.connect(_sofa_dialog.popup_centered)
	_sofa_dialog.file_selected.connect(func(path): var m = _manager(); if m: m.spatial_settings.set_hrtf(path); _refresh_spatial())
	_sofa_reset.pressed.connect(func(): var m = _manager(); if m: m.spatial_settings.set_hrtf("default"); _refresh_spatial())
```

`show_sound()` llama además `_refresh_spatial()`:

```gdscript
func _manager():
	return get_node_or_null("/root/OpenDou")

## Refleja el backend y los ajustes vigentes; con godot, todo deshabilitado y dicho.
func _refresh_spatial() -> void:
	var m = _manager()
	var native: bool = m != null and m.is_steam_audio_backend()
	_backend_label.text = "Backend: %s" % (m.spatial_backend_label() if m != null else "sin manager")
	_blend.editable = native
	_output.disabled = not native
	_sofa.disabled = not native
	_sofa_reset.disabled = not native
	if m != null:
		_blend.set_value_no_signal(m.spatial_settings.blend)
		_output.set_pressed_no_signal(m.spatial_settings.output == "speakers")

func spatial_controls() -> Dictionary:
	return {"backend": _backend_label, "blend": _blend, "output": _output, "sofa": _sofa, "reset": _sofa_reset}
```

`_ready` termina con `_refresh_spatial()` para que la suite lo vea sin abrir el menú.

- [ ] **Step 4: HUD**

En `demo_hud.gd`, `_ready`, tras rellenar `_exercises.text`:

```gdscript
	# El backend espacial es parte de lo que la escena ejercita, y cambia por maquina.
	var m = get_node_or_null("/root/OpenDou")
	if m != null and m.has_method("spatial_backend_label"):
		_exercises.text += "\n•  Backend espacial: %s" % m.spatial_backend_label()
```

- [ ] **Step 5: Verde y commit**

```bash
./run_tests.sh
git add addons/opendou/runtime/audio_event_manager.gd addons/opendou/runtime/native_player_pool.gd scenes/shared/pause_menu.tscn scenes/shared/pause_menu.gd scenes/shared/demo_hud.gd tests/test_scene_guards.gd tests/test_demo_scenes.gd tests/test_binaural.gd tests/test_all.gd
git commit -m "Fase 7B: ajustes del jugador en vivo, bloque de espacializacion en el menu y backend en el HUD"
```

---

### Task 13: Retiradas y reescrituras

**Files:**
- Delete: `addons/opendou/core/spatial/audio_spatial_binaural.gd` (+ `.uid`)
- Modify: `addons/opendou/editor/nodes/opendou_binaural_graph_node.gd`
- Modify: `tests/test_early_reflections_hrtf.gd` (quitar los Tests 2 y 3), `tests/test_all.gd` (contador 7 → 3)
- Test: `tests/test_editor_nodes.gd` (si ya construye el nodo binaural, se conserva; añadir una aserción)

**Interfaces:**
- Produces en `OpenDouBinauralGraphNode`: sin `preload` del Woodworth; `func refresh_from_runtime() -> void` que rellena `metrics_lbl` con backend, HRTF, mezcla y tamaño de bloque leídos de `/root/OpenDou` si existe (en el editor no existe y muestra «Sin runtime: se resuelve al ejecutar»).

- [ ] **Step 1: Test (rojo)**

En `tests/test_editor_nodes.gd`, junto a los demás nodos de grafo (su `run_all()` devuelve `Array[String]`; `test_all.gd` cuenta 5 → 6):

```gdscript
	var bin_node = load("res://addons/opendou/editor/nodes/opendou_binaural_graph_node.gd").new()
	bin_node.refresh_from_runtime()
	if not bin_node.metrics_lbl.text.contains("Backend"):
		failures.append("7B: el nodo binaural del editor no muestra el backend real")
	bin_node.free()
```

Y en `tests/test_early_reflections_hrtf.gd` borrar desde `# Test 2` hasta antes de `return failures`, quitar el `const AudioSpatialBinauralClass`; en `test_all.gd` su contador pasa a `total_tests += 3`. Run → rojo (`refresh_from_runtime` no existe).

- [ ] **Step 2: Reescribir el nodo del editor**

Quitar `const AudioSpatialBinauralClass = preload(...)`. Sustituir `_on_azimuth_changed` y el texto inicial de `metrics_lbl` por:

```gdscript
func _on_azimuth_changed(val: float) -> void:
	current_azimuth_deg = val
	if radar_canvas:
		radar_canvas.queue_redraw()
	refresh_from_runtime()

## Lo que el nodo ensena es lo REAL: backend, HRTF, mezcla y bloque del manager en marcha.
## En el editor no hay manager y lo dice; antes mostraba una formula que nadie ejecutaba.
func refresh_from_runtime() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var m = tree.root.get_node_or_null("/root/OpenDou") if tree != null and tree.root != null else null
	if m == null or not m.has_method("spatial_backend_label"):
		metrics_lbl.text = "Backend: sin runtime, se resuelve al ejecutar"
		return
	var line: String = "Backend: %s" % m.spatial_backend_label()
	if m.is_steam_audio_backend():
		line += "\nMezcla %.2f · bloque %d" % [m.spatial_settings.blend, int(ClassDB.class_call_static("OpenDouSpatialStream", "get_frame_size"))]
	metrics_lbl.text = line
```

y en `_build_ui`, tras crear `metrics_lbl`: `refresh_from_runtime()`.

- [ ] **Step 3: Retirar el Woodworth**

```bash
git rm addons/opendou/core/spatial/audio_spatial_binaural.gd addons/opendou/core/spatial/audio_spatial_binaural.gd.uid
grep -rn "AudioSpatialBinaural\|audio_spatial_binaural" addons tests scenes docs --include='*.gd' --include='*.tscn' --include='*.md' | grep -v superpowers
```
Expected: sin resultados fuera de `docs/superpowers`.

- [ ] **Step 4: Verde y commit**

```bash
./run_tests.sh
git add -A addons/opendou/core/spatial addons/opendou/editor/nodes/opendou_binaural_graph_node.gd tests/test_early_reflections_hrtf.gd tests/test_editor_nodes.gd tests/test_all.gd
git commit -m "Fase 7B: se retira el Woodworth en GDScript; el nodo binaural del editor muestra el backend real"
```

---

### Task 14: `build.sh`, avisos de licencia, README y documentos

**Files:**
- Create: `native/build.sh`, `addons/opendou/THIRD_PARTY_NOTICES.md`
- Modify: `README.md:11-14`, `docs/architecture/gdextension_api.md` (sección nueva), `AGENTS.md` §5b, `native/thirdparty/README.md`, `docs/tasks/current.md`, `native/CMakeLists.txt` (comentario de cabecera apunta a `build.sh`)

- [ ] **Step 1: `native/build.sh`**

```bash
#!/usr/bin/env bash
# Compila la extension nativa de OpenDou en macOS arm64. Reproducible: descarga y fija las
# dependencias si faltan, compila godot-cpp y la extension, y deja la salida en
# addons/opendou/bin lista para que Godot la cargue (sin cuarentena y firmada ad hoc).
#
# Solo macOS arm64 esta VERIFICADO. El CMake es multiplataforma y el SDK trae bibliotecas
# para Windows, Linux, Android, iOS y wasm, pero nada de eso se afirma hasta compilarlo y
# probarlo (spec 7B, S7).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIRD="$HERE/thirdparty"
GODOTCPP_COMMIT="26fb7ab"
STEAMAUDIO_VERSION="4.8.1"
STEAMAUDIO_URL="https://github.com/ValveSoftware/steam-audio/releases/download/v${STEAMAUDIO_VERSION}/steamaudio_${STEAMAUDIO_VERSION}.zip"
STEAMAUDIO_SHA256="4a0aa5ec1176f38f0b0993a37c2259d9e86f27e22d5e24f83ec4c3cb9a1d5449"
CMAKE="${CMAKE:-$(command -v cmake || echo /Applications/CMake.app/Contents/bin/cmake)}"

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
	echo "[OpenDou] build.sh solo esta verificado en macOS arm64. En otra plataforma, usa el CMake a mano y verifica la salida." >&2
	exit 1
fi

mkdir -p "$THIRD"
if [[ ! -d "$THIRD/godot-cpp/.git" ]]; then
	echo "[OpenDou] clonando godot-cpp @ $GODOTCPP_COMMIT"
	git clone --quiet https://github.com/godotengine/godot-cpp.git "$THIRD/godot-cpp"
fi
git -C "$THIRD/godot-cpp" fetch --quiet origin
git -C "$THIRD/godot-cpp" checkout --quiet "$GODOTCPP_COMMIT"

if [[ ! -f "$THIRD/steamaudio/include/phonon.h" ]]; then
	echo "[OpenDou] descargando Steam Audio $STEAMAUDIO_VERSION"
	TMP_ZIP="$THIRD/steamaudio_${STEAMAUDIO_VERSION}.zip"
	curl -L --fail --silent --show-error -o "$TMP_ZIP" "$STEAMAUDIO_URL"
	ACTUAL="$(shasum -a 256 "$TMP_ZIP" | awk '{print $1}')"
	if [[ "$ACTUAL" != "$STEAMAUDIO_SHA256" ]]; then
		echo "[OpenDou] el SHA-256 del SDK no coincide: $ACTUAL" >&2
		rm -f "$TMP_ZIP"
		exit 1
	fi
	unzip -q "$TMP_ZIP" -d "$THIRD/steamaudio_unpack"
	mv "$THIRD/steamaudio_unpack/steamaudio" "$THIRD/steamaudio"
	rm -rf "$THIRD/steamaudio_unpack" "$TMP_ZIP"
fi

echo "[OpenDou] compilando godot-cpp"
"$CMAKE" -S "$THIRD/godot-cpp" -B "$HERE/build/godot-cpp" -DGODOTCPP_API_VERSION=4.7 \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 > /dev/null
"$CMAKE" --build "$HERE/build/godot-cpp" --parallel > /dev/null

echo "[OpenDou] compilando la extension"
"$CMAKE" -S "$HERE" -B "$HERE/build/ext" -DCMAKE_BUILD_TYPE=Release > /dev/null
"$CMAKE" --build "$HERE/build/ext" --parallel

echo "[OpenDou] Steam Audio $(grep -E 'define STEAMAUDIO_VERSION_(MAJOR|MINOR|PATCH)' "$THIRD/steamaudio/include/phonon_version.h" | awk '{print $3}' | paste -sd. -)"
echo "[OpenDou] salida: $HERE/../addons/opendou/bin/"
ls -la "$HERE/../addons/opendou/bin/"*.dylib
```

`chmod +x native/build.sh`. Verificar: mover `native/build` a un lado (`mv native/build native/build.bak`), correr `./native/build.sh`, comprobar que produce la `.dylib` y que `./run_tests.sh` sigue verde; luego borrar `native/build.bak`. Nota: si la estructura del zip no es `steamaudio/` en la raíz, ajustar el `mv` con lo que `unzip -l` muestre y anotarlo en `native/thirdparty/README.md`.

- [ ] **Step 2: Avisos de licencia**

`addons/opendou/THIRD_PARTY_NOTICES.md`:

```markdown
# Avisos de terceros

OpenDou incluye o enlaza con el software de terceros siguiente. Cada uno conserva su licencia.

## Steam Audio 4.8.1
Copyright 2017-2025 Valve Corporation. Licenciado bajo la Apache License, Version 2.0.
Texto de la licencia: https://www.apache.org/licenses/LICENSE-2.0
Steam Audio incluye a su vez componentes de terceros listados en `THIRDPARTY.md` de su SDK
(https://github.com/ValveSoftware/steam-audio). Se distribuye como `libphonon.*` junto a la
extension nativa de OpenDou, sin modificaciones.

## godot-cpp
Copyright (c) 2017-present Godot Engine contributors. Licencia MIT.
https://github.com/godotengine/godot-cpp/blob/master/LICENSE.md
```

Antes de escribirlo, copiar el año exacto del aviso de copyright desde `native/thirdparty/steamaudio/THIRDPARTY.md` o `doc/` (`grep -ri "copyright" native/thirdparty/steamaudio/THIRDPARTY.md | head -3`).

- [ ] **Step 3: README y documentos**

`README.md` líneas 11–14 pasan a:

```markdown
> **Estado de implementacion.** OpenDou es **GDScript con una extension nativa opcional**:
> el motor, los eventos, el pool de voces y el grafo de salas son GDScript; el binaural
> (HRTF + ITD sobre Steam Audio 4.8.1) es una GDExtension en C++ que vive en `native/` y se
> compila con `native/build.sh` (macOS arm64 verificado). Sin la extension, todo funciona
> con el panner 3D de Godot: la suite lo verifica y lo dice.
```

`docs/architecture/gdextension_api.md`: añadir al final una sección «## 7. Estado real (Fase 7B)» con las clases registradas (`OpenDouSpatialStream`, `OpenDouSpatialStreamPlayback`), las estáticas, el ajuste `opendou/spatial/backend`, y el patrón de doble backend tal como quedó (`OpenDouSpatialBackend.resolve`).

`AGENTS.md` §5b, al final de la lista de trampas:

```markdown
- **Observación 42 (Fase 7B).** `AudioStreamPlayer3D` aplica por distancia un *high-shelf*
  cuyo corte es `attenuation_filter_cutoff_hz` y cuya profundidad es
  `(1 − min(1, multiplicador)) × attenuation_filter_db`. OpenDou escribía en ese corte el de
  oclusión (20 kHz sin oclusión), anulando el oscurecimiento por distancia. Ahora se escribe
  el mínimo de los dos. Limitación del backend `godot` que queda: a menos de `unit_size` la
  profundidad es 0 y una voz ocluida no se filtra; el backend nativo no la tiene.
- **Extensión nativa.** Una `.dylib` bajada del navegador trae `com.apple.quarantine` y
  macOS la rechaza («library load disallowed by system policy»): quitar el atributo y firmar
  ad hoc (lo hace `native/build.sh`). godot-cpp no tiene rama 4.7: `master` @ `26fb7ab`.
  `AudioStreamPlayback.mix_audio()` reserva memoria en el hilo de audio; medido con
  `benchmark_block`, aceptado y documentado en el spec 7B.
- **Steam Audio no renderiza el ITD.** La API C usa fase plana; OpenDou lo aplica con
  Woodworth restando el residuo de `peakDelays`. Si una versión futura lo hornea, la
  aserción «lag 0.45–0.75 ms a 90°» saldrá alta y hay que quitar la línea de retardo, no
  subir el umbral.
```

`native/thirdparty/README.md`: sustituir los pasos manuales por «ejecuta `native/build.sh`» y conservar la nota de qué se ignora en git. `native/CMakeLists.txt`: el comentario de cabecera apunta a `build.sh`. `docs/tasks/current.md`: estado «Fase 7B en ejecución» con enlace al plan.

- [ ] **Step 4: Verde y commit**

```bash
./run_tests.sh
git add native/build.sh native/CMakeLists.txt native/thirdparty/README.md addons/opendou/THIRD_PARTY_NOTICES.md README.md docs/architecture/gdextension_api.md AGENTS.md docs/tasks/current.md
git commit -m "Fase 7B: build.sh reproducible, avisos de licencia y documentos al dia"
```

---

### Task 15: Guardas de coste

**Files:**
- Create: `tools/bench_control_loop.gd`, `tests/dsp_budget.txt`
- Modify: `tests/test_binaural.gd` (`run_budget_async`), `tests/test_character_rig.gd` (`run_bench_async`: sin cambio, es la referencia), `run_tests.sh` (leer `dsp_budget.txt`)

**Interfaces:**
- `tools/bench_control_loop.gd` (`extends SceneTree`, se ejecuta con `Godot --headless --path . -s tools/bench_control_loop.gd`): postea 0, 50, 200 y 500 voces con `hdr_enabled = false`, mide µs por llamada a `_process` con `Time.get_ticks_usec()` sobre 120 frames, e imprime la tabla `instancias | us por _process | us por voz` con los dos backends si la extensión está.
- `tests/dsp_budget.txt`: primer número no comentado = techo en µs por voz y bloque para `benchmark_block(64)`; `run_tests.sh` lo lee igual que `leak_budget.txt` y falla si el log trae `[OpenDou] DSP nativo: N us` con N mayor.

- [ ] **Step 1: El banco del bucle de control**

```gdscript
extends SceneTree

## Coste del bucle de control por voz, con los dos backends. No es parte de la suite: es la
## medida que fija y revisa el techo de +10 % sobre los 3.9 us por voz de la Fase 6.
##
##     Godot --headless --path . -s tools/bench_control_loop.gd

const ManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const DefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var backends: Array = ["godot"]
	if BackendClass.native_available():
		backends.append("steam_audio")
	for backend in backends:
		ProjectSettings.set_setting(BackendClass.SETTING, backend)
		print("\n== backend %s ==" % backend)
		print("instancias | us por _process | us por voz")
		for count in [0, 50, 200, 500]:
			var manager = ManagerClass.new()
			manager.hdr_enabled = false
			root.add_child(manager)
			manager.set_max_physical_voices(64)
			var tone: AudioStreamWAV = load("res://addons/opendou/runtime/audio_synthesizer.gd").create_rain_ambient_loop(1.0)
			var def = DefClass.new(&"Bench", tone)
			def.is_looping = true
			def.stream_length = 1.0
			manager.register_event_definition(def)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in range(count):
				var inst = manager.post_event(def, null)
				if inst != null:
					inst.set_position(Vector3(rng.randf_range(-60, 60), 1.5, rng.randf_range(-60, 60)))
			for i in range(10):
				await process_frame
			var t0: int = Time.get_ticks_usec()
			for i in range(120):
				await process_frame
			var per_call: float = float(Time.get_ticks_usec() - t0) / 120.0
			print("%10d | %16.1f | %10.2f" % [count, per_call, per_call / maxf(float(count), 1.0)])
			manager.stop_all()
			root.remove_child(manager)
			manager.free()
	quit(0)
```

Correr y apuntar la tabla en `docs/superpowers/specs/2026-09-02-fase7b-binaural-todas-las-voces-design.md` §9 (una fila por backend a 200 voces). Si `steam_audio` supera 4.3 µs por voz, buscar primero reservas por frame en `apply_spatial` (ningún `Array`/`Dictionary` nuevo; `DistanceModelClass` es estático y no reserva).

- [ ] **Step 2: Techo del DSP en la suite**

`tests/dsp_budget.txt`:

```
27
# Techo en microsegundos por voz y bloque de 512 muestras para benchmark_block(64).
# 27 us = 15 % de un nucleo con 64 voces a 44.1 kHz (64 * 27 us cada 11.6 ms).
# Se ajusta a la baja cuando la primera medida real lo permita. Historia:
#   27 -> techo inicial (Fase 7B); primera medida: <rellenar con la cifra de la Task 8>
```

(El «rellenar» de la última línea se sustituye por la cifra real al ejecutar esta tarea: no es un marcador de plan, es un dato de medida.)

En `tests/test_binaural.gd`:

```gdscript
static func run_budget_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("binaural_budget")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite binaural_budget omitida")
		return a
	var budget_text := FileAccess.get_file_as_string("res://tests/dsp_budget.txt")
	var budget: float = 27.0
	for line in budget_text.split("\n"):
		if not line.strip_edges().begins_with("#") and line.strip_edges().is_valid_float():
			budget = float(line.strip_edges())
			break
	# Tres medidas y la mediana: el primer bloque paga cache frias.
	var samples: Array[float] = []
	for i in range(3):
		samples.append(float(ClassDB.class_call_static("OpenDouSpatialStream", "benchmark_block", 64)))
	samples.sort()
	print("[OpenDou] DSP nativo: %.1f us por voz y bloque (mediana de 3; techo %.0f)" % [samples[1], budget])
	a.lt(samples[1], budget, "el DSP nativo por voz y bloque queda bajo el techo de tests/dsp_budget.txt")
	return a
```

Registrar `acc.absorb(await TestBinauralClass.run_budget_async(tree))`. En `run_tests.sh` no hace falta parsear nada más: la aserción falla sola. Quitar del bloque de la Task 8 la llamada suelta a `benchmark_block` (queda esta).

- [ ] **Step 3: Verde y commit**

```bash
./run_tests.sh
git add tools/bench_control_loop.gd tools/bench_control_loop.gd.uid tests/dsp_budget.txt tests/test_binaural.gd tests/test_all.gd docs/superpowers/specs/2026-09-02-fase7b-binaural-todas-las-voces-design.md
git commit -m "Fase 7B: guardas de coste del bucle de control y del DSP nativo"
```

---

## Autorrevisión del plan

**Cobertura del spec:** §2 → Task 1; §3 (propiedades, cadena, ITD, HRTF en vivo, frame_size, `mix_audio`) → Tasks 6, 7, 8; §4 (pool, instancia, canal, obs 42) → Tasks 2, 4, 5, 9; §5 → Task 10; §6 → Tasks 3, 12; §7 → Task 14; §8 → Tasks 6, 13; §9 → Task 15; §10 verificación: ITD/ILD/delante-detrás (6, 7), LPF y shelf (6), paridad y obs 42 (5, 11), relocalización de nodo (10), HRTF en vivo (8), altavoces (6), ajustes (3, 12), doble backend (1, 5), composición (12), rendimiento (15). §11 criterios: 1 → 9+10 (audible en «Una casa canta» al correr la escena), 2 → 1, 3 → 10, 4 → 12, 5 → 14, 6 → 14, 7 → 15. Sin huecos.

**Marcadores:** el único «rellenar» es una cifra de medida en `dsp_budget.txt` que se escribe al ejecutar la Task 15.

**Consistencia de nombres:** `apply_spatial(instance, volume_db, pitch, cutoff_hz, listener_position, listener_basis)` (5, 9); `PlayerKind.BINAURAL_3D` (9, 10, 12); `for_each_spatial_stream(Callable)` (9, 12); `OpenDouDistanceModel.{attenuation_db, multiplier, gain_db_for_stream, shelf_db, listener_direction}` (4, 9); `copy_attenuation_from_player` (2, 10); estáticas del stream `configure, set_hrtf_default, set_hrtf_sofa, get_hrtf_name, get_hrtf_generation, benchmark_block, get_last_applied_itd_ms` (7, 8, 12, 13, 15); `OpenDouSpatialSettings.{hrtf, blend, output, set_*, load_from_disk, save_to_disk, changed}` (3, 12); `spatial_backend_label()` (12, 13); `make_manager/ensure_bus/measure_voice` de `TestBackendParity` (5, 9, 10, 11).

**Riesgo conocido al ejecutar:** la Task 11 anticipa que el nivel absoluto entre backends puede diferir por la ganancia frontal del HRTF; la nota dice qué apretar y qué investigar, no qué relajar.
