# Fase 9 — El emisor completo

**Fecha:** 2026-09-02
**Estado:** Aprobado en diseño (ciclo spec → plan → ejecución aprobado por adelantado), pendiente de plan.
**Rama:** `main`
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Hoja de ruta:** [`docs/roadmap/2026-09-02-sprint-aaa.md`](../../roadmap/2026-09-02-sprint-aaa.md), Fase 9
**Fase anterior:** [8](2026-09-02-fase8-higiene-y-deuda-design.md)

---

## 1. Contexto

La Fase 7B hizo que toda voz 3D salga por un panner propio; la 8 puso la mezcla bajo control.
Esta fase da al emisor lo que le falta para sonar como una fuente física y no como un punto
con volumen: tono que cambia al moverse, sonido que llega tarde de lejos, tamaño aparente al
acercarse, refuerzo al pegarse a la oreja, cara (directividad), caídas dibujadas por el
diseñador, y marcadores que sincronizan el juego con el audio. Todo son **exports** del emisor
que ya existe (`OpenDouEventPlayer3D`) y de la definición del evento (`AudioEventDef`, para las
voces anónimas); ningún nodo nuevo, según la clasificación de `docs/ideas/nodos-de-escena.md`
§F.

Hechos comprobados al preparar el spec:

- **Nadie calcula doppler para las voces del sistema**; existe `SpatialAcousticsManager.
  calculate_doppler_pitch(emitter_vel, listener_vel, rel_pos)` (fórmula relativista clásica,
  acotada a [0.5, 2.0]) y solo la usa el emisor de spline para sí mismo.
- **`OpenDouSplineEmitter3D` hereda de `AudioStreamPlayer3D` y no pasa por el sistema de
  voces**: no postea eventos, tiene su propio doppler y su propia absorción del aire, y en el
  backend `steam_audio` **no es binaural**. `docs/funcionalidades.md` lo marcaba ✅ como emisor
  del sistema; pasa a 🟡. Es la **observación 47**; incorporarlo al sistema de voces es una
  tarea aparte que esta fase no aborda (cambia su ciclo de vida completo).
- `spatial_blend` del stream nativo es global (lo fija el menú); el spread necesita un producto
  por voz (documentado en la Fase 7B y en las ideas, §G1).
- No hay archivos `.wav` en el proyecto: los marcadores de audio se autoran en la definición,
  y la lectura del chunk `cue` de un WAV se afirma con un archivo generado por el test.
- La línea de retardo del stream nativo es de 2 ms; el retardo por distancia necesita hasta
  3 s **en mono, antes del HRTF** (530 KB por voz a 44.1 kHz), reservados solo cuando la voz
  lo pide.

### Decisiones

| Decisión | Valor | Razón |
|---|---|---|
| Dónde vive cada función | Exports del emisor + equivalentes en la definición; una función `copy_emitter_settings_from_player()` en la instancia | Un nodo por propiedad física fragmentaría la autoría |
| Doppler | GDScript, ambos backends, sobre `pitch_scale`; **apagado por defecto** | No cambia cómo suenan las escenas existentes; el coche lo enciende |
| Doppler y retardo por distancia juntos en `steam_audio` | El retardo físico produce doppler solo (la rampa de la línea de retardo); la voz **no** aplica además el doppler por tono | Aplicar ambos doblaría el efecto |
| Spread | Por voz: `blend = blend_global × (1 − spread)`; fallback en `godot`: `panning_strength = 1 − spread` | Godot tiene un mando equivalente; el nativo ya tiene `spatial_blend` |
| Campo cercano | Nativo: low-shelf de refuerzo e ILD extra bajo `near_field_distance_m`; sin fallback | Godot no tiene mando equivalente; el inspector lo dice |
| Directividad | GDScript en ambos backends con la fórmula de Steam Audio (`|(1−w) + w·cos θ|^p`), para que la nativa de la Fase 12 sustituya sin cambiar la autoría | Paridad futura |
| Curva de atenuación | Modelo `CURVE` en `OpenDouDistanceModel`; en `godot` se desactiva la atenuación del reproductor y la curva va al volumen | Mismo resultado en ambos backends |
| Marcadores | Recurso `AudioMarker {name, time_sec}` en la definición; importador de chunk `cue` desde un `.wav` en disco; señal `marker_reached` de la instancia sobre el reloj lógico | El reloj lógico ya corre en físicas y virtuales |
| Spline | Solo `flow_speed_mps` en su doppler propio; obs 47 registrada | No se puede dar directividad a algo que el manager no gobierna |

