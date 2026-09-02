# Fase 11 — Emisores nuevos y modos

**Fecha:** 2026-09-02
**Estado:** Implementado (2026-09-02); correcciones en §12.
**Rama:** `main`
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Hoja de ruta:** [`docs/roadmap/2026-09-02-sprint-aaa.md`](../../roadmap/2026-09-02-sprint-aaa.md), Fase 11
**Fase anterior:** [10](2026-09-02-fase10-oyente-y-entorno-design.md)

---

## 1. Contexto

Las fases 9 y 10 completaron el emisor, el oyente y el entorno. Esta fase añade lo que falta
para que un nivel suene sin un script por cada cosa: los cuerpos que chocan suenan solos, un
personaje habla con subtítulos y boca, una superficie irregular suena desde su punto más
cercano, la mezcla de un bus se convierte en un objeto del mundo (la radio del taller), y los
volúmenes disparan eventos. Todo se ejercita en una demo nueva, «El taller», compuesta como
árbol de nodos según `.agents/rules/04_scene_composition.md`.

Según `docs/ideas/nodos-de-escena.md` §H3: dos nodos nuevos (impactos y diálogo, con ciclo de
vida propio), tres **modos** de nodos existentes (malla en el emisor multiposición, captura
de bus en el emisor 3D, disparadores en el área de parámetros) y una **demo con plantilla**
para el vehículo (no un nodo del plugin).

Hechos comprobados al preparar el spec:

- **`PhysicsMaterial` no tiene material acústico.** La superficie se lee de los metadatos
  `surface_type` del cuerpo (o de palabras clave en su nombre), como ya hace
  `SpatialAcousticsManager.detect_surface_at`. El impacto lee lo mismo de los dos cuerpos.
- **`body_entered` no trae normal ni punto de contacto.** `PhysicsServer3D.body_get_direct_state
  (rid)` sí: `get_contact_count()`, `get_contact_collider_object(i)`, `get_contact_local_normal(i)`,
  `get_contact_collider_position(i)`. Es válido dentro del paso de física en que se emite la
  señal; exige `contact_monitor = true` y `max_contacts_reported > 0` en el `RigidBody3D`.
- **Los switches por entidad ya existen** (`GameSyncManager.set_switch(group, state, entity)`) y
  `refresh_playback_context` los pasa al `AudioSwitchContainer` por el `caller` del `post_event`.
  El impacto postea con `caller = self` tras fijar el switch de material en sí mismo.
- **`AudioDialogueManager` toca un `AudioStreamPlayer` directo y el bus `Voice`**; no pasa por
  el sistema de voces ni sabe de posición. `AudioDialogueTable.get_stream(key, lang, fallback)`
  resuelve el stream por idioma. **No guarda subtítulos** (se comprueba en el plan; si no los
  guarda, el nodo los lleva en un `Dictionary` propio `subtitles[key][lang]`).
- **No hay fonemas en Godot.** La boca es la **envolvente de amplitud del WAV** (precalculada
  con `OpenDouWavDecoder.to_mono_floats` en ventanas de 10 ms) leída con el reloj lógico de la
  instancia, más los **visemas autorados** como marcadores (`AudioMarker` con nombre
  `viseme:<nombre>`, Fase 9). Se dice así en el nodo y en los documentos.
- **`OpenDouMultiPositionEmitter3D` ya muestrea vértices de una malla** (`update_points_from_mesh`,
  uno de cada ocho) y elige el más cercano. Eso no es «el punto más cercano de la malla»: en
  un plano de 1000 triángulos deja huecos de varios metros. El modo `MESH` busca el punto más
  cercano **sobre los triángulos** con un árbol de cajas (BVH por mediana) e histéresis.
- **`AudioStreamGenerator` ya se usa** en `OpenDouGranularEmitter3D`. Para el altavoz de mundo
  la fuente de la voz es un generador alimentado por un `AudioEffectCapture` del bus origen.
  En el backend `steam_audio` el reproductor del pool reproduce un `OpenDouSpatialStream` cuyo
  `source` es el generador: para empujar muestras hace falta el **playback interno**, que hoy
  el nativo no expone. Se añade `OpenDouSpatialStreamPlayback.get_source_playback()`.
