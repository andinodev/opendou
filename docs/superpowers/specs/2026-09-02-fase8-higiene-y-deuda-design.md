# Fase 8 — Higiene y deuda: la mezcla limpia

**Fecha:** 2026-09-02
**Estado:** Aprobado en diseño, pendiente de plan.
**Rama:** `main`
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Hoja de ruta:** [`docs/roadmap/2026-09-02-sprint-aaa.md`](../../roadmap/2026-09-02-sprint-aaa.md), Fase 8
**Fase anterior:** [7B](2026-09-02-fase7b-binaural-todas-las-voces-design.md)

---

## 1. Contexto

Esta fase no añade nada que se oiga nuevo. Repara promesas que el plugin hace y no cumple, y
pone bajo medida la mezcla, para que todo lo que venga después (emisor completo, oyente,
entorno, Steam Audio) se evalúe sobre una base honesta. Lo que se encontró al preparar el spec,
leyendo el código y no la documentación:

| Promesa | Dónde se hace | Qué pasa de verdad |
|---|---|---|
| `AudioEventDef.max_instances = 5` | Export visible en el inspector desde el inicio del proyecto | **Ningún código lo lee.** Cualquier evento puede tener mil instancias |
| Instantáneas de mezcla (`AudioMixSnapshotManager`) | `transition_to()`, `apply_snapshot_instant()`, `update()` interpolan estados por bus | **Nadie escribe ese estado en el `AudioServer`.** Solo el editor instancia el gestor, para enseñarlo |
| Ducking entre buses (`AudioDuckingMatrix`) | Calcula atenuaciones por regla; `AudioDialogueManager` lo activa | **Nadie aplica la atenuación a ningún bus.** `get_ducking_attenuation_db()` no tiene consumidor |
| `OpenDouParameterArea3D.target_snapshot` | Al entrar llama `mgr.call("push_snapshot", …)` tras un `has_method` | El manager **no tiene** `push_snapshot` ni `pop_snapshot`: la llamada nunca ocurre |
| Test de «Una casa canta» | Afirma que la música sale por la ventana | Falla de forma **intermitente** con el origen aparente en la puerta (observación 43) |
| Mezcla final | Cuatro demos | **Ningún limitador en Master**; nada mide la sonoridad |

`docs/funcionalidades.md` marcaba instantáneas, ducking y el área de parámetros en verde. Se
corrige en esta fase: pasan a ⚪ hasta que 8.5 esté verde, y vuelven a ✅ con su aserción.

### Decisiones tomadas

| Decisión | Valor | Razón |
|---|---|---|
| Defecto de `max_instances` | **0 = sin límite** (antes 5, inerte) | Aplicar el 5 rompería «El monzón» (200 voces del mismo evento). Nada cambia hasta que una definición lo suba a propósito. Cambio de semántica documentado |
| Aplicación de la mezcla al servidor | En el **runtime**, dueño el `AudioEventManager`, cada frame | Es la única forma de que instantáneas, ducking y el área de parámetros hagan algo |
| Medidor LUFS | GDScript, **apagado por defecto**, encendido por el cajón de mezcla, la suite o un ajuste | Procesar 44 100 muestras por segundo en GDScript no es gratis; se mide antes de dejarlo siempre activo |
| Cadena de masterización | **Recurso + ajuste de proyecto**, no nodo | Master es global; la guarda comprueba el bus |
| Observación 43 | Se elimina la causa raíz; **el test no se relaja** | Un test intermitente que se tolera deja de proteger |
| Archivos reescritos por el editor | Confirmados como «resave» | Volverían al abrir el proyecto |

---

## 2. Entrega 8.1 — Observación 43

**Hecho descartado.** La hipótesis de un empate de coste en el BFS no se sostiene: desde el
emisor de música en (−6, 1.4, −8.5), la puerta cerrada en (−8, 1.05, −5.15) cuesta 3.917 × 16 =
62.7 y la ventana al 15 % en (−4, 1.8, −5.15) cuesta 3.922 × 13.75 = 53.9. La ventana gana
por un 14 % de forma determinista.

