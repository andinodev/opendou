# Fase 9 — El emisor completo: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que el emisor 3D suene como una fuente física: doppler, retardo por distancia, tamaño aparente (spread), campo cercano, directividad, curvas de atenuación dibujadas y marcadores que sincronizan el juego con el audio; todo como exports del emisor y de la definición, sin nodos nuevos.

**Architecture:** GDScript en el canal y el manager para lo que actúa sobre volumen y tono (doppler, directividad, curva, spread en Godot); dos propiedades nuevas del stream nativo para lo que necesita muestras (retardo largo antes del HRTF con fijación inicial y rampa, low-shelf e ILD de campo cercano); un recurso `AudioMarker` y una señal en la instancia sobre el reloj lógico; un lector RIFF del chunk `cue`.

**Tech Stack:** Godot 4.7.2 (GDScript), godot-cpp `master` @ `26fb7ab`, Steam Audio 4.8.1, CMake (`/Applications/CMake.app/Contents/bin/cmake` en esta máquina; `./native/build.sh` para compilar).

**Spec:** `docs/superpowers/specs/2026-09-02-fase9-emisor-completo-design.md`

## Global Constraints

- Rama `main`; cada tarea termina en commit con `./run_tests.sh` verde (sin `SCRIPT ERROR`/`Parse Error`, fugas ≤ techo, `STATUS: PASSED`).
- Aserciones sobre audio capturado con control que apaga el mecanismo; las suites nativas se omiten **y lo dicen** sin extensión.
- Todos los exports nuevos van **apagados por defecto** (`false`, `0.0`): ninguna escena existente cambia de sonido.
- En `steam_audio`, con `propagation_delay_enabled` el doppler por tono se fuerza a 1 (el retardo físico lo produce).
- El estimador de frecuencia por cruces por cero usa un tono puro y ≥ 0.4 s de captura; tolerancia 2 %.
- `OpenDouSplineEmitter3D` no pasa por el sistema de voces (obs 47): solo gana `flow_speed_mps`.
- Trampas vigentes: `:=` no infiere desde `load()`; `AudioStreamPlayer3D` no emite sin cámara (los tests ponen una); el volumen de un bus se aplica al enviarlo (medir en el bus destino o en Master); en headless un frame dura ~2 ms (esperar por tiempo o por muestras, no por frames).
- Comentarios de código sin tildes.

---

## Estructura de archivos

| Archivo | Responsabilidad | Tarea |
|---|---|---|
| `addons/opendou/resources/audio_marker.gd` (nuevo, `AudioMarker`) | `name`, `time_sec` | 1 |
| `addons/opendou/resources/audio_event_def.gd` | Exports del emisor completo + `markers` | 1 |
| `addons/opendou/nodes/opendou_event_player_3d.gd` | Exports + copia a la instancia | 1 |
| `addons/opendou/runtime/event_instance.gd` | Campos, `copy_emitter_settings_from_player`, `set_orientation`, velocidad, `doppler_pitch`, `marker_reached` | 1, 2, 6 |
| `addons/opendou/runtime/audio_event_manager.gd` | `_apply_voices(delta)`, velocidad del oyente, doppler, directividad, ajustes como factor | 2, 4 |
| `addons/opendou/runtime/spatial/distance_model.gd` | `MODEL_CURVE`, `directivity_db()` | 2, 3 |
| `addons/opendou/runtime/physical_voice_channel.gd` | Curva en `godot`, spread, campo cercano, retardo, arranque aplazado | 3, 4, 5 |
| `addons/opendou/runtime/voice_pool_manager.gd` | `start_delay_sec` al arrancar en `godot` | 5 |
| `addons/opendou/runtime/spatial/spatial_backend.gd` | Ajuste `max_propagation_delay_sec` | 5 |
| `native/src/dsp.h`, `native/src/spatial_stream.{h,cpp}` | Low-shelf, `snap()` en la línea de retardo, `propagation_delay_sec`, `near_field_bass_db`, `near_field_ild_db` | 4, 5 |
| `addons/opendou/runtime/wav_markers.gd` (nuevo, `OpenDouWavMarkers`) | Lector del chunk `cue` | 6 |
| `addons/opendou/nodes/opendou_spline_emitter_3d.gd` | `flow_speed_mps` | 7 |
| `tests/test_emitter_physics.gd`, `tests/test_audio_markers.gd`, `tests/test_spline_flow.gd` | Suites | 2–7 |
| `docs/funcionalidades.md`, `AGENTS.md`, `docs/tasks/current.md` | Marcas, obs 47 | 8 |

Convenciones: `class_name TestX extends RefCounted`, `static func run_*_async(tree) -> OpenDouAssert`, registro en `tests/test_all.gd`. Ayudantes reutilizables de `tests/test_backend_parity.gd`: `make_manager(tree, backend)`, `ensure_bus()`, `make_listener_camera(tree)`, `BUS`. De `tests/test_binaural.gd`: `_periodic_noise(rate)`, `_itd_lag`, `_ild_db`, `_band_energy_stereo`, `_rms_db`, `_capture(tree, probe)`.

---

### Task 1: Exports del emisor completo y su copia a la instancia

**Files:**
- Create: `addons/opendou/resources/audio_marker.gd`
- Modify: `addons/opendou/resources/audio_event_def.gd` (tras el grupo «Instance Limits»)
- Modify: `addons/opendou/runtime/event_instance.gd` (campos; `copy_emitter_settings_from_player`; `set_orientation`)
- Modify: `addons/opendou/nodes/opendou_event_player_3d.gd` (exports; llamada tras `copy_attenuation_from_player(self)`)
- Modify: `addons/opendou/runtime/voice_pool_manager.gd:139` (misma llamada para emisores de nodo en `steam_audio`)
- Test: `tests/test_event_instance.gd` (+3 aserciones; contador 9 → 12 en `test_all.gd`)

**Interfaces:**
- Produces `AudioMarker` (Resource): `@export var name: StringName`, `@export var time_sec: float`.
- Produces en `AudioEventDef` y `OpenDouEventPlayer3D` (exports) y `EventInstance` (campos): `doppler_enabled: bool = false`, `propagation_delay_enabled: bool = false`, `spread_radius_m: float = 0.0`, `near_field_distance_m: float = 0.0`, `directivity_dipole_weight: float = 0.0`, `directivity_power: float = 1.0`, `attenuation_curve: Curve = null`, `attenuation_curve_distance_m: float = 50.0`. Solo en la definición: `markers: Array[AudioMarker] = []`. `attenuation_model` gana la opción `"Curve"` (valor 4).
- Produces en `EventInstance`: `emitter_forward: Vector3 = Vector3(0, 0, -1)`, `func set_orientation(forward: Vector3) -> void`, `func copy_emitter_settings_from_player(player: Node3D) -> void` (copia los ocho campos si el nodo los tiene, con `in`).

- [ ] **Step 1: Test (rojo)**

En `tests/test_event_instance.gd`, antes del `return failures`:

```gdscript
	# Fase 9: exports del emisor completo, apagados por defecto, copiados desde el nodo.
	var def9 = AudioEventDef.new(&"Full")
	var inst9 = EventInstance.new(def9, null)
	if inst9.doppler_enabled or inst9.propagation_delay_enabled or inst9.spread_radius_m != 0.0 or inst9.near_field_distance_m != 0.0 or inst9.directivity_dipole_weight != 0.0 or not is_equal_approx(inst9.directivity_power, 1.0):
		failures.append("9-a: los exports del emisor completo no arrancan apagados")
	var node9 = load("res://addons/opendou/nodes/opendou_event_player_3d.gd").new()
	node9.doppler_enabled = true
	node9.spread_radius_m = 12.0
	node9.near_field_distance_m = 0.5
	node9.directivity_dipole_weight = 0.7
	node9.directivity_power = 2.0
	node9.propagation_delay_enabled = true
	inst9.copy_emitter_settings_from_player(node9)
	if not (inst9.doppler_enabled and inst9.propagation_delay_enabled and is_equal_approx(inst9.spread_radius_m, 12.0) and is_equal_approx(inst9.near_field_distance_m, 0.5) and is_equal_approx(inst9.directivity_dipole_weight, 0.7) and is_equal_approx(inst9.directivity_power, 2.0)):
		failures.append("9-b: copy_emitter_settings_from_player no copia los exports")
	inst9.set_orientation(Vector3(1, 0, 0))
	if not inst9.emitter_forward.is_equal_approx(Vector3(1, 0, 0)):
		failures.append("9-c: set_orientation no fija emitter_forward")
	node9.free()
```

`test_all.gd`: `TestEventInstanceClass` de `total_tests += 9` a `+= 12`. Run → rojo (`doppler_enabled` inexistente).

- [ ] **Step 2: Recurso y exports**

`audio_marker.gd`:

```gdscript
@tool
class_name AudioMarker
extends Resource

## Un punto con nombre dentro del audio de un evento. La instancia emite marker_reached(name)
## al cruzarlo con su reloj logico. Se autoran aqui o se leen del chunk `cue` de un WAV.

@export var name: StringName = &""
@export var time_sec: float = 0.0
```

`audio_event_def.gd`, tras `@export_group("")` de los límites:

```gdscript
## El emisor completo (Fase 9). Todo apagado por defecto: ninguna escena cambia de sonido
## hasta que un emisor o una definicion lo encienda. Los emisores de nodo copian estos
## valores de sus propios exports.
@export_group("Emitter Physics")
@export var doppler_enabled: bool = false
@export var propagation_delay_enabled: bool = false
@export_range(0.0, 200.0, 0.1) var spread_radius_m: float = 0.0
@export_range(0.0, 2.0, 0.01) var near_field_distance_m: float = 0.0
@export_range(0.0, 1.0, 0.01) var directivity_dipole_weight: float = 0.0
@export_range(0.1, 8.0, 0.1) var directivity_power: float = 1.0
## Con attenuation_model = Curve: la curva se autora en dB (0 a -60) y su eje X va de 0 a
## attenuation_curve_distance_m.
@export var attenuation_curve: Curve = null
@export var attenuation_curve_distance_m: float = 50.0
## Marcadores con nombre que la instancia emite al cruzarlos.
@export var markers: Array[AudioMarker] = []
@export_group("")
```

y cambiar el enum de `attenuation_model` a `@export_enum("Inverse", "Inverse Square", "Logarithmic", "Disabled", "Curve") var attenuation_model: int = 0`.

`opendou_event_player_3d.gd`, tras el grupo «Spatial Acoustics & Occlusion»:

```gdscript
@export_group("Emitter Physics")
## Cambia el tono con la velocidad relativa. Ambos backends.
@export var doppler_enabled: bool = false
## El sonido llega tarde de lejos (343 m/s). En godot solo retrasa el arranque.
@export var propagation_delay_enabled: bool = false
## Radio en el que la fuente deja de ser un punto al acercarse (0 = apagado).
@export_range(0.0, 200.0, 0.1) var spread_radius_m: float = 0.0
## Refuerzo de graves e ILD extra al pegarse a la oreja (0 = apagado; solo steam_audio).
@export_range(0.0, 2.0, 0.01) var near_field_distance_m: float = 0.0
## Directividad tipo dipolo (0 = omnidireccional). El eje es -Z del nodo.
@export_range(0.0, 1.0, 0.01) var directivity_dipole_weight: float = 0.0
@export_range(0.1, 8.0, 0.1) var directivity_power: float = 1.0
## Con attenuation_model = Curve: curva en dB sobre 0..attenuation_curve_distance_m.
@export var attenuation_curve: Curve = null
@export var attenuation_curve_distance_m: float = 50.0
```

y tras `active_instance.copy_attenuation_from_player(self)`: `active_instance.copy_emitter_settings_from_player(self)`. En `voice_pool_manager.gd`, tras `instance.copy_attenuation_from_player(player)`: `instance.copy_emitter_settings_from_player(player)`.

- [ ] **Step 3: La instancia**

Tras `var emitter_volume_db: float = 0.0`:

```gdscript
# El emisor completo (Fase 9). Copiados de la definicion o del nodo emisor.
var doppler_enabled: bool = false
var propagation_delay_enabled: bool = false
var spread_radius_m: float = 0.0
var near_field_distance_m: float = 0.0
var directivity_dipole_weight: float = 0.0
var directivity_power: float = 1.0
var attenuation_curve: Curve = null
var attenuation_curve_distance_m: float = 50.0
## Hacia donde mira el emisor (eje de la directividad). Los nodos lo actualizan cada frame.
var emitter_forward: Vector3 = Vector3(0, 0, -1)
```

En `_init`, tras copiar la atenuación de la definición:

```gdscript
		doppler_enabled = definition.doppler_enabled
		propagation_delay_enabled = definition.propagation_delay_enabled
		spread_radius_m = definition.spread_radius_m
		near_field_distance_m = definition.near_field_distance_m
		directivity_dipole_weight = definition.directivity_dipole_weight
		directivity_power = definition.directivity_power
		attenuation_curve = definition.attenuation_curve
		attenuation_curve_distance_m = definition.attenuation_curve_distance_m
```

Tras `copy_attenuation_from_player`:

```gdscript
## Copia los exports del emisor completo de un nodo (OpenDouEventPlayer3D u otro que los
## declare). Los que el nodo no tenga se dejan como estan.
func copy_emitter_settings_from_player(player: Node3D) -> void:
	if player == null:
		return
	for field in ["doppler_enabled", "propagation_delay_enabled", "spread_radius_m", "near_field_distance_m", "directivity_dipole_weight", "directivity_power", "attenuation_curve", "attenuation_curve_distance_m"]:
		if field in player:
			set(field, player.get(field))

## Eje de la directividad para voces anonimas; los nodos lo fijan cada frame desde su base.
func set_orientation(forward: Vector3) -> void:
	if forward.length_squared() > 0.000001:
		emitter_forward = forward.normalized()
```

- [ ] **Step 4: Verde y commit**

```bash
./run_tests.sh
git add addons/opendou/resources/audio_marker.gd addons/opendou/resources/audio_marker.gd.uid addons/opendou/resources/audio_event_def.gd addons/opendou/runtime/event_instance.gd addons/opendou/nodes/opendou_event_player_3d.gd addons/opendou/runtime/voice_pool_manager.gd tests/test_event_instance.gd tests/test_all.gd
git commit -m "Fase 9: exports del emisor completo, apagados por defecto, copiados a la instancia"
```

---

### Task 2: Doppler y directividad

**Files:**
- Modify: `addons/opendou/runtime/audio_event_manager.gd` (`_update_listener`, `_process` → `_apply_voices(delta)`)
- Modify: `addons/opendou/runtime/event_instance.gd` (`update_motion(delta)`, `doppler_pitch`)
- Modify: `addons/opendou/runtime/spatial/distance_model.gd` (`directivity_db`)
- Create: `tests/test_emitter_physics.gd` (`run_doppler_async`, `run_directivity_async`), registrar

**Interfaces:**
- Produces en el manager: `var listener_velocity: Vector3`; `_apply_voices(delta: float)`.
- Produces en `EventInstance`: `var emitter_velocity: Vector3`, `var flow_velocity: Vector3`, `var doppler_pitch: float = 1.0`, `func update_motion(delta: float) -> void` (velocidad desde la posición anterior; ignora saltos > 50 m).
- Produces en `OpenDouDistanceModel`: `static func directivity_db(forward: Vector3, to_listener: Vector3, dipole_weight: float, power: float) -> float`.
- Ayudante de test: `static func _estimate_frequency_hz(samples: PackedFloat32Array, rate: float) -> float` (cruces por cero).

- [ ] **Step 1: Test (rojo)**

