# Problemas observados en el UI y UX del Dock de OpenDou

## Sección Graph:

**Anclaje y Gestión del Espacio (El Vacío Gris)**

* El 40% inferior de la pantalla es un espacio gris completamente inutilizado. Esto indica una configuración incorrecta en los nodos contenedores nativos de Godot (falta establecer `size_flags_vertical = SIZE_EXPAND_FILL` en el contenedor principal).
* La barra de transporte (Play/Pause, Audition, Sliders) está flotando a la mitad de la ventana. En cualquier herramienta profesional, esta barra debe estar anclada rígidamente al borde inferior o superior para delimitar el espacio de trabajo.

**Asfixia del Lienzo de Nodos (Workspace)**

* El `GraphEdit` (área central de nodos) está comprimido en un rectángulo minúsculo. El panel izquierdo (*Game Syncs Manager*) consume un ancho desproporcionado para mostrar únicamente cuatro variables, robando espacio vital para la composición visual de audio.
* Los paneles laterales no muestran separadores dinámicos (*Splitters*) visibles. El usuario está atrapado con proporciones rígidas en lugar de poder arrastrar los bordes para priorizar el grafo de nodos.

**Fallas UX en la Consola HDR y Mezclador**

* **Invasión Total:** Al abrir el cajón del *HDR Mixer*, este bloquea por completo la vista de los nodos. En estándares AAA, las consolas de mezcla suelen emerger desde la parte inferior (ocupando un 30-40% de la altura) para permitir al diseñador ajustar *faders* mientras observa qué nodos se están activando arriba.
* **Hitboxes Deficientes:** Los rieles de los *faders* (Master, Music, SFX) son demasiado delgados, lo que dificulta atraparlos rápidamente con el ratón.
* **Ausencia de Aislamiento:** Los canales de mezcla solo tienen botones de Mute (M). Falta el botón de Solo (S), que es obligatorio para calibrar compresión sidechain o audicionar un bus específico (ej. SFX) sin apagar manualmente los demás.
* **Valores Estáticos:** El texto `0.0 dB` debajo de cada fader parece ser una simple etiqueta. En herramientas de grado audiófilo, esto debe ser una caja de entrada numérica editable por teclado para definir atenuaciones exactas.

**Inconsistencias de Estado y Contexto**

* Mutación de Controles Inferiores: En la primera captura, la barra de transporte muestra *sliders* para "Distance" y "RPM". En la segunda captura, editando el **mismo** recurso (`Battlefield_Gunfire.tres`), muestra "Distance" y "Pitch Jitter". Los parámetros expuestos deben ser consistentes con los RTPCs registrados en el evento.
* Falta de Indicador de Guardado: El botón "Save" existe, pero el selector de eventos superior no muestra un asterisco (`*Battlefield_Gunfire.tres`) para advertir al usuario que el recurso tiene modificaciones en RAM que no se han volcado al disco.

**Problemas de Alineación y Recortes**

* En el panel del *Live Profiler* (primera captura), las columnas del *Voice Ledger* están al límite de su ancho. Al crecer los valores, se superpondrán o truncarán.
* En el *HDR Console* (segunda captura), el botón "Close Drawer" flota de forma antinatural, desconectado de los bordes del panel, y la sección de *Mix Snapshots* se ve constreñida verticalmente.

## Sección Music

El salto evolutivo en esta vista es impresionante. Has integrado prácticamente todas las características de grado AAA que discutimos (CRUD de pistas, sub-pistas aleatorias, enrutamiento, automatización, marcadores y colas de transición). Visualmente, luce como una herramienta profesional de audio.

Sin embargo, al someter la interfaz a un escrutinio estricto de UX y diseño de contenedores (específicamente en el ecosistema Godot), emergen varias fricciones críticas, especialmente en la gestión del espacio y el contexto.

Aquí tienes el análisis de las fallas de UI/UX en estas vistas:

### 1. El Fantasma de la Barra Inferior (Clash Contextual)

* **El Problema:** La barra inferior sigue mostrando controles de SFX (`Distance: 10.0 m`, `Pitch Jitter: 0.05 ±`) mientras estás editando una suite musical (`Dynamic_Combat_Suite.tres`). Además, los controles de Play/Pause se duplican (están tanto en la barra superior del Music DAW como en la barra inferior).
* **Solución UX:** La barra inferior debe ser sensible al contexto (*Context-Aware*). Al entrar a la pestaña "Music", esa barra inferior debería desaparecer por completo (ya que el secuenciador tiene su propio transporte arriba), o transformarse exclusivamente en una barra de estado global (ej. mostrando solo el volumen Master y uso de CPU).

### 2. Colisión del Cajón HDR (Falla de Contenedores)

