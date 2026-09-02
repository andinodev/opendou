# Fase 4A — Distribuible y honesto: plan de implementación

> **Para trabajadores agénticos:** SUB-SKILL REQUERIDA: usa superpowers:subagent-driven-development (recomendado) o superpowers:executing-plans para implementar este plan tarea a tarea. Los pasos usan sintaxis de checkbox (`- [ ]`) para seguimiento.

**Goal:** Que el addon se pueda copiar a otro proyecto y funcione, que deje de registrar sus nodos dos veces, que no anuncie una pantalla que no existe, y que sus documentos vivos no apunten al disco de otra persona.

**Architecture:** Un único resolutor de rutas con precedencia override-del-proyecto → default-del-addon → default-en-código sustituye a siete rutas hardcodeadas. El registro de tipos se queda solo con `class_name` + `@icon`, que ya funciona. El resto son arreglos acotados de higiene, cada uno con su guarda para que no vuelvan.

**Tech Stack:** Godot 4.7.2, GDScript. Sin GDExtension. Sin dependencias externas.

**Spec:** `docs/superpowers/specs/2026-09-01-fase4a-distribuible-design.md`

## Global Constraints

- **Godot 4.7.2** exactamente. El binario está en `/Users/Daniel/Downloads/Godot.app/Contents/MacOS/Godot`.
- **Rama `main`.** Este proyecto trabaja en una sola rama, por indicación explícita del usuario. No crees ramas.
- **Ejecuta siempre `./run_tests.sh`**, nunca Godot a mano.
- **Comentarios y docstrings en español**, identificadores en inglés, **indentación con tabuladores**.
- **La observación 19 (namespace global) NO entra en esta fase.** Es la Fase 4B. No renombres ni quites ningún `class_name`.
- **`ProjectSettings.get_global_class_list()`** devuelve las clases globales con su `icon` resuelto. Es la API con la que se verifica el registro de tipos.
- **`EditorInterface` es un singleton en 4.7.** `get_editor_interface()` está deprecado desde 4.2.
- **No cuentes frames fijos para afirmar silencio.** Usa `OpenDouAudioProbe.await_silence()`.
- **Un `AudioStreamPlayer3D` sin oyente activo no emite nada.**
- **Prohibido tocar** los tests de UI del editor para reducir fugas: no pertenece a esta fase. Ni las demos, más allá de lo que exija el runner.
- **Cada tarea acaba en commit** con el estilo del repo (`feat(scope):`, `fix(scope):`, `chore(scope):`).

## Notas de arranque

Baseline: `547/547 PASSED`, cero `SCRIPT ERROR`, fugas **593**, árbol de git limpio.

**Tres correcciones al análisis original que esta fase hereda de la spec.** No las
redescubras ni las contradigas:

- La **observación 17** estaba sobredimensionada: `save_presets`, `save_syncs_to_disk` y
  `save_to_disk` solo las llama el editor, y escribir en `res://` desde el editor es
  correcto. No hay nada que arreglar; se añade una **guarda estática** (Tarea 3).
- La **observación 16** también: `acoustic_material_registry` tiene sus defaults en
  código y `music_player` tiene pistas sintéticas de reserva. El addon degrada, no se
  rompe. Los defectos reales son la degradación silenciosa, los presets del addon
  viviendo en la raíz, y las siete rutas hardcodeadas.
- La **observación 21** es peor de lo dicho: hay **16 archivos `.import` reales** sin
  versionar.

---

## File Structure

### Archivos nuevos

| Archivo | Responsabilidad |
|---|---|
| `addons/opendou/runtime/data_paths.gd` | Resuelve dónde vive cada archivo de datos JSON: override del proyecto, default del addon, o nada. |
| `addons/opendou/data/synth_presets.json` | Presets de síntesis que envía el addon. **Movidos** desde la raíz del proyecto. |
| `addons/opendou/data/syncs.json` | Estructura mínima de Game Syncs para que una instalación limpia resuelva a un archivo válido. |
| `addons/opendou/data/music_suites.json` | Ídem para las suites musicales. |
| `tests/test_data_paths.gd` | Precedencia del resolutor y las tres ramas de resolución. |
| `tests/test_runtime_no_res_writes.gd` | Guarda estática: ningún archivo de runtime escribe en `res://`. |
| `tests/test_plugin_registration.gd` | Los 15 nodos siguen registrados con icono; el plugin no usa API deprecada. |

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `addons/opendou/runtime/synth/synth_preset_registry.gd` | Usa el resolutor; avisa si no hay archivo. |
| `addons/opendou/runtime/spatial/acoustic_material_registry.gd` | Usa el resolutor; conserva sus defaults en código. |
| `addons/opendou/nodes/opendou_music_player.gd` | Usa el resolutor. |
| `addons/opendou/editor/opendou_game_syncs_panel.gd` | Usa el resolutor para leer; sigue guardando en el override del proyecto. |
| `addons/opendou/editor/opendou_music_timeline.gd` | Ídem. |
| `addons/opendou/plugin.gd` | Sin `add_custom_type`, sin `_has_main_screen` true, sin `get_editor_interface`. |
| `.gitignore` | Sin `*.import`; sin `bin/` duplicado. |
| `GEMINI.md`, `docs/README.md`, `docs/tasks/current.md` | Enlaces relativos. |
| `tests/test_no_unfulfilled_claims.gd` | Vigila los enlaces de los documentos vivos. |
| `tests/test_all.gd` | Cablea las tres suites nuevas. |
| **Eliminado** | `opendou_synth_presets.json` de la raíz (se mueve al addon). |

---

## Task 1: El resolutor de rutas de datos

