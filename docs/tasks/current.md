# ⚡ Tarea Activa: Fase 7B — binaural para todas las voces (implementada; a prueba)

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
