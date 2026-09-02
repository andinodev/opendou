# Fase 13 — Reflexiones y ambisonics

**Fecha:** 2026-09-02
**Estado:** Diseñado sin intervención del usuario; **dudas abiertas en [`docs/tasks/observaciones-fases-12-14.md`](../../tasks/observaciones-fases-12-14.md)**. Pendiente de resolverlas antes de ejecutar.
**Rama:** `main`
**Godot verificado:** 4.7.2 · **Steam Audio:** 4.8.1
**Hoja de ruta:** [`docs/roadmap/2026-09-02-sprint-aaa.md`](../../roadmap/2026-09-02-sprint-aaa.md), Fase 13
**Fase anterior:** [12](2026-09-02-fase12-efecto-directo-design.md)

---

## 1. Contexto

Con la escena y el simulador de la Fase 12, Steam Audio puede **trazar la respuesta al
impulso** de la sala donde está el oyente y devolverla lista para convolución (o resumida en
tres RT60 por banda). Hoy el reverb por sala es un `AudioEffectReverb` de Godot por escalón de
RT60 estimado por Sabine (`OpenDouReverbBusPool`), y las reflexiones tempranas son copias
retrasadas contra planos autorados (`ReflectionDispatcher`). Esta fase pone la IR real donde
está el reverb, deja los reflectores como ajuste artístico, añade las camas ambisónicas y
resuelve el modo altavoces con la salida del dispositivo.

Hechos comprobados al preparar el spec:

- **La reflexión se simula por fuente** (`flags = REFLECTIONS`, `iplSimulatorRunReflections`,
  lenta, **en su hilo**) y se aplica con `iplReflectionEffectApply(effect, params, in, out,
  mixer)`. El tipo se fija al crear el simulador: `CONVOLUTION`, `PARAMETRIC`, `HYBRID` o `TAN`.
  Con `HYBRID`/`PARAMETRIC` las salidas incluyen **`reverbTimes[3]`** (RT60 por banda), que es
  justo lo que el fallback de Sabine y el HUD necesitan: **no hace falta analizar la IR**;
  `OpenDouIRRT60Analyzer` se queda para IRs de usuario.
- **Reverb centrado en el oyente**: una fuente colocada **en el oyente** con reflexiones da la IR
  de la sala «donde estás»; aplicarla a la mezcla de las voces de la sala es un reverb de sala
  real, barato (una IR, no una por voz). Es la opción del análisis de la Fase 7 §5.
- **Observación 49**: dentro de un `Area3D` con reverb, Godot manda la voz **entera** al bus de
  reverb de la sala. Eso convierte al bus de reverb en el sitio natural del efecto: el efecto
  de convolución debe devolver **seco + húmedo** (como hace `AudioEffectReverb` con `dry`/`wet`),
  y el `target_bus` de la voz sigue sin recibir nada (deuda que esta fase no resuelve; §10).
- **Godot permite `AudioEffect` propios por GDExtension** (`AudioEffect::_instantiate`,
  `AudioEffectInstance::_process(src, dst, frame_count)`): el reverb por convolución puede ser
  un efecto de bus, no un stream.
- **Un `AudioStreamPlayback` propio solo mezcla estéreo** (`AudioFrame` de dos canales). Un
  stream nativo **no puede** emitir 5.1: la salida surround (13.3) no puede ir por
  `IPLAmbisonicsPanningEffect` dentro del stream. Alternativa honesta (§6).
- **Godot no importa WAV multicanal**: `AudioStreamWAV` es mono o estéreo. Una cama ambisónica
  de orden 1 (4 canales) o 2 (9) necesita lector propio (`OpenDouWavDecoder` gana
  `read_multichannel(path) -> Array[PackedFloat32Array]`) y un recurso propio.
- `OpenDouRoom3D.reverb_mode` ya existe con `SABINE_RT60` e `IR_DERIVED_RT60`.

---

## 2. Alcance

