@tool
class_name LFOModulator
extends AudioModulator

## Low Frequency Oscillator (LFO) modulator for periodic tremolo, vibrato and sweeps.

const LFOStateClass = preload("res://addons/opendou/runtime/modulators/lfo_state.gd")

enum Waveform {
	SINE,
	TRIANGLE,
	SQUARE,
	SAWTOOTH
}

@export var waveform: Waveform = Waveform.SINE
@export var frequency_hz: float = 2.0
@export var phase_offset: float = 0.0

func _init(p_target: StringName = &"pitch_scale", p_wave: Waveform = Waveform.SINE, p_freq: float = 2.0, p_depth: float = 0.1, p_offset: float = 0.0) -> void:
	target_property = p_target
	waveform = p_wave
	frequency_hz = p_freq
	depth = p_depth
	phase_offset = p_offset

func create_runtime_state() -> RefCounted:
	return LFOStateClass.new(waveform, frequency_hz, depth, phase_offset)
