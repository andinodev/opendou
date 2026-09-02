# Fase 10 — El oyente y el entorno: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un oyente con cabeza y HRTF propios, un volumen de entorno con recurso de secciones (medio, viento, oclusión parcial, descarte, superficie), accesibilidad del jugador (mono, modo noche, indicador) y consulta de sonoridad para la IA.

**Architecture:** El oyente es un nodo que el resolver prefiere; radio y velocidad del sonido son dos atómicos estáticos del contexto nativo. El entorno es un `Area3D` con formas hijas cuya pertenencia se decide por geometría cada cuadro en `OpenDouEnvironmentState`; el estado efectivo se empuja al C++, al pool, a la acústica y a Master. La accesibilidad son dos ajustes más del jugador aplicados por un instalador estático sobre Master. La IA reutiliza el grafo de salas y la oclusión con otro destino.

**Tech Stack:** Godot 4.7.2 (GDScript), GDExtension C++17 sobre Steam Audio 4.8.1 (`native/`), suite headless `./run_tests.sh`.

**Spec:** `docs/superpowers/specs/2026-09-02-fase10-oyente-y-entorno-design.md`

## Global Constraints

- Rama `main`, commits pequeños con mensaje en español sin acentos en la primera línea.
- Comentarios de código en español sin acentos. Documentos en español con acentos.
- `./run_tests.sh` en verde antes de cada commit: `STATUS: PASSED`, cero `SCRIPT ERROR`, fugas ≤ `tests/leak_budget.txt` (540). Vigilante 180 s.
- Los tests con nodos van a `run_async_suite(tree)` de `tests/test_all.gd` (los síncronos corren sin árbol).
- Medir en Master o en el bus destino; un 3D no suena sin cámara u oyente; esperar por muestras.
- «El proyecto solo afirma lo que hace»: cada rasgo tiene un test con control (rasgo apagado = sin efecto).
- Rasgo apagado = sin cálculo en el bucle por voz (la Fase 9 dejó el coste por voz sobre el techo).
- Compilar la extensión: `/Applications/CMake.app/Contents/bin/cmake --build native/build/ext --parallel`. Godot: `/Users/Daniel/Downloads/Godot.app/Contents/MacOS/Godot`.
- El banco: `Godot --headless --path . -s tools/bench_control_loop.gd` (fila 200 voces).

---

## Estructura de archivos

| Archivo | Responsabilidad |
|---|---|
| `native/src/dsp.h` | `woodworth_itd_seconds(dx, dy, dz, r, c)` |
| `native/src/spatial_stream.{h,cpp}` | estáticos `configure_listener`, `get_head_radius_m`, `get_speed_of_sound_mps` |
| `addons/opendou/nodes/opendou_listener_3d.gd` | nodo oyente |
| `addons/opendou/runtime/listener_resolver.gd` | prioridad `opendou_listener_3d` |
| `addons/opendou/resources/acoustic_environment.gd` | recurso de cinco secciones |
| `addons/opendou/nodes/opendou_acoustic_volume_3d.gd` | volumen: contención y longitud de segmento |
| `addons/opendou/runtime/spatial/environment_state.gd` | estado efectivo del entorno por cuadro |
| `addons/opendou/runtime/spatial/medium_filter_installer.gd` | paso-bajo del medio en Master |
| `addons/opendou/runtime/accessibility_applier.gd` | mono y modo noche en Master |
| `addons/opendou/nodes/opendou_sound_indicator.gd` | HUD de direcciones |
| `addons/opendou/nodes/opendou_ai_hearing_3d.gd` | nodo de percepción |
| `addons/opendou/runtime/audio_event_manager.gd` | registro, `_update_environment`, viento, tono, `get_loudness_at`, accesibilidad |
| tests | `test_listener_3d.gd`, `test_acoustic_volume.gd`, `test_accessibility.gd`, `test_ai_hearing.gd` |

---

### Task 1: Radio de cabeza y velocidad del sonido como parámetros del contexto nativo

**Files:**
- Modify: `native/src/dsp.h:140-152`
- Modify: `native/src/spatial_stream.h` (junto a `configure_max_propagation_delay`), `native/src/spatial_stream.cpp` (`_bind_methods`, sitio del ITD ~línea 471)
- Test: `tests/test_listener_3d.gd` (parte A), registrar en `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouSpatialStream.configure_listener(head_radius_m: float, speed_of_sound_mps: float) -> bool` (estático; acota r a [0.02, 0.2] y c a [100, 6000]); `get_head_radius_m() -> float`, `get_speed_of_sound_mps() -> float` (estáticos).

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestListener3D
extends RefCounted

## Fase 10: el oyente como nodo. Parte A: radio de cabeza y velocidad del sonido en el C++.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const BUS: StringName = &"ListenerProbe"

static func _native() -> bool:
	return ClassDB.class_exists("OpenDouSpatialStream") and bool(ClassDB.class_call_static("OpenDouSpatialStream", "is_native_available"))

