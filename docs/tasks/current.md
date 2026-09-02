# ⚡ Tarea Activa: Fase 10 implementada — siguiente, Fase 11

* **Regla que gobierna las escenas:** [`.agents/rules/04_scene_composition.md`](../../.agents/rules/04_scene_composition.md)
* **Última fase con spec y plan:** Fase 6 — [spec](../superpowers/specs/2026-09-01-fase6-portales-audibles-design.md) · [plan](../superpowers/plans/2026-09-01-fase6-portales-audibles.md)

El hub tiene cinco entradas: «Bajo la quilla», «El monzón», «La cabina», «Una casa canta» y
el banco del rig. Todas se componen como árboles de nodos en su `.tscn`; los scripts solo
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

**Siguiente:** spec de la Fase 11 según la hoja de ruta (emisores nuevos y modos).
