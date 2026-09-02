# Fase 11 — Emisores nuevos y modos: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cuerpos que suenan al chocar, un personaje que habla con subtítulos y boca, un emisor que sigue el punto más cercano de una malla, la mezcla de un bus como objeto del mundo, volúmenes que disparan eventos, y la demo «El taller» que lo ejercita todo.

**Architecture:** Dos nodos nuevos (`OpenDouPhysicsImpact3D`, `OpenDouDialogueEmitter3D`) sobre el sistema de voces existente (post_event con caller, switches por entidad, RTPC locales, marcadores). Tres modos en nodos existentes: `MESH` en el emisor multiposición con un BVH propio, `BUS_CAPTURE` en el emisor 3D (captura → generador → fuente de la voz; el nativo expone el playback interno) y disparadores en el área de parámetros. La demo se compone en el `.tscn` y su script solo autora streams y reacciona.

**Tech Stack:** Godot 4.7.2 (GDScript), GDExtension C++17 (`native/`), suite headless `./run_tests.sh`.

**Spec:** `docs/superpowers/specs/2026-09-02-fase11-emisores-nuevos-y-modos-design.md`

## Global Constraints

- Rama `main`, un commit por tarea, mensaje en español sin acentos en la primera línea.
- Comentarios de código en español sin acentos; documentos con acentos.
- `./run_tests.sh` en verde antes de cada commit: `STATUS: PASSED`, cero `SCRIPT ERROR`, fugas ≤ `tests/leak_budget.txt` (540; hoy 533: si una tarea lo supera con objetos legítimos, subirlo con justificación en el commit).
- Tests con nodos en `run_async_suite(tree)`; diferencias de nivel en el bus de sonda (`TestBackendParity.BUS`), nunca en Master (compresor); `set_event_manager()`/`set_manager()` porque el autoload `/root/OpenDou` existe en la suite; esperar por muestras; cámara para que suene un 3D.
- Arreglos tipados: `.append()`, no literales.
- Compilar la extensión: `/Applications/CMake.app/Contents/bin/cmake --build native/build/ext --parallel`. Godot: `/Users/Daniel/Downloads/Godot.app/Contents/MacOS/Godot`.
- Escenas: nodos en el `.tscn`; el script solo autora streams y reacciona (`.agents/rules/04_scene_composition.md`).

---

## Estructura de archivos

| Archivo | Responsabilidad |
|---|---|
| `addons/opendou/nodes/opendou_physics_impact_3d.gd` | impactos físicos |
| `addons/opendou/nodes/opendou_dialogue_emitter_3d.gd` | diálogo con subtítulos, boca y visemas |
| `addons/opendou/runtime/spatial/triangle_bvh.gd` | `OpenDouTriangleBVH`: punto más cercano sobre triángulos |
| `addons/opendou/nodes/opendou_multi_position_emitter_3d.gd` | modo `MESH` |
| `addons/opendou/nodes/opendou_event_player_3d.gd` | modo `BUS_CAPTURE` |
| `addons/opendou/runtime/physical_voice_channel.gd` | `get_source_playback()` |
| `native/src/spatial_stream.{h,cpp}` | `OpenDouSpatialStreamPlayback::get_source_playback()` |
| `addons/opendou/nodes/opendou_parameter_area_3d.gd` | disparadores |
| `scenes/shared/vehicle_engine_events.gd` | plantilla de motor (blend por RPM, switch Load) |
| `scenes/demos/workshop/workshop_demo.{tscn,gd}` | la demo |
| tests | `test_physics_impact.gd`, `test_dialogue_emitter.gd`, `test_mesh_emitter.gd`, `test_world_bus.gd`, `test_area_trigger.gd`, `test_demo_scenes.gd::run_workshop_async`, `test_scene_guards.gd` |

---

### Task 1: `OpenDouPhysicsImpact3D`

**Files:**
- Create: `addons/opendou/nodes/opendou_physics_impact_3d.gd`
- Test: `tests/test_physics_impact.gd`; registrar en `tests/test_all.gd` (suite asíncrona)

**Interfaces:**
- Consumes: `AudioEventManager.post_event(event, caller)`, `sync_manager.set_switch(group, state, entity)`, `EventInstance.set_parameter(name, value, immediate)`, `set_position(p)`.
- Produces: nodo con exports del spec §3, `set_event_manager(m)`, señal `impact_posted(speed: float, mass: float, material: StringName, position: Vector3)`, `last_impact: Dictionary`.

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestPhysicsImpact
extends RefCounted

## Fase 11: un RigidBody3D con OpenDouPhysicsImpact3D suena solo al chocar, con la fuerza,
## la masa y el material del otro cuerpo. Fisica headless real.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const ImpactScript = preload("res://addons/opendou/nodes/opendou_physics_impact_3d.gd")

static func _floor(tree: SceneTree, surface: StringName) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	cs.shape = box
	body.add_child(cs)
	body.set_meta("surface_type", surface)
	tree.root.add_child(body)
	body.global_position = Vector3(0, -0.5, 0)
	return body

## Cuerpo de 1 kg a `height` m sobre el suelo, cayendo a `speed` m/s, con el nodo de impacto.
static func _drop(tree: SceneTree, manager, height: float, speed: float, threshold: float = 0.5) -> Array:
	var rb := RigidBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	cs.shape = box
	rb.add_child(cs)
	rb.mass = 1.0
	var impact = ImpactScript.new()
	impact.event_name = &"Clank"
	impact.min_speed_mps = threshold
	rb.add_child(impact)
	tree.root.add_child(rb)
	impact.set_event_manager(manager)
	rb.global_position = Vector3(0, 0.2 + height, 0)
	rb.linear_velocity = Vector3(0, -speed, 0)
	var hits: Array = []
	impact.impact_posted.connect(func(s, m, mat, p): hits.append({"speed": s, "mass": m, "material": mat, "position": p}))
	return [rb, hits]

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("physics_impact")
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.make_current()
	# Evento con switch de material: la rama Metal y la rama Concrete son tonos distintos.
	var sw = AudioSwitchContainerClass.new(&"Material", &"Concrete")
	sw.set_state_node(&"Concrete", AudioPhysicalNodeClass.new(load("res://tests/test_emitter_physics.gd")._tone(300.0, 0.3)))
	sw.set_state_node(&"Metal", AudioPhysicalNodeClass.new(load("res://tests/test_emitter_physics.gd")._tone(2000.0, 0.3)))
	var def = AudioEventDefClass.new(&"Clank")
	def.root_container = sw
	def.stream_length = 0.3
	manager.register_event_definition(def)
	var floor := _floor(tree, &"Metal")

	var slow = _drop(tree, manager, 0.02, 2.0)
	var fast = _drop(tree, manager, 0.02, 8.0)
	fast[0].global_position += Vector3(3, 0, 0)
	for i in range(30):
		await tree.physics_frame
	var slow_hits: Array = slow[1]
	var fast_hits: Array = fast[1]
	a.ok(slow_hits.size() >= 1, "el cuerpo lento choca y postea (%d)" % slow_hits.size())
	a.ok(fast_hits.size() >= 1, "el rapido tambien (%d)" % fast_hits.size())
	if slow_hits.size() >= 1 and fast_hits.size() >= 1:
		var ratio: float = fast_hits[0].speed / maxf(slow_hits[0].speed, 0.001)
		print("[OpenDou] impactos: lento %.2f m/s, rapido %.2f m/s (x%.2f), material %s, masa %.1f" % [slow_hits[0].speed, fast_hits[0].speed, ratio, str(fast_hits[0].material), fast_hits[0].mass])
		a.ok(ratio >= 3.2 and ratio <= 4.8, "ImpactForce del rapido entre 3.2 y 4.8 veces la del lento (x%.2f)" % ratio)
		a.eq(String(fast_hits[0].material), "Metal", "el material es el del otro cuerpo")
		a.approx(fast_hits[0].mass, 1.0, "y la masa la del propio", 0.01)
		a.eq(String(manager.sync_manager.get_switch(&"Material", fast[0].get_node("OpenDouPhysicsImpact3D") if fast[0].has_node("OpenDouPhysicsImpact3D") else fast[0].get_child(1))), "Metal", "el switch de material quedo en la entidad")
	# Bajo el umbral: nada.
	var soft = _drop(tree, manager, 0.02, 0.2, 0.5)
	soft[0].global_position += Vector3(-3, 0, 0)
	for i in range(30):
		await tree.physics_frame
	a.eq((soft[1] as Array).size(), 0, "a 0.2 m/s con umbral 0.5, ningun evento")
	for pair in [slow, fast, soft]:
		tree.root.remove_child(pair[0]); pair[0].free()
	tree.root.remove_child(floor); floor.free()
	manager.stop_all()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	return a
```
La gravedad añade poco en 2 cm; si el cociente sale fuera de 3.2–4.8 por el tramo de caída, subir la velocidad inicial de ambos manteniendo el 1:4 o aumentar el margen y anotarlo.

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar**

```gdscript
@tool
class_name OpenDouPhysicsImpact3D
extends Node3D

## Impactos fisicos sin un script por cuerpo (Fase 11). Hijo de un RigidBody3D: al chocar lee
## el material del otro cuerpo (surface_type), la velocidad normal relativa y la masa, y
## postea el evento con el switch de material y dos RTPC locales.

