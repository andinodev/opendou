El ecosistema de Wwise (Audiokinetic) es el estándar técnico predominante en producciones AAA. Se fundamenta en una separación estricta entre el diseño de estructuras de sonido lógicas (**Actor-Mixer Hierarchy**), el enrutamiento de mezcla (**Master-Mixer Hierarchy**), la lógica musical (**Interactive Music**) y la integración en el juego mediante llamadas directas a eventos y sincronizaciones (**Game Syncs**).

**1. Arquitectura del Núcleo (`AK::SoundEngine`)**

* **Motor C++ Modular:** Arquitectura de bajo nivel de alto rendimiento con ejecución desacoplada por hilos (hilo de audio, hilo de lectura de disco/bancos y cola de comandos del juego).
* **Gestión de Memoria Fija:** Permite reservar *pools* de memoria física con límites estrictos, evitando asignaciones dinámicas (`malloc`) durante la ejecución para garantizar cero fragmentación de RAM.
* **Extensibilidad por Plugins:** API abierta para crear generadores DSP, efectos de inserción, mezcladores de bus y motores de renderizado espacial propietarios.

**2. Jerarquía de Objetos y Contenedores (Actor-Mixer Hierarchy)**

* **Sound SFX / Sound Voice:** Unidad fundamental de audio para efectos o voces dobladas.
* **Random Container:** Selección aleatoria de clips con listas de exclusión de repetición (*shuffle*) o totalmente libres (*standard random*), con variación estocástica de tono, volumen y filtro por cada disparo.
* **Sequence Container:** Reproducción ordenada y secuencial de una lista de elementos (paso 1, paso 2, paso 3).
* **Switch Container:** Contenedor condicional que cambia el contenido reproducido según el estado de un parámetro del juego (por ejemplo, el tipo de superficie en pasos: madera, grava o agua).
* **Blend Container:** Reproducción y mezcla simultánea de múltiples capas o subcontenedores mediante curvas de fundido cruzado ligadas a parámetros RTPC (ej. sonido de motor modulando capas de RPM bajas, medias y altas simultáneamente).

**3. Sistema de Game Syncs (Sincronización de Juego)**

* **RTPC (Real-Time Parameter Controls):** Variables flotantes continuas enviadas por el juego para controlar casi cualquier propiedad en el motor de audio (volumen, frecuencias de corte, *spread* espacial, tiempos de reverberación).
* **States (Estados Globales):** Variables globales del contexto del juego (ej. `GameState = InGame`, `Paused`, `PlayerDead`, `LowHealth`). Aplican transiciones suaves a buses o capas completas.
* **Switches (Interruptores Locales):** Variables discretas asociadas a una entidad u objeto específico del juego (ej. `Surface_Type`, `Weapon_Type`, `Armor_Material`).
* **Triggers:** Disparadores puntuales para eventos musicales o aguijones (*stingers*).

**4. Paradigma de Eventos Basado en Acciones**

* A diferencia de FMOD (donde el evento es el contenedor del sonido), en Wwise un **Event** es una lista ejecutable de acciones dirigida a objetos o buses.
* **Tipos de Acciones:** *Play*, *Stop*, *Pause*, *Resume*, *Mute*, *Unmute*, *Set Volume*, *Set Pitch*, *Set Switch*, *Set State*, *Enable/Disable Bypass*, *Post Trigger*, *Break*, *Seek*.
* Permite que un único evento del programador (ej. `Fire_Weapon`) desencadene sonidos, interrumpa ruidos anteriores, reduzca el volumen de otros buses y aplique un filtro sin cambiar una sola línea de código del juego.

**5. Jerarquía de Mezcla y HDR Audio (Master-Mixer Hierarchy)**

* **Buses de Audio y Buses Auxiliares:** Estructura en árbol jerárquica con herencia de efectos, volumen y paneo.
* **Buses de Control (Control Buses / Auxiliary Sends):** Rutas para reverberaciones y efectos de entorno compartidos asignados estática o dinámicamente por posición.
* **HDR Audio (High Dynamic Range):** Sistema de compresión/ducking psicoacústico automático basado en un umbral dinámico de sonoridad. Cuando ocurre un sonido extremadamente fuerte (una explosión), el sistema baja automáticamente y en tiempo real el rango audible relativo de los sonidos más silenciosos (pasos, grillos), simulando la adaptación del oído humano sin compresión de banda rígida.
* **Auto-Ducking:** Reducción automática de ganancia de buses específicos ante la presencia de señal en otro bus (ej. reducir efectos y música al entrar diálogos).

