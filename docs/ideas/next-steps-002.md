Al revisar la UI saltan a la vista varias carencias fundamentales que impiden que este DAW sea funcionalmente persistente.

**Indicadores de Estado y Guardado (State & Persistence)**

* **Falta el Indicador de "Modificado" (Dirty State):** El menú desplegable muestra `Boss_Phase_Orchestral.tres`, pero no hay un asterisco (`*`) que alerte al usuario de que el recurso tiene cambios sin guardar en RAM.
* **Ausencia de Botón de Guardado (💾):** En la barra superior, junto al selector de recursos, debe existir un botón de guardar (atajo `Ctrl+S`). Godot necesita que tu plugin llame explícitamente a `ResourceSaver.save()` o notifique al `EditorInterface` que el recurso cambió, de lo contrario, al cambiar de pestaña (al Graph), el motor recarga la versión en disco y destruye tu progreso.
* **Caché de Pestañas (Tab State):** La UI no está serializando el estado visual. Si cambias al *Graph* y vuelves al *Music DAW*, cosas como el nivel de Zoom (100%), el cabezal de reproducción y la capa seleccionada deberían restaurarse a como las dejaste.

**Gestión de Pistas y Archivos (Track CRUD)**

* **Falta UI para Añadir/Eliminar Pistas:** No hay ningún botón `[ + Add Track ]` o un icono de papelera. Las cuatro pistas parecen "esculpidas en piedra". Un usuario no tiene por dónde empezar para agregar un `Layer 5: Choirs`.
* **Falta de Asignación de Audio (Clip Assignment):** Las pistas dibujan la forma de onda, pero en ninguna parte de la cabecera (*Track Header*) ni sobre el clip mismo hay un botón de "Cargar Archivo" (icono de carpeta) o un campo de texto que muestre la ruta del archivo `.wav` que se está leyendo. Si quieres cambiar el bajo sigiloso por otro archivo, visualmente no hay dónde hacer clic.

**Navegación y Prevención de Errores**

* **Deshacer/Rehacer (Undo/Redo):** No hay botones de $\curvearrowleft$ y $\curvearrowright$ en la barra superior. En un DAW, mover un parámetro por accidente puede arruinar una mezcla. El plugin debe estar conectado al objeto `UndoRedo` del editor de Godot para registrar cada cambio de volumen o ajuste de BPM.
* **Ausencia Total de Scrollbars:** Como se intuyó antes, el lienzo musical no tiene barras de desplazamiento (ni horizontales ni verticales). Además, en el extremo derecho de tu captura se asoma un pedazo cortado de otra interfaz (parece ser el panel flotante colapsado), lo que indica problemas con los `MarginContainer` de Godot.

**Herramientas de Edición de Clips**

* **Falta UI de Recorte (Trim/Loop):** Los clips ocupan toda la línea de tiempo. Si un diseñador arrastra un archivo de audio al lienzo, debería poder agarrar los bordes del clip para acortarlo o repetirlo visualmente, y eso requiere tiradores o *handles* en las esquinas de los bloques de audio.

Para solucionar la pérdida de datos al cambiar de pestaña, necesitas interceptar la señal `tab_changed` o el botón de navegación en tu plugin de GDScript, y lanzar un cuadro de diálogo nativo: *"¿Deseas aplicar los cambios al recurso Boss_Phase_Orchestral.tres antes de cambiar de vista?"*.

----

Por otro lado, aunque el **Music DAW** de OpenDou ha alcanzado un estándar visual y funcional altísimo, al compararlo con los sistemas de Música Interactiva de Wwise y FMOD, emergen varias ausencias estructurales críticas para la composición no lineal avanzada.

**Sub-Pistas Aleatorias (Multi-Instrument / Random Tracks)**
Actualmente, las capas (ej. `Layer 3: Combat_Drums`) contienen un único archivo de audio estático. En Wwise, cada capa (*Music Track*) puede contener múltiples *Sub-Tracks* (variaciones de percusión, distintos *fills*). En cada repetición del bucle, el motor selecciona aleatoriamente una variación diferente. Sin este sistema, un bucle de combate de 8 compases causará fatiga auditiva rápidamente, por más que la intensidad general varíe.

**Marcadores Personalizados y Colas de Transición (Cues & Tails)**
El sistema actual cuantiza las salidas basándose estrictamente en la cuadrícula (`Next Bar`, `Next Beat`). Wwise y FMOD utilizan marcadores personalizados inyectados en la línea de tiempo:

* **Pre-Entry Cues:** Permite que un segmento comience a reproducirse un poco antes de su compás inicial real para acomodar notas de anticipación (anacrusas o *pickups*).
* **Post-Exit Tails:** Al saltar de un segmento a otro, la cola de reverberación o el platillo final del primer segmento debe seguir sonando (desbordarse) sobre el segundo segmento. El *crossfade* simple de OpenDou corta abruptamente estas colas naturales de los instrumentos.

**Automatización de Parámetros en la Línea de Tiempo**
FMOD brilla por permitir dibujar curvas de automatización directamente debajo de las pistas de audio. Actualmente tienes un fader de `Intensity`, pero no hay forma visual de vincular esa variable a un filtro pasa-bajos (LPF) en la pista `Stealth_Bass`. Falta un carril desplegable por pista para mapear parámetros RTPC a efectos DSP específicos mediante curvas de interpolación.

**Lógica de Playlists (Secuenciadores de Segmentos)**
El editor actual muestra cómo editar un segmento individual (`Boss_Phase_Orchestral`). Falta la capa superior arquitectónica: un **Gestor de Playlists** que defina el flujo lógico (ej. reproducir `Intro` una vez $\rightarrow$ reproducir `Loop_A` aleatoriamente entre 2 y 4 veces $\rightarrow$ transicionar a `Loop_B`).

**Soporte MIDI y Sintetizadores Nativos**
Mencionaste que OpenDou posee un `AudioSynthesizer` procedimental. Wwise permite pistas MIDI en su secuenciador musical para disparar estos sintetizadores nativos en tiempo real. Reproducir patrones de notas MIDI en lugar de archivos `.wav` de 16 bits reduce el consumo de memoria RAM de un banco musical de varios megabytes a unos pocos kilobytes, algo vital para dispositivos móviles.

**Ruteo de Salida Individual por Pista**
Las cabeceras actuales tienen controles de volumen y *Solo/Mute*, pero carecen de un selector de ruteo de bus. Para aplicar *sidechain* o compresión paralela agresiva, el diseñador debe poder enviar la pista `Combat_Drums` a un sub-bus de percusión independiente del `Ambient_Pads` antes de llegar al *Master Output*.

¿Consideras que deberíamos diseñar la integración de los **Marcadores (Pre-Entry/Post-Exit)** primero para perfeccionar las transiciones, o priorizar las **Sub-Pistas Aleatorias** para evitar la fatiga auditiva?