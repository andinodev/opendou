# Fase 10 — El oyente y el entorno

**Fecha:** 2026-09-02
**Estado:** Aprobado en diseño (ciclo spec → plan → ejecución aprobado por adelantado), pendiente de plan.
**Rama:** `main`
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Hoja de ruta:** [`docs/roadmap/2026-09-02-sprint-aaa.md`](../../roadmap/2026-09-02-sprint-aaa.md), Fase 10
**Fase anterior:** [9](2026-09-02-fase9-emisor-completo-design.md)

---

## 1. Contexto

La Fase 9 completó el emisor. Esta fase completa el otro extremo y lo que hay en medio: el
**oyente** como nodo propio con su cabeza y su HRTF, el **entorno** como un volumen con un
recurso de secciones (medio, viento, oclusión parcial, descarte, superficie), la
**accesibilidad** del jugador (mono, modo noche, indicador de sonidos) y la **percepción de la
IA** (cuánto de un sonido llega a un punto cualquiera). Son dos nodos y dos recursos nuevos
más un nodo de HUD y un nodo de IA, según la clasificación de `docs/ideas/nodos-de-escena.md`
§H3: se quedan como nodos los que tienen ciclo de vida propio; lo que es comportamiento va a
un recurso.

Hechos comprobados al preparar el spec:

- **El oyente es hoy un `OpenDouListenerResolver`** que replica la regla de Godot
  (`AudioListener3D` activo, si no la `Camera3D`), con dos overrides (nodo y posición). No hay
  dónde poner el radio de cabeza ni un HRTF por jugador.
- **El radio de cabeza (8.75 cm) y la velocidad del sonido (343 m/s) son constantes en C++**
  (`dsp::woodworth_itd_seconds`), y **343 aparece cinco veces en GDScript** (retardo por
  distancia en el canal y en el pool, doppler en `SpatialAcousticsManager`, reflectores).
  Un medio con otra velocidad tiene que cambiar todos a la vez.
- **Los ajustes del jugador (`OpenDouSpatialSettings`) persisten HRTF, mezcla y salida** en
  `user://opendou_audio.cfg` y el manager los aplica al recibir `changed`. La accesibilidad
  va al mismo almacén.
- **La oclusión es un rayo todo o nada** (`OcclusionScheduler` → `OcclusionManager.
  evaluate_occlusion(ray_hits)`), con presupuesto por cuadro y reparto round-robin. La
  oclusión parcial por volumen se suma a ese mismo resultado sin más rayos.
- **La superficie se detecta en `SpatialAcousticsManager.detect_surface_at`** con tres
  prioridades (rayo hacia abajo → `floor_surface` de la sala → `Concrete`). La superficie
  pintada entra como prioridad cero.
- **El robo de voces ordena por peso** (`calculate_dynamic_weight`) y virtualiza el resto; el
  descarte por categoría es un peso cero para las categorías excluidas mientras el oyente
  esté dentro del volumen.
- **El grafo de salas ya calcula caminos entre dos salas** (`RoomPathDispatcher.chain_for`
  + `attenuation_db_for`) y la atenuación depende del `open_factor` de los portales. La IA
  reutiliza exactamente eso con otro destino.
- **La cadena de masterización `GAME` vive en Master** (`OpenDouMixChainInstaller`); el modo
  noche es otro preset de la misma cadena, no otro efecto.
- **No hay archivos `.sofa` en el repo.** El `hrtf_override` del oyente se afirma con lo que
  se puede afirmar: un SOFA inexistente se rechaza y la generación del HRTF no cambia; con
  `hrtf_override` vacío manda el ajuste del jugador.
- **La afirmación del roadmap «el ITD cae a menos de un quinto» bajo el agua no es exacta:**
  343 / 1480 = 0.232. Se afirma **menos de un cuarto** y se anota la corrección.
