# Propuesta de Evolución: Music DAW Workspace (Interactive Music & Composition Architecture)

**Documento de Idea:** `018-music-daw-enhancements.md`  
**Módulo:** `addons/opendou/editor` / `addons/opendou/nodes` (Music Workspace)  
**Estado:** Análisis & Brainstorming de Mejoras

---

## 🎯 Diagnóstico Actual de la Vista Music

El espacio de trabajo **Music** cuenta con secuenciador multi-pista de stems, remixing vertical por intensidad (`combat_intensity`), playlists horizontales de segmentos, variaciones aleatorias (`🎲 Var: N`) y el nuevo modal *Add Track* conectado al motor de síntesis con audición y sincronización de BPM.

Para alcanzar el estándar de los sistemas de música interactiva más avanzados de la industria (Wwise Interactive Music Hierarchy / Elias Music Engine), se identifican las siguientes áreas de evolución:

---

## 🚀 Oportunidades de Mejora e Innovación para Music

### 1. Matriz de Transiciones Musicales Inteligentes (Interactive Transition Matrix)
* **El Problema:** Al cambiar de un segmento a otro (ej. de *Exploración Pacífica* a *Combate Táctico*), el cambio actualmente ocurre por corte o crossfade genérico, sin reglas de cuantización armónica.
* **La Solución:** Una **Matriz de Transiciones (Source $\to$ Destination)** con reglas profesionales:
  * **Punto de Sincronización:** Cambiar en el *Next Beat*, *Next Bar*, *Next Cue Marker* o *Immediate*.
  * **Stinger de Transición:** Disparar automáticamente un archivo o preset de stinger (ej. redoble de timbal o impacto metálico) durante el cambio.
  * **Curvas de Fade Asimétricas:** Fade-out del tema saliente de 1.2s y Fade-in del entrante de 0.4s.

---

### 2. Secuenciador de Patrones / Mini Piano Roll para Pistas Synth
* **El Problema:** Las pistas asignadas a presets de sintetizador (`synth_preset`) actualmente reproducen bucles pre-sintetizados de nota fija o arpegios predeterminados.
* **La Solución:**
  * Un **Mini Piano Roll / Step Sequencer** (16 a 64 pasos) integrado en la pista para dibujar notas, acordes, líneas de bajo o patrones rítmicos de sintetizador directamente en la línea de tiempo.
  * Permite cambiar las notas melódicas en caliente según el estado del juego (ej. escala menor en peligro, escala mayor en triunfo).

---

### 3. Marcadores de Sincronización de Gameplay (Game Sync Cue Markers)
* **El Problema:** En juegos de acción o cinemáticas, sincronizar un evento del juego (ej. un rayo en el cielo, la entrada de un jefe o el parpadeo de luces neón) con el compás o el *drop* de la música requiere código manual complejo.
* **La Solución:**
  * **Cue Markers en la regla de tiempo:** Marcadores visuales con nombre que emiten la señal `cue_triggered(marker_name)` al alcanzarse durante la reproducción.
  * Permite a los programadores conectar mecánicas visuales directamente al ritmo de la música.

---

### 4. Soporte para Cambios de Compás y Rampa de Tempo (BPM Curves)
* **El Problema:** Toda la suite comparte un único BPM estático y compás $4/4$.
* **La Solución:**
  * Carril de automatización de tempo (`BPM Track`) para acelerar el ritmo en momentos de clímax (ej. de 90 BPM a 140 BPM).
  * Soporte de métricas de compás configurables ($3/4$, $4/4$, $6/8$, $7/8$).

---

### 5. Gestor Visual de Stingers y Ducking Musical Automático
* **El Problema:** Los stingers se disparan de forma independiente y pueden chocar con frecuencias pesadas de la música base.
* **La Solución:**
  * Panel de gestión de Stingers con prioridad y regla de Ducking musical (la música de fondo baja $-4\text{dB}$ automáticamente durante los $2$ segundos que dura el stinger y se recupera con crossfade suave).