**Hipótesis viva.** Una carrera de registro al arrancar la escena: los portales se registran en
sus `_ready`, y el despachador puede calcular el camino en un frame en que la ventana aún no
está registrada (elige la puerta) y cachearlo; el resumen de `open_factor` que invalida la
caché es `número_de_portales + Σ open_factor_i × i` y depende del orden de un diccionario, así
que el registro tardío podría no cambiarlo lo bastante, o el frame de evaluación del test
podría caer antes de la invalidación.

**Método.** Se reproduce con instrumentación, no se arregla a ciegas:
1. Un script en `tools/` corre el test de la calle diez veces seguidas e imprime, en el frame de
   la aserción: salas registradas, portales registrados con su `open_factor`, resumen, camino
   elegido y coste de cada portal candidato.
2. Con la causa a la vista, se elimina. Si es el registro tardío, el despachador invalida la
   caché cuando el conjunto de portales o salas cambia (contador de generación en
   `SpatialAcousticsManager`, no un resumen numérico). Si es otra cosa, se documenta y se
   arregla esa.
3. El test de la calle no cambia sus expectativas.

**Se afirma.** Diez corridas seguidas verdes con la herramienta de 1, que queda en `tools/`
para repetirlo cuando haga falta.

**Hallazgo (2026-09-02, al ejecutar).** Con el código actual la observación **no se
reproduce**: diez corridas aisladas con la herramienta y cinco corridas de la suite completa
con la traza activa, quince trazas idénticas (seis portales registrados, resumen 6.3, la
ventana elegida). Las dos apariciones fueron durante la ejecución de la Fase 7B; desde
entonces los emisores de nodo publican su posición cada frame desde `_apply_voices`, lo que
pudo cerrar la ventana de la carrera sin que nadie la viera. Se deja la herramienta y la traza
bajo `OPENDOU_TRACE_OBS43`, y se aplica el endurecimiento de todos modos porque el defecto
estructural es real: el retorno temprano con el grafo vacío conservaba la caché y el resumen,
y el registro de una sala no invalidaba nada. La observación pasa a «no reproducida,
endurecida». En las mismas cinco corridas apareció otra intermitencia: la paridad entre
backends dio 1.10 dB de diferencia frente a un techo de 1.0 (dispersión medida 0.94–1.10);
el techo pasa a 1.5 con la medida escrita.

---

## 3. Entrega 8.2 — Límites de instancias con alcance

### Datos en `AudioEventDef`

| Export | Defecto | Significado |
|---|---|---|
| `max_instances` | **0** (sin límite) | Instancias simultáneas del evento en todo el juego |
| `max_instances_per_emitter` | 0 | Por nodo emisor (`caller_id`) |
| `max_instances_in_radius` | 0 | Dentro de `instance_radius_m` alrededor de la instancia nueva |
| `instance_radius_m` | 5.0 | Radio del alcance anterior |
| `limit_policy` | `STEAL_OLDEST` | `REJECT_NEW`, `STEAL_OLDEST`, `STEAL_QUIETEST`, `STEAL_FARTHEST` |
| `limit_fade_out_sec` | 0.05 | Fundido de la instancia robada |

### `OpenDouInstanceLimiter` (`runtime/instance_limiter.gd`, `RefCounted`)

`func check(def: AudioEventDef, caller: Node, position: Vector3, active: Array[EventInstance], listener_pos: Vector3) -> Dictionary` devuelve `{"allow": bool, "steal": EventInstance o null}`.

- Recorre `active` una vez y cuenta las instancias del mismo `definition` que estén sonando
  (`is_playing()`), por los tres alcances a la vez. Es O(n) por `post_event`; con la cuenta de
  instancias activas de las demos es despreciable y el banco del bucle lo mide.