**Files:**
- Create: `addons/opendou/runtime/data_paths.gd`
- Create: `tests/test_data_paths.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouDataPaths` con las constantes `PROJECT_PREFIX`, `ADDON_DATA_DIR`, `SYNTH_PRESETS`, `ACOUSTIC_MATERIALS`, `MUSIC_SUITES`, `GAME_SYNCS`, y los métodos estáticos `project_override_path(data_name: String) -> String`, `addon_default_path(data_name: String) -> String`, `resolve(data_name: String) -> String`.
- Consumes: `OpenDouAssert`.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_data_paths.gd`:

```gdscript
class_name TestDataPaths
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const DataPathsClass = preload("res://addons/opendou/runtime/data_paths.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("data_paths")

	# Las rutas se construyen con los nombres de archivo que el proyecto ya usa.
	a.eq(DataPathsClass.project_override_path(DataPathsClass.SYNTH_PRESETS),
		"res://opendou_synth_presets.json", "el override de presets conserva su nombre")
	a.eq(DataPathsClass.project_override_path(DataPathsClass.GAME_SYNCS),
		"res://opendou_syncs.json", "el override de syncs conserva su nombre")
	a.eq(DataPathsClass.addon_default_path(DataPathsClass.SYNTH_PRESETS),
		"res://addons/opendou/data/synth_presets.json", "el default vive dentro del addon")

	# Precedencia: si existe el override del proyecto, gana.
	var probe_name := "__probe_data_paths__"
	var override_path: String = DataPathsClass.project_override_path(probe_name)
	var default_path: String = DataPathsClass.addon_default_path(probe_name)

	# Sin ninguno de los dos, cadena vacia: el consumidor cae a su default en codigo.
	a.eq(DataPathsClass.resolve(probe_name), "", "sin archivos resuelve a cadena vacia")

	# Solo el default del addon.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DataPathsClass.ADDON_DATA_DIR))
	var f = FileAccess.open(default_path, FileAccess.WRITE)
	if f == null:
		a.ok(false, "no se pudo crear el default de sonda en %s" % default_path)
		return a
	f.store_string("{}")
	f.close()
	a.eq(DataPathsClass.resolve(probe_name), default_path, "con solo el default del addon, resuelve a el")

	# Con override del proyecto, el override gana.
	var g = FileAccess.open(override_path, FileAccess.WRITE)
	if g != null:
		g.store_string("{}")
		g.close()
		a.eq(DataPathsClass.resolve(probe_name), override_path, "el override del proyecto tiene prioridad")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(override_path))
	else:
		a.ok(false, "no se pudo crear el override de sonda")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(default_path))

	# Los cuatro nombres canonicos resuelven sin reventar, exista el archivo o no.
	for name in [DataPathsClass.SYNTH_PRESETS, DataPathsClass.ACOUSTIC_MATERIALS,
			DataPathsClass.MUSIC_SUITES, DataPathsClass.GAME_SYNCS]:
		var r: String = DataPathsClass.resolve(name)
		a.ok(r.is_empty() or r.begins_with("res://"), "resolve('%s') devuelve ruta valida o vacia" % name)

	return a
```

Registra la suite en `run_suite()` de `tests/test_all.gd` con su `preload`, siguiendo el
patrón de las demás:

```gdscript
const TestDataPathsClass = preload("res://tests/test_data_paths.gd")
```

```gdscript
	var paths_res = TestDataPathsClass.run_all()
	total_tests += paths_res.assertions_run
	all_failures.append_array(paths_res.failures)
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO con `Parse Error: Preload file ... data_paths.gd does not exist`.

- [ ] **Step 3: Implementa el resolutor**

Crea `addons/opendou/runtime/data_paths.gd`:

```gdscript
class_name OpenDouDataPaths
extends RefCounted

## Resuelve donde vive cada archivo de datos JSON de OpenDou.
##
## Existe porque habia siete rutas res:// hardcodeadas en seis archivos distintos, y
## copiar solo addons/opendou/ a otro proyecto dejaba al addon sin sus datos.
##
## Precedencia:
##  1. Override del proyecto: res://opendou_<nombre>.json
##  2. Default del addon:     res://addons/opendou/data/<nombre>.json
##  3. Nada: cadena vacia, para que el consumidor caiga a su default en codigo.
##
## Es el patron estandar de un addon: envia sus defaults, el usuario los sobreescribe
## en su proyecto.

const PROJECT_PREFIX: String = "res://opendou_"
const ADDON_DATA_DIR: String = "res://addons/opendou/data/"

## Nombres canonicos de los archivos de datos.
const SYNTH_PRESETS: String = "synth_presets"
const ACOUSTIC_MATERIALS: String = "acoustic_materials"
const MUSIC_SUITES: String = "music_suites"
const GAME_SYNCS: String = "syncs"

## Ruta del override del proyecto para un nombre de datos, exista o no.
static func project_override_path(data_name: String) -> String:
	return "%s%s.json" % [PROJECT_PREFIX, data_name]

## Ruta del default que envia el addon, exista o no.
static func addon_default_path(data_name: String) -> String:
	return "%s%s.json" % [ADDON_DATA_DIR, data_name]

## Ruta que se debe leer para un nombre de datos.
##
## Devuelve cadena vacia si no existe ninguna de las dos, para que el consumidor pueda
## caer a su default en codigo en lugar de intentar abrir un archivo ausente.
static func resolve(data_name: String) -> String:
	var override_path: String = project_override_path(data_name)
	if FileAccess.file_exists(override_path):
		return override_path
	var default_path: String = addon_default_path(data_name)
	if FileAccess.file_exists(default_path):
		return default_path
	return ""
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK.

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/data_paths.gd tests/test_data_paths.gd tests/test_all.gd
git commit -m "feat(runtime): add a single resolution point for data file paths

Habia siete rutas res:// hardcodeadas en seis archivos distintos, y copiar solo
addons/opendou/ a otro proyecto dejaba al addon sin sus datos.

El resolutor tiene precedencia explicita: override del proyecto, default del
addon, y cadena vacia si no hay ninguno para que el consumidor caiga a su default
en codigo. Es el patron estandar de un addon."
```

