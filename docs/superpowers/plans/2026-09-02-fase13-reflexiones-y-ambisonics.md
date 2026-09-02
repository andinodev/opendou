# Fase 13 — Reflexiones y ambisonics: plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reverb por convolución trazado contra la geometría real (centrado en el oyente, en hilo propio), camas ambisónicas que rotan con la cabeza, salida por el dispositivo en modo altavoces, y los reflectores autorados como ajuste artístico.

**Architecture:** El simulador de la Fase 12 gana `REFLECTIONS` (HYBRID) y un hilo que corre `iplSimulatorRunReflections` para una fuente colocada en el oyente por sala; un `AudioEffect` nativo en el bus de reverb de la sala aplica la IR (seco + húmedo, compatible con la observación 49) y publica los RT60 reales para el fallback de Sabine. Un stream nativo ambisónico rota y decodifica al HRTF; un nodo lo hospeda. En surround, Godot panea la señal procesada del anfitrión.

**Tech Stack:** Godot 4.7.2, GDExtension C++17, Steam Audio 4.8.1, CMake, suite headless.

**Spec:** `docs/superpowers/specs/2026-09-02-fase13-reflexiones-y-ambisonics-design.md` · **Observaciones a resolver antes:** `docs/tasks/observaciones-fases-12-14.md` (A4–A8, **B5 con su spike**, B6–B9).

## Global Constraints

- Los de la Fase 12 (rama, commits, suite, omisión con aviso sin extensión, bus de sonda, CMake).
- **`iplSimulatorCommit` solo en el hilo principal y nunca mientras `running_` es verdadero.**
- El hilo de simulación no toca objetos de Godot: solo estructuras de Steam Audio y atómicos.
- Todo recurso nativo nuevo (efectos, streams) se libera: el contador de fugas de la suite es la guarda.

---

## Estructura de archivos

| Archivo | Responsabilidad |
|---|---|
| `native/src/simulator.{h,cpp}` | `REFLECTIONS`, fuente de oyente, hilo, `reverb_times`, IR para el efecto |
| `native/src/convolution_reverb.{h,cpp}` | `OpenDouConvolutionReverb` (`AudioEffect`) + instancia |
| `native/src/ambisonic_stream.{h,cpp}` | `OpenDouAmbisonicStream` + playback |
| `native/src/spatial_stream.{h,cpp}` | `output_mode = MONO_PASS` |
| `addons/opendou/resources/ambisonic_audio.gd` | recurso con canales |
| `addons/opendou/runtime/wav_decoder.gd` | `read_multichannel(path)` |
| `addons/opendou/nodes/opendou_ambisonic_bed_3d.gd` | nodo cama |
| `addons/opendou/nodes/opendou_room_3d.gd`, `runtime/spatial/reverb_bus_pool.gd`, `runtime/spatial/audio_room.gd` | `CONVOLUTION` |
| `addons/opendou/runtime/audio_event_manager.gd` | fuente de oyente por sala, orientación a camas, dispatcher |
| `addons/opendou/runtime/native_player_pool.gd`, `physical_voice_channel.gd` | anfitrión en surround |
| `addons/opendou/runtime/reflection_dispatcher.gd` | `enabled` |
| tests | `test_native_effect_spike.gd`, `test_reflections_thread.gd`, `test_convolution_reverb.gd`, `test_ambisonic_bed.gd`, `test_speaker_output_mode.gd` |

---

### Task 0 (spike B5, una hora): un `AudioEffect` nativo de ganancia

**Files:** `native/src/gain_effect_spike.{h,cpp}` (se borra al final de la fase o se queda como ejemplo), `tests/test_native_effect_spike.gd`.