- **El volumen de un bus se aplica al enviarlo** (trampa de la Fase 8): un `AudioEffectCapture`
  en el bus origen sigue viendo la señal aunque el bus esté a −80 dB. Así se silencia la
  salida directa sin perder la captura.
- **`OpenDouParameterArea3D` ya tiene `register_target_entered(target)`** con filtro por máscara
  física e histéresis; el disparador entra ahí.
- **Las demos se componen en el `.tscn`** y `tests/test_scene_guards.gd` lo hace cumplir por
  mínimo de nodos y por scripts de OpenDou requeridos. Los eventos se autoran en código
  porque los streams se sintetizan (única excepción legítima).

---

## 2. Alcance

**Entra**

1. `OpenDouPhysicsImpact3D` (nodo hijo de `RigidBody3D`).
2. `OpenDouDialogueEmitter3D` (nodo): línea por idioma, subtítulos, ducking absoluto,
   `mouth_amplitude`, visemas autorados.
3. `OpenDouMultiPositionEmitter3D.source_mode = MESH` con BVH e histéresis.
4. `OpenDouEventPlayer3D.source = BUS_CAPTURE` con `capture_bus`; nativo:
   `get_source_playback()`.
5. Disparadores en `OpenDouParameterArea3D`: `trigger_event`, `trigger_probability`,
   `trigger_cooldown_sec`, `trigger_once`, `trigger_group`.
6. Demo «El taller» + plantilla de motor (`scenes/shared/vehicle_engine_events.gd`), guarda de
   composición, aserciones de escena y presupuesto de sonoridad.
7. Documentación: `funcionalidades.md`, `AGENTS.md` (observación 49 y trampas), `current.md`.

**No entra**

- Fonemas o visemas automáticos (se dice).
- Un nodo de vehículo en el plugin: el motor es una plantilla del grafo y una demo.
- Voz de red (H2.5): el modo `BUS_CAPTURE` la hace posible, no la implementa.
- Impactos continuos (arrastre, rodadura): solo el choque.

---

## 3. `OpenDouPhysicsImpact3D`

`Node3D`, en `addons/opendou/nodes/opendou_physics_impact_3d.gd`. Hijo directo de un
`RigidBody3D`; si el padre no lo es, avisa una vez y no hace nada.

**Exports**

| Export | Defecto | Efecto |
|---|---|---|
| `event_name` | `&""` | Evento a postear (nombre registrado en el manager). |
| `event_def` | `null` | Alternativa al nombre. |
| `min_speed_mps` | 0.5 | Por debajo de esta velocidad normal relativa, nada. |
| `cooldown_sec` | 0.1 | Recarga entre impactos del mismo cuerpo. |
| `material_switch_group` | `&"Material"` | Grupo del switch que recibe el material del **otro** cuerpo. |
| `force_rtpc` | `&"ImpactForce"` | RTPC local con la velocidad normal relativa (m/s). |
| `mass_rtpc` | `&"ImpactMass"` | RTPC local con la masa del cuerpo propio (kg). |
| `default_material` | `&"Concrete"` | Si el otro cuerpo no declara superficie. |

**Comportamiento.** En `_ready` activa `contact_monitor` y sube `max_contacts_reported` a 4 como
mínimo en el padre, y conecta `body_entered`. Al entrar un cuerpo: lee el estado directo del
padre, busca el contacto con ese cuerpo (normal y punto; si no lo encuentra, normal =
dirección al otro cuerpo y punto = posición propia), calcula `speed = |(v_propia − v_otro) ·
normal|` (`v_otro` = 0 si no es `RigidBody3D`), y si `speed ≥ min_speed_mps` y pasó la recarga:
material del otro cuerpo (`surface_type` en metadatos → palabras clave del nombre →
`default_material`), `sync_manager.set_switch(material_switch_group, material, self)`,
`post_event(evento, self)`, `set_parameter(force_rtpc, speed, true)`,
`set_parameter(mass_rtpc, masa, true)`, `set_position(punto)`. Emite
`impact_posted(speed, mass, material, position)`.

