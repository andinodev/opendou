# Fase 1 — Cadena de audio real

**Fecha:** 2026-09-01
**Estado:** Diseño aprobado, pendiente de plan de implementación
**Rama:** `fase1-cadena-audio-real`
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf

---

## 1. Contexto

Un análisis del proyecto identificó 24 observaciones. La más grave (nº1) no es un bug
sino un subsistema ausente: **OpenDou no emite audio**. `PhysicalVoiceChannel.play_stream()`
almacena el stream y activa banderas, pero nunca crea un reproductor ni invoca `AudioServer`.
En 21.400 líneas del addon el único método de `AudioServer` usado es `get_bus_index`.
`OpenDou.post_event()` no produce ningún sonido.

Las observaciones 3, 4, 6 y 12 son consecuencias directas de esa ausencia, y la nº23
(tests ciegos) es la razón por la que pudo pasar inadvertida.

### Objetivo del proyecto

OpenDou debe ser un **middleware real, publicable y usable en juegos exportados a
producción**, capaz de sostener cientos de voces simultáneas. Esta decisión descarta
cualquier enfoque que ponga DSP por muestra en GDScript.

### Descomposición en 5 fases

| Fase | Tema | Observaciones |
|------|------|---------------|
| **1** | Cadena de audio real | 1, 3, 4, 6, 12, 23 |
| 2 | Corrección espacial | 5, 7, 8, 9, 10, 11 |
| 3 | Rendimiento | 13, 14, 15 |
| 4 | Distribuible y honesto | 16, 17, 18, 19, 20, 21, 22, 24 (parcial: ver 7.4) |
| 5 | 3 demos nuevas (borrar las 10 actuales) | 2 |

Este documento cubre **solo la Fase 1**. Las fases posteriores tendrán su propia spec.

> Nota de alcance: la nº5 (posición del listener) pertenece nominalmente a la Fase 2, pero
> se adelanta a la Fase 1 porque el voice-stealing no puede validarse midiendo distancias
> desde el origen del mundo. La nº8 (managers duplicados) se adelanta por el mismo motivo:
> la oclusión centralizada es parte del ciclo por frame que esta fase define.

---

## 2. Hechos verificados contra Godot 4.7.2

Estas verificaciones se ejecutaron antes de fijar el diseño y son la base de las
decisiones. No son supuestos.

| Hecho | Verificación |
|-------|--------------|
| `AudioStreamPlayer3D` tiene `attenuation_filter_cutoff_hz` y `attenuation_filter_db` | Presentes. Filtro paso-bajo **por voz, en C++**. Elimina la necesidad de un bus por voz para la oclusión. |
| `AudioStreamPlayer3D` expone `unit_size`, `max_db`, `panning_strength`, `doppler_tracking`, `area_mask`, `max_polyphony` | Todas presentes. |
| El filtro por voz es exclusivo de 3D | `AudioStreamPlayer` y `AudioStreamPlayer2D` **no** tienen `attenuation_filter_*`. La oclusión con LPF solo es aplicable a voces 3D; en 2D y no-espacial se aplica como atenuación de volumen. |
| Un error de script aborta la función que lo contiene | Reproducido: la llamada con array mal tipado interrumpe la ejecución y la función devuelve `null`. Explica la cascada de los errores 4 y 5. |
| `play(from_position)` reanuda con offset | `play(0.5)` sobre un WAV de 1 s → `get_playback_position()` = 0.503. La desvirtualización con reanudación es real. |
| Señal `finished` disponible | Sí. Es la fuente de verdad para cerrar voces. |
| `Area3D` tiene reverb nativo por zona | `reverb_bus_enabled`, `reverb_bus_name`, `reverb_bus_amount`, `reverb_bus_uniformity`, `audio_bus_override`, `audio_bus_name`. (El nombre correcto es `reverb_bus_enabled`, no `reverb_bus_enable`.) |
| Regla de listener de Godot replicable | `Viewport.get_audio_listener_3d()` y `get_camera_3d()` existen; `AudioListener3D`/`2D` existen. |
| **El audio es medible en `--headless`** | Con driver `Dummy`, `AudioEffectCapture` devolvió 24.576 frames y pico **0.8000** para un seno de amplitud 0.8. Las aserciones de audio en CI son viables. |
| Efectos disponibles | `AudioEffectLowPassFilter`, `AudioEffectFilter`, `AudioEffectReverb`, `AudioEffectCompressor`, `AudioEffectLimiter`, `AudioEffectHardLimiter`, `AudioEffectCapture`. |

