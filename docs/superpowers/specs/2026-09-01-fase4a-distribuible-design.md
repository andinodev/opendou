# Fase 4A — Distribuible y honesto

**Fecha:** 2026-09-01
**Estado:** Diseño aprobado, pendiente de plan de implementación
**Rama:** `main` (este proyecto trabaja en una sola rama)
**Godot verificado:** 4.7.2.stable.official.ed1daf0bf
**Fases anteriores:** [Fase 1](2026-09-01-fase1-cadena-audio-real-design.md) · [Fase 2](2026-09-01-fase2-correccion-espacial-design.md) · [Fase 3](2026-09-01-fase3-rendimiento-design.md)

---

## 1. Contexto

Las fases 1 a 3 hicieron que el motor suene, que la geometría sea correcta y que el
pipeline de bancos produzca audio. Esta fase se ocupa de que el addon **se pueda
instalar en otro proyecto** y de que deje de afirmar cosas que no cumple.

### La partición de la Fase 4

La observación 19 (namespace global) implica tocar unos 115 archivos y es del tamaño
de una fase por sí sola. Se separa:

- **Fase 4A, este documento:** observaciones 16, 17, 18, 20, 21, 22 y el resto de la 24.
- **Fase 4B, con su propia spec:** observación 19, la limpieza del namespace.

Así el riesgo del renombrado masivo queda aislado, con la suite en verde antes y después.

### Tres correcciones al análisis original

Al medir el estado real, tres de estas observaciones resultaron **menos graves de lo
que el análisis afirmaba**. Queda escrito porque la spec no debe heredar un diagnóstico
inflado:

| Observación | Lo que decía el análisis | Lo que se midió |
|---|---|---|
| **17** | «Escrituras a `res://` que fallan en builds exportadas» | `save_presets`, `save_syncs_to_disk` y `save_to_disk` **solo las llama el editor**. Escribir en `res://` desde el editor es correcto: así se autoran datos de proyecto. No hay ninguna ruta de escritura alcanzable en un export. |
| **16** | «Copiar el addon rompe Game Syncs, presets y suites musicales» | `acoustic_material_registry` tiene sus valores por defecto **en código**, y `music_player` tiene **pistas sintéticas de reserva**. El addon degrada, no se rompe. |
| **21** | «`.gitignore` ignora `*.import`» | Correcto, y **peor de lo dicho**: existen 16 archivos `.import` reales para los 16 iconos SVG, y al no versionarse quien clone obtiene UIDs regenerados. |

---

## 2. Hechos verificados contra Godot 4.7.2

| Hecho | Verificación |
|---|---|
| Un `class_name` con `@icon` **ya queda registrado con su icono** | `ProjectSettings.get_global_class_list()` devuelve `OpenDouEventPlayer3D` con `icon = res://addons/opendou/icons/icon_event_player_3d.svg`. Retirar `add_custom_type` no pierde nada. |
| El registro global es **consultable desde tests** | `ProjectSettings.get_global_class_list()` existe y reporta **197 entradas** en este proyecto. Es la cifra del propio motor, más precisa que contar `class_name` con grep. |
| `EditorInterface` es un singleton en 4.7 | `Engine.has_singleton("EditorInterface")` devuelve `true`. `get_editor_interface()` está deprecado desde 4.2. |
| Hay **16 archivos `.import`** sin versionar | Uno por cada uno de los 16 iconos SVG del addon. `.gitignore:4` los excluye. |
| `synth_preset_registry.load_presets()` **degrada en silencio** | Devuelve `false` sin aviso si el archivo no existe. El desplegable sale vacío y el usuario no sabe por qué. |

### Baseline al empezar

`547/547 PASSED`, cero `SCRIPT ERROR`, fugas **593** (techo en `tests/leak_budget.txt`),
árbol de git limpio.

---

## 3. El addon se vuelve autocontenido

### 3.1 El problema real

El addon lee cuatro archivos JSON desde `res://` con **siete rutas hardcodeadas** en
seis archivos distintos. Los defectos concretos son tres:

1. **Degradación silenciosa.** Si falta el JSON de presets de síntesis, el desplegable
   del inspector sale vacío sin explicación.
