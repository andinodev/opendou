@tool
class_name MixChain
extends Resource

## Cadena de masterizacion: compresor + limitador de Godot, con presets. Es un recurso y
## no un nodo porque Master es global: la instala el autoload segun un ajuste de proyecto
## y la guarda comprueba el bus, no la escena.

enum Preset { GAME, CINEMATIC, MOBILE, CUSTOM }

@export var preset: Preset = Preset.GAME:
	set(value):
		preset = value
		if value != Preset.CUSTOM:
			_apply_preset(value)

@export_group("Compressor")
@export var compressor_threshold_db: float = -12.0
@export var compressor_ratio: float = 3.0
@export var compressor_attack_us: float = 20.0
@export var compressor_release_ms: float = 250.0
@export var compressor_gain_db: float = 0.0

@export_group("Limiter")
@export var limiter_ceiling_db: float = -0.3
@export var limiter_pre_gain_db: float = 0.0
@export var limiter_release_sec: float = 0.1

static func from_preset(p: Preset) -> MixChain:
	var c := MixChain.new()
	c.preset = p
	return c

func _apply_preset(p: Preset) -> void:
	match p:
		Preset.GAME:
			compressor_threshold_db = -12.0
			compressor_ratio = 3.0
			compressor_attack_us = 20.0
			compressor_release_ms = 250.0
			compressor_gain_db = 0.0
			limiter_ceiling_db = -0.3
			limiter_pre_gain_db = 0.0
			limiter_release_sec = 0.1
		Preset.CINEMATIC:
			compressor_threshold_db = -18.0
			compressor_ratio = 2.0
			compressor_attack_us = 40.0
			compressor_release_ms = 400.0
			compressor_gain_db = 0.0
			limiter_ceiling_db = -1.0
			limiter_pre_gain_db = 0.0
			limiter_release_sec = 0.2
		Preset.MOBILE:
			compressor_threshold_db = -16.0
			compressor_ratio = 4.0
			compressor_attack_us = 20.0
			compressor_release_ms = 150.0
			compressor_gain_db = 2.0
			limiter_ceiling_db = -0.5
			limiter_pre_gain_db = 0.0
			limiter_release_sec = 0.05
