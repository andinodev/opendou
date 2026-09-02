#!/usr/bin/env bash
# Runner de tests de OpenDou. Multiplataforma (macOS / Linux).
# Falla si el log del motor contiene errores de script o de parseo, o si el
# numero de fugas de ObjectDB aumenta respecto al techo registrado.
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
	echo "[ERROR] No se encontro Godot. Define GODOT_PATH apuntando al ejecutable." >&2
	exit 1
}

echo "[OpenDou] Godot: $GODOT_BIN"
echo "[OpenDou] Script: $TEST_SCRIPT"

# Un class_name recien anadido no existe como tipo global hasta que Godot
# regenera su cache de clases, y sin editor eso solo ocurre al importar. Sin este
# paso, anotar un tipo nuevo produce "Parse Error: Could not find type ... in the
# current scope" y toda la suite deja de compilar, ademas de colgar a Godot.
#
# La comprobacion es exacta en lugar de basarse en fechas: se compara la lista de
# class_name declarados con los que la cache conoce. Asi se importa solo cuando
# de verdad falta alguno, y no en cada edicion de un cuerpo de funcion.
#
# scenes/ entra en el scan desde la Fase 5, que es la primera que declara clases ahi.
# Sin ella, una clase nueva de scenes/ usada como ANOTACION DE TIPO -y no solo por
# preload- daba un Parse Error hasta que algo de addons/ o tests/ forzaba la
# regeneracion por su cuenta.
CLASS_CACHE=".godot/global_script_class_cache.cfg"
NEEDS_IMPORT=0
MISSING_CLASSES=""
if [[ ! -f "$CLASS_CACHE" ]]; then
	NEEDS_IMPORT=1
	echo "[OpenDou] no hay cache de clases"
else
	while IFS= read -r cls; do
		[[ -z "$cls" ]] && continue
		if ! grep -q "\"$cls\"" "$CLASS_CACHE"; then
			MISSING_CLASSES="$MISSING_CLASSES $cls"
			NEEDS_IMPORT=1
		fi
	done < <(grep -rhoE '^class_name[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' addons tests scenes --include='*.gd' 2>/dev/null | awk '{print $2}' | sort -u)
	if [[ -n "$MISSING_CLASSES" ]]; then
		echo "[OpenDou] class_name sin registrar:$MISSING_CLASSES"
	fi
fi
if [[ "$NEEDS_IMPORT" -eq 1 ]]; then
	echo "[OpenDou] regenerando cache de clases"
	"$GODOT_BIN" --headless --path . --import > /dev/null 2>&1
fi
START_TS=$(date +%s)
# Godot se queda vivo si el script de entrada no compila, asi que hace falta un
# watchdog: sin el, un error de parseo cuelga el runner en lugar de fallar.
# macOS no trae coreutils, o sea que no hay `timeout` y se implementa a mano.
TIMEOUT_SECS="${OPENDOU_TEST_TIMEOUT:-180}"
"$GODOT_BIN" --headless --path . --script "$TEST_SCRIPT" > "$CONSOLE_LOG" 2>&1 &
GODOT_PID=$!
ELAPSED=0
while kill -0 "$GODOT_PID" 2>/dev/null; do
	if [[ "$ELAPSED" -ge "$TIMEOUT_SECS" ]]; then
		echo "[FALLO] Godot excedio ${TIMEOUT_SECS}s y fue terminado." >&2
		kill -9 "$GODOT_PID" 2>/dev/null
		wait "$GODOT_PID" 2>/dev/null
		GODOT_EXIT=124
		break
	fi
	sleep 1
	ELAPSED=$((ELAPSED + 1))
done
if [[ -z "${GODOT_EXIT:-}" ]]; then
	wait "$GODOT_PID"
	GODOT_EXIT=$?
fi
echo "[OpenDou] duracion: $(( $(date +%s) - START_TS ))s"

grep -E "^STATUS:" "$CONSOLE_LOG" || echo "[WARN] la suite no reporto STATUS"

FATAL=0

# 1) Errores de script y de parseo: fatales sin excepcion.
#    Un error de script aborta la funcion que lo contiene y devuelve null, asi
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
# El archivo admite comentarios con # para justificar el techo: se toma el primer
# numero que aparezca en una linea no comentada.
BUDGET=$(grep -vE '^[[:space:]]*#' "$LEAK_BUDGET_FILE" 2>/dev/null | grep -oE '[0-9]+' | head -1)
BUDGET="${BUDGET:-0}"
echo "[OpenDou] fugas ObjectDB: $LEAKED (techo: $BUDGET)"
if [[ "$LEAKED" -gt "$BUDGET" ]]; then
	echo "[FALLO] las fugas de ObjectDB aumentaron de $BUDGET a $LEAKED." >&2
	echo "         Libera lo que creaste, o justifica y actualiza $LEAK_BUDGET_FILE." >&2
	FATAL=1
fi

# 3) La suite debe haber reportado exito.
if ! grep -q "^STATUS: PASSED" "$CONSOLE_LOG"; then
	echo "[FALLO] la suite no reporto STATUS: PASSED" >&2
	grep -E "^- " "$CONSOLE_LOG" | head -30 >&2
	FATAL=1
fi

if [[ "$FATAL" -ne 0 ]]; then
	echo "[OpenDou] RESULTADO: FALLO"
	exit 1
fi
if [[ "$GODOT_EXIT" -ne 0 ]]; then
	echo "[FALLO] Godot salio con codigo $GODOT_EXIT" >&2
	echo "[OpenDou] RESULTADO: FALLO"
	exit 1
fi
echo "[OpenDou] RESULTADO: OK"
exit 0