```gdscript
class_name TestEmitterPhysics
extends RefCounted

## Fase 9: el emisor completo, medido en el bus con un control por mecanismo.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const ParityClass = preload("res://tests/test_backend_parity.gd")
const BinauralClass = preload("res://tests/test_binaural.gd")

static func _tone(freq: float, seconds: float, peak_db: float = -6.0) -> AudioStreamWAV:
	var rate: int = int(AudioServer.get_mix_rate())
	var n: int = int(rate * seconds)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var amp: float = db_to_linear(peak_db) * 32767.0
	for i in range(n):
		bytes.encode_s16(i * 2, int(sin(TAU * freq * i / rate) * amp))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav

## Frecuencia por cruces por cero de la suma L+R. Solo vale para un tono puro.
static func _estimate_frequency_hz(cap: Dictionary, rate: float) -> float:
	var l: PackedFloat32Array = cap["left"]
	var r: PackedFloat32Array = cap["right"]
	var n: int = mini(l.size(), r.size())
	if n < 1024:
		return 0.0
	var crossings: int = 0
	var prev: float = l[0] + r[0]
	for i in range(1, n):
		var v: float = l[i] + r[i]
		if (prev < 0.0 and v >= 0.0) or (prev > 0.0 and v <= 0.0):
			crossings += 1
		prev = v
	return float(crossings) * 0.5 * rate / float(n)

static func _wait_ms(tree: SceneTree, ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await tree.process_frame

## Un tono de 1 kHz que se acerca a 30 m/s sube a ~1096 Hz; alejandose baja a ~920 Hz; con el
## doppler apagado, 1000 Hz. En el backend godot (pitch_scale) y en steam_audio.
static func run_doppler_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("doppler")
	var previous: String = str(ProjectSettings.get_setting("opendou/spatial/backend", "auto"))
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var rate: float = AudioServer.get_mix_rate()
	for backend in ["godot", "steam_audio"]:
		if backend == "steam_audio" and not ClassDB.class_exists("OpenDouSpatialStream"):
			print("[OpenDou] extension nativa AUSENTE: doppler en steam_audio omitido")
			continue
		var manager = ParityClass.make_manager(tree, backend)
		await tree.process_frame
		var def = AudioEventDefClass.new(&"DopplerTone", _tone(1000.0, 1.0))
		def.is_looping = true
		def.stream_length = 1.0
		def.target_bus = ParityClass.BUS
		def.attenuation_model = 3   # Disabled: el nivel no cambia con la distancia
		manager.register_event_definition(def)
		manager.set_listener_position(Vector3.ZERO)
		for enabled in [true, false]:
			def.doppler_enabled = enabled
			for direction in [-1.0, 1.0]:
				# Empieza a 40 m delante y se mueve a 30 m/s hacia (o desde) el oyente.
				var inst = manager.post_event(def, null)
				var z: float = -40.0 if direction < 0.0 else -10.0
				inst.set_position(Vector3(0, 0, z))
				await _wait_ms(tree, 200)
				probe.drain()
				var l := PackedFloat32Array()
				var r := PackedFloat32Array()
				var t0: int = Time.get_ticks_msec()
				var last: int = t0
				while Time.get_ticks_msec() - t0 < 600:
					await tree.process_frame
					var now: int = Time.get_ticks_msec()
					var dt: float = float(now - last) / 1000.0
					last = now
					z += -direction * 30.0 * dt   # direction -1: se acerca (z sube hacia 0)
					inst.set_position(Vector3(0, 0, z))
					var avail: int = probe._capture.get_frames_available()
					if avail > 0 and now - t0 > 150:
						for v in probe._capture.get_buffer(avail):
							l.append(v.x)
							r.append(v.y)
				var f: float = _estimate_frequency_hz({"left": l, "right": r}, rate)
				var label: String = "%s, doppler %s, %s" % [backend, "on" if enabled else "off", "acercandose" if direction < 0.0 else "alejandose"]
				print("[OpenDou] %s: %.0f Hz" % [label, f])
				if enabled and direction < 0.0:
					a.ok(f > 1050.0 and f < 1140.0, label + ": sube a ~1096 Hz (medido %.0f)" % f)
				elif enabled:
					a.ok(f > 880.0 and f < 960.0, label + ": baja a ~920 Hz (medido %.0f)" % f)
				else:
					a.ok(f > 980.0 and f < 1020.0, label + ": se queda en 1000 Hz (medido %.0f)" % f)
				inst.stop()
				await probe.await_silence(tree, 0.002, 30)
		manager.stop_all()
		tree.root.remove_child(manager)
		manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a

## Directividad dipolo: de frente 0 dB, de lado el suelo; con peso 0, igual en todas partes.
static func run_directivity_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("directivity")
	var previous: String = str(ProjectSettings.get_setting("opendou/spatial/backend", "auto"))
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var manager = ParityClass.make_manager(tree, "godot")
	await tree.process_frame
	var def = AudioEventDefClass.new(&"DirTone", BinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = ParityClass.BUS
	def.attenuation_model = 3
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)
	var levels: Dictionary = {}
	for weight in [1.0, 0.5, 0.0]:
		def.directivity_dipole_weight = weight
		def.directivity_power = 1.0
		for facing in ["front", "side", "back"]:
			var inst = manager.post_event(def, null)
			inst.set_position(Vector3(0, 0, -5))     # delante del oyente; el oyente esta en -Z del emisor... el emisor mira:
			match facing:
				"front": inst.set_orientation(Vector3(0, 0, 1))    # hacia el oyente (que esta en +Z respecto al emisor)
				"side": inst.set_orientation(Vector3(1, 0, 0))
				"back": inst.set_orientation(Vector3(0, 0, -1))
			await _wait_ms(tree, 250)
			probe.drain()
			var cap := await BinauralClass._capture(tree, probe)
			levels["%s_%s" % [weight, facing]] = BinauralClass._rms_db(cap)
			inst.stop()
			await probe.await_silence(tree, 0.002, 30)
	print("[OpenDou] directividad: ", levels)
	a.lt(levels["1.0_side"] - levels["1.0_front"], -20.0, "peso 1: de lado cae al menos 20 dB respecto a de frente")
	a.approx(levels["1.0_back"], levels["1.0_front"], "peso 1 (dipolo): de espaldas suena como de frente", 1.0)
	a.lt(levels["0.5_back"] - levels["0.5_front"], -20.0, "peso 0.5 (cardioide): de espaldas cae al menos 20 dB")
	a.approx(levels["0.0_side"], levels["0.0_front"], "peso 0: omnidireccional (control)", 0.5)
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a
```

Registrar en `run_async_suite`: `acc.absorb(await TestEmitterPhysicsClass.run_doppler_async(tree))` y `run_directivity_async`. Run → rojo (`set_orientation` existe desde la Task 1, pero el tono no cambia y la directividad no se aplica: fallan las aserciones de frecuencia y nivel).

- [ ] **Step 2: Movimiento y doppler en la instancia**

En `event_instance.gd`, tras `emitter_forward`:

```gdscript
## Velocidad del emisor (m/s) estimada por diferencia de posicion entre frames; y una
## velocidad de flujo que quien quiera (el spline) puede sumar.
var emitter_velocity: Vector3 = Vector3.ZERO
var flow_velocity: Vector3 = Vector3.ZERO
## Factor de tono por doppler, suavizado. 1.0 sin doppler.
var doppler_pitch: float = 1.0
var _prev_motion_position: Vector3 = Vector3.ZERO
var _has_prev_motion: bool = false

## Actualiza la velocidad del emisor desde su posicion actual. Un salto mayor de 50 m en un
## frame es un teletransporte, no una velocidad: ese frame vale 0.
func update_motion(delta: float) -> void:
	if not _has_prev_motion or delta <= 0.0:
		_prev_motion_position = emitter_position
		_has_prev_motion = true
		emitter_velocity = Vector3.ZERO
		return
	var step: Vector3 = emitter_position - _prev_motion_position
	_prev_motion_position = emitter_position
	emitter_velocity = Vector3.ZERO if step.length() > 50.0 else step / delta
```

- [ ] **Step 3: Directividad en el modelo**

En `distance_model.gd`:

```gdscript
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
```

- [ ] **Step 4: El manager: velocidad del oyente, doppler y directividad por voz**

En `_update_listener()`:

```gdscript
	if listener_resolver.resolve(get_viewport()):
		var previous_pos: Vector3 = active_listener_position
		active_listener_position = listener_resolver.position
		active_listener_basis = listener_resolver.basis
		var dt: float = get_process_delta_time()
		listener_velocity = (active_listener_position - previous_pos) / dt if dt > 0.0 and _listener_seen else Vector3.ZERO
		_listener_seen = true
```

con `var listener_velocity: Vector3 = Vector3.ZERO` y `var _listener_seen: bool = false` junto a `active_listener_basis`. En `_process`: `_apply_voices(delta)`. En `_apply_voices(delta: float)`, tras leer la posición del nodo (`pos_node`) y antes de `volume_db`:

```gdscript
		# Orientacion y movimiento del emisor (Fase 9).
		if pos_node != null:
			instance.set_orientation(-pos_node.global_transform.basis.z)
		instance.update_motion(delta)
		var to_listener: Vector3 = active_listener_position - instance.emitter_position
		# Doppler por tono: en steam_audio con retardo por distancia lo produce la linea de
		# retardo y aqui se fuerza a 1 (aplicarlo dos veces doblaria el efecto).
		if instance.doppler_enabled and instance.has_spatial_position and not (is_steam_audio_backend() and instance.propagation_delay_enabled):
			var factor: float = spatial_acoustics.calculate_doppler_pitch(instance.emitter_velocity + instance.flow_velocity, listener_velocity, to_listener)
			instance.doppler_pitch = lerpf(instance.doppler_pitch, factor, clampf(10.0 * delta, 0.0, 1.0))
		else:
			instance.doppler_pitch = 1.0
```

y tras el fundido de `stop`:

```gdscript
		# Directividad (GDScript en ambos backends; la nativa llega en la Fase 12).
		if instance.has_spatial_position and instance.directivity_dipole_weight > 0.0:
			volume_db += DistanceModelClass.directivity_db(instance.emitter_forward, to_listener, instance.directivity_dipole_weight, instance.directivity_power)
```

y las dos llamadas `ch.apply_spatial(...)`/`ch.apply(...)` reciben `instance.calculated_pitch_scale * instance.doppler_pitch`. Añadir `const DistanceModelClass = preload("res://addons/opendou/runtime/spatial/distance_model.gd")` al manager si no está.

- [ ] **Step 5: Verde, banco y commit**

`./run_tests.sh`; banco `tools/bench_control_loop.gd` (200 voces: ≤ +5 % sobre 4.09 / 4.25 µs).