2. **Contenido del addon viviendo en la raíz del proyecto.** Los 82 KB de presets de
   síntesis son parte del producto, no datos del usuario: copiar `addons/opendou/` a
   otro proyecto te deja sin ninguno.
3. **Sin punto único de resolución.** Un proyecto no puede reubicar esos archivos.

### 3.2 `OpenDouDataPaths`

Un resolutor con precedencia explícita:

1. **Override del proyecto:** `res://opendou_<nombre>.json`, si existe.
2. **Default del addon:** `res://addons/opendou/data/<nombre>.json`, si existe.
3. **Default en código:** lo que ya hace cada consumidor.

Es el patrón estándar de un addon: envía sus defaults, el usuario los sobreescribe en
su proyecto. Las siete rutas hardcodeadas pasan a pedir su ruta al resolutor.

### 3.3 Qué se mueve y qué no

**Se mueve al addon:** `opendou_synth_presets.json` → `addons/opendou/data/synth_presets.json`.
Es contenido del addon. Se **mueve**, no se copia: dos copias de 82 KB en el repo serían
peores que una. El panel del editor sigue guardando en `res://opendou_synth_presets.json`,
que pasa a ser el override del proyecto.

**No se envía JSON de materiales acústicos.** `acoustic_material_registry` ya tiene sus
coeficientes en código, y un duplicado en JSON sería peor que el código: dos fuentes de
verdad para lo mismo. El resolutor devolverá el override del proyecto si existe.

**`opendou_syncs.json` y `opendou_music_suites.json` se quedan donde están**, como datos
de este proyecto. El addon ganará sus equivalentes en `addons/opendou/data/` con la
estructura mínima que sus lectores esperan —`{"rtpcs": {}, "switches": {}, "states": {}}`
para los syncs y `{}` para las suites— de modo que una instalación limpia resuelva a un
archivo válido en lugar de a ninguno.

### 3.4 Diagnósticos

Donde hoy se degrada en silencio, se emite un `push_warning()` que **nombra el archivo
que falta y qué se pierde**. No basta con avisar: hay que decir qué consecuencia tiene, o
el aviso es ruido.

### 3.5 La observación 17 pasa a ser una guarda, no un descarte

Se midió que ninguna escritura a `res://` es alcanzable en runtime, así que no hay nada
que arreglar. Pero **dejarla sin verificación significa que un cambio futuro podría
introducir una y nadie lo notaría**, que es exactamente la clase de regresión silenciosa
que este proyecto lleva tres fases eliminando.

Se añade una guarda estática: un test que lee los archivos de `addons/opendou/runtime/` y
`addons/opendou/nodes/` y falla si encuentra un `FileAccess.open` en modo escritura junto
a un literal `res://`. Un export no puede escribir en `res://`, así que esa combinación en
código de runtime es siempre un defecto.

---

## 4. Registro de tipos, main screen, `.import` y documentación

### 4.1 Observación 18 — doble registro de tipos

Los 15 nodos se registran dos veces: por `class_name` y por `add_custom_type()`. El
resultado son entradas duplicadas en el diálogo «Crear nodo», y los nodos añadidos por
`add_custom_type` **pierden su tipo al guardar** (se serializan como tipo base más
script), que es la limitación conocida de esa API.

Se retira `add_custom_type()` y su `remove_custom_type()`. La verificación lo respalda:
`OpenDouEventPlayer3D` ya está en el registro global **con su icono resuelto**, así que
el diálogo no pierde nada.

Es verificable en headless: la suite puede afirmar que los 15 nodos siguen en
`get_global_class_list()` con un icono no vacío.

### 4.2 Observación 20 — main screen y API deprecada

`_has_main_screen()` devuelve `true` y el plugin nunca añade nada al contenedor de main
screen: pulsar la pestaña «OpenDou» deja la pantalla vacía y abre una ventana flotante.

**Decisión:** devolver `false`. El Studio se queda en el panel inferior con su ventana
desacoplable, que es el flujo que el autor construyó deliberadamente (`detach_and_maximize`,
botón «Dock Back to Editor»). Desaparece una pestaña que no lleva a ninguna parte, y el
docstring del plugin deja de decir «Main Screen workspace».

`get_editor_interface()`, deprecado desde 4.2, pasa al singleton `EditorInterface`.

### 4.3 Observación 21 — archivos `.import`

