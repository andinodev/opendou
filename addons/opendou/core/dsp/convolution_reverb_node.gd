@tool
class_name ConvolutionReverbNode
extends RefCounted

## Convolution Reverb DSP filter applying real-world acoustic Impulse Responses (IR) via time-domain convolution.

var ir_samples: PackedFloat32Array = PackedFloat32Array()
var ir_sample_rate: int = 44100

var wet_gain_db: float = 0.0
var dry_gain_db: float = 0.0
var pre_delay_ms: float = 0.0

# Delay line history for convolution
var history_buffer: PackedFloat32Array = PackedFloat32Array()
var history_pos: int = 0

func _init(p_ir: PackedFloat32Array = PackedFloat32Array(), p_rate: int = 44100) -> void:
	ir_sample_rate = p_rate
	set_impulse_response(p_ir)

## Sets the Impulse Response (IR) kernel and prepares internal FIR delay line.
func set_impulse_response(ir: PackedFloat32Array) -> void:
	ir_samples = ir
	var ir_len = ir.size()
	if ir_len > 0:
		history_buffer.resize(ir_len)
		history_buffer.fill(0.0)
	else:
		history_buffer.clear()
	history_pos = 0

## Processes a mono audio block through the convolution reverb filter.
func process_block(input_samples: PackedFloat32Array) -> PackedFloat32Array:
	var out_samples = PackedFloat32Array()
	var in_len = input_samples.size()
	out_samples.resize(in_len)
	
	var ir_len = ir_samples.size()
	if ir_len == 0:
		# Passthrough if no IR loaded
		return input_samples.duplicate()
		
	var dry_gain = 0.0 if dry_gain_db <= -60.0 else db_to_linear(dry_gain_db)
	var wet_gain = 0.0 if wet_gain_db <= -60.0 else db_to_linear(wet_gain_db)
	
	for i in range(in_len):
		var dry_sample = input_samples[i]
		
		# Write to circular history buffer
		history_buffer[history_pos] = dry_sample
		
		# Discrete Convolution: y[n] = sum(x[n - k] * h[k])
		var wet_acc: float = 0.0
		var read_idx = history_pos
		
		for k in range(ir_len):
			wet_acc += history_buffer[read_idx] * ir_samples[k]
			read_idx -= 1
			if read_idx < 0:
				read_idx = ir_len - 1
				
		out_samples[i] = (dry_sample * dry_gain) + (wet_acc * wet_gain)
		
		history_pos += 1
		if history_pos >= ir_len:
			history_pos = 0
			
	return out_samples
