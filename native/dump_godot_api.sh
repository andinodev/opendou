#!/usr/bin/env bash
# Vuelca la API GDExtension del Godot instalado, que es el contrato contra el que godot-cpp
# genera sus bindings. Hay que rehacerlo cada vez que cambie la version de Godot.
#
# godot-cpp no tiene rama ni tag para 4.7 (la ultima es 4.5), asi que se construye desde su
# master CONTRA ESTE volcado: las clases y metodos salen de aqui, no de la rama.
set -euo pipefail
GODOT_BIN="${GODOT_BIN:-/Users/Daniel/Downloads/Godot.app/Contents/MacOS/Godot}"
OUT_DIR="$(cd "$(dirname "$0")" && pwd)/godot-api"
mkdir -p "$OUT_DIR"
cd "$OUT_DIR"
"$GODOT_BIN" --headless --dump-extension-api --dump-gdextension-interface >/dev/null 2>&1
python3 -c "import json;h=json.load(open('extension_api.json'))['header'];print('API volcada de', h['version_full_name'])"