```bash
git add addons/opendou/runtime/audio_event_manager.gd addons/opendou/runtime/event_instance.gd addons/opendou/runtime/spatial/distance_model.gd tests/test_emitter_physics.gd tests/test_emitter_physics.gd.uid tests/test_all.gd tests/leak_budget.txt
git commit -m "Fase 9: doppler por tono y directividad dipolo, medidos en el bus"
```

---

### Task 3: Curva de atenuación en ambos backends

**Files:**
- Modify: `addons/opendou/runtime/spatial/distance_model.gd` (`MODEL_CURVE`, firma de `attenuation_db`)
- Modify: `addons/opendou/runtime/physical_voice_channel.gd` (`apply_spatial`: curva en `godot` y en `steam_audio`)
- Test: `tests/test_distance_model.gd` (+3), `tests/test_emitter_physics.gd` (`run_curve_async`)

**Interfaces:**
- Produces: `OpenDouDistanceModel.MODEL_CURVE = 4`; `attenuation_db(distance, model, unit_size, curve: Curve = null, curve_distance: float = 50.0)`; `multiplier(...)` y `gain_db_for_stream(...)` ganan los mismos dos parámetros opcionales al final.

- [ ] **Step 1: Tests (rojo)**

En `tests/test_distance_model.gd` antes de `return a`:

```gdscript
	# Fase 9: modelo CURVE, en dB sobre 0..curve_distance.
	var c := Curve.new()
	c.min_value = -80.0
	c.max_value = 6.0
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.5, 0.0))
	c.add_point(Vector2(0.6, -40.0))
	c.add_point(Vector2(1.0, -40.0))
	a.approx(DM.attenuation_db(5.0, DM.MODEL_CURVE, 10.0, c, 10.0), 0.0, "curva: a 5 m (0.5) vale 0 dB", 0.5)
	a.approx(DM.attenuation_db(6.0, DM.MODEL_CURVE, 10.0, c, 10.0), -40.0, "curva: a 6 m (0.6) vale -40 dB", 0.5)
	a.approx(DM.attenuation_db(50.0, DM.MODEL_CURVE, 10.0, c, 10.0), -40.0, "curva: mas alla del alcance se acota al ultimo punto", 0.5)
	a.approx(DM.attenuation_db(5.0, DM.MODEL_CURVE, 10.0, null, 10.0), 0.0, "curva nula: como desactivada", 0.0001)
```

En `test_emitter_physics.gd`:

```gdscript
## La misma curva da el mismo nivel en los dos backends: a 5.5 m cae ~20 dB respecto a 5 m.
static func run_curve_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("attenuation_curve")
	var previous: String = str(ProjectSettings.get_setting("opendou/spatial/backend", "auto"))
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var c := Curve.new()
	c.min_value = -80.0
	c.max_value = 6.0
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.5, 0.0))
	c.add_point(Vector2(0.6, -40.0))
	c.add_point(Vector2(1.0, -40.0))
	for backend in ["godot", "steam_audio"]:
		if backend == "steam_audio" and not ClassDB.class_exists("OpenDouSpatialStream"):
			print("[OpenDou] extension nativa AUSENTE: curva en steam_audio omitida")
			continue
		var manager = ParityClass.make_manager(tree, backend)
		await tree.process_frame
		var def = AudioEventDefClass.new(&"CurveTone", BinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
		def.is_looping = true
		def.stream_length = 1.0
		def.target_bus = ParityClass.BUS
		def.attenuation_model = 4
		def.attenuation_curve = c
		def.attenuation_curve_distance_m = 10.0
		manager.register_event_definition(def)
		manager.set_listener_position(Vector3.ZERO)
		var levels: Dictionary = {}
		for d in [5.0, 5.5]:
			var inst = manager.post_event(def, null)
			inst.set_position(Vector3(0, 0, -d))
			await _wait_ms(tree, 250)
			probe.drain()
			levels[d] = BinauralClass._rms_db(await BinauralClass._capture(tree, probe))
			inst.stop()
			await probe.await_silence(tree, 0.002, 30)
		print("[OpenDou] curva (%s): 5 m %.1f dB, 5.5 m %.1f dB" % [backend, levels[5.0], levels[5.5]])
		a.ok(levels[5.5] - levels[5.0] < -15.0 and levels[5.5] - levels[5.0] > -25.0, "%s: a 5.5 m cae ~20 dB respecto a 5 m (medido %.1f)" % [backend, levels[5.5] - levels[5.0]])
		manager.stop_all()
		tree.root.remove_child(manager)
		manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a
```

Registrar `run_curve_async`. Run → rojo.

- [ ] **Step 2: Modelo**

```gdscript
const MODEL_CURVE: int = 4

static func attenuation_db(distance: float, model: int, unit_size: float, curve: Curve = null, curve_distance: float = 50.0) -> float:
	var u: float = maxf(unit_size, 0.001)
	match model:
		MODEL_INVERSE:
			return linear_to_db(1.0 / ((distance / u) + EPS))
		MODEL_INVERSE_SQUARE:
			var d: float = distance / u
			return linear_to_db(1.0 / (d * d + EPS))
		MODEL_LOGARITHMIC:
			return -20.0 * log(distance / u + EPS)
		MODEL_CURVE:
			if curve == null:
				return 0.0
			return curve.sample(clampf(distance / maxf(curve_distance, 0.001), 0.0, 1.0))
		_:
			return 0.0
```

`multiplier(distance, model, unit_size, volume_db, max_db, attenuation_max_distance, curve: Curve = null, curve_distance: float = 50.0)` y `gain_db_for_stream(distance, model, unit_size, volume_db, attenuation_max_distance, curve: Curve = null, curve_distance: float = 50.0)` pasan los dos parámetros a `attenuation_db`.

- [ ] **Step 3: Canal**

En la rama nativa de `apply_spatial`, la llamada a `multiplier` añade `instance.attenuation_curve, instance.attenuation_curve_distance_m`. En la rama `AudioStreamPlayer3D`:

```gdscript
	elif player is AudioStreamPlayer3D:
		var vol: float = volume_db + gain_db
		if instance.attenuation_model == DistanceModelClass.MODEL_CURVE:
			# Godot no tiene curvas: se desactiva su atenuacion y la curva va al volumen. Su
			# shelf por distancia queda en 0 (depende del multiplicador, que ahora es 1).
			if player.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED:
				player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
			var d: float = instance.current_apparent_position.distance_to(listener_position)
			vol += DistanceModelClass.attenuation_db(d, DistanceModelClass.MODEL_CURVE, instance.unit_size, instance.attenuation_curve, instance.attenuation_curve_distance_m)
		player.volume_db = clampf(vol, -80.0, 24.0)
		...
```

(el resto de la rama igual). Ojo con los reproductores del pool reutilizados: `play_stream` restaura `attenuation_model` al de la instancia cuando no es `CURVE`: en `play_stream`, si `player is AudioStreamPlayer3D`, `player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE` (el defecto del pool) antes de arrancar; `apply_spatial` lo cambia si hace falta.

- [ ] **Step 4: Verde y commit**

```bash
./run_tests.sh
git add addons/opendou/runtime/spatial/distance_model.gd addons/opendou/runtime/physical_voice_channel.gd tests/test_distance_model.gd tests/test_emitter_physics.gd tests/test_all.gd
git commit -m "Fase 9: curva de atenuacion dibujada, igual en los dos backends"
```

---

### Task 4: Spread y campo cercano

**Files:**
- Modify: `native/src/dsp.h` (`Biquad::set_lowshelf`), `native/src/spatial_stream.{h,cpp}` (`near_field_bass_db`, `near_field_ild_db`)
- Modify: `addons/opendou/runtime/physical_voice_channel.gd` (`apply_spatial`: spread y campo cercano)
- Modify: `addons/opendou/runtime/audio_event_manager.gd` (`_apply_spatial_settings`: solo streams libres)
- Test: `tests/test_emitter_physics.gd` (`run_spread_async`, `run_near_field_async`)

**Interfaces:**
- Produces en `OpenDouSpatialStream`: `near_field_bass_db: float` ([0, 12], 0), `near_field_ild_db: float` ([0, 12], 0).
- Canal: `spread = clamp(1 − d / spread_radius_m, 0, 1)`; nativo `stream.spatial_blend = pool.default_spatial_blend × (1 − spread)`; godot `player.panning_strength = 1 − spread`. `nf = clamp(1 − d / near_field_distance_m, 0, 1)`; `near_field_bass_db = 6·nf`; `near_field_ild_db = 6·nf·|dir.x|`.
- El canal necesita el pool: `PhysicalVoiceChannel.player_pool` (referencia débil o directa) fijada por `VoicePoolManager` al crear los canales (`set_player_pool` la propaga).

- [ ] **Step 1: Tests (rojo)**

