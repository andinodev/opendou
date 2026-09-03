# ⚡ Tarea Activa: Fases 15 y 16 implementadas — siguiente, cierre del sprint

* **Regla que gobierna las escenas:** [`.agents/rules/04_scene_composition.md`](../../.agents/rules/04_scene_composition.md)
* **Última fase con spec y plan:** Fase 16 — [spec](../superpowers/specs/2026-09-03-fase16-la-presa-design.md) · [plan](../superpowers/plans/2026-09-03-fase16-la-presa.md); Fase 15 — [spec](../superpowers/specs/2026-09-03-fase15-deudas-design.md) · [plan](../superpowers/plans/2026-09-03-fase15-deudas.md)

## Cómo retomar (para cualquier modelo o persona)

**Dónde está cada cosa.** Catálogo por funcionalidad, con las clases que la implementan y el error
que costó cada una: `docs/catalogo-de-funcionalidades.md` (el mejor punto de entrada).
Qué hace el plugin y qué afirma cada pieza con números: `docs/funcionalidades.md`.
Por qué se hizo así y qué obligó a corregir la ejecución: cada spec (`docs/superpowers/specs/`, sección
«Correcciones que la ejecución obligó a hacer») y su plan. Trampas de Godot y Steam Audio descubiertas,
numeradas por fase (observaciones 1–55): `AGENTS.md`, bloques «Observaciones y trampas de la Fase N».
Decisiones tomadas sin el usuario y deudas: `docs/tasks/observaciones-fases-12-14.md`. Hoja de ruta:
`docs/roadmap/2026-09-02-sprint-aaa.md`.

**Cómo se trabaja.** Por fase: spec (brainstorming) → plan (writing-plans) → ejecución inline en `main`,
un commit por tarea, sin pedir permiso para continuar. El proyecto **solo afirma lo que hace**: cada
tesis se mide en audio capturado en el bus de sonda (`tests/support/audio_probe.gd`), con un control.
Documentos en español con acentos; comentarios de código en español sin acentos. Los nodos van en el
`.tscn` (regla 04); el código solo autora streams (se sintetizan) y lo dinámico.

**Cómo se comprueba.** `./run_tests.sh` (≈150 s; vigilante 240 s con `OPENDOU_TEST_TIMEOUT`); la
puerta de commit es su **código de salida**, no la línea `STATUS`: también fallan los `SCRIPT ERROR`,
los `Parse Error` y el trinquete de fugas (`tests/leak_budget.txt`, hoy 540; la suite deja 527–529). Un
test con nodos va en `run_async_suite`; el último test de la suite espera 300 ms tras parar voces o los
playbacks quedan vivos al salir. Godot: `/Users/Daniel/Downloads/Godot.app/Contents/MacOS/Godot`;
nativo: `/Applications/CMake.app/Contents/bin/cmake --build native/build/ext --parallel` (los `.cpp`
nuevos van en `native/CMakeLists.txt` y las clases en `native/src/register_types.cpp`). Banco:
`Godot --headless --path . -s tools/bench_control_loop.gd` (200 voces ≈ 3.4–3.7 µs; techo 4.3).

**Cómo se depura (lo que funcionó hoy).**
1. Un fallo que solo aparece en la suite completa se aísla con un **sondeo** (`tools/probe_*.gd`,
   `extends SceneTree`, se ejecuta con `Godot --headless --path . --script tools/probe_x.gd`): carga lo
   mínimo y mide en 10 s en vez de 150. Si en aislamiento funciona, la causa es estado que dejan tests
   previos (pool de voces, presupuesto, LOD, buses del pool que sobreviven al manager).
2. Trazas por variable de entorno: `OPENDOU_TRACE_SIM=1` (el planificador: pares, fuentes del
   simulador, altas y bajas) y `OPENDOU_TRACE_OBS43=1` (el grafo de salas al decidir portal). Se
   activan al lanzar el runner: `OPENDOU_TRACE_SIM=1 Godot --headless --path . --script tests/test_runner_cli.gd`.
3. Un crash nativo: `lldb` no puede adjuntarse a Godot en esta máquina; el informe `.ips` de
   `~/Library/Logs/DiagnosticReports/Godot-*.ips` trae la pila de todos los hilos con el desplazamiento en
   `libphonon`; `lipo -thin arm64` + `llvm-objdump --start-address` desensambla el punto exacto.
4. Un error de parse que la suite solo reporta como «Could not preload»: `Godot --headless --path .
   --check-only --script archivo.gd` da la línea exacta.
