# Propuesta de Evolución: Synth Workspace (VST Modular Rack, DSP Architecture & Sound Design)

**Documento de Idea:** `020-synth-workspace-enhancements.md`  
**Módulo:** `addons/opendou/editor/opendou_synth_rack_workspace.gd` / `addons/opendou/runtime/synth` (Synth Workspace)  
**Estado:** Análisis & Brainstorming de Mejoras

---

## 🎯 Diagnóstico Actual de la Vista Synth

El espacio de trabajo **Synth (Modo 3)** cuenta con un rack modular Eurorack en pantalla completa con 9 generadores DSP (`Harmonic_Buzz`, `Sine`, `Sawtooth`, `FM_2Op`, `Pluck_Karplus`, etc.), envolvente ADSR interactiva, filtro biquad resonante, LFO, saturación de Drive, paneo estéreo de potencia constante, ping-pong delay, reverb FDN espacial y controles interactivos (`OpenDouKnob`, `OpenDouADSREditor`, `OpenDouWaveformPlayhead`, `OpenDouVUMeter`).

Para convertirlo en un sintetizador de producción de sonido y diseño sonoro a la altura de plugins VST comerciales (estilo *Serum*, *Vital* o *Phase Plant*), se identifican las siguientes áreas de evolución:

---

## 🚀 Oportunidades de Mejora e Innovación para Synth

### 1. Motor Multi-Oscilador y Unísono Estéreo Masivo (SuperSaw / Multi-Osc Stacking)
* **El Problema:** Actualmente cada preset sintetiza una sola voz principal, limitando la amplitud de pads y leads épicos.
* **La Solución:**
  * **Módulo Unison:** Permite apilar de 2 a 8 voces por oscilador con desafinación estéreo (*Detune Spread*) y apertura panorámica (*Stereo Spread*).
  * Produce sonidos masivos estilo *SuperSaw*, bajos reese ultra-anchos y texturas cinematográficas densas.

---

### 2. Arpegiador Integrado y Secuenciador de Modulación por Pasos (Step Arp & Mod Sequencer)
* **El Problema:** Los arpegios y ritmos actualmente deben ser programados con código o envolventes fijas.
* **La Solución:**
  * **Arpegiador de 16 Pasos:** Modos `Up`, `Down`, `UpDown`, `Random`, `Chord` con subdivisiones de tiempo ($1/4, 1/8, 1/16, 1/32$) y octavas configurables ($1 - 4$).
  * **Step Modulator:** Carril de pasos donde el usuario dibuja barras de modulación para crear filtros rítmicos (*Trance Gate*, *Wobble Bass*).

---

### 3. Matriz de Modulación Libre (Modulation Matrix / Virtual Patch Bay)
* **El Problema:** El LFO y las envolventes tienen rutas preasignadas en los módulos individuales.
* **La Solución:**
  * Una **Matriz de Modulación 8x8** (o cables de conexión virtuales) donde cualquier fuente (LFO 1, LFO 2, ADSR 2, ModWheel, Velocity, Aleatoriedad) puede modular cualquier destino (Frecuencia de corte, Resonancia, Drive, Pitch, Retardo de Delay, Tamaño de Reverb, Paneo) con profundidad (*Depth*) positiva o negativa.

---

### 4. Exportador de Presets a Archivo WAV con Puntos de Bucle (Render to WAV / Sample Asset)
* **El Problema:** El diseñador de sonido a veces desea congelar un preset en un archivo `.wav` físico para editarlo en software externo o empaquetarlo como sample estándar.
* **La Solución:**
  * Botón `[ 💾 Render to WAV ]` en la barra superior del rack:
    * Genera y guarda un archivo WAV estéreo de 16/24 bits con metadatos de compás y puntos de bucle perfectos (*Loop Points*) en `res://`.

---

### 5. Motor de Tablas de Ondas y Síntesis Granular (Wavetable & Granular Expansion)
* **El Problema:** Los 9 generadores actuales son analógicos/FM/ruido fijos.
* **La Solución:**
  * **Generador de Tablas de Ondas (Wavetable):** Permite morphing y escaneo a través de formas de onda complejas (Vocal, Metálica, Digital, Distorsionada).
  * **Generador Granular:** Fragmenta micro-granos de audio para crear paisajes sonoros texturales, nubes ambientales infinitas y efectos de congelación temporal (*Time Freeze*).