```gdscript
## Spread: a 1 m con radio 10 la voz colapsa hacia el centro (ILD e ITD ~0); a 20 m, no.
static func run_spread_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spread")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite spread omitida")
		return a
	var previous: String = str(ProjectSettings.get_setting("opendou/spatial/backend", "auto"))
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var manager = ParityClass.make_manager(tree, "steam_audio")
	await tree.process_frame
	var def = AudioEventDefClass.new(&"SpreadNoise", BinauralClass._periodic_noise(int(AudioServer.get_mix_rate())))
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = ParityClass.BUS
	def.attenuation_model = 3
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)
	var results: Dictionary = {}
	for radius in [10.0, 0.0]:
		def.spread_radius_m = radius
		for d in [1.0, 20.0]:
			var inst = manager.post_event(def, null)
			inst.set_position(Vector3(d, 0, 0))   # a la derecha
			await _wait_ms(tree, 250)
			probe.drain()
			var cap := await BinauralClass._capture(tree, probe)
			results["%s_%s" % [radius, d]] = {"ild": BinauralClass._ild_db(cap.left, cap.right), "lag": BinauralClass._itd_lag(cap.left, cap.right)}
			inst.stop()
			await probe.await_silence(tree, 0.002, 30)
	print("[OpenDou] spread: ", results)
	a.lt(absf(results["10.0_1.0"]["ild"]), 2.0, "radio 10 a 1 m: la ILD casi desaparece (spread 0.9)")
	a.ok(absf(results["10.0_1.0"]["lag"]) <= 4, "y el ITD tambien")
	a.gt(results["10.0_20.0"]["ild"], 6.0, "radio 10 a 20 m: ILD normal")
	a.gt(results["0.0_1.0"]["ild"], 6.0, "radio 0 (apagado) a 1 m: ILD normal (control)")
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a

## Campo cercano: a 0.2 m con distancia 0.5 suben los graves y crece la ILD; a 1 m, no.
static func run_near_field_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("near_field")
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		print("[OpenDou] extension nativa AUSENTE: suite near_field omitida")
		return a
	var previous: String = str(ProjectSettings.get_setting("opendou/spatial/backend", "auto"))
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	var manager = ParityClass.make_manager(tree, "steam_audio")
	await tree.process_frame
	var rate: float = AudioServer.get_mix_rate()
	var def = AudioEventDefClass.new(&"NearNoise", BinauralClass._periodic_noise(int(rate)))
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = ParityClass.BUS
	def.attenuation_model = 3
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)
	var res: Dictionary = {}
	for nfd in [0.5, 0.0]:
		def.near_field_distance_m = nfd
		for d in [0.2, 1.0]:
			var inst = manager.post_event(def, null)
			inst.set_position(Vector3(d, 0, 0))
			await _wait_ms(tree, 250)
			probe.drain()
			var cap := await BinauralClass._capture(tree, probe)
			res["%s_%s" % [nfd, d]] = {"bass": BinauralClass._band_energy_stereo(cap, rate, 60.0, 200.0), "ild": BinauralClass._ild_db(cap.left, cap.right)}
			inst.stop()
			await probe.await_silence(tree, 0.002, 30)
	var bass_gain_db: float = 10.0 * log(res["0.5_0.2"]["bass"] / maxf(res["0.5_1.0"]["bass"], 1e-12)) / log(10.0)
	var bass_ctrl_db: float = 10.0 * log(res["0.0_0.2"]["bass"] / maxf(res["0.0_1.0"]["bass"], 1e-12)) / log(10.0)
	print("[OpenDou] campo cercano: graves +%.1f dB (control %.1f), ILD %.1f frente a %.1f dB" % [bass_gain_db, bass_ctrl_db, res["0.5_0.2"]["ild"], res["0.5_1.0"]["ild"]])
	a.gt(bass_gain_db, 3.5, "a 0.2 m los graves suben al menos 3.5 dB respecto a 1 m")
	a.lt(absf(bass_ctrl_db), 1.0, "con la distancia en 0, los graves no cambian (control)")
	a.gt(res["0.5_0.2"]["ild"] - res["0.5_1.0"]["ild"], 3.0, "y la ILD crece al menos 3 dB")
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a
```

Registrar ambas. Run → rojo (la ILD a 1 m con radio 10 sigue alta; `near_field_bass_db` no existe → SCRIPT ERROR).

- [ ] **Step 2: Nativo**

`dsp.h`, en `Biquad`:

```cpp
	// Low-shelf RBJ: ganancia gain_db por debajo de fc.
	void set_lowshelf(float fs, float fc, float gain_db) {
		fc = std::clamp(fc, 10.0f, fs * 0.45f);
		const float A = std::pow(10.0f, gain_db / 40.0f);
		const float w0 = 2.0f * kPi * fc / fs;
		const float cw = std::cos(w0), sw = std::sin(w0);
		const float alpha = sw / 2.0f * std::sqrt(2.0f);
		const float sqA2a = 2.0f * std::sqrt(A) * alpha;
		const float a0 = (A + 1.0f) + (A - 1.0f) * cw + sqA2a;
		b0 = (A * ((A + 1.0f) - (A - 1.0f) * cw + sqA2a)) / a0;
		b1 = (2.0f * A * ((A - 1.0f) - (A + 1.0f) * cw)) / a0;
		b2 = (A * ((A + 1.0f) - (A - 1.0f) * cw - sqA2a)) / a0;
		a1 = (-2.0f * ((A - 1.0f) + (A + 1.0f) * cw)) / a0;
		a2 = ((A + 1.0f) + (A - 1.0f) * cw - sqA2a) / a0;
	}
```

Stream: atómicos `near_field_bass_db_{0}`, `near_field_ild_db_{0}`, setters con clamp [0, 12] y propiedades enlazadas. Playback: `dsp::Biquad near_shelf_; float near_applied_db_ = -1.0f;`. En `render_block`, tras el shelf por distancia y antes del HRTF:

```cpp
	const float nf_bass = stream_->near_field_bass_db_.load();
	if (std::fabs(nf_bass - near_applied_db_) > 0.05f) {
		if (nf_bass < 0.05f) near_shelf_.set_identity(); else near_shelf_.set_lowshelf(fs, 250.0f, nf_bass);
		near_applied_db_ = nf_bass;
	}
	if (nf_bass >= 0.05f) for (int i = 0; i < frame_size; i++) mono[i] = near_shelf_.process(mono[i]);
```

y tras el ITD (rama audífonos): `const float nf_ild = stream_->near_field_ild_db_.load(); if (nf_ild > 0.05f) { const float g = std::pow(10.0f, -nf_ild / 20.0f); const int far = dx >= 0.0f ? 0 : 1; for (i) interleaved_[2*i + far] *= g; }`. Reiniciar `near_shelf_` en `_stop()`/`create_effect()`.

- [ ] **Step 3: Canal y ajustes como factor**

`VoicePoolManager.set_player_pool(pool)` propaga `ch.player_pool = pool` a todos los canales (y en `_init` cuando ya haya pool). En `apply_spatial`, rama nativa, tras `s.direction = ...`:

```gdscript
		# Spread: la fuente deja de ser un punto al acercarse. El ajuste del jugador es un factor.
		var spread: float = 0.0
		if instance.spread_radius_m > 0.0:
			spread = clampf(1.0 - distance / instance.spread_radius_m, 0.0, 1.0)
		var base_blend: float = player_pool.default_spatial_blend if player_pool != null else 1.0
		s.spatial_blend = base_blend * (1.0 - spread)
		# Campo cercano: refuerzo de graves e ILD extra al pegarse a la oreja.
		var nf: float = 0.0
		if instance.near_field_distance_m > 0.0:
			nf = clampf(1.0 - distance / instance.near_field_distance_m, 0.0, 1.0)
		s.near_field_bass_db = 6.0 * nf
		s.near_field_ild_db = 6.0 * nf * absf(s.direction.x)
```

Rama `AudioStreamPlayer3D`: `player.panning_strength = 1.0 - spread` (con el mismo cálculo de `spread`; `1.0` si el radio es 0). En el manager, `_apply_spatial_settings`: `for_each_spatial_stream` solo fija `output_mode`; el blend lo pone el canal por voz y los libres nacen con `default_spatial_blend`. (Comprobar el test `run_settings_live_async` de `test_binaural.gd`: afirmaba que cambiar la mezcla llega al stream **libre** adquirido con `acquire`; sigue valiendo si `_apply_spatial_settings` recorre los libres: el pool gana `for_each_free_spatial_stream`.)

- [ ] **Step 4: Compilar, verde, guarda de DSP y commit**