5. Fugas: `Godot --headless --path . --script tests/test_runner_cli.gd --verbose` lista las instancias
   vivas al salir; las nativas aparecen sin nombre de clase.
6. Medidas de audio: para el ruido periódico de los tests, `_band_energy_stereo` (rectangular, exacta);
   para señales arbitrarias (demos), `_band_energy_stereo_windowed` (Hann). El driver headless corre
   a ~0.84 s de audio por segundo de reloj bajo carga: esperar por muestras, no por milisegundos.

El hub tiene siete entradas: «Bajo la quilla», «El monzón», «La cabina», «Una casa canta»,
«El taller», «La presa» y el banco del rig (eran cinco cuando se escribió este párrafo). Todas se componen como árboles de nodos en su `.tscn`; los scripts solo
llevan lo dinámico, y una guarda lee cada escena sin instanciarla para hacerlo cumplir.

«Una casa canta» es un sector urbano cerrado con tres casas de verdad —suelo, paredes,
techo, puertas con hoja, ventanas con cristal— y la calle como sala `Outdoor`. Es la
primera escena que luce el grafo de salas de la Fase 6: la música sale por la ventana
entreabierta, y dentro de las casas dormidas la calle llega cortada a 300 Hz.

**Fase 7A, spike hecho (2026-09-02):** una voz de Godot 4.7 sale por Steam Audio 4.8.1 y el
HRTF se mide: ILD ±15 dB, delante/detrás 15.9 % frente a 2.5 % sin HRTF, 11.6 ms de latencia.
Hallazgo: la API C **no** renderiza el ITD (fase plana por defecto); lo reporta en `peakDelays`
y 7B tiene que aplicarlo. Resultados en §11 del
[análisis](../superpowers/specs/2026-09-01-fase7-steam-audio-analisis.md). El código nativo vive
en `native/` (fuentes en git; SDK, godot-cpp y binarios ignorados; se compila con
`native/CMakeLists.txt`). Si la extensión no está compilada, la suite omite el spike y lo dice.

**Fase 7B, spec aprobado en diseño (2026-09-02):**
[`2026-09-02-fase7b-binaural-todas-las-voces-design.md`](../superpowers/specs/2026-09-02-fase7b-binaural-todas-las-voces-design.md).
Todas las voces físicas 3D por un panner propio sobre Steam Audio: HRTF, ITD por cabeza
esférica (Woodworth a C++), LPF de oclusión y shelf por distancia con los números de Godot,
emisores de nodo como fuente de posición, ajustes del jugador y bloque de espacialización en
el menú. Corrige la observación 42 (OpenDou anulaba el oscurecimiento por distancia de Godot).
Doppler fuera por decisión. **Siguiente:** el plan de 7B. La Fase 4B (prefijado `OpenDou`)
queda pendiente detrás.

**Plan de 7B (2026-09-02):** [`2026-09-02-fase7b-binaural-todas-las-voces.md`](../superpowers/plans/2026-09-02-fase7b-binaural-todas-las-voces.md), quince tareas con su ciclo de test y commit. Las quince ejecutadas y confirmadas. Lo que toca es probarla con audífonos en las demos. Correcciones que la ejecución obligó a hacer: §15 del spec.

**Hoja de ruta del sprint (2026-09-02):** [`docs/roadmap/2026-09-02-sprint-aaa.md`](../roadmap/2026-09-02-sprint-aaa.md).
Ocho fases ordenadas por dependencias, de la 8 (higiene y deuda: obs 43, límites de instancias,
cadena de masterización, LUFS) a la 15 (cierre y prefijado). La siguiente es la **Fase 8**.

**Fase 8, spec y plan (2026-09-02):** [spec](../superpowers/specs/2026-09-02-fase8-higiene-y-deuda-design.md) ·
[plan](../superpowers/plans/2026-09-02-fase8-higiene-y-deuda.md), ocho tareas. Hallazgo del spec: instantáneas
de mezcla, ducking y el área de parámetros nunca escribían en el `AudioServer`; `max_instances` nunca se aplicó.

**Fase 8, implementada (2026-09-02):** ocho tareas, 1174 aserciones. Límites de instancias
(`max_instances` por fin se aplica; defecto 0), `stop(fade)` real, cadena de masterización
`GAME` en Master, medidor LUFS con presupuesto por demo, y la mezcla dinámica (instantáneas,
ducking, área de parámetros, vinculación por estado) escribiendo en el `AudioServer` por
primera vez. Observaciones 43 (no reproducida, endurecida), 45 y 46 en `AGENTS.md`;
correcciones del spec en su §13.