**Entra**

1. Simulación de reflexiones en hilo propio: `OpenDouSimulator` gana `REFLECTIONS` (`HYBRID`),
   una **fuente de oyente** por sala activa, `start_reflections(hz)`, `reverb_times(room)`.
2. `OpenDouConvolutionReverb` (`AudioEffect` nativo) con `dry`/`wet`, alimentado con la IR de la
   sala del oyente; `OpenDouRoom3D.reverb_mode = CONVOLUTION`; el pool de Sabine recibe los RT60
   reales como fallback y para el HUD.
3. `OpenDouAmbisonicAudio` (recurso), `OpenDouAmbisonicStream` (stream nativo: rotación con el
   oyente + decodificación al HRTF) y `OpenDouAmbisonicBed3D` (nodo).
4. Modo altavoces con la salida del dispositivo: el anfitrión deja de estar neutralizado en
   paneo cuando `output = speakers` y el dispositivo es 3.1/5.1/7.1 (Godot panea la señal ya
   procesada); estéreo sigue con nuestro paneo de potencia constante.
5. `ReflectionDispatcher` deja de ser fuente de verdad: apagado por defecto en salas con
   convolución; los `OpenDouReflector3D` quedan como ajuste artístico.
6. Documentación.

**No entra**

- Reflexiones **por fuente** (una IR por voz): coste alto; queda como opción futura bajo LOD.
- `TAN`/GPU, Embree, RadeonRays.
- Resolver la observación 49 (el envío propio de reverb): §10.

---

## 3. Reflexiones en hilo

`OpenDouSimulator` (Fase 12) se crea con `flags = DIRECT | REFLECTIONS`,
`reflectionType = HYBRID`, `maxNumRays` (4096), `numDiffuseSamples` (32), `maxDuration` (2.0 s),
`maxOrder` (1), `numThreads` (2), y `iplSimulatorSetSharedInputs(REFLECTIONS, {listener,
numRays, numBounces (16), duration, order, irradianceMinDistance})`.

- `create_listener_source() -> int`: fuente con `flags = REFLECTIONS` colocada en el oyente
  (`set_source_inputs` cada cuadro con la posición del oyente; `reverbScale = {1,1,1}`,
  `hybridReverbTransitionTime = 1.0`, `hybridReverbOverlapPercent = 0.25`).
- `start_reflections(hz: float = 10.0)`: hilo `std::thread` que cada `1/hz` s copia las entradas
  (mutex), llama `iplSimulatorRunReflections` y publica las salidas (`iplSourceGetOutputs(REFLECTIONS)`)
  con un mutex; `stop_reflections()` al descargar. **`iplSimulatorCommit` solo en el hilo
  principal** y nunca mientras corre una simulación (bandera atómica `running_`).
- `get_reverb_times(handle) -> Vector3` (RT60 por banda del último resultado) y
  `reflections_generation(handle) -> int` (cambia cuando hay resultado nuevo).
- La IR (`IPLReflectionEffectIR`, opaca) vive en el nativo y la consume el efecto (§4).

**Se afirma:** con la escena de la quilla y el oyente en la sala de máquinas (metal), el RT60
medio (`reverb_times().y`) es mayor que en una sala del mismo volumen con `Wood` (un test que
construye dos cajas iguales con materiales distintos); el hilo entrega al menos un resultado
en 0.5 s y no bloquea el hilo principal (el tiempo por cuadro del manager no sube más de 10 %).

---

## 4. `OpenDouConvolutionReverb` y `reverb_mode = CONVOLUTION`

