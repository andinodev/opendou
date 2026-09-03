# Fase 15 — Deudas C1–C5

**Fecha:** 2026-09-03
**Estado:** Implementado (2026-09-03); correcciones en §11.
**Rama:** `main`
**Godot verificado:** 4.7.2 · **Steam Audio:** 4.8.1
**Origen:** [`docs/tasks/observaciones-fases-12-14.md`](../../tasks/observaciones-fases-12-14.md) §C
**Fase anterior:** [14](2026-09-02-fase14-propagacion-y-geometria-dinamica-design.md)

---

## 1. Contexto

Las Fases 12–14 dejaron cinco deudas anotadas. Cuatro se pagan aquí; la quinta (C2, la demo de
los nodos de la Fase 10) se paga en la Fase 16 con la escena grande, que instancia esos nodos y
recorta `EXPECTED_UNCOVERED` a `opendou_event_player_2d.gd`. Decidido así para no construir
una demo pequeña que la grande volvería redundante una semana después.

Hechos comprobados al preparar el spec:

- **Observación 49.** Dentro de un `Area3D` con `reverb_bus_enabled`, Godot manda la salida del
  `AudioStreamPlayer3D` **solo** al bus de reverb del área. `target_bus`, instantáneas y ducking
  por bus no alcanzan a las voces 3D dentro de salas. El pool de reverb ya monta sus efectos con
  `dry = 0, wet = 1` (Sabine) y `dry = 1` (convolución) para compensar.
- Todos los reproductores y efectos de bus mezclan en **el mismo hilo de audio**, y en cada paso
  Godot mezcla primero los reproductores y después procesa los buses: un búfer escrito por los
  streams durante la mezcla puede ser leído por un efecto del bus en el mismo paso sin carreras.
- `OpenDouSpatialStreamPlayback::_mix` tiene la voz en **mono ya atenuada por distancia,
  filtrada, con efecto directo y retardo** justo antes del HRTF: el punto natural de un envío.
- Los buses del pool se comparten entre salas del mismo escalón de RT60 (`OpenDouReverb_N`):
  el envío es **por bus**, no por sala.
- `OpenDouSplineEmitter3D` y `OpenDouMultiPositionEmitter3D` extienden `AudioStreamPlayer3D`
  y **suenan por su cuenta** (obs 47): ni pool, ni robo de voces, ni grafo de salas, ni backend
  binaural. Mueven su propio nodo al punto más cercano al oyente. Las demos `workshop`,
  `monsoon` y `street` los instancian con `stream` y `autoplay`.
- El pool ya sabe de **emisores de nodo**: `position_node` aporta posición y atenuación y la voz
  sale por un reproductor del pool (`voice_pool_manager.gd`).
- `OpenDouLoudnessMeter` (GDScript) drena un `AudioEffectCapture` y filtra muestra a muestra:
  91 ms por segundo de audio (~9 % de un núcleo). La compuerta y las ventanas trabajan sobre
  **bloques de 100 ms** (10 números por segundo): lo caro es el filtro K por muestra.
- El altavoz de mundo (`OpenDouEventPlayer3D.source = BUS_CAPTURE`) captura el bus origen con
  un `AudioEffectCapture` (0.5 s) y lo reemite por un `AudioStreamGenerator` (0.2 s de búfer)
  bombeado desde `_process`. Su latencia nunca se midió.

---

## 2. Alcance

**Entra**

1. **C1 — Envío propio de reverb (backend `steam_audio`).** `OpenDouSendBus` nativo (acumuladores
   mono por bus del pool), `OpenDouReverbSendInput` (`AudioEffect` que inyecta el acumulado al
   inicio del bus), `set_send(id, gain)` en el stream; las salas dejan de usar `reverb_bus_enabled`
   en este backend y la voz vuelve a su `target_bus`.
2. **C3 — Spline y multiposición en el sistema de voces.** Ambos nodos publican un evento por el
   manager y aportan la posición cada cuadro como **proveedores de posición** de la instancia.
3. **C4 — LUFS nativo.** `OpenDouLoudnessTap` (`AudioEffect`): filtro K + potencia por bloque de
   100 ms + pico; `OpenDouLoudnessMeter` lo usa cuando existe y conserva compuerta y ventanas.