**Pendiente que sale de la Fase 8:** aceleración nativa del medidor LUFS (91 ms por segundo
de audio en GDScript) y llevar su lectura al cajón del editor por Live Update.

**Fase 9, spec y plan (2026-09-02):** [spec](../superpowers/specs/2026-09-02-fase9-emisor-completo-design.md) ·
[plan](../superpowers/plans/2026-09-02-fase9-emisor-completo.md), ocho tareas.

**Fase 9, implementada (2026-09-02):** ocho tareas, 1224 aserciones. El emisor completo, como
exports del nodo y de la definición: doppler con velocidad del oyente (apagado en steam_audio
cuando el retardo por distancia está activo, que ya lo produce), retardo por distancia (línea de
retardo nativa; arranque aplazado en `godot`), spread, campo cercano, directividad por dipolo,
curva de atenuación propia (`MODEL_CURVE`), marcadores (`marker_reached`, leídos del chunk `cue`
del WAV con `OpenDouWavMarkers`) y flujo del spline en su doppler. Observación 47 y trampas en
`AGENTS.md`; correcciones del spec en su §17.

**Pendiente que sale de la Fase 9:** integrar `OpenDouSplineEmitter3D` al sistema de voces
(obs 47); una corrida de la suite dio un pico muestral espurio de −4.6 dBFS en el test del
medidor LUFS (no reproducido en la siguiente): vigilarlo.
El coste del bucle de control por voz quedó **por encima del techo**: 4.31–4.45 µs (godot) y
4.74–4.83 µs (steam_audio) a 200 voces, frente a 4.09 / 4.25 al inicio de la fase; el camino es
saltar cada cálculo cuando su export está apagado (spec §17.10).

**Fase 10, spec y plan (2026-09-02):** [spec](../superpowers/specs/2026-09-02-fase10-oyente-y-entorno-design.md) ·
[plan](../superpowers/plans/2026-09-02-fase10-oyente-y-entorno.md), ocho tareas.

**Fase 10, implementada (2026-09-02):** ocho tareas, 1301 aserciones. `OpenDouListener3D`
(radio de cabeza y velocidad del sonido como parámetros estáticos del C++, HRTF por jugador,
orientación externa), `AcousticEnvironment` + `OpenDouAcousticVolume3D` (medio, viento, oclusión
parcial, descarte, superficie; pertenencia por geometría), accesibilidad (mono, modo noche
`NIGHT`, `OpenDouSoundIndicator`) y la IA que oye (`get_loudness_at`, `OpenDouAIHearing3D`).
Observación 48 y trampas en `AGENTS.md`; correcciones del spec en su §10.

**Deuda de coste pagada (2026-09-02):** `tools/profile_control_loop.gd` mide el bucle por etapas.
Tres recortes sin cambio de comportamiento (sin `sort_custom` en el robo de voces ni en la
oclusión, sin `Dictionary` de rasgos LOD por instancia, una llamada nativa por voz en lugar de
nueve escrituras): a 200 voces, de 4.5 / 4.9 µs por voz a **3.20–3.44 (godot) / 3.39–3.52
(steam_audio)**, por debajo del techo histórico de 4.29. Lo que más pesa ahora es el robo de
voces (1.2 µs por voz) y los parámetros por instancia (0.7).

**Pendiente que sale de la Fase 10:** el techo de fugas queda a siete objetos (533 de 540); el
pico espurio del medidor LUFS ya apareció cinco veces y sigue sin causa.

**Fase 11, spec y plan (2026-09-02):** [spec](../superpowers/specs/2026-09-02-fase11-emisores-nuevos-y-modos-design.md) ·
[plan](../superpowers/plans/2026-09-02-fase11-emisores-nuevos-y-modos.md), siete tareas.

**Fase 11, implementada (2026-09-02):** 1394 aserciones. `OpenDouPhysicsImpact3D`,
`OpenDouDialogueEmitter3D`, modo `MESH` (BVH) en el multiposición, `BUS_CAPTURE` en el emisor 3D,
disparadores en el área de parámetros y la demo «El taller» con la plantilla de motor. Dos
promesas sin cumplir arregladas por el camino: el árbol de contenedores solo reproducía la
primera voz (observación 50; ahora capas reales con cruce en vivo) y los RTPC locales asentaban
a 10 unidades por segundo. Un hallazgo del motor con deuda: dentro de una sala con reverb,
Godot manda las voces 3D solo al bus de reverb (observación 49).

**Pendiente que sale de la Fase 11:** envío de reverb propio para que `target_bus` y la mezcla
gobiernen las voces 3D dentro de salas (obs 49; encaja con la fase de reverb); una demo que
luzca los nodos de la Fase 10 (hoy no cubiertos por la guarda); el techo de fugas queda a
trece objetos (527 de 540).