- [ ] **Step 1: Test** — bus de sonda con un `OpenDouGainEffect` (`gain_db = -12`) y un tono de −6 dBFS: el pico medido es −18 ±0.5; quitar el efecto devuelve −6.
- [ ] **Step 2: Implementar**
```cpp
class OpenDouGainEffect : public godot::AudioEffect {
	GDCLASS(OpenDouGainEffect, godot::AudioEffect)
public:
	float gain_db = 0.0f;
	void set_gain_db(float v) { gain_db = v; }
	float get_gain_db() const { return gain_db; }
	godot::Ref<godot::AudioEffectInstance> _instantiate() override;
protected:
	static void _bind_methods();  // propiedad gain_db
};
class OpenDouGainEffectInstance : public godot::AudioEffectInstance {
	GDCLASS(OpenDouGainEffectInstance, godot::AudioEffectInstance)
public:
	godot::Ref<OpenDouGainEffect> base;
	void _process(const void *p_src_frames, godot::AudioFrame *p_dst_frames, int32_t p_frame_count) override {
		const godot::AudioFrame *src = static_cast<const godot::AudioFrame *>(p_src_frames);
		const float g = std::pow(10.0f, base->gain_db / 20.0f);
		for (int i = 0; i < p_frame_count; i++) { p_dst_frames[i].left = src[i].left * g; p_dst_frames[i].right = src[i].right * g; }
	}
	bool _process_silence() const override { return false; }
protected:
	static void _bind_methods() {}
};
```
Si la firma de `_process` en godot-cpp 4.7 difiere (`const void *` frente a `const AudioFrame *`), adaptar y **anotar en observaciones B5**. Si el efecto no se puede instanciar desde GDScript (`OpenDouGainEffect.new()`), la Fase 13 cambia de forma: la convolución iría en el stream (por voz) y hay que reabrir A4/A5.
- [ ] **Step 3: Commit** — `git commit -m "Fase 13: spike B5: un AudioEffect nativo funciona en un bus"`

---

### Task 1: Reflexiones en hilo (`REFLECTIONS`, fuente de oyente, `reverb_times`)

**Files:** `native/src/simulator.{h,cpp}`; test `tests/test_reflections_thread.gd`.

**Interfaces:**
- Produces: `OpenDouSimulator.configure(max_sources, occlusion_samples, transmission_rays, with_reflections: bool = false, max_duration: float = 2.0, max_rays: int = 4096)`; `create_listener_source() -> int`; `set_listener_source_position(handle, position)`; `start_reflections(hz: float)`, `stop_reflections()`, `is_reflections_running() -> bool`; `get_reverb_times(handle) -> Vector3`; `reflections_generation(handle) -> int`; C++: `bool copy_reflection_params(int handle, IPLReflectionEffectParams &out)` (mutex) para el efecto.

- [ ] **Step 1: Test en rojo**

```gdscript
class_name TestReflectionsThread
extends RefCounted

## Fase 13: la IR de la sala del oyente se traza en un hilo y sus RT60 dependen del material.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestSteamSceneClass = preload("res://tests/test_steam_scene.gd")
const BakeScript = preload("res://addons/opendou/nodes/opendou_acoustic_geometry_bake.gd")

## Caja cerrada de 6 x 3 x 6 con seis paredes del material.
static func make_box_room(tree: SceneTree, material: StringName) -> Array:
	var walls: Array = []
	var specs: Array = [[Vector3(0, -0.15, 0), Vector3(6, 0.3, 6)], [Vector3(0, 3.15, 0), Vector3(6, 0.3, 6)], [Vector3(-3.15, 1.5, 0), Vector3(0.3, 3, 6)], [Vector3(3.15, 1.5, 0), Vector3(0.3, 3, 6)], [Vector3(0, 1.5, -3.15), Vector3(6, 3, 0.3)], [Vector3(0, 1.5, 3.15), Vector3(6, 3, 0.3)]]
	for sp in specs:
		var body := StaticBody3D.new()
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = sp[1]
		mi.mesh = box
		mi.add_to_group("AcousticObstacle")
		mi.set_meta("acoustic_material", material)
		body.add_child(mi)
		tree.root.add_child(body)
		body.global_position = sp[0]
		walls.append(body)
	return walls

static func _rt60_of(tree: SceneTree, material: StringName) -> float:
	var walls: Array = make_box_room(tree, material)
	var bake = BakeScript.new()
	bake.auto_bake_on_ready = false
	tree.root.add_child(bake)
	bake.bake_geometry(tree.root)
	bake.export_to_native()
	OpenDouSimulator.configure(8, 16, 2, true, 2.0, 4096)
	var h: int = OpenDouSimulator.create_listener_source()
	OpenDouSimulator.set_listener(Vector3(0, 1.5, 0), Vector3(0, 0, -1), Vector3.UP)
	OpenDouSimulator.set_listener_source_position(h, Vector3(0, 1.5, 0))
	OpenDouSimulator.start_reflections(10.0)
	var gen0: int = OpenDouSimulator.reflections_generation(h)
	var t0: int = Time.get_ticks_msec()
	while OpenDouSimulator.reflections_generation(h) == gen0 and Time.get_ticks_msec() - t0 < 3000:
		await tree.process_frame
	var rt: Vector3 = OpenDouSimulator.get_reverb_times(h)
	OpenDouSimulator.stop_reflections()
	OpenDouSimulator.release_source(h)
	tree.root.remove_child(bake); bake.free()
	for w in walls:
		tree.root.remove_child(w); w.free()
	OpenDouAcousticScene.clear()
	print("[OpenDou] RT60 trazado en caja de %s: %.2f / %.2f / %.2f s" % [material, rt.x, rt.y, rt.z])
	return rt.y

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("reflections_thread")
	if not TestSteamSceneClass._native() or not ClassDB.class_exists("OpenDouSimulator"):
		print("[OpenDou] extension nativa AUSENTE: reflexiones omitidas")
		return a
	var metal: float = await _rt60_of(tree, &"Metal")
	var wood: float = await _rt60_of(tree, &"Wood")
	a.gt(metal, 0.05, "la caja de metal tiene RT60 (llego un resultado del hilo)")
	a.gt(metal, wood * 1.3, "y es al menos un 30 %% mas largo que la de madera (%.2f frente a %.2f)" % [metal, wood])
	a.ok(not OpenDouSimulator.is_reflections_running(), "el hilo se detuvo")
	return a
```
(Las clases nativas se usan por nombre; envolver el archivo en `if ClassDB.class_exists` ya lo hace `_native()`; si el parser se queja de nombres nativos no cargados en el backend godot, usar `ClassDB.class_call_static`.)

- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar.** `configure(..., with_reflections, max_duration, max_rays)`: `flags |= REFLECTIONS`, `reflectionType = HYBRID`, `maxNumRays`, `numDiffuseSamples = 32`, `maxDuration`, `maxOrder = 1`, `numThreads = 2`, `rayBatchSize = 16`. `iplSimulatorSetSharedInputs(REFLECTIONS, {listener, numRays = 2048, numBounces = 16, duration = max_duration, order = 1, irradianceMinDistance = 1.0})` en `set_listener`. Fuente de oyente: `IPLSourceSettings{flags = REFLECTIONS}`; `set_listener_source_position` fija `IPLSimulationInputs{flags = REFLECTIONS, source = space(pos, −Z, UP), reverbScale = {1,1,1}, hybridReverbTransitionTime = 1.0, hybridReverbOverlapPercent = 0.25}`. Hilo:
```cpp
void OpenDouSimulator::start_reflections(float hz) {
	if (sim_ == nullptr || thread_.joinable()) return;
	period_ms_ = static_cast<int>(1000.0f / std::max(hz, 0.5f));
	stop_flag_ = false;
	thread_ = std::thread([]() {
		while (!stop_flag_.load()) {
			{ std::lock_guard<std::mutex> lk(commit_mutex_); if (dirty_commit_) { iplSimulatorCommit(sim_); dirty_commit_ = false; } running_ = true; }
			iplSimulatorRunReflections(sim_);
			{ std::lock_guard<std::mutex> lk(outputs_mutex_);
			  for (size_t i = 0; i < sources_.size(); i++) if (sources_[i] != nullptr && (flags_[i] & IPL_SIMULATIONFLAGS_REFLECTIONS)) { iplSourceGetOutputs(sources_[i], IPL_SIMULATIONFLAGS_REFLECTIONS, &refl_outputs_[i]); refl_generation_[i]++; } }
			running_ = false;
			std::this_thread::sleep_for(std::chrono::milliseconds(period_ms_));
		}
	});
}
```
`create_source`/`release_source` toman `commit_mutex_` y marcan `dirty_commit_` (el commit lo hace quien llegue primero: el hilo entre corridas o `run_direct` en el principal, ambos bajo el mutex). `get_reverb_times(h)` → `refl_outputs_[h].reflections.reverbTimes`. `stop_reflections` pone la bandera y `join`. `copy_reflection_params` copia bajo `outputs_mutex_` (la IR es un handle que Steam Audio actualiza internamente; el efecto la usa desde el hilo de audio, como manda la API: `iplReflectionEffectApply` acepta los `params` del último `GetOutputs`).

