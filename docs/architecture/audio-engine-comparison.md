| Área Arquitectónica | Godot Engine (Nativo) | FMOD Studio | Wwise (Audiokinetic) |
| --- | --- | --- | --- |
| **Paradigma de Disparo** | Nodos en escena (`AudioStreamPlayer`) acoplados al árbol. | **Eventos tipo Timeline/DAW** con pistas, capas e instrumentos modulados en el tiempo o por parámetros. | **Eventos basados en Acciones** (*Play*, *Stop*, *Set Switch*, *Set State*) sobre contenedores lógicos abstractos. |
| **Estructuras de Contención** | `AudioStreamRandomizer`, `AudioStreamPlaylist`. | *Multi-Instrument*, *Scatterer*, *Programmer Instrument*. | *Random Container*, *Sequence Container*, *Blend Container*, *Switch Container*. |
| **Variables y Modulación** | Sin capa de abstracción; control manual mediante *scripts* (`set_volume_db`, Tweens). | **Parámetros RTPC** (continuos/discretos), parámetros integrados (Distancia, Ángulo) y moduladores (AHDSR, LFO). | **Game Syncs Desacoplados**: *RTPCs* con curvas mapeadas, *Switches* por entidad, *States* globales y *Triggers*. |
| **Gestión de Voces (Virtualización)** | Polifonía básica (`max_polyphony`). Sin seguimiento inaudible ni *voice stealing* dinámico. | **Virtual Voices**: seguimiento de tiempo sin consumo de DSP/CPU. Robo por volumen, distancia, antigüedad o prioridad. | **Virtual Voices avanzadas** (*Resume*, *Elapsed time*, *Restart*, *Kill*), límites por entidad y prioridad con *offset* por distancia. |
| **Espacialización y Acústica** | Atenuación básica (curvas estándar), conos direccionales y cambio de bus vía `Area3D`. | Oclusión poligonal por mallas (*Geometry API*), plugins binaurales HRTF. | **Spatial Audio**: *Rooms and Portals*, difracción geométrica en esquinas, reflexiones tempranas (*Wwise Reflect*). |
| **Música Interactiva** | `AudioStreamInteractive` y `AudioStreamSynchronized` (cambios por compás/tempo y *stems*). | Líneas de tiempo cuantizadas con marcadores de tempo, compás y saltos condicionales. | **Interactive Music Hierarchy**: Matriz de transiciones $N \times N$, segmentos, *playlists*, pistas puente y *stingers*. |
| **Mezcla y Dinámica Avanzada** | Buses jerárquicos y efectos de inserción (compresor con *sidechain* básico). | **Snapshots** aditivos/excluyentes con curvas de interpolación, canales VCA. | **HDR Audio** (umbral de sonoridad psicoacústico adaptativo), *Auto-Ducking* de bus multinivel. |
| **Empaquetado y Streaming** | Archivos sueltos en paquetes `.pck` (WAV/Vorbis/MP3). Carga completa o *stream* directo. | **Bancos FSB / Bank**: Separación de metadatos y muestras con compresión propietaria (FADPCM/Vorbis). | **SoundBanks por eventos**: Carga selectiva, compresión optimizada y *Prefetch* (milisegundos iniciales en RAM para latencia cero). |
| **Entorno de Autoría** | Inspector nativo y panel inferior de buses de audio dentro del editor. | **FMOD Studio** (DAW independiente con interfaz visual de mezcla). | **Wwise Authoring Tool** (Suite técnica visual orientada a objetos lógicos). |
| **Ajuste en Caliente y Profiling** | Monitoreo estándar de rendimiento del motor. Sin consola dedicada de audio. | **Live Update por TCP**: ajuste de mezcla y curvas en tiempo real contra el juego en ejecución; Profiler de voces/CPU. | **Live Profiler y WAAPI**: captura de línea de tiempo cuadro a cuadro, monitor de asignación de memoria y automatización por WebSockets. |

---

**Componentes que debemos construir desde cero para nuestro Middleware**

**1. Núcleo Lógico Desacoplado (GDExtension / C++)**

* **Gestor de Eventos y Acciones:** Un despachador que traduzca llamadas del juego (ej. `AudioEngine.post_event("Play_Footstep", self)`) en comandos internos independientes de la escena.
* **Contenedores Lógicos:** Implementación de nodos de control (*Random/Shuffle*, *Switch*, *Blend* y *Sequence*) que evalúen condiciones lógicas antes de emitir sonido.
* **Motor RTPC y Curvas de Modulación:** Sistema centralizado para registrar variables flotantes/discretas y calcular valores interpolados (volumen, tono, filtros) según curvas spline personalizadas.

**2. Sistema de Voces Virtuales y Asignación de Recursos**

* **Voice Pool Manager:** Límite global y por categoría de voces físicas simultáneas.
* **Seguimiento Virtual (Zero-Cost Playback):** Contadores de posición de reproducción que avanzan en milisegundos lógicos sin instanciar decodificadores de audio mientras el sonido esté fuera de rango o por debajo del umbral de audibilidad.
* **Algoritmos de Robo de Voz:** Evaluación en tiempo real de prioridad dinámica (`Prioridad Base - (Distancia * Factor)`) para reasignar canales físicos al sonido de mayor peso.

**3. Pipeline de SoundBanks y Streaming Híbrido**

* **Formato de Archivo Empaquetado Binario:** Compilador de assets que genere archivos empaquetados (`.bank`) con compresión eficiente (como Opus o ADPCM optimizado) y tablas de búsqueda rápida de metadatos.
* **Capa de Prefetching:** Carga de los primeros 64–128 KB de cada muestra en un *pool* de memoria fija (RAM) para disparo instantáneo, conectando de forma transparente con un lector en segundo plano (*streaming thread*) para el resto del archivo.

**4. Módulo de Acústica y Propagación (Spatial Audio)**

* **Sistema de Habitaciones y Portales (Rooms & Portals):** Nodos espaciales que calculen automáticamente la ruta de propagación del sonido entre recintos cerrados y aberturas, aplicando filtrado pasabajo (*Low Pass Filter*) dinámico por oclusión.
* **Integración de Trazado de Rayos Acústico:** Uso del servidor de físicas de Godot (`PhysicsServer3D`) para disparar rayos asíncronos y calcular distancias a obstáculos para atenuación y difracción.

**5. Servidor de Live Update y Protocolo de Comunicación**

* **Servidor TCP/WebSockets Embebido:** Hilo secundario en el motor que reciba actualizaciones de parámetros, curvas, volúmenes de bus e inserciones de efectos en caliente desde una herramienta de edición externa sin detener el juego.
* **Monitor de Telemetría (Profiler Backend):** Recopilador de estadísticas en tiempo real (conteo de voces físicas activas, voces virtuales, consumo de memoria de bancos y tiempo de procesamiento DSP) exportables hacia un cliente de visualización.