---

## Task 2: Los consumidores usan el resolutor, y los presets se mudan al addon

**Files:**
- Create: `addons/opendou/data/synth_presets.json` (**movido** desde la raíz)
- Create: `addons/opendou/data/syncs.json`
- Create: `addons/opendou/data/music_suites.json`
- **Delete:** `opendou_synth_presets.json` de la raíz
- Modify: `addons/opendou/runtime/synth/synth_preset_registry.gd`
- Modify: `addons/opendou/runtime/spatial/acoustic_material_registry.gd`
- Modify: `addons/opendou/nodes/opendou_music_player.gd`
- Modify: `addons/opendou/editor/opendou_game_syncs_panel.gd`
- Modify: `addons/opendou/editor/opendou_music_timeline.gd`
- Modify: `tests/test_data_paths.gd`

**Interfaces:**
- Consumes: `OpenDouDataPaths.resolve()` de la Tarea 1.
- `SynthPresetRegistry.load_presets(json_path: String = "")` — el argumento vacío significa «resuelve tú»; devuelve `false` y emite `push_warning()` si no hay archivo. `save_presets(json_path: String = "")` guarda en el **override del proyecto** cuando se le pasa vacío.
- El resto de firmas no cambia.

- [ ] **Step 1: Escribe el test que falla**

Añade a `tests/test_data_paths.gd`, antes del `return a`:

```gdscript
	# Los presets de sintesis son contenido del ADDON, no datos del usuario: copiar
	# solo addons/opendou/ a otro proyecto tiene que dejarte con presets.
	a.ok(FileAccess.file_exists(DataPathsClass.addon_default_path(DataPathsClass.SYNTH_PRESETS)),
		"el addon envia sus presets de sintesis")

	# Y una instalacion limpia resuelve a un archivo valido para syncs y suites.
	for name in [DataPathsClass.GAME_SYNCS, DataPathsClass.MUSIC_SUITES]:
		a.ok(FileAccess.file_exists(DataPathsClass.addon_default_path(name)),
			"el addon envia un default para '%s'" % name)

	# El registro carga presets sin que nadie le diga de donde.
	var RegistryClass = load("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
	var reg = RegistryClass.get_singleton()
	a.ok(reg != null, "el registro de presets existe")
	if reg != null:
		a.gt(float(reg.get_preset_names().size()), 0.0, "el registro tiene presets tras resolver solo")

	# Ninguna ruta hardcodeada queda en el codigo del addon.
	var offenders: Array[String] = []
	for path in ["res://addons/opendou/runtime/synth/synth_preset_registry.gd",
			"res://addons/opendou/runtime/spatial/acoustic_material_registry.gd",
			"res://addons/opendou/nodes/opendou_music_player.gd",
			"res://addons/opendou/editor/opendou_game_syncs_panel.gd",
			"res://addons/opendou/editor/opendou_music_timeline.gd"]:
		var f2 = FileAccess.open(path, FileAccess.READ)
		if f2 == null:
			continue
		var text: String = f2.get_as_text()
		f2.close()
		if text.contains('"res://opendou_'):
			offenders.append(path)
	a.eq(offenders.size(), 0, "sin rutas res://opendou_ hardcodeadas, sobran: %s" % str(offenders))

	# El aviso al faltar el archivo. push_warning() no es capturable desde GDScript,
	# asi que se comprueba por las dos vias disponibles: que la funcion devuelve
	# false ante un archivo inexistente, y que el codigo contiene un aviso que
	# nombra la consecuencia. No es tan fuerte como capturar el aviso, y es lo mejor
	# que el motor permite.
	if reg != null:
		a.eq(reg.load_presets("res://__archivo_que_no_existe__.json"), false,
			"load_presets devuelve false ante un archivo inexistente")
	var rf = FileAccess.open("res://addons/opendou/runtime/synth/synth_preset_registry.gd", FileAccess.READ)
	if rf != null:
		var rsrc: String = rf.get_as_text()
		rf.close()
		a.ok(rsrc.contains("push_warning"), "load_presets avisa en lugar de callar")
		a.ok(rsrc.contains("desplegable"), "el aviso nombra la consecuencia, no solo el fallo")

	# Recargar los presets de verdad para no dejar el registro vacio para otras
	# suites: load_presets() los ha sobreescrito con nada.
	if reg != null:
		reg.load_presets()
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `el addon envia sus presets de sintesis` y en `sin rutas
res://opendou_ hardcodeadas`, listando los cinco archivos.

- [ ] **Step 3: Mueve los presets y crea los defaults del addon**

```bash
mkdir -p addons/opendou/data
git mv opendou_synth_presets.json addons/opendou/data/synth_presets.json
printf '{"rtpcs": {}, "switches": {}, "states": {}}\n' > addons/opendou/data/syncs.json
printf '{}\n' > addons/opendou/data/music_suites.json
```

Se **mueve**, no se copia: dos copias de 82 KB en el repo serían peores que una. El
override del proyecto lo creará el panel del editor la próxima vez que el usuario guarde.

- [ ] **Step 4: Los cinco consumidores piden su ruta al resolutor**