```bash
/Applications/CMake.app/Contents/bin/cmake --build native/build/ext --parallel && ./run_tests.sh
git add native/src addons/opendou/runtime/physical_voice_channel.gd addons/opendou/runtime/voice_pool_manager.gd addons/opendou/runtime/native_player_pool.gd addons/opendou/runtime/audio_event_manager.gd tests/test_emitter_physics.gd tests/test_binaural.gd tests/test_all.gd
git commit -m "Fase 9: spread por distancia (blend por voz / panning_strength) y campo cercano nativo"
```

---

### Task 5: Retardo por distancia

**Files:**
- Modify: `native/src/dsp.h` (`FractionalDelay::snap`), `native/src/spatial_stream.{h,cpp}` (`propagation_delay_sec`, línea larga perezosa)
- Modify: `addons/opendou/runtime/spatial/spatial_backend.gd` (ajuste `max_propagation_delay_sec`)
- Modify: `addons/opendou/runtime/physical_voice_channel.gd` (`play_stream(..., start_delay_sec)`, cuenta atrás; empuje de `propagation_delay_sec`)
- Modify: `addons/opendou/runtime/voice_pool_manager.gd` (`devirtualize`: `start_delay_sec` en `godot`)
- Test: `tests/test_emitter_physics.gd` (`run_propagation_delay_async`)

**Interfaces:**
- Produces en el stream: `propagation_delay_sec: float` ([0, max], 0); estática `configure_max_propagation_delay(sec: float)` (antes de crear playbacks; por defecto 3.0).
- `FractionalDelay::snap(float samples)` fija `current = target = samples` sin rampa.
- Canal: `play_stream(stream, start_offset, volume_db, pitch, bus_name, start_delay_sec: float = 0.0)`; `var start_delay_remaining: float`; `process_fade` descuenta y arranca el reproductor al llegar a 0.
- `OpenDouSpatialBackend.MAX_DELAY_SETTING = "opendou/spatial/max_propagation_delay_sec"`, `read_max_propagation_delay() -> float`.

- [ ] **Step 1: Test (rojo)**

```gdscript
## Retardo por distancia: a 343 m el primer transitorio llega ~1 s despues de postear; a 34 m,
## antes de 0.2 s; apagado, antes de 0.1 s. En steam_audio (linea de retardo) y en godot
## (arranque aplazado).
static func run_propagation_delay_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("propagation_delay")
	var previous: String = str(ProjectSettings.get_setting("opendou/spatial/backend", "auto"))
	ParityClass.ensure_bus()
	var probe = OpenDouAudioProbeClass.new()
	probe.attach_to_existing_bus(ParityClass.BUS, 2.0)
	var cam: Camera3D = ParityClass.make_listener_camera(tree)
	for backend in ["godot", "steam_audio"]:
		if backend == "steam_audio" and not ClassDB.class_exists("OpenDouSpatialStream"):
			print("[OpenDou] extension nativa AUSENTE: retardo en steam_audio omitido")
			continue
		var manager = ParityClass.make_manager(tree, backend)
		await tree.process_frame
		var def = AudioEventDefClass.new(&"DelayTone", _tone(1000.0, 1.0, -6.0))
		def.is_looping = true
		def.stream_length = 1.0
		def.target_bus = ParityClass.BUS
		def.attenuation_model = 3
		manager.register_event_definition(def)
		manager.set_listener_position(Vector3.ZERO)
		for case in [[true, 343.0, 0.85, 1.3], [true, 34.0, 0.0, 0.25], [false, 343.0, 0.0, 0.12]]:
			def.propagation_delay_enabled = bool(case[0])
			probe.drain()
			var t0: int = Time.get_ticks_msec()
			var inst = manager.post_event(def, null)
			inst.set_position(Vector3(0, 0, -float(case[1])))
			var onset: float = -1.0
			var captured: int = 0
			while Time.get_ticks_msec() - t0 < 1800:
				await tree.process_frame
				var avail: int = probe._capture.get_frames_available()
				if avail <= 0:
					continue
				var buf: PackedVector2Array = probe._capture.get_buffer(avail)
				for i in range(buf.size()):
					if absf(buf[i].x) + absf(buf[i].y) > 0.02:
						onset = float(captured + i) / AudioServer.get_mix_rate()
						break
				if onset >= 0.0:
					break
				captured += avail
			var label: String = "%s, retardo %s, %.0f m" % [backend, "on" if case[0] else "off", case[1]]
			print("[OpenDou] %s: primer transitorio a %.3f s" % [label, onset])
			a.ok(onset >= float(case[2]) and onset <= float(case[3]), "%s: llega entre %.2f y %.2f s (medido %.3f)" % [label, case[2], case[3], onset])
			inst.stop()
			await probe.await_silence(tree, 0.002, 30)
		manager.stop_all()
		tree.root.remove_child(manager)
		manager.free()
	tree.root.remove_child(cam)
	cam.free()
	probe.teardown()
	ProjectSettings.set_setting("opendou/spatial/backend", previous)
	return a
```

El tiempo se mide **en muestras capturadas** desde que se drenó la sonda justo antes de postear, no con el reloj: así la latencia del sistema no cuenta. Registrar. Run → rojo (todo llega de inmediato).

- [ ] **Step 2: Nativo**

`dsp.h`, en `FractionalDelay`: `void snap(float samples) { target = current = std::clamp(samples, 0.0f, max_delay); step = 0.0f; }`.

Stream: `std::atomic<float> propagation_delay_{0}`; setter/getter/propiedad `propagation_delay_sec` con clamp [0, max]; estática `configure_max_propagation_delay(float)` guardando `static float max_propagation_delay_sec_ = 3.0f`. Playback: `dsp::FractionalDelay prop_delay_; bool prop_ready_ = false; bool prop_snapped_ = false;`. En `render_block`, tras la ganancia y los filtros y antes del HRTF:

```cpp
	const float prop = stream_->propagation_delay_.load();
	if (prop > 0.0f) {
		if (!prop_ready_) {
			prop_delay_.init(static_cast<int>(OpenDouSpatialStream::max_propagation_delay_sec_ * fs) + 4);
			prop_ready_ = true;
			prop_snapped_ = false;
		}
		const float samples = prop * fs;
		if (!prop_snapped_) { prop_delay_.snap(samples); prop_snapped_ = true; }
		else { prop_delay_.set_target(samples, frame_size); }
		for (int i = 0; i < frame_size; i++) mono[i] = prop_delay_.process(mono[i]);
	} else {
		prop_snapped_ = false;   // al volver a >0, se fija de golpe otra vez
	}
```

`_stop()` reinicia `prop_delay_` y `prop_snapped_`.

- [ ] **Step 3: GDScript**

`spatial_backend.gd`: `MAX_DELAY_SETTING`, `ensure` y `read_max_propagation_delay()` (defecto 3.0, acotado a [0.1, 10]); `native_available()` llama `configure_max_propagation_delay(read_max_propagation_delay())` si el método existe.

Canal: `play_stream(..., start_delay_sec: float = 0.0)`: si `> 0`, guarda `start_delay_remaining = start_delay_sec`, deja el reproductor **sin arrancar** (pero `is_busy = true` y el fade de entrada pendiente); `process_fade(delta)`: si `start_delay_remaining > 0`, descuenta y al cruzar 0 arranca (`player.play(playback_start_offset)`) y empieza el fade de entrada. `apply_spatial` rama nativa: `s.propagation_delay_sec = distance / 343.0 if instance.propagation_delay_enabled else 0.0`.

`voice_pool_manager.devirtualize`: en `godot`, `start_delay = distance(instance.emitter_position, listener_pos) / 343.0 if instance.propagation_delay_enabled else 0.0` y se pasa a `play_stream`. Necesita el oyente: `devirtualize` no lo recibe hoy; `resolve_voice_stealing(active, listener_pos, delta)` sí: guardar `_last_listener_pos` en el pool al entrar en `resolve_voice_stealing` y usarlo.

- [ ] **Step 4: Compilar, verde y commit**

```bash
/Applications/CMake.app/Contents/bin/cmake --build native/build/ext --parallel && ./run_tests.sh
git add native/src addons/opendou/runtime/spatial/spatial_backend.gd addons/opendou/runtime/physical_voice_channel.gd addons/opendou/runtime/voice_pool_manager.gd tests/test_emitter_physics.gd tests/test_all.gd
git commit -m "Fase 9: retardo por distancia (linea de retardo con fijacion inicial en steam_audio; arranque aplazado en godot)"
```

---

### Task 6: Marcadores de audio

**Files:**
- Create: `addons/opendou/runtime/wav_markers.gd`
- Modify: `addons/opendou/runtime/event_instance.gd` (señal `marker_reached`, cruce en `update_parameters`)
- Create: `tests/test_audio_markers.gd`, registrar

**Interfaces:**
- Produces en `EventInstance`: `signal marker_reached(name: StringName)`; `var _last_marker_position: float = 0.0`.
- Produces `OpenDouWavMarkers.read_cues(path: String) -> Array` de `AudioMarker` (vacío si no hay chunk `cue`).

