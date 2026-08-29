@tool
class_name RTPCBinding
extends Resource

## Defines how a Real-Time Parameter Control (RTPC) modulates an audio property with O(1) LUT curve acceleration.

enum Operation {
	ADD,       ## Value from curve is added to base property value
	MULTIPLY,  ## Value from curve is multiplied with base property value
	OVERRIDE   ## Value from curve overrides base property value
}

@export var parameter_id: StringName = &""
@export var target_property: StringName = &"volume_db" # e.g. "volume_db", "pitch_scale", "cutoff_hz"
@export var modulation_curve: Curve:
	set(val):
		modulation_curve = val
		bake_lut()

@export var math_operation: Operation = Operation.ADD

# Input parameter normalization range
@export var min_input_value: float = 0.0
@export var max_input_value: float = 100.0

# Pre-baked lookup table for O(1) constant-time evaluation
var baked_lut: PackedFloat32Array = PackedFloat32Array()
var lut_size: int = 256

func _init(p_param_id: StringName = &"", p_target_property: StringName = &"volume_db", p_curve: Curve = null, p_op: Operation = Operation.ADD, p_min: float = 0.0, p_max: float = 100.0) -> void:
	parameter_id = p_param_id
	target_property = p_target_property
	math_operation = p_op
	min_input_value = p_min
	max_input_value = p_max
	modulation_curve = p_curve
	bake_lut()

## Bakes the modulation curve into an equidistant Lookup Table (LUT) for O(1) performance.
func bake_lut(samples: int = 256) -> void:
	lut_size = max(16, samples)
	baked_lut = PackedFloat32Array()
	baked_lut.resize(lut_size)
	
	if not modulation_curve:
		for i in range(lut_size):
			var norm: float = float(i) / float(lut_size - 1)
			baked_lut[i] = lerpf(min_input_value, max_input_value, norm)
		return
		
	for i in range(lut_size):
		var norm_pos: float = float(i) / float(lut_size - 1)
		# Sample curve at normalized X coordinate
		baked_lut[i] = modulation_curve.sample_baked(norm_pos)

## Evaluates the parameter in constant O(1) time using the pre-baked lookup table.
func evaluate_fast(param_value: float) -> float:
	if baked_lut.is_empty():
		bake_lut(lut_size)
		
	var span: float = max_input_value - min_input_value
	var norm_val: float = 0.0
	if span != 0.0:
		norm_val = clampf((param_value - min_input_value) / span, 0.0, 1.0)
		
	var index: int = clampi(int(round(norm_val * float(lut_size - 1))), 0, lut_size - 1)
	return baked_lut[index]

## General evaluation function (defaults to O(1) LUT).
func evaluate(param_value: float) -> float:
	if not baked_lut.is_empty():
		return evaluate_fast(param_value)
	elif modulation_curve:
		return modulation_curve.sample_baked(param_value)
	return param_value

## Applies the evaluated curve output to an accumulator value based on math_operation.
func apply_to(base_value: float, curve_output: float) -> float:
	match math_operation:
		Operation.ADD:
			return base_value + curve_output
		Operation.MULTIPLY:
			return base_value * curve_output
		Operation.OVERRIDE:
			return curve_output
		_:
			return base_value + curve_output