4. **C5 — Latencia del altavoz de mundo.** Medida con un click; techo afirmado en la suite y
   anotado en los documentos.
5. Documentación (observación 54).

**No entra**

- C2 (demo de los nodos de la Fase 10): Fase 16.
- Envío propio de reverb en el backend `godot` (sin extensión no hay dónde escribir el envío):
  la observación 49 sigue vigente allí y así se documenta.
- Reverb por convolución **por voz**.

---

## 3. C1 — Envío propio de reverb

**Nativo.**
- `OpenDouSendBus` (estático): `create() -> int`, `release(id)`, `accumulate(id, const float*
  mono, n, gain)` (hilo de audio, desde los streams), `drain(id, float* out, n)` (hilo de audio,
  desde el efecto). Cada envío es un anillo mono de 16384 muestras con índices de escritura y
  lectura; varios streams suman sobre la misma región (todos en el hilo de audio, en orden).
- `OpenDouReverbSendInput` (`AudioEffect` + instancia; propiedad `send_id`): en `_process`,
  `dst = src + drain(send_id)` copiado a L y R. Colocado en la **posición 0** del bus del pool,
  marcado `OpenDou_SendInput`. Sin envío o con `send_id < 0`, pasa `src` sin tocar.
- `OpenDouSpatialStream.set_send(id, gain)`: en `_mix`, después del campo cercano y antes del
  HRTF, `accumulate(send_id, mono, frame_size, gain)` si `id >= 0 && gain > 0`.

**Pool.** `OpenDouReverbBusPool` da a cada bus un `send_id` al crearlo (`send_id_for(bus)`), e
instala `OpenDouReverbSendInput` en la posición 0 (`install_send_input`) cuando la extensión
existe; `install_convolution` fija `dry = 0` si el bus tiene entrada de envío (la voz seca ya no
pasa por el bus). `release_all` libera los envíos.

**Sala.** `OpenDouRoom3D._route_native_reverb`: si el manager es `steam_audio` **y** el pool
tiene entrada de envío para el bus, `reverb_bus_enabled = false` y `runtime_room.send_id =
pool.send_id_for(bus)`; si no, como hoy (Godot enruta). `AudioRoom` gana `send_id: int = -1`.

**Manager.** En `_apply_voices`, para cada voz con posición espacial: `room =
spatial_acoustics.get_room_at_position(instance.emitter_position)`; `ch.set_send(room.send_id,
room.reverb_send_amount)` si la sala tiene envío, `ch.set_send(-1, 0)` si no. El canal lo empuja
al stream solo cuando cambia. La consulta de sala por voz ya existe para las reflexiones
(`reflections_allowed_for`); se hace una vez por voz y cuadro.

**Se afirma** (`tests/test_reverb_send.gd`, backend `steam_audio`): con la voz dentro de una
caja `CONVOLUTION` de hormigón y `target_bus = ParityProbe`, la sonda del bus destino oye el
tono (RMS > −20 dB; hoy −200 por la observación 49); el bus de reverb de la sala tiene cola tras
el tono (> −45 dB en 0.05–0.2 s tras el final) y **no** tiene el tono seco (durante el tono, el
bus de reverb queda al menos 6 dB por debajo del bus destino); con `reverb_send_amount = 0` el
bus de reverb calla (< −80 dB). Control: en backend `godot`, el bus destino sigue mudo (−200;
observación 49 documentada). Los tests de Fase 13 que capturaban en el bus de reverb
(`test_convolution_reverb`, `test_demo_scenes` taller) se adaptan: el tono seco se mide en el
bus destino y la cola en el de reverb.

---

## 4. C3 — Proveedores de posición

`EventInstance.position_provider: Object = null` con el contrato `resolve_emitter_position(
listener_position: Vector3) -> Vector3` y, opcional, `resolve_flow_velocity(listener_position)
-> Vector3`. En `_apply_voices`, **antes** del emisor de nodo: si hay proveedor, `instance.
set_position(provider.resolve_emitter_position(active_listener_position))` y `flow_velocity`.
El pool no cambia: la voz es una voz del pool en ambos backends (el nodo no se liga como
reproductor).