- [ ] **Step 1: Test (rojo)**

```gdscript
class_name TestAudioMarkers
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioMarkerClass = preload("res://addons/opendou/resources/audio_marker.gd")
const WavMarkersClass = preload("res://addons/opendou/runtime/wav_markers.gd")
const SynthClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

## WAV minimo de 16 bits con dos cues etiquetados, escrito por el test.
static func _write_wav_with_cues(path: String) -> void:
	var rate: int = 44100
	var frames: int = rate   # 1 s de silencio
	var pcm := PackedByteArray()
	pcm.resize(frames * 2)
	var buf := StreamPeerBuffer.new()
	buf.big_endian = false
	# fmt
	var fmt := StreamPeerBuffer.new()
	fmt.put_u16(1); fmt.put_u16(1); fmt.put_u32(rate); fmt.put_u32(rate * 2); fmt.put_u16(2); fmt.put_u16(16)
	# cue: dos puntos a 0.25 s y 0.75 s
	var cue := StreamPeerBuffer.new()
	cue.put_u32(2)
	for entry in [[1, int(rate * 0.25)], [2, int(rate * 0.75)]]:
		cue.put_u32(entry[0]); cue.put_u32(entry[1]); cue.put_data("data".to_ascii_buffer()); cue.put_u32(0); cue.put_u32(0); cue.put_u32(entry[1])
	# LIST/adtl con labl
	var adtl := StreamPeerBuffer.new()
	adtl.put_data("adtl".to_ascii_buffer())
	for entry in [[1, "Golpe"], [2, "Eco"]]:
		var text: PackedByteArray = (entry[1] as String).to_ascii_buffer()
		text.append(0)
		if text.size() % 2 == 1:
			text.append(0)
		adtl.put_data("labl".to_ascii_buffer()); adtl.put_u32(4 + text.size()); adtl.put_u32(entry[0]); adtl.put_data(text)
	var chunks := StreamPeerBuffer.new()
	for c in [["fmt ", fmt.data_array], ["cue ", cue.data_array], ["LIST", adtl.data_array], ["data", pcm]]:
		chunks.put_data((c[0] as String).to_ascii_buffer()); chunks.put_u32((c[1] as PackedByteArray).size()); chunks.put_data(c[1])
	buf.put_data("RIFF".to_ascii_buffer()); buf.put_u32(4 + chunks.data_array.size()); buf.put_data("WAVE".to_ascii_buffer()); buf.put_data(chunks.data_array)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(buf.data_array)
	f.close()

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("audio_markers")
	# Lector de cues.
	var path := "user://opendou_cues_test.wav"
	_write_wav_with_cues(path)
	var markers: Array = WavMarkersClass.read_cues(path)
	a.eq(markers.size(), 2, "el WAV generado tiene dos cues")
	if markers.size() == 2:
		a.eq(String(markers[0].name), "Golpe", "el primero se llama Golpe")
		a.approx(markers[0].time_sec, 0.25, "y esta a 0.25 s", 0.001)
		a.eq(String(markers[1].name), "Eco", "el segundo se llama Eco")
		a.approx(markers[1].time_sec, 0.75, "y esta a 0.75 s", 0.001)
	a.eq(WavMarkersClass.read_cues("user://no_existe.wav").size(), 0, "un archivo inexistente da una lista vacia")

	# Marcador autorado: la senal llega a tiempo, y en bucle vuelve en la segunda vuelta.
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var def = AudioEventDefClass.new(&"Marked", SynthClass.create_rain_ambient_loop(1.0))
	def.is_looping = true
	def.stream_length = 1.0
	var m := AudioMarkerClass.new()
	m.name = &"Medio"
	m.time_sec = 0.5
	def.markers = [m]
	manager.register_event_definition(def)
	var hits: Array = []
	var t0: int = Time.get_ticks_msec()
	var inst = manager.post_event(def, null)
	inst.marker_reached.connect(func(n): hits.append([n, Time.get_ticks_msec() - t0]))
	while Time.get_ticks_msec() - t0 < 1700:
		await tree.process_frame
	a.eq(hits.size(), 2, "el marcador de 0.5 s suena dos veces en 1.7 s de bucle de 1 s")
	if hits.size() >= 1:
		a.eq(String(hits[0][0]), "Medio", "con su nombre")
		a.ok(hits[0][1] >= 430 and hits[0][1] <= 650, "la primera vez entre 0.43 y 0.65 s (medido %d ms)" % hits[0][1])
	if hits.size() >= 2:
		a.ok(hits[1][1] >= 1400 and hits[1][1] <= 1700, "la segunda tras envolver el bucle (medido %d ms)" % hits[1][1])
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return a
```

Registrar `TestAudioMarkersClass.run_all_async`. Run → rojo.

- [ ] **Step 2: Lector RIFF**

```gdscript
class_name OpenDouWavMarkers
extends RefCounted

## Lee los marcadores (chunk `cue`) de un archivo WAV en disco, con sus etiquetas
## (LIST/adtl/labl), y los devuelve como AudioMarker en segundos. AudioStreamWAV no conserva
## estos chunks, por eso se lee el archivo original.

const AudioMarkerClass = preload("res://addons/opendou/resources/audio_marker.gd")

static func read_cues(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return out
	var rate: int = 44100
	var cues: Dictionary = {}   # id -> muestra
	var labels: Dictionary = {} # id -> nombre
	var pos: int = 12
	while pos + 8 <= bytes.size():
		var cid: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(pos + 4)
		var body: int = pos + 8
		match cid:
			"fmt ":
				rate = bytes.decode_u32(body + 4)
			"cue ":
				var count: int = bytes.decode_u32(body)
				for i in range(count):
					var e: int = body + 4 + i * 24
					cues[bytes.decode_u32(e)] = bytes.decode_u32(e + 20)
			"LIST":
				if bytes.slice(body, body + 4).get_string_from_ascii() == "adtl":
					var p: int = body + 4
					while p + 8 <= body + size:
						var sub: String = bytes.slice(p, p + 4).get_string_from_ascii()
						var sub_size: int = bytes.decode_u32(p + 4)
						if sub == "labl":
							var cue_id: int = bytes.decode_u32(p + 8)
							var text: PackedByteArray = bytes.slice(p + 12, p + 8 + sub_size)
							var end: int = text.find(0)
							labels[cue_id] = (text.slice(0, end) if end >= 0 else text).get_string_from_ascii()
						p += 8 + sub_size + (sub_size % 2)
		pos = body + size + (size % 2)
	var ids: Array = cues.keys()
	ids.sort_custom(func(x, y): return cues[x] < cues[y])
	for cue_id in ids:
		var mk = AudioMarkerClass.new()
		mk.name = StringName(str(labels.get(cue_id, "cue_%d" % cue_id)))
		mk.time_sec = float(cues[cue_id]) / float(maxi(rate, 1))
		out.append(mk)
	return out
```

- [ ] **Step 3: La señal en la instancia**

`signal marker_reached(name: StringName)` y `var _last_marker_position: float = 0.0`. Al final de `update_parameters` (antes de `calculated_volume_db = vol`) no: el reloj lógico avanza en dos sitios (`advance_virtual_time` para virtuales y el bloque de físicas de la obs 31). Se centraliza: nueva función `_emit_markers_crossed(previous: float, current: float, wrapped: bool)` llamada en ambos sitios tras mover `logical_playback_position`:

```gdscript
## Emite los marcadores cuyo tiempo quedo entre la posicion anterior y la actual. Si el
## bucle envolvio, los del tramo final y los del tramo inicial.
func _emit_markers_crossed(previous: float, current: float, wrapped: bool) -> void:
	if definition == null or definition.markers.is_empty():
		return
	for mk in definition.markers:
		if mk == null:
			continue
		var t: float = mk.time_sec
		var hit: bool = (not wrapped and t > previous and t <= current) or (wrapped and (t > previous or t <= current))
		if hit:
			marker_reached.emit(mk.name)
```

En el bloque de físicas (obs 31) y en `advance_virtual_time` (`VIRTUAL_ELAPSED_TIME`): guardar `var before: float = logical_playback_position`, avanzar, detectar `wrapped` cuando se aplica `fmod`, y llamar `_emit_markers_crossed(before, logical_playback_position, wrapped)`.

- [ ] **Step 4: Verde y commit**

```bash
./run_tests.sh
git add addons/opendou/runtime/wav_markers.gd addons/opendou/runtime/wav_markers.gd.uid addons/opendou/runtime/event_instance.gd tests/test_audio_markers.gd tests/test_audio_markers.gd.uid tests/test_all.gd
git commit -m "Fase 9: marcadores de audio autorados y leidos del chunk cue, con senal marker_reached"
```

---

### Task 7: Flujo del spline

**Files:**
- Modify: `addons/opendou/nodes/opendou_spline_emitter_3d.gd`
- Create: `tests/test_spline_flow.gd`, registrar