Añade a la cabecera de cada uno de los cinco archivos, si no está:

```gdscript
const DataPathsClass = preload("res://addons/opendou/runtime/data_paths.gd")
```

**`synth_preset_registry.gd`.** Sustituye las dos firmas:

```gdscript
func load_presets(json_path: String = "res://opendou_synth_presets.json") -> bool:
```

por:

```gdscript
## Carga los presets de sintesis.
##
## Con json_path vacio resuelve por su cuenta: override del proyecto, default del
## addon, o nada.
func load_presets(json_path: String = "") -> bool:
	invalidate_hint_cache()
	var path: String = json_path
	if path.is_empty():
		path = DataPathsClass.resolve(DataPathsClass.SYNTH_PRESETS)
	if path.is_empty():
		push_warning("[OpenDou] no hay presets de sintesis: no existe ni '%s' ni '%s'. El desplegable de presets del inspector quedara vacio." % [
			DataPathsClass.project_override_path(DataPathsClass.SYNTH_PRESETS),
			DataPathsClass.addon_default_path(DataPathsClass.SYNTH_PRESETS)])
		return false
	if not FileAccess.file_exists(path):
		push_warning("[OpenDou] el archivo de presets '%s' no existe. El desplegable de presets del inspector quedara vacio." % path)
		return false
```

y **borra** el `if not FileAccess.file_exists(json_path): return false` que había justo
después, junto con el `invalidate_hint_cache()` duplicado si quedan dos. El resto del
cuerpo usa `path` en lugar de `json_path`: **lee la función completa y sustituye todas
las apariciones.**

Para `save_presets`:

```gdscript
func save_presets(json_path: String = "res://opendou_synth_presets.json") -> bool:
```

por:

```gdscript
## Guarda los presets.
##
## Con json_path vacio guarda en el OVERRIDE DEL PROYECTO, nunca en el default del
## addon: modificar el addon del usuario seria incorrecto.
func save_presets(json_path: String = "") -> bool:
	var path: String = json_path
	if path.is_empty():
		path = DataPathsClass.project_override_path(DataPathsClass.SYNTH_PRESETS)
```

y el resto del cuerpo usa `path`.

**`acoustic_material_registry.gd`.** Sustituye:

```gdscript
func load_from_json(path: String = "res://opendou_acoustic_materials.json") -> void:
```

por:

```gdscript
## Carga materiales acusticos desde JSON, si hay archivo.
##
## No hay default en el addon a proposito: los coeficientes ya estan en codigo, y un
## JSON duplicado seria dos fuentes de verdad para lo mismo. Este archivo es un
## override opcional del proyecto.
func load_from_json(path: String = "") -> void:
	var resolved: String = path
	if resolved.is_empty():
		resolved = DataPathsClass.resolve(DataPathsClass.ACOUSTIC_MATERIALS)
	if resolved.is_empty():
		return
```

y el resto del cuerpo usa `resolved`. **Lee la función completa antes de editar.**

**`opendou_music_player.gd`.** Sustituye la constante local y su uso:

```gdscript
	const SUITES_PATH = "res://opendou_music_suites.json"
	if FileAccess.file_exists(SUITES_PATH):
		var file = FileAccess.open(SUITES_PATH, FileAccess.READ)
```

por:

```gdscript
	var suites_path: String = DataPathsClass.resolve(DataPathsClass.MUSIC_SUITES)
	if not suites_path.is_empty():
		var file = FileAccess.open(suites_path, FileAccess.READ)
```

El fallback de pistas sintéticas que hay más abajo se queda: es el default en código.

**`opendou_game_syncs_panel.gd`.** La constante `SYNCS_FILE_PATH` y `DEFAULT_PRESETS_PATH`
pasan a resolverse. Los campos inyectables `syncs_file_path` y `presets_file_path` que
añadió la Fase 1 se conservan; lo que cambia es su valor por defecto:

```gdscript
var syncs_file_path: String = DataPathsClass.project_override_path(DataPathsClass.GAME_SYNCS)
var presets_file_path: String = DataPathsClass.project_override_path(DataPathsClass.SYNTH_PRESETS)
```

Y en `load_syncs_from_disk()`, si `syncs_file_path` no existe, cae al resolutor:

```gdscript
func load_syncs_from_disk() -> void:
	var path: String = syncs_file_path
	if not FileAccess.file_exists(path):
		path = DataPathsClass.resolve(DataPathsClass.GAME_SYNCS)
	if path.is_empty() or not FileAccess.file_exists(path):
		return
```

El resto del cuerpo usa `path`. **Guardar sigue yendo a `syncs_file_path`**, que es el
override del proyecto: correcto.

**`opendou_music_timeline.gd`.** `MUSIC_SUITES_SAVE_PATH` pasa a
`DataPathsClass.project_override_path(DataPathsClass.MUSIC_SUITES)`. Guardar en el
override es lo correcto; leer, si el archivo lee en otro sitio, pasa por el resolutor.
**Lee el archivo y aplica el mismo patrón.**

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Si `tests/test_synth_preset_registry.gd` falla, mira si llamaba a
`load_presets()` o `save_presets()` contando con la ruta `res://` por defecto: ahora el
argumento vacío resuelve, y guardar va al override. Ajusta el test para pasar rutas
explícitas de `user://`, como ya hace `test_studio_advanced_ui.gd`.

- [ ] **Step 6: Comprueba que la suite no ensucia el repo**

```bash
git status --porcelain
```

Expected: solo los archivos que has tocado a propósito. Si aparece
`opendou_synth_presets.json` como nuevo, es que algo lo guardó: busca qué test llama a
`save_presets()` sin ruta.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(addon): make the addon self-contained via the path resolver