static func run_head_radius_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("listener_head_radius")
	if not _native():
		print("[OpenDou] extension nativa AUSENTE: radio de cabeza omitido")
		return a
	a.approx(float(ClassDB.class_call_static("OpenDouSpatialStream", "get_head_radius_m")), 0.0875, "radio por defecto 8.75 cm", 0.0001)
	a.approx(float(ClassDB.class_call_static("OpenDouSpatialStream", "get_speed_of_sound_mps")), 343.0, "velocidad por defecto 343", 0.01)
	if AudioServer.get_bus_index(String(BUS)) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, String(BUS))
		AudioServer.set_bus_send(idx, "Master")
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(BUS, 2.0)
	var stream = ClassDB.instantiate("OpenDouSpatialStream")
	stream.source = TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate()))
	stream.spatialize = true
	stream.spatial_blend = 1.0
	stream.direction = Vector3(1, 0, 0)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = String(BUS)
	player.volume_db = -6.0
	tree.root.add_child(player)
	player.play()
	var base := await TestBinauralClass._capture(tree, probe)
	var itd_base: float = stream.get_last_applied_itd_ms()
	var lag_base: int = TestBinauralClass._itd_lag(base.left, base.right)
	a.ok(bool(ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", 0.175, 343.0)), "se acepta el radio doble")
	var doubled := await TestBinauralClass._capture(tree, probe)
	var itd_doubled: float = stream.get_last_applied_itd_ms()
	var lag_doubled: int = TestBinauralClass._itd_lag(doubled.left, doubled.right)
	print("[OpenDou] radio de cabeza: 8.75 cm -> ITD %.3f ms (lag %d); 17.5 cm -> %.3f ms (lag %d)" % [itd_base, lag_base, itd_doubled, lag_doubled])
	a.approx(itd_doubled / maxf(itd_base, 1e-6), 2.0, "el ITD aplicado a 90 grados se dobla", 0.1)
	a.ok(lag_doubled >= int(1.15 * lag_base), "y el retardo medido en la salida crece con el (%d -> %d muestras)" % [lag_base, lag_doubled])
	a.ok(bool(ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", 0.0875, 1480.0)), "se acepta el agua")
	await TestBinauralClass._capture(tree, probe)
	var itd_water: float = stream.get_last_applied_itd_ms()
	a.lt(itd_water / maxf(itd_base, 1e-6), 0.25, "bajo el agua el ITD cae a menos de un cuarto (medido %.3f ms)" % itd_water)
	ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", 0.0875, 343.0)
	a.eq(bool(ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", 5.0, 343.0)), false, "un radio absurdo se rechaza")
	a.approx(float(ClassDB.class_call_static("OpenDouSpatialStream", "get_head_radius_m")), 0.0875, "y no cambia nada", 0.0001)
	player.stop()
	tree.root.remove_child(player)
	player.free()
	probe.teardown()
	return a
```

Registrar en `tests/test_all.gd`: `const TestListener3DClass = preload("res://tests/test_listener_3d.gd")` y, tras el spline, `acc.absorb(await TestListener3DClass.run_head_radius_async(tree))`.

- [ ] **Step 2: Correr y ver el fallo** — `./run_tests.sh`: el error esperado es que `configure_listener`/`get_head_radius_m` no existen (`SCRIPT ERROR` o aserciones en rojo).

- [ ] **Step 3: Implementar**

`native/src/dsp.h`:
```cpp
inline float woodworth_itd_seconds(float dir_x, float dir_y, float dir_z, float r = 0.0875f, float c = 343.0f) {
	float theta = std::fabs(std::atan2(dir_x, -dir_z));
	if (theta > kPi * 0.5f) {
		theta = kPi - theta;
	}
	const float phi = std::asin(std::clamp(dir_y, -1.0f, 1.0f));
	return (r / c) * (theta + std::sin(theta)) * std::cos(phi);
}
```

`native/src/spatial_stream.h` (junto a `configure_max_propagation_delay`):
```cpp
	// Oyente (Fase 10): radio de la cabeza esferica y velocidad del sonido del medio. Son
	// estaticos porque hay un oyente y escribirlos por voz costaria en el bucle de control.
	static bool configure_listener(float p_head_radius_m, float p_speed_of_sound_mps);
	static float get_head_radius_m() { return head_radius_m_.load(); }
	static float get_speed_of_sound_mps() { return speed_of_sound_mps_.load(); }
	static std::atomic<float> head_radius_m_;
	static std::atomic<float> speed_of_sound_mps_;
```

`native/src/spatial_stream.cpp`:
```cpp
std::atomic<float> OpenDouSpatialStream::head_radius_m_{ 0.0875f };
std::atomic<float> OpenDouSpatialStream::speed_of_sound_mps_{ 343.0f };

bool OpenDouSpatialStream::configure_listener(float p_head_radius_m, float p_speed_of_sound_mps) {
	// La linea de retardo del ITD es de 2 ms: r <= 0.2 m a 100 m/s daria 5 ms, pero a 343 m/s
	// 0.2 m son 1.5 ms. Se acotan los dos y se rechaza lo que no cabe.
	if (p_head_radius_m < 0.02f || p_head_radius_m > 0.2f || p_speed_of_sound_mps < 100.0f || p_speed_of_sound_mps > 6000.0f) {
		return false;
	}
	if ((p_head_radius_m / p_speed_of_sound_mps) * (kPi * 0.5f + 1.0f) > 0.0019f) {
		return false;
	}
	head_radius_m_.store(p_head_radius_m);
	speed_of_sound_mps_.store(p_speed_of_sound_mps);
	return true;
}
```
En `_bind_methods`:
```cpp
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("configure_listener", "head_radius_m", "speed_of_sound_mps"), &OpenDouSpatialStream::configure_listener);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("get_head_radius_m"), &OpenDouSpatialStream::get_head_radius_m);
	ClassDB::bind_static_method("OpenDouSpatialStream", D_METHOD("get_speed_of_sound_mps"), &OpenDouSpatialStream::get_speed_of_sound_mps);
```
Sitio del ITD: `const float itd = dsp::woodworth_itd_seconds(dx, dy, dz, head_radius_m_.load(), speed_of_sound_mps_.load()) * blend;` (`kPi` debe ser visible en el .cpp; si no, usar `opendou::dsp::kPi`).

- [ ] **Step 4: Compilar y correr** — `cmake --build …`, `./run_tests.sh` → verde; el test binaural existente sigue midiendo 0.55–0.75 ms.
- [ ] **Step 5: Commit** — `git add native/src tests/test_listener_3d.gd tests/test_all.gd && git commit -m "Fase 10: radio de cabeza y velocidad del sonido como parametros del contexto nativo"`

---

### Task 2: `OpenDouListener3D` y el resolver

**Files:**
- Create: `addons/opendou/nodes/opendou_listener_3d.gd`
- Modify: `addons/opendou/runtime/listener_resolver.gd`, `addons/opendou/runtime/audio_event_manager.gd` (`register_listener`, `unregister_listener`, `_apply_spatial_settings`, `_update_listener`)
- Test: `tests/test_listener_3d.gd` (parte B)

**Interfaces:**
- Produces: `OpenDouListener3D` con `head_radius_m`, `hrtf_override`, `output_mode` (`INHERIT=0, HEADPHONES=1, SPEAKERS=2`), `use_external_orientation`, `set_external_orientation(basis)`, `get_effective_basis()`, señal `listener_changed`; `OpenDouListenerResolver.set_opendou_listener(node)`; `AudioEventManager.register_listener(node)`, `unregister_listener(node)`, `get_listener_node() -> Node3D`.

- [ ] **Step 1: Test en rojo** (añadir a `tests/test_listener_3d.gd` y registrar `run_node_async`)

```gdscript
static func run_node_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("listener_node")
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.global_position = Vector3(50, 0, 0)
	cam.make_current()
	await tree.process_frame
	a.eq(String(manager.listener_resolver.source), "camera_3d", "sin nodo oyente manda la camara")
	var ListenerScript = load("res://addons/opendou/nodes/opendou_listener_3d.gd")
	var listener = ListenerScript.new()
	tree.root.add_child(listener)
	listener.global_position = Vector3(1, 2, 3)
	manager.register_listener(listener)
	await tree.process_frame
	a.eq(String(manager.listener_resolver.source), "opendou_listener_3d", "con el nodo, manda el nodo")
	a.ok(manager.active_listener_position.is_equal_approx(Vector3(1, 2, 3)), "y la posicion es la suya, no la de la camara")
	# Orientacion externa: girado 90 grados a la izquierda, lo que estaba delante queda a la derecha.
	listener.use_external_orientation = true
	listener.set_external_orientation(Basis(Vector3.UP, PI / 2.0))
	await tree.process_frame
	var fwd: Vector3 = -manager.active_listener_basis.z
	a.ok(fwd.is_equal_approx(Vector3(-1, 0, 0)), "la orientacion inyectada gira el frente del oyente (frente = %s)" % str(fwd))
	listener.use_external_orientation = false
	await tree.process_frame
	a.ok((-manager.active_listener_basis.z).is_equal_approx(Vector3(0, 0, -1)), "apagada, vuelve la del nodo")
	if _native():
		var gen_before: int = int(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_generation"))
		listener.hrtf_override = "user://no_existe.sofa"
		await tree.process_frame
		a.eq(int(ClassDB.class_call_static("OpenDouSpatialStream", "get_hrtf_generation")), gen_before, "un SOFA inexistente no cambia la generacion del HRTF")
		listener.hrtf_override = ""
		listener.head_radius_m = 0.1
		await tree.process_frame
		a.approx(float(ClassDB.class_call_static("OpenDouSpatialStream", "get_head_radius_m")), 0.1, "el radio del nodo llega al C++", 0.0001)
		listener.head_radius_m = 0.0875
		await tree.process_frame
	manager.unregister_listener(listener)
	await tree.process_frame
	a.eq(String(manager.listener_resolver.source), "camera_3d", "sin el nodo, vuelve la camara")
	tree.root.remove_child(listener); listener.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	return a
```

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar**

`addons/opendou/nodes/opendou_listener_3d.gd`:
```gdscript
@tool
class_name OpenDouListener3D
extends Node3D

## El oyente como nodo propio (Fase 10). El resolver lo prefiere sobre AudioListener3D y la
## camara. Lleva la cabeza (radio para el ITD), un HRTF por jugador y la orientacion externa
## de un giroscopio o un visor. Sin extension nativa solo aporta posicion y orientacion.

signal listener_changed

enum OutputMode { INHERIT, HEADPHONES, SPEAKERS }

## Radio de la cabeza esferica (Woodworth). Escala el ITD.
@export_range(0.02, 0.2, 0.0005) var head_radius_m: float = 0.0875:
	set(v):
		head_radius_m = clampf(v, 0.02, 0.2)
		listener_changed.emit()
## Ruta a un SOFA que manda sobre el ajuste del jugador. Vacio = el del jugador.
@export_file("*.sofa") var hrtf_override: String = "":
	set(v):
		hrtf_override = v
		listener_changed.emit()
## Salida que manda sobre el ajuste del jugador. INHERIT = la del jugador.
@export var output_mode: OutputMode = OutputMode.INHERIT:
	set(v):
		output_mode = v
		listener_changed.emit()
## Si esta activo, la orientacion viene de set_external_orientation(); la posicion sigue
## siendo la del nodo.
@export var use_external_orientation: bool = false:
	set(v):
		use_external_orientation = v
		listener_changed.emit()

var _external_basis: Basis = Basis.IDENTITY

func set_external_orientation(basis: Basis) -> void:
	_external_basis = basis.orthonormalized()

func get_effective_basis() -> Basis:
	return _external_basis if use_external_orientation else global_transform.basis

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	var m = get_node_or_null("/root/OpenDou")
	if m != null and m.has_method("register_listener"):
		m.register_listener(self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	var m = get_node_or_null("/root/OpenDou")
	if m != null and m.has_method("unregister_listener"):
		m.unregister_listener(self)
```
(El `has_method` aquí es sobre el autoload, que puede no existir en tests; no es una promesa vacía: el método existe y se llama directo en el manager.)

`listener_resolver.gd`: añadir `var _opendou_listener_ref: WeakRef = null`, `func set_opendou_listener(node: Node3D) -> void: _opendou_listener_ref = weakref(node) if node != null else null`, y en `resolve()` entre el override de nodo y `viewport`:
```gdscript
	if _opendou_listener_ref != null:
		var l = _opendou_listener_ref.get_ref()
		if l != null and is_instance_valid(l) and l is Node3D and l.is_inside_tree():
			position = l.global_position
			basis = l.get_effective_basis() if l.has_method("get_effective_basis") else l.global_transform.basis
			source = &"opendou_listener_3d"
			return true
```

Manager:
```gdscript
var _listener_node_ref: WeakRef = null

## Registra el OpenDouListener3D. Si hay dos, manda el ultimo y se avisa una vez.
func register_listener(node: Node3D) -> void:
	if _listener_node_ref != null and _listener_node_ref.get_ref() != null and _listener_node_ref.get_ref() != node:
		push_warning("[OpenDou] hay mas de un OpenDouListener3D: manda el ultimo registrado (%s)" % node.name)
	_listener_node_ref = weakref(node)
	listener_resolver.set_opendou_listener(node)
	if not node.listener_changed.is_connected(_apply_spatial_settings):
		node.listener_changed.connect(_apply_spatial_settings)
	_apply_spatial_settings()

func unregister_listener(node: Node3D) -> void:
	if _listener_node_ref == null or _listener_node_ref.get_ref() != node:
		return
	if node.listener_changed.is_connected(_apply_spatial_settings):
		node.listener_changed.disconnect(_apply_spatial_settings)
	_listener_node_ref = null
	listener_resolver.set_opendou_listener(null)
	_apply_spatial_settings()

func get_listener_node() -> Node3D:
	return _listener_node_ref.get_ref() if _listener_node_ref != null else null
```
En `_apply_spatial_settings`, tras el `return` inicial: `var node = get_listener_node()`; `mode` = según `node.output_mode` si no es INHERIT; HRTF: si `node != null and not node.hrtf_override.is_empty()`: `if bool(set_hrtf_sofa(node.hrtf_override)): return (tras aplicar blend/mode)` y si falla `push_warning` una vez (`_warned_hrtf_override: String`) y seguir con el del jugador. Radio: `configure_listener(node.head_radius_m if node else 0.0875, environment.speed_of_sound if environment else 343.0)` — hasta la Task 3, `343.0`. La llamada a `configure_listener` va ANTES del `return` de «no es steam_audio» solo si la clase existe; sin extensión no hace nada.

- [ ] **Step 4: Correr** → verde.
- [ ] **Step 5: Commit** — `git add addons/opendou/nodes/opendou_listener_3d.gd addons/opendou/runtime/listener_resolver.gd addons/opendou/runtime/audio_event_manager.gd tests/test_listener_3d.gd tests/test_all.gd && git commit -m "Fase 10: OpenDouListener3D, preferido por el resolver, con cabeza, HRTF y orientacion externa"`

---

### Task 3: `AcousticEnvironment`, `OpenDouAcousticVolume3D`, estado del entorno y el medio

**Files:**
- Create: `addons/opendou/resources/acoustic_environment.gd`, `addons/opendou/nodes/opendou_acoustic_volume_3d.gd`, `addons/opendou/runtime/spatial/environment_state.gd`, `addons/opendou/runtime/spatial/medium_filter_installer.gd`
- Modify: `audio_event_manager.gd` (`register_acoustic_volume`, `_update_environment`, tono del medio en `_apply_voices`), `voice_pool_manager.gd:220`, `physical_voice_channel.gd:190`, `spatial_acoustics_manager.gd:280`
- Test: `tests/test_acoustic_volume.gd` (`run_geometry`, `run_medium_async`)

**Interfaces:**
- Produces: `AcousticEnvironment` (exports del spec §4.1); `OpenDouAcousticVolume3D.environment`, `.priority`, `contains_point(p) -> bool`, `segment_length_inside(a, b) -> float`; `OpenDouEnvironmentState.update(volumes: Array, listener_pos: Vector3, delta: float)`, `.speed_of_sound`, `.medium_lowpass_hz`, `.medium_pitch_scale`, `.medium_snapshot`, `.wind_velocity` (ya con ráfaga), `.wind_min_distance_m`, `.culled_buses: Dictionary`, `.medium_changed: bool`; `AudioEventManager.register_acoustic_volume(v)`, `unregister_acoustic_volume(v)`, `acoustic_volumes: Array`, `environment: OpenDouEnvironmentState`; `VoicePoolManager.speed_of_sound`, `set_speed_of_sound(c)`; `PhysicalVoiceChannel.speed_of_sound`; `SpatialAcousticsManager.speed_of_sound`.

- [ ] **Step 1: Tests en rojo**

```gdscript
class_name TestAcousticVolume
extends RefCounted

## Fase 10: el entorno como volumen + recurso.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EnvClass = preload("res://addons/opendou/resources/acoustic_environment.gd")
const VolumeScript = preload("res://addons/opendou/nodes/opendou_acoustic_volume_3d.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func make_box_volume(tree: SceneTree, center: Vector3, size: Vector3, env) -> Node:
	var v = VolumeScript.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	v.add_child(shape)
	v.environment = env
	tree.root.add_child(v)
	v.global_position = center
	return v

static func run_geometry(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_volume_geometry")
	var v = make_box_volume(tree, Vector3(10, 0, 0), Vector3(4, 4, 4), EnvClass.new())
	a.ok(v.contains_point(Vector3(10, 1, 1)), "contiene un punto dentro de la caja")
	a.ok(not v.contains_point(Vector3(13, 0, 0)), "no contiene uno fuera")
	a.approx(v.segment_length_inside(Vector3(0, 0, 0), Vector3(20, 0, 0)), 4.0, "un segmento que la cruza mide su lado", 0.001)
	a.approx(v.segment_length_inside(Vector3(0, 0, 0), Vector3(10, 0, 0)), 2.0, "hasta el centro, la mitad", 0.001)
	a.approx(v.segment_length_inside(Vector3(0, 10, 0), Vector3(20, 10, 0)), 0.0, "por fuera, nada", 0.001)
	v.rotate_y(PI / 4.0)
	a.ok(v.contains_point(Vector3(10, 0, 0)), "girada sigue conteniendo el centro")
	a.ok(not v.contains_point(Vector3(12.5, 0, 0)), "y ya no la esquina que quedo fuera")
	tree.root.remove_child(v); v.free()
	var s = VolumeScript.new()
	var sh := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.0
	sh.shape = sphere
	s.add_child(sh)
	tree.root.add_child(s)
	a.approx(s.segment_length_inside(Vector3(-5, 0, 0), Vector3(5, 0, 0)), 4.0, "una esfera de radio 2 cruzada por el centro mide 4", 0.001)
	a.approx(s.segment_length_inside(Vector3(-5, 1, 0), Vector3(5, 1, 0)), 2.0 * sqrt(3.0), "a 1 m del centro, la cuerda", 0.001)
	tree.root.remove_child(s); s.free()
	return a

static func run_medium_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_volume_medium")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var backend: String = "steam_audio" if BackendClass.native_available() else "godot"
	var manager = TestParityClass.make_manager(tree, backend)
	var cam := TestParityClass.make_listener_camera(tree)
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var noise = TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate()))
	var def = AudioEventDefClass.new(&"MediumVoice", noise)
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(2, 0, 0))
	var air := await TestBinauralClass._capture(tree, probe)
	var air_high: float = TestBinauralClass._band_energy_stereo(air, AudioServer.get_mix_rate(), 4000.0, 8000.0)
	var itd_air: float = _max_applied_itd(manager)
	var env = EnvClass.new()
	env.medium_enabled = true
	env.speed_of_sound_mps = 1480.0
	env.medium_lowpass_hz = 800.0
	var water = make_box_volume(tree, Vector3.ZERO, Vector3(10, 10, 10), env)
	manager.register_acoustic_volume(water)
	for i in range(30):
		await tree.process_frame
	a.approx(manager.environment.speed_of_sound, 1480.0, "con el oyente dentro, el medio es agua", 0.01)
	a.approx(manager.voice_pool.speed_of_sound, 1480.0, "y el pool lo sabe", 0.01)
	a.approx(manager.spatial_acoustics.speed_of_sound, 1480.0, "y el doppler tambien", 0.01)
	var wet := await TestBinauralClass._capture(tree, probe)
	var wet_high: float = TestBinauralClass._band_energy_stereo(wet, AudioServer.get_mix_rate(), 4000.0, 8000.0)
	var drop: float = linear_to_db(maxf(wet_high, 1e-12)) - linear_to_db(maxf(air_high, 1e-12))
	print("[OpenDou] medio agua (%s): banda 4-8 kHz %.1f dB; ITD aire %.3f ms, agua %.3f ms" % [backend, drop, itd_air, _max_applied_itd(manager)])
	a.lt(drop, -12.0, "la banda alta cae al menos 12 dB bajo el agua")
	if backend == "steam_audio":
		a.lt(_max_applied_itd(manager) / maxf(itd_air, 1e-6), 0.25, "el ITD cae a menos de un cuarto")
	water.global_position = Vector3(100, 0, 0)
	for i in range(30):
		await tree.process_frame
	a.approx(manager.environment.speed_of_sound, 343.0, "al salir, aire", 0.01)
	var back := await TestBinauralClass._capture(tree, probe)
	var back_high: float = TestBinauralClass._band_energy_stereo(back, AudioServer.get_mix_rate(), 4000.0, 8000.0)
	a.approx(linear_to_db(maxf(back_high, 1e-12)) - linear_to_db(maxf(air_high, 1e-12)), 0.0, "y la banda alta vuelve", 1.5)
	inst.stop()
	manager.unregister_acoustic_volume(water)
	tree.root.remove_child(water); water.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a

static func _max_applied_itd(manager) -> float:
	if manager.player_pool == null or not ClassDB.class_exists("OpenDouSpatialStream"):
		return 0.0
	var best: Array = [0.0]
	manager.player_pool.for_each_spatial_stream(func(s): best[0] = maxf(best[0], s.get_last_applied_itd_ms()))
	return best[0]
```
Registrar en `test_all.gd` (suite asíncrona): `acc.absorb(TestAcousticVolumeClass.run_geometry(tree))` y `acc.absorb(await TestAcousticVolumeClass.run_medium_async(tree))`.

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar**

`resources/acoustic_environment.gd`:
```gdscript
@tool
class_name AcousticEnvironment
extends Resource

## Comportamiento acustico de un volumen (Fase 10): cinco secciones opcionales, todas
## apagadas por defecto. El nodo es OpenDouAcousticVolume3D; esto es el dato, como
## Environment lo es de WorldEnvironment.

@export_group("Medio")
@export var medium_enabled: bool = false
## Escala el ITD, el retardo por distancia y el doppler. Agua: 1480.
@export_range(100.0, 6000.0, 1.0) var speed_of_sound_mps: float = 343.0
## Paso-bajo en Master mientras el oyente esta dentro. 20000 = sin filtro.
@export_range(200.0, 20000.0, 1.0) var medium_lowpass_hz: float = 20000.0
## Factor de tono sobre todas las voces fisicas.
@export_range(0.5, 2.0, 0.01) var medium_pitch_scale: float = 1.0
## Instantanea de mezcla que se empuja al entrar y se saca al salir. Vacia = ninguna.
@export var medium_snapshot: StringName = &""

@export_group("Viento")
@export var wind_enabled: bool = false
## Velocidad del viento en el mundo, m/s.
@export var wind_velocity: Vector3 = Vector3.ZERO
@export_range(0.0, 1.0, 0.01) var wind_gust_strength: float = 0.0
@export_range(0.01, 5.0, 0.01) var wind_gust_rate_hz: float = 0.2
## Solo las voces mas lejanas que esto notan el viento.
@export_range(0.0, 500.0, 1.0) var wind_min_distance_m: float = 20.0

@export_group("Oclusion parcial")
@export var occluder_enabled: bool = false
@export_range(0.0, 30.0, 0.1) var occluder_db_per_m: float = 3.0
@export_range(0.0, 10000.0, 10.0) var occluder_cutoff_hz_per_m: float = 2000.0

@export_group("Descarte")
@export var cull_enabled: bool = false
## Buses (target_bus de la definicion) cuyas voces se virtualizan con el oyente dentro.
@export var cull_buses: Array[StringName] = []

@export_group("Superficie")
@export var surface_enabled: bool = false
@export var surface_type: StringName = &""
@export var surface_priority: int = 0
```

`nodes/opendou_acoustic_volume_3d.gd`:
```gdscript
@tool
class_name OpenDouAcousticVolume3D
extends Area3D

## Volumen de entorno acustico (Fase 10). Sus formas son los CollisionShape3D hijos; la
## pertenencia del oyente se decide por geometria (caja, esfera, cilindro analiticos; otras
## por su AABB), no por body_entered: el oyente no es un cuerpo.

const AcousticEnvironmentClass = preload("res://addons/opendou/resources/acoustic_environment.gd")

@export var environment: AcousticEnvironment = null
## Entre volumenes que contienen al oyente, manda el de mayor prioridad.
@export var priority: int = 0

var _warned_no_shape: bool = false

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	var m = get_node_or_null("/root/OpenDou")
	if m != null and m.has_method("register_acoustic_volume"):
		m.register_acoustic_volume(self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	var m = get_node_or_null("/root/OpenDou")
	if m != null and m.has_method("unregister_acoustic_volume"):
		m.unregister_acoustic_volume(self)

func _shapes() -> Array:
	var out: Array = []
	for c in get_children():
		if c is CollisionShape3D and c.shape != null:
			out.append(c)
	if out.is_empty() and not _warned_no_shape:
		_warned_no_shape = true
		push_warning("[OpenDou] %s no tiene CollisionShape3D: no contiene nada" % name)
	return out

## True si el punto (mundo) cae dentro de alguna forma.
func contains_point(p: Vector3) -> bool:
	for cs in _shapes():
		var local: Vector3 = cs.global_transform.affine_inverse() * p
		var sh: Shape3D = cs.shape
		if sh is BoxShape3D:
			var h: Vector3 = sh.size * 0.5
			if absf(local.x) <= h.x and absf(local.y) <= h.y and absf(local.z) <= h.z:
				return true
		elif sh is SphereShape3D:
			if local.length() <= sh.radius:
				return true
		elif sh is CylinderShape3D:
			if absf(local.y) <= sh.height * 0.5 and Vector2(local.x, local.z).length() <= sh.radius:
				return true
		else:
			var aabb: AABB = sh.get_debug_mesh().get_aabb()
			if aabb.has_point(local):
				return true
	return false

## Longitud (m) del segmento a->b (mundo) que queda dentro del volumen. Caja y esfera
## analiticas (slab y cuerda); cilindro y otras por su AABB. Si hay varias formas se suma.
func segment_length_inside(a: Vector3, b: Vector3) -> float:
	var total: float = 0.0
	for cs in _shapes():
		var inv: Transform3D = cs.global_transform.affine_inverse()
		var la: Vector3 = inv * a
		var lb: Vector3 = inv * b
		var sh: Shape3D = cs.shape
		var world_len: float = a.distance_to(b)
		if sh is SphereShape3D:
			total += _sphere_chord(la, lb, sh.radius) * world_len
		else:
			var half: Vector3
			if sh is BoxShape3D:
				half = sh.size * 0.5
			elif sh is CylinderShape3D:
				half = Vector3(sh.radius, sh.height * 0.5, sh.radius)
			else:
				var aabb: AABB = sh.get_debug_mesh().get_aabb()
				half = aabb.size * 0.5
				la -= aabb.get_center()
				lb -= aabb.get_center()
			total += _box_slab(la, lb, half) * world_len
	return total

## Fraccion [0,1] del segmento local la->lb dentro de la caja centrada de semilados `half`.
static func _box_slab(la: Vector3, lb: Vector3, half: Vector3) -> float:
	var t0: float = 0.0
	var t1: float = 1.0
	var d: Vector3 = lb - la
	for axis in range(3):
		if absf(d[axis]) < 1e-9:
			if absf(la[axis]) > half[axis]:
				return 0.0
			continue
		var ta: float = (-half[axis] - la[axis]) / d[axis]
		var tb: float = (half[axis] - la[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 >= t1:
			return 0.0
	return t1 - t0

## Fraccion del segmento dentro de la esfera de radio r centrada en el origen.
static func _sphere_chord(la: Vector3, lb: Vector3, r: float) -> float:
	var d: Vector3 = lb - la
	var aa: float = d.dot(d)
	if aa < 1e-12:
		return 1.0 if la.length() <= r else 0.0
	var bb: float = 2.0 * la.dot(d)
	var cc: float = la.dot(la) - r * r
	var disc: float = bb * bb - 4.0 * aa * cc
	if disc <= 0.0:
		return 0.0
	var sq: float = sqrt(disc)
	var t0: float = clampf((-bb - sq) / (2.0 * aa), 0.0, 1.0)
	var t1: float = clampf((-bb + sq) / (2.0 * aa), 0.0, 1.0)
	return maxf(0.0, t1 - t0)
```

`runtime/spatial/medium_filter_installer.gd`:
```gdscript
class_name OpenDouMediumFilterInstaller
extends RefCounted

## Paso-bajo del medio en Master (Fase 10), antes de la cadena de masterizacion. Marcado
## para que sea idempotente y la suite lo encuentre.

const MARK: String = "OpenDou_Medium_LPF"

static func apply(cutoff_hz: float, bus_name: String = "Master") -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var fx := _find(idx) as AudioEffectLowPassFilter
	if cutoff_hz >= 19999.0:
		if fx != null:
			for i in range(AudioServer.get_bus_effect_count(idx)):
				if AudioServer.get_bus_effect(idx, i) == fx:
					AudioServer.remove_bus_effect(idx, i)
					break
		return
	if fx == null:
		fx = AudioEffectLowPassFilter.new()
		fx.resource_name = MARK
		AudioServer.add_bus_effect(idx, fx, 0)
	fx.cutoff_hz = clampf(cutoff_hz, 200.0, 20000.0)

static func is_installed(bus_name: String = "Master") -> bool:
	var idx: int = AudioServer.get_bus_index(bus_name)
	return idx >= 0 and _find(idx) != null

static func _find(bus_idx: int) -> AudioEffect:
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var e := AudioServer.get_bus_effect(bus_idx, i)
		if e != null and e.resource_name == MARK:
			return e
	return null
```

`runtime/spatial/environment_state.gd`:
```gdscript
class_name OpenDouEnvironmentState
extends RefCounted

## Estado efectivo del entorno para el oyente, resuelto cada cuadro a partir de los
## volumenes que lo contienen (Fase 10). Medio y viento: el de mayor prioridad; descarte: la
## union. La oclusion parcial y la superficie no son estado del oyente y se consultan aparte.

var speed_of_sound: float = 343.0
var medium_lowpass_hz: float = 20000.0
var medium_pitch_scale: float = 1.0
var medium_snapshot: StringName = &""
var wind_velocity: Vector3 = Vector3.ZERO   # ya con la rafaga aplicada
var wind_min_distance_m: float = 20.0
var culled_buses: Dictionary = {}           # StringName -> true
var inside: Array = []                      # volumenes que contienen al oyente este cuadro
## True el cuadro en que cambio el medio (velocidad, filtro, tono o instantanea).
var medium_changed: bool = false
var _time: float = 0.0

func update(volumes: Array, listener_pos: Vector3, delta: float) -> void:
	_time += delta
	inside.clear()
	culled_buses.clear()
	var medium = null
	var medium_prio: int = -2147483648
	var wind = null
	var wind_prio: int = -2147483648
	for v in volumes:
		if v == null or not is_instance_valid(v) or v.environment == null or not v.is_inside_tree():
			continue
		if not v.contains_point(listener_pos):
			continue
		inside.append(v)
		var env = v.environment
		if env.medium_enabled and v.priority > medium_prio:
			medium = env
			medium_prio = v.priority
		if env.wind_enabled and v.priority > wind_prio:
			wind = env
			wind_prio = v.priority
		if env.cull_enabled:
			for b in env.cull_buses:
				culled_buses[b] = true
	var new_c: float = medium.speed_of_sound_mps if medium != null else 343.0
	var new_lpf: float = medium.medium_lowpass_hz if medium != null else 20000.0
	var new_pitch: float = medium.medium_pitch_scale if medium != null else 1.0
	var new_snap: StringName = medium.medium_snapshot if medium != null else &""
	medium_changed = not is_equal_approx(new_c, speed_of_sound) or not is_equal_approx(new_lpf, medium_lowpass_hz) \
		or not is_equal_approx(new_pitch, medium_pitch_scale) or new_snap != medium_snapshot
	speed_of_sound = new_c
	medium_lowpass_hz = new_lpf
	medium_pitch_scale = new_pitch
	medium_snapshot = new_snap
	if wind != null:
		var gust: float = 1.0 + wind.wind_gust_strength * sin(TAU * wind.wind_gust_rate_hz * _time)
		wind_velocity = wind.wind_velocity * gust
		wind_min_distance_m = wind.wind_min_distance_m
	else:
		wind_velocity = Vector3.ZERO

func has_wind() -> bool:
	return wind_velocity.length_squared() > 1e-6

func is_culled(bus: StringName) -> bool:
	return culled_buses.has(bus)
```

Manager:
```gdscript
const EnvironmentStateClass = preload("res://addons/opendou/runtime/spatial/environment_state.gd")
const MediumFilterInstallerClass = preload("res://addons/opendou/runtime/spatial/medium_filter_installer.gd")
var acoustic_volumes: Array = []
var environment: OpenDouEnvironmentState = EnvironmentStateClass.new()
var _active_medium_snapshot: StringName = &""

func register_acoustic_volume(volume: Node3D) -> void:
	if not acoustic_volumes.has(volume):
		acoustic_volumes.append(volume)
	if spatial_acoustics != null:
		spatial_acoustics.surface_volumes = acoustic_volumes   # Task 5 lo usa

func unregister_acoustic_volume(volume: Node3D) -> void:
	acoustic_volumes.erase(volume)

## Resuelve el entorno del oyente y empuja el medio a quien lo necesita, solo si cambio.
func _update_environment(delta: float) -> void:
	if acoustic_volumes.is_empty() and environment.inside.is_empty() and is_equal_approx(environment.speed_of_sound, 343.0):
		return
	environment.update(acoustic_volumes, active_listener_position, delta)
	if not environment.medium_changed:
		return
	var c: float = environment.speed_of_sound
	if voice_pool != null:
		voice_pool.set_speed_of_sound(c)
	if spatial_acoustics != null:
		spatial_acoustics.speed_of_sound = c
	if ClassDB.class_exists("OpenDouSpatialStream"):
		var node = get_listener_node()
		ClassDB.class_call_static("OpenDouSpatialStream", "configure_listener", node.head_radius_m if node != null else 0.0875, c)
	MediumFilterInstallerClass.apply(environment.medium_lowpass_hz)
	if environment.medium_snapshot != _active_medium_snapshot:
		if _active_medium_snapshot != &"":
			pop_snapshot(_active_medium_snapshot)
		if environment.medium_snapshot != &"":
			push_snapshot(environment.medium_snapshot)
		_active_medium_snapshot = environment.medium_snapshot
```
En `_process`, justo después de `_update_listener()`: `_update_environment(delta)`. En `_apply_voices`: `var pitch: float = instance.calculated_pitch_scale * instance.doppler_pitch` → si `environment.medium_pitch_scale != 1.0`, multiplicar. En `_exit_tree` (o `NOTIFICATION_PREDELETE`) del manager: `MediumFilterInstallerClass.apply(20000.0)` para no dejar el filtro en Master entre tests.

`voice_pool_manager.gd`: `var speed_of_sound: float = 343.0`; `func set_speed_of_sound(c: float) -> void: speed_of_sound = c; for ch in channels: ch.speed_of_sound = c` (usar el nombre real del arreglo de canales); línea 220: `/ speed_of_sound`. `physical_voice_channel.gd`: `var speed_of_sound: float = 343.0`; línea 190: `distance / speed_of_sound`. `spatial_acoustics_manager.gd`: `var speed_of_sound: float = 343.0` y en `calculate_doppler_pitch` quitar la local.

- [ ] **Step 4: Correr** → verde (el doppler y el retardo de la Fase 9 siguen iguales con 343).
- [ ] **Step 5: Commit** — `git add addons/opendou/resources/acoustic_environment.gd addons/opendou/nodes/opendou_acoustic_volume_3d.gd addons/opendou/runtime/spatial/environment_state.gd addons/opendou/runtime/spatial/medium_filter_installer.gd addons/opendou/runtime/audio_event_manager.gd addons/opendou/runtime/voice_pool_manager.gd addons/opendou/runtime/physical_voice_channel.gd addons/opendou/runtime/spatial/spatial_acoustics_manager.gd tests/test_acoustic_volume.gd tests/test_all.gd && git commit -m "Fase 10: AcousticEnvironment y OpenDouAcousticVolume3D; el medio escala ITD, retardo y doppler y filtra Master"`

---

### Task 4: Viento y oclusión parcial

**Files:**
- Modify: `audio_event_manager.gd` (`_apply_voices`), `runtime/spatial/occlusion_scheduler.gd` (`process`), `event_instance.gd` (`culled`)
- Test: `tests/test_acoustic_volume.gd` (`run_wind_async`, `run_occluder_async`)

**Interfaces:**
- Consumes: `environment.has_wind()`, `wind_velocity`, `wind_min_distance_m`; `volume.segment_length_inside(a, b)`.
- Produces: `OcclusionScheduler.process(instances, listener_pos, world_3d, occluder_volumes: Array = [])`; `EventInstance.culled: bool`.

- [ ] **Step 1: Tests en rojo**

```gdscript
static func _rms_db_of(cap: Dictionary) -> float:
	return TestBinauralClass._rms_db(cap)

static func run_wind_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_volume_wind")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam := TestParityClass.make_listener_camera(tree)
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var noise = TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate()))
	var def = AudioEventDefClass.new(&"WindVoice", noise)
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.max_distance = 500.0
	inst.set_position(Vector3(0, 0, -60))
	var calm := await TestBinauralClass._capture(tree, probe)
	var env = EnvClass.new()
	env.wind_enabled = true
	env.wind_velocity = Vector3(0, 0, -15)   # sopla del oyente hacia el emisor: en contra del sonido
	env.wind_min_distance_m = 20.0
	var zone = make_box_volume(tree, Vector3.ZERO, Vector3(10, 10, 10), env)
	manager.register_acoustic_volume(zone)
	for i in range(20):
		await tree.process_frame
	var head := await TestBinauralClass._capture(tree, probe)
	env.wind_velocity = Vector3(0, 0, 15)    # a favor
	for i in range(20):
		await tree.process_frame
	var tail := await TestBinauralClass._capture(tree, probe)
	env.wind_velocity = Vector3.ZERO
	for i in range(20):
		await tree.process_frame
	var none := await TestBinauralClass._capture(tree, probe)
	var rate: float = AudioServer.get_mix_rate()
	var hi_head: float = linear_to_db(maxf(TestBinauralClass._band_energy_stereo(head, rate, 2000.0, 8000.0), 1e-12))
	var hi_tail: float = linear_to_db(maxf(TestBinauralClass._band_energy_stereo(tail, rate, 2000.0, 8000.0), 1e-12))
	print("[OpenDou] viento a 60 m: en contra %.1f dB, a favor %.1f dB, sin viento %.1f dB, sin volumen %.1f dB (RMS); banda alta en contra %.1f / a favor %.1f dB" % [
		_rms_db_of(head), _rms_db_of(tail), _rms_db_of(none), _rms_db_of(calm), hi_head, hi_tail])
	a.lt(_rms_db_of(head), _rms_db_of(tail) - 3.0, "viento en contra: al menos 3 dB menos que a favor")
	a.lt(hi_head, hi_tail - 3.0, "y la banda alta cae mas que el conjunto")
	a.approx(_rms_db_of(none), _rms_db_of(calm), "sin viento, igual que sin volumen", 0.5)
	a.approx(_rms_db_of(tail), _rms_db_of(calm), "a favor no se anade nada", 0.5)
	inst.stop()
	manager.unregister_acoustic_volume(zone)
	tree.root.remove_child(zone); zone.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a

static func run_occluder_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_volume_occluder")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam := TestParityClass.make_listener_camera(tree)
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var tone = load("res://tests/test_emitter_physics.gd")._tone(1000.0, 1.0)
	var def = AudioEventDefClass.new(&"OccluderVoice", tone)
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(0, 0, -8))
	await _settle(tree, 1.2)
	var clear_db: float = _rms_db_of(await TestBinauralClass._capture(tree, probe))
	var env = EnvClass.new()
	env.occluder_enabled = true
	env.occluder_db_per_m = 3.0
	env.occluder_cutoff_hz_per_m = 2000.0
	var hedge = make_box_volume(tree, Vector3(0, 0, -4), Vector3(6, 6, 4), env)   # 4 m de follaje en el camino
	manager.register_acoustic_volume(hedge)
	await _settle(tree, 1.2)
	var hedge4_db: float = _rms_db_of(await TestBinauralClass._capture(tree, probe))
	hedge.get_child(0).shape.size = Vector3(6, 6, 2)                                 # 2 m
	await _settle(tree, 1.2)
	var hedge2_db: float = _rms_db_of(await TestBinauralClass._capture(tree, probe))
	print("[OpenDou] oclusion parcial: sin volumen %.1f dB, 4 m %.1f dB, 2 m %.1f dB" % [clear_db, hedge4_db, hedge2_db])
	a.approx(hedge4_db - clear_db, -12.0, "4 m a 3 dB/m: -12 dB", 1.5)
	a.approx(hedge2_db - clear_db, -6.0, "2 m: -6 dB", 1.5)
	a.gt(manager.occlusion_scheduler.raycasts_this_frame + 0.0, 0.0, "la oclusion parcial viaja en el rayo que ya se lanza")
	inst.stop()
	manager.unregister_acoustic_volume(hedge)
	tree.root.remove_child(hedge); hedge.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	probe.teardown()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a

static func _settle(tree: SceneTree, sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await tree.process_frame
```
Comprobar la firma real de `_tone` en `tests/test_emitter_physics.gd` antes de usarla. La oclusión de Godot por rayo da 0 aquí (no hay cuerpos), así que lo medido es solo el volumen.

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar**

`event_instance.gd`: `var culled: bool = false` (junto a las variables de estado); en `calculate_dynamic_weight`, tras `if not is_playing(): return 0.0` → `if culled: return 0.0`.

`occlusion_scheduler.gd`: firma `func process(instances: Array, listener_pos: Vector3, world_3d: World3D, occluder_volumes: Array = []) -> int`; en la selección: `if inst.room_path_active or inst.culled: continue`; tras `var result = occlusion_manager.evaluate_occlusion(...)`:
```gdscript
		var extra_db: float = 0.0
		var extra_cut: float = 0.0
		for v in occluder_volumes:
			if v == null or not is_instance_valid(v) or v.environment == null or not v.environment.occluder_enabled:
				continue
			var l: float = v.segment_length_inside(inst.emitter_position, listener_pos)
			if l > 0.0:
				extra_db -= v.environment.occluder_db_per_m * l
				extra_cut += v.environment.occluder_cutoff_hz_per_m * l
		var lpf: float = result.target_lpf if extra_cut <= 0.0 else maxf(500.0, minf(result.target_lpf, 20000.0 - extra_cut))
		inst.set_target_lpf(lpf, result.volume_attenuation_db + extra_db)
```
Manager `_process`: `occlusion_scheduler.process(active_instances, active_listener_position, w3d, acoustic_volumes)`.

Viento en `_apply_voices`, tras la directividad:
```gdscript
		# Viento (Fase 10): aproximacion perceptual. En contra: menos nivel y menos agudos.
		if environment.has_wind() and instance.has_spatial_position:
			var dist: float = to_listener.length()
			if dist > environment.wind_min_distance_m and dist > 0.001:
				var headwind: float = maxf(0.0, -environment.wind_velocity.dot(to_listener / dist))
				if headwind > 0.0:
					volume_db -= minf(12.0, 0.3 * headwind)
					cutoff *= 1.0 - 0.5 * clampf(headwind / 20.0, 0.0, 1.0)
```
(`cutoff` debe leerse antes de esta línea: mover `var cutoff` arriba.)

- [ ] **Step 4: Correr** → verde.
- [ ] **Step 5: Commit** — `git commit -m "Fase 10: viento perceptual y oclusion parcial por volumen sobre el rayo existente"`

---

### Task 5: Descarte por categoría y superficie pintada

**Files:**
- Modify: `audio_event_manager.gd` (marcar `culled` antes del robo), `spatial_acoustics_manager.gd` (`surface_volumes`, prioridad cero en `detect_surface_at`)
- Test: `tests/test_acoustic_volume.gd` (`run_cull_async`, `run_surface_async`)

- [ ] **Step 1: Tests en rojo**

```gdscript
static func run_cull_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_volume_cull")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam := TestParityClass.make_listener_camera(tree)
	var def = AudioEventDefClass.new(&"CullVoice", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = &"Master"
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(0, 0, -3))
	for i in range(10):
		await tree.process_frame
	a.eq(int(inst.voice_state), int(inst.VoiceState.STATE_PHYSICAL), "sin volumen la voz es fisica")
	var env = EnvClass.new()
	env.cull_enabled = true
	env.cull_buses = [&"Master"]
	var bunker = make_box_volume(tree, Vector3.ZERO, Vector3(10, 10, 10), env)
	manager.register_acoustic_volume(bunker)
	for i in range(10):
		await tree.process_frame
	a.ok(inst.culled, "con el oyente dentro, la voz queda descartada")
	a.eq(int(inst.voice_state), int(inst.VoiceState.STATE_VIRTUAL), "y se virtualiza")
	a.eq(manager.occlusion_scheduler.raycasts_this_frame, 0, "sin gastar rayos")
	var t_before: float = inst.logical_playback_position
	await _settle(tree, 0.5)
	var advanced: float = inst.logical_playback_position - t_before
	if advanced < 0.0:
		advanced += def.stream_length
	a.approx(advanced, 0.5, "su tiempo logico sigue corriendo", 0.12)
	var before_exit: float = inst.logical_playback_position
	var t0: int = Time.get_ticks_msec()
	bunker.global_position = Vector3(100, 0, 0)
	for i in range(10):
		await tree.process_frame
	a.ok(not inst.culled, "al salir deja de estar descartada")
	a.eq(int(inst.voice_state), int(inst.VoiceState.STATE_PHYSICAL), "y vuelve a ser fisica")
	var expected: float = fmod(before_exit + float(Time.get_ticks_msec() - t0) / 1000.0, def.stream_length)
	var got: float = inst.logical_playback_position
	var diff: float = absf(got - expected)
	if diff > def.stream_length * 0.5:
		diff = def.stream_length - diff
	a.lt(diff, 0.1, "en la posicion del bucle que le toca (esperada %.2f, real %.2f)" % [expected, got])
	inst.stop()
	manager.unregister_acoustic_volume(bunker)
	tree.root.remove_child(bunker); bunker.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a

static func run_surface_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("acoustic_volume_surface")
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var street = load("res://addons/opendou/runtime/spatial/audio_room.gd").new(&"Calle", 1.0, 0.5, &"Asphalt")
	street.set_bounds(AABB(Vector3(-50, -5, -50), Vector3(100, 20, 100)))
	manager.spatial_acoustics.register_room(street)
	a.eq(String(manager.spatial_acoustics.detect_surface_at(Vector3(5, 0, 5))), "Asphalt", "sin volumen, el suelo de la sala")
	var env = EnvClass.new()
	env.surface_enabled = true
	env.surface_type = &"Water"
	env.surface_priority = 1
	var puddle = make_box_volume(tree, Vector3(5, 0, 5), Vector3(2, 1, 2), env)
	manager.register_acoustic_volume(puddle)
	a.eq(String(manager.spatial_acoustics.detect_surface_at(Vector3(5, 0, 5))), "Water", "dentro del charco, agua")
	a.eq(String(manager.spatial_acoustics.detect_surface_at(Vector3(8, 0, 5))), "Asphalt", "fuera, asfalto")
	var env2 = EnvClass.new()
	env2.surface_enabled = true
	env2.surface_type = &"Metal"
	env2.surface_priority = 5
	var grate = make_box_volume(tree, Vector3(5, 0, 5), Vector3(1, 1, 1), env2)
	manager.register_acoustic_volume(grate)
	a.eq(String(manager.spatial_acoustics.detect_surface_at(Vector3(5, 0, 5))), "Metal", "gana la prioridad mayor")
	for n in [puddle, grate]:
		manager.unregister_acoustic_volume(n)
		tree.root.remove_child(n); n.free()
	tree.root.remove_child(manager); manager.free()
	return a
```

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar**

Manager, en `_process` antes del robo de voces (paso 6), y solo si hay algo que descartar o hubo algo antes:
```gdscript
	# 5e. Descarte por entorno (Fase 10): peso cero en el robo, sin rayos.
	if not environment.culled_buses.is_empty() or _had_culled:
		_had_culled = not environment.culled_buses.is_empty()
		for instance in active_instances:
			var bus: StringName = instance.definition.target_bus if instance.definition != null else &""
			instance.culled = environment.is_culled(bus)
```
(`var _had_culled: bool = false`.) Además, en `voice_pool.resolve_voice_stealing`, las descartadas con peso 0 caen por debajo de `min_audibility_threshold` y se virtualizan; si el umbral es 0, añadir `if instance.culled` a la condición de virtualizar.

`spatial_acoustics_manager.gd`: `var surface_volumes: Array = []`; al principio de `detect_surface_at`:
```gdscript
	# Prioridad 0 (Fase 10): superficie pintada por un OpenDouAcousticVolume3D.
	var best_name: StringName = &""
	var best_prio: int = -2147483648
	for v in surface_volumes:
		if v == null or not is_instance_valid(v) or v.environment == null or not v.environment.surface_enabled:
			continue
		if v.environment.surface_priority > best_prio and v.contains_point(pos):
			best_prio = v.environment.surface_priority
			best_name = v.environment.surface_type
	if best_name != &"":
		return best_name
```
El manager ya asigna `spatial_acoustics.surface_volumes = acoustic_volumes` en `register_acoustic_volume` (Task 3); hacerlo también en `_init` tras crear `spatial_acoustics`.

- [ ] **Step 4: Correr** → verde.
- [ ] **Step 5: Commit** — `git commit -m "Fase 10: descarte por bus con el oyente dentro y superficie pintada con prioridad"`

---

### Task 6: Accesibilidad — mono, modo noche, indicador

**Files:**
- Modify: `runtime/spatial/spatial_settings.gd`, `resources/mix_chain.gd` (preset `NIGHT`), `audio_event_manager.gd` (`_apply_spatial_settings` llama al aplicador; ya no retorna temprano con backend godot para la accesibilidad)
- Create: `runtime/accessibility_applier.gd`, `nodes/opendou_sound_indicator.gd`
- Test: `tests/test_accessibility.gd`

**Interfaces:**
- Produces: `OpenDouSpatialSettings.mono`, `.night_mode`, `set_mono(bool)`, `set_night_mode(bool)`; `OpenDouAccessibilityApplier.apply(settings)`, `.MARK_MONO`, `is_mono_installed()`; `MixChain.Preset.NIGHT`; `OpenDouSoundIndicator.get_indicators() -> Array[Dictionary]`.

- [ ] **Step 1: Tests en rojo**

```gdscript
class_name TestAccessibility
extends RefCounted

## Fase 10: mono, modo noche e indicador de sonidos.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const SettingsClass = preload("res://addons/opendou/runtime/spatial/spatial_settings.gd")
const ApplierClass = preload("res://addons/opendou/runtime/accessibility_applier.gd")
const InstallerClass = preload("res://addons/opendou/runtime/mix_chain_installer.gd")
const MixChainClass = preload("res://addons/opendou/resources/mix_chain.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func run_settings() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("accessibility_settings")
	var path := "user://opendou_audio_access_test.cfg"
	var s = SettingsClass.new()
	a.eq(s.mono, false, "mono apagado por defecto")
	a.eq(s.night_mode, false, "modo noche apagado por defecto")
	var n: Array[int] = [0]
	s.changed.connect(func(): n[0] += 1)
	s.set_mono(true)
	s.set_night_mode(true)
	a.eq(n[0], 2, "cada ajuste emite changed")
	s.save_to_disk(path)
	var s2 = SettingsClass.new()
	s2.load_from_disk(path)
	a.ok(s2.mono and s2.night_mode, "los dos se recargan")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return a

static func run_mono_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("accessibility_mono")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var backend: String = "steam_audio" if BackendClass.native_available() else "godot"
	var manager = TestParityClass.make_manager(tree, backend)
	var cam := TestParityClass.make_listener_camera(tree)
	var def = AudioEventDefClass.new(&"MonoVoice", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(2, 0, 0))
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var stereo := await TestBinauralClass._capture(tree, probe)
	var ild_stereo: float = TestBinauralClass._ild_db(stereo.left, stereo.right)
	probe.teardown()
	manager.spatial_settings.set_mono(true)
	a.ok(ApplierClass.is_mono_installed(), "mono instala su efecto en Master")
	probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var mono := await TestBinauralClass._capture(tree, probe)
	var ild_mono: float = TestBinauralClass._ild_db(mono.left, mono.right)
	probe.teardown()
	manager.spatial_settings.set_mono(false)
	a.ok(not ApplierClass.is_mono_installed(), "apagado, lo quita")
	probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var back := await TestBinauralClass._capture(tree, probe)
	var ild_back: float = TestBinauralClass._ild_db(back.left, back.right)
	print("[OpenDou] mono (%s): ILD estereo %.1f dB, mono %.2f dB, de vuelta %.1f dB" % [backend, ild_stereo, ild_mono, ild_back])
	a.gt(ild_stereo, 3.0, "una fuente a la derecha tiene ILD")
	a.lt(absf(ild_mono), 0.5, "con mono, ILD cero")
	a.gt(ild_back, 3.0, "sin mono, vuelve")
	inst.stop()
	probe.teardown()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a

static func _peak_db_of_tone(tree: SceneTree, probe, level_db: float) -> float:
	var player := AudioStreamPlayer.new()
	player.stream = load("res://tests/test_emitter_physics.gd")._tone(1000.0, 2.0)
	player.volume_db = level_db
	player.bus = "Master"
	tree.root.add_child(player)
	player.play()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 400:
		await tree.process_frame
		probe.drain()
	var peak: float = await probe.measure_peak_db_over_frames(tree, 30)
	player.stop()
	tree.root.remove_child(player); player.free()
	await probe.await_silence(tree, 0.002, 30)
	return peak

static func run_night_mode_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("accessibility_night")
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	await tree.process_frame
	a.ok(InstallerClass.is_installed(), "la cadena GAME esta en Master")
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(&"Master", 2.0)
	var loud_game: float = await _peak_db_of_tone(tree, probe, -6.0)
	var quiet_game: float = await _peak_db_of_tone(tree, probe, -30.0)
	manager.spatial_settings.set_night_mode(true)
	var loud_night: float = await _peak_db_of_tone(tree, probe, -6.0)
	var quiet_night: float = await _peak_db_of_tone(tree, probe, -30.0)
	manager.spatial_settings.set_night_mode(false)
	var range_game: float = loud_game - quiet_game
	var range_night: float = loud_night - quiet_night
	print("[OpenDou] modo noche: rango GAME %.1f dB (%.1f / %.1f), NIGHT %.1f dB (%.1f / %.1f)" % [range_game, loud_game, quiet_game, range_night, loud_night, quiet_night])
	a.lt(range_night, range_game - 6.0, "el rango pico-valle baja al menos 6 dB")
	a.gt(quiet_night, quiet_game + 2.0, "y lo bajo sube")
	probe.teardown()
	tree.root.remove_child(manager); manager.free()
	return a

static func run_indicator_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("accessibility_indicator")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam := TestParityClass.make_listener_camera(tree)
	var def = AudioEventDefClass.new(&"Campana", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3(5, 0, 0))
	var indicator = load("res://addons/opendou/nodes/opendou_sound_indicator.gd").new()
	indicator.poll_interval = 0.01
	tree.root.add_child(indicator)
	for i in range(10):
		await tree.process_frame
	var items: Array = indicator.get_indicators()
	a.ok(items.size() >= 1, "hay un indicador")
	if items.size() >= 1:
		a.eq(String(items[0].event_name), "Campana", "con el nombre del evento")
		a.approx(items[0].angle_rad, PI / 2.0, "a la derecha del oyente (+pi/2)", 0.2)
	inst.stop()
	tree.root.remove_child(indicator); indicator.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a
```
Registrar las cuatro en la suite asíncrona (`run_settings` sin await).

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar**

`spatial_settings.gd`: `const ACCESS_SECTION: String = "accessibility"`, `var mono: bool = false`, `var night_mode: bool = false`, `set_mono`, `set_night_mode` (emiten `changed`), y en `load_from_disk`/`save_to_disk` leer y escribir `mono` y `night_mode` en esa sección.

`mix_chain.gd`: `enum Preset { GAME, CINEMATIC, MOBILE, NIGHT, CUSTOM }` (NIGHT antes de CUSTOM para no cambiar el valor de los tres primeros); en `_apply_preset`:
```gdscript
		Preset.NIGHT:
			# Modo noche: aplasta el rango dinamico y sube lo bajo. Accesibilidad (Fase 10).
			compressor_threshold_db = -24.0
			compressor_ratio = 6.0
			compressor_attack_us = 20.0
			compressor_release_ms = 250.0
			compressor_gain_db = 6.0
			limiter_ceiling_db = -0.3
			limiter_pre_gain_db = 0.0
			limiter_release_sec = 0.1
```

`runtime/accessibility_applier.gd`:
```gdscript
class_name OpenDouAccessibilityApplier
extends RefCounted

## Aplica los ajustes de accesibilidad del jugador sobre Master (Fase 10): mono con un
## StereoEnhance sin separacion al final de la cadena, y modo noche reinstalando la cadena
## de masterizacion con el preset NIGHT. Vale para los dos backends: es Godot.

const MARK_MONO: String = "OpenDou_Access_Mono"
const InstallerClass = preload("res://addons/opendou/runtime/mix_chain_installer.gd")
const MixChainClass = preload("res://addons/opendou/resources/mix_chain.gd")

static func apply(settings) -> void:
	_apply_mono(settings.mono)
	_apply_night(settings.night_mode)

static func is_mono_installed() -> bool:
	var idx: int = AudioServer.get_bus_index("Master")
	return idx >= 0 and _find(idx, MARK_MONO) != null

static func _apply_mono(on: bool) -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	var fx := _find(idx, MARK_MONO)
	if on and fx == null:
		var se := AudioEffectStereoEnhance.new()
		se.resource_name = MARK_MONO
		se.pan_pullout = 0.0
		se.surround = 0.0
		se.time_pullout_ms = 0.0
		AudioServer.add_bus_effect(idx, se)   # al final: despues del limitador
	elif not on and fx != null:
		for i in range(AudioServer.get_bus_effect_count(idx)):
			if AudioServer.get_bus_effect(idx, i) == fx:
				AudioServer.remove_bus_effect(idx, i)
				break

static func _apply_night(on: bool) -> void:
	if on:
		InstallerClass.install(MixChainClass.from_preset(MixChainClass.Preset.NIGHT), "Master")
	else:
		# Vuelve lo que diga el ajuste de proyecto; si no dice nada, se quita la cadena.
		if not InstallerClass.install_from_setting():
			InstallerClass.uninstall("Master")

static func _find(bus_idx: int, mark: String) -> AudioEffect:
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var e := AudioServer.get_bus_effect(bus_idx, i)
		if e != null and e.resource_name == mark:
			return e
	return null
```
Cuidado: `InstallerClass.install` sobre una cadena ya instalada solo actualiza parámetros (busca por marca), así que NIGHT ↔ GAME no acumula efectos. Si `pan_pullout = 0` no da ILD < 0.5 dB (riesgo del spec §9), la alternativa es quitar el `StereoEnhance` y, en el aplicador, poner el `output_mode` de los streams nativos en un modo mono nuevo más un `AudioEffectPanner`... que no hace mono. Medir primero.

Manager `_apply_spatial_settings`: mover la accesibilidad ANTES del `return` de backend: al principio, `if spatial_settings != null: AccessibilityApplierClass.apply(spatial_settings)`; y conectar `spatial_settings.changed` a `_apply_spatial_settings` si no lo está ya (comprobar cómo lo hace hoy el menú). Al salir del árbol (`_exit_tree`), `OpenDouAccessibilityApplier._apply_mono(false)` para no dejar el efecto entre tests.

`nodes/opendou_sound_indicator.gd`:
```gdscript
class_name OpenDouSoundIndicator
extends Control

## HUD de accesibilidad (Fase 10): un anillo con un punto por sonido audible, en la
## direccion relativa al frente del oyente. Reutiliza lo que el monitor audible ya calcula.

const AudibleVoiceMonitorClass = preload("res://addons/opendou/runtime/audible_voice_monitor.gd")

@export var max_items: int = 6
@export var min_db_threshold: float = -40.0
@export var ring_radius_px: float = 80.0
@export_range(0.01, 1.0, 0.01) var poll_interval: float = 0.1

var _indicators: Array[Dictionary] = []
var _timer: float = 0.0

func _process(delta: float) -> void:
	_timer += delta
	if _timer < poll_interval:
		return
	_timer = 0.0
	_refresh()
	queue_redraw()

## Devuelve [{event_name, angle_rad, level_db}], angulo 0 = delante, +pi/2 = derecha.
func get_indicators() -> Array[Dictionary]:
	return _indicators

func _refresh() -> void:
	_indicators.clear()
	var manager = get_node_or_null("/root/OpenDou")
	if manager == null:
		for m in AudibleVoiceMonitorClass._find_managers(get_tree()):
			manager = m
			break
	if manager == null:
		return
	var listener_pos: Vector3 = manager.active_listener_position
	var basis: Basis = manager.active_listener_basis
	for inst in manager.active_instances:
		if inst == null or not inst.has_spatial_position or not inst.is_playing():
			continue
		var level: float = inst.calculated_volume_db
		if level < min_db_threshold:
			continue
		var local: Vector3 = basis.inverse() * (inst.emitter_position - listener_pos)
		var angle: float = atan2(local.x, -local.z)
		_indicators.append({"event_name": inst.definition.event_name if inst.definition != null else &"", "angle_rad": angle, "level_db": level})
	_indicators.sort_custom(func(x, y): return x.level_db > y.level_db)
	if _indicators.size() > max_items:
		_indicators.resize(max_items)

func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_arc(center, ring_radius_px, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 1.5)
	for it in _indicators:
		var p: Vector2 = center + Vector2(sin(it.angle_rad), -cos(it.angle_rad)) * ring_radius_px
		var r: float = clampf(4.0 + (it.level_db + 40.0) * 0.2, 3.0, 12.0)
		draw_circle(p, r, Color(1.0, 0.85, 0.3, 0.9))
```
Comprobar el nombre real del campo de nombre en `AudioEventDef` (`event_name`).

- [ ] **Step 4: Correr** → verde.
- [ ] **Step 5: Commit** — `git commit -m "Fase 10: accesibilidad: mono, modo noche (preset NIGHT) e indicador de sonidos"`

---

### Task 7: La IA oye

**Files:**
- Modify: `audio_event_manager.gd` (`get_loudness_at`)
- Create: `nodes/opendou_ai_hearing_3d.gd`
- Test: `tests/test_ai_hearing.gd`

**Interfaces:**
- Produces: `AudioEventManager.get_loudness_at(position: Vector3, world_3d: World3D = null) -> Array[Dictionary]` con `{instance, event_name, loudness_db, from_position}`; `OpenDouAIHearing3D` con `threshold_db`, `poll_interval_sec`, `max_rays_per_poll`, señal `sound_heard(event_name, loudness_db, from_position)`, `get_last_heard()`.

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestAIHearing
extends RefCounted

## Fase 10: cuanto de un sonido llega a un punto cualquiera, por grafo de salas y por rayo.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const AudioPortalClass = preload("res://addons/opendou/runtime/spatial/audio_portal.gd")

static func _loudness_of(manager, name: StringName, pos: Vector3, w3d: World3D = null) -> float:
	for e in manager.get_loudness_at(pos, w3d):
		if e.event_name == name:
			return e.loudness_db
	return -INF

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("ai_hearing")
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.make_current()
	var def = AudioEventDefClass.new(&"Disparo", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	def.hdr_loudness_db = 0.0
	manager.register_event_definition(def)
	var inst = manager.post_event(def, null)
	inst.set_position(Vector3.ZERO)
	await tree.process_frame
	var guard := Vector3(0, 0, 20)
	var open_field: float = _loudness_of(manager, &"Disparo", guard)
	a.ok(open_field > -INF, "la consulta devuelve el evento")
	a.approx(open_field, -26.0, "a 20 m con modelo inverso (unit 1): -26 dB", 1.0)
	# Dos salas y un portal cerrado entre ellas.
	var ac = manager.spatial_acoustics
	var room_a = AudioRoomClass.new(&"A")
	room_a.set_bounds(AABB(Vector3(-5, -5, -5), Vector3(10, 10, 15)))     # z de -5 a 10
	ac.register_room(room_a)
	var room_b = AudioRoomClass.new(&"B")
	room_b.set_bounds(AABB(Vector3(-5, -5, 10), Vector3(10, 10, 15)))     # z de 10 a 25
	ac.register_room(room_b)
	var door = AudioPortalClass.new(&"Puerta", &"A", &"B", Vector3(0, 0, 10), 0.0)
	ac.register_portal(door)
	manager.room_path_dispatcher.clear_cache()
	var closed: float = _loudness_of(manager, &"Disparo", guard)
	door.open_factor = 1.0
	manager.room_path_dispatcher.clear_cache()
	var opened: float = _loudness_of(manager, &"Disparo", guard)
	print("[OpenDou] la IA oye: campo abierto %.1f dB, puerta cerrada %.1f dB, abierta %.1f dB" % [open_field, closed, opened])
	a.lt(closed, open_field - 10.0, "tras la puerta cerrada, al menos 10 dB menos")
	a.gt(opened, closed + 6.0, "al abrirla, sube al menos 6 dB")
	ac.unregister_portal(&"Puerta")
	ac.unregister_room(&"A")
	ac.unregister_room(&"B")
	manager.room_path_dispatcher.clear_cache()
	# Una pared fisica en la misma sala: el rayo la ve.
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, 0.5)
	cs.shape = box
	wall.add_child(cs)
	tree.root.add_child(wall)
	wall.global_position = Vector3(0, 0, 10)
	await tree.physics_frame
	await tree.physics_frame
	var w3d: World3D = tree.root.find_world_3d()
	var walled: float = _loudness_of(manager, &"Disparo", guard, w3d)
	a.lt(walled, open_field - 5.0, "tras una pared fisica, al menos 5 dB menos (medido %.1f)" % walled)
	wall.global_position = Vector3(100, 0, 0)
	await tree.physics_frame
	await tree.physics_frame
	a.approx(_loudness_of(manager, &"Disparo", guard, w3d), open_field, "sin pared, igual que en campo abierto", 0.5)
	# El nodo.
	var hearing = load("res://addons/opendou/nodes/opendou_ai_hearing_3d.gd").new()
	hearing.threshold_db = -30.0
	hearing.poll_interval_sec = 0.02
	tree.root.add_child(hearing)
	hearing.global_position = Vector3(0, 0, 3)
	var heard: Array = []
	hearing.sound_heard.connect(func(n, l, p): heard.append([n, l, p]))
	var far_def = AudioEventDefClass.new(&"Lejano", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	far_def.is_looping = true
	far_def.stream_length = 1.0
	manager.register_event_definition(far_def)
	var far = manager.post_event(far_def, null)
	far.max_distance = 1000.0
	far.set_position(Vector3(0, 0, 200))
	for i in range(30):
		await tree.process_frame
	a.eq(heard.size(), 1, "el guardia oye el disparo cercano una sola vez")
	if heard.size() >= 1:
		a.eq(String(heard[0][0]), "Disparo", "y sabe cual es")
		a.ok(heard[0][2].is_equal_approx(Vector3.ZERO), "y de donde viene")
	a.eq(hearing.get_last_heard().size(), 2, "la ultima consulta trae las dos voces")
	inst.stop()
	far.stop()
	tree.root.remove_child(hearing); hearing.free()
	tree.root.remove_child(wall); wall.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	return a
```

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar**

Manager:
```gdscript
## Cuanto de cada voz activa llega a `position` (Fase 10, la IA oye). Reutiliza el grafo de
## salas y la oclusion con otro destino; por eso cuesta un rayo por voz si hay world_3d.
## loudness_db = sonoridad de diseno + volumen calculado + distancia + camino.
func get_loudness_at(position: Vector3, world_3d: World3D = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var point_room: StringName = &""
	if spatial_acoustics != null:
		var r = spatial_acoustics.get_room_at_position(position)
		if r != null:
			point_room = r.room_name
	for instance in active_instances:
		if instance == null or instance.definition == null or not instance.has_spatial_position or not instance.is_playing():
			continue
		var d: float = instance.emitter_position.distance_to(position)
		var db: float = instance.definition.hdr_loudness_db + instance.calculated_volume_db - instance.occlusion_attenuation_db
		db += DistanceModelClass.attenuation_db(d, instance.attenuation_model, instance.unit_size, instance.attenuation_curve, instance.attenuation_curve_distance_m)
		var emitter_room: StringName = &""
		if spatial_acoustics != null:
			var er = spatial_acoustics.get_room_at_position(instance.emitter_position)
			if er != null:
				emitter_room = er.room_name
		if room_path_dispatcher != null and emitter_room != &"" and point_room != &"" and emitter_room != point_room:
			var chain: Dictionary = room_path_dispatcher.chain_for(emitter_room, point_room, instance.emitter_position, position)
			if bool(chain.sealed):
				db += room_path_dispatcher.max_attenuation_db
			else:
				var virtual_distance: float = instance.emitter_position.distance_to(chain.entry_pos) + float(chain.chain_length) + Vector3(chain.exit_pos).distance_to(position)
				db += room_path_dispatcher.attenuation_db_for(virtual_distance, chain.exit_pos, position)
				var min_open: float = 1.0
				for p in chain.portals:
					min_open = minf(min_open, p.open_factor)
				# Un portal cerrado no es un muro: se le da -26 dB (open_factor 0.05) para
				# que la IA oiga algo a traves de una puerta, como el jugador.
				db += 20.0 * (log(maxf(min_open, 0.05)) / log(10.0))
		elif world_3d != null and occlusion_scheduler != null:
			var query := PhysicsRayQueryParameters3D.create(instance.emitter_position, position, occlusion_scheduler.collision_mask)
			var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
			var ray_hits: Array[bool] = [not hit.is_empty()]
			db += occlusion_scheduler.occlusion_manager.evaluate_occlusion(instance.emitter_position, position, ray_hits).volume_attenuation_db
			for v in acoustic_volumes:
				if v != null and is_instance_valid(v) and v.environment != null and v.environment.occluder_enabled:
					db -= v.environment.occluder_db_per_m * v.segment_length_inside(instance.emitter_position, position)
		out.append({"instance": instance, "event_name": instance.definition.event_name, "loudness_db": db, "from_position": instance.emitter_position})
	return out
```
Se resta `instance.occlusion_attenuation_db` porque `calculated_volume_db` ya lleva la oclusión **hacia el oyente**, que aquí no aplica. Comprobar la firma real de `DistanceModelClass.attenuation_db` (Fase 9) y el nombre `event_name`.

`nodes/opendou_ai_hearing_3d.gd`:
```gdscript
class_name OpenDouAIHearing3D
extends Node3D

## Un oido para la IA (Fase 10): consulta la sonoridad de cada voz en su posicion y emite
## sound_heard una vez por voz cuando cruza el umbral hacia arriba.

signal sound_heard(event_name: StringName, loudness_db: float, from_position: Vector3)

@export var threshold_db: float = -30.0
@export_range(0.01, 2.0, 0.01) var poll_interval_sec: float = 0.1
## Tope de rayos por consulta: las voces mas alla se evaluan sin rayo.
@export var max_rays_per_poll: int = 8

var _timer: float = 0.0
var _heard_ids: Dictionary = {}   # instance_id -> true mientras siga por encima
var _last: Array[Dictionary] = []

func get_last_heard() -> Array[Dictionary]:
	return _last

func _process(delta: float) -> void:
	_timer += delta
	if _timer < poll_interval_sec:
		return
	_timer = 0.0
	var manager = get_node_or_null("/root/OpenDou")
	if manager == null:
		for m in preload("res://addons/opendou/runtime/audible_voice_monitor.gd")._find_managers(get_tree()):
			manager = m
			break
	if manager == null:
		return
	var w3d: World3D = get_world_3d() if max_rays_per_poll > 0 else null
	_last = manager.get_loudness_at(global_position, w3d)
	var alive: Dictionary = {}
	for e in _last:
		var id: int = e.instance.get_instance_id()
		alive[id] = true
		if e.loudness_db >= threshold_db:
			if not _heard_ids.has(id):
				_heard_ids[id] = true
				sound_heard.emit(e.event_name, e.loudness_db, e.from_position)
		else:
			_heard_ids.erase(id)
	for id in _heard_ids.keys():
		if not alive.has(id):
			_heard_ids.erase(id)
```
(`max_rays_per_poll` limita el rayo por voz en `get_loudness_at`: si hace falta, pasar `max_rays` como tercer parámetro opcional y contar; si el test no lo exige, documentar que hoy es «con rayos o sin rayos».)

- [ ] **Step 4: Correr** → verde.
- [ ] **Step 5: Commit** — `git commit -m "Fase 10: la IA oye: get_loudness_at por grafo de salas y rayo, y OpenDouAIHearing3D"`

---

### Task 8: Documentos, banco y cierre

**Files:**
- Modify: `docs/funcionalidades.md` (tabla de nodos: `OpenDouListener3D`, `OpenDouAcousticVolume3D`, `OpenDouSoundIndicator`, `OpenDouAIHearing3D`; recursos: `AcousticEnvironment`; sección 3 nativa: `configure_listener`; ideas: B3, B4, C2, C4, C5, A7 y H2.1/H2.4 ya viven en el plugin), `AGENTS.md` (observación 48: el oyente no es un cuerpo → pertenencia geométrica; trampas: `StereoEnhance` mono, filtro en Master antes de la cadena, `install` idempotente por marca, capture antes de un efecto no lo ve), `docs/tasks/current.md`, spec §10.

- [ ] **Step 1:** Editar los cuatro documentos.
- [ ] **Step 2:** Correr el banco tres veces (fila 200) con un manager sin volúmenes y anotar en el spec §10; añadir a `tools/bench_control_loop.gd` una segunda pasada con 8 volúmenes registrados (cajas de 10 m repartidas) si el coste con volúmenes no se mide de otro modo, y anotar ambos.
- [ ] **Step 3:** `./run_tests.sh` verde; commit: `git add docs AGENTS.md tools && git commit -m "Fase 10: documentos al dia; observacion 48; coste medido"`.

---

## Autorevisión

- **Cobertura del spec:** §3 → Tasks 1–2; §4.1–4.4 → Tasks 3–5; §5 → Task 6; §6 → Task 7; §7 repartido; §8 los cuatro archivos de test; §9 riesgos nombrados en Tasks 3 y 6; §10 en Task 8.
- **Consistencia de nombres:** `configure_listener`, `get_head_radius_m`, `get_speed_of_sound_mps` (1, 2, 3); `register_listener`/`unregister_listener`/`get_listener_node` (2, 3); `register_acoustic_volume`/`acoustic_volumes`/`environment` (3, 4, 5, 7); `contains_point`/`segment_length_inside` (3, 4, 5, 7); `culled` (4, 5); `speed_of_sound` en pool, canal y acústica (3); `set_mono`/`set_night_mode`/`is_mono_installed` (6); `get_loudness_at`/`sound_heard`/`get_last_heard` (7).
- **Sin marcadores de posición.** Los dos «comprobar la firma real» (`_tone`, `attenuation_db`, `event_name`) son verificaciones contra código de fases anteriores, no huecos del plan.
