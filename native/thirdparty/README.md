# Dependencias nativas (no versionadas)

Esta carpeta NO se versiona: son cientos de megas de binarios de terceros. Cada clon la
rellena a mano con estas dos piezas, en estas rutas exactas:

| Ruta | Que es | De donde |
|---|---|---|
| `steamaudio/` | Steam Audio SDK **4.8.1** (`include/phonon.h`, `lib/<plataforma>/`) | [Releases de ValveSoftware/steam-audio](https://github.com/ValveSoftware/steam-audio/releases): el zip `steamaudio_4.8.1.zip`, descomprimido aqui |
| `godot-cpp/` | Bindings C++ de Godot, rama **master** | `git clone --depth 1 https://github.com/godotengine/godot-cpp` |

`godot-cpp` no tiene rama ni tag para Godot 4.7 (la ultima es 4.5), pero su **master trae
`extension_api-4-7.json` y 4.7 es su API por defecto**, asi que se construye desde master tal
cual. `../dump_godot_api.sh` vuelca la API del Godot instalado para **verificar** que coincide
con la que godot-cpp usa; su salida (`../godot-api/`) no se versiona: son 7 MB regenerables.

Licencia de Steam Audio: Apache 2.0. Su `THIRDPARTY.md` y el aviso de copyright viajan con
los binarios que se distribuyan.
