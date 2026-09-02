class_name OpenDouSpatialBackend
extends RefCounted

## Decide UNA vez, al arrancar, quien convierte las voces 3D en estereo.
##
## `godot`: el AudioStreamPlayer3D de siempre. `steam_audio`: un AudioStreamPlayer estereo
## con OpenDouSpatialStream (HRTF + ITD) por canal. No hay cambio en caliente: los
## reproductores del pool se crean por tipo, y el conmutador audifonos/altavoces ya es en
## vivo sin necesidad de cambiar de backend.

const SETTING: String = "opendou/spatial/backend"
const GODOT: StringName = &"godot"
const STEAM_AUDIO: StringName = &"steam_audio"

## Registra el ajuste de proyecto con su defecto si no existe. Idempotente.
static func ensure_setting() -> void:
	if not ProjectSettings.has_setting(SETTING):
		ProjectSettings.set_setting(SETTING, "auto")
	ProjectSettings.set_initial_value(SETTING, "auto")
	ProjectSettings.add_property_info({
		"name": SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "auto,godot,steam_audio",
	})

static func read_setting() -> String:
	ensure_setting()
	return str(ProjectSettings.get_setting(SETTING, "auto"))

## true si la extension esta cargada Y Steam Audio se inicializo.
static func native_available() -> bool:
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		return false
	if not ClassDB.class_has_method("OpenDouSpatialStream", "is_native_available"):
		return false
	return bool(ClassDB.class_call_static("OpenDouSpatialStream", "is_native_available"))

## La regla, separada de sus entradas para poder afirmarla sin extension.
static func resolve(setting_value: String, p_native_available: bool) -> StringName:
	match setting_value:
		"godot":
			return GODOT
		"steam_audio":
			if p_native_available:
				return STEAM_AUDIO
			push_error("[OpenDou] opendou/spatial/backend = steam_audio pero la extension nativa no esta cargada: se usa el backend de Godot")
			return GODOT
		_:
			return STEAM_AUDIO if p_native_available else GODOT