Se quita `*.import` de `.gitignore` y se versionan los 16 archivos de los iconos. En
Godot 4 esos archivos contienen el UID y los ajustes de importación del recurso: sin
versionarlos, cada clon regenera UIDs distintos.

Se aprovecha para eliminar la duplicación de `bin/` y `obj/`, que aparecen dos veces.

### 4.4 Observación 22 y resto de la 24 — documentación

Quedan enlaces `file:///c:/Users/Danielillo/...` en unos diez `.md`. Pasan a rutas
relativas en los **documentos vivos**: `README.md`, `GEMINI.md`, `docs/README.md`,
`docs/tasks/current.md`, `docs/tasks/backlog.md` y `docs/tasks/roadmap.md`.

**No se tocan** `docs/tasks/completed.md` ni los `docs/plans/*.md` históricos: son
registro de lo que se hizo en su momento, corregirlos es cosmético y reescribe historia.
El test de vigilancia cubrirá solo los documentos vivos.

---

## 5. Criterios de aceptación

1. `OpenDouDataPaths.resolve()` devuelve el override del proyecto cuando existe.
2. Devuelve el default del addon cuando el override no existe.
3. Devuelve cadena vacía cuando no existe ninguno de los dos, para que el consumidor
   pueda caer a su default en código.
4. `addons/opendou/data/synth_presets.json` existe y contiene presets; el archivo de la
   raíz del proyecto ya no es la única copia.
5. Ninguna de las siete rutas hardcodeadas queda en el código: todas pasan por el
   resolutor.
6. `load_presets()` con un archivo inexistente emite un `push_warning()` que nombra el
   archivo.
6b. Ningún archivo de `addons/opendou/runtime/` ni de `addons/opendou/nodes/` combina un
   `FileAccess.open` en modo escritura con un literal `res://`. Es una guarda estática
   contra una regresión futura, no la corrección de un defecto actual.
7. `plugin.gd` no invoca `add_custom_type()` ni `remove_custom_type()`.
8. Los 15 nodos siguen en `ProjectSettings.get_global_class_list()` con un `icon` no
   vacío.
9. `_has_main_screen()` devuelve `false`.
10. `plugin.gd` no invoca `get_editor_interface()`.
11. `.gitignore` no ignora `*.import`, y los 16 archivos están versionados.
12. Los seis documentos vivos no contienen `file:///c:/`.
13. Un test vigila los criterios 6b, 7, 9, 10 y 12 para que no vuelvan.
14. La suite sigue en verde con cero `SCRIPT ERROR`, fugas no superiores al techo y el
    árbol de git limpio.

---

## 6. Fuera de alcance

- **Observación 19**, la limpieza del namespace global: Fase 4B, con su propia spec.
- Versión 2 del formato ODBK con tabla de nombres (diferido en la Fase 3).
- nº2 y las tres demos nuevas: Fase 5.
- Llevar las fugas de ObjectDB a cero. Son casi todas de los tests de UI del editor, y
  su limpieza no pertenece a esta fase: aquí no se toca ninguno de esos tests.
- Corregir los enlaces de `docs/tasks/completed.md` y `docs/plans/*.md` históricos.
- Convertir el Studio en un main screen de verdad. Se decidió conservar el flujo del
  panel inferior.

---

## 7. Riesgos

| Riesgo | Mitigación |
|---|---|
| Mover el JSON de presets rompe el flujo de guardado del panel | El panel guarda en el override del proyecto, que es el comportamiento correcto de un addon. El resolutor lee override primero, así que lo guardado gana. |
| Retirar `add_custom_type` hace desaparecer los nodos del diálogo «Crear nodo» | Verificado que el registro global ya los tiene con icono, y un test lo afirma. |
| Versionar los `.import` mete ruido en los diffs | Son 16 archivos pequeños que cambian solo al reimportar. Es lo que documenta Godot. |
| `_has_main_screen() = false` rompe algún flujo del Studio | El Studio no usa el contenedor de main screen: hoy la pestaña lleva a una pantalla vacía. Devolver `false` elimina un camino roto, no uno que funcione. |
| Los defaults vacíos del addon enmascaran un archivo que debería existir | Por eso los diagnósticos del 3.4 nombran el archivo y su consecuencia en lugar de callar. |
