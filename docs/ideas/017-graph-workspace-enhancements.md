# Propuesta de Evolución: Graph Workspace (SFX & Visual Event Architecture)

**Documento de Idea:** `017-graph-workspace-enhancements.md`  
**Módulo:** `addons/opendou/editor` / `addons/opendou/core` (Graph Workspace)  
**Estado:** Análisis & Brainstorming de Mejoras

---

## 🎯 Diagnóstico Actual de la Vista Graph

El espacio de trabajo **Graph** es la columna vertebral del diseño de efectos sonoros (SFX) y jerarquías de eventos en OpenDou. Actualmente cuenta con nodos fundamentales (`Blend`, `Random`, `Switch`, `Sequence`, `Physical`, `Attenuation`, `Duck`, `Microphone`, `Synth`), integración con Game Syncs (RTPCs/Switches) y exportación a SoundBanks.

Sin embargo, para proyectos de gran escala (AAA), la vista presenta oportunidades de mejora en modularidad, inspección en tiempo real y ergonomía visual.

---

## 🚀 Oportunidades de Mejora e Innovación para Graph

### 1. Nodos Compuestos y Sub-Grafos Reutilizables (Compound / Macro Nodes)
* **El Problema:** En eventos complejos (ej. *Disparo de Arma*, *Pasos con Calzado + Superficie + Foley de Ropa*), el lienzo se llena de decenas de nodos interconectados, volviéndose difícil de mantener.
* **La Solución:** Permitir agrupar una selección de nodos en un **Sub-Grafo reutilizable** (o *Macro Node*) con entradas y salidas configurables. Esto permite instanciar un macro `Footstep_Compound` en múltiples eventos sin duplicar lógica.

---

### 2. Pulso Visual de Señal en Tiempo Real (Live Execution Glow & Node VU Meters)
* **El Problema:** Al audicionar un evento o durante el Live Update con el juego corriendo, no es evidente a simple vista qué camino de la jerarquía se está ejecutando ni qué porcentaje de señal atraviesa cada rama.
* **La Solución:**
  * **Cables Animados:** Las conexiones activas emiten un pulso de luz o flujo de partículas eléctricas al activarse.
  * **VUMeters en Nodos:** Pequeños medidores LED en la cabecera de cada nodo que muestran el nivel de salida individual de esa capa en tiempo real.
  * **Indicador de Voz Virtual:** Borde amarillo/naranja si el nodo fue virtualizado por el gestor de prioridades.

---

### 3. Inserción de Efectos DSP por Nodo (Node FX Chain Inserts)
* **El Problema:** Actualmente los efectos globales se aplican principalmente a nivel de bus o sala acústica. Si un diseñador quiere que solo la capa de *Eco de Metralla* tenga un Pitch Shifter aleatorio y un Chorus sin alterar el resto del evento, debe crear un bus separado.
* **La Solución:** Añadir una pestaña o ranura de **Inserción de Efectos DSP por Nodo** (Filtro Paramétrico, Pitch Shift, Flanger/Chorus, Distorsión, Compresor ligero) configurable directamente en el Inspector del nodo.

---

### 4. Envíos Auxiliares de Reverb / Delay por Nodo (Aux Sends)
* **El Problema:** El envío a reverb está ligado al entorno 3D espacial o al bus principal.
* **La Solución:** Control deslizante de `Aux Send` (ej. `Reverb Send Level` / `Echo Send Level`) en cada nodo del grafo, permitiendo que una capa seca de impacto tenga $0\%$ de reverb mientras que la cola ambiental del mismo evento envíe un $80\%$ a la reverb de la sala.

---

### 5. Cajas de Comentarios y Organización Visual (Backdrop Comment Boxes)
* **El Problema:** Al crecer el grafo, no hay forma visual de delimitar secciones lógicas (ej. *"Capa de Impacto"*, *"Capa de Mecanismo"*, *"Capa de Cola Ambiental"*).
* **La Solución:**
  * **Comment Nodes / Backdrops:** Áreas rectangulares de color personalizable con título descriptivo que agrupan y mueven juntos todos los nodos contenidos en su interior.
  * **Herramientas de Alineación Automática:** Botones de alineación rápida (Alinear a la izquierda, distribuir horizontalmente, auto-formato en cuadrícula).

---

### 6. Mini-Teclado Virtual de Audición y Scrubber RTPC Integrado
* **El Problema:** Para probar un evento en diferentes notas o con variaciones de RTPC, hay que cambiar de panel o simular variables manualmente.
* **La Solución:** Una barra inferior colapsable en el propio Graph con:
  * Sliders rápidos de los RTPCs que afectan a los nodos en pantalla.
  * Botón de audición instantánea del nodo seleccionado individualmente (solo ese nodo, sin disparar todo el evento).
