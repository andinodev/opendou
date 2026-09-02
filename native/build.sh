#!/usr/bin/env bash
# Compila la extension nativa de OpenDou en macOS arm64. Reproducible: descarga y fija las
# dependencias si faltan, compila godot-cpp y la extension, y deja la salida en
# addons/opendou/bin lista para que Godot la cargue (sin cuarentena y firmada ad hoc).
#
# Solo macOS arm64 esta VERIFICADO. El CMake es multiplataforma y el SDK trae bibliotecas
# para Windows, Linux, Android, iOS y wasm, pero nada de eso se afirma hasta compilarlo y
# probarlo (spec 7B, S7).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THIRD="$HERE/thirdparty"
GODOTCPP_COMMIT="26fb7ab"
STEAMAUDIO_VERSION="4.8.1"
STEAMAUDIO_URL="https://github.com/ValveSoftware/steam-audio/releases/download/v${STEAMAUDIO_VERSION}/steamaudio_${STEAMAUDIO_VERSION}.zip"
STEAMAUDIO_SHA256="4a0aa5ec1176f38f0b0993a37c2259d9e86f27e22d5e24f83ec4c3cb9a1d5449"

find_cmake() {
	if [[ -n "${CMAKE:-}" && -x "${CMAKE}" ]]; then echo "$CMAKE"; return 0; fi
	if command -v cmake >/dev/null 2>&1; then command -v cmake; return 0; fi
	[[ -x /Applications/CMake.app/Contents/bin/cmake ]] && { echo /Applications/CMake.app/Contents/bin/cmake; return 0; }
	return 1
}
CMAKE_BIN="$(find_cmake)" || { echo "[OpenDou] no se encontro cmake. Instala CMake o define CMAKE=/ruta/a/cmake" >&2; exit 1; }

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
	echo "[OpenDou] build.sh solo esta verificado en macOS arm64. En otra plataforma, usa el CMake a mano y verifica la salida." >&2
	exit 1
fi

mkdir -p "$THIRD"
if [[ ! -d "$THIRD/godot-cpp/.git" ]]; then
	echo "[OpenDou] clonando godot-cpp @ $GODOTCPP_COMMIT"
	git clone --quiet https://github.com/godotengine/godot-cpp.git "$THIRD/godot-cpp"
fi
if [[ "$(git -C "$THIRD/godot-cpp" rev-parse --short HEAD)" != "$GODOTCPP_COMMIT" ]]; then
	git -C "$THIRD/godot-cpp" fetch --quiet origin
	git -C "$THIRD/godot-cpp" checkout --quiet "$GODOTCPP_COMMIT"
fi

if [[ ! -f "$THIRD/steamaudio/include/phonon.h" ]]; then
	echo "[OpenDou] descargando Steam Audio $STEAMAUDIO_VERSION"
	TMP_ZIP="$THIRD/steamaudio_${STEAMAUDIO_VERSION}.zip"
	curl -L --fail --silent --show-error -o "$TMP_ZIP" "$STEAMAUDIO_URL"
	ACTUAL="$(shasum -a 256 "$TMP_ZIP" | awk '{print $1}')"
	if [[ "$ACTUAL" != "$STEAMAUDIO_SHA256" ]]; then
		echo "[OpenDou] el SHA-256 del SDK no coincide: $ACTUAL" >&2
		rm -f "$TMP_ZIP"
		exit 1
	fi
	rm -rf "$THIRD/steamaudio_unpack"
	unzip -q "$TMP_ZIP" -d "$THIRD/steamaudio_unpack"
	# No se supone la estructura del zip: se busca la carpeta que contiene include/phonon.h.
	SDK_DIR="$(dirname "$(dirname "$(find "$THIRD/steamaudio_unpack" -type f -name phonon.h -path '*/include/*' | head -1)")")"
	[[ -d "$SDK_DIR" ]] || { echo "[OpenDou] el zip no contiene include/phonon.h" >&2; exit 1; }
	mv "$SDK_DIR" "$THIRD/steamaudio"
	rm -rf "$THIRD/steamaudio_unpack" "$TMP_ZIP"
fi

echo "[OpenDou] compilando godot-cpp"
"$CMAKE_BIN" -S "$THIRD/godot-cpp" -B "$HERE/build/godot-cpp" -DGODOTCPP_API_VERSION=4.7 \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 > /dev/null
"$CMAKE_BIN" --build "$HERE/build/godot-cpp" --parallel > /dev/null

echo "[OpenDou] compilando la extension"
"$CMAKE_BIN" -S "$HERE" -B "$HERE/build/ext" -DCMAKE_BUILD_TYPE=Release > /dev/null
"$CMAKE_BIN" --build "$HERE/build/ext" --parallel

echo "[OpenDou] Steam Audio $(grep -E 'define STEAMAUDIO_VERSION_(MAJOR|MINOR|PATCH)' "$THIRD/steamaudio/include/phonon_version.h" | awk '{print $3}' | paste -sd. -)"
echo "[OpenDou] salida: $HERE/../addons/opendou/bin/"
ls -la "$HERE/../addons/opendou/bin/"*.dylib