**Se afirma** (física headless, cuerpos reales): un cuerpo que cae sobre una placa con
`surface_type = Metal` a 2 m/s y otro a 8 m/s: `ImpactForce` del segundo entre 3.2 y 4.8
veces la del primero, y los dos con el switch `Metal`; a 0.2 m/s con umbral 0.5, ningún
evento; dos contactos en 50 ms con recarga 0.1 s, un solo evento.

---

## 4. `OpenDouDialogueEmitter3D`

`Node3D`, en `addons/opendou/nodes/opendou_dialogue_emitter_3d.gd`.

**Exports:** `dialogue_table: AudioDialogueTable`, `language` (`"en"`; vacío = el del
`AudioDialogueManager` del manager si existe), `fallback_language` (`"en"`), `subtitles:
Dictionary` (`key → {lang → texto}`) si la tabla no los trae, `bus_category` (`"Voice"`),
`duck_bus` (`&"Music"`), `duck_db` (−12), `duck_attack_sec` (0.05), `duck_release_sec` (0.4),
`mouth_window_ms` (10), `markers: Array[AudioMarker]` (visemas autorados: nombre `viseme:X`).

**API y señales**

- `speak(key: StringName) -> EventInstance`: resuelve el stream por idioma, construye o reutiliza
  un `AudioEventDef` propio (`target_bus = bus_category`, `markers` del nodo), postea con
  `caller = self`, precalcula la envolvente del WAV (si es `AudioStreamWAV`; si no, la boca
  queda en 0 y se avisa una vez), activa el ducking y emite `line_started(key)` y
  `subtitle_changed(texto)` (vacío si no hay subtítulo).
- `stop_speaking(fade_sec = 0.05)`.
- `is_speaking() -> bool`, `mouth_amplitude: float` (0..1, actualizado cada cuadro desde la
  envolvente en `logical_playback_position`), `current_viseme: StringName`.
- Señales: `line_started(key)`, `line_finished(key)`, `subtitle_changed(text)`,
  `viseme_changed(viseme)`.

**Ducking absoluto.** Al empezar la línea: `manager.mix.ducking.add_rule(bus_category,
duck_bus, duck_db, attack, release)` (idempotente por par) y `set_bus_active(bus_category,
true)`; al terminar, `set_bus_active(false)`. La matriz ya escribe en el `AudioServer` desde la
Fase 8. «Absoluto» significa que el valor lo fija la línea, no la mezcla del momento; si otra
regla ya ducka más, gana la mayor atenuación (comportamiento de la matriz).

**Se afirma:** una línea sintetizada (tono con envolvente: fuerte 0–0.5 s, silencio 0.5–1 s):
`mouth_amplitude > 0.5` a 0.25 s y `< 0.05` a 0.75 s; `subtitle_changed` llega con su texto al
empezar; el bus `Music` baja al menos 10 dB durante la línea (medido con `get_bus_volume_db`
tras el ataque) y vuelve a ±0.5 dB de su base tras la liberación; un marcador `viseme:AA` a
0.2 s emite `viseme_changed(&"AA")` y deja `current_viseme` en `AA`.

---

## 5. Emisor de malla como modo

`OpenDouMultiPositionEmitter3D` gana `source_mode: {POINTS, MESH}` (defecto `POINTS`, sin
cambio de comportamiento), `mesh_path: NodePath` y `mesh_hysteresis_m` (0.25).

**MESH.** En `_ready` y en `rebuild_mesh()`: lee `mesh.get_faces()` del `MeshInstance3D`,
transforma al espacio del emisor y construye un BVH por mediana (`OpenDouTriangleBVH`,
`RefCounted`, en `addons/opendou/runtime/spatial/triangle_bvh.gd`): nodos con AABB y hasta 8
triángulos por hoja. `closest_point(p) -> Vector3` baja por el árbol con poda por distancia a la
caja y punto más cercano sobre triángulo (proyección al plano y a las aristas). Cada cuadro el
emisor pide el punto más cercano al oyente; si el nuevo punto está a menos de
`mesh_hysteresis_m` del actual no se mueve (evita el temblor entre dos triángulos).

