# Fase 1 — Cadena de audio real: plan de implementación

> **Para trabajadores agénticos:** SUB-SKILL REQUERIDA: usa superpowers:subagent-driven-development (recomendado) o superpowers:executing-plans para implementar este plan tarea a tarea. Los pasos usan sintaxis de checkbox (`- [ ]`) para seguimiento.

**Goal:** Que OpenDou emita audio real y verificable: `post_event()` produce sonido medible, los parámetros calculados llegan a la salida, las voces terminan, y la suite de tests deja de ser ciega a los errores.

**Architecture:** Pool de nodos nativos (orquestador). Godot mezcla en C++; OpenDou decide qué suena, cuándo y con qué volumen, pitch, bus y filtrado. Dos fuentes de voz —el propio reproductor del nodo `OpenDouEventPlayer*`, y reproductores anónimos de un pool hijo del autoload— sobre un único presupuesto gestionado por `VoicePoolManager`, que pasa de dueño de canales a asignador de permiso.

**Tech Stack:** Godot 4.7.2, GDScript. Sin GDExtension. Sin dependencias externas.

**Spec:** `docs/superpowers/specs/2026-09-01-fase1-cadena-audio-real-design.md`

## Global Constraints

- **Godot 4.7.2** exactamente (`4.7.2.stable.official.ed1daf0bf`). El binario en esta máquina está en `/Users/Daniel/Downloads/Godot.app/Contents/MacOS/Godot`.
- **GDScript puro.** Nada de DSP por muestra: la mezcla la hace Godot en C++.
- **Idioma:** comentarios y docstrings en español, igual que el resto del addon. Identificadores en inglés, igual que el resto del addon.
- **Indentación con tabuladores**, como todo el proyecto (verificado: no hay ni un archivo con indentación mixta).
- **`attenuation_filter_cutoff_hz` y `attenuation_filter_db` existen SOLO en `AudioStreamPlayer3D`.** En 2D y no-espacial la oclusión se aplica como atenuación de volumen, nunca como LPF.
- **Ningún test escribe en `res://`.** Las rutas de escritura de los tests van a `user://` o a un directorio temporal.
- **Un error de script aborta la función que lo contiene** y devuelve `null`. Nunca asumas que una llamada fallida devuelve un valor por defecto.
- **Prohibido tocar** lo que pertenece a fases posteriores: spline emitter, transforms sin rotación, `open_factor`, decodificación WAV, ring buffer, `_get_property_list()`, empaquetado, `class_name` globales, main screen, `.gitignore`, demos.
- **Cada tarea acaba en commit** con mensaje en el estilo del repo (`feat(scope):`, `fix(scope):`, `test(scope):`).

## Notas de arranque

Ejecuta el proyecto siempre con `--path .` desde la raíz del repo. Antes de la Tarea 1, el baseline es:

```
STATUS: PASSED | TOTAL: 337 | PASSED: 337 | FAILURES: 0
```

…con **5 `SCRIPT ERROR`** en el log y 1015 instancias ObjectDB filtradas. Ese es el punto de partida y la Tarea 1 consiste precisamente en hacer que eso deje de reportarse como éxito.

Aviso sobre el conteo de tests: `tests/test_all.gd` **suma totales escritos a mano** (`total_tests += 10`), no cuenta aserciones reales. El "337" es una afirmación del autor, no una medición. El helper de la Tarea 1 cuenta aserciones de verdad; no intentes hacer cuadrar el número antiguo.

Aviso sobre tests de demos: `tests/test_demo_suite.gd`, `test_cyberpunk_demo.gd`, `test_tactical_canyon_demo.gd` y `test_tactical_infiltration_demo.gd` prueban escenas que la Fase 5 va a borrar. **No los arregles más allá de lo que exija el runner**, y no inviertas esfuerzo en su cobertura.

---

## File Structure

### Archivos nuevos

| Archivo | Responsabilidad |
|---|---|
| `tests/support/opendou_assert.gd` | Acumulador de aserciones que cuenta las ejecutadas y registra cada fallo con etiqueta. Sustituye al patrón `if x != y: failures.append(...)`. |
| `tests/support/audio_probe.gd` | Sonda de audio: bus dedicado con `AudioEffectCapture`, medición de pico. Única fuente de verdad sobre "esto suena". |
| `tests/test_audio_output.gd` | Aserciones de audio real: `post_event` suena, virtualizada calla, RTPC mueve el pico. |
| `tests/test_listener_resolver.gd` | Resolución del oyente y su efecto sobre prioridad y oclusión. |
| `tests/test_occlusion_scheduler.gd` | Presupuesto de raycasts y priorización por LOD. |
| `tests/test_early_reflections.gd` | Reflexiones tempranas como voces reales. |
| `addons/opendou/runtime/native_player_pool.gd` | Pool de `AudioStreamPlayer`/`2D`/`3D` nativos, hijos del autoload. Crecimiento perezoso con cupo. |
| `addons/opendou/runtime/listener_resolver.gd` | Posición y orientación del oyente replicando la regla de Godot, con override. |
| `addons/opendou/runtime/spatial/occlusion_scheduler.gd` | Un único `OcclusionManager` y presupuesto de N raycasts por frame priorizado por LOD. |
| `addons/opendou/runtime/reflection_dispatcher.gd` | Traduce las reflexiones de `AcousticReflectorEngine` en voces anónimas del pool. |
| `run_tests.sh` | Runner multiplataforma que falla si el log contiene errores del motor. |

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `addons/opendou/runtime/physical_voice_channel.gd` | De objeto contable a envoltorio sobre un reproductor nativo real. |
| `addons/opendou/runtime/voice_pool_manager.gd` | De dueño de canales a asignador de permiso. `get_active_virtual_count` deja de exigir array tipado. |
| `addons/opendou/runtime/event_instance.gd` | Añade vínculo al reproductor y cierre por señal. |
| `addons/opendou/runtime/audio_event_manager.gd` | Nuevo ciclo por frame en orden estricto, con el paso «aplicar». |
| `addons/opendou/nodes/opendou_event_player_3d.gd` | Deja de reproducir por su cuenta; su reproductor pasa a ser la voz. Se retira el toggle de HRTF. |
| `addons/opendou/nodes/opendou_event_player_2d.gd` | Ídem, sin LPF por voz. |
| `addons/opendou/nodes/opendou_event_player.gd` | Ídem, sin espacialización. |
| `addons/opendou/editor/nodes/opendou_blend_graph_node.gd` | Añade `set_live_rtpc_progress()`. |
| `addons/opendou/editor/opendou_bank_panel.gd` | Añade `_on_add_stream_pressed()`. |
| `tests/test_game_syncs.gd` | `evaluate_fast` → `evaluate`. |
| `tests/test_all.gd` | Añade suite asíncrona y usa el contador real de aserciones. |
| `tests/test_runner_cli.gd` | Ejecuta la suite asíncrona y propaga el conteo real. |
| `README.md`, `addons/opendou/plugin.cfg` | Se retira la mención a HRTF. |
| `run_tests.ps1` | Pasa a envoltorio fino que delega en la misma lógica. |

---
## Bloque A — Infraestructura de verificación

Sin esto, ninguna tarea posterior es comprobable. La observación nº1 sobrevivió 58 tareas porque la suite no podía detectarla.

### Task 1: Runner que falla ante errores del motor

**Files:**
- Create: `tests/support/opendou_assert.gd`
- Create: `run_tests.sh`
- Create: `tests/leak_budget.txt`
- Modify: `run_tests.ps1` (pasa a envoltorio fino)
- Test: el propio `run_tests.sh` contra el baseline actual

**Interfaces:**
- Produces: `OpenDouAssert` con `ok(cond, label)`, `eq(actual, expected, label)`, `approx(actual, expected, label, tol=0.0001)`, `gt(actual, threshold, label)`, `lt(actual, threshold, label)`, `has_no_property(obj, name, label)`; propiedades `failures: Array[String]` y `assertions_run: int`. Todas las funciones de aserción devuelven `bool` (true si pasó) para permitir cortocircuitos.
- Produces: `run_tests.sh` con código de salida 0 solo si no hay `SCRIPT ERROR`, ni `Parse Error`, ni aumento de fugas.

**Nota de diseño — desviación deliberada de la spec.** La spec pide que el run falle si el log contiene `ObjectDB instances were leaked`. El baseline tiene **1015** fugas provenientes de los propios tests (crean `Node` y `Control` sin liberar). Exigir cero en la Fase 1 convertiría esta tarea en una limpieza de 109 archivos de test, que es trabajo de la Fase 4. En su lugar se implementa un **trinquete**: se registra el conteo actual como techo en `tests/leak_budget.txt` y el run falla si **aumenta**. Las fugas no pueden crecer, y llevarlas a cero queda para la Fase 4. `SCRIPT ERROR` y `Parse Error` sí son fatales de inmediato, sin trinquete.

- [ ] **Step 1: Escribe el helper de aserciones**

Crea `tests/support/opendou_assert.gd`:

```gdscript
class_name OpenDouAssert
extends RefCounted

## Acumulador de aserciones para la suite de OpenDou.
## Cuenta las aserciones realmente ejecutadas en lugar de confiar en un total
## escrito a mano, y registra cada fallo con su etiqueta y valores observados.

var failures: Array[String] = []
var assertions_run: int = 0

var _context: String = ""

func _init(p_context: String = "") -> void:
	_context = p_context

func _fail(msg: String) -> void:
	if _context.is_empty():
		failures.append(msg)
	else:
		failures.append("[%s] %s" % [_context, msg])

## Afirma que una condición es verdadera.
func ok(condition: bool, label: String) -> bool:
	assertions_run += 1
	if not condition:
		_fail("%s: se esperaba verdadero" % label)
		return false
	return true

## Afirma igualdad exacta.
func eq(actual: Variant, expected: Variant, label: String) -> bool:
	assertions_run += 1
	if actual != expected:
		_fail("%s: se esperaba %s, se obtuvo %s" % [label, str(expected), str(actual)])
		return false
	return true

## Afirma igualdad de flotantes con tolerancia.
func approx(actual: float, expected: float, label: String, tolerance: float = 0.0001) -> bool:
	assertions_run += 1
	if absf(actual - expected) > tolerance:
		_fail("%s: se esperaba %f +/- %f, se obtuvo %f" % [label, expected, tolerance, actual])
		return false
	return true

## Afirma que un valor supera un umbral.
func gt(actual: float, threshold: float, label: String) -> bool:
	assertions_run += 1
	if actual <= threshold:
		_fail("%s: se esperaba > %f, se obtuvo %f" % [label, threshold, actual])
		return false
	return true

## Afirma que un valor queda por debajo de un umbral.
func lt(actual: float, threshold: float, label: String) -> bool:
	assertions_run += 1
	if actual >= threshold:
		_fail("%s: se esperaba < %f, se obtuvo %f" % [label, threshold, actual])
		return false
	return true

## Afirma que un objeto NO expone una propiedad. Para verificar retiradas.
func has_no_property(obj: Object, prop_name: String, label: String) -> bool:
	assertions_run += 1
	if obj == null:
		_fail("%s: objeto nulo" % label)
		return false
	for p in obj.get_property_list():
		if String(p["name"]) == prop_name:
			_fail("%s: la propiedad '%s' debería haber sido retirada" % [label, prop_name])
			return false
	return true

## Fusiona el resultado de otro acumulador (para suites compuestas).
func absorb(other: OpenDouAssert) -> void:
	if other == null:
		return
	assertions_run += other.assertions_run
	failures.append_array(other.failures)
```

- [ ] **Step 2: Escribe el runner que detecta errores del motor**

Crea `run_tests.sh` y hazlo ejecutable:

```bash
#!/usr/bin/env bash
# Runner de tests de OpenDou. Multiplataforma (macOS / Linux).
# Falla si el log del motor contiene errores de script o de parseo, o si el
# número de fugas de ObjectDB aumenta respecto al techo registrado.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

TEST_SCRIPT="${1:-tests/test_runner_cli.gd}"
CONSOLE_LOG="test_console.log"
LEAK_BUDGET_FILE="tests/leak_budget.txt"

find_godot() {
	if [[ -n "${GODOT_PATH:-}" && -x "${GODOT_PATH}" ]]; then
		echo "${GODOT_PATH}"; return 0
	fi
	local candidates=(
		"/Applications/Godot.app/Contents/MacOS/Godot"
		"$HOME/Applications/Godot.app/Contents/MacOS/Godot"
		"$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
		"/opt/homebrew/bin/godot"
		"/usr/local/bin/godot"
		"/usr/bin/godot"
	)
	local c
	for c in "${candidates[@]}"; do
		[[ -x "$c" ]] && { echo "$c"; return 0; }
	done
	if command -v godot >/dev/null 2>&1; then
		command -v godot; return 0
	fi
	return 1
}

GODOT_BIN="$(find_godot)" || {
	echo "[ERROR] No se encontró Godot. Define GODOT_PATH apuntando al ejecutable." >&2
	exit 1
}

echo "[OpenDou] Godot: $GODOT_BIN"
echo "[OpenDou] Script: $TEST_SCRIPT"
"$GODOT_BIN" --headless --path . --script "$TEST_SCRIPT" > "$CONSOLE_LOG" 2>&1
GODOT_EXIT=$?

# Resultado reportado por la propia suite.
grep -E "^STATUS:" "$CONSOLE_LOG" || echo "[WARN] la suite no reportó STATUS"

FATAL=0

# 1) Errores de script y de parseo: fatales sin excepción.
#    Un error de script aborta la función que lo contiene y devuelve null, así
#    que un test puede "pasar" mientras el motor grita. Por eso son fatales.
SCRIPT_ERRORS=$(grep -c "SCRIPT ERROR" "$CONSOLE_LOG" || true)
PARSE_ERRORS=$(grep -c "Parse Error" "$CONSOLE_LOG" || true)
if [[ "$SCRIPT_ERRORS" -gt 0 ]]; then
	echo "[FALLO] $SCRIPT_ERRORS SCRIPT ERROR en el log:" >&2
	grep -n "SCRIPT ERROR" "$CONSOLE_LOG" | head -20 >&2
	FATAL=1
fi
if [[ "$PARSE_ERRORS" -gt 0 ]]; then
	echo "[FALLO] $PARSE_ERRORS Parse Error en el log:" >&2
	grep -n "Parse Error" "$CONSOLE_LOG" | head -20 >&2
	FATAL=1
fi

# 2) Trinquete de fugas de ObjectDB: no pueden aumentar.
LEAKED=$(grep -oE "[0-9]+ ObjectDB instances were leaked" "$CONSOLE_LOG" | grep -oE "^[0-9]+" | tail -1)
LEAKED="${LEAKED:-0}"
BUDGET=$(tr -d '[:space:]' < "$LEAK_BUDGET_FILE" 2>/dev/null || echo "0")
BUDGET="${BUDGET:-0}"
echo "[OpenDou] fugas ObjectDB: $LEAKED (techo: $BUDGET)"
if [[ "$LEAKED" -gt "$BUDGET" ]]; then
	echo "[FALLO] las fugas de ObjectDB aumentaron de $BUDGET a $LEAKED." >&2
	echo "         Libera lo que creaste, o justifica y actualiza $LEAK_BUDGET_FILE." >&2
	FATAL=1
fi

# 3) La suite debe haber reportado éxito.
if ! grep -q "^STATUS: PASSED" "$CONSOLE_LOG"; then
	echo "[FALLO] la suite no reportó STATUS: PASSED" >&2
	grep -E "^- " "$CONSOLE_LOG" | head -30 >&2
	FATAL=1
fi

if [[ "$FATAL" -ne 0 ]]; then
	echo "[OpenDou] RESULTADO: FALLO"
	exit 1
fi
if [[ "$GODOT_EXIT" -ne 0 ]]; then
	echo "[FALLO] Godot salió con código $GODOT_EXIT" >&2
	echo "[OpenDou] RESULTADO: FALLO"
	exit 1
fi
echo "[OpenDou] RESULTADO: OK"
exit 0
```

Luego: `chmod +x run_tests.sh`

- [ ] **Step 3: Registra el techo de fugas del baseline**

Ejecuta la suite una vez y extrae el conteo real:

```bash
/Users/Daniel/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_runner_cli.gd > /tmp/baseline.log 2>&1
grep -oE "[0-9]+ ObjectDB instances were leaked" /tmp/baseline.log | grep -oE "^[0-9]+" | tail -1 > tests/leak_budget.txt
cat tests/leak_budget.txt
```

Espera un número en torno a **1015**. Escribe exactamente el observado, sin redondear.

- [ ] **Step 4: Ejecuta el runner y verifica que FALLA**

Run: `./run_tests.sh`

Expected: **FALLO**, con la lista de 5 `SCRIPT ERROR`. Este es el rojo de esta tarea: el runner detecta lo que la suite ocultaba. Si sale OK, el runner no está funcionando — revisa los `grep`.

- [ ] **Step 5: Convierte `run_tests.ps1` en envoltorio fino**

Sustituye el cuerpo de `run_tests.ps1` por una versión que aplique las mismas tres comprobaciones. Mantén los parámetros `-TestScript`, `-GodotPath`, `-LogFile` para no romper el flujo existente en Windows, y añade al final las mismas verificaciones de `SCRIPT ERROR`, `Parse Error` y trinquete de fugas leyendo `tests/leak_budget.txt`.

- [ ] **Step 6: Commit**

```bash
git add tests/support/opendou_assert.gd run_tests.sh run_tests.ps1 tests/leak_budget.txt
git commit -m "test(infra): add assertion helper and runner that fails on engine errors

El runner detecta SCRIPT ERROR y Parse Error como fatales, y aplica un
trinquete a las fugas de ObjectDB para que no aumenten. Con el baseline
actual el runner falla, exponiendo los 5 SCRIPT ERROR que la suite
reportaba como 337/337 PASSED."
```

---

### Task 2: Resolver los 5 SCRIPT ERROR del baseline

**Files:**
- Modify: `tests/test_game_syncs.gd:22-24`
- Modify: `addons/opendou/editor/nodes/opendou_blend_graph_node.gd`
- Modify: `addons/opendou/editor/opendou_bank_panel.gd`
- Modify: `addons/opendou/runtime/voice_pool_manager.gd:123`

**Interfaces:**
- Consumes: `run_tests.sh` de la Tarea 1.
- Produces: `OpenDouBlendGraphNode.set_live_rtpc_progress(progress: float) -> void`; `OpenDouBankPanel._on_add_stream_pressed() -> void`; `VoicePoolManager.get_active_virtual_count(active_instances: Array) -> int` (parámetro sin tipar).

**Son 4 causas raíz, no 5.** El desajuste de array tipado aborta `AudioTelemetryCollector.collect_snapshot()`, que devuelve `null`, y de ahí sale el acceso a `physical_voices` sobre `Nil`. Arreglar el array arregla los dos.

- [ ] **Step 1: Ejecuta el runner y anota los 5 errores**

Run: `./run_tests.sh 2>&1 | grep "SCRIPT ERROR"`

Expected: 5 líneas. Guárdalas para comparar al final.

- [ ] **Step 2: Corrige la llamada al nombre inexistente `evaluate_fast`**

`RTPCBinding` **ya tiene la LUT O(1)**: `bake_lut()` la construye y `evaluate()` la consulta. Solo falla el nombre. En `tests/test_game_syncs.gd` líneas 22-24, sustituye:

```gdscript
	var lut_val_0 = binding.evaluate_fast(0.0)
	var lut_val_50 = binding.evaluate_fast(50.0)
	var lut_val_100 = binding.evaluate_fast(100.0)
```

por:

```gdscript
	var lut_val_0 = binding.evaluate(0.0)
	var lut_val_50 = binding.evaluate(50.0)
	var lut_val_100 = binding.evaluate(100.0)
```

No añadas un alias `evaluate_fast`: sería API muerta para mantener un nombre equivocado.

- [ ] **Step 3: Implementa `set_live_rtpc_progress` en el nodo de blend**

El test afirma que el nodo de blend muestra la posición del RTPC en vivo, y el método no existe. Añade al final de `addons/opendou/editor/nodes/opendou_blend_graph_node.gd`:

```gdscript
## Posición normalizada [0,1] del RTPC en vivo, dibujada como marcador sobre la
## curva de blend. La llama el editor cuando el servidor de Live Update reporta
## un cambio de parámetro.
var live_rtpc_progress: float = -1.0

## Fija la posición del marcador de RTPC en vivo. Un valor negativo lo oculta.
func set_live_rtpc_progress(progress: float) -> void:
	live_rtpc_progress = -1.0 if progress < 0.0 else clampf(progress, 0.0, 1.0)
	queue_redraw()
```

- [ ] **Step 4: Implementa `_on_add_stream_pressed` en el panel de bancos**

Sigue el patrón de los handlers existentes `_on_prefetch_changed` (línea 144) y `_on_compile_pressed` (línea 152). Añade:

```gdscript
## Añade una entrada de stream vacía a la lista de compilación del banco.
func _on_add_stream_pressed() -> void:
	var entry_id: int = pending_streams.size()
	pending_streams.append({
		"id": entry_id,
		"path": "",
		"prefetch_kb": int(prefetch_kb),
	})
	_refresh_stream_list()
```

Antes de escribirlo, **lee el archivo** para confirmar los nombres reales de `pending_streams`, `prefetch_kb` y el método de refresco de la lista. Si no existen, créalos con los nombres que use el panel; no inventes campos que no encajen con su estado.

- [ ] **Step 5: Quita el tipado del parámetro que rompe la telemetría**

En `addons/opendou/runtime/voice_pool_manager.gd:123`, cambia:

```gdscript
func get_active_virtual_count(active_instances: Array[EventInstance]) -> int:
```

por:

```gdscript
## Devuelve el número de voces virtuales activas.
## El parámetro va SIN tipar a propósito: AudioTelemetryCollector.collect_snapshot()
## reenvía aquí un Array genérico mediante call(), y un array tipado provocaría un
## error que abortaría la recolección entera y devolvería null.
func get_active_virtual_count(active_instances: Array) -> int:
```

El cuerpo no cambia: solo itera y consulta `voice_state`.

- [ ] **Step 6: Ejecuta el runner y verifica que ya no hay errores de script**

Run: `./run_tests.sh`

Expected: `[OpenDou] fugas ObjectDB: ... (techo: ...)` sin líneas `[FALLO] ... SCRIPT ERROR`. Si la suite reporta fallos de aserción nuevos, son reales: los errores estaban ocultando resultados. Arréglalos antes de seguir.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "fix(tests): resolve the 5 baseline SCRIPT ERROR (4 root causes)

- evaluate_fast -> evaluate: la LUT O(1) ya existía, solo fallaba el nombre
- set_live_rtpc_progress: implementado en OpenDouBlendGraphNode
- _on_add_stream_pressed: implementado en OpenDouBankPanel
- get_active_virtual_count: parámetro sin tipar, porque el array tipado
  abortaba collect_snapshot() y provocaba en cascada el acceso a
  physical_voices sobre Nil"
```

---

### Task 3: Tests sin efectos secundarios sobre el repo

**Files:**
- Modify: `addons/opendou/editor/opendou_game_syncs_panel.gd:659`
- Modify: `addons/opendou/runtime/synth/synth_preset_registry.gd:48`
- Modify: `tests/test_studio_advanced_ui.gd:190` y `:540`
- Test: `git status --porcelain` tras ejecutar la suite

**Interfaces:**
- Produces: `OpenDouGameSyncsPanel.syncs_file_path: String` (por defecto `SYNCS_FILE_PATH`) y `save_syncs_to_disk()` que lo respeta; `SynthPresetRegistry.save_presets(json_path)` invocable con ruta arbitraria (ya lo es).

Ejecutar la suite hoy **modifica datos versionados**: inyecta `RTPC_210` y `RTPC_211` en `opendou_syncs.json` y 102 líneas en `opendou_synth_presets.json`. Culpables exactos: `tests/test_studio_advanced_ui.gd:187` añade los RTPC en memoria, `:190` los persiste con `save_syncs_to_disk()`, y `:540` persiste los presets con `_on_save_presets_pressed()`.

Esta tarea **no** migra `res://` a `user://` en el addon: eso es la observación nº17 y pertenece a la Fase 4. Aquí solo se hace inyectable la ruta para que los tests no escriban en el repo.

- [ ] **Step 1: Escribe el test que demuestra la contaminación**

Añade a `tests/test_studio_advanced_ui.gd`, como primer test de su `run_all()`, una comprobación de que la ruta de guardado es inyectable:

```gdscript
	# Las rutas de persistencia deben ser inyectables para que los tests no
	# escriban en res:// y contaminen el repositorio.
	var syncs_probe = OpenDouGameSyncsPanelClass.new()
	var custom_path := "user://opendou_syncs_test.json"
	syncs_probe.syncs_file_path = custom_path
	if syncs_probe.syncs_file_path != custom_path:
		failures.append("Test 0 Failed: syncs_file_path no es inyectable")
	syncs_probe.free()
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO. `syncs_file_path` no existe todavía, así que habrá un `SCRIPT ERROR` por propiedad inexistente, que el runner de la Tarea 1 convierte en fatal.

- [ ] **Step 3: Haz inyectable la ruta del panel de syncs**

En `addons/opendou/editor/opendou_game_syncs_panel.gd`, junto a la constante existente `SYNCS_FILE_PATH` (línea 13), añade:

```gdscript
## Ruta de persistencia de los Game Syncs. Inyectable para que los tests no
## escriban en res://. Por defecto apunta a SYNCS_FILE_PATH.
var syncs_file_path: String = SYNCS_FILE_PATH
```

Y en `save_syncs_to_disk()` (línea 659) sustituye `SYNCS_FILE_PATH` por `syncs_file_path` en la llamada a `FileAccess.open`. Revisa el archivo por si `SYNCS_FILE_PATH` se usa también al cargar; si es así, usa `syncs_file_path` en ambos sitios para que carga y guardado sean coherentes.

- [ ] **Step 4: Redirige las escrituras de los tests**

En `tests/test_studio_advanced_ui.gd`, antes de la línea 190, fija la ruta al directorio de usuario:

```gdscript
	syncs_panel.syncs_file_path = "user://opendou_syncs_test.json"
	syncs_panel.save_syncs_to_disk()
```

Para la línea 540, localiza cómo `_on_save_presets_pressed()` obtiene su ruta. Si llama a `SynthPresetRegistry.save_presets()` con el valor por defecto, dale al panel una propiedad `presets_file_path` con el mismo patrón y pásala. `save_presets(json_path)` ya acepta ruta arbitraria, así que no hace falta tocar el registro.

- [ ] **Step 5: Ejecuta y verifica que pasa, con el árbol limpio**

```bash
git status --porcelain > /tmp/antes.txt
./run_tests.sh
git status --porcelain > /tmp/despues.txt
diff /tmp/antes.txt /tmp/despues.txt && echo "ARBOL LIMPIO"
```

Expected: `run_tests.sh` OK y `ARBOL LIMPIO`. Si `opendou_syncs.json` u `opendou_synth_presets.json` aparecen modificados, queda alguna ruta de escritura sin redirigir: busca más llamadas con `grep -rn "save_" tests/`.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "test(infra): stop tests from writing to versioned project data

Ejecutar la suite inyectaba RTPC_210/RTPC_211 en opendou_syncs.json y 102
líneas en opendou_synth_presets.json. La ruta de persistencia pasa a ser
inyectable y los tests escriben en user://. La migración de res:// a
user:// en el addon es la observación 17 y corresponde a la Fase 4."
```