**`OpenDouSplineEmitter3D` y `OpenDouMultiPositionEmitter3D`** ganan `event_def:
AudioEventDef`, `auto_play_event: bool` (por defecto sigue a `autoplay`), `play_event()`,
`stop_event()`, `active_instance`. Sin `event_def`, `stream` se envuelve en una definición
propia (`looping` según el `AudioStreamWAV`/`autoplay`, `target_bus = bus`). Publican con
`manager.post_event(def, self)`, fijan `active_instance.position_provider = self`,
`copy_attenuation_from_player(self)`, y **dejan de reproducir por su cuenta** (`stream` ya no
suena en el nodo; `_ready` llama `stop()`). El spline conserva `update_spline_acoustics` como
cabeza de reproducción visual (los tests de anclaje siguen) pero sin doppler ni aire propios:
los hace el sistema de voces (`flow_velocity` del proveedor entra al doppler de la Fase 9).
El multiposición conserva su geometría (`get_closest_point_to`, `calculate_blended_position`,
malla); `_process` ya no mueve el nodo: `resolve_emitter_position` devuelve el punto suavizado.

**Se afirma** (`tests/test_position_provider.gd`, ambos backends): spline recto de (−20,0,−3) a
(20,0,−3) con oyente en el origen → tras 10 cuadros `emitter_position ≈ (0,0,−3)` (±0.2) y la
voz es del pool (`ch.get_player() != nodo`); oyente en (10,0,0) → `x ≈ 10`. Multiposición con
puntos (−5,0,−5) y (5,0,−5) y oyente en (4,0,0) → `emitter_position ≈ (5,0,−5)`. En steam_audio,
ILD medida con el oyente desplazado: el sonido viene del punto cercano (ILD del mismo signo que
la geometría). Las demos que los usan siguen verdes (`test_demo_scenes`).

---

## 5. C4 — LUFS nativo

`OpenDouLoudnessTap` (`AudioEffect` + instancia): filtro K (BS.1770-4: shelf + paso-alto, los
mismos coeficientes que el GDScript, calculados a la tasa del servidor) por canal; suma de
potencias L+R por **bloque de 100 ms**; anillo de 64 bloques cerrados (6.4 s) con contador
monótono; pico muestral. API: `take_blocks() -> PackedFloat32Array` (bloques cerrados desde la
última llamada, en orden), `take_peak() -> float` (pico desde la última llamada), `reset()`.
Todo el estado de audio en la instancia; el intercambio con el hilo principal por índices
atómicos (el anillo es de un solo escritor y un solo lector).

`OpenDouLoudnessMeter.attach(bus)`: si `ClassDB.class_exists("OpenDouLoudnessTap")`, instala el
efecto (marcado `OpenDou_LoudnessMeter_Tap`) en lugar del `AudioEffectCapture`; `process()`
toma los bloques y el pico y alimenta `_blocks`/`_close_block()` como hoy. `use_native: bool`
(solo lectura) dice cuál está activo; `force_gdscript` para el test de equivalencia.

**Se afirma** (`tests/test_loudness_meter.gd`): el tono de calibración da −23.0 LUFS (±0.5) en
integrada, corto plazo y momentánea, y pico −23 dBFS (±0.3) **con el tap nativo**; el modo
GDScript forzado da lo mismo (±0.2 LU entre ambos sobre el mismo tono); el coste del nativo
medido en `last_process_usec` es menor de 5 ms por segundo de audio (hoy 91). Sin extensión,
el medidor sigue en GDScript.

---

## 6. C5 — Latencia del altavoz de mundo

Test `tests/test_world_speaker_latency.gd`: bus `WorldSrc` con un click (una muestra a 0 dBFS
seguida de silencio, repetido cada 0.5 s) reproducido por un `AudioStreamPlayer` en ese bus;
un `OpenDouEventPlayer3D` con `source = BUS_CAPTURE`, `capture_bus = WorldSrc`, `bus_category
= ParityProbe` a 1 m del oyente; sondas en ambos buses (la de `WorldSrc` **antes** del efecto
de captura y del −80 dB: se engancha primero y se lee el pico en su captura); la latencia es la
diferencia entre el índice del primer pico de la sonda origen y el del primer pico de la sonda
destino, en ms. Se afirma que la latencia es **menor de 250 ms** y estable (tres clicks, ±20
ms). El valor medido se anota en `funcionalidades.md`. Si la medida supera 120 ms, el búfer del
generador baja de 0.2 a 0.1 s y se vuelve a medir (§11 lo dice).

