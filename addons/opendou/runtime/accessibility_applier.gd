class_name OpenDouAccessibilityApplier
extends RefCounted

## Aplica los ajustes de accesibilidad del jugador sobre Master (Fase 10): mono con un
## StereoEnhance sin separacion al final de la cadena, y modo noche reinstalando la cadena
## de masterizacion con el preset NIGHT. Vale para los dos backends: es Godot.

const MARK_MONO: String = "OpenDou_Access_Mono"
const InstallerClass = preload("res://addons/opendou/runtime/mix_chain_installer.gd")
const MixChainClass = preload("res://addons/opendou/resources/mix_chain.gd")

static func apply(settings) -> void:
	apply_mono(settings.mono)
	apply_night(settings.night_mode)

static func is_mono_installed() -> bool:
	var idx: int = AudioServer.get_bus_index("Master")
	return idx >= 0 and _find(idx, MARK_MONO) != null

static func apply_mono(on: bool) -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx < 0:
		return
	var fx := _find(idx, MARK_MONO)
	if on and fx == null:
		var se := AudioEffectStereoEnhance.new()
		se.resource_name = MARK_MONO
		se.pan_pullout = 0.0
		se.surround = 0.0
		se.time_pullout_ms = 0.0
		AudioServer.add_bus_effect(idx, se)   # al final: despues del limitador
	elif not on and fx != null:
		for i in range(AudioServer.get_bus_effect_count(idx)):
			if AudioServer.get_bus_effect(idx, i) == fx:
				AudioServer.remove_bus_effect(idx, i)
				break

static func apply_night(on: bool) -> void:
	if on:
		InstallerClass.install(MixChainClass.from_preset(MixChainClass.Preset.NIGHT), "Master")
	elif not InstallerClass.install_from_setting():
		# Sin ajuste de proyecto no hay cadena a la que volver: se quita.
		InstallerClass.uninstall("Master")

static func _find(bus_idx: int, mark: String) -> AudioEffect:
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var e := AudioServer.get_bus_effect(bus_idx, i)
		if e != null and e.resource_name == mark:
			return e
	return null