- [ ] **Step 4: Compilar, correr** → verde; anotar los RT60 medidos en el spec §11.
- [ ] **Step 5: Commit** — `git commit -m "Fase 13: reflexiones HYBRID en hilo propio con fuente de oyente y RT60 por banda"`

---

### Task 2: `OpenDouConvolutionReverb` y `reverb_mode = CONVOLUTION`

**Files:** `native/src/convolution_reverb.{h,cpp}`, `native/src/steam_audio_context.{h,cpp}` (acceso al HRTF para el decodificador), `nodes/opendou_room_3d.gd`, `runtime/spatial/reverb_bus_pool.gd`, `runtime/spatial/audio_room.gd`, `runtime/audio_event_manager.gd`; test `tests/test_convolution_reverb.gd`.

**Interfaces:**
- Produces: efecto `OpenDouConvolutionReverb` con `dry: float`, `wet: float`, `room_handle: int`; `OpenDouReverbBusPool.install_convolution(bus: StringName, room_handle: int) -> bool` / `install_sabine(bus, rt60, absorption)`; `OpenDouRoom3D.ReverbMode.CONVOLUTION`; manager `listener_source_for_room(room_name) -> int` (crea y mueve la fuente de oyente por sala del oyente), `get_room_reverb_times(room_name) -> Vector3`.

- [ ] **Step 1: Test en rojo** — dos cajas (`make_box_room`, Metal y Wood) alternas con una `OpenDouRoom3D` `CONVOLUTION` que cubre la caja, un manager steam_audio con el oyente dentro, `start_reflections`; esperar resultado; tono de 50 ms posteado dentro (bus de reverb de la sala = donde llega la voz, observación 49); capturar 1.5 s y medir T20 con `OpenDouIRRT60Analyzer.rt60_from_ir` sobre la cola (envolver la captura en un `AudioStreamWAV` mono): metal > madera × 1.3; con `wet = 0` la salida iguala a la entrada ±0.5 dB (comparar RMS del tono con y sin efecto); sin extensión (`ProjectSettings backend = godot`), `reverb_mode = CONVOLUTION` deja un `AudioEffectReverb` en el bus y `get_assigned_reverb_bus()` no está vacío.
- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar.**
  - Efecto: `OpenDouConvolutionReverb : AudioEffect` (propiedades `dry`, `wet`, `room_handle`), instancia con `IPLReflectionEffect` (`type = HYBRID, irSize = maxDuration·rate, numChannels = 4`), `IPLAmbisonicsDecodeEffect` (`maxOrder = 1`, `speakerLayout = STEREO`, `hrtf` del contexto), búferes `in (1 ch)`, `amb (4 ch)`, `out (2 ch)`. `_process`: mono = (L+R)/2 → `iplReflectionEffectApply(effect, &params, &in, &amb, nullptr)` con `params` de `OpenDouSimulator::copy_reflection_params(room_handle, p)` (si no hay resultado, solo seco) → `iplAmbisonicsDecodeEffectApply({orientation = identidad, order = 1, hrtf, binaural = true}, &amb, &out)` → `dst = dry·src + wet·out`. HRTF con `acquire_hrtf/release_hrtf` por bloque (B8).
  - Pool: `install_convolution(bus, room_handle)`: quita el `AudioEffectReverb` del bus y añade `OpenDouConvolutionReverb` marcado `OpenDou_ConvReverb` (`wet` = `reverb_send_amount` de la sala, `dry = 1.0`); `install_sabine` es el camino de hoy (`_make_reverb`).
  - Sala: `ReverbMode.CONVOLUTION`; en `_route_native_reverb`, si `CONVOLUTION` y `ClassDB.class_exists("OpenDouConvolutionReverb")` y la escena está lista: pide al manager `listener_source_for_room(room_name)` y al pool `install_convolution(bus, handle)`; si no, Sabine con `reverb_decay_time = manager.get_room_reverb_times(room_name).y` si es > 0 (RT60 real conocido) o el de Sabine.
  - Manager: `_update_environment` o un paso nuevo `_update_listener_room()`: sala del oyente (`spatial_acoustics.get_room_at_position`); una fuente de oyente por sala visitada (`_room_listener_sources: Dictionary`), `set_listener_source_position(handle, listener_pos)` solo para la sala actual; `start_reflections(10)` la primera vez que hay una sala `CONVOLUTION`; `stop_reflections` en `_exit_tree`.