- Si algún alcance está lleno: con `REJECT_NEW`, `allow = false`. Con las políticas de robo,
  `steal` es la instancia elegida **dentro del alcance que se llenó**: la más antigua
  (`elapsed_time` mayor), la más silenciosa (`calculated_volume_db` menor) o la más lejana
  del oyente.
- `post_event` llama al limitador **antes** de crear la instancia. Si `allow` es falso devuelve
  `null` (los emisores de nodo ya tratan `null`; se documenta). Si hay `steal`, llama
  `steal.stop(def.limit_fade_out_sec)` y crea la nueva.

### Por qué aquí y no en el robo de voces

El `VoicePoolManager` decide qué voces **suenan** con el presupuesto de canales; el limitador
decide qué instancias **existen**. Una instancia rechazada no gasta canal, ni oclusión, ni
camino por salas, ni tiempo lógico. Son dos preguntas distintas y se quedan en dos sitios.

### Se afirma

- Con `max_instances = 3` y `STEAL_OLDEST`, el cuarto `post_event` detiene la primera
  instancia con fundido y nunca suenan cuatro voces del evento en el bus (pico del bus
  acotado frente al control sin límite).
- Con `REJECT_NEW`, el cuarto `post_event` devuelve `null` y el bus no cambia.
- Con `max_instances_in_radius = 2` y radio 5 m, dos emisores a 1 m del nuevo no suman una
  tercera voz mientras un tercero a 50 m sí suena.
- Con `max_instances_per_emitter = 1`, un emisor que postea dos veces roba su propia voz y
  otro emisor no se ve afectado.
- «El monzón» sigue posteando sus 200 voces (defecto 0).

---

## 4. Entrega 8.3 — Cadena de masterización

### Recurso `MixChain` (`resources/mix_chain.gd`)

| Export | Defecto | Notas |
|---|---|---|
| `preset` | `GAME` | `GAME`, `CINEMATIC`, `MOBILE`, `CUSTOM` |
| `compressor_threshold_db`, `compressor_ratio`, `compressor_attack_us`, `compressor_release_ms`, `compressor_gain_db` | según preset | Mapean a `AudioEffectCompressor` |
| `limiter_ceiling_db`, `limiter_threshold_db`, `limiter_soft_clip_db` | −0.3, 0.0, 2.0 | Mapean a `AudioEffectLimiter` |

Presets: `GAME` (umbral −12 dB, 3:1, ataque 20 µs, release 250 ms, techo −0.3), `CINEMATIC`
(umbral −18 dB, 2:1, release 400 ms, techo −1.0: más rango), `MOBILE` (umbral −16 dB, 4:1,
release 150 ms, techo −0.5: altavoces pequeños). `CUSTOM` respeta los valores escritos.

### Ajuste e instalación

- Ajuste de proyecto `opendou/mix/master_chain`: ruta a un `MixChain.tres` o vacío.
  Vacío = **no se instala nada** (el proyecto decide; un juego con su propia cadena no la
  quiere duplicada).
- El manager, en `_ready`, llama `OpenDouMixChainInstaller.install(chain, "Master")`: añade un
  `AudioEffectCompressor` y un `AudioEffectLimiter` **con `resource_name` marcado**
  (`OpenDou_MixChain_Compressor` / `_Limiter`) al final de la cadena del bus, o actualiza los
  que ya llevan esa marca. Idempotente: abrir dos veces la escena no duplica efectos.
- Las demos declaran la cadena `GAME` en el ajuste del proyecto.

### Se afirma

- Dos voces a +6 dB sumadas sobre Master con la cadena `GAME`: el pico capturado no supera
  0 dBFS. Con el ajuste vacío, lo supera (control).
- Instalar dos veces deja exactamente dos efectos marcados.
- El cajón de mezcla del editor muestra la cadena instalada (lectura de los efectos del bus).

---

## 5. Entrega 8.4 — Medidor LUFS (EBU R128 / ITU-R BS.1770-4)

### `OpenDouLoudnessMeter` (`runtime/loudness_meter.gd`, `RefCounted`)