**Efecto nativo** `OpenDouConvolutionReverb` (`AudioEffect`) con instancia
`OpenDouConvolutionReverbInstance`: propiedades `dry` (1.0), `wet` (0.5), `room_handle: int`
(la fuente de oyente cuya IR aplica). En `_process`: mezcla el estéreo de entrada a mono,
`iplReflectionEffectApply(effect, params{type = HYBRID, ir, reverbTimes, eq, delay, numChannels =
ambisónico orden 1 → 4}, in, out, nullptr)` y decodifica el orden 1 al binaural con un
`IPLAmbisonicsDecodeEffect` (HRTF activo) → estéreo húmedo; salida = `dry·entrada + wet·húmedo`.
Los parámetros se leen del simulador con doble búfer (la IR se sustituye entre bloques, nunca
a medias). Sin resultado todavía, solo seco.

**Sala.** `OpenDouRoom3D.reverb_mode` gana `CONVOLUTION`. Con la extensión y la escena listas:
la sala pide al pool un bus (como hoy) y en él el pool instala **`OpenDouConvolutionReverb` en
lugar de `AudioEffectReverb`** (marcado `OpenDou_ConvReverb`), con `room_handle` de la fuente de
oyente de esa sala (el manager crea una por sala que tenga oyente dentro y la mueve con él;
las salas sin oyente comparten la IR de la última visita). Sin extensión, `CONVOLUTION` cae a
`SABINE_RT60` **alimentado por los RT60 reales si alguna vez los hubo** (`runtime_room.
reverb_decay_time = reverb_times().y`); si nunca, Sabine, como hoy. El HUD y el depurador
muestran el RT60 real.

**Se afirma:** tono corto (50 ms) en una sala `CONVOLUTION` de metal: la cola medida en el bus
de la sala (energía tras el fin del tono) dura más (T20 con `OpenDouIRRT60Analyzer` sobre la
captura) que en la misma sala en `Wood`; con `wet = 0`, la salida iguala a la entrada (±0.5 dB);
sin extensión, `reverb_mode = CONVOLUTION` produce un `AudioEffectReverb` con RT60 de Sabine y
la suite de salas sigue verde.

---

## 5. Camas ambisónicas

- **Recurso** `OpenDouAmbisonicAudio` (`addons/opendou/resources/ambisonic_audio.gd`): `order`
  (1 o 2), `channels: Array[PackedFloat32Array]` (4 o 9, ACN/SN3D), `mix_rate`, `loop`;
  `static from_wav_file(path) -> OpenDouAmbisonicAudio` con `OpenDouWavDecoder.read_multichannel`
  (WAV PCM 16/24 bits de 4 o 9 canales); `static from_stereo(left_right: AudioStreamWAV, width_deg)`
  para «cama estéreo codificada» (dos fuentes virtuales a ±width/2 codificadas con
  `IPLAmbisonicsEncodeEffect`). Sin assets en el repo: los tests sintetizan (una fuente
  codificada al frente).
- **Stream nativo** `OpenDouAmbisonicStream` (`AudioStream`) + playback: `audio:
  OpenDouAmbisonicAudio`, `listener_basis: Basis` (lo empuja el manager cada cuadro),
  `spatial_blend`. Cadena por bloque: canales → `IPLAmbisonicsRotationEffect` (orientación
  inversa del oyente) → `IPLAmbisonicsDecodeEffect` (binaural con el HRTF activo, o paneo
  estéreo en modo altavoces) → estéreo.
- **Nodo** `OpenDouAmbisonicBed3D` (`AudioStreamPlayer` con script): `audio`, `autoplay`, `bus`;
  se registra en el manager para recibir la orientación del oyente (`register_ambisonic_bed`).
  No tiene posición: es el ambiente que rodea.

**Se afirma:** una fuente codificada al frente (orden 1, sintetizada) con el oyente mirando
a −Z mide ILD ≈ 0; girado 90° a la izquierda, la ILD supera 6 dB con el signo de «fuente a la
derecha»; girado 90° a la derecha, el signo contrario; sin extensión, el nodo avisa una vez y
reproduce el canal W en mono (fallback audible, no silencio).

---

## 6. Salida por el dispositivo (modo altavoces)