signal impact_posted(speed: float, mass: float, material: StringName, position: Vector3)

const AudibleVoiceMonitorClass = preload("res://addons/opendou/runtime/audible_voice_monitor.gd")
const SURFACE_KEYWORDS: Array[String] = ["metal", "water", "wood", "glass", "concrete", "tile", "foliage", "stone", "mud", "asphalt", "grass"]

@export var event_name: StringName = &""
@export var event_def: AudioEventDef = null
## Por debajo de esta velocidad normal relativa (m/s), nada.
@export_range(0.0, 50.0, 0.05) var min_speed_mps: float = 0.5
## Recarga entre impactos de este cuerpo.
@export_range(0.0, 5.0, 0.01) var cooldown_sec: float = 0.1
@export var material_switch_group: StringName = &"Material"
@export var force_rtpc: StringName = &"ImpactForce"
@export var mass_rtpc: StringName = &"ImpactMass"
@export var default_material: StringName = &"Concrete"

var last_impact: Dictionary = {}
var _manager: Node = null
var _body: RigidBody3D = null
var _last_time_ms: int = -1000000
var _warned: bool = false

func set_event_manager(manager: Node) -> void:
	_manager = manager

func _find_manager():
	if _manager != null and is_instance_valid(_manager):
		return _manager
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		return m
	var found = AudibleVoiceMonitorClass._find_managers(get_tree())
	return found[0] if not found.is_empty() else null

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_body = get_parent() as RigidBody3D
	if _body == null:
		push_warning("[OpenDou] %s tiene que ser hijo de un RigidBody3D" % name)
		return
	_body.contact_monitor = true
	_body.max_contacts_reported = maxi(_body.max_contacts_reported, 4)
	if not _body.body_entered.is_connected(_on_body_entered):
		_body.body_entered.connect(_on_body_entered)

## Material del otro cuerpo: metadatos, palabras clave del nombre, o el defecto.
static func material_of(body: Node, fallback: StringName) -> StringName:
	if body == null:
		return fallback
	if body.has_meta("surface_type"):
		return StringName(str(body.get_meta("surface_type")))
	var lower: String = body.name.to_lower()
	for k in SURFACE_KEYWORDS:
		if k in lower:
			return StringName(k.capitalize())
	return fallback

func _on_body_entered(other: Node) -> void:
	if _body == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_time_ms < int(cooldown_sec * 1000.0):
		return
	# Normal y punto de contacto: el estado directo del cuerpo los tiene durante el paso de
	# fisica en que se emite body_entered. Si no aparece el contacto, se aproxima.
	var normal: Vector3 = Vector3.ZERO
	var point: Vector3 = _body.global_position
	var state := PhysicsServer3D.body_get_direct_state(_body.get_rid())
	if state != null:
		for i in range(state.get_contact_count()):
			if state.get_contact_collider_object(i) == other:
				normal = state.get_contact_local_normal(i)
				point = state.get_contact_collider_position(i)
				break
	if normal.is_zero_approx():
		if other is Node3D:
			normal = (other.global_position - _body.global_position).normalized()
		if normal.is_zero_approx():
			normal = Vector3.UP
	var other_v: Vector3 = other.linear_velocity if other is RigidBody3D else Vector3.ZERO
	var speed: float = absf((_body.linear_velocity - other_v).dot(normal))
	if speed < min_speed_mps:
		return
	var manager = _find_manager()
	if manager == null:
		return
	_last_time_ms = now
	var material: StringName = material_of(other, default_material)
	if manager.sync_manager != null and not material_switch_group.is_empty():
		manager.sync_manager.set_switch(material_switch_group, material, self)
	var inst = null
	if event_def != null:
		inst = manager.post_event(event_def, self)
	elif not event_name.is_empty():
		inst = manager.post_event(event_name, self)
	if inst != null:
		inst.set_position(point)
		inst.set_parameter(force_rtpc, speed, true)
		inst.set_parameter(mass_rtpc, _body.mass, true)
	last_impact = {"speed": speed, "mass": _body.mass, "material": material, "position": point}
	impact_posted.emit(speed, _body.mass, material, point)
```
Al arrancar (`_on_body_entered` puede llegar antes de que el cuerpo haya salido del suelo si nace tocándolo): el test lo coloca 2 cm arriba.

- [ ] **Step 4: Correr** → verde. Si `body_entered` llega pero `get_contact_count()` es 0 en headless, el nodo cae a la aproximación (dirección al otro cuerpo) y el test sigue valiendo: anotarlo en el spec §12.
- [ ] **Step 5: Commit** — `git add addons/opendou/nodes/opendou_physics_impact_3d.gd tests/test_physics_impact.gd tests/test_all.gd && git commit -m "Fase 11: OpenDouPhysicsImpact3D: el cuerpo suena solo al chocar, con fuerza, masa y material"`

---

### Task 2: `OpenDouDialogueEmitter3D`

**Files:**
- Create: `addons/opendou/nodes/opendou_dialogue_emitter_3d.gd`
- Test: `tests/test_dialogue_emitter.gd`

**Interfaces:**
- Consumes: `AudioDialogueTable.get_stream(key, lang, fallback)`, `OpenDouWavDecoder.to_mono_floats(wav)`, `manager.mix.ducking.add_rule/set_bus_active`, `EventInstance.marker_reached`, `logical_playback_position`, `is_playing()`.
- Produces: `speak(key) -> EventInstance`, `stop_speaking(fade)`, `is_speaking()`, `mouth_amplitude`, `current_viseme`, señales `line_started`, `line_finished`, `subtitle_changed`, `viseme_changed`; `set_event_manager(m)`.

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestDialogueEmitter
extends RefCounted

## Fase 11: una linea con subtitulo, boca (envolvente del WAV), visemas autorados y ducking.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const AudioMarkerClass = preload("res://addons/opendou/resources/audio_marker.gd")
const TableClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_table.gd")
const EmitterScript = preload("res://addons/opendou/nodes/opendou_dialogue_emitter_3d.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

## Tono de 1 s: fuerte la primera mitad, silencio la segunda.
static func _line_wav() -> AudioStreamWAV:
	var rate: int = int(AudioServer.get_mix_rate())
	var bytes := PackedByteArray()
	bytes.resize(rate * 2)
	for i in range(rate):
		var amp: float = 0.5 if i < rate / 2 else 0.0
		bytes.encode_s16(i * 2, int(sin(TAU * 220.0 * i / rate) * amp * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav

static func _wait(tree: SceneTree, ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await tree.process_frame

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("dialogue_emitter")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var manager = TestParityClass.make_manager(tree, "godot")
	var cam := TestParityClass.make_listener_camera(tree)
	for b in [&"Voice", &"Music"]:
		if AudioServer.get_bus_index(String(b)) < 0:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, String(b))
			AudioServer.set_bus_send(idx, "Master")
	var music_base: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	var table = TableClass.new()
	table.add_entry(&"greet", "es", _line_wav())
	var em = EmitterScript.new()
	em.dialogue_table = table
	em.language = "es"
	em.subtitles = {&"greet": {"es": "Buenas, ¿que le pasa al coche?"}}
	em.duck_bus = &"Music"
	em.duck_db = -12.0
	em.duck_attack_sec = 0.02
	em.duck_release_sec = 0.05
	var mk = AudioMarkerClass.new()
	mk.name = &"viseme:AA"
	mk.time_sec = 0.2
	em.markers.append(mk)
	tree.root.add_child(em)
	em.set_event_manager(manager)
	em.global_position = Vector3(0, 0, -2)
	var subtitles: Array = []
	var visemes: Array = []
	var finished: Array = []
	em.subtitle_changed.connect(func(t): subtitles.append(t))
	em.viseme_changed.connect(func(v): visemes.append(v))
	em.line_finished.connect(func(k): finished.append(k))
	var inst = em.speak(&"greet")
	a.ok(inst != null, "speak devuelve la instancia")
	a.ok(em.is_speaking(), "y el emisor habla")
	a.eq(subtitles.size(), 1, "el subtitulo llega al empezar")
	if subtitles.size() == 1:
		a.eq(String(subtitles[0]), "Buenas, ¿que le pasa al coche?", "con su texto")
	await _wait(tree, 250)
	var mouth_open: float = em.mouth_amplitude
	var music_ducked: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	a.gt(mouth_open, 0.5, "a 0.25 s la boca esta abierta (%.2f)" % mouth_open)
	a.lt(music_ducked, music_base - 10.0, "la musica baja al menos 10 dB durante la linea (%.1f)" % music_ducked)
	a.eq(visemes.size(), 1, "el visema autorado a 0.2 s llego")
	a.eq(String(em.current_viseme), "AA", "y queda como visema actual")
	await _wait(tree, 500)
	var mouth_closed: float = em.mouth_amplitude
	a.lt(mouth_closed, 0.05, "a 0.75 s la boca esta cerrada (%.2f)" % mouth_closed)
	await _wait(tree, 700)
	a.ok(not em.is_speaking(), "la linea termino")
	a.eq(finished.size(), 1, "y lo dijo")
	a.approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), music_base, "la musica vuelve", 0.5)
	tree.root.remove_child(em); em.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a
```
Comprobar antes que `manager.mix.ducking` es la `AudioDuckingMatrix` que `OpenDouMixBusApplier.apply` lee cada cuadro y que `managed_buses()` incluye los buses nombrados en reglas (si no, añadir el bus del ducking al conjunto gestionado; ver `mix_bus_applier.gd`).

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar**

