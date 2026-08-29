class_name LFOState
extends RefCounted

## Dynamic runtime evaluation state for a Low Frequency Oscillator (LFO).

enum Waveform {
	SINE,
	TRIANGLE,
	SQUARE,
	SAWTOOTH
}

var waveform: Waveform = Waveform.SINE
var frequency_hz: float = 2.0
var depth: float = 1.0
var phase: float = 0.0

func _init(p_waveform: Waveform = Waveform.SINE, p_freq: float = 2.0, p_depth: float = 1.0, p_phase_offset: float = 0.0) -> void:
	waveform = p_waveform
	frequency_hz = p_freq
	depth = p_depth
	phase = fmod(p_phase_offset, 1.0)

## Advances oscillator phase and calculates normalized wave output [-1.0, 1.0] * depth.
func process(delta: float) -> float:
	phase += (frequency_hz * delta)
	if phase >= 1.0 or phase < 0.0:
		phase = fmod(phase, 1.0)
		if phase < 0.0:
			phase += 1.0
			
	var raw_wave: float = 0.0
	match waveform:
		Waveform.SINE:
			raw_wave = sin(phase * TAU)
		Waveform.TRIANGLE:
			raw_wave = 1.0 - 4.0 * absf(phase - 0.5)
		Waveform.SQUARE:
			raw_wave = 1.0 if phase < 0.5 else -1.0
		Waveform.SAWTOOTH:
			raw_wave = (2.0 * phase) - 1.0
			
	return raw_wave * depth