Las siete rutas res:// hardcodeadas en seis archivos pasan por OpenDouDataPaths.

Los presets de sintesis se MUEVEN a addons/opendou/data/: son contenido del addon,
no datos del usuario, y copiar solo addons/opendou/ dejaba sin ninguno. El panel
del editor sigue guardando en el override del proyecto, que es el flujo correcto de
un addon.

No se envia JSON de materiales acusticos: los coeficientes ya estan en codigo y un
duplicado seria dos fuentes de verdad para lo mismo.

Donde se degradaba en silencio ahora hay un push_warning que nombra el archivo que
falta Y la consecuencia: un aviso que no dice que se pierde es ruido."
```

---

## Task 3: Guarda estática contra escrituras a `res://` en runtime

**La observación 17 pasa de descarte a guarda.**

**Files:**
- Create: `tests/test_runtime_no_res_writes.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- No produce API. Es una guarda.

Se midió que ninguna escritura a `res://` es alcanzable en runtime, así que no hay nada
que arreglar. Pero descartarla sin verificación dejaría la puerta abierta a que un cambio
futuro introduzca una y nadie lo note.

- [ ] **Step 1: Escribe la guarda**

Crea `tests/test_runtime_no_res_writes.gd`:

```gdscript
class_name TestRuntimeNoResWrites
extends RefCounted

## Guarda estatica: ningun archivo de runtime debe escribir en res://.
##
## Un build exportado no puede escribir en res://, asi que esa combinacion en codigo
## de runtime es siempre un defecto. El editor SI puede y debe escribir ahi: es como
## se autoran datos de proyecto, y por eso addons/opendou/editor/ no se inspecciona.
##
## Se midio que hoy no hay ninguna, y esta guarda existe para que siga siendo verdad.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")

const SCANNED_DIRS: Array[String] = [
	"res://addons/opendou/runtime",
	"res://addons/opendou/nodes",
	"res://addons/opendou/resources",
	"res://addons/opendou/core",
]

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("runtime_no_res_writes")

	var scanned: int = 0
	var offenders: Array[String] = []
	for dir_path in SCANNED_DIRS:
		for file_path in _gd_files_in(dir_path):
			scanned += 1
			var f = FileAccess.open(file_path, FileAccess.READ)
			if f == null:
				continue
			var text: String = f.get_as_text()
			f.close()
			if _writes_to_res(text):
				offenders.append(file_path)

	a.gt(float(scanned), 20.0, "la guarda inspecciono los archivos de runtime")
	a.eq(offenders.size(), 0, "ningun archivo de runtime escribe en res://, sobran: %s" % str(offenders))
	return a

## Busca un FileAccess.open en modo escritura en la misma linea que un literal res://,
## o un FileAccess.open con res:// cuyo modo sea WRITE en la misma sentencia.
static func _writes_to_res(text: String) -> bool:
	for line in text.split("\n"):
		var l: String = line.strip_edges()
		if l.begins_with("#"):
			continue
		if not l.contains("FileAccess.open"):
			continue
		if not (l.contains("FileAccess.WRITE") or l.contains("WRITE_READ")):
			continue
		if l.contains('"res://'):
			return true
	return false

static func _gd_files_in(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = "%s/%s" % [dir_path, name]
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_gd_files_in(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out
```

Registra la suite en `run_suite()` con su `preload`.

- [ ] **Step 2: Ejecuta y verifica que pasa a la primera**

Run: `./run_tests.sh`

Expected: OK. **Esta guarda debe pasar sin cambiar código**, porque se midió que no hay
ninguna escritura de ese tipo. Si falla, has encontrado algo que la medición no vio:
investiga el archivo que reporta antes de tocar la guarda.

- [ ] **Step 3: Comprueba que la guarda puede fallar**

Para verificar que no es vacua, añade temporalmente a
`addons/opendou/runtime/data_paths.gd`, al final:

```gdscript
func _guard_probe() -> void:
	var f = FileAccess.open("res://probe.json", FileAccess.WRITE)
	if f: f.close()
```

Run: `./run_tests.sh`

Expected: FALLO en `ningun archivo de runtime escribe en res://`, nombrando
`data_paths.gd`. **Después borra ese método**, vuelve a ejecutar y confirma que pasa.

- [ ] **Step 4: Commit**

```bash
git add tests/test_runtime_no_res_writes.gd tests/test_all.gd
git commit -m "test(guard): forbid res:// writes in runtime code

La observacion 17 estaba sobredimensionada: save_presets, save_syncs_to_disk y
save_to_disk solo las llama el editor, y escribir en res:// desde el editor es
correcto porque asi se autoran datos de proyecto.

Pero descartarla sin verificacion dejaria la puerta abierta a que un cambio futuro
introduzca una escritura de runtime y nadie lo note. Esta guarda estatica lee los
archivos de runtime, nodes, resources y core, y falla si encuentra un FileAccess en
modo escritura junto a un literal res://. El directorio editor/ no se inspecciona a
proposito.

Verificada con una probe temporal: la guarda falla cuando debe."
```

---
## Task 4: `plugin.gd` con un solo registro de tipos y sin API deprecada

**Resuelve las observaciones 18 y 20.**