Un stream propio no puede emitir más de dos canales, así que **el paneo surround lo hace
Godot**: cuando `settings.output == "speakers"` y `AudioServer.get_speaker_mode() != STEREO`,
el anfitrión del pool deja de estar neutralizado en paneo (`panning_strength = 1`, modelo de
atenuación `DISABLED` como hoy, posición real) y el stream nativo pasa a `output_mode = MONO_PASS`
(nuevo: la señal procesada en mono, sin HRTF ni paneo). Godot reparte esa señal por los
altavoces del dispositivo con su propio paneo 3D. Con estéreo, todo como hoy.

**Se afirma:** con `AudioServer` en 5.1 (`ProjectSettings audio/general/…` no lo fuerza en
headless: el test solo puede afirmar la **decisión**: que con `speaker_mode` distinto de estéreo
el anfitrión tiene `panning_strength = 1` y el stream `MONO_PASS`, y que con estéreo sigue
neutralizado). La afirmación de energía por canal trasero se marca como **no verificable en la
suite** (observación).

---

## 7. `ReflectionDispatcher` y los reflectores

`ReflectionDispatcher` gana `enabled` (true) y el manager lo pone a `false` para las voces cuyo
emisor está en una sala con `reverb_mode = CONVOLUTION` (la IR ya trae las reflexiones). Los
`OpenDouReflector3D` siguen funcionando donde el diseñador los ponga (Sabine o fuera de salas):
ajuste artístico. `tests/test_early_reflections*.gd` siguen verdes (salas Sabine).

---

## 8. Cambios en lo que existe

| Archivo | Cambio |
|---|---|
| `native/src/simulator.{h,cpp}` | `REFLECTIONS`, hilo, fuente de oyente, `reverb_times` |
| `native/src/convolution_reverb.{h,cpp}` (nuevo) | `AudioEffect` de convolución |
| `native/src/ambisonic_stream.{h,cpp}` (nuevo) | stream ambisónico |
| `native/src/spatial_stream.{h,cpp}` | `output_mode = MONO_PASS` |
| `resources/ambisonic_audio.gd`, `nodes/opendou_ambisonic_bed_3d.gd`, `runtime/wav_decoder.gd` | cama ambisónica |
| `nodes/opendou_room_3d.gd`, `runtime/spatial/reverb_bus_pool.gd`, `runtime/spatial/audio_room.gd` | `CONVOLUTION`, efecto en el bus, RT60 real |
| `runtime/audio_event_manager.gd` | fuente de oyente por sala, orientación a las camas, dispatcher apagado |
| `runtime/native_player_pool.gd`, `runtime/physical_voice_channel.gd` | anfitrión sin neutralizar en surround |
| `runtime/reflection_dispatcher.gd` | `enabled` |

## 9. Tests

`tests/test_reflections_thread.gd`, `tests/test_convolution_reverb.gd`, `tests/test_ambisonic_bed.gd`,
`tests/test_speaker_output_mode.gd`; los de salas y reflexiones existentes siguen.

## 10. Riesgos y deudas

- **Observación 49 sigue abierta**: el bus de la sala recibe la voz entera; el efecto devuelve
  seco + húmedo. `target_bus` de las voces 3D en salas sigue sin gobernar. El envío propio
  (doble reproductor o captura por voz) es una fase aparte; queda anotado.
- **Hilo de reflexiones y `commit`**: añadir fuentes mientras el hilo corre está prohibido por
  la API; se serializa con una bandera y una cola de altas/bajas aplicada en el hilo principal.
- **CPU de la convolución**: HYBRID con 1 s de convolución y orden 1 son 4 convoluciones por
  bloque por sala activa; se mide en la guarda DSP (`benchmark`) y si supera el techo se baja
  `hybridReverbTransitionTime` a 0.5.
- **La suite no puede probar 5.1**: se afirma la decisión, no la energía por canal.

## 11. Correcciones que la ejecución obligue a hacer

Se anotan aquí, numeradas.