---

## 2. Datos: exports nuevos

Los mismos nombres en `OpenDouEventPlayer3D` (exports) y en `AudioEventDef` (exports, para
voces anónimas) y en `EventInstance` (campos). `copy_emitter_settings_from_player(node)` los
copia del nodo a la instancia igual que hoy `copy_attenuation_from_player`.

| Export | Defecto | Rango | Entrega |
|---|---|---|---|
| `doppler_enabled` | `false` | — | 9.1 |
| `propagation_delay_enabled` | `false` | — | 9.2 |
| `spread_radius_m` | 0.0 (apagado) | 0–200 | 9.3 |
| `near_field_distance_m` | 0.0 (apagado) | 0–2 | 9.4 |
| `directivity_dipole_weight` | 0.0 (omnidireccional) | 0–1 | 9.5 |
| `directivity_power` | 1.0 | 0.1–8 | 9.5 |
| `attenuation_model` gana el valor `CURVE = 4` | — | — | 9.7 |
| `attenuation_curve: Curve` | null | y en dB | 9.7 |
| `attenuation_curve_distance_m` | 50.0 | > 0 | 9.7 |
| `markers: Array[AudioMarker]` (solo en la definición) | vacío | — | 9.8 |
| `flow_speed_mps` (solo en `OpenDouSplineEmitter3D`) | 0.0 | — | 9.6 |

Ajuste de proyecto nuevo: `opendou/spatial/max_propagation_delay_sec` = 3.0 (acota la memoria
por voz con retardo).

---

## 3. Entrega 9.1 — Doppler

- El manager pasa `delta` a `_apply_voices(delta)`. Guarda la posición del oyente del frame
  anterior y calcula `listener_velocity`. Cada instancia con `doppler_enabled` guarda su
  posición anterior y calcula `emitter_velocity = (pos − prev) / delta`, más `flow_velocity`
  (cero salvo para quien la fije).
- Factor: `spatial_acoustics.calculate_doppler_pitch(emitter_velocity, listener_velocity,
  listener − emisor)`, ya acotado a [0.5, 2.0]; se suaviza `doppler_pitch = lerp(doppler_pitch,
  factor, clamp(10·delta, 0, 1))` para que el ruido de posición por frame no vibre.
- Se multiplica en el tono que va al canal: `calculated_pitch_scale × doppler_pitch`. En
  ambos backends, porque `pitch_scale` existe en todos los reproductores.
- Excepción: en `steam_audio`, si la voz tiene `propagation_delay_enabled`, `doppler_pitch`
  se fuerza a 1: el retardo físico ya lo produce (§4).
- Se afirma: un tono de 1 kHz cuyo emisor se mueve hacia el oyente a 30 m/s se mide en el bus
  por encima de 1 kHz (≈1.096 kHz) y alejándose por debajo (≈0.92 kHz); con `doppler_enabled =
  false`, en 1 kHz. La frecuencia se estima por cruces por cero en la captura.

---

## 4. Entrega 9.2 — Retardo por distancia

- **`steam_audio`.** El stream gana `propagation_delay_sec` (0 = apagado). El playback reserva
  una `FractionalDelay` **mono, antes del HRTF**, de `max_propagation_delay_sec` la primera vez
  que la propiedad es > 0. Al arrancar (o al pasar de 0 a > 0) el retardo se **fija de golpe**
  (`snap`): un retardo inicial no se rampa, o se oiría un barrido. Después, cada bloque rampa
  hacia el objetivo nuevo: un emisor que se acerca acorta el retardo y eso **es** el doppler
  físico, por eso 9.1 no se suma.