**Se afirma:** un plano de 1000 triángulos (`PlaneMesh` 40×40 m subdividido): el origen aparente
queda a menos de 1 cm del punto exacto para 20 posiciones aleatorias del oyente (comparado con
la fuerza bruta sobre todos los triángulos); a menos de una arista (2 m) siempre; coste de la
consulta bajo 150 µs (mediana de 50); con `POINTS` nada cambia respecto a hoy.

---

## 6. Altavoz de mundo como modo

`OpenDouEventPlayer3D` gana `source: {EVENT, BUS_CAPTURE}` (defecto `EVENT`) y `capture_bus:
StringName`.

**BUS_CAPTURE.** Al reproducir: añade (o reutiliza, marcado `OpenDou_WorldBus_Capture`) un
`AudioEffectCapture` de 0.5 s en `capture_bus`, pone el bus a −80 dB (la captura es anterior
al volumen), crea un `AudioStreamGenerator` (`mix_rate` del servidor, `buffer_length` 0.2 s) como
stream de un `AudioEventDef` propio (`is_looping = true`, `stream_length = 0`) y postea. Cada
cuadro, mientras suene: pide al canal `get_source_playback()` y empuja al generador todo lo
disponible en la captura (`get_buffer(avail)` → `push_buffer`), rellenando con silencio la
primera vez para no quedarse sin muestras. Al parar: quita la captura y devuelve el volumen
del bus. El resto del emisor (posición, oclusión, directividad, spread…) se aplica igual: la
voz es «lo que suena en el bus».

**Nativo.** `OpenDouSpatialStreamPlayback.get_source_playback() -> AudioStreamPlayback`
(devuelve `inner_`). `PhysicalVoiceChannel.get_source_playback()` lo resuelve en los dos
backends: `player.get_stream_playback()` en godot; en steam_audio el `get_source_playback()` del
playback del stream nativo.

**Latencia.** Captura + generador: unos dos bloques del servidor más el anillo del stream
nativo. Se mide y se anota.

**Se afirma:** un tono de 1 kHz que suena solo en un bus `Radio` (a −80 dB de salida directa)
aparece en el bus del emisor con RMS > −30 dBFS y una ILD > 3 dB con el emisor a la derecha;
al moverlo a la izquierda, la ILD cambia de signo; en Master no hay energía del tono cuando el
emisor para y el bus sigue a −80 (la salida directa está silenciada).

---

## 7. Disparadores en `OpenDouParameterArea3D`

Exports nuevos (grupo «Trigger»): `trigger_event: StringName` (`&""` = ninguno),
`trigger_probability` (1.0), `trigger_cooldown_sec` (0.0), `trigger_once` (false),
`trigger_group: StringName` (`&""` = cualquier cuerpo). En `register_target_entered(target)`,
tras el registro: si hay evento, el cuerpo está en el grupo (o no hay filtro), pasó la
recarga, no se agotó el «una vez» y `randf() < probabilidad`: `post_event(trigger_event,
target)` y señal `triggered(event_name, target)`.

**Se afirma:** un cuerpo del grupo `player` entra: el evento suena una vez y `triggered` llega;
vuelve a entrar antes de la recarga: nada; otro cuerpo sin el grupo: nada; con
`trigger_once`, la segunda entrada tras la recarga tampoco dispara; con probabilidad 0, nunca.

---

## 8. Demo «El taller»

`scenes/demos/workshop/workshop_demo.tscn` + `workshop_demo.gd`, tarjeta en el hub. Compuesta
en el `.tscn` (mínimo 30 nodos declarados); el script solo autora eventos (streams
sintetizados), reacciona a teclas y a señales.