- `attach(bus: StringName)` añade un `AudioEffectCapture` al bus (marcado, idempotente);
  `detach()` lo quita. `process()` se llama por frame desde el manager si el medidor está
  activo: drena la captura y actualiza las medidas.
- Filtro K por canal: high-shelf +4 dB a 1681 Hz y paso-alto a 38 Hz (coeficientes de la
  norma para 48 kHz, recalculados para la `mix_rate` real con las mismas fórmulas biquad).
- Potencia media por bloques de 100 ms; **momentánea** = ventana de 400 ms; **corto plazo**
  = 3 s; **integrada** = media de los bloques que pasan la compuerta absoluta (−70 LUFS) y la
  relativa (−10 LU bajo la media provisional). `LUFS = −0.691 + 10·log10(Σ canales)`.
- **Pico**: pico muestral en dBFS. Un pico *verdadero* exige sobremuestreo ×4; se anota como
  no hecho y el medidor lo llama `sample_peak_db`, no `true_peak_db`, para no prometer.
- `reset()` reinicia la integración.
- **Coste.** Se mide con el banco. Si en GDScript supera 2 ms por segundo de audio (≈0.2 % de
  un núcleo) se acepta; si lo supera con holgura, la aceleración nativa entra como tarea
  posterior y el spec lo dice.

### Dónde se ve

- Cajón de mezcla del editor: momentánea, corto plazo, integrada y pico del bus Master, con
  botón de reiniciar. Se enciende al abrir el cajón, se apaga al cerrarlo.
- Manager: `loudness_meter` accesible; `AudibleMonitor` (el HUD de depuración) muestra la
  integrada cuando el medidor está activo.

### Se afirma

- Tono de calibración: seno de 1 kHz a −23 dBFS de pico **en ambos canales**, 3 s. La norma
  BS.1770-4 fija que un seno de 1 kHz a 0 dBFS en un solo canal mide −3.01 LKFS, así que en
  los dos canales a −23 dBFS mide **−23.0 LUFS**; el medidor tiene que dar −23.0 ±0.5 en las
  tres ventanas.
- Silencio: la compuerta absoluta deja la integrada sin valor (`-INF`/«—»), no −70.
- Un ruido a −20 dBFS con 2 s de silencio en medio: la integrada ignora el silencio (queda
  igual que sin él, ±0.3).
- Guarda por demo: la suite mide 5 s de cada demo y afirma un rango escrito por escena en
  `tests/loudness_budget.txt`, que se fija con la primera medida (como el techo de fugas).

---

## 6. Entrega 8.5 — La mezcla llega al servidor

### Modelo: base + delta + ducking

Para cada bus con nombre `b`:

```
volumen_aplicado(b) = base(b) + delta_instantánea(b) + atenuación_ducking(b)
```

- `base(b)` es el volumen del bus tal como lo dejó el proyecto o el jugador. El manager lo
  captura al arrancar y **el deslizador del menú de pausa (`BusRow`) edita la base**, no el
  volumen del servidor directamente. Así una instantánea no pelea con el jugador ni el jugador
  con la instantánea.
- `delta_instantánea(b)` viene del estado interpolado del `AudioMixSnapshotManager`, que pasa
  a vivir en el manager (`mix_snapshots`). Las instantáneas por defecto (`Default`,
  `Tinnitus_Explosion`, `Pause_Menu`, `Underwater`) se conservan.
- `atenuación_ducking(b)` viene de `AudioDuckingMatrix.get_ducking_attenuation_db(b)`, que
  pasa a vivir en el manager (`ducking`). `AudioDialogueManager` y `OpenDouMusicPlayer` ya
  saben hablar con una matriz: se les da la del manager.
- Paso-bajo y paso-alto: cuando la instantánea pide un corte distinto del neutro (20 000 y 20
  Hz), el manager añade bajo demanda al bus un `AudioEffectLowPassFilter` /
  `AudioEffectHighPassFilter` marcados (idempotentes, como la cadena) y ajusta su corte cada
  frame; con corte neutro los deshabilita (`set_bus_effect_enabled`), no los quita.
