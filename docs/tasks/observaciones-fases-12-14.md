# Observaciones abiertas — Fases 12, 13 y 14

**Fecha:** 2026-09-02. Specs y planes escritos sin intervención del usuario para ahorrar tiempo y
tokens. **Antes de ejecutar cada fase hay que resolver sus puntos aquí** y anotar la decisión
en el spec correspondiente (§1 «Hechos» o la sección afectada). Cada punto dice qué se
decidió provisionalmente y qué pasa si la decisión es otra.

Specs: [12](../superpowers/specs/2026-09-02-fase12-efecto-directo-design.md) ·
[13](../superpowers/specs/2026-09-02-fase13-reflexiones-y-ambisonics-design.md) ·
[14](../superpowers/specs/2026-09-02-fase14-propagacion-y-geometria-dinamica-design.md).
Planes: [12](../superpowers/plans/2026-09-02-fase12-efecto-directo.md) ·
[13](../superpowers/plans/2026-09-02-fase13-reflexiones-y-ambisonics.md) ·
[14](../superpowers/plans/2026-09-02-fase14-propagacion-y-geometria-dinamica.md).

---

## A. Decisiones que necesitan el visto bueno del usuario

| # | Fase | Decisión provisional | Alternativa | Qué cambia si se elige la alternativa |
|---|---|---|---|---|
| A1 | 12 | La **atenuación por distancia sigue siendo la nuestra** (paridad exacta con Godot); el efecto directo solo aplica oclusión, transmisión, aire y directividad | Dejar que Steam Audio atenúe (`APPLYDISTANCEATTENUATION`) | Se pierde la paridad medida entre backends (Fase 7B/9); habría que rehacer `test_backend_parity` |
| A2 | 12 | `run_direct` corre en el **hilo principal** una vez por cuadro con presupuesto por LOD | Hilo propio desde la 12 | Más complejidad (mutex, commit); solo si con 64 fuentes supera 1 ms |
| A3 | 12 | Materiales: **ocho presets** con los números de la tabla del spec (§3); `Foliage` y `Water` son propios | Empezar de la tabla de Steam Audio tal cual (11 nombres) | Cambia el vocabulario `surface_type` que leen pisadas, impactos y el bake |
| A4 | 13 | Reverb **centrado en el oyente** (una IR por sala con el oyente dentro), tipo `HYBRID` | Reflexiones por fuente (una IR por voz bajo LOD) | Coste ×N voces; más fiel para fuentes lejanas de la sala del oyente |
| A5 | 13 | El reverb por convolución es un **`AudioEffect` nativo en el bus de la sala** que devuelve seco + húmedo (compatible con la observación 49) | Resolver primero la observación 49 (envío propio) y poner la convolución como envío real | Es una fase aparte; sin ella, `target_bus` de las voces 3D en salas sigue sin gobernar |
| A6 | 13 | **Modo altavoces surround** = Godot panea la señal ya procesada (anfitrión sin neutralizar + stream en `MONO_PASS`); no hay ambisonic panning en el stream | Renunciar al surround nativo hasta que Godot permita streams multicanal | La suite no puede probar 5.1 en ninguno de los dos casos |
| A7 | 13 | Camas ambisónicas desde **WAV multicanal leído por nosotros** (`read_multichannel`) o codificadas desde estéreo | Solo estéreo codificado (sin lector multicanal) | Menos código nativo; sin soporte a archivos ambisónicos reales |
| A8 | 13 | `ReflectionDispatcher` **apagado** en salas con convolución, reflectores como ajuste artístico | Retirarlo del todo | Sus tests se convierten o se borran; Sabine pierde las reflexiones tempranas |
| A9 | 14 | Los caminos aportan **dirección aparente y banda** al panner propio (no `iplPathEffectApply`) | Render ambisónico del camino por voz | Mucho más caro por voz; más realista con varios caminos simultáneos |
| A10 | 14 | El **grafo autorado manda** sobre las sondas cuando una voz está gobernada por un portal | Mezclar ambos (portal + camino) | Doble atenuación; hay que definir la regla de combinación |
| A11 | 14 | `.probes` se guarda **junto a la escena** y se versiona en git | Carpeta `res://acoustics/` centralizada | Rutas en el bake y en la guarda de assets |
| A12 | 14 | `EdgeDiffractionEngine` y `RoomCouplingEngine` **se borran** (inertes) | Conservarlos como referencia | El documento de funcionalidades los mantiene ⚪ |
| A13 | 12–14 | Sin extensión, todo lo nuevo se **omite con aviso** y el plugin sigue con el fallback (pool de Sabine, `OcclusionManager`, canal W en mono) | Emular algo en GDScript | Mucho trabajo por poco valor; el doble backend ya está decidido |

## B. Dudas técnicas que hay que comprobar al empezar (no bloquean el diseño)

