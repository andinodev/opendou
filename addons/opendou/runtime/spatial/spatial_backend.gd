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
const FRAME_SIZE_SETTING: String = "opendou/spatial/frame_size"
const FRAME_SIZES: Array[int] = [256, 512, 1024]
const MAX_DELAY_SETTING: String = "opendou/spatial/max_propagation_delay_sec"

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

static func ensure_frame_size_setting() -> void:
	if not ProjectSettings.has_setting(FRAME_SIZE_SETTING):
		ProjectSettings.set_setting(FRAME_SIZE_SETTING, 512)
	ProjectSettings.set_initial_value(FRAME_SIZE_SETTING, 512)
	ProjectSettings.add_property_info({
		"name": FRAME_SIZE_SETTING, "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM,
		"hint_string": "256:256,512:512,1024:1024",
	})

## Tamano de bloque del DSP nativo. Se lee UNA vez al crear el contexto: cambiarlo exige
## reiniciar. 512 = 11.6 ms a 44.1 kHz (medido en el spike); 256 baja la latencia y sube la CPU.
static func read_frame_size() -> int:
	ensure_frame_size_setting()
	var v: int = int(ProjectSettings.get_setting(FRAME_SIZE_SETTING, 512))
	if not FRAME_SIZES.has(v):
		push_warning("[OpenDou] opendou/spatial/frame_size = %d no es 256, 512 ni 1024: se usa 512" % v)
		return 512
	return v

## Tope del retardo por distancia, en segundos (memoria por voz: 176 KB por segundo a 44.1 kHz).
static func read_max_propagation_delay() -> float:
	if not ProjectSettings.has_setting(MAX_DELAY_SETTING):
		ProjectSettings.set_setting(MAX_DELAY_SETTING, 3.0)
	ProjectSettings.set_initial_value(MAX_DELAY_SETTING, 3.0)
	ProjectSettings.add_property_info({"name": MAX_DELAY_SETTING, "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,10,0.1"})
	return clampf(float(ProjectSettings.get_setting(MAX_DELAY_SETTING, 3.0)), 0.1, 10.0)

## true si la extension esta cargada Y Steam Audio se inicializo.
static func native_available() -> bool:
	if not ClassDB.class_exists("OpenDouSpatialStream"):
		return false
	if not ClassDB.class_has_method("OpenDouSpatialStream", "is_native_available"):
		return false
	if ClassDB.class_has_method("OpenDouSpatialStream", "configure"):
		ClassDB.class_call_static("OpenDouSpatialStream", "configure", read_frame_size())
	if ClassDB.class_has_method("OpenDouSpatialStream", "configure_max_propagation_delay"):
		ClassDB.class_call_static("OpenDouSpatialStream", "configure_max_propagation_delay", read_max_propagation_delay())
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