---

### Task 4: Sonda de audio y suite asíncrona

**Files:**
- Create: `tests/support/audio_probe.gd`
- Modify: `tests/test_all.gd`
- Modify: `tests/test_runner_cli.gd`
- Test: `tests/test_audio_output.gd` (solo el primer test, la sonda contra sí misma)

**Interfaces:**
- Produces: `OpenDouAudioProbe` con `setup(buffer_length_sec := 2.0) -> int` (devuelve índice de bus), `bus_name() -> StringName`, `drain() -> void`, `drain_peak() -> float` (drena todo lo disponible y devuelve el pico de ese lote, sin avanzar frames), `measure_peak_over_frames(tree: SceneTree, frames := 12) -> float` (corrutina, hay que hacerle `await`), `measure_peak_db_over_frames(tree, frames) -> float`, `teardown() -> void`.
- Produces: `TestAll.run_async_suite(tree: SceneTree) -> Dictionary` con claves `total`, `failures`, `passed`.
- Consumes: `OpenDouAssert` de la Tarea 1.

Los tests de audio necesitan varios frames y por tanto `await`. La suite actual es síncrona (`static func run_all() -> Array[String]` invocada desde `_init()`). **Verificado que `await tree.process_frame` funciona dentro de `_init()` de un script que extiende `SceneTree`**, así que la suite asíncrona se añade al lado de la síncrona en lugar de reescribirla.

- [ ] **Step 1: Escribe el test que la sonda debe satisfacer**

Crea `tests/test_audio_output.gd`:

```gdscript
class_name TestAudioOutput
extends RefCounted

## Aserciones de audio REAL: miden lo que llega a la mezcla, no banderas internas.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")

## La sonda debe medir una señal conocida. Si esto falla, ninguna otra
## aserción de audio de la suite es fiable.
static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("audio_output")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	var player := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = float(AudioServer.get_mix_rate())
	gen.buffer_length = 0.2
	player.stream = gen
	player.bus = String(probe.bus_name())
	tree.root.add_child(player)
	await tree.process_frame
	player.play()
	await tree.process_frame

	var playback = player.get_stream_playback()
	if playback == null:
		a.ok(false, "el generador no devolvió playback")
		probe.teardown()
		player.queue_free()
		return a

	# Empuja un seno de amplitud 0.8 mientras se drena la sonda.
	var phase := 0.0
	var peak := 0.0
	for _f in range(20):
		var n: int = playback.get_frames_available()
		for _i in range(n):
			var s: float = sin(phase) * 0.8
			phase += TAU * 440.0 / gen.mix_rate
			playback.push_frame(Vector2(s, s))
		await tree.process_frame
		peak = maxf(peak, probe.drain_peak())

	a.approx(peak, 0.8, "pico de un seno de amplitud 0.8", 0.05)
	a.gt(peak, 0.05, "la sonda mide señal audible")

	probe.teardown()
	player.queue_free()
	return a
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO — `audio_probe.gd` no existe, así que el `preload` provoca error de parseo, que el runner marca como fatal.

- [ ] **Step 3: Escribe la sonda**

Crea `tests/support/audio_probe.gd`:

```gdscript
class_name OpenDouAudioProbe
extends RefCounted

## Sonda de audio para aserciones reales en modo headless.
## Crea un bus dedicado con un AudioEffectCapture y mide el pico de la señal que
## realmente llega a la mezcla.
##
## Verificado en Godot 4.7.2 con --headless: el driver Dummy SÍ mezcla, y la
## captura devuelve el pico correcto (0.8000 para un seno de amplitud 0.8).

const BUS_NAME: StringName = &"OpenDouTestProbe"

var bus_index: int = -1

var _capture: AudioEffectCapture = null

## Crea el bus de sonda con la captura insertada. Devuelve el índice del bus.
func setup(buffer_length_sec: float = 2.0) -> int:
	teardown()
	bus_index = AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, String(BUS_NAME))
	AudioServer.set_bus_send(bus_index, "Master")
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = buffer_length_sec
	AudioServer.add_bus_effect(bus_index, _capture, 0)
	return bus_index

## Nombre del bus al que deben enrutarse los reproductores bajo prueba.
func bus_name() -> StringName:
	return BUS_NAME

## Vacía la captura sin medir. Úsalo antes de empezar una medición para
## descartar la señal previa.
func drain() -> void:
	if _capture == null:
		return
	var avail: int = _capture.get_frames_available()
	if avail > 0:
		_capture.get_buffer(avail)

## Drena TODO lo disponible y devuelve el pico absoluto de ese lote.
##
## Drenar por completo es obligatorio: get_buffer() devuelve los frames MÁS
## ANTIGUOS, así que leer solo un trozo devolvería el silencio anterior al
## arranque del sonido y daría un falso 0.
func drain_peak() -> float:
	if _capture == null:
		return 0.0
	var avail: int = _capture.get_frames_available()
	if avail <= 0:
		return 0.0
	var peak: float = 0.0
	for v in _capture.get_buffer(avail):
		peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
	return peak

## Avanza n frames drenando cada uno, y devuelve el pico global observado.
## Es una corrutina: hay que hacerle await.
func measure_peak_over_frames(tree: SceneTree, frames: int = 12) -> float:
	var peak: float = 0.0
	for _i in range(maxi(1, frames)):
		await tree.process_frame
		peak = maxf(peak, drain_peak())
	return peak

## Igual que measure_peak_over_frames pero en dBFS. Devuelve -INF en silencio.
func measure_peak_db_over_frames(tree: SceneTree, frames: int = 12) -> float:
	var peak: float = await measure_peak_over_frames(tree, frames)
	if peak <= 0.0:
		return -INF
	return linear_to_db(peak)

## Elimina el bus de sonda y su captura.
func teardown() -> void:
	if bus_index >= 0 and bus_index < AudioServer.bus_count:
		AudioServer.remove_bus(bus_index)
	bus_index = -1
	_capture = null
```

- [ ] **Step 4: Conecta la suite asíncrona**

En `tests/test_all.gd`, añade al final, sin tocar `run_suite()`:

```gdscript
const TestAudioOutputClass = preload("res://tests/test_audio_output.gd")

## Suite asíncrona: tests que necesitan avanzar frames del SceneTree, como todas
## las aserciones de audio real. Se ejecuta después de la suite síncrona.
static func run_async_suite(tree: SceneTree) -> Dictionary:
	var acc := OpenDouAssertClass.new()
	acc.absorb(await TestAudioOutputClass.run_all_async(tree))
	return {
		"total": acc.assertions_run,
		"failures": acc.failures,
		"passed": acc.assertions_run - acc.failures.size(),
	}
```

Añade también `const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")` a la cabecera del archivo.

- [ ] **Step 5: Haz que el runner CLI ejecute ambas suites**

En `tests/test_runner_cli.gd`, sustituye el cuerpo de `_init()` para sumar ambas suites:

```gdscript
func _init() -> void:
	var res = TestAllClass.run_suite()
	var total: int = res["total"]
	var passed: int = res["passed"]
	var failures: Array = res["failures"]

	# Suite asíncrona (aserciones de audio real). Necesita frames del SceneTree.
	var async_res = await TestAllClass.run_async_suite(self)
	total += int(async_res["total"])
	passed += int(async_res["passed"])
	failures.append_array(async_res["failures"])
```

Deja intacto el resto de la función (la escritura de `test_results.log` y el `quit()`).

- [ ] **Step 6: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK, y el total ahora incluye las aserciones asíncronas. En el log debe verse `STATUS: PASSED` con un total mayor que 337.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "test(infra): add real audio probe and async test suite

AudioEffectCapture sobre un bus dedicado mide el pico que llega de verdad a
la mezcla. Verificado que el driver Dummy de --headless sí mezcla. Esta es la
clase de aserción que habría detectado el motor mudo desde el primer día."
```

---
## Bloque B — La cadena de audio

Aquí muere la observación nº1. Para los tests de este bloque usa
`AudioSynthesizer.create_tone(440.0, 2.0, 0.8, false)` como stream de prueba
(firma real: `create_tone(freq_hz := 440.0, duration_sec := 0.5, volume := 0.5, has_decay := true) -> AudioStreamWAV`).
El cuarto argumento en `false` evita el decaimiento, para que el pico sea estable
durante toda la medición.

### Task 5: Pool de reproductores nativos

**Files:**
- Create: `addons/opendou/runtime/native_player_pool.gd`
- Test: `tests/test_native_player_pool.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouNativePlayerPool extends Node` con `enum PlayerKind { NON_SPATIAL, SPATIAL_2D, SPATIAL_3D }`, `acquire(kind: int) -> Node` (null si se agotó el cupo), `release(player: Node) -> void`, `busy_count(kind: int) -> int`, `total_count(kind: int) -> int`, propiedad `max_players_per_kind: int`.
- Consumes: `OpenDouAssert`.

Los reproductores permanecen hijos del pool y se reposicionan asignando
`global_position`. **Nunca se reparentan**: reparentar cada frame sería costoso y
es la razón por la que el diseño los mantiene aquí.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_native_player_pool.gd`:

```gdscript
class_name TestNativePlayerPool
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("native_player_pool")

	var pool = NativePlayerPoolClass.new(3)

	# Crecimiento perezoso: nada existe hasta que se pide.
	a.eq(pool.total_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D), 0, "pool arranca vacío")

	var p1 = pool.acquire(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)
	a.ok(p1 is AudioStreamPlayer3D, "acquire 3D devuelve AudioStreamPlayer3D")
	a.eq(pool.busy_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D), 1, "una voz ocupada")

	var p2 = pool.acquire(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)
	var p3 = pool.acquire(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)
	a.eq(pool.busy_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D), 3, "tres voces ocupadas")

	# Cupo agotado: devuelve null en lugar de crecer sin límite.
	var p4 = pool.acquire(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)
	a.eq(p4, null, "acquire por encima del cupo devuelve null")

	# Liberar permite reutilizar, sin crear nodos nuevos.
	pool.release(p2)
	a.eq(pool.busy_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D), 2, "liberar reduce las ocupadas")
	var p5 = pool.acquire(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)
	a.eq(p5, p2, "acquire reutiliza el reproductor liberado")
	a.eq(pool.total_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D), 3, "no se crean nodos extra")

	# Los tres tipos son independientes.
	var n1 = pool.acquire(NativePlayerPoolClass.PlayerKind.NON_SPATIAL)
	a.ok(n1 is AudioStreamPlayer, "acquire no-espacial devuelve AudioStreamPlayer")
	var d1 = pool.acquire(NativePlayerPoolClass.PlayerKind.SPATIAL_2D)
	a.ok(d1 is AudioStreamPlayer2D, "acquire 2D devuelve AudioStreamPlayer2D")
	a.eq(pool.busy_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D), 3, "los tipos no comparten cupo")

	pool.free()
	return a
```

Registra la suite en `tests/test_all.gd` dentro de `run_suite()`, siguiendo el patrón existente pero usando el acumulador:

```gdscript
	var pool_res = TestNativePlayerPoolClass.run_all()
	total_tests += pool_res.assertions_run
	all_failures.append_array(pool_res.failures)
```

Y el `preload` correspondiente en la cabecera.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO por error de parseo (`native_player_pool.gd` no existe).

- [ ] **Step 3: Implementa el pool**

Crea `addons/opendou/runtime/native_player_pool.gd`:

```gdscript
class_name OpenDouNativePlayerPool
extends Node

## Pool de reproductores nativos de Godot para las voces anónimas de OpenDou.
##
## Existe porque post_event() sin nodo dedicado necesita algo que reproduzca de
## verdad. Los reproductores permanecen hijos de este nodo durante toda su vida y
## se reposicionan asignando global_position; nunca se reparentan, porque
## reparentar cada frame sería costoso.
##
## El crecimiento es perezoso y con cupo: acquire() devuelve null cuando se agota,
## en lugar de crear nodos sin límite.

enum PlayerKind {
	NON_SPATIAL, ## AudioStreamPlayer: UI, música, narración
	SPATIAL_2D,  ## AudioStreamPlayer2D
	SPATIAL_3D,  ## AudioStreamPlayer3D
}

## Cupo máximo de reproductores por tipo.
var max_players_per_kind: int = 64

var _free: Dictionary = {}
var _busy: Dictionary = {}

func _init(p_max_per_kind: int = 64) -> void:
	name = "OpenDouNativePlayerPool"
	max_players_per_kind = maxi(1, p_max_per_kind)
	for kind in [PlayerKind.NON_SPATIAL, PlayerKind.SPATIAL_2D, PlayerKind.SPATIAL_3D]:
		_free[kind] = []
		_busy[kind] = []

## Obtiene un reproductor libre del tipo pedido, creándolo si hace falta.
## Devuelve null si se alcanzó el cupo.
func acquire(kind: int) -> Node:
	if not _free.has(kind):
		return null
	var free_list: Array = _free[kind]
	var busy_list: Array = _busy[kind]
	var player: Node = null

	while not free_list.is_empty() and player == null:
		var candidate = free_list.pop_back()
		if is_instance_valid(candidate):
			player = candidate

	if player == null:
		if busy_list.size() >= max_players_per_kind:
			return null
		player = _instantiate(kind)
		add_child(player)

	busy_list.append(player)
	return player

## Devuelve un reproductor al pool, deteniéndolo antes.
func release(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	var kind: int = _kind_of(player)
	if kind < 0:
		return
	var busy_list: Array = _busy[kind]
	var idx: int = busy_list.find(player)
	if idx >= 0:
		busy_list.remove_at(idx)
	if player.has_method("stop"):
		player.stop()
	player.stream = null
	_free[kind].append(player)

## Número de reproductores actualmente asignados de un tipo.
func busy_count(kind: int) -> int:
	if not _busy.has(kind):
		return 0
	return (_busy[kind] as Array).size()

## Número total de reproductores instanciados de un tipo (libres + ocupados).
func total_count(kind: int) -> int:
	if not _busy.has(kind):
		return 0
	return (_busy[kind] as Array).size() + (_free[kind] as Array).size()

func _instantiate(kind: int) -> Node:
	match kind:
		PlayerKind.SPATIAL_3D:
			var p3 := AudioStreamPlayer3D.new()
			# Doppler nativo desactivado por defecto: OpenDou controla el pitch y
			# dejarlo activo produciría doble modulación.
			p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
			return p3
		PlayerKind.SPATIAL_2D:
			return AudioStreamPlayer2D.new()
		_:
			return AudioStreamPlayer.new()

func _kind_of(player: Node) -> int:
	if player is AudioStreamPlayer3D:
		return PlayerKind.SPATIAL_3D
	if player is AudioStreamPlayer2D:
		return PlayerKind.SPATIAL_2D
	if player is AudioStreamPlayer:
		return PlayerKind.NON_SPATIAL
	return -1
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Si el trinquete de fugas se queja, es porque el test no libera el pool: `pool.free()` debe liberar también sus hijos, que es el comportamiento de `Node.free()`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(runtime): add native player pool for anonymous voices

Pool de AudioStreamPlayer/2D/3D hijos del pool, con crecimiento perezoso y
cupo por tipo. Los reproductores no se reparentan nunca: se reposicionan."
```

---

### Task 6: `PhysicalVoiceChannel` reproduce de verdad

**Aquí muere la observación nº1.**

**Files:**
- Modify: `addons/opendou/runtime/physical_voice_channel.gd` (reescritura del cuerpo)
- Modify: `addons/opendou/runtime/event_instance.gd` (añade vínculo al reproductor)
- Test: `tests/test_audio_output.gd` (añade el segundo test)

**Interfaces:**
- Produces: `PhysicalVoiceChannel.bind(player: Node, owned_by_node: bool) -> void`, `play_stream(stream, start_offset, volume_db, pitch, bus_name) -> void` (firma conservada), `apply(volume_db: float, pitch: float, cutoff_hz: float, position: Vector3) -> void`, `stop_with_fade(fade_time_sec := 0.015) -> void`, `stop_immediate() -> void`, `process_fade(delta: float) -> void`, `get_player() -> Node`, propiedad `owned_by_node: bool`.
- Produces: `EventInstance.bind_player(player: Node) -> void`, `get_bound_player() -> Node` (null si no hay o dejó de ser válido).
- Consumes: `OpenDouAudioProbe`, `OpenDouNativePlayerPool`.

- [ ] **Step 1: Escribe el test que falla**

Añade a `tests/test_audio_output.gd` una segunda función, y llámala desde `run_all_async` con `a.absorb(...)`:

```gdscript
## Un canal físico vinculado a un reproductor real debe producir audio medible.
## Este es el test que la observación nº1 no habría pasado nunca.
static func run_channel_audio_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("channel_audio")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	var pool = NativePlayerPoolClass.new(4)
	tree.root.add_child(pool)
	await tree.process_frame

	var player = pool.acquire(NativePlayerPoolClass.PlayerKind.NON_SPATIAL)
	a.ok(player != null, "el pool entregó un reproductor")

	var tone := AudioSynthesizerClass.create_tone(440.0, 2.0, 0.8, false)
	a.gt(float(tone.get_length()), 0.5, "el tono de prueba tiene duración")

	var channel = PhysicalVoiceChannelClass.new(0)
	channel.bind(player, false)
	channel.play_stream(tone, 0.0, 0.0, 1.0, probe.bus_name())

	probe.drain()
	var peak: float = await probe.measure_peak_over_frames(tree, 20)
	a.gt(peak, 0.05, "el canal físico produce audio audible")

	# Detener debe silenciar de verdad.
	channel.stop_immediate()
	probe.drain()
	var peak_after: float = await probe.measure_peak_over_frames(tree, 10)
	a.lt(peak_after, 0.01, "tras stop_immediate el bus queda en silencio")

	pool.release(player)
	probe.teardown()
	pool.queue_free()
	return a
```

Añade a la cabecera del archivo:

```gdscript
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")
const PhysicalVoiceChannelClass = preload("res://addons/opendou/runtime/physical_voice_channel.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `el canal físico produce audio audible` con pico 0. Ese cero es la observación nº1 medida por primera vez. Además habrá `SCRIPT ERROR` por `bind()` inexistente, que el runner marca como fatal.

- [ ] **Step 3: Reescribe el canal físico**

Sustituye el contenido de `addons/opendou/runtime/physical_voice_channel.gd`:

```gdscript
class_name PhysicalVoiceChannel
extends RefCounted

## Un canal de voz física: envoltorio delgado sobre un reproductor nativo de Godot.
##
## Antes este objeto solo llevaba la contabilidad y no emitía nada. Ahora es dueño
## de la reproducción: play_stream() invoca play() de verdad sobre el reproductor,
## y apply() empuja los valores calculados una vez por frame.
##
## El reproductor puede ser de dos procedencias:
##  - propiedad de un nodo OpenDouEventPlayer* (owned_by_node = true), en cuyo caso
##    NO se toca su transform: lo posiciona el juego.
##  - anónimo del OpenDouNativePlayerPool (owned_by_node = false), reposicionado
##    cada frame desde la posición del emisor.

var channel_id: int = -1
var is_busy: bool = false
var assigned_instance_ref: WeakRef = null

## Verdadero si el reproductor pertenece a un nodo del usuario y no al pool.
var owned_by_node: bool = false

# Bus de mezcla destino en el AudioServer de Godot.
var target_bus: StringName = &"Master"

# Micro-fades para evitar chasquidos al robar o detener voces.
var is_fading_out: bool = false
var is_fading_in: bool = false
var fade_duration_sec: float = 0.015
var fade_timer: float = 0.0
var current_fade_gain: float = 1.0

var current_stream: AudioStream = null
var current_volume_db: float = 0.0
var current_pitch: float = 1.0
var playback_start_offset: float = 0.0

var _player: Node = null

func _init(p_channel_id: int = -1) -> void:
	channel_id = p_channel_id
	is_busy = false
	target_bus = &"Master"

## Vincula el canal a un reproductor nativo concreto.
func bind(player: Node, p_owned_by_node: bool) -> void:
	_player = player
	owned_by_node = p_owned_by_node

## Reproductor vinculado, o null si no hay o dejó de ser válido.
func get_player() -> Node:
	if _player != null and is_instance_valid(_player):
		return _player
	return null

## Fija el bus de mezcla destino.
func set_bus(p_bus: StringName) -> void:
	target_bus = p_bus if not p_bus.is_empty() else &"Master"

## Asigna el stream al reproductor vinculado y arranca la reproducción real.
func play_stream(stream: AudioStream, start_offset: float = 0.0, volume_db: float = 0.0, pitch: float = 1.0, bus_name: StringName = &"Master") -> void:
	current_stream = stream
	playback_start_offset = start_offset
	current_volume_db = volume_db
	current_pitch = pitch
	set_bus(bus_name)

	is_busy = true
	is_fading_out = false
	is_fading_in = true
	fade_duration_sec = 0.010
	fade_timer = 0.0
	current_fade_gain = 0.0

	var player := get_player()
	if player == null or stream == null:
		return
	if not player.is_inside_tree():
		return

	player.stream = stream
	if AudioServer.get_bus_index(String(target_bus)) != -1:
		player.bus = String(target_bus)
	# Se arranca con el fade en 0 y apply() sube la ganancia, así que el volumen
	# inicial se fija en el suelo para no soltar un chasquido.
	player.volume_db = -80.0
	player.pitch_scale = clampf(pitch, 0.01, 4.0)
	player.play(maxf(0.0, start_offset))

## Empuja los valores calculados al reproductor. Se llama una vez por frame.
func apply(volume_db: float, pitch: float, cutoff_hz: float, position: Vector3) -> void:
	var player := get_player()
	if player == null or not is_busy:
		return

	# El fade anti-click es un multiplicador de amplitud: se convierte a dB y se
	# suma. Sin el suelo de 0.0001, un fade en 0 daría -INF dB.
	var gain_db: float = linear_to_db(maxf(current_fade_gain, 0.0001))
	player.volume_db = clampf(volume_db + gain_db, -80.0, 24.0)
	player.pitch_scale = clampf(pitch, 0.01, 4.0)

	if player is AudioStreamPlayer3D:
		# attenuation_filter_cutoff_hz existe SOLO en 3D. Es el LPF de oclusión
		# por voz, y lo aplica Godot en C++.
		player.attenuation_filter_cutoff_hz = clampf(cutoff_hz, 20.0, 20000.0)
		if not owned_by_node:
			player.global_position = position
	elif player is AudioStreamPlayer2D:
		# En 2D no hay filtro por voz: la oclusión llega ya como atenuación de
		# volumen dentro de volume_db.
		if not owned_by_node:
			player.global_position = Vector2(position.x, position.y)

## Inicia un micro-fade de salida antes de liberar el canal.
func stop_with_fade(fade_time_sec: float = 0.015) -> void:
	if not is_busy:
		return
	fade_duration_sec = maxf(0.005, fade_time_sec)
	is_fading_out = true
	is_fading_in = false
	fade_timer = fade_duration_sec

## Detiene y libera el canal de inmediato.
func stop_immediate() -> void:
	var player := get_player()
	if player != null and player.has_method("stop"):
		player.stop()
	is_busy = false
	is_fading_out = false
	is_fading_in = false
	current_stream = null
	assigned_instance_ref = null
	current_fade_gain = 0.0

## Procesa los multiplicadores de fade de entrada y salida por frame.
func process_fade(delta: float) -> void:
	if not is_busy:
		return

	if is_fading_out:
		fade_timer -= delta
		current_fade_gain = clampf(fade_timer / fade_duration_sec, 0.0, 1.0)
		if fade_timer <= 0.0:
			stop_immediate()
	elif is_fading_in:
		fade_timer += delta
		current_fade_gain = clampf(fade_timer / fade_duration_sec, 0.0, 1.0)
		if fade_timer >= fade_duration_sec:
			is_fading_in = false
			current_fade_gain = 1.0
	else:
		current_fade_gain = 1.0
```

- [ ] **Step 4: Añade el vínculo al reproductor en `EventInstance`**

En `addons/opendou/runtime/event_instance.gd`, junto a las demás variables de estado de voz, añade:

```gdscript
## Reproductor nativo que esta instancia usa como voz física, si su emisor es un
## nodo OpenDouEventPlayer*. Null en las voces anónimas, que reciben uno del pool.
var bound_player_ref: WeakRef = null
```

Y como métodos públicos:

```gdscript
## Vincula esta instancia al reproductor de su nodo emisor.
func bind_player(player: Node) -> void:
	bound_player_ref = weakref(player) if player != null else null

## Reproductor vinculado, o null si no hay o el nodo ya no existe.
func get_bound_player() -> Node:
	if bound_player_ref == null:
		return null
	var p = bound_player_ref.get_ref()
	if p != null and is_instance_valid(p):
		return p
	return null
```

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK, con `el canal físico produce audio audible` en verde. **Es la primera vez que el proyecto demuestra que suena.**

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(runtime): make PhysicalVoiceChannel actually produce audio

play_stream() ahora invoca play() sobre un reproductor nativo real, y apply()
empuja volumen, pitch y cutoff cada frame. El canal distingue reproductores
propiedad de un nodo (no se les toca el transform) de los anónimos del pool.

Resuelve la observación 1. El test mide el pico en el bus y ya no es cero."
```

---

### Task 7: `VoicePoolManager` como asignador de permiso

**Files:**
- Modify: `addons/opendou/runtime/voice_pool_manager.gd`
- Test: `tests/test_voice_pool.gd` (amplía), `tests/test_audio_output.gd` (añade test de presupuesto)

**Interfaces:**
- Produces: `VoicePoolManager.set_player_pool(pool: OpenDouNativePlayerPool) -> void`, `devirtualize(instance) -> void` y `virtualize(instance) -> void` conservan firma, `process_channel_fades(delta: float) -> void`, `get_channel(channel_id: int) -> PhysicalVoiceChannel`.
- Consumes: `EventInstance.get_bound_player()`, `OpenDouNativePlayerPool.acquire/release`.

- [ ] **Step 1: Escribe el test que falla**

Añade a `tests/test_audio_output.gd`:

```gdscript
## Superado el presupuesto, las voces de menor prioridad se virtualizan y dejan
## de sonar; al liberarse presupuesto reanudan en su posición lógica.
static func run_budget_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("budget")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)
	var pool = NativePlayerPoolClass.new(4)
	tree.root.add_child(pool)
	await tree.process_frame

	# Presupuesto de UNA sola voz física.
	var vpool = VoicePoolManagerClass.new(1)
	vpool.set_player_pool(pool)

	var tone := AudioSynthesizerClass.create_tone(440.0, 3.0, 0.8, false)

	var near_def = AudioEventDefClass.new(&"Near", tone)
	near_def.target_bus = probe.bus_name()
	near_def.base_priority = 90.0
	var far_def = AudioEventDefClass.new(&"Far", tone)
	far_def.target_bus = probe.bus_name()
	far_def.base_priority = 10.0

	var near = EventInstanceClass.new(near_def)
	near.set_position(Vector3(1.0, 0.0, 0.0))
	near.max_distance = 100.0
	near.play()
	var far = EventInstanceClass.new(far_def)
	far.set_position(Vector3(80.0, 0.0, 0.0))
	far.max_distance = 100.0
	far.play()

	var instances: Array[EventInstance] = [near, far]
	vpool.resolve_voice_stealing(instances, Vector3.ZERO, 0.016)

	a.eq(near.voice_state, EventInstanceClass.VoiceState.STATE_PHYSICAL, "la voz cercana gana el permiso")
	a.eq(far.voice_state, EventInstanceClass.VoiceState.STATE_VIRTUAL, "la voz lejana queda virtual")
	a.eq(far.assigned_channel_id, -1, "la voz virtual no retiene canal")

	probe.teardown()
	pool.queue_free()
	return a
```

Añade los `preload` de `VoicePoolManagerClass`, `EventInstanceClass` y `AudioEventDefClass`.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO por `set_player_pool` inexistente.

- [ ] **Step 3: Adapta el pool manager**

En `addons/opendou/runtime/voice_pool_manager.gd`:

Añade el preload y la referencia al pool de reproductores:

```gdscript
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")

## Pool de reproductores nativos para las voces anónimas. Sin él, solo pueden
## sonar las voces cuyo emisor es un nodo OpenDouEventPlayer*.
var player_pool: OpenDouNativePlayerPool = null

## Inyecta el pool de reproductores nativos.
func set_player_pool(pool: OpenDouNativePlayerPool) -> void:
	player_pool = pool
```

Sustituye `devirtualize()` por:

```gdscript
## Pasa una instancia de virtual a física, consiguiéndole un reproductor real.
func devirtualize(instance: EventInstance) -> void:
	if not instance:
		return

	var free_ch_id: int = find_free_channel()
	if free_ch_id < 0:
		return

	# El reproductor puede venir del nodo emisor o del pool anónimo.
	var player: Node = instance.get_bound_player()
	var owned_by_node: bool = player != null
	if player == null:
		if player_pool == null:
			return
		player = player_pool.acquire(_kind_for_instance(instance))
		if player == null:
			return

	var voices = instance.definition.resolve_voices() if instance.definition else []
	var stream = voices[0].stream if not voices.is_empty() else (instance.definition.base_stream if instance.definition else null)
	if stream == null:
		if not owned_by_node and player_pool != null:
			player_pool.release(player)
		return

	var start_offset: float = 0.0
	if instance.virtualization_mode == AudioEventDefClass.VirtualizationMode.VIRTUAL_ELAPSED_TIME:
		start_offset = instance.logical_playback_position
		# Sin el módulo, un ambiente virtualizado 3 minutos intentaría arrancar
		# en el segundo 180 de un loop de 4 segundos y no sonaría.
		var length: float = instance.definition.stream_length if instance.definition else 0.0
		if length <= 0.0:
			length = float(stream.get_length())
		if instance.definition != null and instance.definition.is_looping and length > 0.0:
			start_offset = fmod(start_offset, length)
		elif length > 0.0:
			start_offset = clampf(start_offset, 0.0, maxf(0.0, length - 0.001))

	instance.assigned_channel_id = free_ch_id
	instance.voice_state = EventInstanceClass.VoiceState.STATE_PHYSICAL

	var ch: PhysicalVoiceChannel = channels[free_ch_id]
	ch.assigned_instance_ref = weakref(instance)
	ch.bind(player, owned_by_node)

	var bus_name: StringName = instance.definition.target_bus if instance.definition else &"Master"
	ch.play_stream(stream, start_offset, instance.calculated_volume_db, instance.calculated_pitch_scale, bus_name)
```

Sustituye `virtualize()` por:

```gdscript
## Pasa una instancia a virtual y libera su canal y su reproductor.
func virtualize(instance: EventInstance) -> void:
	if not instance:
		return

	if instance.assigned_channel_id >= 0 and instance.assigned_channel_id < channels.size():
		var ch: PhysicalVoiceChannel = channels[instance.assigned_channel_id]
		var player: Node = ch.get_player()
		var was_owned: bool = ch.owned_by_node
		ch.stop_immediate()
		ch.bind(null, false)
		# Los reproductores anónimos vuelven al pool; los del nodo se quedan
		# donde están, porque no son nuestros.
		if not was_owned and player != null and player_pool != null:
			player_pool.release(player)
		instance.assigned_channel_id = -1

	if instance.virtualization_mode == AudioEventDefClass.VirtualizationMode.VIRTUAL_KILL_VOICE:
		instance.voice_state = EventInstanceClass.VoiceState.STATE_KILLED
	else:
		instance.voice_state = EventInstanceClass.VoiceState.STATE_VIRTUAL
```

Añade los dos helpers:

```gdscript
## Procesa los fades de todos los canales ocupados.
func process_channel_fades(delta: float) -> void:
	for ch in channels:
		ch.process_fade(delta)

## Canal por índice, o null si el índice no es válido.
func get_channel(channel_id: int) -> PhysicalVoiceChannel:
	if channel_id < 0 or channel_id >= channels.size():
		return null
	return channels[channel_id]

func _kind_for_instance(instance: EventInstance) -> int:
	# Una instancia con posición espacial suena en 3D; sin ella, no espacial.
	if instance.has_spatial_position:
		return NativePlayerPoolClass.PlayerKind.SPATIAL_3D
	return NativePlayerPoolClass.PlayerKind.NON_SPATIAL
```

En `resolve_voice_stealing()`, sustituye el bucle inicial `for ch in channels: ch.process_fade(delta)` por `process_channel_fades(delta)`.

- [ ] **Step 4: Expón el pool también en el manager**

La Tarea 8 necesita inyectar el pool desde los tests, así que el punto de entrada
se define aquí y no más adelante. En `addons/opendou/runtime/audio_event_manager.gd`:

```gdscript
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")

## Pool de reproductores nativos para las voces anónimas.
var player_pool: OpenDouNativePlayerPool = null

## Inyecta un pool de reproductores. Si nadie lo inyecta, _ready() crea uno propio.
func set_player_pool(pool: OpenDouNativePlayerPool) -> void:
	player_pool = pool
	if voice_pool != null:
		voice_pool.set_player_pool(pool)
```

Y en `_ready()`, crea uno si no se inyectó:

```gdscript
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if player_pool == null:
		player_pool = NativePlayerPoolClass.new(64)
		add_child(player_pool)
	voice_pool.set_player_pool(player_pool)
```

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Si `tests/test_voice_pool.gd` falla, revisa qué afirmaba: los tests que daban por bueno el comportamiento simulado tienen que actualizarse, y eso es trabajo esperado, no regresión.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(runtime): turn VoicePoolManager into a permission allocator

devirtualize() consigue un reproductor real: el del nodo emisor si lo tiene, o
uno anónimo del pool. virtualize() lo libera. La reanudación de loops aplica
fmod sobre la longitud del stream."
```

---

### Task 8: Las voces terminan de verdad

**Resuelve la observación nº6.**

**Files:**
- Modify: `addons/opendou/runtime/event_instance.gd`
- Modify: `addons/opendou/runtime/voice_pool_manager.gd` (conecta la señal)
- Test: `tests/test_audio_output.gd`

**Interfaces:**
- Produces: `EventInstance.notify_stream_finished() -> void`.

Hoy `advance_virtual_time()` sale temprano si el estado no es `STATE_VIRTUAL`, así que una voz física nunca avanza su posición lógica y nunca detecta el fin del stream: `is_finished()` es siempre falso y `active_instances` crece sin límite. Con 64 voces el pool queda ocupado para siempre.

- [ ] **Step 1: Escribe el test que falla**

Añade a `tests/test_audio_output.gd`:

```gdscript
## Una voz cuyo stream termina debe salir de active_instances. Sin esto, la lista
## crece de forma monótona y el pool queda ocupado permanentemente.
static func run_lifecycle_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("lifecycle")

	var pool = NativePlayerPoolClass.new(8)
	tree.root.add_child(pool)
	var manager = AudioEventManagerClass.new()
	manager.set_player_pool(pool)
	tree.root.add_child(manager)
	await tree.process_frame

	# Tono muy corto para que termine dentro del test.
	var tone := AudioSynthesizerClass.create_tone(660.0, 0.12, 0.8, false)
	var def = AudioEventDefClass.new(&"Blip", tone)
	def.stream_length = float(tone.get_length())
	def.is_looping = false

	manager.register_event_definition(def)
	for _i in range(20):
		manager.post_event(&"Blip", null)

	a.eq(manager.active_instances.size(), 20, "las 20 instancias entran en la lista")

	# Deja pasar tiempo suficiente para que todas terminen.
	for _f in range(90):
		await tree.process_frame

	a.lt(float(manager.active_instances.size()), 20.0, "la lista se vacía al terminar los streams")
	a.eq(manager.active_instances.size(), 0, "no queda ninguna instancia colgada")

	manager.queue_free()
	pool.queue_free()
	return a
```

Añade el `preload` de `AudioEventManagerClass`.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `la lista se vacía al terminar los streams` con 20 instancias colgadas. Ésa es la observación nº6 medida.

- [ ] **Step 3: Añade el cierre por señal en `EventInstance`**

En `addons/opendou/runtime/event_instance.gd`:

```gdscript
## Notifica que el reproductor nativo emitió `finished`.
##
## Es la fuente de verdad del fin de reproducción: un stream físico no avanza su
## posición lógica (eso solo lo hacen las voces virtuales), así que sin esta señal
## la instancia nunca sabría que acabó.
func notify_stream_finished() -> void:
	if not is_key_on or modulator_states.is_empty():
		voice_state = VoiceState.STATE_STOPPED
		assigned_channel_id = -1
		return
	# Con moduladores activos se entra en fase de release y update_parameters()
	# concluirá cuando el AHDSR llegue a IDLE.
	is_key_on = false
```

- [ ] **Step 4: Conecta la señal al desvirtualizar**

En `devirtualize()` de `voice_pool_manager.gd`, justo después de `ch.bind(player, owned_by_node)`, añade:

```gdscript
	# La señal `finished` es la única fuente fiable del fin de reproducción.
	# Se conecta en modo ONE_SHOT para que no se acumulen conexiones al
	# virtualizar y desvirtualizar repetidamente.
	if player.has_signal("finished"):
		var cb := Callable(instance, "notify_stream_finished")
		if not player.is_connected("finished", cb):
			player.connect("finished", cb, CONNECT_ONE_SHOT)
```

Y en `virtualize()`, antes de `ch.stop_immediate()`, desconecta para que un `stop()` provocado por nosotros no se confunda con el fin natural:

```gdscript
		if player != null and player.has_signal("finished"):
			var cb := Callable(instance, "notify_stream_finished")
			if player.is_connected("finished", cb):
				player.disconnect("finished", cb)
```

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK, con `no queda ninguna instancia colgada` en verde.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix(runtime): close voices on the finished signal

Una voz física no avanza su posición lógica, así que nunca detectaba el fin
del stream: active_instances crecía sin límite y el pool quedaba ocupado para
siempre. Ahora la señal finished del reproductor cierra la instancia.

Resuelve la observación 6."
```

---

### Task 9: El ciclo por frame aplica los valores calculados

**Resuelve la observación nº4.**

**Files:**
- Modify: `addons/opendou/runtime/audio_event_manager.gd`
- Test: `tests/test_audio_output.gd`

**Interfaces:**
- Produces: `AudioEventManager.set_player_pool(pool) -> void`, `player_pool: OpenDouNativePlayerPool`, `_apply_voices() -> void` (privado, invocado desde `_process`).
- Consumes: `PhysicalVoiceChannel.apply()`, `VoicePoolManager.get_channel()`.

- [ ] **Step 1: Escribe el test que falla**

Añade a `tests/test_audio_output.gd`:

```gdscript
## Un RTPC ligado a volumen debe mover el pico medido. Sin el paso «aplicar»,
## calculated_volume_db cambia y la salida no se entera.
static func run_rtpc_affects_output_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("rtpc_output")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)
	var pool = NativePlayerPoolClass.new(4)
	tree.root.add_child(pool)
	var manager = AudioEventManagerClass.new()
	manager.set_player_pool(pool)
	tree.root.add_child(manager)
	await tree.process_frame

	var tone := AudioSynthesizerClass.create_tone(440.0, 4.0, 0.8, false)
	var def = AudioEventDefClass.new(&"Sustained", tone)
	def.target_bus = probe.bus_name()
	def.stream_length = float(tone.get_length())
	def.is_looping = true
	def.base_volume_db = 0.0
	manager.register_event_definition(def)

	var inst = manager.post_event(&"Sustained", null)
	a.ok(inst != null, "post_event devuelve una instancia")

	probe.drain()
	var loud: float = await probe.measure_peak_over_frames(tree, 25)
	a.gt(loud, 0.05, "a volumen base el evento suena")

	# Bajar el volumen base debe reflejarse en la salida.
	inst.definition.base_volume_db = -40.0
	for _f in range(10):
		await tree.process_frame
	probe.drain()
	var quiet: float = await probe.measure_peak_over_frames(tree, 25)
	a.lt(quiet, loud * 0.5, "al bajar 40 dB el pico medido cae")

	probe.teardown()
	manager.queue_free()
	pool.queue_free()
	return a
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `al bajar 40 dB el pico medido cae`: el volumen se recalcula pero nadie lo empuja al reproductor. Es la observación nº4.

- [ ] **Step 3: Añade el paso «aplicar» al manager**

`player_pool` y `set_player_pool()` ya existen desde la Tarea 7, Step 4. Aquí solo
se añade la aplicación por frame y el reorden del ciclo.

Añade el método de aplicación a `addons/opendou/runtime/audio_event_manager.gd`:

```gdscript
## Empuja los valores calculados de cada voz física a su reproductor nativo.
##
## Este paso es el que faltaba: sin él, calculated_volume_db, calculated_pitch_scale
## y el cutoff de oclusión se calculan cada frame y no afectan a ningún sonido.
func _apply_voices() -> void:
	if voice_pool == null:
		return
	for instance in active_instances:
		if instance == null or instance.assigned_channel_id < 0:
			continue
		var ch = voice_pool.get_channel(instance.assigned_channel_id)
		if ch == null or not ch.is_busy:
			continue
		var cutoff: float = float(instance.calculated_properties.get(&"cutoff_hz", 20000.0))
		ch.apply(
			instance.calculated_volume_db,
			instance.calculated_pitch_scale,
			cutoff,
			instance.emitter_position
		)