| # | Fase | Duda | Cómo se resuelve |
|---|---|---|---|
| B1 | 12 | El binario de Steam Audio 4.8.1 para macOS incluye el trazador `DEFAULT` (sí, siempre); **Embree no**. El spec usa `DEFAULT` | Ninguna acción; si el coste de `run_direct` es alto, es el trazador |
| B2 | 12 | Convención de ejes y **winding** de los triángulos del bake frente a `IPLStaticMesh` | El primer test de oclusión (muro entre fuente y oyente) lo dice; si «no hay muro», invertir el orden de índices |
| B3 | 12 | ¿`iplDirectEffectApply` acepta in-place sobre `in_buffer_` (mono)? La doc dice que los efectos que no generan cola sí | Probar; si no, un búfer mono auxiliar |
| B4 | 12 | Coste real de `run_direct` con 64 fuentes × 16 muestras en el bake de la quilla | Medirlo en la primera corrida y fijar `tests/sim_budget.txt` |
| B5 | 13 | **`AudioEffect` por GDExtension**: hay que confirmar que `AudioEffectInstance::_process(const void *src, AudioFrame *dst, int frame_count)` está expuesto en godot-cpp 4.7 con esa firma | Un spike de una hora: un efecto de ganancia nativo en un bus y un test que lo mide |
| B6 | 13 | `IPLReflectionEffectIR` es opaca: la IR **no** se puede exportar a GDScript; el RT60 sale de `reverbTimes` (HYBRID) | Ninguna acción; `OpenDouIRRT60Analyzer` se queda para IRs de usuario |
| B7 | 13 | `iplSimulatorCommit` **no** puede llamarse mientras corre `RunReflections`/`RunPathing` en otro hilo | Bandera `running_` + cola de altas/bajas aplicada en el hilo principal entre corridas |
| B8 | 13 | La decodificación binaural ambisónica dentro del efecto de bus usa el HRTF activo: cambiar de HRTF en vivo tiene que respetar el contador de referencias de `SteamAudioContext` | Reusar `acquire_hrtf/release_hrtf` por bloque, como el binaural |
| B9 | 13 | En headless, `AudioServer.get_speaker_mode()` es estéreo: la decisión surround se afirma por estado, no por audio | Ninguna acción; queda escrito en el spec §6 |
| B10 | 14 | Convención de los coeficientes SH de orden 1 en `IPLPathEffectParams.shCoeffs` (ACN/SN3D: W, Y, Z, X) para derivar la dirección | El test «fuente a la vista» compara con la dirección real; se permuta si sale espejada |
| B11 | 14 | Tiempo del bake de caminos en la suite (`iplPathBakerBake`) | La escena de test es pequeña (≈20 sondas); si pasa de 5 s, bajar `numSamples` |
| B12 | 14 | El botón «Bake probes» en el inspector reutiliza `OpenDouAcousticGeometryBakeInspectorPlugin` (existe) | Añadir el segundo botón y una barra de progreso por señal |
| B13 | 12–14 | El techo de fugas de la suite está a 13 objetos (527 de 540): las fases nativas crean recursos (streams, efectos) que hay que liberar | Revisar el contador tras cada tarea; subir el techo solo con justificación |

## C. Deudas heredadas que estas fases tocan

| # | Deuda | Origen | Propuesta |
|---|---|---|---|
| C1 | **Observación 49**: dentro de una sala con reverb, Godot manda la voz 3D solo al bus de reverb; `target_bus` y la mezcla por buses no la gobiernan | Fase 11 | Fase propia tras la 13: envío de reverb sin el `Area3D` (segundo reproductor por voz o captura del bus de la voz hacia el efecto de convolución). Hasta entonces, el efecto de convolución devuelve seco + húmedo |
| C2 | Los cuatro nodos de la Fase 10 no tienen demo (guarda de cobertura con `EXPECTED_UNCOVERED`) | Fase 11 | Una demo «El estanque» (oyente bajo el agua, volumen de entorno, indicador, guardia que oye) en la Fase 15 o antes |
| C3 | `OpenDouSplineEmitter3D` y `OpenDouMultiPositionEmitter3D` fuera del sistema de voces (obs 47) | Fases 9 y 11 | Integrarlos como fuentes de posición del pool (como los emisores de nodo en steam_audio) en una tarea aparte |
| C4 | Aceleración nativa del medidor LUFS (91 ms por segundo de audio en GDScript) | Fase 8 | Un `AudioEffect` nativo cuando B5 esté confirmado: mismo mecanismo que la convolución |
| C5 | Latencia del altavoz de mundo (`BUS_CAPTURE`) no medida | Fase 11 | Medirla con un impulso en el bus origen y el bus del emisor |

## D. Cómo retomar

1. Leer este documento y decidir A1–A13 (basta una línea por punto).
2. Anotar cada decisión en el spec de su fase (y ajustar el plan si cambia una tarea).
3. Resolver B5 con el spike de una hora **antes** de la Fase 13 (condiciona la convolución, la
   cama ambisónica y C4).
4. Ejecutar la Fase 12 con `superpowers:executing-plans` (inline, como siempre); luego 13 y 14.