**Fases 12, 13 y 14, diseñadas y planificadas sin intervención (2026-09-02):** specs
[12](../superpowers/specs/2026-09-02-fase12-efecto-directo-design.md) ·
[13](../superpowers/specs/2026-09-02-fase13-reflexiones-y-ambisonics-design.md) ·
[14](../superpowers/specs/2026-09-02-fase14-propagacion-y-geometria-dinamica-design.md) y planes
[12](../superpowers/plans/2026-09-02-fase12-efecto-directo.md) ·
[13](../superpowers/plans/2026-09-02-fase13-reflexiones-y-ambisonics.md) ·
[14](../superpowers/plans/2026-09-02-fase14-propagacion-y-geometria-dinamica.md).
**Las dudas están en [`observaciones-fases-12-14.md`](observaciones-fases-12-14.md)** (13 decisiones
A1–A13, 13 comprobaciones B1–B13, 5 deudas C1–C5) y hay que resolverlas antes de ejecutar.

**Fase 12, implementada (2026-09-03):** 1457 aserciones. `AcousticMaterial` por banda,
`OpenDouAcousticScene` desde el bake, `OpenDouSimulator` (`DIRECT`) con fuentes por LOD, el
`IPLDirectEffect` en el stream y el presupuesto de simulación. Observación 51 y trampas en
`AGENTS.md`; correcciones en el §11 del spec; B1–B5 resueltas en las observaciones (el spike B5
confirmó el `AudioEffect` nativo).

**Fase 13, implementada (2026-09-03):** 1487 aserciones. Reflexiones `HYBRID` en hilo propio con
fuente de oyente por sala, `OpenDouConvolutionReverb` en el bus de la sala (`reverb_mode =
CONVOLUTION`, RT60 real para el fallback), camas ambisónicas (recurso, lector WAV multicanal,
stream nativo, `OpenDouAmbisonicBed3D`), surround por el dispositivo (`MONO_PASS`) y los
reflectores como ajuste artístico. Observación 52 y trampas en `AGENTS.md`; §11 del spec;
B5–B9 resueltas.

**Fase 14, implementada (2026-09-03):** 1516 aserciones. Sondas en el bake (`.probes` junto a la
escena, botón en el inspector), caminos de Steam Audio como origen aparente + EQ + ganancia del
camino (el grafo autorado manda), ocluidores dinámicos como `IPLInstancedMesh` seguidos con umbral,
el depurador dibuja los caminos reales, `EdgeDiffractionEngine` y `RoomCouplingEngine` retirados.
Observación 53 y trampas en `AGENTS.md`; §11 del spec; B10–B13 resueltas.

**Fase 15, implementada (2026-09-03):** 1560 aserciones. Envío propio de reverb en `steam_audio`
(la voz vuelve a su `target_bus`; obs 49 acotada a `godot`), spline y multiposición como proveedores
de posición del pool, `OpenDouLoudnessTap` nativo, latencia del altavoz de mundo 107 ms afirmada.
Observación 54 y trampas en `AGENTS.md`; §11 del spec; C1, C3, C4, C5 pagadas; C2 pasa a la 16.

**Fase 16, implementada (2026-09-03):** 1624 aserciones. «La presa» (`scenes/demos/presa/`): 372 nodos
declarados, los 21 tipos de nodo salvo el 2D, sondas precocinadas, diez tesis afirmadas con audio
medido (spec §12). Destapó y arregló tres huecos del plugin (observación 55): el pool del
planificador tras cambiar el presupuesto, las capas sin efecto directo, y los caminos «a la vista»
congelados.

**Arreglado al releer la documentación (2026-09-03):** el manager cacheaba en GDScript si el hilo
de reflexiones y caminos estaba arrancado (`_reflections_started`) y no lo revivía cuando otro test
lo apagaba: con la escena de «La presa» tal como está comprometida, RT60 0 y ningún camino.
Ahora pregunta al nativo (`is_reflections_running()`); observación 56. Con ello se cerraron dos
aserciones que fluctuaban: la cola del hormigón de la convolución (espera dos corridas del hilo) y
la llegada del trueno (espera audio capturado, no reloj). Tres corridas seguidas verdes.

**Siguiente:** el cierre del sprint que quedó en la hoja de ruta (15.1 prefijado `OpenDou` de las
clases sin prefijo, 15.3 notas de versión y `README.md`), y después CI y plataformas. Candidatos a
estabilizar: `near_field` (Fase 9) fluctúa a veces.
