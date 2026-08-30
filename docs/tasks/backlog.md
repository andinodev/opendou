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

---

## 💾 16. Persistencia Real, CRUD de Pistas y Ergonomía del Music DAW (`TASK-030`)

* [x] `TASK-030.1`: **Indicador de Estado Modificado (`Dirty State *`):**
  * Al modificar cualquier valor del DAW, mostrar un asterisco junto al nombre del recurso y advertir con un diálogo al cambiar de pestaña si hay cambios sin guardar.
* [x] `TASK-030.2`: **Guardado en Disco (`Ctrl+S` / Botón 💾):**
  * Serialización persistente del recurso `MusicSegment.tres` y su árbol de pistas mediante `ResourceSaver.save()` y JSON de respaldo.
* [x] `TASK-030.3`: **Caché y Restauración Visual de Pestañas:**
  * Guardar en memoria la posición del scroll, nivel de zoom, capas activas y cabezal al alternar entre *Graph*, *Music DAW* y *Dialogues*.
* [x] `TASK-030.4`: **CRUD de Pistas (`Add / Delete Track`):**
  * Botón `[ ➕ Add Track ]` para crear nuevas capas dinámicas y botón `[ 🗑️ ]` para eliminarlas.
* [x] `TASK-030.5`: **Asignación de Archivos de Audio (`Audio File Picker`):**
  * Selector en la cabecera del track (`[ 📁 Load WAV/OGG ]`) mediante `EditorFileDialog` para asignar cualquier archivo del proyecto.
* [x] `TASK-030.6`: **Scrollbars y Tiradores de Recorte (`Clip Trim Handles`):**
  * Barras de desplazamiento horizontal/vertical fluidas en `ScrollContainer` y tiradores en los bordes de los clips para recortar o repetir visualmente.

---

## ⏱️ 17. Marcadores Estructurales y Sub-Pistas Aleatorias (`TASK-031`)

* [x] `TASK-031.1`: **Marcadores Pre-Entry Cues (Anacrusas / Pickups):**
  * Marcador visual interactivo que permite que el clip comience a sonar antes del compás 1.
* [x] `TASK-031.2`: **Colas de Desbordamiento Post-Exit Tails:**
  * Cola de reverberación y platillos que sigue sonando sin cortarse abruptamente tras transicionar al siguiente segmento.
* [x] `TASK-031.3`: **Sub-Pistas Aleatorias (*Random Multi-Tracks*):**
  * Carriles de variación dentro de cada capa (ej. Variación A, B y C de batería) que el motor elige aleatoriamente en cada vuelta del bucle de 8 compases.

---

## 📈 18. Automatizaciones RTPC en Línea de Tiempo y Ruteo de Buses (`TASK-032`)

* [x] `TASK-032.1`: **Carriles de Automatización Desplegables:**
  * Líneas de curvas de puntos (*Splines / Beziers*) bajo cada pista para automatizar volumen, filtros pasa-bajos (LPF) o envíos auxiliares.
* [x] `TASK-032.2`: **Vinculación a Parámetros RTPC:**
  * Mapeo de curvas a variables del juego (`CombatIntensity`, `Health`, `DangerLevel`).
* [x] `TASK-032.3`: **Ruteo de Sub-Buses por Pista:**
  * Selector en cada cabecera de pista para dirigir la salida a sub-buses específicos de Godot (`Music_Pads`, `Music_Percussion`, `Music_Leads`).

---

## 🎼 19. Gestor de Playlists Musicales y Jerarquía (`TASK-033`)

* [x] `TASK-033.1`: **Secuenciador de Playlists (`MusicPlaylistManager`):**
  * Orquestación de flujo de estados musicales (`Intro` $\rightarrow$ `Loop_A (2 a 4 veces)` $\rightarrow$ `Transición` $\rightarrow$ `Loop_B` $\rightarrow$ `Outro`).
* [x] `TASK-033.2`: **Reglas de Aleatoriedad y Repetición de Segmentos:**
  * Lógica no lineal para evitar repetición predecible entre secciones de combate y exploración.
* [x] `TASK-033.3`: **Integración de Deshacer/Rehacer (`UndoRedo`):**
  * Conexión completa al historial del editor de Godot para todas las acciones del DAW.

---

## 🦆 20. Matriz Visual de Audio Ducking en el HDR Mixer (`TASK-034`)