- **Área y punto.** Un `Area3D` detecta cuerpos, no posiciones. El oyente no es un cuerpo, así
  que la pertenencia del oyente a un volumen se decide **geométricamente** con las formas
  hijas (`BoxShape3D`, `SphereShape3D`, `CylinderShape3D`; otras por su AABB), igual que ya
  aproxima `OpenDouParameterArea3D._get_approx_extents`. Es determinista y no depende de un
  paso de física.

---

## 2. Alcance

**Entra**

1. `OpenDouListener3D` (nodo): `head_radius_m`, `hrtf_override`, `output_mode`, orientación
   externa; el resolver lo prefiere; radio y velocidad del sonido pasan al C++ como parámetros.
2. `AcousticEnvironment` (recurso) con cinco secciones opcionales y `OpenDouAcousticVolume3D`
   (`Area3D`) que lo aplica según el oyente y los emisores.
3. Accesibilidad: `mono` y `night_mode` en `OpenDouSpatialSettings`, aplicados por
   `OpenDouAccessibilityApplier`; nodo HUD `OpenDouSoundIndicator`.
4. La IA oye: `AudioEventManager.get_loudness_at(position, world_3d)` y `OpenDouAIHearing3D`.
5. Documentación: `funcionalidades.md`, `AGENTS.md` (observación 48 y trampas), `current.md`.

**No entra**

- Reverb distinta por medio (llega con la convolución de la Fase 13).
- Medio para el emisor (una fuente bajo el agua oída desde fuera): solo cuenta el medio del
  **oyente**. Se documenta.
- Materiales por banda en la oclusión parcial: dB/m y Hz/m planos (la Fase 12 trae las bandas).
- Fonemas, visemas o cualquier cosa del diálogo (Fase 11).
- El coste por voz que la Fase 9 dejó por encima del techo (§17.10 de su spec): esta fase
  **no lo empeora** en el bucle de control por voz más de lo que mide (§12), y el salto
  «rasgo apagado = sin cálculo» se aplica a lo nuevo. Pagar la deuda es tarea aparte.

---

## 3. El oyente: `OpenDouListener3D`

`Node3D`, `class_name OpenDouListener3D`, en `addons/opendou/nodes/opendou_listener_3d.gd`.

**Exports**

| Export | Defecto | Efecto |
|---|---|---|
| `head_radius_m` | 0.0875 | Radio de la cabeza esférica de Woodworth. Va al C++. |
| `hrtf_override` | `""` | Ruta a un SOFA que manda sobre el ajuste del jugador. Vacío = el del jugador. |
| `output_mode` | `INHERIT` | `INHERIT`, `HEADPHONES`, `SPEAKERS`. `INHERIT` = el del jugador. |
| `use_external_orientation` | `false` | Si está activo, la orientación viene de `set_external_orientation()`. |

**API**

- `set_external_orientation(basis: Basis)`: la orientación que inyecta un giroscopio o un
  visor; la posición sigue siendo la del nodo. Con `use_external_orientation` apagado se
  guarda pero no se usa.
- `get_effective_basis() -> Basis`.
- Señal `listener_changed`: cualquiera de los cuatro exports cambió; el manager la escucha.

**Resolución.** El resolver gana una prioridad entre los overrides y la regla de Godot:
`override_position` > `override_node` > **`opendou_listener_3d`** > `audio_listener_3d` >
`camera_3d`. El nodo se registra en `_enter_tree` (`OpenDou.register_listener(self)`) y se
desregistra en `_exit_tree`. Si hay dos, manda el último registrado y se avisa una vez.

**Parámetros al C++.** `OpenDouSpatialStream.configure_listener(head_radius_m, speed_of_sound_mps)`
es **estático**: dos atómicos en el contexto que `woodworth_itd_seconds` lee en cada bloque.
El roadmap decía «parámetro del stream»; se elige estático porque hay **un** oyente y porque
escribir dos propiedades por voz y por cuadro es coste en el bucle que la Fase 9 ya dejó por
encima del techo. Sin extensión, el radio no cambia nada y se dice.