```gdscript
@tool
class_name OpenDouDialogueEmitter3D
extends Node3D

## Emisor de dialogo (Fase 11): una linea por idioma desde una AudioDialogueTable, subtitulo,
## ducking absoluto sobre un bus, boca por la envolvente del WAV y visemas AUTORADOS por
## marcadores (nombre "viseme:X"). Godot no trae fonemas: aqui no hay visemas automaticos.

signal line_started(key: StringName)
signal line_finished(key: StringName)
signal subtitle_changed(text: String)
signal viseme_changed(viseme: StringName)

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")
const AudibleVoiceMonitorClass = preload("res://addons/opendou/runtime/audible_voice_monitor.gd")

@export var dialogue_table: AudioDialogueTable = null
## Vacio = el idioma del AudioDialogueManager del manager, si existe; si no, "en".
@export var language: String = "en"
@export var fallback_language: String = "en"
## key -> {lang -> texto}. La tabla de dialogo solo guarda streams.
@export var subtitles: Dictionary = {}
@export var bus_category: StringName = &"Voice"
@export_group("Ducking")
@export var duck_bus: StringName = &"Music"
@export_range(-60.0, 0.0, 0.5) var duck_db: float = -12.0
@export_range(0.0, 2.0, 0.01) var duck_attack_sec: float = 0.05
@export_range(0.0, 5.0, 0.01) var duck_release_sec: float = 0.4
@export_group("Boca y visemas")
@export_range(2, 100, 1) var mouth_window_ms: int = 10
## Visemas autorados: marcadores con nombre "viseme:<nombre>".
@export var markers: Array[AudioMarker] = []

var mouth_amplitude: float = 0.0
var current_viseme: StringName = &""

var _manager: Node = null
var _instance = null
var _key: StringName = &""
var _envelope: PackedFloat32Array = PackedFloat32Array()
var _def: AudioEventDef = null
var _warned_no_wav: bool = false

func set_event_manager(manager: Node) -> void:
	_manager = manager

func _find_manager():
	if _manager != null and is_instance_valid(_manager):
		return _manager
	var m = get_node_or_null("/root/OpenDou")
	if m != null:
		return m
	var found = AudibleVoiceMonitorClass._find_managers(get_tree())
	return found[0] if not found.is_empty() else null

func is_speaking() -> bool:
	return _instance != null and _instance.is_playing()

## Envolvente RMS por ventana, normalizada al pico. Vacia si el stream no es un WAV.
static func envelope_of(stream: AudioStream, window_ms: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if not (stream is AudioStreamWAV):
		return out
	var samples: PackedFloat32Array = WavDecoderClass.to_mono_floats(stream)
	var win: int = maxi(1, int(float(stream.mix_rate) * float(window_ms) / 1000.0))
	var peak: float = 0.0
	var i: int = 0
	while i < samples.size():
		var acc: float = 0.0
		var n: int = mini(win, samples.size() - i)
		for k in range(n):
			acc += samples[i + k] * samples[i + k]
		var rms: float = sqrt(acc / float(n))
		out.append(rms)
		peak = maxf(peak, rms)
		i += win
	if peak > 0.0:
		for k in range(out.size()):
			out[k] /= peak
	return out

func speak(key: StringName) -> EventInstance:
	var manager = _find_manager()
	if manager == null or dialogue_table == null:
		return null
	var lang: String = language
	if lang.is_empty():
		lang = manager.dialogue_manager.current_language if "dialogue_manager" in manager and manager.dialogue_manager != null else "en"
	var stream = dialogue_table.get_stream(key, lang, fallback_language)
	if not (stream is AudioStream):
		push_warning("[OpenDou] %s: la clave %s no tiene stream en %s" % [name, key, lang])
		return null
	stop_speaking(0.0)
	_key = key
	_def = AudioEventDefClass.new(StringName("Dialogue_%s" % key), stream)
	_def.target_bus = bus_category
	_def.is_looping = false
	_def.stream_length = float(stream.get_length())
	for mk in markers:
		_def.markers.append(mk)
	_envelope = envelope_of(stream, mouth_window_ms)
	if _envelope.is_empty() and not _warned_no_wav:
		_warned_no_wav = true
		push_warning("[OpenDou] %s: el stream no es un WAV, la boca queda en 0" % name)
	_instance = manager.post_event(_def, self)
	if _instance == null:
		return null
	_instance.set_position(global_position if is_inside_tree() else position)
	_instance.marker_reached.connect(_on_marker)
	_apply_ducking(manager, true)
	current_viseme = &""
	line_started.emit(key)
	var text: String = ""
	if subtitles.has(key):
		var by_lang: Dictionary = subtitles[key]
		text = str(by_lang.get(lang, by_lang.get(fallback_language, "")))
	subtitle_changed.emit(text)
	return _instance

func stop_speaking(fade_sec: float = 0.05) -> void:
	if _instance != null:
		if _instance.is_playing():
			_instance.stop(fade_sec)
		_finish()

func _on_marker(marker_name: StringName) -> void:
	var s: String = String(marker_name)
	if s.begins_with("viseme:"):
		current_viseme = StringName(s.substr(7))
		viseme_changed.emit(current_viseme)

func _apply_ducking(manager, on: bool) -> void:
	if manager == null or manager.mix == null or manager.mix.ducking == null or duck_bus.is_empty():
		return
	var d = manager.mix.ducking
	if on:
		d.add_rule(bus_category, duck_bus, duck_db, duck_attack_sec, duck_release_sec)
	d.set_bus_active(bus_category, on)

func _finish() -> void:
	var manager = _find_manager()
	_apply_ducking(manager, false)
	if _instance != null and _instance.marker_reached.is_connected(_on_marker):
		_instance.marker_reached.disconnect(_on_marker)
	_instance = null
	mouth_amplitude = 0.0
	current_viseme = &""
	line_finished.emit(_key)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _instance == null:
		return
	if not _instance.is_playing():
		_finish()
		return
	if is_inside_tree():
		_instance.set_position(global_position)
	if _envelope.is_empty():
		mouth_amplitude = 0.0
		return
	var idx: int = int(_instance.logical_playback_position * 1000.0 / float(mouth_window_ms))
	mouth_amplitude = _envelope[clampi(idx, 0, _envelope.size() - 1)]

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		stop_speaking(0.0)
```

- [ ] **Step 4: Correr** → verde. Si el ducking no llega al `AudioServer` en 250 ms, revisar que `OpenDouMixBusApplier.managed_buses()` incluya `Music` (los buses de las reglas de ducking) y que el bus exista antes de `add_rule`.
- [ ] **Step 5: Commit** — `git commit -m "Fase 11: OpenDouDialogueEmitter3D: linea por idioma, subtitulo, ducking absoluto, boca por envolvente y visemas autorados"`

---

### Task 3: Emisor de malla (`OpenDouTriangleBVH` + modo `MESH`)

**Files:**
- Create: `addons/opendou/runtime/spatial/triangle_bvh.gd`
- Modify: `addons/opendou/nodes/opendou_multi_position_emitter_3d.gd`
- Test: `tests/test_mesh_emitter.gd`

**Interfaces:**
- Produces: `OpenDouTriangleBVH.build(faces: PackedVector3Array)`, `closest_point(p: Vector3) -> Vector3`, `triangle_count() -> int`, `static closest_point_on_triangle(p, a, b, c) -> Vector3`; en el emisor: `source_mode` (`SourceMode.POINTS = 0, MESH = 1`), `mesh_path: NodePath`, `mesh_hysteresis_m`, `rebuild_mesh()`, `get_mesh_closest_point(p) -> Vector3`.

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestMeshEmitter
extends RefCounted

## Fase 11: el punto mas cercano SOBRE los triangulos de una malla, con BVH, contra la fuerza
## bruta; y el emisor multiposicion en modo MESH lo sigue.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const BVHClass = preload("res://addons/opendou/runtime/spatial/triangle_bvh.gd")
const EmitterScript = preload("res://addons/opendou/nodes/opendou_multi_position_emitter_3d.gd")