```

Reordena `_process(delta)` al orden estricto de la spec. El paso 1 (listener) se
completa en la Tarea 10; aquí deja la llamada preparada:

```gdscript
func _process(delta: float) -> void:
	# 1. Resolver el oyente. Todo lo que dependa de distancia va DESPUÉS.
	_update_listener()

	# 2. Live Update remoto.
	if live_update_server and live_update_server.is_server_running:
		live_update_server.poll()
		live_update_server.dispatch_commands(event_registry, sync_manager)

	# 3. Game Syncs.
	if sync_manager:
		sync_manager.process(delta)

	# 4. Parámetros de instancia y limpieza de terminadas.
	for i in range(active_instances.size() - 1, -1, -1):
		var instance: EventInstance = active_instances[i]
		instance.interpolate_locals(delta)
		var global_rtpcs = sync_manager.global_rtpcs if sync_manager else {}
		instance.update_parameters(delta, global_rtpcs)
		if instance.is_finished():
			if voice_pool and instance.assigned_channel_id >= 0:
				voice_pool.virtualize(instance)
			active_instances.remove_at(i)

	# 5. Asignar permiso: quién es audible dentro del presupuesto.
	if voice_pool:
		voice_pool.resolve_voice_stealing(active_instances, active_listener_position, delta)

	# 6. Aplicar los valores calculados a los reproductores reales.
	_apply_voices()

	# 7. Telemetría.
	if live_update_server and live_update_server.is_server_running:
		var phys_count = voice_pool.get_active_physical_count() if voice_pool else 0
		var virt_count = voice_pool.get_active_virtual_count(active_instances) if voice_pool else 0
		live_update_server.send_telemetry(phys_count, virt_count, active_instances.size())
```

Añade el stub del listener, que la Tarea 10 sustituye:

```gdscript
## Actualiza la posición del oyente. La Tarea 10 lo sustituye por la resolución
## completa mediante OpenDouListenerResolver.
func _update_listener() -> void:
	pass
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK, con `al bajar 40 dB el pico medido cae` en verde.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(runtime): apply calculated values to real players each frame

Nuevo paso en el ciclo por frame que empuja calculated_volume_db,
calculated_pitch_scale y el cutoff de oclusión al reproductor nativo, con el
fade anti-click como multiplicador de amplitud. El ciclo pasa al orden
estricto de la spec.

Resuelve la observación 4."
```

---
## Bloque C — Corrección espacial y retirada de promesas

### Task 10: Resolución del oyente

**Resuelve la observación nº5.**

**Files:**
- Create: `addons/opendou/runtime/listener_resolver.gd`
- Modify: `addons/opendou/runtime/audio_event_manager.gd`
- Test: `tests/test_listener_resolver.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouListenerResolver` con `resolve(viewport: Viewport) -> bool`, `set_listener_node(node: Node3D) -> void`, `set_listener_position(pos: Vector3) -> void`, `clear_override() -> void`, y propiedades `position: Vector3`, `basis: Basis`, `source: StringName`.
- Produces: `AudioEventManager.listener_resolver: OpenDouListenerResolver`, `set_listener_node(node) -> void`, y `set_listener_position(pos)` conservada.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_listener_resolver.gd`:

```gdscript
class_name TestListenerResolver
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const ListenerResolverClass = preload("res://addons/opendou/runtime/listener_resolver.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("listener_resolver")
	var r = ListenerResolverClass.new()

	# Sin viewport ni override no hay oyente, y se dice explícitamente.
	a.eq(r.resolve(null), false, "sin fuentes no resuelve")
	a.eq(r.source, &"none", "la fuente se reporta como none")

	# La Camera3D activa es el oyente por defecto, como en Godot.
	var cam := Camera3D.new()
	cam.position = Vector3(5.0, 2.0, -3.0)
	tree.root.add_child(cam)
	cam.make_current()
	await tree.process_frame
	a.eq(r.resolve(tree.root), true, "resuelve con cámara activa")
	a.eq(r.source, &"camera_3d", "la fuente es la cámara")
	a.approx(r.position.x, 5.0, "toma la X de la cámara")

	# Un AudioListener3D activo tiene prioridad sobre la cámara.
	var listener := AudioListener3D.new()
	listener.position = Vector3(-9.0, 1.0, 0.0)
	tree.root.add_child(listener)
	listener.make_current()
	await tree.process_frame
	a.eq(r.resolve(tree.root), true, "resuelve con AudioListener3D")
	a.eq(r.source, &"audio_listener_3d", "el AudioListener3D gana a la cámara")
	a.approx(r.position.x, -9.0, "toma la X del AudioListener3D")

	# El override explícito gana a todo.
	r.set_listener_position(Vector3(100.0, 0.0, 0.0))
	a.eq(r.resolve(tree.root), true, "resuelve con override de posición")
	a.eq(r.source, &"override_position", "el override tiene prioridad máxima")
	a.approx(r.position.x, 100.0, "toma la X del override")

	r.clear_override()
	a.eq(r.resolve(tree.root), true, "tras limpiar vuelve a la regla de Godot")
	a.eq(r.source, &"audio_listener_3d", "vuelve al AudioListener3D")

	listener.queue_free()
	cam.queue_free()
	return a
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh` → FALLO por archivo inexistente.

- [ ] **Step 3: Implementa el resolutor**

Crea `addons/opendou/runtime/listener_resolver.gd`:

```gdscript
class_name OpenDouListenerResolver
extends RefCounted

## Determina la posición y la orientación del oyente.
##
## Replica la regla de Godot en lugar de inventar una propia: el AudioListener3D
## activo del viewport y, en su defecto, la Camera3D activa. Un override explícito
## tiene prioridad sobre ambos, para juegos con el oyente desacoplado de la cámara.
##
## Existe porque nadie invocaba set_listener_position() y active_listener_position
## se quedaba en Vector3.ZERO de forma permanente: el voice-stealing medía
## distancias desde el origen del mundo y el rayo de oclusión apuntaba a (0,0,0).

var position: Vector3 = Vector3.ZERO
var basis: Basis = Basis.IDENTITY

## De dónde se resolvió: &"override_position", &"override_node",
## &"audio_listener_3d", &"camera_3d" o &"none".
var source: StringName = &"none"

var _override_node_ref: WeakRef = null
var _override_position: Vector3 = Vector3.ZERO
var _has_override_position: bool = false

## Fija un nodo como oyente explícito. Pasar null lo desactiva.
func set_listener_node(node: Node3D) -> void:
	_override_node_ref = weakref(node) if node != null else null
	if node != null:
		_has_override_position = false

## Fija una posición fija de oyente. Tiene prioridad sobre todo lo demás.
func set_listener_position(pos: Vector3) -> void:
	_override_position = pos
	_has_override_position = true
	_override_node_ref = null

## Elimina cualquier override y vuelve a la regla de Godot.
func clear_override() -> void:
	_override_node_ref = null
	_has_override_position = false

## Resuelve el oyente para este frame. Devuelve true si encontró alguno.
func resolve(viewport: Viewport) -> bool:
	if _has_override_position:
		position = _override_position
		basis = Basis.IDENTITY
		source = &"override_position"
		return true

	if _override_node_ref != null:
		var n = _override_node_ref.get_ref()
		if n != null and is_instance_valid(n) and n is Node3D and n.is_inside_tree():
			position = n.global_position
			basis = n.global_transform.basis
			source = &"override_node"
			return true

	if viewport != null:
		var listener := viewport.get_audio_listener_3d()
		if listener != null and is_instance_valid(listener) and listener.is_inside_tree():
			position = listener.global_position
			basis = listener.global_transform.basis
			source = &"audio_listener_3d"
			return true
		var cam := viewport.get_camera_3d()
		if cam != null and is_instance_valid(cam) and cam.is_inside_tree():
			position = cam.global_position
			basis = cam.global_transform.basis
			source = &"camera_3d"
			return true

	source = &"none"
	return false
```

- [ ] **Step 4: Conéctalo al manager**

En `audio_event_manager.gd` añade el preload, créalo en `_init()` y sustituye el stub:

```gdscript
const ListenerResolverClass = preload("res://addons/opendou/runtime/listener_resolver.gd")

## Resolutor del oyente activo.
var listener_resolver: OpenDouListenerResolver = null
```

En `_init()`: `listener_resolver = ListenerResolverClass.new()`

Sustituye `_update_listener()`:

```gdscript
## Resuelve el oyente del frame y actualiza la posición cacheada.
func _update_listener() -> void:
	if listener_resolver == null or not is_inside_tree():
		return
	if listener_resolver.resolve(get_viewport()):
		active_listener_position = listener_resolver.position
```

Y añade el paso a la API pública, respetando la API existente:

```gdscript
## Fija un nodo como oyente explícito.
func set_listener_node(node: Node3D) -> void:
	if listener_resolver != null:
		listener_resolver.set_listener_node(node)
```

Modifica `set_listener_position()` para que delegue en el resolutor y siga
funcionando como override:

```gdscript
## Fija una posición fija de oyente, con prioridad sobre la regla automática.
func set_listener_position(pos: Vector3) -> void:
	active_listener_position = pos
	if listener_resolver != null:
		listener_resolver.set_listener_position(pos)
```

Registra la suite asíncrona en `run_async_suite()` de `tests/test_all.gd`.

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh` → OK.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix(runtime): resolve the active listener instead of assuming origin

Replica la regla de Godot (AudioListener3D activo, en su defecto Camera3D
activa) con override explícito. Antes active_listener_position se quedaba en
Vector3.ZERO para siempre: el voice-stealing medía desde el origen del mundo y
el rayo de oclusión apuntaba a (0,0,0).

Resuelve la observación 5."
```

---

### Task 11: Los nodos emisores son dueños de su voz

**Resuelve la observación nº3.**

**Files:**
- Modify: `addons/opendou/nodes/opendou_event_player_3d.gd`
- Modify: `addons/opendou/nodes/opendou_event_player_2d.gd`
- Modify: `addons/opendou/nodes/opendou_event_player.gd`
- Test: `tests/test_audio_output.gd`

**Interfaces:**
- Consumes: `EventInstance.bind_player()` de la Tarea 6.
- Los tres nodos conservan `play_event()`, `stop_event()`, `set_rtpc()`, `set_switch()`, `set_state()`, `set_event_manager()` y `get_calculated_occlusion()` con las mismas firmas.

- [ ] **Step 1: Escribe el test que falla**

Añade a `tests/test_audio_output.gd`:

```gdscript
## Un emisor declarativo debe producir UNA voz, no dos. Antes creaba un
## EventInstance y además llamaba a su propio play(), duplicando la reproducción.
static func run_single_voice_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("single_voice")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)
	var pool = NativePlayerPoolClass.new(8)
	tree.root.add_child(pool)
	var manager = AudioEventManagerClass.new()
	manager.set_player_pool(pool)
	tree.root.add_child(manager)
	await tree.process_frame

	var tone := AudioSynthesizerClass.create_tone(440.0, 4.0, 0.5, false)
	var def = AudioEventDefClass.new(&"EmitterTone", tone)
	def.target_bus = probe.bus_name()
	def.stream_length = float(tone.get_length())
	def.is_looping = true

	var emitter = OpenDouEventPlayer3DClass.new()
	emitter.event_def = def
	emitter.set_event_manager(manager)
	tree.root.add_child(emitter)
	await tree.process_frame

	var busy_before: int = pool.busy_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)
	emitter.play_event()
	for _f in range(6):
		await tree.process_frame

	# La voz sale del propio nodo, no del pool anónimo.
	a.eq(pool.busy_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D), busy_before,
		"el emisor no consume una voz anónima del pool")
	a.eq(manager.active_instances.size(), 1, "una sola instancia activa")
	a.ok(emitter.active_instance != null, "el emisor guarda su instancia")
	a.eq(emitter.active_instance.get_bound_player(), emitter, "la instancia está vinculada al propio emisor")

	# El toggle de HRTF debe haber desaparecido: no se puede cumplir.
	a.has_no_property(emitter, "enable_binaural_hrtf", "toggle de HRTF retirado")

	probe.teardown()
	emitter.queue_free()
	manager.queue_free()
	pool.queue_free()
	return a
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `la instancia está vinculada al propio emisor` y en `toggle de HRTF retirado`.

- [ ] **Step 3: Modifica `opendou_event_player_3d.gd`**

Tres cambios quirúrgicos:

**a)** Elimina el toggle imposible. Borra la línea:

```gdscript
@export var enable_binaural_hrtf: bool = true
```

**b)** En `play_event()`, **borra** el bloque final que provocaba la doble reproducción:

```gdscript
	if stream != null and is_inside_tree():
		play(0.0)