**HRTF y salida.** `_apply_spatial_settings` del manager consulta al oyente registrado: si
`hrtf_override` no está vacío intenta `set_hrtf_sofa(override)` y, si falla, cae al ajuste del
jugador con un aviso una vez; si `output_mode` no es `INHERIT`, manda sobre `settings.output`.

**Se afirma.** Con `head_radius_m` al doble, `get_last_applied_itd_ms()` a 90° se dobla (±5 %).
Un `hrtf_override` inexistente se rechaza y `get_hrtf_generation()` no cambia. Con el nodo en
el árbol, `listener_resolver.source == &"opendou_listener_3d"` y la posición es la del nodo,
aunque haya una cámara en otro sitio. Con orientación externa girada 90° a la izquierda, una
fuente que estaba delante mide como fuente a la derecha (ILD del signo esperado).

---

## 4. El entorno: `AcousticEnvironment` y `OpenDouAcousticVolume3D`

### 4.1 El recurso

`Resource`, `class_name AcousticEnvironment`, en `addons/opendou/resources/acoustic_environment.gd`.
Cinco secciones, cada una con su interruptor; todo apagado por defecto (un recurso vacío no
hace nada).

| Sección | Exports | Qué hace |
|---|---|---|
| **Medio** | `medium_enabled`, `speed_of_sound_mps` (343), `medium_lowpass_hz` (20000), `medium_pitch_scale` (1.0), `medium_snapshot` (`&""`) | Con el oyente dentro: la velocidad del sonido escala el ITD (C++), el retardo por distancia (canal y pool) y el doppler; un paso-bajo en Master (`OpenDou_Medium_LPF`, antes de la cadena); un factor de tono sobre todas las voces físicas; y una instantánea de mezcla que se empuja al entrar y se saca al salir. |
| **Viento** | `wind_enabled`, `wind_velocity` (m/s, mundo), `wind_gust_strength` (0..1), `wind_gust_rate_hz` (0.2), `wind_min_distance_m` (20) | Para cada voz física más lejana que `wind_min_distance_m`, con el oyente dentro: `headwind = max(0, −wind · dir_emisor→oyente)` (viento en contra). Ganancia `−0.3 dB × headwind`, tope −12 dB; corte `cutoff × (1 − 0.5 × clamp(headwind / 20))`. Las ráfagas multiplican el viento por `1 + gust_strength × sin(2π · rate · t)`. **Es una aproximación perceptual, no física**, y el documento lo dice. |
| **Oclusión parcial** | `occluder_enabled`, `occluder_db_per_m` (3.0), `occluder_cutoff_hz_per_m` (2000) | Para cada rayo del `OcclusionScheduler`: longitud del segmento emisor→oyente dentro del volumen (caja o esfera, analítico); se suman `−db_per_m × L` a la atenuación y `−hz_per_m × L` al corte (mínimo 500 Hz). No gasta rayos. |
| **Descarte** | `cull_enabled`, `cull_buses: Array[StringName]` | Con el oyente dentro: las instancias cuyo `definition.target_bus` esté en la lista pesan 0 en el robo de voces (se virtualizan y siguen contando su tiempo lógico) y el planificador de oclusión no les gasta rayos. |
| **Superficie** | `surface_enabled`, `surface_type` (`&""`), `surface_priority` (0) | `detect_surface_at(pos)` consulta primero los volúmenes con superficie que contienen `pos`; gana la prioridad mayor; después sigue la cadena de siempre. |

### 4.2 El nodo

`Area3D`, `class_name OpenDouAcousticVolume3D`, en `addons/opendou/nodes/opendou_acoustic_volume_3d.gd`.

- Exports: `environment: AcousticEnvironment`, `priority: int` (0). Sus formas son los
  `CollisionShape3D` hijos, como cualquier `Area3D`, y en el editor se ven igual.
- `contains_point(p: Vector3) -> bool` y `segment_length_inside(a: Vector3, b: Vector3) -> float`
  con caja, esfera y cilindro analíticos (el cilindro como caja de su AABB para el segmento)
  y AABB para cualquier otra forma. Sin formas, no contiene nada y avisa una vez.
