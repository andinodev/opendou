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