### Baseline del proyecto

- El proyecto **compila limpio** en 4.7.2: sin errores de parseo.
- La suite reporta `STATUS: PASSED | TOTAL: 337 | PASSED: 337 | FAILURES: 0`.
- **En el mismo log Godot emite 5 `SCRIPT ERROR`** y filtra 1015 instancias ObjectDB.
  Métodos inexistentes que la suite cree cubrir: `RTPCBinding.evaluate_fast`,
  `OpenDouBlendGraphNode.set_live_rtpc_progress`, `OpenDouBankPanel._on_add_stream_pressed`;
  más un desajuste de array tipado en `VoicePoolManager.get_active_virtual_count`, que
  aborta `AudioTelemetryCollector.collect_snapshot()` y provoca en cascada el acceso a
  `physical_voices` sobre `Nil`: son una única causa raíz, no dos.

  **Corrección:** la tabla LUT O(1) del roadmap **sí existe** (`RTPCBinding.bake_lut()`, y
  `evaluate()` la consulta). El defecto es solo que el test invoca un nombre de método que
  no existe. Un análisis previo lo describió como LUT ausente; era inexacto.
- **Correr la suite muta datos versionados**: inyectó `RTPC_210`, `RTPC_211` en
  `opendou_syncs.json` y 102 líneas en `opendou_synth_presets.json` (manifestación de la nº17).

---

## 3. Enfoque elegido

**Pool de nodos nativos (orquestador).** Godot mezcla en C++; OpenDou decide qué suena,
cuándo, a qué volumen, en qué bus y con qué filtrado.

Enfoques descartados y por qué:

- **Motor propio con `AudioStreamGenerator`**: pondría la mezcla de todas las voces en
  GDScript. Contradice el objetivo de cientos de voces y obligaría a reimplementar
  atenuación, paneo y Doppler 3D que Godot ya resuelve en C++.
- **Híbrido con `AudioStreamPlayback` propio**: el método `_mix()` corre en el hilo de
  audio; GDScript ahí invita a underruns.

Consecuencia aceptada: los crossfades quedan cuantizados a frame, no son sample-exact.
Para un middleware de gameplay es un coste irrelevante.

---

## 4. Arquitectura

### 4.1 Dos fuentes de voz, un solo presupuesto

**Voces propiedad del nodo.** `OpenDouEventPlayer3D` sigue heredando de
`AudioStreamPlayer3D`, y **su propio reproductor pasa a ser la voz física**. Virtualizar es
`stop()` más seguimiento de la posición lógica; desvirtualizar es
`play(logical_position)`. La duplicación de la nº3 desaparece por construcción: ya no
existen dos reproducciones, existe una y el `EventInstance` es su ficha de control.

Se conservan así todas las propiedades 3D nativas en el inspector (`unit_size`, `max_db`,
curvas de atenuación, `doppler_tracking`, `area_mask`), que es lo que un diseñador de audio
espera encontrar y que ninguna reimplementación en GDScript igualaría.

**Voces anónimas del pool.** `OpenDou.post_event("Explosion", self)` sin nodo dedicado
obtiene un reproductor de un pool de hijos del autoload, lo posiciona en
`emitter_position` cada frame y lo devuelve al terminar. Es el caso fire-and-forget que hoy
no suena en absoluto.

**`VoicePoolManager` deja de ser dueño de canales y pasa a ser asignador de permiso**:
decide qué instancias son audibles dentro del presupuesto, con independencia de dónde
provenga el reproductor. El algoritmo de voice-stealing existente se conserva; lo que
cambia es que ahora surte efecto.