**Files:**
- Modify: `addons/opendou/plugin.gd`
- Create: `tests/test_plugin_registration.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Desaparecen del plugin: las 15 llamadas a `add_custom_type()` y sus 15
  `remove_custom_type()`. `_has_main_screen()` pasa a devolver `false`.
  `get_editor_interface()` pasa al singleton `EditorInterface`.
- No cambia ninguna API que consuman otras tareas.

**Por qué se puede retirar `add_custom_type` sin perder nada.** Verificado que
`ProjectSettings.get_global_class_list()` ya devuelve `OpenDouEventPlayer3D` con
`icon = res://addons/opendou/icons/icon_event_player_3d.svg`. El diálogo «Crear nodo»
toma la clase y el icono de ese registro. Se gana además que los nodos **conserven su
tipo al guardar la escena**: los añadidos por `add_custom_type` se serializan como tipo
base más script, que es la limitación conocida de esa API.

**Sobre cómo se verifica.** Un `EditorPlugin` no se puede instanciar de forma útil en
headless, así que las aserciones sobre el plugin son **estáticas**: se lee `plugin.gd`
como texto y se comprueba qué API invoca. Es lo mismo que hace la guarda de la Tarea 3, y
por la misma razón.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_plugin_registration.gd`:

```gdscript
class_name TestPluginRegistration
extends RefCounted

## Verifica el registro de tipos del plugin y que no use API deprecada.
##
## Las aserciones sobre plugin.gd son estaticas, leyendo el archivo como texto: un
## EditorPlugin no se puede instanciar de forma util en headless.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")

const PLUGIN_PATH: String = "res://addons/opendou/plugin.gd"

## Los 15 nodos declarativos que el plugin expone.
const DECLARATIVE_NODES: Array[String] = [
	"OpenDouEventPlayer", "OpenDouEventPlayer2D", "OpenDouEventPlayer3D",
	"OpenDouRoom3D", "OpenDouPortal3D", "OpenDouReflector3D",
	"OpenDouMusicPlayer", "OpenDouAudibleMonitor", "OpenDouAcousticDebugger3D",
	"OpenDouSplineEmitter3D", "OpenDouGranularEmitter3D", "OpenDouParameterArea3D",
	"OpenDouMultiPositionEmitter3D", "OpenDouAcousticGeometryBake", "OpenDouAnimationSync",
]

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("plugin_registration")

	# Los 15 nodos siguen en el registro global CON icono. Es lo que hace que
	# retirar add_custom_type no pierda nada: el dialogo "Crear nodo" toma la clase
	# y el icono de aqui.
	var registered: Dictionary = {}
	for entry in ProjectSettings.get_global_class_list():
		registered[str(entry.get("class", ""))] = str(entry.get("icon", ""))

	for node_class in DECLARATIVE_NODES:
		a.ok(registered.has(node_class), "%s esta en el registro global" % node_class)
		if registered.has(node_class):
			a.ok(not String(registered[node_class]).is_empty(),
				"%s tiene icono registrado" % node_class)

	# El plugin no debe registrar los tipos por segunda via.
	var f = FileAccess.open(PLUGIN_PATH, FileAccess.READ)
	if f == null:
		a.ok(false, "no se pudo leer plugin.gd")
		return a
	var src: String = f.get_as_text()
	f.close()

	a.ok(not src.contains("add_custom_type("),
		"el plugin no usa add_custom_type: duplicaba las entradas del dialogo")
	a.ok(not src.contains("remove_custom_type("),
		"el plugin no usa remove_custom_type")

	# API deprecada desde Godot 4.2.
	a.ok(not src.contains("get_editor_interface()"),
		"el plugin usa el singleton EditorInterface y no get_editor_interface()")

	# No debe anunciar un main screen que no existe.
	#
	# Una sola asercion precisa, no una compuesta con `or`: un `or` entre dos
	# comprobaciones puede pasar por el lado equivocado y no probar lo que dice.
	a.ok(src.contains("func _has_main_screen() -> bool:\n\treturn false"),
		"_has_main_screen devuelve false")

	# Y el docstring no debe prometerlo.
	a.ok(not src.contains("Main Screen workspace"),
		"el docstring del plugin no promete un Main Screen workspace")

	return a
```

Registra la suite en `run_suite()` con su `preload`.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `el plugin no usa add_custom_type`, `remove_custom_type`,
`get_editor_interface`, `_has_main_screen devuelve false` y el docstring. Las aserciones
del registro global **deben pasar ya**: es lo que demuestra que se puede retirar.

- [ ] **Step 3: Retira el doble registro**

En `addons/opendou/plugin.gd`:

Borra el bloque completo de las 15 llamadas a `add_custom_type(...)` de `_enter_tree()`,
junto con su comentario `# 4. Register Declarative Audio Custom Types`, y sustitúyelo por:

```gdscript
	# Los nodos declarativos NO se registran con add_custom_type: cada uno ya tiene
	# class_name y @icon, y ProjectSettings.get_global_class_list() los devuelve con
	# su icono resuelto, asi que el dialogo "Crear nodo" los muestra igual.
	#
	# Registrarlos por las dos vias duplicaba sus entradas en ese dialogo, y los
	# nodos anadidos por add_custom_type pierden su tipo al guardar la escena: se
	# serializan como tipo base mas script.
```

Borra de `_exit_tree()` el bloque de las 15 `remove_custom_type(...)` con su comentario
`# Remove Declarative Audio Custom Types`.

**Las constantes `OpenDou*Class` e `Icon*` que quedan sin uso**: revisa cuáles siguen
haciendo falta. `OpenDouGizmoPlugin3DClass`, `OpenDouAcousticGeometryBakeInspectorPluginClass`
y `OpenDouStudioMainClass` se siguen usando. Los 15 `preload` de nodos y los 15 de iconos
quedan sin consumidor: **bórralos también**, o el archivo carga 30 recursos que nadie usa
cada vez que arranca el editor.

- [ ] **Step 4: Arregla el main screen y la API deprecada**

Sustituye:

```gdscript
func _has_main_screen() -> bool:
	return true
```

