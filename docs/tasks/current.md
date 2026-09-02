# ⚡ Tarea Activa: «Una casa canta» — la escena que junta todo

* **Regla que gobierna las escenas:** [`.agents/rules/04_scene_composition.md`](../../.agents/rules/04_scene_composition.md)
* **Última fase con spec y plan:** Fase 6 — [spec](../superpowers/specs/2026-09-01-fase6-portales-audibles-design.md) · [plan](../superpowers/plans/2026-09-01-fase6-portales-audibles.md)

El hub tiene cinco entradas: «Bajo la quilla», «El monzón», «La cabina», «Una casa canta» y
el banco del rig. Todas se componen como árboles de nodos en su `.tscn`; los scripts solo
llevan lo dinámico, y una guarda lee cada escena sin instanciarla para hacerlo cumplir.

«Una casa canta» es un sector urbano cerrado con tres casas de verdad —suelo, paredes,
techo, puertas con hoja, ventanas con cristal— y la calle como sala `Outdoor`. Es la
primera escena que luce el grafo de salas de la Fase 6: la música sale por la ventana
entreabierta, y dentro de las casas dormidas la calle llega cortada a 300 Hz.

**Siguiente:** Fase 7 — Steam Audio. Análisis previo en
[`docs/superpowers/specs/2026-09-01-fase7-steam-audio-analisis.md`](../superpowers/specs/2026-09-01-fase7-steam-audio-analisis.md);
el spec de 7A (el spike) es lo que toca escribir. La Fase 4B (prefijado `OpenDou`) queda
pendiente detrás.