- **`godot`.** `AudioStreamPlayer3D` no puede retrasar la señal. El canal aplaza el **arranque**
  de la voz `distancia_inicial / 343` s (`play_stream(..., start_delay_sec)`, cuenta atrás en
  `process_fade`). Es peor (no sigue al emisor en movimiento) y el inspector lo dice.
- El canal calcula `propagation_delay_sec = distancia / 343` cada frame y lo empuja al stream.
- Se afirma: emisor a 343 m con la voz posteada en t₀: el primer transitorio llega al bus
  entre 0.9 y 1.2 s después; a 34 m, antes de 0.2 s; con la función apagada, antes de 0.1 s.
  En el backend nativo y en el de Godot (arranque aplazado).

---

## 5. Entrega 9.3 — Spread por distancia

- `spread = clamp(1 − d / spread_radius_m, 0, 1)` (0 si el radio es 0).
- `steam_audio`: `stream.spatial_blend = pool.default_spatial_blend × (1 − spread)`, escrito
  por el canal cada frame. El ajuste del jugador pasa a ser un **factor**: `_apply_spatial_
  settings` fija `default_spatial_blend` y lo escribe solo en los streams **libres**; los
  ocupados lo reciben por el canal. El menú sigue funcionando en vivo.
- `godot`: `player.panning_strength = 1 − spread` (Godot lo tiene).
- Se afirma (nativo): fuente a 1 m con radio 10: ILD e ITD cercanos a cero; a 20 m: los de
  siempre; con radio 0: sin cambio. (`godot`): `panning_strength` del reproductor a 0.1 y
  1.0 respectivamente.

---

## 6. Entrega 9.4 — Campo cercano

- `nf = clamp(1 − d / near_field_distance_m, 0, 1)` (0 si la distancia es 0).
- Nativo: `near_field_bass_db = 6·nf` (low-shelf RBJ a 250 Hz sobre el mono, antes del HRTF)
  y `near_field_ild_db = 6·nf·|dir.x|` restado al oído **lejano** tras el HRTF. Godot: sin
  efecto; el inspector lo dice.
- Se afirma: fuente a 0.2 m frente a 1.0 m a la derecha con `near_field_distance_m = 0.5`:
  la banda 60–200 Hz sube al menos 4 dB y la ILD crece al menos 3 dB; con la distancia en 0,
  sin cambio.

---

## 7. Entrega 9.5 — Directividad (GDScript)

- Orientación: los emisores de nodo usan `−global_basis.z` leída cada frame en
  `_apply_voices` (como la posición); las voces anónimas, `emitter_forward` fijado con
  `set_orientation(forward: Vector3)` (por defecto `(0, 0, −1)`).
- Ganancia (fórmula del efecto directo de Steam Audio, para que la Fase 12 la sustituya sin
  cambiar autoría): `cos θ = forward · dir_al_oyente`; `g = |(1 − w) + w·cos θ|^p`;
  `gain_db = 20·log10(max(g, 0.001))`. Con `w = 0`, 0 dB siempre. Se suma al volumen en ambos
  backends.
- Una flecha en la vista 3D del editor (gizmo) queda para la Fase 12 con la directividad
  nativa; aquí basta el export.
- Nota sobre la fórmula: con el valor absoluto es un **dipolo**, como en Steam Audio: con
  `w = 1` de frente y de espaldas dan 0 dB y de lado (θ = 90°) el suelo de −60 dB. Con
  `w = 0.5` de espaldas cae a −∞ en teoría y al suelo en la práctica: es el «cardioide».
- Se afirma: `w = 1, p = 1`, emisor de frente frente a emisor de lado: caída medible ≥ 20 dB
  en el bus; `w = 0.5`, de espaldas cae ≥ 20 dB respecto a de frente; con `w = 0`, iguales.

---