- [ ] **Step 4: Compilar, correr** → verde; anotar T20 medidos.
- [ ] **Step 5: Commit** — `git commit -m "Fase 13: reverb por convolucion en el bus de la sala (AudioEffect nativo) y reverb_mode = CONVOLUTION con RT60 real para el fallback"`

---

### Task 3: Camas ambisónicas

**Files:** `runtime/wav_decoder.gd` (`read_multichannel`), `resources/ambisonic_audio.gd`, `native/src/ambisonic_stream.{h,cpp}`, `nodes/opendou_ambisonic_bed_3d.gd`, `runtime/audio_event_manager.gd` (`register_ambisonic_bed`, orientación por cuadro); test `tests/test_ambisonic_bed.gd`.

**Interfaces:**
- Produces: `OpenDouWavDecoder.read_multichannel(path) -> Dictionary {channels: Array[PackedFloat32Array], mix_rate: int}`; `OpenDouAmbisonicAudio` (`order`, `channels`, `mix_rate`, `loop`, `static from_wav_file(path)`, `static encode_point(mono: PackedFloat32Array, direction: Vector3, mix_rate, order = 1) -> OpenDouAmbisonicAudio` para los tests); `OpenDouAmbisonicStream` (`audio`, `listener_basis: Basis`, `spatial_blend`); `OpenDouAmbisonicBed3D` (`audio`, `autoplay`), `set_listener_basis(b)`.

- [ ] **Step 1: Test en rojo** — una fuente sintetizada al frente (ruido periódico codificado con `encode_point(noise, Vector3(0, 0, -1))`: SN3D orden 1: W = x, Y = x·dir.y…; usar la fórmula ACN/SN3D: `[W = s, Y = s·y, Z = s·z, X = s·x]` con `x = dir.x, y = dir.y, z = -dir.z` en la convención de Steam Audio: la orientación se comprueba con el propio test); cama en un bus de sonda; manager steam_audio con `OpenDouListener3D`; ILD ≈ 0 (< 1.5 dB) con el oyente mirando a −Z; `listener.set_external_orientation(Basis(Vector3.UP, PI/2))` → ILD > 6 dB positiva (fuente a la derecha); `-PI/2` → negativa; sin extensión, `OpenDouAmbisonicBed3D` reproduce el canal W en mono (RMS > −40 dB en el bus).
- [ ] **Step 2: Correr y ver el fallo.**
- [ ] **Step 3: Implementar.** Decoder: leer `fmt` (`numChannels`, bits 16/24, rate) y `data`, desentrelazar. Recurso con `channels` y `encode_point` (SN3D orden 1, factores 1). Stream nativo: `_mix` lee `order`, toma un bloque de cada canal (posición de lectura propia, `loop`), `IPLAmbisonicsRotationEffect` con `orientation` = espacio del oyente invertido (`right/up/ahead` desde `listener_basis`), luego `IPLAmbisonicsDecodeEffect` (`binaural = true`, HRTF del contexto; en modo altavoces `binaural = false`, `speakerLayout = STEREO`). Nodo: `AudioStreamPlayer` con script; en `_ready` (fuera del editor) si la extensión está: `stream = OpenDouAmbisonicStream.new(); stream.audio = audio`; si no: `stream = AudioStreamWAV` construido con el canal W (16 bits) y `push_warning` una vez; se registra en el manager, que en `_process` llama `set_listener_basis(active_listener_basis)` a cada cama.
- [ ] **Step 4: Compilar, correr** → verde; si el signo de la ILD sale invertido, ajustar la convención en `encode_point` y anotar (B10 hermano).
- [ ] **Step 5: Commit** — `git commit -m "Fase 13: camas ambisonicas: recurso, stream nativo con rotacion y decodificacion HRTF, nodo OpenDouAmbisonicBed3D"`

---

### Task 4: Salida por el dispositivo en modo altavoces