**Nodos:** `OpenDouRoom3D` «Taller» (material `Concrete`, `floor_surface` `Concrete`) con su
`CollisionShape3D`; suelo `StaticBody3D` con `surface_type = Concrete`; mesa metálica
`StaticBody3D` con `surface_type = Metal`; tres `RigidBody3D` (lata, caja, llave inglesa) con
`OpenDouPhysicsImpact3D` hijo, posados en una repisa alta que la tecla `E` suelta (el script
pone `freeze = false`); mecánico (`npc.tscn` compartido) con `OpenDouDialogueEmitter3D`; un
`OpenDouParameterArea3D` frente al mecánico con `trigger_event = &"MechanicGreets"` y
`trigger_group = &"player"`, cuya señal `triggered` el script convierte en `speak(&"greet")`;
radio: `OpenDouEventPlayer` que reproduce un bucle sintetizado en el bus `Radio` y
`OpenDouEventPlayer3D` «RadioSpeaker» con `source = BUS_CAPTURE`, `capture_bus = &"Radio"` y
directividad dipolo 0.7; motor: `OpenDouEventPlayer3D` «Engine» con la plantilla de vehículo;
lona irregular: `OpenDouMultiPositionEmitter3D` en `MESH` sobre un `MeshInstance3D` con un
`PlaneMesh` deformado (viento en la lona, ruido de banda); `OpenDouAcousticGeometryBake`,
`OpenDouAcousticDebugger3D`, `Player`, `Hud`, `PauseMenu`, luz.

**Plantilla de motor** (`scenes/shared/vehicle_engine_events.gd`, estático `register(manager)`):
un `AudioEventDef` «WorkshopEngine» con `root_container = AudioBlendContainer(&"RPM", 600,
6000)` de tres capas granulares sintetizadas (ralentí, medio, alto) con curvas de volumen
cruzadas, y un `AudioSwitchContainer(&"Load")` con ramas `Idle` y `Load` que cambia el conjunto
de capas (más graves bajo carga). RTPC `RPM` y switch `Load` los mueve el script con las
teclas `↑/↓` y `Espacio`. Es demo y preset, no nodo.

**Se afirma** (`tests/test_demo_scenes.gd`, `run_workshop_async`): la escena carga y declara ≥ 30
nodos con los scripts requeridos (guarda); al soltar la repisa, al menos un `impact_posted`
llega con material `Metal` (la mesa) o `Concrete` (el suelo) y `ImpactForce > 1`; `RPM` de 800
a 4000 cambia la capa dominante (la energía del bus `Engine` sube al menos 3 dB o cambia el
centroide espectral); la radio tiene ILD ≠ 0 en su bus; el área del mecánico dispara
`MechanicGreets` y el emisor de diálogo emite `subtitle_changed`; presupuesto LUFS «workshop»
en `tests/loudness_budget.txt` medido en la primera corrida y fijado con ±4 LU.

---

## 9. Cambios en lo que existe

| Archivo | Cambio |
|---|---|
| `nodes/opendou_multi_position_emitter_3d.gd` | `source_mode`, `mesh_path`, `mesh_hysteresis_m`, `rebuild_mesh()`, consulta al BVH en `_process`. |
| `nodes/opendou_event_player_3d.gd` | `source`, `capture_bus`, bombeo por cuadro, captura marcada, volumen del bus. |
| `nodes/opendou_parameter_area_3d.gd` | grupo «Trigger» y `_maybe_trigger` en `register_target_entered`. |
| `runtime/physical_voice_channel.gd` | `get_source_playback()`. |
| `native/src/spatial_stream.{h,cpp}` | `OpenDouSpatialStreamPlayback::get_source_playback()`. |
| `tests/test_scene_guards.gd` | entrada del taller (min 30, requires). |
| `tests/test_demo_scenes.gd`, `tests/loudness_budget.txt` | `run_workshop_async`, presupuesto. |
| `scenes/demos/demo_hub.tscn` | sexta tarjeta (la guarda del hub pasa de cinco a seis). |

---

## 10. Tests

- `tests/test_physics_impact.gd` (física headless real, `await physics_frame`).
- `tests/test_dialogue_emitter.gd` (WAV sintetizado con envolvente; bus `Music` creado por el test).
- `tests/test_mesh_emitter.gd` (BVH contra fuerza bruta; coste).
- `tests/test_world_bus.gd` (tono en `Radio`, ILD en el bus del emisor, silencio directo).
- `tests/test_area_trigger.gd` (`register_target_entered` con cuerpos en grupos).
- `tests/test_demo_scenes.gd::run_workshop_async` y guarda de composición.