```

**c)** Dentro de `play_event()`, en el bloque `if active_instance != null:`, añade el vínculo justo antes de aplicar los RTPC:

```gdscript
		# El reproductor de este nodo ES la voz física. Vincularlo evita que el
		# pool asigne una voz anónima adicional, que era la doble reproducción.
		active_instance.bind_player(self)
```

**d)** En `_ready()`, sustituye la rama de autoplay nativo por la del evento, para
que no haya dos caminos de arranque:

```gdscript
func _ready() -> void:
	if not Engine.is_editor_hint():
		if stream == null and synth_preset != "None":
			_apply_synth_preset()
		elif stream == null and not event_name.is_empty():
			_auto_infer_synth_preset()

		if auto_play_event or (autoplay and stream != null):
			play_event()
```

- [ ] **Step 4: Aplica los mismos cambios a 2D y no espacial**

En `opendou_event_player_2d.gd` y `opendou_event_player.gd`, repite (b), (c) y (d).
No tienen `enable_binaural_hrtf`, así que (a) no aplica. Verifica leyendo cada
archivo que el bloque de doble reproducción sea idéntico; si difiere, adáptalo sin
cambiar el resto de la lógica.

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh` → OK.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "fix(nodes): emitter players own their voice instead of double-playing

Antes cada OpenDouEventPlayer* creaba un EventInstance y ADEMÁS llamaba a su
propio play(): dos reproducciones simultáneas del mismo sonido. Ahora el
reproductor del nodo es la voz física y la instancia queda vinculada a él.

Retira también enable_binaural_hrtf, imposible de cumplir en esta arquitectura.

Resuelve la observación 3 y parte de la 12."
```

---

### Task 12: Oclusión centralizada y presupuestada

**Resuelve la observación nº8.**

**Files:**
- Create: `addons/opendou/runtime/spatial/occlusion_scheduler.gd`
- Modify: `addons/opendou/runtime/audio_event_manager.gd`
- Modify: `addons/opendou/nodes/opendou_event_player_3d.gd`
- Test: `tests/test_occlusion_scheduler.gd`

**Interfaces:**
- Produces: `OpenDouOcclusionScheduler` con `process(instances: Array, listener_pos: Vector3, world_3d: World3D) -> int` (devuelve raycasts lanzados), propiedades `raycasts_per_frame: int` (defecto 8), `collision_mask: int`, `occlusion_manager: OcclusionManager`, `lod_controller: AcousticLODController`, `raycasts_this_frame: int`, `last_processed_ids: Array` (ids atendidos en la última llamada; existe para que los tests comprueben que el round-robin avanza).
- Produces: `AudioEventManager.occlusion_scheduler: OpenDouOcclusionScheduler`.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_occlusion_scheduler.gd`:

```gdscript
class_name TestOcclusionScheduler
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OcclusionSchedulerClass = preload("res://addons/opendou/runtime/spatial/occlusion_scheduler.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("occlusion_scheduler")

	var sched = OcclusionSchedulerClass.new()
	sched.raycasts_per_frame = 3

	# 20 instancias cercanas al oyente: todas elegibles, pero el presupuesto manda.
	var instances: Array = []
	for i in range(20):
		var def = AudioEventDefClass.new(&"Occ")
		var inst = EventInstanceClass.new(def)
		inst.set_position(Vector3(float(i) * 0.2, 0.0, 1.0))
		inst.play()
		instances.append(inst)

	var node := Node3D.new()
	tree.root.add_child(node)
	await tree.process_frame

	var launched: int = sched.process(instances, Vector3.ZERO, node.get_world_3d())
	a.eq(launched, 3, "no se lanzan más raycasts que el presupuesto")
	a.eq(sched.raycasts_this_frame, 3, "el contador refleja el presupuesto")

	# En frames sucesivos el cursor avanza y atiende a otras voces.
	var first_batch: Array = sched.last_processed_ids.duplicate()
	sched.process(instances, Vector3.ZERO, node.get_world_3d())
	a.ok(sched.last_processed_ids != first_batch, "el reparto round-robin avanza")

	# Las voces en LOD culleado no consumen presupuesto.
	var far_instances: Array = []
	for i in range(10):
		var fdef = AudioEventDefClass.new(&"FarOcc")
		var finst = EventInstanceClass.new(fdef)
		finst.set_position(Vector3(500.0, 0.0, 0.0))
		finst.play()
		far_instances.append(finst)
	var far_launched: int = sched.process(far_instances, Vector3.ZERO, node.get_world_3d())
	a.eq(far_launched, 0, "las voces lejanas no gastan raycasts")

	# Ningún emisor debe crear su propio OcclusionManager.
	var emitter = OpenDouEventPlayer3DClass.new()
	a.has_no_property(emitter, "_occlusion_manager", "el emisor ya no tiene manager propio")
	emitter.free()

	node.queue_free()
	return a
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh` → FALLO por archivo inexistente.

- [ ] **Step 3: Implementa el programador**

Crea `addons/opendou/runtime/spatial/occlusion_scheduler.gd`:

```gdscript
class_name OpenDouOcclusionScheduler
extends RefCounted

## Programa los raycasts de oclusión con un presupuesto fijo por frame.
##
## Antes cada OpenDouEventPlayer3D creaba su propio OcclusionManager y lanzaba su
## propio raycast cada 50 ms: con 200 emisores eran 200 managers y ~4.000
## raycasts por segundo, y un coste que crecía sin límite con el número de
## emisores. Ahora hay un único manager y un techo duro de raycasts por frame,
## repartidos round-robin entre las voces elegibles.
##
## La elegibilidad la decide AcousticLODController por distancia: las voces
## demasiado lejanas no gastan presupuesto.

const OcclusionManagerClass = preload("res://addons/opendou/runtime/spatial/occlusion_manager.gd")
const AcousticLODControllerClass = preload("res://addons/opendou/runtime/spatial/acoustic_lod_controller.gd")

## Techo de raycasts por frame.
var raycasts_per_frame: int = 8

## Capa física contra la que se comprueba la línea de visión.
var collision_mask: int = 1

var occlusion_manager: OcclusionManager = null
var lod_controller: AcousticLODController = null

## Raycasts lanzados en la última llamada a process().
var raycasts_this_frame: int = 0

## Identificadores de las instancias atendidas en la última llamada. Existe para
## que los tests puedan comprobar que el reparto round-robin avanza.
var last_processed_ids: Array = []

var _cursor: int = 0

func _init() -> void:
	occlusion_manager = OcclusionManagerClass.new()
	lod_controller = AcousticLODControllerClass.new()

## Atiende un lote de instancias dentro del presupuesto.
## Devuelve el número de raycasts realmente lanzados.
func process(instances: Array, listener_pos: Vector3, world_3d: World3D) -> int:
	raycasts_this_frame = 0
	last_processed_ids = []

	if world_3d == null or instances.is_empty() or raycasts_per_frame <= 0:
		return 0
	var space_state := world_3d.direct_space_state
	if space_state == null:
		return 0

	# Elegibles: con posición espacial y dentro del alcance de física según LOD.
	var eligible: Array = []
	for inst in instances:
		if inst == null or not inst.has_spatial_position:
			continue
		var lod: int = lod_controller.get_lod_level(inst.emitter_position.distance_to(listener_pos))
		var feats: Dictionary = lod_controller.get_lod_features(lod)
		if bool(feats.get("enable_physics_occlusion", false)):
			eligible.append(inst)

	if eligible.is_empty():
		return 0

	# Las más cercanas al oyente primero: son las que más se notan.
	eligible.sort_custom(func(x, y):
		return x.emitter_position.distance_squared_to(listener_pos) < y.emitter_position.distance_squared_to(listener_pos)
	)

	# Reparto round-robin desde el cursor, para que ninguna voz quede sin atender.
	var budget: int = mini(raycasts_per_frame, eligible.size())
	if _cursor >= eligible.size():
		_cursor = 0

	for i in range(budget):
		var idx: int = (_cursor + i) % eligible.size()
		var inst = eligible[idx]
		var query := PhysicsRayQueryParameters3D.create(inst.emitter_position, listener_pos, collision_mask)
		var hit: Dictionary = space_state.intersect_ray(query)
		var ray_hits: Array[bool] = [not hit.is_empty()]
		var result = occlusion_manager.evaluate_occlusion(inst.emitter_position, listener_pos, ray_hits)
		inst.set_target_lpf(result.target_lpf, result.volume_attenuation_db)
		raycasts_this_frame += 1
		last_processed_ids.append(inst.get_instance_id() if inst is Object else idx)

	_cursor = (_cursor + budget) % eligible.size()
	return raycasts_this_frame
```

- [ ] **Step 4: Conéctalo al manager y quítalo de los nodos**

En `audio_event_manager.gd` añade el preload, la propiedad, la creación en `_init()`
y la llamada como paso 4 del ciclo (antes de los parámetros de instancia):

```gdscript
const OcclusionSchedulerClass = preload("res://addons/opendou/runtime/spatial/occlusion_scheduler.gd")

## Programador único de raycasts de oclusión.
var occlusion_scheduler: OpenDouOcclusionScheduler = null
```

En `_process()`, entre los Game Syncs y los parámetros de instancia:

```gdscript
	# 4. Oclusión presupuestada: un único manager y un techo de raycasts.
	if occlusion_scheduler != null and is_inside_tree():
		var w3d: World3D = get_viewport().find_world_3d() if get_viewport() != null else null
		occlusion_scheduler.process(active_instances, active_listener_position, w3d)
```

En `opendou_event_player_3d.gd` elimina la oclusión por nodo:
- borra `var _occlusion_manager: OcclusionManager = null` y su preload si queda sin uso
- borra el `_init()` que lo instanciaba (si el `_init` queda vacío, bórralo entero)
- borra `_update_occlusion()` completo
- borra del `_process()` el bloque `if enable_dynamic_occlusion and is_inside_tree(): ...`; si `_process` queda vacío salvo el `return` de editor, bórralo
- conserva `enable_dynamic_occlusion` y `occlusion_collision_mask` como exports: ahora informan al programador central en lugar de disparar raycasts propios
- `get_calculated_occlusion()` pasa a leer de la instancia:

```gdscript
## Último factor de oclusión calculado (0.0 = despejado, 1.0 = totalmente ocluido).
func get_calculated_occlusion() -> float:
	if active_instance == null:
		return 0.0
	# El programador central escribe el LPF objetivo; se deriva el factor.
	var span: float = 20000.0 - 1500.0
	if span <= 0.0:
		return 0.0
	return clampf((20000.0 - active_instance.target_spatial_lpf) / span, 0.0, 1.0)
```

Haz lo propio en `opendou_event_player_2d.gd` con su `_update_occlusion` 2D.

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh` → OK.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "perf(spatial): centralize occlusion behind a per-frame raycast budget

Un único OcclusionManager y un techo de N raycasts por frame repartidos
round-robin entre las voces elegibles, con la elegibilidad decidida por
AcousticLODController. Antes cada emisor creaba su propio manager y lanzaba
raycasts cada 50 ms sin techo global.

Da además su primer consumidor real a acoustic_lod_controller.gd.

Resuelve la observación 8."
```

---

### Task 13: Reflexiones tempranas reales

**Resuelve la parte de la observación nº12 que se cablea.**

**Files:**
- Create: `addons/opendou/runtime/reflection_dispatcher.gd`
- Modify: `addons/opendou/runtime/audio_event_manager.gd`
- Test: `tests/test_early_reflections.gd`

**Interfaces:**
- Produces: `OpenDouReflectionDispatcher` con `set_player_pool(pool) -> void`, `dispatch(instance, listener_pos: Vector3, world_3d: World3D) -> int` (devuelve reflexiones emitidas), `collect_finished() -> void` (devuelve al pool las reflexiones que ya terminaron), `release_all() -> void`, propiedades `max_reflections_per_voice: int` (defecto 2), `max_total_reflections: int` (defecto 16), `collision_mask: int`, `active_reflection_count: int`.
- Consumes: `AcousticReflectorEngine.trace_early_reflections()`, que ya devuelve `image_source_pos`, `delay_seconds`, `gain` y `cutoff_lpf`.

