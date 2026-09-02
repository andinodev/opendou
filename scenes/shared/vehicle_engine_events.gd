class_name VehicleEngineEvents
extends RefCounted

## Plantilla de motor (Fase 11): un evento con AudioSwitchContainer(Load) -> dos
## AudioBlendContainer(RPM) de tres capas sintetizadas con curvas cruzadas. Es demo y preset
## del grafo, no un nodo del plugin: un motor es un contenedor bien autorado.

const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioBlendContainerClass = preload("res://addons/opendou/resources/containers/audio_blend_container.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")

const EVENT_NAME: StringName = &"WorkshopEngine"
const RPM_RTPC: StringName = &"RPM"
const LOAD_SWITCH: StringName = &"Load"
const RPM_MIN: float = 600.0
const RPM_MAX: float = 6000.0

## Curva en dB con tres puntos: 0 dB en el centro de la capa, -60 en las otras dos.
static func _layer_curve(index: int) -> Curve:
	var c := Curve.new()
	c.min_value = -60.0
	c.max_value = 0.0
	for k in range(3):
		c.add_point(Vector2(float(k) * 0.5, 0.0 if k == index else -60.0))
	return c

static func _blend(base_freqs: Array) -> AudioBlendContainer:
	var blend = AudioBlendContainerClass.new(RPM_RTPC, RPM_MIN, RPM_MAX)
	for i in range(3):
		var loop := AudioSynthesizerClass.create_engine_loop(float(base_freqs[i]), 1.0)
		blend.add_layer(AudioPhysicalNodeClass.new(loop), _layer_curve(i))
	return blend

## Autora el evento y lo registra. Devuelve la definicion (target_bus lo fija quien llama).
static func register(manager) -> AudioEventDef:
	var sw = AudioSwitchContainerClass.new(LOAD_SWITCH, &"Idle")
	sw.set_state_node(&"Idle", _blend([40.0, 80.0, 160.0]))
	sw.set_state_node(&"Load", _blend([30.0, 60.0, 120.0]))   # mas grave bajo carga
	var def = AudioEventDefClass.new(EVENT_NAME)
	def.root_container = sw
	def.is_looping = true
	def.stream_length = 1.0
	def.base_volume_db = -8.0
	def.base_priority = 60.0
	def.hdr_loudness_db = -8.0
	if manager != null:
		manager.register_event_definition(def)
	return def