### 4.2 `PhysicalVoiceChannel`

Pasa de objeto contable a envoltorio delgado sobre un reproductor real. Interfaz:

- `bind(player, owned_by_node: bool)` — asocia el canal a un reproductor nativo.
- `play_stream(stream, offset, volume_db, pitch, bus)` — configura y llama `play(offset)`.
- `apply(volume_db, pitch, cutoff_hz, position)` — empuje por frame.
- `stop_with_fade(sec)` — rampa real de volumen y luego `stop()`.
- `release()` — desvincula; si no es propiedad de un nodo, devuelve el reproductor al pool.

Los tres sub-pools (`AudioStreamPlayer`, `2D`, `3D`) crecen de forma perezosa hasta
`max_physical_voices`.

### 4.3 Resolución de las observaciones de la fase

| Obs. | Mecanismo |
|------|-----------|
| **nº1** motor mudo | `play_stream()` invoca `play()` sobre un reproductor nativo real. |
| **nº3** doble reproducción | El nodo ya no reproduce por su cuenta; su reproductor *es* la voz. |
| **nº4** `calculated_volume_db` / `pitch` no llegan | Se empujan cada frame en el paso «aplicar». |
| **nº4** `current_fade_gain` muerto | `volume_db = calculated_volume_db + linear_to_db(max(fade_gain, 0.0001))`. Los micro-fades anti-click pasan a ser audibles. |
| **nº4** `cutoff_hz` muerto | `attenuation_filter_cutoff_hz` + `attenuation_filter_db` por voz. |
| **nº6** voces que nunca terminan | Señal `finished` → `voice_state = STOPPED`. Los loops no la emiten, que es correcto. |

---

## 5. Flujo por frame

Orden estricto en `AudioEventManager._process(delta)`:

1. **Resolver listener.** Todo cálculo dependiente de distancia ocurre después de este
   paso, nunca antes.
2. **Game Syncs.** `sync_manager.process(delta)`.
3. **Oclusión presupuestada.** Ver 5.2.
4. **Parámetros de instancia.** `interpolate_locals` + `update_parameters`.
5. **Asignar permiso.** `resolve_voice_stealing`.
6. **Aplicar al reproductor.** *Paso nuevo.* Volumen, pitch, cutoff, bus y posición.
7. **Cerrar voces terminadas.** Por señal, no por inferencia.
8. **Telemetría.**

### 5.1 Fuente de verdad del listener (nº5)

Hoy nadie invoca `set_listener_position()`, así que `active_listener_position` permanece en
`Vector3.ZERO` de forma permanente. El voice-stealing mide distancias desde el origen del
mundo, y el rayo de oclusión de `OpenDouEventPlayer3D` apunta a (0,0,0) en lugar de al
oyente.

OpenDou **replica la regla de Godot** en lugar de inventar una propia:

1. `AudioListener3D` activo del viewport, si existe.
2. En su defecto, la `Camera3D` activa.
3. Override explícito vía `set_listener_node(node)` / `set_listener_position(pos)` para
   juegos con oyente desacoplado de la cámara.

Correcto por defecto, sin configuración.

### 5.2 Oclusión presupuestada (nº8)

Hoy cada `OpenDouEventPlayer3D` crea su propio `OcclusionManager` en `_init()` y lanza su
propio raycast cada 50 ms. Con 200 emisores son 200 managers y ~4.000 raycasts/segundo,
todos apuntando al lugar equivocado.

Pasa a existir **un único `OcclusionManager` en el autoload y un presupuesto de N raycasts
por frame** (por defecto 8), repartidos round-robin y priorizados por cercanía al listener.
Con 64 voces da ~7 Hz de refresco por voz con un techo de coste fijo, en lugar de un coste
que crece sin límite con el número de emisores.

Esto le da por fin un consumidor a `acoustic_lod_controller.gd`, hoy huérfano: es quien
decide cuántos rayos merece cada voz según su distancia.

### 5.3 Detalle de corrección: reanudación de loops