static func _plane_faces() -> PackedVector3Array:
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	pm.subdivide_width = 21
	pm.subdivide_depth = 21   # 22 x 22 celdas x 2 = 968 triangulos
	return pm.get_faces()

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("mesh_emitter")
	var faces := _plane_faces()
	var bvh = BVHClass.new()
	bvh.build(faces)
	a.ok(bvh.triangle_count() >= 900, "el plano tiene ~1000 triangulos (%d)" % bvh.triangle_count())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var worst: float = 0.0
	var times: Array = []
	for i in range(20):
		var p := Vector3(rng.randf_range(-30, 30), rng.randf_range(0.5, 6.0), rng.randf_range(-30, 30))
		var t0: int = Time.get_ticks_usec()
		var q: Vector3 = bvh.closest_point(p)
		times.append(Time.get_ticks_usec() - t0)
		# Fuerza bruta.
		var best := Vector3.ZERO
		var best_d: float = INF
		for t in range(0, faces.size(), 3):
			var c: Vector3 = BVHClass.closest_point_on_triangle(p, faces[t], faces[t + 1], faces[t + 2])
			var d: float = c.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = c
		worst = maxf(worst, absf(sqrt(best_d) - q.distance_to(p)))
	times.sort()
	print("[OpenDou] BVH de %d triangulos: peor error %.4f m, consulta mediana %d us" % [bvh.triangle_count(), worst, times[times.size() / 2]])
	a.lt(worst, 0.01, "la distancia al punto del BVH coincide con la fuerza bruta a 1 cm")
	a.lt(float(times[times.size() / 2]), 150.0, "la consulta mediana baja de 150 us")

	# El emisor en modo MESH.
	var mesh_node := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	pm.subdivide_width = 21
	pm.subdivide_depth = 21
	mesh_node.mesh = pm
	tree.root.add_child(mesh_node)
	mesh_node.global_position = Vector3(0, 0, 0)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(7.3, 2.0, -4.1)
	var em = EmitterScript.new()
	em.source_mode = EmitterScript.SourceMode.MESH
	em.smooth_position_lag = 0.0
	tree.root.add_child(em)
	em.mesh_path = em.get_path_to(mesh_node)
	em.rebuild_mesh()
	for i in range(5):
		await tree.process_frame
	a.ok(em.global_position.is_equal_approx(Vector3(7.3, 0.0, -4.1)), "el emisor se pone en el punto del plano bajo el oyente (%s)" % str(em.global_position))
	cam.global_position = Vector3(7.4, 2.0, -4.1)   # 10 cm: dentro de la histeresis
	for i in range(3):
		await tree.process_frame
	a.ok(em.global_position.is_equal_approx(Vector3(7.3, 0.0, -4.1)), "10 cm no lo mueven (histeresis 0.25 m)")
	cam.global_position = Vector3(12.0, 2.0, -4.1)
	for i in range(3):
		await tree.process_frame
	a.ok(em.global_position.is_equal_approx(Vector3(12.0, 0.0, -4.1)), "5 m si")
	tree.root.remove_child(em); em.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(mesh_node); mesh_node.free()
	return a
```

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar**

`runtime/spatial/triangle_bvh.gd`:
```gdscript
class_name OpenDouTriangleBVH
extends RefCounted

## Arbol de cajas por mediana sobre triangulos (Fase 11): punto mas cercano sobre la
## superficie de una malla, con poda por distancia a la caja. Hojas de hasta 8 triangulos.

const LEAF_SIZE: int = 8

var _faces: PackedVector3Array = PackedVector3Array()
var _centroids: PackedVector3Array = PackedVector3Array()
var _order: PackedInt32Array = PackedInt32Array()   # indices de triangulo, reordenados
var _node_aabb: Array = []            # AABB por nodo
var _node_left: PackedInt32Array = PackedInt32Array()
var _node_right: PackedInt32Array = PackedInt32Array()
var _node_start: PackedInt32Array = PackedInt32Array()
var _node_count: PackedInt32Array = PackedInt32Array()

func triangle_count() -> int:
	return _faces.size() / 3

func build(faces: PackedVector3Array) -> void:
	_faces = faces
	var n: int = faces.size() / 3
	_centroids.resize(n)
	_order.resize(n)
	for i in range(n):
		_centroids[i] = (faces[3 * i] + faces[3 * i + 1] + faces[3 * i + 2]) / 3.0
		_order[i] = i
	_node_aabb.clear()
	_node_left = PackedInt32Array()
	_node_right = PackedInt32Array()
	_node_start = PackedInt32Array()
	_node_count = PackedInt32Array()
	if n > 0:
		_build_node(0, n)

func _tri_aabb(t: int) -> AABB:
	var b := AABB(_faces[3 * t], Vector3.ZERO)
	b = b.expand(_faces[3 * t + 1])
	return b.expand(_faces[3 * t + 2])

## Construye el nodo del rango [start, start+count) de _order y devuelve su indice.
func _build_node(start: int, count: int) -> int:
	var box: AABB = _tri_aabb(_order[start])
	for i in range(start + 1, start + count):
		box = box.merge(_tri_aabb(_order[i]))
	var idx: int = _node_aabb.size()
	_node_aabb.append(box)
	_node_left.append(-1)
	_node_right.append(-1)
	_node_start.append(start)
	_node_count.append(count)
	if count <= LEAF_SIZE:
		return idx
	# Eje mas largo y mediana de centroides: pares [coordenada, triangulo] con sort() nativo.
	var axis: int = box.get_longest_axis_index()
	var pairs: Array = []
	pairs.resize(count)
	for i in range(count):
		var t: int = _order[start + i]
		pairs[i] = [_centroids[t][axis], t]
	pairs.sort()
	for i in range(count):
		_order[start + i] = pairs[i][1]
	var half: int = count / 2
	var left: int = _build_node(start, half)
	var right: int = _build_node(start + half, count - half)
	_node_left[idx] = left
	_node_right[idx] = right
	return idx

## Punto mas cercano de la superficie a p.
func closest_point(p: Vector3) -> Vector3:
	if _node_aabb.is_empty():
		return p
	var best: Array = [INF, p]
	_query(0, p, best)
	return best[1]

func _query(node: int, p: Vector3, best: Array) -> void:
	var box: AABB = _node_aabb[node]
	# Distancia al punto mas cercano de la caja: si ya es peor que lo mejor, se poda.
	var clamped := Vector3(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y), clampf(p.z, box.position.z, box.end.z))
	if clamped.distance_squared_to(p) >= best[0]:
		return
	if _node_left[node] < 0:
		var start: int = _node_start[node]
		for i in range(start, start + _node_count[node]):
			var t: int = _order[i]
			var c: Vector3 = closest_point_on_triangle(p, _faces[3 * t], _faces[3 * t + 1], _faces[3 * t + 2])
			var d: float = c.distance_squared_to(p)
			if d < best[0]:
				best[0] = d
				best[1] = c
		return
	# Primero el hijo mas cercano: poda mas.
	var l: int = _node_left[node]
	var r: int = _node_right[node]
	var dl: float = _box_dist2(_node_aabb[l], p)
	var dr: float = _box_dist2(_node_aabb[r], p)
	if dl <= dr:
		_query(l, p, best)
		_query(r, p, best)
	else:
		_query(r, p, best)
		_query(l, p, best)

static func _box_dist2(box: AABB, p: Vector3) -> float:
	var c := Vector3(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y), clampf(p.z, box.position.z, box.end.z))
	return c.distance_squared_to(p)

## Punto mas cercano a p sobre el triangulo abc (Ericson, Real-Time Collision Detection 5.1.5).
static func closest_point_on_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var ap: Vector3 = p - a
	var d1: float = ab.dot(ap)
	var d2: float = ac.dot(ap)
	if d1 <= 0.0 and d2 <= 0.0:
		return a
	var bp: Vector3 = p - b
	var d3: float = ab.dot(bp)
	var d4: float = ac.dot(bp)
	if d3 >= 0.0 and d4 <= d3:
		return b
	var vc: float = d1 * d4 - d3 * d2
	if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
		return a + ab * (d1 / (d1 - d3))
	var cp: Vector3 = p - c
	var d5: float = ab.dot(cp)
	var d6: float = ac.dot(cp)
	if d6 >= 0.0 and d5 <= d6:
		return c
	var vb: float = d5 * d2 - d1 * d6
	if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
		return a + ac * (d2 / (d2 - d6))
	var va: float = d3 * d6 - d5 * d4
	if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denom: float = 1.0 / (va + vb + vc)
	return a + ab * (vb * denom) + ac * (vc * denom)
```

Emisor multiposición: añadir tras `rendering_mode`:
```gdscript
enum SourceMode { POINTS, MESH }
@export_group("Mesh Source")
## MESH: el punto mas cercano SOBRE los triangulos del MeshInstance3D (BVH), no un vertice.
@export var source_mode: SourceMode = SourceMode.POINTS
@export_node_path("MeshInstance3D") var mesh_path: NodePath = NodePath("")
## El origen no se mueve si el nuevo punto esta mas cerca que esto (evita el temblor).
@export_range(0.0, 5.0, 0.01) var mesh_hysteresis_m: float = 0.25

var _bvh = null
var _mesh_xform: Transform3D = Transform3D.IDENTITY
var _mesh_point: Vector3 = Vector3.ZERO
var _mesh_point_valid: bool = false

## Reconstruye el BVH desde el MeshInstance3D (en espacio mundo, con su transformacion actual).
func rebuild_mesh() -> void:
	_bvh = null
	_mesh_point_valid = false
	if mesh_path.is_empty():
		return
	var mi = get_node_or_null(mesh_path) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var faces: PackedVector3Array = mi.mesh.get_faces()
	var world := PackedVector3Array()
	world.resize(faces.size())
	var xf: Transform3D = mi.global_transform if mi.is_inside_tree() else mi.transform
	for i in range(faces.size()):
		world[i] = xf * faces[i]
	_bvh = preload("res://addons/opendou/runtime/spatial/triangle_bvh.gd").new()
	_bvh.build(world)

func get_mesh_closest_point(global_target: Vector3) -> Vector3:
	if _bvh == null:
		return TransformUtilsClass.world_position_of(self)
	var q: Vector3 = _bvh.closest_point(global_target)
	if _mesh_point_valid and q.distance_to(_mesh_point) < mesh_hysteresis_m:
		return _mesh_point
	_mesh_point = q
	_mesh_point_valid = true
	return q