Reglas de siempre: bus de sonda para diferencias de nivel (Master lleva el compresor);
`set_manager()` o `set_event_manager()` en los nodos porque el autoload existe en la suite;
esperar por muestras; cámara u oyente para que suene un 3D.

---

## 11. Riesgos

- **Contactos en headless.** Si `body_get_direct_state` no trae el contacto en el instante de
  `body_entered`, el nodo cae a la aproximación (dirección al otro cuerpo) y el test lo dice.
- **Generador sin muestras.** Si el bombeo por cuadro no alcanza (cuadros de 2 ms en headless
  con bloques de 512), el generador se queda sin datos y hay huecos; se prellena 0.1 s y se
  mide el RMS, no la continuidad.
- **Coste del BVH en GDScript.** 1000 triángulos, consulta O(log n) con poda; si supera 150 µs,
  se reduce el número de hojas visitadas con histéresis mayor y se anota.
- **La demo es grande.** Si la composición pasa de 60 nodos, las subescenas (repisa con los
  tres cuerpos, rincón de la radio) van a `.tscn` propios.

---

## 12. Correcciones que la ejecución obligó a hacer

1. **Velocidad de impacto (§3).** Cuando llega `body_entered` la velocidad ya está resuelta
   a 0: el nodo guarda la velocidad en `_physics_process` (antes del paso) y usa esa. Medido:
   2.16 y 8.15 m/s (×3.77), material `Metal`, masa 1.0, punto de contacto real. El caso «bajo
   el umbral» usa umbral 1.0 porque la gravedad en 2 cm suma 0.66 m/s a los 0.2 iniciales.
2. **El blend no cruzaba (§8, plantilla de motor).** El runtime reproducía solo `voices[0]` y
   tiraba los desplazamientos (observación 50). Se implementaron capas reales: un canal por voz
   resuelta (hasta 4 extra), desplazamientos aplicados también a la principal y re-resueltos
   cada cuadro cuando el árbol es determinista (`AudioLogicNode.is_deterministic()`). Medido:
   Mix 0 → grave +40 dB; Mix 1 → aguda +65 dB; Mix 0.5 → las dos presentes y reducidas.
3. **RTPC locales lentos.** `RTPCValue` a 10 unidades/s: 900 → 5000 rpm tardaba siete
   minutos. `EventInstance.set_parameter` escala la velocidad con el salto (asienta en 0.25 s).
4. **El bus de la voz dentro de una sala (§8, demo).** Dentro de un `Area3D` con reverb, Godot
   manda la salida del reproductor 3D **solo** al bus de reverb (observación 49). El motor se
   mide en el bus de reverb del taller: a 800 rpm media/grave −25.8 dB, a 5000 rpm +9.5 dB.
5. **Altavoz de mundo y aplicador de mezcla (§6).** El bus origen se calla también en la base
   del aplicador (`set_bus_base_volume_db`), porque el ducking del diálogo del taller nombra
   `Radio` y el aplicador lo reescribía cada cuadro. El test usa el autoload, como las demos.
6. **Centroide (§8).** El estimador de la suite empieza en 229 Hz; el motor se mide por bandas
   (20–150 frente a 150–800 Hz).
7. **`loop_end = num_samples` pica en el bucle.** Descubierto por el pico espurio del medidor
   LUFS (seis apariciones en tres fases); `tools/probe_loop_click.gd`. El sintetizador pasa a
   `num_samples − 1`.
8. **Latencia del altavoz (§6).** Medida indirecta: la voz aparece con RMS −15.5 dBFS e ILD
   ±17 dB; el colchón inicial es 0.1 s y la captura se drena por cuadro.
9. **Guarda de cobertura.** `EXPECTED_UNCOVERED` pasa a lista: el 2D y los cuatro nodos de
   la Fase 10 no tienen demo todavía.
10. **Suite.** 1394 aserciones, 527 objetos vivos de 540; sonoridad del taller −22.9 LUFS
    (rango −30 a −18). Banco a 200 voces: 3.32–3.39 / 3.37–3.81 µs, sin regresión.