Al desvirtualizar un stream en bucle la reanudación es
`play(fmod(logical_position, stream_length))`. Sin el `fmod`, un ambiente virtualizado
durante 3 minutos intentaría arrancar en el segundo 180 de un loop de 4 segundos y no
sonaría.

---

## 6. Destino de las features huérfanas (nº12)

| Feature | Estado hoy | Decisión |
|---------|-----------|----------|
| `enable_early_reflections` | Toggle no leído en ninguna parte; `acoustic_reflector_engine` calcula fuentes imagen que no suenan | **Cablear.** Cada reflexión de 1er orden es una voz anónima del pool en la posición espejo, con atenuación y retardo. Presupuestado: máx. 2 reflexiones por voz y 16 voces de reflexión simultáneas en total, configurables. |
| Convolución IR (`ConvolutionReverbNode`) | 512 taps en GDScript, desconectados; el IR por defecto es `exp(-i/64)*sin(i*0.2)`, que no es un IR | **Diferido a la Fase 2.** La decisión es sustituirlo por reverb nativo: el RT60 de Sabine que `Room3D` ya calcula se mapea a `AudioEffectReverb` en un bus por sala, accionado por los `reverb_bus_*` nativos de `Area3D`, y el nodo de convolución se reconvierte en herramienta *offline* para derivar RT60 de un IR real. Es corrección espacial, no de la ruta de la voz. |
| `AudioHDREngine` | Solo lo consume el mixer del editor | **Diferido a la Fase 3.** La decisión es cablearlo como controlador de ganancia por categoría de bus (`set_bus_volume_db`) más `AudioEffectLimiter`. Es trabajo de mezcla, no de la ruta de la voz. |
| `enable_binaural_hrtf` | Toggle no leído; `AudioSpatialBinaural` calcula ITD/ILD que nadie consume | **Retirar.** Godot no tiene HRTF nativo y un HRTF real exige convolucionar cada voz con un par de HRIR: DSP por muestra en GDScript, lo contrario del objetivo. Se elimina el toggle del inspector y la mención de HRTF del README y `plugin.cfg`. `AudioSpatialBinaural` se conserva documentado como utilidad de cálculo, no como capacidad del emisor. |

Criterio de corte: la Fase 1 resuelve las huérfanas que viven **en la ruta de la voz**
(los toggles del emisor). Las que viven en la mezcla o en la acústica de sala se deciden
aquí pero se implementan en su fase. Lo que no se aplaza en ningún caso es la retirada del
HRTF: un toggle que promete algo imposible en esta arquitectura no debe sobrevivir a esta
fase.

Principio rector: **el proyecto solo afirma lo que hace.**

---

## 7. Estrategia de verificación (nº23)

### 7.1 El runner debe fallar ante errores del motor

El log actual contiene 5 `SCRIPT ERROR` y la suite reporta 337/337. En GDScript una llamada
a un método inexistente emite error y devuelve `null`; el test solo registra fallo si una
comparación falla. Godot no expone un hook de errores de script, así que la detección es a
nivel de proceso: **el run falla si el log contiene `SCRIPT ERROR`, `Parse Error` o
`ObjectDB instances were leaked`.** Las 1015 instancias filtradas de hoy son un fallo real,
no ruido.

### 7.2 Aserciones de audio reales

Bus de test dedicado con `AudioEffectCapture`. Clases de aserción:

- Tras `post_event("X")`, el pico en el bus supera un umbral (p. ej. −40 dBFS).
- Una voz virtualizada, culleada o detenida deja el bus en silencio.
- Un cambio de RTPC ligado a volumen se refleja como cambio medible de pico.
- Una voz ocluida presenta menos energía de alta frecuencia que la misma sin ocluir.

Verificado viable en `--headless`. **Es la clase de aserción que habría detectado la nº1 el
primer día.**

### 7.3 Tests sin efectos secundarios

Ningún test debe escribir en `res://`. Los tests que hoy mutan `opendou_syncs.json` y
`opendou_synth_presets.json` se aíslan redirigiendo las escrituras a rutas temporales.