`AcousticReflectorEngine` está completo y probado; lo único que faltaba era que
alguien convirtiera sus resultados en sonido. Cada reflexión se emite como una voz
anónima del pool colocada en la posición de la fuente imagen, con la ganancia y el
cutoff que el motor calcula.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_early_reflections.gd` con este contenido:

```gdscript
class_name TestEarlyReflections
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const ReflectionDispatcherClass = preload("res://addons/opendou/runtime/reflection_dispatcher.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("early_reflections")

	var pool = NativePlayerPoolClass.new(16)
	tree.root.add_child(pool)

	# Una sala cerrada de cajas estáticas para que haya superficies que reflejar.
	var room := Node3D.new()
	tree.root.add_child(room)
	for spec in [
		{"pos": Vector3(0, 0, -6), "size": Vector3(12, 6, 0.5)},
		{"pos": Vector3(0, 0, 6), "size": Vector3(12, 6, 0.5)},
		{"pos": Vector3(-6, 0, 0), "size": Vector3(0.5, 6, 12)},
		{"pos": Vector3(6, 0, 0), "size": Vector3(0.5, 6, 12)},
	]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec["size"]
		shape.shape = box
		body.position = spec["pos"]
		body.add_child(shape)
		room.add_child(body)
	await tree.process_frame
	await tree.physics_frame

	var dispatcher = ReflectionDispatcherClass.new()
	dispatcher.set_player_pool(pool)
	dispatcher.max_reflections_per_voice = 2
	dispatcher.max_total_reflections = 4

	var tone := AudioSynthesizerClass.create_tone(440.0, 2.0, 0.6, false)
	var def = AudioEventDefClass.new(&"Reflected", tone)
	var inst = EventInstanceClass.new(def)
	inst.set_position(Vector3.ZERO)
	inst.play()

	var emitted: int = dispatcher.dispatch(inst, Vector3(2.0, 0.0, 2.0), room.get_world_3d())
	a.gt(float(emitted), 0.0, "se emite al menos una reflexión en una sala cerrada")
	a.ok(emitted <= dispatcher.max_reflections_per_voice, "se respeta el techo por voz")

	# El techo global no se puede superar por muchas voces que haya.
	for _i in range(10):
		var d2 = AudioEventDefClass.new(&"R2", tone)
		var i2 = EventInstanceClass.new(d2)
		i2.set_position(Vector3(1.0, 0.0, 1.0))
		i2.play()
		dispatcher.dispatch(i2, Vector3(2.0, 0.0, 2.0), room.get_world_3d())
	a.ok(dispatcher.active_reflection_count <= dispatcher.max_total_reflections,
		"se respeta el techo global de reflexiones")

	dispatcher.release_all()
	a.eq(dispatcher.active_reflection_count, 0, "release_all devuelve todas las voces")

	room.queue_free()
	pool.queue_free()
	return a
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh` → FALLO por archivo inexistente.

- [ ] **Step 3: Implementa el despachador**

Crea `addons/opendou/runtime/reflection_dispatcher.gd`:

```gdscript
class_name OpenDouReflectionDispatcher
extends RefCounted

## Convierte las reflexiones tempranas calculadas por AcousticReflectorEngine en
## voces reales del pool anónimo.
##
## El motor de reflexiones ya calculaba posición de fuente imagen, retardo,
## ganancia y cutoff; nadie los convertía en sonido y `enable_early_reflections`
## era un interruptor muerto. Cada reflexión de 1er orden se emite como una voz
## colocada en la posición espejo, que es cómo se hacen las reflexiones baratas.
##
## Presupuestado en dos niveles para que no se dispare el número de voces.

const AcousticReflectorEngineClass = preload("res://addons/opendou/runtime/spatial/acoustic_reflector_engine.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")

## Reflexiones como máximo por voz directa.
var max_reflections_per_voice: int = 2

## Reflexiones simultáneas como máximo en total.
var max_total_reflections: int = 16

## Capa física contra la que se trazan las reflexiones.
var collision_mask: int = 1

var reflector_engine: AcousticReflectorEngine = null
var player_pool: OpenDouNativePlayerPool = null

## Voces de reflexión actualmente sonando.
var active_reflection_count: int = 0

var _active_players: Array = []

func _init() -> void:
	reflector_engine = AcousticReflectorEngineClass.new()

## Inyecta el pool de reproductores anónimos.
func set_player_pool(pool: OpenDouNativePlayerPool) -> void:
	player_pool = pool

## Emite las reflexiones tempranas de una instancia. Devuelve cuántas emitió.
func dispatch(instance, listener_pos: Vector3, world_3d: World3D) -> int:
	if player_pool == null or world_3d == null or instance == null:
		return 0
	if active_reflection_count >= max_total_reflections:
		return 0

	var stream: AudioStream = instance.definition.base_stream if instance.definition else null
	if stream == null:
		return 0

	var reflections: Array[Dictionary] = reflector_engine.trace_early_reflections(
		instance.emitter_position, listener_pos, world_3d, collision_mask
	)
	if reflections.is_empty():
		return 0

	# Las reflexiones más fuertes primero: si el presupuesto recorta, que recorte
	# las que menos se oyen.
	reflections.sort_custom(func(x, y): return float(x["gain"]) > float(y["gain"]))

	var emitted: int = 0
	for refl in reflections:
		if emitted >= max_reflections_per_voice:
			break
		if active_reflection_count >= max_total_reflections:
			break

		var player = player_pool.acquire(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)
		if player == null:
			break

		player.stream = stream
		player.global_position = refl["image_source_pos"]
		# La ganancia del motor es lineal; el reproductor espera dB.
		player.volume_db = clampf(linear_to_db(maxf(float(refl["gain"]), 0.0001)), -80.0, 0.0)
		player.attenuation_filter_cutoff_hz = clampf(float(refl["cutoff_lpf"]), 20.0, 20000.0)
		var bus_name: String = String(instance.definition.target_bus) if instance.definition else "Master"
		if AudioServer.get_bus_index(bus_name) != -1:
			player.bus = bus_name
		# El retardo de llegada se aplica como offset negativo imposible, así que
		# se aproxima arrancando la reflexión más adelante en el propio stream.
		var length: float = float(stream.get_length())
		var offset: float = 0.0
		if length > 0.0:
			offset = clampf(float(refl["delay_seconds"]), 0.0, maxf(0.0, length - 0.001))
		player.play(offset)

		_active_players.append(player)
		active_reflection_count += 1
		emitted += 1

	return emitted

## Devuelve al pool todas las voces de reflexión que hayan terminado.
func collect_finished() -> void:
	for i in range(_active_players.size() - 1, -1, -1):
		var p = _active_players[i]
		if not is_instance_valid(p) or not p.playing:
			if is_instance_valid(p) and player_pool != null:
				player_pool.release(p)
			_active_players.remove_at(i)
			active_reflection_count = maxi(0, active_reflection_count - 1)

## Devuelve al pool todas las voces de reflexión, sonando o no.
func release_all() -> void:
	for p in _active_players:
		if is_instance_valid(p) and player_pool != null:
			player_pool.release(p)
	_active_players.clear()
	active_reflection_count = 0
```

- [ ] **Step 4: Conéctalo al manager**

En `audio_event_manager.gd`, añade preload, propiedad, creación en `_init()`, la
inyección del pool en `_ready()`, y en `_process()` justo después de `_apply_voices()`:

```gdscript
	# 6b. Reflexiones tempranas de las voces que las tengan activadas.
	if reflection_dispatcher != null and is_inside_tree():
		reflection_dispatcher.collect_finished()
		var w3d_refl: World3D = get_viewport().find_world_3d() if get_viewport() != null else null
		for instance in active_instances:
			if instance == null or instance.assigned_channel_id < 0:
				continue
			var node = instance.get_bound_player()
			if node != null and "enable_early_reflections" in node and node.enable_early_reflections:
				reflection_dispatcher.dispatch(instance, active_listener_position, w3d_refl)
```

**Cuidado con el coste:** trazar 6 rayos por voz y por frame es caro. Añade al
despachador un intervalo mínimo entre trazados por instancia (por ejemplo 0.25 s)
usando un diccionario `id_instancia -> tiempo_del_último_trazado`, y no vuelvas a
trazar antes de ese plazo. Si no lo haces, el test pasa pero el rendimiento en una
escena real será inaceptable.

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh` → OK.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(spatial): make early reflections audible as pooled voices

AcousticReflectorEngine ya calculaba fuente imagen, retardo, ganancia y cutoff;
nadie los convertía en sonido y enable_early_reflections era un interruptor
muerto. Cada reflexión de 1er orden pasa a ser una voz anónima en la posición
espejo, con techo por voz y techo global.

Resuelve la parte cableable de la observación 12."
```

---

### Task 14: Retirar el HRTF de la documentación y verificación final

**Cierra la observación nº12 y valida los 13 criterios de aceptación.**

**Files:**
- Modify: `README.md`
- Modify: `addons/opendou/plugin.cfg`
- Modify: `docs/tasks/roadmap.md`
- Test: verificación completa contra los criterios de aceptación de la spec

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_no_unfulfilled_claims.gd`:

```gdscript
class_name TestNoUnfulfilledClaims
extends RefCounted

## El proyecto solo debe afirmar lo que hace. Este test vigila que las promesas
## retiradas no vuelvan a aparecer en la documentación ni en los exports.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("no_unfulfilled_claims")

	# El toggle no debe existir en ningún emisor.
	var e3 = OpenDouEventPlayer3DClass.new()
	a.has_no_property(e3, "enable_binaural_hrtf", "3D sin toggle de HRTF")
	e3.free()

	# Ni README ni plugin.cfg deben prometer HRTF.
	for path in ["res://README.md", "res://addons/opendou/plugin.cfg"]:
		var f = FileAccess.open(path, FileAccess.READ)
		if f == null:
			a.ok(false, "no se pudo leer %s" % path)
			continue
		var text: String = f.get_as_text().to_lower()
		f.close()
		a.ok(not text.contains("hrtf"), "%s no menciona HRTF" % path)
		a.ok(not text.contains("binaural"), "%s no menciona binaural" % path)

	return a
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO — `plugin.cfg` dice literalmente «HRTF binaural cues» en su descripción.

- [ ] **Step 3: Retira las menciones**

En `addons/opendou/plugin.cfg`, quita «HRTF binaural cues» de la descripción.

En `README.md`, revisa el pilar 4 («Spatial Audio, Rooms & Portals») y elimina o
reformula cualquier mención a HRTF o binaural. Aprovecha para corregir dos cosas
más de la observación nº22 que son mentiras directas y cuestan una línea:
- El pilar 5 y la estructura mencionan bindings GDExtension en C++/Rust que no
  existen: marca esa sección como *planificada*, no como existente.
- Los enlaces `file:///c:/Users/Danielillo/...` no funcionan fuera de esa máquina:
  cámbialos por rutas relativas (`docs/README.md`, etc.).

En `docs/tasks/roadmap.md`, corrige la afirmación de que el búfer SPSC es
lock-free: en GDScript no hay atómicos y nada corre en otro hilo. Descríbelo como
búfer circular de un productor y un consumidor, sin la palabra «lock-free».

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh` → OK.

- [ ] **Step 5: Verifica los 13 criterios de aceptación de la spec**

Recórrelos uno a uno contra la suite y anota en qué test se comprueba cada uno.
Los criterios 2, 6, 9 y 13 son los que más fácilmente se quedan sin cobertura real:

| Criterio | Dónde se verifica |
|---|---|
| 1 `post_event` produce audio medible | `test_audio_output.gd::run_channel_audio_async` |
| 2 un emisor produce UNA voz | `run_single_voice_async` |
| 3 RTPC altera el pico | `run_rtpc_affects_output_async` |
| 4 las instancias no crecen sin límite | `run_lifecycle_async` |
| 5 virtualización y reanudación lógica | `run_budget_async` |
| 6 oyente desplazado afecta prioridad y rayo | `test_listener_resolver.gd` + añade una aserción en `run_budget_async` con oyente en (50,0,0) |
| 7 sin managers por emisor, raycasts acotados | `test_occlusion_scheduler.gd` |
| 8 HRTF inexistente | `test_no_unfulfilled_claims.gd` |
| 9 reflexiones medibles | `test_early_reflections.gd` |
| 10 el runner falla ante errores | comprobado a mano en la Tarea 1 |
| 11 los 5 SCRIPT ERROR resueltos | `./run_tests.sh` sin líneas `SCRIPT ERROR` |
| 12 árbol de git limpio tras la suite | Tarea 3, Step 5 |
| 13 `run_tests.sh` funciona en macOS | uso continuado durante todo el plan |

Si alguno no tiene cobertura real, **escribe el test que falta antes de cerrar la fase.**

- [ ] **Step 6: Commit final**

```bash
git add -A
git commit -m "docs: stop claiming HRTF, GDExtension bindings and lock-free SPSC

El proyecto solo afirma lo que hace. Se retira HRTF de plugin.cfg y README, se
marca como planificada la capa GDExtension inexistente, se corrigen los enlaces
file:///c:/... por rutas relativas y se elimina la palabra lock-free del
roadmap: en GDScript no hay atómicos y nada corre en otro hilo.

Cierra la observación 12 y la parte documental de la 22 y la 24."
```

---

## Notas para quien ejecute el plan

**Cada función async nueva hay que cablearla.** Las tareas 6, 7, 8, 9 y 11 añaden
funciones `run_*_async()` a `tests/test_audio_output.gd`. Cada una debe invocarse
desde `run_all_async()` con `a.absorb(await ...)`, o el test quedará escrito y
nunca se ejecutará —que es exactamente el tipo de ceguera que esta fase corrige.
Tras añadir cada función, comprueba que su nombre aparece en `run_all_async()`.

**Orden obligatorio.** Las tareas 1-4 son la infraestructura de verificación: sin ellas no puedes saber si las demás funcionan. Las tareas 5-9 son la cadena de audio y tienen dependencias estrictas entre sí. Las 10-14 se apoyan en las anteriores. No reordenes.

**Si un test existente empieza a fallar** al tocar `PhysicalVoiceChannel` o `VoicePoolManager`: comprueba qué afirmaba. Muchos tests actuales dan por bueno el comportamiento simulado (que no suene nada). Reescribirlos como aserciones de audio real es trabajo esperado de esta fase, no una regresión que haya que ocultar.

**No toques los tests de demos** (`test_demo_suite.gd`, `test_cyberpunk_demo.gd`, `test_tactical_canyon_demo.gd`, `test_tactical_infiltration_demo.gd`) más allá de lo que exija el runner para no reportar errores. Esas escenas se borran en la Fase 5.

**El conteo de tests va a cambiar** y eso es correcto. `test_all.gd` sumaba totales escritos a mano; el nuevo acumulador cuenta aserciones reales. No intentes que cuadre con 337.

**Al terminar la fase**, ejecuta `./run_tests.sh` en limpio y confirma: `RESULTADO: OK`, sin `SCRIPT ERROR`, fugas no superiores al techo, y `git status --porcelain` vacío.
