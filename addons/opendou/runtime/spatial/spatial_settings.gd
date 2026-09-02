class_name OpenDouSpatialSettings
extends RefCounted

## Ajustes de espacializacion DEL JUGADOR: HRTF, mezcla y salida. Persisten en user://.
##
## Es el primer almacen de ajustes de usuario del plugin. Solo persiste y valida; aplicarlos
## a los streams del pool lo hace el AudioEventManager al recibir `changed`.

signal changed

const PATH: String = "user://opendou_audio.cfg"
const SECTION: String = "spatial"
const OUTPUTS: PackedStringArray = ["headphones", "speakers"]
const ACCESS_SECTION: String = "accessibility"

var hrtf: String = "default"
var blend: float = 1.0
var output: String = "headphones"
## Accesibilidad (Fase 10): mezcla mono y modo noche (compresion del rango dinamico).
var mono: bool = false
var night_mode: bool = false

func set_hrtf(value: String) -> void:
	hrtf = value if not value.is_empty() else "default"
	changed.emit()

func set_blend(value: float) -> void:
	blend = clampf(value, 0.0, 1.0)
	changed.emit()

func set_output(value: String) -> void:
	output = value if OUTPUTS.has(value) else "headphones"
	changed.emit()

func set_mono(value: bool) -> void:
	mono = value
	changed.emit()

func set_night_mode(value: bool) -> void:
	night_mode = value
	changed.emit()

## Lee el archivo si existe. Sin archivo, conserva los defectos y no emite nada.
func load_from_disk(path: String = PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	hrtf = str(cfg.get_value(SECTION, "hrtf", "default"))
	if hrtf.is_empty():
		hrtf = "default"
	blend = clampf(float(cfg.get_value(SECTION, "blend", 1.0)), 0.0, 1.0)
	output = str(cfg.get_value(SECTION, "output", "headphones"))
	if not OUTPUTS.has(output):
		output = "headphones"
	mono = bool(cfg.get_value(ACCESS_SECTION, "mono", false))
	night_mode = bool(cfg.get_value(ACCESS_SECTION, "night_mode", false))

func save_to_disk(path: String = PATH) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "hrtf", hrtf)
	cfg.set_value(SECTION, "blend", blend)
	cfg.set_value(SECTION, "output", output)
	cfg.set_value(ACCESS_SECTION, "mono", mono)
	cfg.set_value(ACCESS_SECTION, "night_mode", night_mode)
	return cfg.save(path)