**6. Virtual Voice System y Gestión de Instancias**

* **Modos de Voz Virtual Avanzados:**
* *Play from beginning:* Reinicia la muestra al volver a ser audible.
* *Play from elapsed time:* Continúa el avance lógico del tiempo y retoma la muestra en la posición exacta.
* *Resume:* Pausa y reanuda donde quedó.
* *Kill voice:* Descarta la instancia permanentemente.


* **Prioridad con Compensación por Distancia:** Permite asignar una prioridad base (1-100) que se degrada o aumenta dinámicamente según la distancia entre el emisor y el oyente (*Priority Offset*).
* **Límites de Instancias Globales y por Objeto:** Restricción rígida de polifonía por entidad o por tipo de sonido con comportamientos configurables (*Discard oldest*, *Discard lowest priority*).

**7. Jerarquía de Música Interactiva (Interactive Music Hierarchy)**

* **Estructuras Musicales:** *Music Track*, *Music Segment*, *Music Playlist Container* y *Music Switch Container*.
* **Matriz de Transiciones (Transition Matrix):** Reglas detalladas para saltar de cualquier sección musical A a una sección B, permitiendo definir el punto de salida (inmediato, en el siguiente golpe de compás, al final del compás o en el siguiente marcador), el puente musical (*transition segment*) y el punto de entrada con fundidos cruzados.
* **Stingers dinámicos:** Inserción de notas o fragmentos de tensión sincronizados con la métrica del compás actual.

**8. Wwise Spatial Audio y Simulación Acústica**

* **Rooms and Portals:** Modelo acústico para interiores/exteriores. Conecta habitaciones cerradas mediante portales (puertas/ventanas) para calcular automáticamente propagación del sonido, atenuación y difracción sin necesidad de trazados de rayos pesados.
* **Wwise Reflect:** Cálculo geométrico en tiempo real de reflexiones tempranas (*early reflections*) basado en las mallas de colisión del entorno.
* **Difracción Geométrica:** Simula cómo las ondas de sonido bordean esquinas y obstáculos físicos.
* **Formatos Inmersivos:** Soporte nativo para *Ambisonics* de orden superior, Dolby Atmos, Sony 3D Audio y salidas de canal basadas en objetos.

**9. Síntesis Procedural y Herramientas Especializadas**

* **Wwise SoundSeed:** Generadores de audio procedural que reducen el tamaño de memoria:
* *SoundSeed Air:* Generación de viento, turbulencia y flujos de aire sin usar archivos de audio.
* *SoundSeed Impact:* Resintetizador modal para golpes y colisiones.
* *SoundSeed Grain:* Síntesis granular en tiempo real.


* **Wwise Motion:** Integración de háptica que convierte señales de audio o fuentes dedicadas directamente en vibraciones complejas para mandos (DualSense, Xbox Controllers) y periféricos táctiles.

**10. SoundBanks y Estrategias de Carga**

* **Bancos Basados en Eventos (Event-Based Packaging):** Generación automática de bancos donde los assets se empaquetan y cargan automáticamente al referenciar un evento.
* **Prefetch Length (Zero-Latency Streaming):** Carga los primeros milisegundos de un archivo de audio directamente en RAM para disparo instantáneo, mientras el resto de la pista se lee en segundo plano desde el disco.
* **Localización Dinámica:** Reemplazo atómico de bancos de diálogo por idioma sin duplicar las definiciones de eventos ni estructuras de datos.

**11. Profiling y Automatización (WAAPI)**

* **Wwise Profiler:** Registro paso a paso (*timeline capture*), seguimiento gráfico del grafo de voces físicas/virtuales, medidores de nivel por bus, consumo de memoria por *pool* y registro de llamadas API en vivo.
* **WAAPI (Wwise Authoring API):** Interfaz completa sobre WebSockets/JSON para automatizar el editor de Wwise externamente desde scripts de Python, C# o herramientas internas de integración continua (creación de eventos, importación masiva de WAVs y compilación de bancos).