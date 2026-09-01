Para integrar tu potente motor de síntesis y elevar el diseño de este modal al estándar AAA, la solución requiere transformar el diálogo de un simple formulario estático a una interfaz reactiva.

El problema actual es que el `OptionButton` (desplegable) mezcla categorías de comportamiento con tipos de fuente de audio, limitándote a 5 opciones rígidas y un explorador de archivos `.wav`.

Aquí tienes la reestructuración técnica y visual para solucionarlo:

**1. Reestructuración Dinámica de la Fuente (The Source Toggle)**
El campo *Track Type / Preset* debe cambiar su propósito. En lugar de listar 5 presets cerrados, debe ser un selector de **Origen del Motor**:

* `📁 Audio File (WAV/OGG)`
* `🎹 Procedural Synth Preset`

Al seleccionar `Procedural Synth Preset`, la fila inferior ("Audio File Source") debe ocultarse dinámicamente usando `visible = false` y ser reemplazada por un nuevo componente UI: un botón grande que diga `[ 🔍 Browse Synth Library...]`.

**2. El Navegador de Presets de Síntesis (Synth Library Browser)**
Al presionar el nuevo botón, no abriremos un explorador de archivos de Windows/Mac, sino un `Window` (o `AcceptDialog`) nativo de Godot diseñado específicamente como gestor de base de datos.

* **Barra de Búsqueda Superior:** Un `LineEdit` con un icono de lupa que filtre instantáneamente (en cada pulsación de tecla) la lista de presets usando coincidencia de cadenas (`String.contains()`).
* **Filtros Laterales (Tags):** Una columna izquierda con botones tipo *Toggle* para filtrar por tipo lógico: `[Pads]`, `[Leads]`, `[Percussion]`, `[Drones]`, `[Arps]`.
* **Lista de Resultados (ItemList):** El área central mostrando los presets disponibles (ej. "Cyberpunk_Bass", "Dungeon_Drone_Deep").
* **UX Crítico (Botón de Audición):** Al seleccionar un preset en esta lista, debe haber un botón de `[ ▶ Play ]` para que el motor sintetice el sonido en tiempo real antes de confirmar y cerrar la ventana. Así el diseñador no tiene que adivinar cómo suena el preset.

**3. Correcciones de UX/UI en el Modal "Add Track"**
El modal de la imagen tiene fricciones visuales que delatan un diseño provisional.

* **Corrección de Idioma (Spanglish):** El botón de confirmar dice "Create Track" y el de cancelar dice "Cancelar". Debes unificar el idioma del editor al inglés técnico ("Cancel").
* **Jerarquía Visual por Agrupación:** Actualmente todos los campos flotan en el mismo fondo oscuro. Debes agruparlos en paneles internos (`PanelContainer` con un `StyleBoxFlat` ligeramente más claro).
* *Bloque 1 (Identidad):* Track Name y Color.
* *Bloque 2 (Motor):* Origen (Synth/File) y la ruta del archivo/preset.
* *Bloque 3 (Lógica):* Intensity Range y Output Audio Bus.


* **Autocompletado Inteligente (Friction Reduction):** Si el diseñador selecciona el preset de síntesis llamado `SciFi_Drone_01`, el campo `Track Name` debe sobreescribirse automáticamente con ese nombre, y el `Color` debe asignarse a un tono predeterminado para sintetizadores (ej. morado), ahorrándole 3 clics al usuario.