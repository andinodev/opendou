class_name TestRoomConvolution
extends RefCounted

const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const ConvolutionReverbNodeClass = preload("res://addons/opendou/core/dsp/convolution_reverb_node.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	var room = OpenDouRoom3DClass.new()
	if room == null:
		failures.append("Test 1 Failed: Could not instantiate OpenDouRoom3D")
		return failures

	# Test reverb modes enum
	if room.reverb_mode != OpenDouRoom3DClass.ReverbMode.ALGORITHMIC:
		failures.append("Test 2 Failed: Default reverb mode should be ALGORITHMIC")

	room.reverb_mode = OpenDouRoom3DClass.ReverbMode.CONVOLUTION_IR
	if room.reverb_mode != OpenDouRoom3DClass.ReverbMode.CONVOLUTION_IR:
		failures.append("Test 3 Failed: Failed to switch reverb mode to CONVOLUTION_IR")

	# Test calibrated FIR kernel processing
	var ir_kernel = PackedFloat32Array()
	ir_kernel.resize(512)
	for i in range(512):
		ir_kernel[i] = exp(-float(i) / 64.0) * sin(float(i) * 0.2)

	var conv = ConvolutionReverbNodeClass.new(ir_kernel)
	var input_signal = PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0])
	var output_signal = conv.process_block(input_signal)

	if output_signal.size() != 5:
		failures.append("Test 4 Failed: Convolution output signal size mismatch")

	if absf(output_signal[0] - 1.0) > 0.1:
		failures.append("Test 5 Failed: Convolution direct signal passthrough mismatch")

	room.free()
	return failures
