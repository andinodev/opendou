class_name TestDSPAdvanced
extends RefCounted

const ConvolutionReverbNodeClass = preload("res://addons/opendou/core/dsp/convolution_reverb_node.gd")
const AudioGranularSynthesizerClass = preload("res://addons/opendou/core/dsp/audio_granular_synthesizer.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: Convolution Reverb with simple Delta Impulse Response
	# Delta IR [1.0, 0.0, 0.0] -> convolution should reproduce exact dry input
	var delta_ir = PackedFloat32Array([1.0, 0.0, 0.0])
	var reverb = ConvolutionReverbNodeClass.new(delta_ir, 44100)
	reverb.dry_gain_db = -80.0 # 100% wet
	reverb.wet_gain_db = 0.0
	
	var test_in = PackedFloat32Array([0.5, -0.25, 0.75, 0.0])
	var test_out = reverb.process_block(test_in)
	
	if test_out.size() != test_in.size():
		failures.append("Test 1a Failed: Output size mismatch (expected %d, got %d)" % [test_in.size(), test_out.size()])
	elif not is_equal_approx(test_out[0], 0.5) or not is_equal_approx(test_out[1], -0.25):
		failures.append("Test 1b Failed: Delta IR convolution output incorrect (got %f, %f)" % [test_out[0], test_out[1]])
		
	# Test 2: Convolution Reverb with 2-tap Echo IR [1.0, 0.5]
	var echo_ir = PackedFloat32Array([0.5, 0.5])
	var echo_reverb = ConvolutionReverbNodeClass.new(echo_ir, 44100)
	echo_reverb.dry_gain_db = -80.0
	echo_reverb.wet_gain_db = 0.0
	
	var impulse_in = PackedFloat32Array([1.0, 0.0, 0.0])
	var echo_out = echo_reverb.process_block(impulse_in)
	if not is_equal_approx(echo_out[0], 0.5) or not is_equal_approx(echo_out[1], 0.5):
		failures.append("Test 2 Failed: Echo IR convolution output incorrect (got %f, %f)" % [echo_out[0], echo_out[1]])
		
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
