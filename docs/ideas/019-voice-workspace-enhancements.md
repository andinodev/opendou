# Propuesta de Evolución: Voice Workspace (Dialogue, Localization & Voice DSP Architecture)

**Documento de Idea:** `019-voice-workspace-enhancements.md`  
**Módulo:** `addons/opendou/editor` / `addons/opendou/core/dialogue` (Voice Workspace)  
**Estado:** Análisis & Brainstorming de Mejoras

---

## 🎯 Diagnóstico Actual de la Vista Voice

El espacio de trabajo **Voice** cuenta con el gestor centralizado `AudioDialogueManager`, matriz de localización multi-idioma (`en`, `es`, `ja`, etc.), tabla de subtítulos sincronizada y efectos de radio táctica para transmisiones cibernéticas.

Para proyectos con fuerte carga narrativa y cinemáticas, se identifican las siguientes áreas de evolución:

---

## 🚀 Oportunidades de Mejora e Innovación para Voice

### 1. Generador de Voces Procedurales Sintéticas (Gibberish / Phoneme Chatter Synth)
* **El Problema:** Durante el desarrollo temprano o en juegos con estilo estilizado (estilo *Celeste*, *Animal Crossing* o transmisiones alienígenas), los desarrolladores no tienen actores de voz listos y deben recurrir a archivos temporales o silencio.
* **La Solución:**
  * Un **Generador de Balbuceo Fonético Procedural (Gibberish Synth)** integrado que utiliza `ModularSynthEngine` para modular micro-tonos y formantes vocales según las letras del texto del subtítulo.
  * Permite asignar perfiles de tono, velocidad y timbre a cada personaje para que "hablen" proceduralmente con texto en pantalla.

---

### 2. Extractor de Visemas y Lip-Sync Automático (Automated Viseme / Mouth Shapes)
* **El Problema:** Sincronizar la animación facial de personajes 3D o avatares 2D con los archivos de voz requiere software externo o animación manual cuadro a cuadro.
* **La Solución:**
  * **Analizador de Amplitud y Formantes en Tiempo Real:** Analiza el audio y genera una señal de apertura de boca (`viseme_weight: 0.0 - 1.0` y fonemas básicos $A, E, I, O, U, M, F, S$).
  * Emite señales para que los animadores conecten *BlendShapes* o sprites de boca directamente sin plugins externos.

---

### 3. Perfiles de Procesamiento de Voz por Personaje (Voice Actor DSP Profiles)
* **El Problema:** Actualmente los efectos de radio son globales o se aplican manualmente en cada llamada.
* **La Solución:**
  * **Perfiles de Personaje:** Tarjetas configurables en el editor con DSP dedicado:
    * *Personaje Principal (Jesika):* EQ de presencia + calidez + de-esser ligero.
    * *Comandante Táctico:* Radio Walkie-Talkie (Bandpass 400Hz - 3.5kHz, saturación y bleeps de apertura/cierre de micro).
    * *IA Holográfica:* Chorus estéreo + Bitcrusher ligero + Delay de 120ms.
    * *Entidad Sobrenatural:* Pitch Shift de -4 semitonos + generador sub-armónico.

---

### 4. Árbol de Flujo de Conversación y Diálogos con Ramas (Dialogue Branching Graph)
* **El Problema:** Los diálogos se disparan como eventos aislados, requiriendo lógica externa de gameplay para encadenar conversaciones complejas.
* **La Solución:**
  * **Grafo de Conversación:** Nodos de diálogo encadenados con soporte de opciones de respuesta del jugador, condiciones de variables (`RTPC`, `GameState`) y disparadores de eventos de audio en momentos clave.

---

### 5. Importador/Exportador Masivo de Localización y Auditor de Faltantes (CSV / PO Auditor)
* **El Problema:** Traducir cientos de líneas de diálogo en proyectos grandes es propenso a errores humanos de archivos de audio extraviados.
* **La Solución:**
  * Importador/Exportador directo a formato **CSV / JSON / PO**.
  * **Auditor de Integridad:** Un botón `[ 🔍 Audit Missing Audio ]` que analiza todos los idiomas y destaca en rojo qué líneas no tienen archivo de voz asignado o qué subtítulos están desincronizados.
