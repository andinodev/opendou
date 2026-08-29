class_name RTPCValue
extends RefCounted

## Represents a real-time parameter control with slew-rate interpolation.

var current_value: float = 0.0
var target_value: float = 0.0
var attack_speed: float = 10.0 # Units per second when increasing
var release_speed: float = 10.0 # Units per second when decreasing

func _init(p_initial_value: float = 0.0, p_attack_speed: float = 10.0, p_release_speed: float = 10.0) -> void:
	current_value = p_initial_value
	target_value = p_initial_value
	attack_speed = p_attack_speed
	release_speed = p_release_speed

## Sets the target value towards which current_value will interpolate.
func set_target(p_value: float) -> void:
	target_value = p_value

## Sets both current and target values immediately without interpolation.
func set_value_immediate(p_value: float) -> void:
	current_value = p_value
	target_value = p_value

## Interpolates current_value towards target_value based on elapsed delta time.
func interpolate(delta: float) -> void:
	if current_value < target_value:
		current_value += attack_speed * delta
		if current_value > target_value:
			current_value = target_value
	elif current_value > target_value:
		current_value -= release_speed * delta
		if current_value < target_value:
			current_value = target_value

## Returns true if current value has reached target value.
func is_at_target() -> bool:
	return is_equal_approx(current_value, target_value)