```
En `_ready`: `if source_mode == SourceMode.MESH: rebuild_mesh()`. En `_process`, dentro del `match rendering_mode`, antes: `if source_mode == SourceMode.MESH: target_render_pos = get_mesh_closest_point(listener_pos)` y saltar el `match` (envolver el `match` en `else`). El `should_cull_at_distance` y `is_position_inside_emission_volume` usan `emission_points`; en `MESH` con la lista por defecto (`[Vector3.ZERO]`) siguen funcionando respecto al origen del nodo: dejar así y anotar.

- [ ] **Step 4: Correr** → verde.
- [ ] **Step 5: Commit** — `git commit -m "Fase 11: emisor de malla como modo: BVH de triangulos con histeresis en OpenDouMultiPositionEmitter3D"`

---

### Task 4: Altavoz de mundo (`BUS_CAPTURE`)

**Files:**
- Modify: `native/src/spatial_stream.h` (`OpenDouSpatialStreamPlayback`: `_bind_methods`, `get_source_playback`), `addons/opendou/runtime/physical_voice_channel.gd`, `addons/opendou/nodes/opendou_event_player_3d.gd`
- Test: `tests/test_world_bus.gd`

**Interfaces:**
- Produces: `OpenDouSpatialStreamPlayback.get_source_playback() -> AudioStreamPlayback`; `PhysicalVoiceChannel.get_source_playback() -> AudioStreamPlayback`; en el emisor 3D: `enum Source { EVENT, BUS_CAPTURE }`, `source`, `capture_bus`, `MARK_CAPTURE = "OpenDou_WorldBus_Capture"`.

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestWorldBus
extends RefCounted

## Fase 11: la mezcla de un bus como objeto del mundo. Un tono que suena solo en `Radio`
## aparece en el bus del emisor con la ILD de su posicion; la salida directa esta callada.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const TestParityClass = preload("res://tests/test_backend_parity.gd")
const EmitterScript = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")
const BackendClass = preload("res://addons/opendou/runtime/spatial/spatial_backend.gd")

static func _bus(name: String, send: String = "Master") -> void:
	if AudioServer.get_bus_index(name) < 0:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, send)

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("world_bus")
	var previous_backend = ProjectSettings.get_setting(BackendClass.SETTING, "auto")
	var backend: String = "steam_audio" if BackendClass.native_available() else "godot"
	var manager = TestParityClass.make_manager(tree, backend)
	var cam := TestParityClass.make_listener_camera(tree)
	_bus("Radio")
	TestParityClass.ensure_bus()
	# El tono vive solo en Radio.
	var radio := AudioStreamPlayer.new()
	radio.stream = TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate()))
	radio.bus = "Radio"
	radio.volume_db = -6.0
	tree.root.add_child(radio)
	radio.play()
	var speaker = EmitterScript.new()
	speaker.source = EmitterScript.Source.BUS_CAPTURE
	speaker.capture_bus = &"Radio"
	speaker.bus_category = "Master"
	tree.root.add_child(speaker)
	speaker.set_event_manager(manager)
	speaker.global_position = Vector3(2, 0, 0)
	speaker.play_event()
	# La voz del altavoz sale por el bus de sonda para medirla sin el compresor de Master.
	if speaker.active_instance != null:
		speaker.active_instance.definition.target_bus = TestParityClass.BUS
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(TestParityClass.BUS, 2.0)
	for i in range(30):
		await tree.process_frame
		probe.drain()
	var right := await TestBinauralClass._capture(tree, probe)
	var rms_right: float = TestBinauralClass._rms_db(right)
	var ild_right: float = TestBinauralClass._ild_db(right.left, right.right)
	speaker.global_position = Vector3(-2, 0, 0)
	for i in range(20):
		await tree.process_frame
		probe.drain()
	var left := await TestBinauralClass._capture(tree, probe)
	var ild_left: float = TestBinauralClass._ild_db(left.left, left.right)
	print("[OpenDou] altavoz de mundo (%s): RMS %.1f dBFS, ILD derecha %.1f dB, izquierda %.1f dB; bus Radio a %.0f dB" % [backend, rms_right, ild_right, ild_left, AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Radio"))])
	a.gt(rms_right, -30.0, "lo que suena en Radio llega al bus del emisor")
	a.gt(ild_right, 3.0, "a la derecha, ILD positiva")
	a.lt(ild_left, -3.0, "a la izquierda, negativa")
	a.approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Radio")), -80.0, "la salida directa del bus Radio esta callada", 0.1)
	speaker.stop_event()
	await tree.process_frame
	a.approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Radio")), 0.0, "al parar, el bus Radio recupera su volumen", 0.1)
	radio.stop()
	probe.teardown()
	tree.root.remove_child(radio); radio.free()
	tree.root.remove_child(speaker); speaker.free()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	ProjectSettings.set_setting(BackendClass.SETTING, previous_backend)
	return a
```
Si cambiar `target_bus` de la definición tras `play_event` no mueve la voz de bus (el canal lee el bus al arrancar), poner `speaker.bus_category = String(TestParityClass.BUS)` antes de `play_event` (el `bus_category` es un `export_enum` de cadenas; asignar cualquier cadena funciona en runtime).

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar**

Nativo (`spatial_stream.h`, clase `OpenDouSpatialStreamPlayback`): sustituir `static void _bind_methods() {}` por
```cpp
	static void _bind_methods() {
		godot::ClassDB::bind_method(godot::D_METHOD("get_source_playback"), &OpenDouSpatialStreamPlayback::get_source_playback);
	}
	// El playback del stream fuente (Fase 11): para empujar muestras a un AudioStreamGenerator.
	godot::Ref<godot::AudioStreamPlayback> get_source_playback() const { return inner_; }
```
Comprobar que el header incluye `<godot_cpp/core/class_db.hpp>` (lo usa el stream); recompilar.

Canal:
```gdscript
## El playback de la FUENTE de la voz: en godot el del reproductor; en steam_audio el interno
## del stream nativo. Sirve para empujar muestras a un AudioStreamGenerator (Fase 11).
func get_source_playback() -> AudioStreamPlayback:
	var player := get_player()
	if player == null:
		return null
	var pb = player.get_stream_playback()
	if pb == null:
		return null
	if _has_spatial_stream(player) and pb.has_method("get_source_playback"):
		return pb.get_source_playback()
	return pb
```
(`has_method` aquí es sobre un objeto nativo cuya versión puede ser vieja: no es una promesa vacía nuestra, es compatibilidad; si la extensión es la actual el método existe.)

Emisor 3D, exports tras el grupo «OpenDou Event»:
```gdscript
enum Source { EVENT, BUS_CAPTURE }
@export_group("World Bus")
## BUS_CAPTURE: la voz es lo que suena en `capture_bus` (radio, megafonia). La salida directa
## del bus se calla (-80 dB: la captura es anterior al volumen del bus).
@export var source: Source = Source.EVENT
@export var capture_bus: StringName = &""
const MARK_CAPTURE: String = "OpenDou_WorldBus_Capture"
var _capture: AudioEffectCapture = null
var _generator: AudioStreamGenerator = null
var _capture_bus_prev_db: float = 0.0
var _primed: bool = false
```
En `play_event`, al principio, si `source == Source.BUS_CAPTURE`: `_start_bus_capture(manager)` y `return`:
```gdscript
func _start_bus_capture(manager) -> void:
	var idx: int = AudioServer.get_bus_index(String(capture_bus))
	if idx < 0 or manager == null:
		push_warning("[OpenDou] %s: capture_bus '%s' no existe" % [name, capture_bus])
		return
	_capture = null
	for i in range(AudioServer.get_bus_effect_count(idx)):
		var e := AudioServer.get_bus_effect(idx, i)
		if e is AudioEffectCapture and e.resource_name == MARK_CAPTURE:
			_capture = e
	if _capture == null:
		_capture = AudioEffectCapture.new()
		_capture.resource_name = MARK_CAPTURE
		_capture.buffer_length = 0.5
		AudioServer.add_bus_effect(idx, _capture)
	_capture_bus_prev_db = AudioServer.get_bus_volume_db(idx)
	AudioServer.set_bus_volume_db(idx, -80.0)
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = AudioServer.get_mix_rate()
	_generator.buffer_length = 0.2
	var def = AudioEventDefClass.new(StringName("WorldBus_%s" % capture_bus), _generator)
	def.target_bus = StringName(bus_category)
	def.is_looping = true
	def.stream_length = 0.0
	active_instance = manager.post_event(def, self)
	if active_instance != null:
		active_instance.bind_player(self)
		active_instance.copy_attenuation_from_player(self)
		active_instance.copy_emitter_settings_from_player(self)
		active_instance.max_distance = cull_distance
		active_instance.set_position(global_position if is_inside_tree() else position)
	_primed = false

func _pump_bus_capture() -> void:
	if _capture == null or active_instance == null or not active_instance.is_playing():
		return
	var manager: AudioEventManager = _get_manager()
	if manager == null or manager.voice_pool == null or active_instance.assigned_channel_id < 0:
		return
	var ch = manager.voice_pool.get_channel(active_instance.assigned_channel_id)
	if ch == null:
		return
	var pb = ch.get_source_playback() as AudioStreamGeneratorPlayback
	if pb == null:
		return
	if not _primed:
		# Colchon inicial de 0.1 s de silencio para no quedarse sin muestras.
		var silence := PackedVector2Array()
		silence.resize(int(_generator.mix_rate * 0.1))
		pb.push_buffer(silence)
		_primed = true
	var avail: int = _capture.get_frames_available()
	if avail <= 0:
		return
	var frames: PackedVector2Array = _capture.get_buffer(avail)
	var room: int = pb.get_frames_available()
	if frames.size() > room:
		frames = frames.slice(frames.size() - room)
	pb.push_buffer(frames)

func _stop_bus_capture() -> void:
	if _capture != null:
		var idx: int = AudioServer.get_bus_index(String(capture_bus))
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, _capture_bus_prev_db)
			for i in range(AudioServer.get_bus_effect_count(idx)):
				if AudioServer.get_bus_effect(idx, i) == _capture:
					AudioServer.remove_bus_effect(idx, i)
					break
	_capture = null
	_generator = null
```
En `_process` (crear si no existe; comprobar que el nodo no tenga ya uno): `if source == Source.BUS_CAPTURE: _pump_bus_capture()`. En `stop_event`, tras parar la instancia: `if source == Source.BUS_CAPTURE: _stop_bus_capture()`. En `_notification(NOTIFICATION_EXIT_TREE)` (ya existe `_notification`): `_stop_bus_capture()`.