## 8. Entrega 9.6 — Flujo del spline (acotada)

- `OpenDouSplineEmitter3D.flow_speed_mps`: en `update_spline_acoustics`, la velocidad del
  emisor virtual suma `tangente × flow_speed_mps`, con la tangente en el punto más cercano
  (`curve.sample_baked_with_rotation(curve.get_closest_offset(local))`, eje `−Z` de la
  base). Un río que corre hacia el oyente sube el tono; alejándose lo baja.
- Nada más: el spline no pasa por el manager (obs 47), así que directividad y spread no le
  llegan hasta que se incorpore al sistema de voces.
- Se afirma: con `flow_speed_mps = 20` y oyente aguas abajo, `pitch_scale` del nodo > 1;
  aguas arriba, < 1; con 0, igual a `base_pitch_scale`.

---

## 9. Entrega 9.7 — Curva de atenuación

- `OpenDouDistanceModel.MODEL_CURVE = 4`; `attenuation_db()` con `CURVE` devuelve
  `curve.sample(clamp(d / curve_distance, 0, 1))` en dB (la curva se autora en dB: valores
  típicos 0 a −60). `multiplier()` sigue aplicando volumen, tope y distancia máxima.
- `steam_audio`: el canal ya calcula la ganancia con el modelo → sin más cambio.
- `godot`: si el modelo es `CURVE`, el canal pone `attenuation_model = DISABLED` en el
  reproductor 3D y suma la ganancia de la curva al `volume_db` cada frame; el shelf por
  distancia de Godot deja de depender del multiplicador (es 0 con atenuación desactivada), y
  se documenta.
- Se afirma: curva 0 dB hasta 0.5 y −40 dB en 0.6 (con `curve_distance = 10`): nivel a 5.5 m
  ~20 dB por debajo del de 5 m; con el modelo inverso, ~1 dB. En ambos backends.

---

## 10. Entrega 9.8 — Marcadores de audio

- Recurso `AudioMarker` (`resources/audio_marker.gd`): `name: StringName`, `time_sec: float`.
- `AudioEventDef.markers: Array[AudioMarker]` (ordenados por tiempo al usar).
- `EventInstance.marker_reached(name: StringName)` (señal). En `update_parameters`, tras
  avanzar el reloj lógico: se emiten los marcadores cuyo `time_sec` quedó entre la posición
  anterior y la actual; al envolver el bucle, se reinician.
- `OpenDouWavMarkers.read_cues(path: String) -> Array[AudioMarker]` (`runtime/wav_markers.gd`):
  lee un `.wav` del disco, recorre los chunks RIFF, toma `cue ` (posiciones en muestras) y las
  etiquetas `LIST/adtl/labl`; convierte a segundos con la `fmt ` del archivo. Un botón en el
  inspector de la definición queda para más adelante; aquí es API.
- Se afirma: marcador autorado a 0.5 s → la señal llega entre 0.45 y 0.6 s tras `post_event`;
  un WAV generado por el test con dos cues y etiquetas se lee con sus nombres y tiempos; en
  bucle, el marcador vuelve a sonar en la segunda vuelta.

---

## 11. Componentes