- `mute`: `AudioServer.set_bus_mute`, respetando el silencio del jugador (o lógico entre
  ambos).

Se aplica en `_process`, tras HDR y antes de `_apply_voices`, y **solo escribe si el valor
cambió** más de 0.01 dB o 1 Hz: sin transiciones activas cuesta cero escrituras.

### Pila de instantáneas: `push_snapshot` / `pop_snapshot`

- `push_snapshot(name: StringName, blend_sec: float = -1.0)` apila y hace `transition_to`
  al nuevo tope. `pop_snapshot(name)` quita esa entrada de la pila (esté o no en el tope) y
  transiciona al tope resultante, o a `Default` si la pila queda vacía.
- `OpenDouParameterArea3D` ya llama a ambos con `has_method`: empieza a funcionar sin tocarlo,
  y el `has_method` se quita para que un fallo futuro grite.
- `transition_to` sigue disponible para quien quiera saltar sin pila.

### `MixStateBinding` (`resources/mix_state_binding.gd`)

| Export | Significado |
|---|---|
| `state_group`, `state_name` | El estado de `GameSyncManager` que dispara |
| `snapshot_name` | La instantánea que se apila mientras el estado esté activo |
| `blend_sec` | Fundido (−1 = el de la instantánea) |
| `priority` | Orden dentro de la pila cuando hay varias activas: mayor gana el tope |

El manager conecta `GameSyncManager.state_changed`: al entrar en `(group, state)` con
vinculación, `push_snapshot`; al salir, `pop_snapshot`. Las vinculaciones se registran con
`register_mix_state_binding(binding)` y se cargan de un `Array[MixStateBinding]` en un ajuste
de proyecto o desde el panel de Game Syncs (persistencia JSON existente).

### Se afirma

- Con `push_snapshot(&"Underwater")`, el volumen real de `Music` en el `AudioServer` baja al
  de la instantánea con el fundido, y el efecto de paso-bajo del bus queda a 350 Hz; `pop`
  devuelve la base y deshabilita el filtro.
- Mover el deslizador de `Music` en el menú con una instantánea activa cambia la base y el
  volumen aplicado se mueve lo mismo, sin saltos.
- `AudioDialogueManager.play_dialogue()` activa `Voice` y el volumen real de `Music` baja la
  atenuación de la regla mientras suena; al terminar, vuelve.
- Un `OpenDouParameterArea3D` con `target_snapshot = &"Pause_Menu"`: al entrar el oyente, el
  volumen real de `SFX` baja; al salir, vuelve. (Hoy, este test no puede pasar.)
- `set_state(&"Player", &"LowHealth")` con una vinculación a `Tinnitus_Explosion`: el paso-bajo
  de Master baja a 600 Hz con el fundido; volver a `Normal` lo quita.
- Guarda: sin transiciones ni ducking activos, cero llamadas a `set_bus_volume_db` por frame
  (contador expuesto para la suite).

---

## 7. Componentes

| Componente | Archivo | Nuevo / modificado |
|---|---|---|
| Herramienta de reproducción de la obs 43 | `tools/repeat_street_test.gd` | Nuevo |
| Invalidación por generación del grafo | `runtime/spatial/spatial_acoustics_manager.gd`, `room_path_dispatcher.gd` | Modificado (si la hipótesis se confirma) |
| `OpenDouInstanceLimiter` | `runtime/instance_limiter.gd` | Nuevo |
| Exports de límites | `resources/audio_event_def.gd` | Modificado |
| `post_event` con limitador | `runtime/audio_event_manager.gd` | Modificado |
| `MixChain` + `OpenDouMixChainInstaller` | `resources/mix_chain.gd`, `runtime/mix_chain_installer.gd` | Nuevos |
| `OpenDouLoudnessMeter` | `runtime/loudness_meter.gd` | Nuevo |
| Medidor en el cajón de mezcla | `editor/opendou_mixer_drawer.gd` | Modificado |
| `OpenDouMixBusApplier` (base + delta + ducking + filtros) | `runtime/mix_bus_applier.gd` | Nuevo |
| `mix_snapshots`, `ducking`, `push/pop_snapshot`, vinculaciones | `runtime/audio_event_manager.gd` | Modificado |
| `MixStateBinding` | `resources/mix_state_binding.gd` | Nuevo |
| `BusRow` edita la base | `scenes/shared/bus_row.gd` | Modificado |
| Presupuesto de sonoridad por demo | `tests/loudness_budget.txt` | Nuevo |
| Marcas corregidas | `docs/funcionalidades.md` | Modificado |

