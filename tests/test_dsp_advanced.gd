class_name TestDSPAdvanced
extends RefCounted

const AudioGranularSynthesizerClass = preload("res://addons/opendou/core/dsp/audio_granular_synthesizer.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Las dos pruebas de convolucion que habia aqui se retiraron con
	# ConvolutionReverbNode: 512 taps por muestra en GDScript es DSP interpretado,
	# y el reverb pasa a aplicarlo Godot en C++ sobre un bus. El RT60 derivado de
	# un IR se prueba en test_ir_rt60.gd.

	# Test 3: Granular Synthesizer block generation
	var sine_src = PackedFloat32Array()
	sine_src.resize(1000)
	for i in range(1000):
		sine_src[i] = sin(float(i) * 0.1)
		
	var gran_synth = AudioGranularSynthesizerClass.new(sine_src, 44100)
	gran_synth.grain_rate_hz = 100.0
	gran_synth.grain_size_ms = 20.0
	gran_synth.spawn_grain()
	
	var gran_block = gran_synth.generate_block(256)
	if gran_block.size() != 256:
		failures.append("Test 3a Failed: Granular block size mismatch (got %d)" % gran_block.size())
	
	# Verify that samples are within valid audio range [-1.0, 1.0]
	var all_valid = true
	for s in gran_block:
		if s < -1.0 or s > 1.0 or is_nan(s):
			all_valid = false
			break
	if not all_valid:
		failures.append("Test 3b Failed: Granular synthesis produced clipping or NaN audio samples")
		
	return failures
