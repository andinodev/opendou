FMOD divide su ecosistema en tres capas principales: la herramienta de autoría visual (**FMOD Studio**), el motor de eventos de alto nivel (**Studio API**) y el motor de procesamiento de señales y DSP de bajo nivel (**Core API**).

**1. Arquitectura de Niveles de API**

* **FMOD Core API (Bajo Nivel):** Motor de audio C/C++ ultraoptimizado con gestión directa de *Channels*, *ChannelGroups*, búferes circulares y un grafo de nodos DSP totalmente libre y reconfigurable en tiempo de ejecución.
* **FMOD Studio API (Alto Nivel):** Capa orientada a objetos desacoplada de los archivos de audio físicos. Maneja la reproducción mediante eventos (`EventDescription`, `EventInstance`), parámetros, carga asíncrona de bancos y persistencia de memoria.
* **Grafo DSP Modular:** Permite insertar, encadenar y crear procesadores de señal personalizados o *plugins* de terceros (como VST, Steam Audio o Dolby Atmos) en cualquier punto de la cadena de mezcla.

**2. Sistema de Eventos e Instrumentos**

* **Eventos:** Contenedores auto-contenidos que encapsulan la lógica de reproducción, modulación, efectos DSP y espacialización de un sonido o conjunto de sonidos.
* **Línea de Tiempo y Automatización:** Pistas de audio multipista similares a un DAW donde el volumen, tono, cortes de filtro y envíos se automatizan mediante curvas sobre el tiempo o sobre parámetros.
* **Tipos de Instrumentos:**
* *Single Instrument:* Reproducción de un clip directo con fundidos de entrada/salida.
* *Multi Instrument:* Selección aleatoria, secuencial o ponderada (*weighted*) con variaciones automáticas de tono y volumen para evitar fatiga auditiva.
* *Scatterer Instrument:* Generador granular/ambiental que distribuye muestras en el espacio 3D y en intervalos de tiempo aleatorios.
* *Programmer Instrument:* Disparador dinámico controlado por código para inyectar pistas de diálogo localizadas en tiempo de ejecución.
* *Silence/Command Instrument:* Emisión de comandos internos (detener otros eventos, disparar snapshots, modular parámetros globales).



**3. Parámetros y Modulación (RTPC)**

* **Parámetros Continuos y Discretos:** Variables expuestas al motor del juego (*float*, *int*, *enum*) para alterar el comportamiento del audio en tiempo real (velocidad, salud, nivel de alerta).
* **Parámetros Automáticos Integrados:** FMOD calcula y actualiza internamente valores de física/espacio: distancia al oyente, ángulo direccional (*event cone*), elevación respecto al plano, velocidad relativa y orientación.
* **Moduladores Nativos:**
* *AHDSR (Attack, Hold, Decay, Sustain, Release):* Envolventes para transiciones orgánicas.
* *Random / Jitter:* Variaciones estocásticas por cada disparo.
* *LFO (Low Frequency Oscillator):* Modulación periódica continua (senoidal, cuadrada, triangular).



**4. Gestión de Voces y Virtualización (*Voice Stealing*)**

* **Virtual Voice System:** Cuando una fuente de audio se vuelve inaudible (por baja prioridad, atenuación por distancia o límite de polifonía), FMOD la degrada a una "voz virtual". La pista sigue avanzando en tiempo sin consumir recursos de decodificación de CPU ni memoria DSP, y se reactiva físicamente si vuelve a estar dentro del rango.
* **Límites de Polifonía e Instanciación:** Restricciones configurables por evento o categoría (ej. máximo 8 impactos simultáneos).
* **Comportamiento de Robo (*Stealing Behavior*):** Algoritmos deterministas para liberar canales: *Quietest* (robar el más silencioso), *Oldest* (el más antiguo), *Furthest* (el más lejano), *Lowest Priority* (menor prioridad) o *Fail to Play* (ignorar el nuevo sonido si no hay canales).

**5. Mezclador, Enrutamiento y Snapshots**

* **Jerarquía de Buses y VCA:** Estructura en árbol de buses con soporte de canales VCA (*Voltage Controlled Amplifiers*) para escalar ganancias de grupos independientes de la jerarquía de mezcla.
* **Snapshots (Estados de Mezcla):** Guardan configuraciones de volumen, efectos y filtros de toda la mesa de mezcla. Se aplican de forma aditiva o excluyente con curvas de transición (*tweening*), ideales para efectos de aturdimiento (*concussion*), menús de pausa o transiciones bajo el agua.
* **Envíos de Retorno (Sends/Returns) y Sidechaining:** Enrutamiento auxiliar para efectos compartidos y compresión dinámica cruzada (bajar la música automáticamente cuando suena un diálogo).

**6. Espacialización, Oclusión y Acústica 3D**

* **Modelos de Atenuación 3D:** Curvas personalizadas de caída de volumen (*Logarithmic*, *Linear-Squared*, *Inverse*).
* **FMOD Geometry API:** Permite pasar mallas de colisión del juego a FMOD para calcular oclusión y difracción acústica poligonal en tiempo real sin requerir trazado de rayos pesado.
* **Integración con Spatialize Plugins:** Soporte nativo para audio binaural basado en HRTF (Google Resonance, Oculus Spatializer, Steam Audio).

**7. Música Interactiva y Cuantización**

* **Marcadores de Sincronización:** Definición de compás, tempo (BPM) y cambios de métrica en la línea de tiempo.
* **Regiones de Transición Cuantizadas:** Capacidad de saltar entre secciones musicales únicamente en el siguiente compás (*bar*), tiempo (*beat*) o semicorchea, garantizando cambios fluidos sin romper el ritmo.

**8. Pipeline de Empaquetado y Bancos (*Soundbanks*)**

* **Formato FSB (FMOD Sound Bank):** Contenedor binario optimizado con compresión propietaria (FADPCM para baja CPU, Vorbis para alta compresión, AT9/XMA para hardware de consolas).
* **Separación de Metadatos y Audio:** Los bancos de metadatos (lógica y curvas, muy ligeros) se cargan al inicio, mientras que los bancos de muestras (*sample data*) se cargan o descargan bajo demanda de forma síncrona o asíncrona.
* **Bancos de Localización:** Reemplazo dinámico de archivos de voz según el idioma seleccionado sin duplicar la lógica de eventos.

**9. Live Update y Profiling (Monitoreo en Vivo)**

* **Conexión TCP en Tiempo Real:** Permite conectar la herramienta FMOD Studio al juego ejecutándose (en PC, móvil o consola) para ajustar volúmenes, ecualizaciones, curvas y añadir efectos en vivo sin reiniciar el juego ni recompilar.
* **FMOD Profiler:** Grabación y visualización gráfica del consumo de CPU por hilo de audio, memoria asignada, conteo de voces físicas/virtuales, eventos activos y advertencias de rendimiento (*buffer underruns*).