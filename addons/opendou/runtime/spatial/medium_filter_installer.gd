class_name OpenDouMediumFilterInstaller
extends RefCounted

## Paso-bajo del medio en Master (Fase 10), antes de la cadena de masterizacion. Marcado
## para que sea idempotente y la suite lo encuentre. 20000 Hz = quitarlo.

const MARK: String = "OpenDou_Medium_LPF"

static func apply(cutoff_hz: float, bus_name: String = "Master") -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var fx := _find(idx) as AudioEffectLowPassFilter
	if cutoff_hz >= 19999.0:
		if fx != null:
			for i in range(AudioServer.get_bus_effect_count(idx)):
				if AudioServer.get_bus_effect(idx, i) == fx:
					AudioServer.remove_bus_effect(idx, i)
					break
		return
	if fx == null:
		fx = AudioEffectLowPassFilter.new()
		fx.resource_name = MARK
		AudioServer.add_bus_effect(idx, fx, 0)
	fx.cutoff_hz = clampf(cutoff_hz, 200.0, 20000.0)

static func is_installed(bus_name: String = "Master") -> bool:
	var idx: int = AudioServer.get_bus_index(bus_name)
	return idx >= 0 and _find(idx) != null

static func _find(bus_idx: int) -> AudioEffect:
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		var e := AudioServer.get_bus_effect(bus_idx, i)
		if e != null and e.resource_name == MARK:
			return e
	return null