- [ ] **Step 4: Compilar y correr** → verde. Anotar la latencia estimada (captura 0.5 s de búfer, pero se drena por cuadro: latencia ≈ 1–2 bloques + colchón 0.1 s) en el spec §12.
- [ ] **Step 5: Commit** — `git add native/src addons/opendou/runtime/physical_voice_channel.gd addons/opendou/nodes/opendou_event_player_3d.gd tests/test_world_bus.gd tests/test_all.gd && git commit -m "Fase 11: altavoz de mundo: source = BUS_CAPTURE en OpenDouEventPlayer3D (captura -> generador -> voz); playback fuente en el nativo"`

---

### Task 5: Disparadores en `OpenDouParameterArea3D`

**Files:**
- Modify: `addons/opendou/nodes/opendou_parameter_area_3d.gd`
- Test: `tests/test_area_trigger.gd`

**Interfaces:**
- Produces: exports `trigger_event`, `trigger_probability`, `trigger_cooldown_sec`, `trigger_once`, `trigger_group`; señal `triggered(event_name: StringName, target: Node3D)`; `trigger_count: int`.

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestAreaTrigger
extends RefCounted

## Fase 11: el area de parametros dispara un evento al entrar un cuerpo del grupo, con
## probabilidad, recarga y "una sola vez".

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestBinauralClass = preload("res://tests/test_binaural.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AreaScript = preload("res://addons/opendou/nodes/opendou_parameter_area_3d.gd")

static func _body(tree: SceneTree, group: String) -> Node3D:
	var b := CharacterBody3D.new()
	if not group.is_empty():
		b.add_to_group(group)
	tree.root.add_child(b)
	return b

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("area_trigger")
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var def = AudioEventDefClass.new(&"Bell", TestBinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.stream_length = 0.5
	manager.register_event_definition(def)
	var area = AreaScript.new()
	area.trigger_event = &"Bell"
	area.trigger_group = &"player"
	area.trigger_cooldown_sec = 0.3
	tree.root.add_child(area)
	area.set_event_manager(manager)
	var fired: Array = []
	area.triggered.connect(func(e, t): fired.append([e, t]))
	var player := _body(tree, "player")
	var crate := _body(tree, "")
	area.register_target_entered(player)
	a.eq(fired.size(), 1, "un cuerpo del grupo player dispara")
	a.eq(manager.active_instances.size(), 1, "y el evento suena")
	area.register_target_exited(player)
	area.register_target_entered(player)
	a.eq(fired.size(), 1, "volver a entrar antes de la recarga no dispara")
	area.register_target_exited(player)
	area.register_target_entered(crate)
	a.eq(fired.size(), 1, "un cuerpo sin el grupo no dispara")
	area.register_target_exited(crate)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 350:
		await tree.process_frame
	area.register_target_entered(player)
	a.eq(fired.size(), 2, "pasada la recarga, dispara otra vez")
	area.register_target_exited(player)
	area.trigger_once = true
	area.trigger_count = 0
	area.trigger_cooldown_sec = 0.0
	area.register_target_entered(player)
	area.register_target_exited(player)
	area.register_target_entered(player)
	a.eq(fired.size(), 3, "con trigger_once solo la primera entrada dispara")
	area.register_target_exited(player)
	area.trigger_once = false
	area.trigger_probability = 0.0
	area.register_target_entered(player)
	a.eq(fired.size(), 3, "con probabilidad 0, nunca")
	area.register_target_exited(player)
	manager.stop_all()
	for n in [player, crate, area]:
		tree.root.remove_child(n); n.free()
	tree.root.remove_child(manager); manager.free()
	return a
```

- [ ] **Step 2: Correr y ver el fallo.**

- [ ] **Step 3: Implementar** (tras el grupo «Transitions & Physics Robustness»):
```gdscript
@export_group("Trigger")
## Evento que se postea al entrar un cuerpo (Fase 11). Vacio = ninguno.
@export var trigger_event: StringName = &""
@export_range(0.0, 1.0, 0.01) var trigger_probability: float = 1.0
@export_range(0.0, 60.0, 0.05) var trigger_cooldown_sec: float = 0.0
@export var trigger_once: bool = false
## Solo cuerpos de este grupo disparan. Vacio = cualquiera.
@export var trigger_group: StringName = &""

signal triggered(event_name: StringName, target: Node3D)
var trigger_count: int = 0
var _last_trigger_ms: int = -1000000
```
Al final de `register_target_entered` (tras conectar `tree_exited`): `_maybe_trigger(target)`:
```gdscript
func _maybe_trigger(target: Node3D) -> void:
	if trigger_event.is_empty():
		return
	if not trigger_group.is_empty() and not target.is_in_group(trigger_group):
		return
	if trigger_once and trigger_count > 0:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_trigger_ms < int(trigger_cooldown_sec * 1000.0):
		return
	if randf() >= trigger_probability:
		return
	var manager = _get_manager()
	if manager == null:
		return
	_last_trigger_ms = now
	trigger_count += 1
	manager.post_event(trigger_event, target)
	triggered.emit(trigger_event, target)
```

- [ ] **Step 4: Correr** → verde.
- [ ] **Step 5: Commit** — `git commit -m "Fase 11: disparadores en OpenDouParameterArea3D: evento, probabilidad, recarga, una vez, grupo"`

---

### Task 6: Demo «El taller» y plantilla de motor

**Files:**
- Create: `scenes/shared/vehicle_engine_events.gd`, `scenes/demos/workshop/workshop_demo.tscn`, `scenes/demos/workshop/workshop_demo.gd`
- Modify: `scenes/demos/demo_hub.tscn` (sexta tarjeta), `tests/test_scene_guards.gd` (SCENES, NODE_SCRIPTS, COMPOSITION, `EXPECTED_UNCOVERED` → lista), `tests/test_demo_scenes.gd` (hub: seis tarjetas; `run_workshop_async`), `tests/loudness_budget.txt`

- [ ] **Step 1: Plantilla de motor**

```gdscript
class_name VehicleEngineEvents
extends RefCounted

## Plantilla de motor (Fase 11): un evento con AudioSwitchContainer(Load) -> dos
## AudioBlendContainer(RPM) de tres capas sintetizadas con curvas cruzadas. Es demo y preset
## del grafo, no un nodo del plugin: un motor es un contenedor bien autorado.

const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioBlendContainerClass = preload("res://addons/opendou/resources/containers/audio_blend_container.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")

const EVENT_NAME: StringName = &"WorkshopEngine"
const RPM_RTPC: StringName = &"RPM"
const LOAD_SWITCH: StringName = &"Load"

## Curva en dB: 0 en `center`, -60 en los extremos del tramo [center-width, center+width].
static func _bell(center: float, width: float) -> Curve:
	var c := Curve.new()
	c.min_value = -60.0
	c.max_value = 0.0
	c.add_point(Vector2(0.0, 0.0 if center - width <= 0.0 else -60.0))
	c.add_point(Vector2(clampf(center - width, 0.0, 1.0), -60.0 if center - width > 0.0 else 0.0))
	c.add_point(Vector2(center, 0.0))
	c.add_point(Vector2(clampf(center + width, 0.0, 1.0), -60.0 if center + width < 1.0 else 0.0))
	c.add_point(Vector2(1.0, 0.0 if center + width >= 1.0 else -60.0))
	return c

static func _blend(base_freqs: Array) -> AudioBlendContainer:
	var blend = AudioBlendContainerClass.new(RPM_RTPC, 600.0, 6000.0)
	var centers: Array = [0.0, 0.5, 1.0]
	for i in range(3):
		var loop := AudioSynthesizerClass.create_engine_loop(float(base_freqs[i]), 1.0)
		blend.add_layer(AudioPhysicalNodeClass.new(loop), _bell(centers[i], 0.5))
	return blend

static func register(manager) -> AudioEventDef:
	var sw = AudioSwitchContainerClass.new(LOAD_SWITCH, &"Idle")
	sw.set_state_node(&"Idle", _blend([40.0, 80.0, 160.0]))
	sw.set_state_node(&"Load", _blend([30.0, 60.0, 120.0]))   # mas grave bajo carga
	var def = AudioEventDefClass.new(EVENT_NAME)
	def.root_container = sw
	def.is_looping = true
	def.stream_length = 1.0
	def.base_volume_db = -8.0
	def.base_priority = 60.0
	def.hdr_loudness_db = -8.0
	if manager != null:
		manager.register_event_definition(def)
	return def
```

- [ ] **Step 2: La escena.** `scenes/demos/workshop/workshop_demo.tscn` con estos nodos (todos con sus propiedades en el `.tscn`; los scripts como `ext_resource`):

| Nodo | Tipo / script | Propiedades clave |
|---|---|---|
| `WorkshopDemo` | `Node3D` + `workshop_demo.gd` | |
| `Workshop` + `Shape` | `Area3D` + `opendou_room_3d.gd`; `CollisionShape3D` Box 16×5×12 | `room_name = &"Workshop"`, `material_preset = "Concrete"`, `floor_surface = &"Concrete"`, `reverb_send_amount = 0.5` |
| `Floor` + `Collision` + `Mesh` | `StaticBody3D` con `surface_type` (metadata) `Concrete`; Box 16×1×12 en y = −0.5; `MeshInstance3D` BoxMesh | |
| `Bench` + `Collision` + `Mesh` | `StaticBody3D` con `surface_type` `Metal`; Box 3×0.1×1.2 en (3, 0.9, −2); `Mesh` en grupo `AcousticObstacle` | |
| `Shelf` | `Node3D` en (3, 2.6, −2) | repisa lógica |
| `Can`, `Crate`, `Wrench` | `RigidBody3D` (`freeze = true`, `mass` 0.3 / 4.0 / 1.2) con `Collision` (Box 0.3 / 0.5 / 0.35) y `Mesh`, en (2.2, 2.7, −2), (3, 2.8, −2), (3.8, 2.7, −2.3); hijo `Impact` `Node3D` + `opendou_physics_impact_3d.gd` con `event_name = &"Clank"`, `min_speed_mps = 0.6`, `cooldown_sec = 0.15` | |
| `Mechanic` | instancia `npc.tscn` en (−3, 1, −3), `waypoints` = [(-3,1,-3), (-3,1,3), (-3,1,-3)]; hijo `Voice` `Node3D` + `opendou_dialogue_emitter_3d.gd` con `language = "es"`, `duck_bus = &"Radio"`, `duck_db = -10.0`, `subtitles = {&"greet": {"es": "Buenas. Si es el motor, dejelo encendido y escuche."}}` | |
| `GreetZone` + `Shape` | `Area3D` + `opendou_parameter_area_3d.gd`, Box 4×3×4 en (−3, 1.5, 0); `trigger_event = &"MechanicGreets"`, `trigger_group = &"player"`, `trigger_cooldown_sec = 8.0`, `target_entity_mask = 1` | |
| `RadioSource` | `AudioStreamPlayer` + `opendou_event_player.gd`; `bus_category` (o el export equivalente) `"Radio"` | reproduce el bucle en `Radio` |
| `RadioSpeaker` | `AudioStreamPlayer3D` + `opendou_event_player_3d.gd` en (6, 1.5, −5); `source = 1` (BUS_CAPTURE), `capture_bus = &"Radio"`, `directivity_dipole_weight = 0.7`, `unit_size = 4.0`, `area_mask = 1`, `auto_play_event = false` | |
| `Engine` | `AudioStreamPlayer3D` + `opendou_event_player_3d.gd` en (0, 0.8, 2); `event_name = &"WorkshopEngine"`, `unit_size = 6.0`, `area_mask = 1`, `auto_play_event = false` | |
| `Tarp` + `TarpMesh` | `Node3D` + `opendou_multi_position_emitter_3d.gd`, `source_mode = 1`, `mesh_path = NodePath("TarpMesh")`, `mesh_hysteresis_m = 0.3`; `TarpMesh` `MeshInstance3D` PlaneMesh 6×4 subdividido 7×5 en (−5, 2.8, 3) | lona |
| `AcousticBake` | `Node3D` + `opendou_acoustic_geometry_bake.gd` | |
| `AcousticDebugger` | `Node3D` + `opendou_acoustic_debugger_3d.gd` | |
| `Player` | instancia `player.tscn` en (0, 1, 4) | |
| `Sun` | `DirectionalLight3D` | |
| `Hud` | instancia `demo_hud.tscn` con `demo_title = "El taller"`, `thesis`, `controls`, `exercises` (los seis nodos y modos) | |
| `PauseMenu` | instancia `pause_menu.tscn` | |

Escribir el `.tscn` a mano siguiendo el formato de `keel_demo.tscn` (`[gd_scene load_steps=N format=3]`, `ext_resource` por script y subescena, `sub_resource` por forma y malla, metadatos como `metadata/surface_type = &"Metal"`). Son ~45 nodos declarados. Comprobar con el guard que se lee sin instanciar.

- [ ] **Step 3: El script** `workshop_demo.gd`:

```gdscript
class_name WorkshopDemo
extends Node3D

## «El taller»: los objetos suenan solos.
##
## Una lata, una caja y una llave caen de la repisa sobre una mesa metalica y el suelo de
## hormigon y suenan segun con que chocan y a que velocidad; el mecanico saluda al
## acercarse, con subtitulo y boca; la radio del taller es un altavoz de verdad: lo que
## suena en el bus Radio sale de una caja en la pared, con directividad; el motor es un
## contenedor por RPM y carga; la lona del fondo suena desde su punto mas cercano.
##
## LA ESCENA lleva todo eso como nodos. Este script autora los streams (se sintetizan),
## suelta la repisa, mueve RPM y carga con las teclas y convierte el disparo del area en
## la linea del mecanico. Ver .agents/rules/04_scene_composition.md.

const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const VehicleEngineEventsClass = preload("res://scenes/shared/vehicle_engine_events.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const TableClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_table.gd")

const RADIO_BUS: StringName = &"Radio"
const ENGINE_BUS: StringName = &"Engine"

@onready var engine: OpenDouEventPlayer3D = $Engine
@onready var radio_source: OpenDouEventPlayer = $RadioSource
@onready var radio_speaker: OpenDouEventPlayer3D = $RadioSpeaker
@onready var tarp: OpenDouMultiPositionEmitter3D = $Tarp
@onready var greet_zone: OpenDouParameterArea3D = $GreetZone
@onready var mechanic_voice: OpenDouDialogueEmitter3D = $Mechanic/Voice
@onready var debugger: OpenDouAcousticDebugger3D = $AcousticDebugger

var event_manager = null
var rpm: float = 900.0
var load_on: bool = false
var shelf_released: bool = false

func _ready() -> void:
	event_manager = DemoAudioClass.manager(self)
	DemoAudioClass.ensure_bus(RADIO_BUS)
	DemoAudioClass.ensure_bus(ENGINE_BUS)
	if event_manager != null:
		FootstepEventsClass.register(event_manager)
		_author_clank()
		_author_radio()
		_author_tarp()
		_author_greeting()
		var engine_def = VehicleEngineEventsClass.register(event_manager)
		engine_def.target_bus = ENGINE_BUS
	greet_zone.triggered.connect(_on_greet_triggered)
	radio_source.play_event()
	radio_speaker.play_event()
	engine.play_event()
	_apply_engine_state()
	tarp.play_event() if tarp.has_method("play_event") else null

## Impacto: switch Material -> tres ramas con variaciones; ImpactForce sube el volumen.
func _author_clank() -> void:
	var sw = AudioSwitchContainerClass.new(&"Material", &"Concrete")
	for mat in [&"Concrete", &"Metal", &"Wood"]:
		var rnd = AudioRandomContainerClass.new()
		rnd.pitch_jitter_range = Vector2(-0.08, 0.08)
		for v in range(1, 4):
			rnd.add_child_node(AudioPhysicalNodeClass.new(AudioSynthesizerClass.create_footstep(mat, v)))
		sw.set_state_node(mat, rnd)
	var def = AudioEventDefClass.new(&"Clank")
	def.root_container = sw
	def.stream_length = 0.25
	def.base_volume_db = -2.0
	def.base_priority = 55.0
	event_manager.register_event_definition(def)

func _author_radio() -> void:
	var def = AudioEventDefClass.new(&"RadioMusic", AudioSynthesizerClass.create_music_pad_loop(2.0))
	def.is_looping = true
	def.stream_length = 2.0
	def.target_bus = RADIO_BUS
	def.base_volume_db = -6.0
	event_manager.register_event_definition(def)
	radio_source.event_name = &"RadioMusic"

func _author_tarp() -> void:
	var def = AudioEventDefClass.new(&"TarpWind", AudioSynthesizerClass.create_canopy_wind_loop(3.0))
	def.is_looping = true
	def.stream_length = 3.0
	def.base_volume_db = -10.0
	event_manager.register_event_definition(def)
	tarp.event_name = &"TarpWind"   # si el emisor multiposicion expone event_name; si no, el nodo tiene su propio stream

func _author_greeting() -> void:
	var table = TableClass.new()
	table.add_entry(&"greet", "es", AudioSynthesizerClass.create_tone(180.0, 1.2, 0.4, true))
	mechanic_voice.dialogue_table = table
	var def = AudioEventDefClass.new(&"MechanicGreets", AudioSynthesizerClass.create_tone(880.0, 0.15, 0.3, true))
	def.stream_length = 0.15
	event_manager.register_event_definition(def)

func _on_greet_triggered(_event: StringName, _target: Node3D) -> void:
	if not mechanic_voice.is_speaking():
		mechanic_voice.speak(&"greet")

func release_shelf() -> void:
	shelf_released = true
	for n in [$Can, $Crate, $Wrench]:
		n.freeze = false

func set_rpm(value: float) -> void:
	rpm = clampf(value, 600.0, 6000.0)
	_apply_engine_state()

func toggle_load() -> void:
	load_on = not load_on
	_apply_engine_state()

func _apply_engine_state() -> void:
	engine.set_rtpc(VehicleEngineEventsClass.RPM_RTPC, rpm)
	engine.set_switch(VehicleEngineEventsClass.LOAD_SWITCH, &"Load" if load_on else &"Idle")

func toggle_debugger() -> bool:
	debugger.enabled = not debugger.enabled
	return debugger.enabled

func _exit_tree() -> void:
	if event_manager != null:
		event_manager.stop_all()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E: release_shelf()
			KEY_UP: set_rpm(rpm + 400.0)
			KEY_DOWN: set_rpm(rpm - 400.0)
			KEY_SPACE: toggle_load()
			KEY_F9: toggle_debugger()
```
Comprobar la API real del emisor multiposición para arrancar su voz (`event_name` + `play_event()` o equivalente) y de `OpenDouEventPlayer` (`bus_category` u otro export) antes de escribir la escena; ajustar nombres, no inventarlos.

- [ ] **Step 4: Guardas y tests.** En `test_scene_guards.gd`: añadir la escena a `SCENES`; a `NODE_SCRIPTS` añadir `"opendou_physics_impact_3d.gd"`, `"opendou_dialogue_emitter_3d.gd"`, `"opendou_listener_3d.gd"`, `"opendou_acoustic_volume_3d.gd"`, `"opendou_sound_indicator.gd"`, `"opendou_ai_hearing_3d.gd"`; convertir `EXPECTED_UNCOVERED` en `EXPECTED_UNCOVERED: Array[String] = ["opendou_event_player_2d.gd", "opendou_listener_3d.gd", "opendou_acoustic_volume_3d.gd", "opendou_sound_indicator.gd", "opendou_ai_hearing_3d.gd"]` con el comentario «la Fase 10 no tiene demo todavía» y adaptar las tres aserciones (`covered.size() == NODE_SCRIPTS.size() - EXPECTED_UNCOVERED.size()`, ninguno de los no cubiertos en `covered`, todos los demás cubiertos); entrada en `COMPOSITION` (`min_nodes: 40`, requires: room, event_player_3d, event_player, parameter_area, physics_impact, dialogue_emitter, multi_position, acoustic_geometry_bake, acoustic_debugger). En `test_demo_scenes.gd`: el hub declara **seis** tarjetas; añadir `run_workshop_async`:

```gdscript
static func run_workshop_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("workshop_demo")
	var manager = tree.root.get_node_or_null("OpenDou")
	a.ok(manager != null, "el autoload OpenDou existe")
	var packed: PackedScene = load("res://scenes/demos/workshop/workshop_demo.tscn")
	a.ok(packed != null, "la escena del taller carga")
	var demo = packed.instantiate()
	tree.root.add_child(demo)
	var lufs_meter = TestLoudnessMeterClass.start_master_meter(tree)
	await tree.process_frame
	await tree.physics_frame
	await tree.physics_frame
	# Impactos: soltar la repisa y esperar a que caigan.
	var hits: Array = []
	for body_name in ["Can", "Crate", "Wrench"]:
		demo.get_node(body_name + "/Impact").impact_posted.connect(func(s, m, mat, p): hits.append([s, mat]))
	demo.release_shelf()
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2500 and hits.size() < 3:
		await tree.physics_frame
	a.ok(hits.size() >= 1, "al soltar la repisa, al menos un impacto suena (%d)" % hits.size())
	var materials: Dictionary = {}
	for h in hits:
		materials[String(h[1])] = true
		a.gt(float(h[0]), 1.0, "ImpactForce > 1 m/s (%.2f)" % h[0])
	a.ok(materials.has("Metal") or materials.has("Concrete"), "el material es la mesa (Metal) o el suelo (Concrete): %s" % str(materials.keys()))
	# Motor: RPM cambia la capa dominante (centroide espectral en su bus).
	var probe = OpenDouAudioProbeClass.new()
	a.ok(probe.attach_to_existing_bus(&"Engine", 2.0), "la sonda se engancha al bus del motor")
	demo.set_rpm(800.0)
	for i in range(30):
		await tree.process_frame
		probe.drain()
	var low := await TestBinauralClass._capture(tree, probe)
	demo.set_rpm(5000.0)
	for i in range(30):
		await tree.process_frame
		probe.drain()
	var high := await TestBinauralClass._capture(tree, probe)
	var c_low: float = TestBinauralClass._spectral_centroid_stereo(low, AudioServer.get_mix_rate())
	var c_high: float = TestBinauralClass._spectral_centroid_stereo(high, AudioServer.get_mix_rate())
	print("[OpenDou] taller: motor a 800 rpm centroide %.0f Hz, a 5000 rpm %.0f Hz" % [c_low, c_high])
	a.gt(c_high, c_low * 1.2, "a mas RPM, capa mas aguda")
	probe.teardown()
	# Radio: la voz del altavoz tiene ILD en su bus (Master, medido solo el signo).
	var radio_idx: int = AudioServer.get_bus_index("Radio")
	a.approx(AudioServer.get_bus_volume_db(radio_idx), -80.0, "el bus Radio esta callado en directo: suena por el altavoz", 0.1)
	# Mecanico: el area dispara y la voz habla con subtitulo.
	var subtitles: Array = []
	demo.mechanic_voice.subtitle_changed.connect(func(t): subtitles.append(t))
	demo.greet_zone.register_target_entered(demo.get_node("Player"))
	await tree.process_frame
	a.eq(subtitles.size(), 1, "el area del mecanico dispara el saludo con subtitulo")
	a.ok(demo.mechanic_voice.is_speaking(), "y el mecanico habla")
	# Composicion.
	var state: SceneState = packed.get_state()
	a.gt(float(state.get_node_count()), 39.5, "la escena declara al menos 40 nodos (%d)" % state.get_node_count())
	var t1: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 1500:
		await tree.process_frame
	TestLoudnessMeterClass.check_budget(a, "workshop", TestLoudnessMeterClass.finish_master_meter(lufs_meter))
	if manager != null:
		manager.stop_all()
	_release_current(demo)
	tree.root.remove_child(demo)
	demo.free()
	return a
```
Registrar en `run_all_async` de `test_demo_scenes.gd` tras las demás demos. Añadir a `tests/loudness_budget.txt` la línea `workshop <min> <max>` con la primera medida ±6 LU (primera corrida sin la línea: `check_budget` imprime «sin rango» sin fallar; después se fija).

- [ ] **Step 5: Correr** → verde (dos corridas: una para medir la sonoridad, otra con el presupuesto). Comprobar el techo de fugas.
- [ ] **Step 6: Commit** — `git add scenes tests/test_scene_guards.gd tests/test_demo_scenes.gd tests/loudness_budget.txt && git commit -m "Fase 11: demo El taller: impactos, dialogo, radio como altavoz, motor por RPM y carga, lona por malla; plantilla de motor"`

---

### Task 7: Documentos y cierre

**Files:**
- Modify: `docs/funcionalidades.md` (tabla de emisores: `OpenDouPhysicsImpact3D`, `OpenDouDialogueEmitter3D`, modo MESH en el multiposición, `BUS_CAPTURE` en el 3D, disparadores en el área; demos: «El taller»; ideas: G3, B6, C6, diálogo ya viven en el plugin), `AGENTS.md` (observación 49 + trampas de la Fase 11), `docs/tasks/current.md`, spec §12.

- [ ] **Step 1:** Editar los cuatro documentos.
- [ ] **Step 2:** Banco (`tools/bench_control_loop.gd`, tres corridas, fila 200) para comprobar que el bucle no subió; anotar.
- [ ] **Step 3:** `./run_tests.sh` verde; `git commit -m "Fase 11: documentos al dia; observacion 49; coste medido"`.

---

## Autorevisión

- **Cobertura del spec:** §3 → Task 1; §4 → Task 2; §5 → Task 3; §6 → Task 4; §7 → Task 5; §8 → Task 6; §9 repartido; §10 los cinco archivos de test más la demo; §11 riesgos nombrados en las tareas 1, 3, 4 y 6; §12 en Task 7.
- **Consistencia de nombres:** `impact_posted(speed, mass, material, position)` (1, 6); `speak/is_speaking/subtitle_changed/mouth_amplitude/current_viseme` (2, 6); `SourceMode.MESH`, `mesh_path`, `mesh_hysteresis_m`, `rebuild_mesh()` (3, 6); `Source.BUS_CAPTURE`, `capture_bus`, `get_source_playback()` (4, 6); `trigger_event/trigger_group/triggered/register_target_entered` (5, 6); `VehicleEngineEvents.RPM_RTPC/LOAD_SWITCH/register` (6).
- **Sin marcadores de posición.** Las tres comprobaciones «ver API real» (arranque del multiposición, export de bus del `OpenDouEventPlayer`, `managed_buses` del ducking) son verificaciones contra código existente, no huecos.
