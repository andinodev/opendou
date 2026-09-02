class_name OpenDouMixChainInstaller
extends RefCounted

## Instala, actualiza y quita la cadena de masterizacion de un bus. Idempotente: los efectos
## van marcados por resource_name y se reutilizan. Se insertan al PRINCIPIO de la cadena del
## bus, para que una captura o un analizador anadidos despues midan lo que sale de verdad.

const SETTING: String = "opendou/mix/master_chain"
const MARK_COMP: String = "OpenDou_MixChain_Compressor"
const MARK_LIM: String = "OpenDou_MixChain_Limiter"
const MixChainClass = preload("res://addons/opendou/resources/mix_chain.gd")

static func ensure_setting() -> void:
	if not ProjectSettings.has_setting(SETTING):
		ProjectSettings.set_setting(SETTING, "")
	ProjectSettings.set_initial_value(SETTING, "")
	ProjectSettings.add_property_info({"name": SETTING, "type": TYPE_STRING, "hint": PROPERTY_HINT_PLACEHOLDER_TEXT,
		"hint_string": "vacio = nada; GAME, CINEMATIC, MOBILE, o ruta a un MixChain.tres"})

## Lee el ajuste y actua. Devuelve true si instalo algo.
static func install_from_setting() -> bool:
	ensure_setting()
	var value: String = str(ProjectSettings.get_setting(SETTING, "")).strip_edges()
	if value.is_empty():
		return false
	var chain: MixChain = null
	match value.to_upper():
		"GAME":
			chain = MixChainClass.from_preset(MixChainClass.Preset.GAME)
		"CINEMATIC":
			chain = MixChainClass.from_preset(MixChainClass.Preset.CINEMATIC)
		"MOBILE":
			chain = MixChainClass.from_preset(MixChainClass.Preset.MOBILE)
		_:
			if ResourceLoader.exists(value):
				chain = load(value) as MixChain
	if chain == null:
		push_warning("[OpenDou] opendou/mix/master_chain = '%s' no es un preset ni un MixChain: no se instala nada" % value)
		return false
	return install(chain, "Master")

static func install(chain: MixChain, bus_name: String = "Master") -> bool:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0 or chain == null:
		return false
	var comp := _find(idx, MARK_COMP) as AudioEffectCompressor
	if comp == null:
		comp = AudioEffectCompressor.new()
		comp.resource_name = MARK_COMP
		AudioServer.add_bus_effect(idx, comp, 0)
	comp.threshold = chain.compressor_threshold_db
	comp.ratio = chain.compressor_ratio
	comp.attack_us = chain.compressor_attack_us
	comp.release_ms = chain.compressor_release_ms
	comp.gain = chain.compressor_gain_db
	var lim := _find(idx, MARK_LIM) as AudioEffectHardLimiter
	if lim == null:
		lim = AudioEffectHardLimiter.new()
		lim.resource_name = MARK_LIM
		AudioServer.add_bus_effect(idx, lim, 1)
	lim.ceiling_db = chain.limiter_ceiling_db
	lim.pre_gain_db = chain.limiter_pre_gain_db
	lim.release = chain.limiter_release_sec
	return true

static func uninstall(bus_name: String = "Master") -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	for e in range(AudioServer.get_bus_effect_count(idx) - 1, -1, -1):
		var fx_name: String = AudioServer.get_bus_effect(idx, e).resource_name
		if fx_name == MARK_COMP or fx_name == MARK_LIM:
			AudioServer.remove_bus_effect(idx, e)

static func is_installed(bus_name: String = "Master") -> bool:
	var idx: int = AudioServer.get_bus_index(bus_name)
	return idx >= 0 and _find(idx, MARK_COMP) != null and _find(idx, MARK_LIM) != null

static func _find(bus_idx: int, mark: String) -> AudioEffect:
	for e in range(AudioServer.get_bus_effect_count(bus_idx)):
		var fx := AudioServer.get_bus_effect(bus_idx, e)
		if fx != null and fx.resource_name == mark:
			return fx
	return null