- Se registra en el manager al entrar al árbol (`register_acoustic_volume`) y se va al salir.
  El manager mantiene la lista; **no hay `body_entered`**: la pertenencia del oyente se decide
  por geometría en `_update_environment()`, una vez por cuadro.

### 4.3 El estado del entorno en el manager

`OpenDouEnvironmentState` (`RefCounted`, `addons/opendou/runtime/spatial/environment_state.gd`)
resuelve **cada cuadro** qué volúmenes contienen al oyente y compone el estado efectivo:

- **Medio:** el del volumen de mayor prioridad que tenga medio; sin ninguno, aire (343, sin
  paso-bajo, tono 1, sin instantánea). Al cambiar: `configure_listener(head_radius, c)` al C++,
  `voice_pool.speed_of_sound` y `spatial_acoustics.speed_of_sound`, el paso-bajo de Master,
  y `push_snapshot` / `pop_snapshot` de la instantánea (con el fundido por defecto de la
  instantánea, trampa de la Fase 8).
- **Viento:** el del volumen de mayor prioridad con viento; sin ninguno, cero.
- **Descarte:** la unión de los `cull_buses` de los volúmenes que contienen al oyente.
- **Oclusión parcial y superficie** no son «estado del oyente»: se consultan por segmento y
  por punto en la lista completa de volúmenes.

Los cinco 343 de GDScript pasan a leer `speed_of_sound`: `PhysicalVoiceChannel` y
`VoicePoolManager` (retardo), `SpatialAcousticsManager.calculate_doppler_pitch` (parámetro con
defecto 343), `AcousticReflectorEngine` (ya es variable). La constante de
`core/spatial/acoustic_reflector.gd` no se toca (no está en el camino de las voces).

### 4.4 Dónde entra cada cosa en el bucle

- `_process` del manager: `_update_listener()` → **`_update_environment()`** (nuevo) → lo demás.
- `resolve_voice_stealing`: `calculate_dynamic_weight` devuelve 0 si `instance.culled` (marca
  que el manager pone según el estado del entorno antes del robo).
- `OcclusionScheduler.process(..., occluder_volumes)`: salta las instancias `culled`; tras el
  rayo, suma la oclusión parcial de los volúmenes que el segmento atraviesa.
- `_apply_voices`: viento (solo si el estado tiene viento y la voz está lejos) y
  `medium_pitch_scale` (solo si ≠ 1). Rasgo apagado = sin cálculo.

**Se afirma.** Oyente dentro de un volumen «agua» (1480 m/s, paso-bajo 800 Hz): el ITD medido a
90° cae a **menos de un cuarto** del de aire, y la banda alta medida en Master cae al menos
12 dB; al salir, vuelven los valores de aire. Emisor a 60 m con viento en contra de 15 m/s: la
banda alta medida es menor que con viento a favor; con viento 0, iguales (±0.5 dB). Emisor
tras 4 m de «follaje» a 3 dB/m: −12 dB (±1) respecto a sin volumen; tras 2 m, −6. Oyente en un
volumen que descarta `SFX`: los rayos de la categoría son 0 y una voz de `SFX` en bucle sigue
avanzando su tiempo lógico; al salir vuelve a sonar en la posición del bucle que le toca
(`logical_playback_position` continuo). Pisada dentro de un volumen «charco» (prioridad 1)
sobre un suelo «Asphalt» (sala): `detect_surface_at` da `Water`; fuera, `Asphalt`.

---

## 5. Accesibilidad

### 5.1 Ajustes

`OpenDouSpatialSettings` gana `mono: bool` y `night_mode: bool`, con `set_mono` y
`set_night_mode`, persistidos en la sección `accessibility` del mismo archivo. El manager los
aplica al recibir `changed`, como los demás.

### 5.2 Aplicador

`OpenDouAccessibilityApplier` (estático, `addons/opendou/runtime/accessibility_applier.gd`):