* [ ] `TASK-034.1`: **Panel / Pestaña "🦆 Ducking Matrix" en el Mixer Drawer:**
  * Vista matricial (Bus Emisor vs Bus Receptor) para configurar atenuación automática.
* [ ] `TASK-034.2`: **Configuración de Parámetros de Ducking:**
  * Atenuación en dB (`-1 dB a -48 dB`), tiempos de ataque y liberación en milisegundos (`Attack / Release ms`), y curva de fade.
* [ ] `TASK-034.3`: **Indicadores de Atenuación en Tiempo Real y Persistencia:**
  * Animación visual de medidores cuando un diálogo o explosión atenúa la música o ambiente.

---

## 🎛️ 21. Nodos Visuales de Modulación AHDSR y LFOs en Graph Editor (`TASK-035`)

* [ ] `TASK-035.1`: **Nodo Visual de Envolvente AHDSR (`OpenDouAHDSRGraphNode`):**
  * Canvas gráfico interactivo con curvas de ataque, hold, decaimiento, sustain y liberación.
* [ ] `TASK-035.2`: **Nodo Visual de Oscilador LFO (`OpenDouLFOGraphNode`):**
  * Generador de formas de onda periódicas (`Sine`, `Triangle`, `Square`, `Random S&H`) con selector de frecuencia en Hz y profundidad.
* [ ] `TASK-035.3`: **Enrutamiento de Modulación a Parámetros DSP:**
  * Conexión por cables para modular dinámicamente volumen, tono (*pitch*) y frecuencias de corte de filtros.

---

## ⛓️ 22. Nodo Contenedor Secuencial en Graph Editor (`TASK-036`)

* [ ] `TASK-036.1`: **Nodo Visual de Secuencia (`OpenDouSequenceGraphNode`):**
  * Nodo con tabla/lista ordenada de clips de audio y retardos individuales entre pasos (*step delays*).
* [ ] `TASK-036.2`: **Modos de Secuenciación Cronológica:**
  * Soporte de modos `Sequential (One-Shot)`, `Continuous Loop` y `Ping-Pong`.
* [ ] `TASK-036.3`: **Audición en Vivo y Serialización:**
  * Reproducción interactiva de la cadena paso a paso y guardado en JSON / `.tres`.

---

## 📊 23. Grabador y Reproductor de Sesiones en el Live Profiler (`TASK-037`)

* [ ] `TASK-037.1`: **Controles de Grabación de Telemetría (`Record / Stop`):**
  * Botón `[ 🔴 Record Session ]` en el panel del Profiler con temporizador y contador de muestras en vivo.
* [ ] `TASK-037.2`: **Exportación e Importación de Sesiones JSON:**
  * Carga de sesiones de juego grabadas para análisis post-mortem de consumo de CPU, voces activas y picos de memoria.
* [ ] `TASK-037.3`: **Línea de Tiempo de Reproducción / Scrubbing del Perfil:**
  * Barra de desplazamiento temporal para reproducir la sesión grabada segundo a segundo.

---

## 🏛️ 24. Diseñador Paramétrico de Salas Acústicas en Convolución (`TASK-038`)

* [ ] `TASK-038.1`: **Panel Paramétrico de Salas en `OpenDouConvolutionGraphNode`:**
  * Controles de dimensiones físicas (Largo, Ancho, Alto en metros).
* [ ] `TASK-038.2`: **Materiales y Coeficientes de Absorción:**
  * Selección de materiales acústicos (Madera, Concreto, Vidrio, Metal) y cálculo de tiempo de reverberación `RT60`.
* [ ] `TASK-038.3`: **Síntesis Procedural Inmediata de IR:**
  * Generación y preview de forma de onda del impulso acústico generado en tiempo real.

---

## 📡 25. Depurador Visual de Zonas Acústicas, Portales y Oclusión (`TASK-039`)

* [ ] `TASK-039.1`: **Radar / Visor 2D Acústico Integrado en el Dock:**
  * Renderizado interactivo de salas acústicas (`AudioRoom`), portales (`AudioPortal`) y posición del oyente/emisor.
* [ ] `TASK-039.2`: **Monitoreo de Oclusión y Difracción en Tiempo Real:**
  * Visualización de rayos acústicos directos, atenuación de aperturas y cálculo de difracción en esquinas.