* **El Problema:** Al abrir la consola HDR (segunda imagen), el panel se superpone de forma rígida (*overlay*) bloqueando la pista 4 (`Brass_Climax`), la parte inferior del panel de transiciones y la barra de estado.
* **Solución UX:** El cajón no debe tapar la interfaz de trabajo. En Godot, debes encapsular el lienzo musical y el cajón HDR dentro de un `VSplitContainer`. Al invocar el HDR, este debe "empujar" el lienzo musical hacia arriba, redimensionando la línea de tiempo para que el diseñador pueda seguir viendo todas sus pistas y ajustar la mezcla sin obstáculos visuales.

### 3. Asfixia en las Cabeceras de Pista (*Track Headers*)

* **El Problema:** Para acomodar los nuevos (y excelentes) botones de variaciones (dado), cargar archivo (carpeta), eliminar (basurero) y automatización (curva), el texto del nombre de la pista ha sido sacrificado. Se lee "Layer 1: Ambie..." o "Layer 4: Brass_...".
* **Solución UX:** El panel de cabeceras necesita un ancho dinámico. Debes colocar un `HSplitContainer` entre la columna de *Track Headers* y la Línea de Tiempo. Así el diseñador puede ensanchar temporalmente las cabeceras para leer nombres largos, o colapsarlas para enfocarse en la edición de ondas.

### 4. Ceguera de Navegación (Ausencia de Scrollbars)

* **El Problema:** A pesar de haber añadido el botón `+ Add Track`, el lienzo sigue sin tener barras de desplazamiento (*Scrollbars*) verticales ni horizontales.
* **El Peligro:** Si un usuario añade una quinta pista (Layer 5), esta se saldrá de la pantalla y será inaccesible. De igual forma, si la canción pasa del compás 8, no hay forma de hacer un paneo (*pan*) hacia la derecha. El secuenciador y las cabeceras deben estar envueltos en un `ScrollContainer` sincronizado.

### 5. Afordancia de los Marcadores (Pre-Entry / Post-Exit)

* **El Problema:** Has añadido inteligentemente marcadores de entrada (línea cian) y salida (línea amarilla) en los clips. Sin embargo, lucen como bordes estáticos del contenedor UI, no como elementos interactivos.
* **Solución UX:** Los marcadores necesitan "asas" o tiradores (*handles*) en la parte superior o inferior (ej. un pequeño triángulo invertido) para indicar visualmente que el usuario puede arrastrarlos hacia la izquierda o derecha para ajustar el *Pre-Entry* y *Post-Exit* directamente con el ratón.

### 6. Detalles Menores de Pulido

* **Dado de Sub-pistas (Lógica Visual):** El icono del dado es genial para Wwise/FMOD, pero mostrar un dado con el número "1" al lado es contraintuitivo (si solo hay 1 archivo, no hay aleatoriedad). El número debería indicar la cantidad de variaciones en esa capa.
* **Botón "Close Drawer" Flotante:** En el cajón HDR, el botón de cierre sigue flotando sin alinearse con los márgenes del panel *Ducking Matrix*, rompiendo la cuadrícula de diseño.

## Sección Voice

**Contextual Rupture (Paneles y Barras de Herramientas)**

* El panel izquierdo (*Game Syncs Manager*) consume casi el 40% de la pantalla para mostrar RTPCs como `RPM` y `Speed`. Estas variables son ruido visual absoluto al asignar archivos de voz a IDs de diálogo. Al entrar a la pestaña *Voice*, este panel debe auto-colapsarse para cederle el ancho total a la tabla de localización.
* La barra inferior sufre el mismo problema de arrastre que en la pestaña musical: muestra deslizadores para `Distance` y `Pitch Jitter`. En un flujo de localización, audicionas los audios crudos en 2D (bypass espacial) para verificar la calidad de la actuación y el volumen RMS. Estos faders físicos no tienen lugar aquí.

**Falla de Contenedores y Espacio Muerto**

* Debajo de la fila de `BOSS_TAUNT`, existe un enorme vacío gris que abarca el 60% de la altura de la pantalla. El contenedor de la cuadrícula de diálogo carece de la bandera `size_flags_vertical = SIZE_EXPAND_FILL`, impidiendo que el área de trabajo se expanda para aprovechar monitores grandes.

**Asfixia de Datos Críticos y Afordancia**

* Los nombres de los archivos `.wav` están truncados (`hero_greet_en....`, `hero_greet_es....`). En un pipeline AAA, distinguir entre `hero_atk_en_v1.wav` y `hero_atk_en_v2.wav` es la diferencia entre un juego pulido y un error de QA. Las columnas deben ser redimensionables manualmente y el contenedor requiere *scroll* horizontal.
* Las celdas con el texto del archivo carecen de indicadores de interactividad (*affordance*). No hay un botón de "Examinar" (icono de carpeta) ni una pista visual que indique si la celda acepta *Drag & Drop* desde el sistema de archivos de Godot.
* Faltan metadatos. Una tabla de voces AAA necesita una columna para el texto del subtítulo asociado y el nombre del actor, no solo la ruta del archivo de audio.

