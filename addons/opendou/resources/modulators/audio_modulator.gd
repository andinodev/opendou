@tool
class_name AudioModulator
extends Resource

## Base class for autonomous runtime parameter modulators (AHDSR envelopes, LFOs).

enum Operation {
	ADD,       ## Modulator output is added to base/RTPC value
	MULTIPLY,  ## Modulator output is multiplied with base/RTPC value
	OVERRIDE   ## Modulator output overrides value
}

@export var target_property: StringName = &"volume_db"
@export var math_operation: Operation = Operation.ADD
@export var depth: float = 1.0

## Factory method to create the corresponding dynamic runtime state object.
func create_runtime_state() -> RefCounted:
	return null

## Applies the evaluated modulator output to a base property value.
func apply_to(base_val: float, mod_output: float) -> float:
	var scaled_mod: float = mod_output * depth
	match math_operation:
		Operation.ADD:
			return base_val + scaled_mod
		Operation.MULTIPLY:
			return base_val * scaled_mod
		Operation.OVERRIDE:
			return scaled_mod
		_:
			return base_val + scaled_mod