por:

```gdscript
## El Studio vive en el panel inferior con su ventana desacoplable, no en el
## contenedor de main screen.
##
## Devolvia true sin anadir nada a ese contenedor, asi que pulsar la pestana
## "OpenDou" del editor dejaba la pantalla vacia y abria la ventana flotante.
func _has_main_screen() -> bool:
	return false
```

Sustituye:

```gdscript
func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("AudioStreamPlayer", "EditorIcons")
```

por:

```gdscript
func _get_plugin_icon() -> Texture2D:
	# EditorInterface es un singleton desde Godot 4.2; get_editor_interface() esta
	# deprecado.
	return EditorInterface.get_base_control().get_theme_icon("AudioStreamPlayer", "EditorIcons")
```

Y en la cabecera del archivo, sustituye:

```gdscript
## Provides Main Screen workspace, bottom dock, and real-time audio logic authoring.
```

por:

```gdscript
## Provides a bottom-panel Studio with a detachable window, 3D gizmos for the spatial
## nodes, an inspector tool for acoustic geometry baking, and the runtime autoload.
```

Revisa si `_make_visible()` sigue teniendo sentido con `_has_main_screen()` en `false`:
Godot solo lo invoca para plugins con main screen. **Déjalo**: es inofensivo y documenta
la intención si algún día se convierte en main screen.

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Si algún test del editor falla, comprueba que no dependiera de los
`preload` de iconos que has borrado de `plugin.gd`.

- [ ] **Step 6: Commit**

```bash
git add addons/opendou/plugin.gd tests/test_plugin_registration.gd tests/test_all.gd
git commit -m "fix(plugin): register node types once and drop deprecated editor API

Los 15 nodos se registraban dos veces: por class_name y por add_custom_type. El
resultado eran entradas duplicadas en el dialogo Crear nodo, y los nodos anadidos
por add_custom_type pierden su tipo al guardar la escena porque se serializan como
tipo base mas script.

Verificado que ProjectSettings.get_global_class_list() ya devuelve cada nodo con su
icono resuelto, asi que retirar add_custom_type no pierde nada. Se borran tambien
los 30 preload de nodos e iconos que quedaban sin consumidor: cargaban recursos que
nadie usaba en cada arranque del editor.

_has_main_screen() devolvia true sin anadir nada al contenedor de main screen, asi
que la pestana OpenDou del editor llevaba a una pantalla vacia. Devuelve false: el
Studio vive en el panel inferior con su ventana desacoplable, que es el flujo
construido a proposito.

get_editor_interface(), deprecado desde 4.2, pasa al singleton EditorInterface."
```

---

## Task 5: Los `.import` se versionan

**Resuelve la observación 21.**

**Files:**
- Modify: `.gitignore`
- Add: los 16 `addons/opendou/icons/*.svg.import`
- Modify: `tests/test_no_unfulfilled_claims.gd`

**Interfaces:**
- No produce API.

En Godot 4 los archivos `.import` contienen el UID y los ajustes de importación del
recurso. Sin versionarlos, cada clon del repositorio regenera UIDs distintos.

- [ ] **Step 1: Escribe la guarda**

Añade a `tests/test_no_unfulfilled_claims.gd`, antes del `return a`:

