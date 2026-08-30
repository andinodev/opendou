# Propuesta de Evolución: Graph Workspace (SFX & Visual Event Architecture)

**Documento de Idea:** `017-graph-workspace-enhancements.md`  
**Módulo:** `addons/opendou/editor` / `addons/opendou/core` (Graph Workspace)  
**Estado:** Análisis & Brainstorming de Mejoras

---

## 🎯 Diagnóstico Actual de la Vista Graph

El espacio de trabajo **Graph** es la columna vertebral del diseño de efectos sonoros (SFX) y jerarquías de eventos en OpenDou. Actualmente cuenta con nodos fundamentales (`Blend`, `Random`, `Switch`, `Sequence`, `Physical`, `Attenuation`, `Duck`, `Microphone`), integración con Game Syncs (RTPCs/Switches) y exportación a SoundBanks.

Sin embargo, tras el análisis del flujo de trabajo, se detectan dos limitaciones críticas inmediatas en las fuentes de sonido, junto con oportunidades de modularidad e inspección en tiempo real:

---

## 🚀 Oportunidades de Mejora e Innovación para Graph

### 1. Nodo de Presets de Síntesis Procedural en el Grafo (`⚡ Add Synth Preset Node`)
* **El Problema:** El motor de síntesis VST (`SynthPresetRegistry` / `ModularSynthEngine`) ya está conectado a los Nodos Declarativos 3D y al Music DAW, pero **no existe un nodo de Grafo dedicado** en el menú contextual (`Clic derecho / Tab`) para instanciar un preset de síntesis dentro de un evento de sonido SFX.
* **La Solución:**
  * Crear el nodo visual **`OpenDouSynthGraphNode`** (`⚡ Synth (Procedural Generator)`):
    * **Selector de Preset:** Menú desplegable o buscador reactivo de presets categorizados (`Leads`, `Pads`, `Bass`, `Percussion`, `Nature/Ambience`, `SFX`).
    * **Controles Rápidos en Nodo:** Perillas de Frecuencia Base (`Base Pitch / Freq`), Variación aleatoria y Ganancia.
    * **Audición y Forma de Onda:** Botón `[ ▶ Play ]` con visualizador de onda y playhead interactivo directo en el nodo.
    * **Salida de Audio Conectable:** Conectable a `RandomNode`, `BlendNode`, `SequenceNode`, `SwitchNode` o `Master_Output`.

---

### 2. Selector Interactivo de Archivos en Nodos WAV (`📁 File Browser & Drag-and-Drop Picker`)
* **El Problema:** Al presionar *"🎵 Add WAV (Audio File)"* en el menú contextual, el nodo instanciado viene fijado con el texto `"gunfire_var1.wav"` de forma rígida y no cuenta con un botón para abrir un `FileDialog` y seleccionar otros archivos `.wav` o `.ogg` del proyecto `res://`.
* **La Solución:**
  * **Botón `[ 📁 Browse... ]` en el propio `OpenDouAudioFileGraphNode`:** Al pulsarlo, abre un explorador de archivos nativo filtrado a extensiones soportadas (`*.wav, *.ogg, *.mp3`).
  * **Soporte Drag & Drop Mejorado:** Arrastrar archivos de audio desde el panel de *FileSystem* de Godot directamente sobre el lienzo del Grafo instanciará automáticamente nodos `OpenDouAudioFileGraphNode` con la ruta, duración y forma de onda calculadas al instante.
  * **Recálculo Inmediato de Forma de Onda:** Al cambiar el archivo seleccionado, la mini-pantalla de forma de onda del nodo redibuja automáticamente los picos reales del nuevo archivo.

---

### 3. Nodos Compuestos y Sub-Grafos Reutilizables (Compound / Macro Nodes)
* **El Problema:** En eventos complejos (ej. *Disparo de Arma*, *Pasos con Calzado + Superficie + Foley de Ropa*), el lienzo se llena de decenas de nodos interconectados, volviéndose difícil de mantener.
* **La Solución:** Permitir agrupar una selección de nodos en un **Sub-Grafo reutilizable** (o *Macro Node*) con entradas y salidas configurables. Esto permite instanciar un macro `Footstep_Compound` en múltiples eventos sin duplicar lógica.

---

### 4. Pulso Visual de Señal en Tiempo Real (Live Execution Glow & Node VU Meters)
* **El Problema:** Al audicionar un evento o durante el Live Update con el juego corriendo, no es evidente a simple vista qué camino de la jerarquía se está ejecutando ni qué porcentaje de señal atraviesa cada rama.
* **La Solución:**
  * **Cables Animados:** Las conexiones activas emiten un pulso de luz o flujo de partículas eléctricas al activarse.
  * **VUMeters en Nodos:** Pequeños medidores LED en la cabecera de cada nodo que muestran el nivel de salida individual de esa capa en tiempo real.
  * **Indicador de Voz Virtual:** Borde amarillo/naranja si el nodo fue virtualizado por el gestor de prioridades.

---

### 5. Inserción de Efectos DSP por Nodo (Node FX Chain Inserts)
* **El Problema:** Actualmente los efectos globales se aplican principalmente a nivel de bus o sala acústica. Si un diseñador quiere que solo la capa de *Eco de Metralla* tenga un Pitch Shifter aleatorio y un Chorus sin alterar el resto del evento, debe crear un bus separado.
* **La Solución:** Añadir una pestaña o ranura de **Inserción de Efectos DSP por Nodo** (Filtro Paramétrico, Pitch Shift, Flanger/Chorus, Distorsión, Compresor ligero) configurable directamente en el Inspector del nodo.

---

### 6. Envíos Auxiliares de Reverb / Delay por Nodo (Aux Sends)
* **El Problema:** El envío a reverb está ligado al entorno 3D espacial o al bus principal.
* **La Solución:** Control deslizante de `Aux Send` (ej. `Reverb Send Level` / `Echo Send Level`) en cada nodo del grafo, permitiendo que una capa seca de impacto tenga $0\%$ de reverb mientras que la cola ambiental del mismo evento envíe un $80\%$ a la reverb de la sala.

---

### 7. Cajas de Comentarios y Organización Visual (Backdrop Comment Boxes)
* **El Problema:** Al crecer el grafo, no hay forma visual de delimitar secciones lógicas (ej. *"Capa de Impacto"*, *"Capa de Mecanismo"*, *"Capa de Cola Ambiental"*).
* **La Solución:**
  * **Comment Nodes / Backdrops:** Áreas rectangulares de color personalizable con título descriptivo que agrupan y mueven juntos todos los nodos contenidos en su interior.
  * **Herramientas de Alineación Automática:** Botones de alineación rápida (Alinear a la izquierda, distribuir horizontalmente, auto-formato en cuadrícula).

---

### 8. Mini-Teclado Virtual de Audición y Scrubber RTPC Integrado
* **El Problema:** Para probar un evento en diferentes notas o con variaciones de RTPC, hay que cambiar de panel o simular variables manualmente.
* **La Solución:** Una barra inferior colapsable en el propio Graph con:
  * Sliders rápidos de los RTPCs que afectan a los nodos en pantalla.
  * Botón de audición instantánea del nodo seleccionado individualmente (solo ese nodo, sin disparar todo el evento).