- **Mono:** un `AudioEffectStereoEnhance` en Master con `pan_pullout = 0` marcado
  `OpenDou_Access_Mono`, insertado **al final** de la cadena (después del limitador). Se quita
  al apagar. Es de Godot, así que vale para los dos backends y para lo que no pase por OpenDou.
- **Modo noche:** reinstala la cadena de masterización con el preset `MixChain.Preset.NIGHT`
  (umbral −24 dB, razón 6:1, ataque 20 µs, liberación 250 ms, ganancia +6 dB; limitador igual
  que `GAME`). Al apagar, vuelve el preset del ajuste de proyecto.

### 5.3 Indicador de sonidos

`OpenDouSoundIndicator` (`Control`, `addons/opendou/nodes/opendou_sound_indicator.gd`): dibuja,
en un anillo, la dirección de las voces más audibles respecto al frente del oyente. Reutiliza
`AudibleVoiceMonitor.collect_audible_voices` (lo mismo que el HUD y el radar). Exports:
`max_items` (6), `min_db_threshold` (−40), `ring_radius_px` (80), `poll_interval` (0.1).
Método `get_indicators() -> Array[Dictionary]` con `{event_name, angle_rad, level_db}` para
que la suite lo afirme sin píxeles; `_draw` pinta un punto por indicador con tamaño según nivel.

**Se afirma.** Con mono activo, una fuente a 90° mide ILD < 0.5 dB en Master; al apagarlo,
vuelve la ILD de siempre (> 6 dB). Modo noche sobre una señal de dos niveles (−6 y −30 dBFS):
la diferencia pico-valle medida en Master baja **al menos 6 dB** respecto a la cadena `GAME`.
El roadmap lo pedía «sobre una demo»; se afirma sobre una señal controlada porque la demo
tiene azar y ya cuesta 30 s. El indicador con una voz a la derecha del oyente devuelve un
indicador con `angle_rad ≈ +π/2` (±0.2) y su nombre.

---

## 6. La IA oye

### 6.1 Consulta

`AudioEventManager.get_loudness_at(position: Vector3, world_3d: World3D = null) -> Array[Dictionary]`,
una entrada por instancia activa con posición espacial:
`{instance, event_name, loudness_db, from_position}`.

`loudness_db` = `definition.hdr_loudness_db` (la sonoridad de diseño) + `calculated_volume_db`
(RTPC, moduladores, fundidos) + atenuación por distancia con el modelo de la instancia
(`OpenDouDistanceModel.attenuation_db`, incluida la curva) + **camino**:

- Si el emisor y el punto están en salas distintas del grafo: `chain_for` +
  `attenuation_db_for` del `RoomPathDispatcher` (el mismo cálculo que gobierna las voces). Con
  el portal cerrado la cadena atenúa más; al abrirlo, menos.
- Si están en la misma sala (o fuera del grafo) y hay `world_3d`: un rayo emisor→punto y
  `OcclusionManager.evaluate_occlusion` (−6 dB por defecto) más la oclusión parcial de los
  volúmenes atravesados.
- Sin `world_3d`: solo distancia y grafo.

No usa la oclusión ya calculada de la voz porque esa es **hacia el oyente**; es un cálculo con
otro destino y por eso cuesta rayos: uno por instancia y consulta.

### 6.2 El nodo

`OpenDouAIHearing3D` (`Node3D`, `addons/opendou/nodes/opendou_ai_hearing_3d.gd`):

- Exports: `threshold_db` (−30), `poll_interval_sec` (0.1), `max_rays_per_poll` (8).
- Señal `sound_heard(event_name: StringName, loudness_db: float, from_position: Vector3)`: se
  emite **una vez por instancia** cuando su sonoridad en el nodo cruza el umbral hacia arriba;
  si baja y vuelve a subir, se emite otra vez. Las instancias terminadas se olvidan.
- `get_last_heard() -> Array[Dictionary]` con la última consulta, para depurar y para la suite.