| Componente | Archivo | Cambio |
|---|---|---|
| Exports del emisor y copia a la instancia | `nodes/opendou_event_player_3d.gd`, `runtime/event_instance.gd`, `resources/audio_event_def.gd` | 9.1–9.8 |
| Doppler y directividad | `runtime/audio_event_manager.gd` (`_apply_voices(delta)`, velocidad del oyente), `runtime/event_instance.gd` | 9.1, 9.5 |
| Stream nativo: retardo largo, campo cercano | `native/src/spatial_stream.{h,cpp}`, `native/src/dsp.h` (low-shelf), `native/src/steam_audio_context.*` (no) | 9.2, 9.4 |
| Canal: spread, retardo, arranque aplazado, curva en `godot` | `runtime/physical_voice_channel.gd` | 9.2, 9.3, 9.7 |
| Ajuste `max_propagation_delay_sec` | `runtime/spatial/spatial_backend.gd` | 9.2 |
| Ajustes del jugador como factor | `runtime/audio_event_manager.gd` (`_apply_spatial_settings`) | 9.3 |
| `MODEL_CURVE` | `runtime/spatial/distance_model.gd` | 9.7 |
| `AudioMarker`, `OpenDouWavMarkers` | `resources/audio_marker.gd`, `runtime/wav_markers.gd` | 9.8 |
| Spline: flujo | `nodes/opendou_spline_emitter_3d.gd` | 9.6 |
| Suites | `tests/test_emitter_physics.gd` (doppler, retardo, spread, campo cercano, directividad, curva), `tests/test_audio_markers.gd`, `tests/test_spline_flow.gd` | — |
| Documentos | `docs/funcionalidades.md` (spline a 🟡, exports nuevos), `AGENTS.md` (obs 47), `docs/tasks/current.md` | — |

---

## 12. Casos límite

- Doppler con `delta = 0` o primer frame: velocidad 0. Teletransporte (salto > 50 m en un
  frame): se ignora ese frame (velocidad 0) para no silbar.
- Retardo por distancia con emisor más lejos que `max_propagation_delay_sec × 343`: se acota
  al máximo.
- Spread y campo cercano con distancia 0: `d < 1 mm` ya devuelve dirección frontal; spread 1,
  nf 1.
- Directividad con `forward` degenerado (longitud 0): se trata como omnidireccional.
- Curva nula con modelo `CURVE`: se comporta como `DISABLED` y avisa una vez.
- Marcadores fuera de la duración del stream: nunca se emiten; en bucle, los que quedan
  antes del final sí.
- WAV sin chunk `cue`: lista vacía, sin error.

---

## 13. Verificación

Todo sobre audio capturado (`OpenDouAudioProbe`) o sobre lecturas del `AudioServer`, con
control que apaga cada mecanismo; fuente periódica o tono puro según la medida. Las suites
nativas se omiten **y lo dicen** sin extensión. Guardas: fugas, banco del bucle (+5 % máximo a
200 voces: el doppler y la directividad son un producto punto y un `lerp` por voz), guarda de
DSP (la línea de retardo larga cuesta una lectura interpolada por muestra).

---

## 14. Criterios de aceptación

1. El coche de «Una casa canta», con `doppler_enabled` y `propagation_delay_enabled`, cambia
   de tono al pasar en ambos backends (en el nativo por el retardo físico), y su tono se
   afirma con el estimador de frecuencia.
2. Spread, campo cercano y directividad medidos con su control.
3. La curva de atenuación da el mismo nivel en ambos backends (±1 dB) a 5 y 5.5 m.
4. Un marcador autorado y uno leído de un WAV generado emiten su señal a tiempo.
5. El spline sube y baja el tono con el flujo.
6. Observación 47 en `AGENTS.md`; `docs/funcionalidades.md` con el spline en 🟡 y los exports
   nuevos; banco y guardas dentro de techo.

---

## 15. Fuera de alcance

Gizmo de directividad, directividad nativa (Fase 12), incorporar el spline al sistema de
voces (obs 47, tarea propia), spread «fiel» con varias direcciones HRTF, pico verdadero,
importador de cues en el inspector.

---

## 16. Riesgos

| Riesgo | Mitigación |
|---|---|
| La reserva de 530 KB por voz con retardo | Solo al pedirlo; ajuste de proyecto acota; se cuenta en el banco de DSP |
| El estimador de frecuencia por cruces por cero es ruidoso | Tono puro, 0.5 s de captura, tolerancia del 2 % |
| El doppler por tono y el retardo físico se suman por error | Regla explícita en el canal y aserción: con ambos activos en nativo, el tono medido coincide con el del retardo solo |
| `panning_strength` como spread en `godot` no suena igual que el blend nativo | Es el fallback: se afirma lo que hace (el valor del mando), no la percepción |

---

## 17. Correcciones que la ejecución obligó a hacer a este spec

