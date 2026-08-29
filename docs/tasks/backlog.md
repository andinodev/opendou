# 📋 Backlog de Tareas: OpenDou Audio Middleware

Este archivo almacena el banco de tareas pendientes y planificadas para **OpenDou**, organizadas por módulo técnico, fases evolutivas y jerarquía de dependencias.

---

## 🎚️ 9. Audio HDR y Snapshots de Mezcla Global (`TASK-023`)

* [x] `TASK-023.1`: **Arquitectura de Snapshots de Mezcla (`AudioMixSnapshot`):**
  * Definición de perfiles de mezcla globales (volumen de buses, ecualización, envíos auxiliares y muteos) con curvas de interpolación suave (*blend times*).
* [x] `TASK-023.2`: **Motor de Audio HDR con Ventana de Sonoridad Móvil (`AudioHDREngine`):**
  * Ventana de compresión dinámica basada en el umbral físico superior de decibelios para evitar saturación balística.
* [x] `TASK-023.3`: **Matriz de Ducking Automático por Prioridad de Bus:**
  * Configuración de atenuaciones automáticas (ej. Diálogos y Disparos atenuando música y ambiente ambiental).
* [x] `TASK-023.4`: **Integración en la Suite de Edición (`OpenDouStudioMain`):**
  * Panel de gestión de Snapshots y visualizador gráfico de la ventana HDR.
* [x] `TASK-023.5`: **Suite de Pruebas Automatizadas:**
  * Validación unitaria de transiciones de snapshots y compresión HDR.

---

## 🎼 10. Jerarquía de Música Interactiva (`TASK-024`)

* [x] `TASK-024.1`: **Reloj Musical de Alta Precisión (`MusicClock`):**
  * Motor de sincronía con BPM, métricas de compás (4/4, 3/4, etc.), cálculo de *beats* y eventos de cuantización.
* [x] `TASK-024.2`: **Pistas y Segmentos Musicales Multicapa (`MusicSegment` & `MusicTrack`):**
  * Capas instrumentales dinámicas moduladas por intensidad de combate / exploración.
* [x] `TASK-024.3`: **Matriz de Transiciones Cuantizadas (`MusicTransitionMatrix`):**
  * Reglas de transición rítmica (*Immediate*, *Next Beat*, *Next Bar*, *Custom Exit Cue*) con crossfade sincrónico.
* [x] `TASK-024.4`: **Inyección de Stingers y Cues Rítmicos (`MusicStingerQueue`):**
  * Disparo de acentos musicales sincronizados al compás exacto con ducking temporal de la música base.
* [x] `TASK-024.5`: **Integración en el Editor y Pruebas Automatizadas:**
  * Nodos visuales de música interactiva en el lienzo y tests rítmicos.

---

## 🌐 11. Gestión y Localización de Diálogos (`TASK-025`)

* [x] `TASK-025.1`: **Mapeador de Tablas de Diálogo (`AudioDialogueTable`):**
  * Base de datos en memoria para asociar claves de diálogo (IDs) con archivos de audio según el *locale* activo (`es`, `en`, `ja`, `zh`, etc.).
* [x] `TASK-025.2`: **SoundBanks de Localización e Intercambio en Caliente:**
  * Carga y descarga dinámica de bancos de voz sin reiniciar ni duplicar árboles de eventos.
* [x] `TASK-025.3`: **Enrutamiento de Voz y Ducking Directo:**
  * Priorización automática de voces sobre buses de efectos y música.
* [x] `TASK-025.4`: **Integración en el Editor y Pruebas Automatizadas:**
  * Pestaña de localización en OpenDou Studio y verificación de cambio de idioma en runtime.

---

## 🎧 12. Reflexiones Tempranas 3D y Audio Inmersivo HRTF (`TASK-026`)

* [x] `TASK-026.1`: **Trazador de Rayos de Reflexiones Tempranas 3D (`AcousticReflector`):**
  * Trazado geométrico para calcular reflexiones de 1er y 2do orden contra paredes y techos cercanos.
* [x] `TASK-026.2`: **Procesador Espacial Binaural HRTF e ITD:**
  * Filtros espectrales de cabeza (*Head-Related Transfer Function*) y retardo interaural temporal para auriculares.
* [x] `TASK-026.3`: **Integración con `AudioRoom` y `AudioPortal`:**
  * Acoplamiento de reflexiones tempranas a las salas acústicas volumétricas.
* [x] `TASK-026.4`: **Pruebas Automatizadas de Espacialización 3D:**
  * Validación de posicionamiento binaural y coherencia de reflexiones.

---

## 🌊 13. Procesamiento DSP Avanzado (`TASK-027`)

* [x] `TASK-027.1`: **Motor de Reverberación por Convolución (`ConvolutionReverbNode`):**
  * Procesamiento de respuestas a impulsos reales (.wav IR) para realismo acústico en recintos físicos.
* [x] `TASK-027.2`: **Motor de Síntesis Granular en Tiempo Real (`AudioGranularSynthesizer`):**
  * Generación y modulación continua de granos acústicos para estiramiento temporal (*time-stretching*) y texturas ambientales complejas.
* [x] `TASK-027.3`: **Integración en Nodos del Grafo y Pruebas Automatizadas:**
  * Nodos de convolución y granular en el editor con validación headless.

---

## ⏱️ 14. Grabación Histórica de Sesión y Time-Travel Rewind (`TASK-028`)

* [x] `TASK-028.1`: **Búfer Circular de Telemetría Histórica (`ProfilerSessionRecorder`):**
  * Grabación en segundo plano de llamadas API, voces activas, picos DSP y transiciones.
* [x] `TASK-028.2`: **Línea de Tiempo Interactiva (*Time-Travel Scrubbing*) en el Profiler:**
  * Barra de reproducción/pausa/rebobinado en `OpenDouProfilerPanel` para congelar fotogramas y auditar robos de voz.
* [x] `TASK-028.3`: **Exportación e Importación de Sesiones (`.douprof`):**
  * Guardado y carga de sesiones de telemetría para depuración remota.
* [x] `TASK-028.4`: **Pruebas Automatizadas de Grabación y Rebobinado:**
  * Verificación de persistencia y consistencia de datos históricos.

---

## 📦 15. Empaquetado Final y Distribución (`TASK-029`)

* [x] `TASK-029.1`: **Iconografía y Tematizado Visual:**
  * Iconos SVG vectoriales para cada tipo de nodo en el árbol de escenas de Godot.
* [x] `TASK-029.2`: **Manifiesto `plugin.cfg` y Documentación de Instalación:**
  * Metadatos para Godot Asset Library y guía de integración rápida.
* [x] `TASK-029.3`: **Verificación Final y Release Package:**
  * Ejecución de la suite completa de pruebas con código de salida 0.