**Interfaces:**
- Produces: `@export var flow_speed_mps: float = 0.0`; `func get_flow_velocity_at(listener_pos: Vector3) -> Vector3` (tangente × velocidad); `update_spline_acoustics` suma la velocidad de flujo a la del emisor virtual al calcular el doppler.

- [ ] **Step 1: Test (rojo)**

```gdscript
class_name TestSplineFlow
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spline_flow")
	var SplineScript = load("res://addons/opendou/nodes/opendou_spline_emitter_3d.gd")
	var spline = SplineScript.new()
	var c := Curve3D.new()
	c.add_point(Vector3(0, 0, 0))
	c.add_point(Vector3(100, 0, 0))   # el rio corre hacia +X
	spline.curve = c
	spline.enable_doppler = true
	spline.base_pitch_scale = 1.0
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(spline)
	spline.reanchor()
	# Oyente aguas abajo (+X, a un lado): el flujo se acerca -> tono > 1.
	spline.flow_speed_mps = 20.0
	var downstream := Vector3(80, 0, 5)
	var flow: Vector3 = spline.get_flow_velocity_at(downstream)
	a.ok(flow.is_equal_approx(Vector3(20, 0, 0)), "la velocidad de flujo es la tangente por la velocidad")
	spline.update_spline_acoustics(downstream, Vector3.ZERO, 0.016)
	spline.update_spline_acoustics(downstream, Vector3.ZERO, 0.016)
	var pitch_down: float = spline.pitch_scale
	# Aguas arriba (-X del punto mas cercano): el flujo se aleja -> tono < 1.
	spline.flow_speed_mps = -20.0
	spline.update_spline_acoustics(downstream, Vector3.ZERO, 0.016)
	spline.update_spline_acoustics(downstream, Vector3.ZERO, 0.016)
	var pitch_up: float = spline.pitch_scale
	spline.flow_speed_mps = 0.0
	spline.update_spline_acoustics(downstream, Vector3.ZERO, 0.016)
	spline.update_spline_acoustics(downstream, Vector3.ZERO, 0.016)
	var pitch_none: float = spline.pitch_scale
	print("[OpenDou] flujo del spline: hacia el oyente %.3f, alejandose %.3f, sin flujo %.3f" % [pitch_down, pitch_up, pitch_none])
	a.gt(pitch_down, 1.02, "el flujo hacia el oyente sube el tono")
	a.lt(pitch_up, 0.98, "el flujo alejandose lo baja")
	a.approx(pitch_none, 1.0, "sin flujo, tono base", 0.02)
	tree.root.remove_child(spline)
	spline.free()
	return a
```

Nota: el punto más cercano a (80, 0, 5) es (80, 0, 0); el vector emisor→oyente es (0, 0, 5), **perpendicular** al flujo, así que el doppler radial sería 0. El test necesita un oyente con componente a lo largo del río: usar `downstream = Vector3(120, 0, 5)`, cuyo punto más cercano es el extremo (100, 0, 0) y el vector (20, 0, 5) sí tiene componente en +X. Corregir las tres llamadas antes de ejecutar.

Registrar en `run_suite` (síncrono). Run → rojo (`flow_speed_mps` inexistente).

- [ ] **Step 2: El export y la tangente**

```gdscript
## Velocidad del flujo a lo largo de la curva, en m/s (rios, cintas). Positiva en el sentido
## de la curva. Entra en el doppler: un rio que corre hacia el oyente sube el tono.
@export var flow_speed_mps: float = 0.0

## Velocidad del flujo en el punto de la curva mas cercano al oyente: tangente x velocidad.
func get_flow_velocity_at(listener_pos: Vector3) -> Vector3:
	if curve == null or curve.point_count < 2 or is_zero_approx(flow_speed_mps):
		return Vector3.ZERO
	var anchor: Transform3D = get_curve_anchor()
	var local_listener: Vector3 = anchor.affine_inverse() * listener_pos
	var offset: float = curve.get_closest_offset(local_listener)
	var sample: Transform3D = curve.sample_baked_with_rotation(offset, false, true)
	var tangent_local: Vector3 = -sample.basis.z
	return (anchor.basis * tangent_local).normalized() * flow_speed_mps
```

En `update_spline_acoustics`, la velocidad del emisor pasa a `var emitter_vel = (global_position - _prev_emitter_pos) / maxf(0.001, delta) + get_flow_velocity_at(listener_pos)`.

- [ ] **Step 3: Verde y commit**

```bash
./run_tests.sh
git add addons/opendou/nodes/opendou_spline_emitter_3d.gd tests/test_spline_flow.gd tests/test_spline_flow.gd.uid tests/test_all.gd
git commit -m "Fase 9: flujo del spline en su doppler (obs 47: el spline sigue fuera del sistema de voces)"
```

---

### Task 8: Documentos y observación 47

**Files:**
- Modify: `docs/funcionalidades.md` (spline a 🟡 con la razón; exports nuevos en la fila del emisor 3D; sección 3.2 con retardo y campo cercano), `AGENTS.md` (obs 47 y trampas), `docs/tasks/current.md`, spec §17 (correcciones si las hubo)

- [ ] **Step 1: Editar y confirmar**

`AGENTS.md`, tras las trampas de la Fase 8:

```markdown
**Observaciones y trampas de la Fase 9 (el emisor completo):**

* **Observación 47.** `OpenDouSplineEmitter3D` hereda de `AudioStreamPlayer3D` y **no pasa por
  el sistema de voces**: no postea eventos, lleva su propio doppler y su propia absorción del
  aire, y en `steam_audio` no es binaural. Incorporarlo al sistema (posición virtual como
  emisor de nodo) es una tarea propia, pendiente.
* **Doppler por tono y retardo físico no se suman.** En `steam_audio`, con
  `propagation_delay_enabled` la rampa de la línea de retardo produce el doppler y el factor
  de tono se fuerza a 1.
* **El ajuste de mezcla HRTF del jugador es un factor**, no un valor: el canal escribe
  `default_spatial_blend × (1 − spread)` en cada voz ocupada; el menú solo toca los libres.
* **Godot: `Curve3D.sample_baked_with_rotation` da la tangente como `−basis.z`.**
```

Correr la suite, el banco (`tools/bench_control_loop.gd`) y anotar en el spec el coste. Commit:

```bash
git add docs/funcionalidades.md AGENTS.md docs/tasks/current.md docs/superpowers/specs/2026-09-02-fase9-emisor-completo-design.md
git commit -m "Fase 9: documentos al dia; observacion 47"
```

---

## Autorrevisión del plan

**Cobertura del spec.** §2 exports → Task 1; §3 doppler → Task 2; §4 retardo → Task 5; §5 spread → Task 4; §6 campo cercano → Task 4; §7 directividad → Task 2; §8 spline → Task 7; §9 curva → Task 3; §10 marcadores → Task 6; §11 componentes → todas; §12 casos límite: teletransporte (Task 2, `update_motion`), retardo acotado al máximo (Task 5, clamp del setter), distancia 0 (dirección frontal ya existente; spread y nf a 1 por el clamp), forward degenerado (Task 2, `directivity_db` devuelve 0), curva nula (Task 3, 0 dB), marcadores fuera de duración (Task 6, nunca se cruzan) y WAV sin `cue` (lista vacía); §13 verificación → suites por tarea; §14 aceptación → 1 (Tasks 2 y 5), 2 (Tasks 2 y 4), 3 (Task 3), 4 (Task 6), 5 (Task 7), 6 (Task 8).

**Marcadores.** Ninguno. El único texto que depende de la ejecución es el coste del banco en la Task 8.

**Consistencia de nombres.** `copy_emitter_settings_from_player`, `set_orientation`, `emitter_forward`, `update_motion`, `doppler_pitch`, `emitter_velocity`, `flow_velocity` (Tasks 1, 2); `OpenDouDistanceModel.directivity_db(forward, to_listener, dipole_weight, power)` y `MODEL_CURVE` con la firma ampliada de `attenuation_db/multiplier/gain_db_for_stream` (Tasks 2, 3, 4); propiedades del stream `near_field_bass_db`, `near_field_ild_db`, `propagation_delay_sec` y estática `configure_max_propagation_delay` (Tasks 4, 5); `play_stream(..., start_delay_sec)` (Task 5); `marker_reached`, `_emit_markers_crossed` (Task 6); `flow_speed_mps`, `get_flow_velocity_at` (Task 7); ayudantes de test `_tone`, `_estimate_frequency_hz`, `_wait_ms` definidos en la Task 2 y usados en 3, 4 y 5.

**Riesgo al ejecutar.** El estimador por cruces por cero exige que la voz esté sola en el bus y que el tono no tenga graves añadidos: por eso las pruebas de doppler y retardo usan un seno y atenuación desactivada. La directividad usa ruido periódico y RMS.