**Se afirma.** Emisor en la sala A, guardia en la sala B, portal con `open_factor` 0: la
sonoridad en el guardia es al menos 10 dB menor que sin grafo; al abrir el portal (1.0),
sube al menos 6 dB. Con `world_3d` y una pared física entre emisor y guardia en la misma
sala, baja (−6 dB de la oclusión). Un `OpenDouAIHearing3D` con umbral −30 dB emite
`sound_heard` una vez para un emisor cercano y ninguna para uno a 200 m con modelo inverso.

---

## 7. Cambios en lo que existe

| Archivo | Cambio |
|---|---|
| `runtime/listener_resolver.gd` | prioridad `opendou_listener_3d`; `set_opendou_listener(node)`. |
| `runtime/audio_event_manager.gd` | `register_listener/unregister_listener`, `register_acoustic_volume/unregister_acoustic_volume`, `environment: OpenDouEnvironmentState`, `_update_environment()`, `speed_of_sound` propagado, viento y tono del medio en `_apply_voices`, `get_loudness_at`, accesibilidad en `_apply_spatial_settings`. |
| `runtime/spatial/spatial_settings.gd` | `mono`, `night_mode`, sección `accessibility`. |
| `runtime/spatial/spatial_acoustics_manager.gd` | `speed_of_sound`, `calculate_doppler_pitch(..., speed_of_sound)`, `surface_volumes` y prioridad cero en `detect_surface_at`. |
| `runtime/spatial/occlusion_scheduler.gd` | salta `culled`; `occluder_volumes` sumados al resultado. |
| `runtime/voice_pool_manager.gd`, `runtime/physical_voice_channel.gd` | `speed_of_sound` en lugar de 343. |
| `runtime/event_instance.gd` | `culled: bool`; `calculate_dynamic_weight` devuelve 0 si `culled`. |
| `resources/mix_chain.gd` | preset `NIGHT`. |
| `native/src/dsp.h`, `spatial_stream.{h,cpp}`, `steam_audio_context.{h,cpp}` | `woodworth_itd_seconds(dx, dy, dz, r, c)`; atómicos `head_radius_`, `speed_of_sound_`; estático `configure_listener`. |

---

## 8. Tests

Cuatro archivos nuevos, en la suite asíncrona (todos añaden nodos):

- `tests/test_listener_3d.gd`: resolver, radio (ITD doble), SOFA inexistente, orientación externa.
- `tests/test_acoustic_volume.gd`: contención y longitud de segmento (síncrono dentro del mismo
  archivo), medio (ITD y banda alta), viento, oclusión parcial, descarte, superficie.
- `tests/test_accessibility.gd`: mono (ILD), modo noche (rango), indicador, persistencia de los
  dos ajustes.
- `tests/test_ai_hearing.gd`: sonoridad por grafo con portal cerrado y abierto, oclusión por
  pared, la señal del nodo.

Reglas de siempre: medir en Master o en el bus destino (el volumen del bus se aplica al
enviar), cámara o `OpenDouListener3D` para que suene un 3D, esperar por muestras y no por
cuadros, y los tests con nodos van a `run_async_suite(tree)`.

---

## 9. Riesgos

- **`AudioEffectStereoEnhance` con `pan_pullout = 0`** debería colapsar a mono; si la ILD
  medida no baja de 0.5 dB, el aplicador pasa a un `AudioEffectPanner`... que no hace mono.
  Alternativa segura: mono **en el stream nativo** (`output_mode = MONO`) más `StereoEnhance`
  para lo que no pase por OpenDou. Se decide con la medida.
- **El paso-bajo del medio en Master** afecta también a la música y a la interfaz. Es lo que
  hace el agua en los juegos que lo hacen bien (todo se apaga), y el diseñador puede optar por
  `medium_snapshot` si quiere salvar la música. Se documenta.
- **Coste:** `_update_environment` es O(volúmenes) por cuadro con contención analítica; la
  oclusión parcial es O(volúmenes) por rayo. Se mide en el banco con 8 volúmenes.

---

## 10. Correcciones que la ejecución obligue a hacer

Se anotan aquí, numeradas, como en las fases anteriores.
