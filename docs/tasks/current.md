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

**Fase 7A, spike hecho (2026-09-02):** una voz de Godot 4.7 sale por Steam Audio 4.8.1 y el
HRTF se mide: ILD ±15 dB, delante/detrás 15.9 % frente a 2.5 % sin HRTF, 11.6 ms de latencia.
Hallazgo: la API C **no** renderiza el ITD (fase plana por defecto); lo reporta en `peakDelays`
y 7B tiene que aplicarlo. Resultados en §11 del
[análisis](../superpowers/specs/2026-09-01-fase7-steam-audio-analisis.md). El código nativo vive
en `native/` (fuentes en git; SDK, godot-cpp y binarios ignorados; se compila con
`native/CMakeLists.txt`). Si la extensión no está compilada, la suite omite el spike y lo dice.

**Siguiente:** spec de 7A/7B a partir del análisis y del spike. La Fase 4B (prefijado
`OpenDou`) queda pendiente detrás.