```gdscript
	# Los .import llevan el UID del recurso: sin versionarlos, cada clon regenera
	# UIDs distintos. Godot documenta que deben ir al control de versiones.
	var gitignore := FileAccess.open("res://.gitignore", FileAccess.READ)
	if gitignore != null:
		var gtext: String = gitignore.get_as_text()
		gitignore.close()
		var ignores_import := false
		for line in gtext.split("\n"):
			if line.strip_edges() == "*.import":
				ignores_import = true
				break
		a.ok(not ignores_import, ".gitignore no ignora *.import")

	# Y cada icono SVG debe tener su .import al lado.
	var missing: Array[String] = []
	var icons := DirAccess.open("res://addons/opendou/icons")
	if icons != null:
		icons.list_dir_begin()
		var n: String = icons.get_next()
		while n != "":
			if n.ends_with(".svg") and not FileAccess.file_exists("res://addons/opendou/icons/%s.import" % n):
				missing.append(n)
			n = icons.get_next()
		icons.list_dir_end()
	a.eq(missing.size(), 0, "todos los iconos SVG tienen su .import, faltan: %s" % str(missing))
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `.gitignore no ignora *.import`. La segunda aserción debería pasar: los
16 archivos existen en disco, solo no están versionados.

- [ ] **Step 3: Quita `*.import` del `.gitignore` y limpia el duplicado**

Borra la línea 4:

```
*.import
```

y sustitúyela por:

```
# Los .import NO se ignoran: llevan el UID y los ajustes de importacion del
# recurso, y sin versionarlos cada clon regenera UIDs distintos.
```

`bin/` aparece dos veces, en la línea 9 y en la 36. **Borra la de la línea 36** y deja la
primera.

- [ ] **Step 4: Versiona los 16 archivos**

```bash
git add -f addons/opendou/icons/*.svg.import
git status --porcelain -- addons/opendou/icons/ | grep -c "^A" 
```

Expected: `16`.

El `-f` es necesario en la misma ejecución si git aún tiene el patrón en caché; tras
editar `.gitignore` no debería hacer falta, pero no estorba.

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK.

- [ ] **Step 6: Commit**

```bash
git add .gitignore addons/opendou/icons/ tests/test_no_unfulfilled_claims.gd
git commit -m "chore(repo): version the .import files instead of ignoring them

En Godot 4 los .import contienen el UID y los ajustes de importacion del recurso:
sin versionarlos, cada clon del repositorio regenera UIDs distintos. Habia 16
archivos .import reales en disco, uno por icono SVG, y .gitignore los excluia.

Se aprovecha para borrar la entrada bin/ duplicada, que aparecia dos veces.

Un test vigila que *.import no vuelva al .gitignore y que cada SVG tenga su .import
al lado."
```

---

## Task 6: Los documentos vivos dejan de apuntar a otro disco

**Resuelve la observación 22 y el resto de la 24.**

**Files:**
- Modify: `GEMINI.md` (4 enlaces)
- Modify: `docs/README.md` (43 enlaces)
- Modify: `docs/tasks/current.md` (2 enlaces)
- Modify: `tests/test_no_unfulfilled_claims.gd`

**Interfaces:**
- No produce API.

`README.md`, `docs/tasks/backlog.md` y `docs/tasks/roadmap.md` ya están limpios de fases
anteriores. **No se tocan** `docs/tasks/completed.md` ni los `docs/plans/*.md` históricos:
son registro de lo que se hizo en su momento, y corregirlos es cosmético.

- [ ] **Step 1: Escribe la guarda**

Añade a `tests/test_no_unfulfilled_claims.gd`, antes del `return a`:

```gdscript
	# Los documentos VIVOS no deben apuntar al disco de otra persona. Los historicos
	# (completed.md, plans/*.md) se dejan a proposito: son registro de lo que se hizo.
	for doc in ["res://README.md", "res://GEMINI.md", "res://docs/README.md",
			"res://docs/tasks/current.md", "res://docs/tasks/backlog.md",
			"res://docs/tasks/roadmap.md"]:
		var df = FileAccess.open(doc, FileAccess.READ)
		if df == null:
			a.ok(false, "no se pudo leer %s" % doc)
			continue
		var dtext: String = df.get_as_text()
		df.close()
		a.ok(not dtext.contains("file:///c:/"), "%s no tiene enlaces file:///c:/" % doc)
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `GEMINI.md`, `docs/README.md` y `docs/tasks/current.md`. Los otros tres
pasan: se limpiaron en fases anteriores.

- [ ] **Step 3: Sustituye los enlaces por rutas relativas**

El patrón a eliminar es exactamente:

```
file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/
```

Se borra el prefijo, dejando la ruta relativa que le sigue. Por ejemplo:

```markdown
[Documentation Hub](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/docs/README.md)
```

pasa a:

```markdown
[Documentation Hub](docs/README.md)
```

**Cuidado con la profundidad.** En `docs/README.md` y `docs/tasks/current.md`, una ruta
relativa a `docs/...` desde un archivo que ya está dentro de `docs/` sería incorrecta.
Comprueba cada enlace: desde `docs/README.md`, el enlace a `docs/architecture/overview.md`
debe quedar como `architecture/overview.md`. Desde `docs/tasks/current.md`, un enlace a
`docs/specs/foo.md` debe quedar como `../specs/foo.md`.

Hazlo con cuidado archivo por archivo; **son 49 enlaces en total** y equivocar la
profundidad los deja roto de otra manera, que no es mejor que como estaban.

- [ ] **Step 4: Comprueba que los enlaces resuelven**

Para cada enlace relativo que hayas escrito, verifica que el archivo destino existe:

```bash
python3 - <<'EOF'
import re, pathlib
roto = []
for doc in ["README.md", "GEMINI.md", "docs/README.md", "docs/tasks/current.md"]:
    p = pathlib.Path(doc)
    if not p.exists():
        continue
    base = p.parent
    for m in re.finditer(r'\]\(([^)#:]+\.md)\)', p.read_text()):
        target = (base / m.group(1)).resolve()
        if not target.exists():
            roto.append("%s -> %s" % (doc, m.group(1)))
print("enlaces roto: %d" % len(roto))
for r in roto:
    print("  " + r)
EOF
```

Expected: `enlaces roto: 0`. Si aparece alguno, corrige su profundidad.

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK.

- [ ] **Step 6: Commit**

```bash
git add GEMINI.md docs/README.md docs/tasks/current.md tests/test_no_unfulfilled_claims.gd
git commit -m "docs: make live document links relative instead of absolute

Quedaban 49 enlaces file:///c:/Users/Danielillo/... en GEMINI.md, docs/README.md y
docs/tasks/current.md: no servian a nadie fuera de esa maquina. README, backlog y
roadmap se limpiaron en fases anteriores.

No se tocan completed.md ni los plans historicos: son registro de lo que se hizo en
su momento y corregirlos es cosmetico.

Un test vigila los seis documentos vivos, y un script comprueba que cada enlace
relativo resuelve a un archivo que existe: equivocar la profundidad los dejaria
rotos de otra manera, que no es mejor."
```

---

## Notas para quien ejecute el plan

**Orden.** La Tarea 2 consume el resolutor de la Tarea 1. Las tareas 3, 4, 5 y 6 son
independientes entre sí y de las dos primeras.

**La Tarea 3 debe pasar a la primera.** Es una guarda sobre algo que ya se midió correcto.
Si falla, has encontrado algo que la medición no vio: investiga antes de tocar la guarda.

**No toques la observación 19.** Ningún `class_name` se renombra ni se quita en esta fase;
eso es la Fase 4B y tiene su propia spec.

**No toques los tests de UI del editor para reducir fugas.** El techo está en 593 y esta
fase no debería moverlo: si sube, es que algo que has creado no se libera.

**Al terminar la fase**, ejecuta `./run_tests.sh` en limpio y confirma: `RESULTADO: OK`,
sin `SCRIPT ERROR`, fugas no superiores al techo, y `git status --porcelain` vacío.