---

## 7. Orden y documentos

C1 → C3 → C4 → C5 → documentos. `funcionalidades.md` (filas de sala, spline, multiposición,
LUFS, altavoz de mundo; §3.2 nueva fila «Envío propio de reverb»), `AGENTS.md` (observación 54:
el envío propio; la observación 49 queda acotada al backend `godot`), `current.md`, este spec
§11, `observaciones-fases-12-14.md` §C (C1, C3, C4, C5 pagadas; C2 → Fase 16).

## 8. Riesgos

- El acumulado del envío y el drenaje del efecto podrían **desfasarse** si Godot mezcla un
  reproductor en dos trozos dentro de un paso: el anillo lo absorbe; el efecto drena solo lo
  disponible y rellena con ceros.
- Un bus del pool con varias salas mezcla los envíos de todas: es lo mismo que hace Godot hoy
  con el `Area3D`.
- Cambiar los emisores de spline/multiposición a voces del pool cambia **qué** suena en las
  demos (ahora pasan por HRTF y salas): los tests de demo miden niveles con tolerancia, se
  comprueban.

## 9. Tests

`test_reverb_send.gd`, `test_position_provider.gd`, `test_loudness_meter.gd` (ampliado),
`test_world_speaker_latency.gd`; adaptaciones en `test_convolution_reverb.gd` y
`test_demo_scenes.gd`.

## 10. Fuera de alcance explícito

Ducking y snapshots dentro de salas quedan cubiertos **de rebote** por C1 (la voz vuelve a su
bus); no se les añade test propio en esta fase más allá del nivel en el bus destino.

## 11. Correcciones que la ejecución obligó a hacer

1. **C1, el mecanismo (§3).** El efecto de entrada (`OpenDouReverbSendInput`) no sirve: un bus sin
   reproductores está inactivo para Godot (no llega a Master, no limpia su búfer, el efecto
   realimenta y explota). El envío sale por `OpenDouSendStream` reproducido por un
   `AudioStreamPlayer` hijo del manager en el bus de reverb. Los ids de envío son estáticos del
   pool; el manager libera sus reproductores en `_exit_tree`.
2. **C1, la afirmación «6 dB por debajo» (§3)** era falsa: el reverb temprano de una caja de 6 m
   iguala al seco. Se afirma «no lleva seco» con `wet = 0` y envío 1 (−180 dB).
3. **C1, tests que asumían el `Area3D`**: `room_reverb` usa una voz del manager y la sala se
   registra en ese manager; el taller mide el motor en el bus `Engine`; el presupuesto de la
   calle sube a [−33, −19] (las voces en salas vuelven a sonar en seco + envío) y el del taller
   baja a [−33, −18] (la lona pasa por el pool).
4. **C3, la caché de caminos (§4).** Por par de salas, la primera voz fijaba el portal de todas;
   la clave lleva la celda de 4 m del emisor. `post_event(def, self)` pisa la posición cada
   cuadro: los proveedores publican con `caller = null`.
5. **C3, tests del spline y la malla**: el doppler ya no está en el nodo; `spline_flow` mide el
   `doppler_pitch` de la voz (1.057 / 0.953 / 0.997) y `mesh_emitter` el punto resuelto.
6. **C4 (§5).** El tap vive en la instancia del efecto y el recurso guarda la última instancia;
   `reset()` se aplica en el hilo de audio con una bandera. Medido: −23.26 LUFS en ambos
   caminos; 0.81 ms/s nativo frente a 72.9 GDScript.
7. **C5 (§6).** 107.3 ms, idéntica en cuatro clicks; bajo los 120 ms del recorte: búferes sin cambio.
8. **Suite.** El driver headless corre a 0.84 s de audio por segundo bajo carga: `loudness_meter`
   espera por `processed_seconds`, el retardo `godot` se afirma con el reloj de pared, y
   `_band_energy_stereo` promedia por periodo (dos medidas del mismo sonido diferían 3 dB).
   1560 aserciones, 527 objetos vivos de 540; banco a 200 voces: godot 3.45–3.48, steam_audio 3.57–3.69 µs por voz (techo 4.3).
