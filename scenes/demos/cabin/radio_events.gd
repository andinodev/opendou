class_name RadioEvents
extends RefCounted

## El chatter de radio y el banco de locuciones de «La cabina».
##
## HONESTIDAD DE DISENO: sin assets de voz no hay habla inteligible, y la ficcion se
## eligio para que la limitacion sea invisible. La radio es el unico caso donde una voz
## sintetizada -filtrada, con squelch, ininteligible por diseno- resulta creible.
## Ninguna de estas fuentes pretende decir palabras.

const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const ModularSynthEngineClass = preload("res://addons/opendou/runtime/synth/modular_synth_engine.gd")
const SoundBankBuilderClass = preload("res://addons/opendou/runtime/soundbank_builder.gd")
const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")

const EVENT_NAME: StringName = &"RadioChatter"
const SWITCH_GROUP: StringName = &"RadioStation"

## Las tres estaciones. Cada una tiene su banda de frecuencias, asi que se distinguen
## de oido y en una asercion.
const STATIONS: Array[StringName] = [&"Tower", &"Approach", &"Ground"]

## Frecuencia central del formante por estacion, en Hz.
const STATION_FREQ: Dictionary = {
	&"Tower": 900.0,
	&"Approach": 1500.0,
	&"Ground": 600.0,
}

## Variaciones de chatter por estacion.
const VARIATIONS: int = 3

## Chatter: ruido con formante y envolvente de squelch.
static func make_chatter(station: StringName, variation: int) -> AudioStreamWAV:
	var center: float = float(STATION_FREQ.get(station, 1000.0))
	var preset: Dictionary = {
		"type": "Single_Generator",
		"generator_type": "Filtered_Noise",
		"noise_type": "White",
		"duration": 1.1,
		"base_freq": center,
		"filter": {
			"type": "BandPass",
			# Cada variacion desplaza el formante: tres lineas de la misma estacion se
			# distinguen entre si sin dejar de sonar a la misma estacion.
			"cutoff_hz": center * (1.0 + 0.12 * float(variation - 1)),
			"resonance_q": 6.0,
		},
		"envelope": {"attack": 0.01, "decay": 0.08, "sustain": 0.55, "release": 0.12},
		"lfo": {"depth": 0.6, "rate_hz": 7.0 + float(variation), "wave": "Square", "target": "Amplitude"},
		"drive": {"type": "Foldback", "amount": 1.6},
		"gain_db": -9.0,
	}
	return ModularSynthEngineClass.synthesize_wav(preset, 4200 + variation * 17)

## Autora el evento de chatter con un switch container sobre RadioStation.
static func register(manager, target_bus: StringName) -> AudioEventDef:
	var switch_container = AudioSwitchContainerClass.new(SWITCH_GROUP, STATIONS[0])
	for station in STATIONS:
		var random_container = AudioRandomContainerClass.new()
		random_container.use_shuffle = true
		random_container.pitch_jitter_range = Vector2(-0.04, 0.04)
		random_container.volume_jitter_db_range = Vector2(-3.0, 0.0)
		for v in range(1, VARIATIONS + 1):
			random_container.add_child_node(AudioPhysicalNodeClass.new(make_chatter(station, v)))
		switch_container.set_state_node(station, random_container)

	var def = AudioEventDefClass.new(EVENT_NAME)
	def.root_container = switch_container
	def.is_looping = true
	def.stream_length = 1.1
	def.base_volume_db = -5.0
	def.base_priority = 65.0
	def.hdr_loudness_db = -8.0
	def.target_bus = target_bus
	if manager != null:
		manager.register_event_definition(def)
	return def

## Locuciones de la torre. Devuelve el dict de entradas del banco por id.
##
## Tres frases: dos en dos lenguas para la tabla de dialogo, y una de reserva.
static func announcement_entries() -> Dictionary:
	var entries: Dictionary = {}
	var specs: Array[Dictionary] = [
		{"id": 0, "freq": 780.0, "dur": 1.4},   # ClearedToLand / es
		{"id": 1, "freq": 1020.0, "dur": 1.4},  # ClearedToLand / en
		{"id": 2, "freq": 640.0, "dur": 1.8},   # GoAround
	]
	for spec in specs:
		var wav := ModularSynthEngineClass.synthesize_wav({
			"type": "Single_Generator",
			"generator_type": "Filtered_Noise",
			"noise_type": "Pink",
			"duration": spec["dur"],
			"base_freq": spec["freq"],
			"filter": {"type": "BandPass", "cutoff_hz": spec["freq"], "resonance_q": 8.0},
			"envelope": {"attack": 0.02, "decay": 0.1, "sustain": 0.6, "release": 0.2},
			"lfo": {"depth": 0.5, "rate_hz": 5.5, "wave": "Triangle", "target": "Amplitude"},
			"gain_db": -8.0,
		}, 9100 + int(spec["id"]))
		entries[int(spec["id"])] = {
			"samples": WavDecoderClass.to_mono_floats(wav),
			"codec": 0,
			"channels": 1,
			"sample_rate": 44100,
			# La primera se precarga: es la que tiene que sonar sin latencia de disco.
			"is_prefetch": int(spec["id"]) == 0,
		}
	return entries

## Escribe el banco de locuciones. Devuelve si lo consiguio.
static func build_announcement_bank(path: String) -> bool:
	return SoundBankBuilderClass.build_bank(path, announcement_entries())