---

## 8. Casos límite

- Un bus nombrado en una instantánea que no existe en el `AudioServer`: se ignora con un
  aviso una sola vez, no cada frame.
- `push_snapshot` de un nombre no registrado: aviso y sin efecto.
- El limitador con `caller == null` (voz anónima): el alcance por emisor no aplica; el radio
  usa la posición inicial de la instancia (`emitter_position`) si la tiene.
- Robar la propia instancia que aún no existe: imposible por construcción (se decide antes de
  crearla).
- El medidor sobre un bus que se borra: `detach()` en la señal de cambio de layout; la
  observación 40 sigue vigente (borrar buses reenruta voces), y el medidor no crea buses.
- Cadena de masterización con Master ya ocupado por efectos ajenos: se añade al final, no se
  toca lo ajeno.

---

## 9. Verificación

Todo con `OpenDouAudioProbe` sobre el bus real o con lectura directa del `AudioServer`, y con
control que apaga el mecanismo. Suites nuevas: `test_instance_limiter.gd`,
`test_mix_chain.gd`, `test_loudness_meter.gd`, `test_mix_bus_applier.gd`; la de la calle no
cambia; `test_hdr_snapshots.gd` gana las aserciones de aplicación real. Guardas: fugas,
banco del bucle (el limitador y el aplicador no pueden subirlo más de un 5 % a 200 voces),
`tests/loudness_budget.txt`.

---

## 10. Criterios de aceptación

1. Diez corridas seguidas del test de la calle, verdes, con la herramienta.
2. `max_instances` hace algo, con los tres alcances y las cuatro políticas afirmados en el bus.
3. Master lleva la cadena `GAME` en las demos y ninguna suma de voces supera 0 dBFS.
4. El medidor da −23.0 ±0.5 LUFS para el tono de calibración y cada demo tiene su rango.
5. Instantáneas, ducking y el área de parámetros mueven volúmenes reales del `AudioServer`;
   el menú de pausa convive con ellos; una vinculación por estado funciona de punta a punta.
6. `docs/funcionalidades.md` con las marcas verdaderas; `AGENTS.md` con la observación 45
   (mezcla nunca aplicada) y lo que la 43 resulte ser.

---

## 11. Fuera de alcance

Pico verdadero con sobremuestreo, medidor en nativo (solo si el coste lo exige), doppler y
todo lo de la Fase 9, cualquier nodo nuevo, CI.

---

## 12. Riesgos

| Riesgo | Mitigación |
|---|---|
| La causa de la obs 43 no es la hipótesis | El método es reproducir primero; el spec no se casa con la hipótesis |
| Aplicar la mezcla cada frame pisa a quien ya escribía en el `AudioServer` | Solo `BusRow` lo hacía en el proyecto; pasa a editar la base. Se documenta para juegos ajenos: quien toque volúmenes de bus por su cuenta debe hacerlo por `set_bus_base_volume_db()` |
| El medidor en GDScript cuesta demasiado | Apagado por defecto; medido; aceleración nativa como tarea si hace falta |
| Cambiar el defecto de `max_instances` sorprende a quien contaba con 5 | Nadie podía contar con él: no hacía nada. Anotado en el cambio de semántica |