**Files:** `native/src/spatial_stream.{h,cpp}` (`OUTPUT_MONO_PASS = 2`), `runtime/native_player_pool.gd`, `runtime/physical_voice_channel.gd`, `runtime/audio_event_manager.gd` (`_apply_spatial_settings`); test `tests/test_speaker_output_mode.gd`.

- [ ] **Step 1: Test** — con el manager en steam_audio: `spatial_settings.set_output("speakers")`; si `AudioServer.get_speaker_mode() == SPEAKER_MODE_STEREO` (headless): los anfitriones siguen con `panning_strength == 0` y `output_mode == 1` (altavoces estéreo propios); se fuerza la decisión con `manager.surround_available = true` (propiedad de prueba que sustituye la lectura del servidor): los anfitriones ocupados pasan a `panning_strength == 1` y `output_mode == 2` (`MONO_PASS`); `set_output("headphones")` los devuelve.
- [ ] **Step 2: Implementar.** Stream: `OUTPUT_MONO_PASS`: la señal mono procesada se copia a L y R sin HRTF, ITD ni paneo. Manager: `var surround_available: bool = AudioServer.get_speaker_mode() != AudioServer.SPEAKER_MODE_STEREO` al arrancar; en `_apply_spatial_settings`, `mode = 2 if output == speakers and surround_available else (1 if speakers else 0)`; `player_pool.default_panning_strength = 1.0 if mode == 2 else 0.0`, aplicado a los anfitriones (`for_each_host`), y el canal respeta `default_panning_strength` en vez de fijar 0 (comprobar dónde se neutraliza: `native_player_pool._instantiate` y `apply_spatial`).
- [ ] **Step 3: Compilar, correr, commit** — `git commit -m "Fase 13: modo altavoces surround: Godot panea la senal procesada (MONO_PASS) cuando el dispositivo no es estereo"`

---

### Task 5: `ReflectionDispatcher.enabled` y reflectores como ajuste artístico

**Files:** `runtime/reflection_dispatcher.gd`, `runtime/audio_event_manager.gd`; test: `tests/test_early_reflections.gd` sigue verde + una aserción nueva en `test_convolution_reverb.gd`: con la sala en `CONVOLUTION`, `reflection_dispatcher.active_reflection_count == 0` para las voces de esa sala; en Sabine, como hoy.

- [ ] Implementar: `var enabled: bool = true`; en `_dispatch_reflections` del manager, saltar las instancias cuyo emisor está en una sala con `reverb_mode == CONVOLUTION` y extensión activa (`spatial_acoustics.get_room_at_position(inst.emitter_position)` → `runtime_room.reverb_mode == 2`).
- [ ] Correr, commit — `git commit -m "Fase 13: los reflectores autorados quedan como ajuste artistico; sin reflexiones tempranas en salas con convolucion"`

---

### Task 6: Documentos y cierre

- [ ] `funcionalidades.md` (§2.2 `OpenDouRoom3D` con `CONVOLUTION`, nueva fila `OpenDouAmbisonicBed3D`, §3.2 reflexiones/ambisonics/surround, §3.5 recortado, recurso `OpenDouAmbisonicAudio`), `AGENTS.md` (observación 52: el `AudioEffect` nativo; trampas: commit vs hilo, IR opaca, stream estéreo solo), `current.md`, spec §11; el spike de Task 0 se borra o se documenta como ejemplo.
- [ ] `./run_tests.sh` verde; commit `"Fase 13: documentos al dia; observacion 52"`.

---

## Autorevisión

- **Cobertura:** §3 → T1; §4 → T2; §5 → T3; §6 → T4; §7 → T5; §8–§9 repartidos; §10 riesgos en T1 (commit/hilo), T2 (CPU: `hybridReverbTransitionTime`), T4 (5.1 no verificable).
- **Nombres:** `configure(..., with_reflections, max_duration, max_rays)`, `create_listener_source`, `set_listener_source_position`, `start/stop_reflections`, `get_reverb_times`, `reflections_generation`, `copy_reflection_params` (T1, T2); `install_convolution/install_sabine` (T2); `read_multichannel`, `encode_point`, `set_listener_basis` (T3); `OUTPUT_MONO_PASS`, `surround_available`, `default_panning_strength` (T4).
- **Dependencia dura:** T2 y T3 dependen del resultado de T0 (B5). Si B5 falla, parar y reabrir A4/A5 en observaciones.