1. **La curva no es lo único que cae con el modelo `CURVE` (§9).** El multiplicador de la
   curva alimenta el shelf por distancia en el backend nativo, y en `godot` el multiplicador
   de su shelf incluye `volume_db` (que ahora lleva la curva): con la curva a −20 dB, ambos
   suman unos −10 dB más sobre ruido de banda ancha. Medido: −30.2 y −30.1 dB. Es coherente y
   se afirma como «al menos la curva» más paridad (< 1.5 dB) entre backends, no como igualdad
   con la curva. Y `Curve.sample()` interpola con Hermite: a mitad de camino entre dos puntos
   da lo que la curva dice, no la interpolación lineal que el spec suponía.
2. **Spread (§6).** Con `spatial_blend` 0.1 quedan unos 3 dB de ILD, no cero: se afirma que la
   fuente ancha deja menos de un cuarto del ILD de la fuente puntual, no la ausencia de ILD.
3. **Campo cercano (§7).** El realce es `6 dB x near_field` y el test pedia 6 dB con un factor
   de 0.6; se afirma `6 x nf +/- 1 dB` en los graves y el ILD adicional proporcional a `|dir.x|`.
4. **Retardo por distancia (§5).** A 343 m ninguno de los dos backends sonaba, y no por el
   retardo: el robo de voces descarta por `max_distance` (100 m). El test sube `max_distance`
   a 1000 m. Medido: el primer transitorio llega a 1.004 s (steam_audio) y 0.930 s (godot) a
   343 m, ~0.1 s a 34 m y < 5 ms con el retardo apagado.
5. **Atenuacion en el backend `godot` (§9).** Los reproductores anonimos del pool se quedaban
   con la atenuacion por defecto de Godot; ahora el canal les copia modelo, `unit_size`,
   `max_distance` y filtro de la instancia. Con `CURVE`, el reproductor queda en
   `ATTENUATION_DISABLED` y la curva va por `volume_db`.
6. **Ajustes en vivo (§6).** Aplicar la mezcla HRTF del menu solo a los flujos libres rompia
   el test de ajustes en vivo; se aplica a todos y el canal sobrescribe a los ocupados en su
   siguiente `apply_spatial` con `blend x (1 - spread)`.
7. **Marcadores (§11).** Mientras la voz es fisica el reloj logico no envolvia con el bucle
   (solo terminaba las no cicladas); ahora envuelve con `fmod` y los marcadores suenan en cada
   vuelta tambien en fisico. El test de marcadores escribe su propio WAV con `cue` y `LIST/adtl`.
8. **Flujo del spline (§10).** El doppler del spline suaviza con alfa 0.15 por llamada, asi
   que el test lo actualiza doce veces por caso. Medido con 20 m/s: 1.160 hacia el oyente,
   0.947 alejandose, 1.000 sin flujo. El spline sigue fuera del sistema de voces (obs 47).
9. **Suite.** Pasa de 90 s; el vigilante sube a 180 s. Los tests con nodos van a la suite
   asincrona porque los sincronos corren sin arbol. Total al cierre: 1224 aserciones, 529
   objetos vivos de 540.
10. **Coste del bucle de control (§14), por encima del techo.** El plan fijaba <= +5 % sobre
    4.09 / 4.25 us por voz (godot / steam_audio, 200 voces). Tres corridas al cierre de la
    fase: godot 4.31, 4.44 y 4.45 us; steam_audio 4.74, 4.77 y 4.83 us. Es decir, entre +5 y
    +9 % en godot y entre +12 y +14 % en steam_audio; tambien por encima del techo historico
    de +10 % sobre los 3.9 us de la Fase 6. El emisor hace mas por voz cada cuadro (movimiento
    y velocidad, doppler suavizado, directividad, curva, copia de la atenuacion al reproductor
    del pool). No se oculta: queda como deuda medida para la siguiente fase, con el camino
    obvio de saltar el calculo de cada rasgo cuando su export esta apagado.
