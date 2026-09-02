# Dependencias nativas (no versionadas)

Esta carpeta NO se versiona: son cientos de megas de binarios de terceros. **La rellena
`../build.sh`**, que descarga y fija las dos piezas en estas rutas exactas, y luego compila:

| Ruta | Que es | Como se fija |
|---|---|---|
| `steamaudio/` | Steam Audio SDK **4.8.1** (`include/phonon.h`, `lib/<plataforma>/`) | zip `steamaudio_4.8.1.zip` de las [releases de ValveSoftware/steam-audio](https://github.com/ValveSoftware/steam-audio/releases), verificado por SHA-256 en `build.sh` |
| `godot-cpp/` | Bindings C++ de Godot | rama `master`, commit `26fb7ab` |

`godot-cpp` no tiene rama ni tag para Godot 4.7, pero su master trae `extension_api-4-7.json`
y 4.7 es su API por defecto. `../dump_godot_api.sh` vuelca la API del Godot instalado para
**verificar** que coincide; su salida (`../godot-api/`) no se versiona: son 7 MB regenerables.

Licencia de Steam Audio: Apache 2.0. El aviso vive en `addons/opendou/THIRD_PARTY_NOTICES.md`
y su `THIRDPARTY.md` viaja con los binarios que se distribuyan.