### 7.4 Runner multiplataforma (parcial de nº24)

`run_tests.ps1` y `godot.cmd` son exclusivos de Windows. Se añade `run_tests.sh` que
localiza Godot vía `$GODOT_PATH` con fallbacks por plataforma, y se conserva el `.ps1` como
envoltorio fino. El resto de la nº24 (enlaces `file:///c:/...` en la documentación)
corresponde a la Fase 4.

### 7.5 Framework

Se conserva el framework casero y se añade un helper `Assert` con registro de fallos y
aserciones de audio. Migrar 109 archivos a gdUnit4 sería una fase entera y el problema real
no es el framework, es que no falla.

---

## 8. Criterios de aceptación

1. `OpenDou.post_event("X")` produce audio medible: pico > −40 dBFS en el bus de test.
2. Un `OpenDouEventPlayer3D` con `auto_play_event` produce **una sola** voz, no dos.
3. Un cambio de RTPC ligado a volumen altera el pico medido en el bus.
4. Una voz cuyo stream termina sale de `active_instances`; `active_instances` no crece de
   forma monótona en una prueba de 1.000 eventos sucesivos.
5. Superado el presupuesto de voces, las de menor prioridad se virtualizan y el bus refleja
   la reducción; al liberarse presupuesto se desvirtualizan reanudando en su posición
   lógica.
6. Con un `AudioListener3D` desplazado del origen, la prioridad por distancia y el rayo de
   oclusión usan su posición.
7. Ningún emisor crea su propio `OcclusionManager`; los raycasts por frame no superan el
   presupuesto configurado.
8. `enable_binaural_hrtf` no existe; README y `plugin.cfg` no mencionan HRTF.
9. `enable_early_reflections` activado produce voces de reflexión medibles.
10. El runner falla si el log contiene `SCRIPT ERROR`, `Parse Error` o fugas de ObjectDB.
11. Los 5 `SCRIPT ERROR` del baseline quedan resueltos (4 causas raíz: dos de ellos son la misma en cascada).
12. Correr la suite deja el árbol de git limpio.
13. `run_tests.sh` funciona en macOS.

---

## 9. Fuera de alcance

Corresponden a fases posteriores y **no** se abordan aquí:

- nº7 deriva del spline emitter, nº9 transforms sin rotación, nº10 `open_factor`,
  nº11 decodificación WAV (Fase 2).
- Reverb nativo por sala y retirada de la convolución en GDScript (Fase 2, decidido en 6).
- nº13 ring buffer byte a byte, nº14 SPSC, nº15 `load()` en `_get_property_list()` (Fase 3).
- Cableado del `AudioHDREngine` a buses de runtime (Fase 3, decidido en 6).
- nº16–22 empaquetado, rutas `res://`, doble registro de tipos, 176 `class_name` globales,
  main screen, `.gitignore`, README vs realidad (Fase 4).
- nº2 y las 3 demos nuevas (Fase 5).

**Decisión aplazada:** el pipeline ODBK queda sin salida de audio real con este enfoque. En
la Fase 4 se decidirá si se convierte en precarga a `AudioStreamWAV` (real y útil) o se
retira junto con la afirmación del roadmap. No se toca en la Fase 1.

---

## 10. Riesgos

| Riesgo | Mitigación |
|--------|-----------|
| Cambiar `PhysicalVoiceChannel` y `VoicePoolManager` rompe tests existentes que afirman el comportamiento simulado | Esos tests afirman la ausencia de audio. Se reescriben como aserciones de audio real; es trabajo esperado, no regresión. |
| El presupuesto de raycasts introduce latencia perceptible en la oclusión | Presupuesto configurable y priorización por cercanía; las voces próximas al oyente refrescan más rápido. |
| Reparentar reproductores del pool cada frame sería costoso | No se reparentan: permanecen hijos del autoload y se les asigna `global_position`. |
| Las voces propiedad del nodo consumen presupuesto sin que el usuario lo sepa | La telemetría distingue voces de nodo y voces de pool. |