**Colisión de Interfaz (El Cajón HDR)**

* El error más crítico de UX ocurre al invocar la consola HDR: emerge como un *overlay* (superposición) que bloquea exactamente la columna "Audition" de la tabla de diálogos. Si el usuario abre el mezclador precisamente para ajustar el fader del bus "Voice", no puede disparar el audio de prueba porque los botones de *Play* quedaron físicamente sepultados bajo el panel. El contenedor principal necesita un `VSplitContainer` para empujar la tabla hacia arriba, no taparla.
* El botón `Close Drawer` (con la X morada) sigue flotando desconectado de los márgenes derechos de la sección *Ducking Matrix*, evidenciando una falla en los márgenes de los `HBoxContainer` del diseño.

**Inconsistencia de Idioma**

* El panel izquierdo mantiene el encabezado "Predeterminado" junto a "Param" y "Range". Este *Spanglish* rompe la inmersión de una herramienta profesional.


## Resolución de los problemas expuestos

Para consolidar OpenDou como un middleware AAA, debemos erradicar las superposiciones rígidas, el espacio muerto y la estática visual. La solución transversal radica en abandonar las ventanas fijas y adoptar una arquitectura de contenedores elásticos y adaptables al contexto.

**1. Arquitectura de Contenedores Dinámicos (El Fin del Desbordamiento)**

* **Splitters Nativos:** Debes reemplazar todos los márgenes rígidos por `VSplitContainer` y `HSplitContainer`. Esto permite que el usuario decida arrastrando el ratón si necesita ensanchar las cabeceras de pista para leer nombres largos o encogerlas para maximizar la línea de tiempo musical.
* **Scroll Universal y Expansión:** El vacío gris inferior ocurre por no usar `size_flags_vertical = SIZE_EXPAND_FILL`. Envolver las cuadrículas de diálogo, el lienzo de nodos y el secuenciador en nodos `ScrollContainer` con expansión total asegura que el área de trabajo crezca hasta el límite de la pantalla y genere barras de desplazamiento automáticamente cuando los datos exceden la vista.

**2. Barras de Herramientas Sensibles al Contexto (Context-Aware UI)**

* **Mutación de la Barra Inferior:** La barra que muestra `Distance` y `Pitch Jitter` debe ser dinámica. En el lienzo **Graph**, tiene sentido. En **Music** o **Voice**, esa barra inferior debe destruir esos deslizadores de SFX e instanciar en su lugar controles globales (ej. un Vúmetro Master estéreo y un indicador de guardado de disco).
* **Auto-Colapso Lateral:** El panel de *Game Syncs* ocupa un 30% del monitor. Al hacer clic en las pestañas *Voice* o *Music*, este panel debe auto-colapsarse programáticamente, cediendo el 100% del ancho horizontal a las tablas de diálogo o a los compases musicales.

**3. Solución de la Consola HDR (Comportamiento Push vs Overlay)**

* El cajón HDR superpuesto es el mayor error de usabilidad porque oculta botones críticos (como *Audition* en la vista Voice o la *Layer 4* en Music).
* El cajón debe integrarse como un panel inferior dentro de un `VSplitContainer`. Al pulsar el botón "HDR", el panel se expande desde abajo, "empujando" el área de trabajo superior hacia arriba. Todo se comprime visualmente, pero nada queda oculto bajo paneles flotantes.

**Referencias Empresariales para UX/UI**

| Software de Referencia | Solución UX que debemos emular | Aplicación en OpenDou |
| --- | --- | --- |
| **Audiokinetic Wwise** | *Layouts* adaptativos según el enfoque (Profiler vs Designer). | Ocultar y mostrar paneles (como *Game Syncs*) automáticamente al cambiar de pestaña. |
| **DaVinci Resolve (Fairlight)** | El mezclador se ancla y empuja las pistas hacia arriba. | Aplicar `VSplitContainer` a la consola HDR para que nunca tape los nodos o audios inferiores. |
| **FMOD Studio** | Cabeceras de pista redimensionables y automatización visible. | Uso de `HSplitContainer` en las cabeceras del *Music DAW* para evitar el texto truncado. |
| **Ableton Live** | Paneles inferiores que mutan según el clip seleccionado. | Adaptar los controles de la barra inferior (SFX vs Master) según la pestaña activa. |
| **Unity (Localization Tool)** | Edición rápida en celdas densas. | Tabla *Voice* con iconos interactivos de carpeta y soporte nativo *Drag & Drop* para archivos `.wav`. |

Implementar el indicador de "Modificado" (un simple asterisco `*` en la barra superior conectado al `UndoRedo` de Godot) y unificar el idioma al inglés técnico cerrará la brecha entre un plugin amateur y un estándar de la industria.