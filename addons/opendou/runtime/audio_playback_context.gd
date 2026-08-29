class_name AudioPlaybackContext
extends RefCounted

## Context injected at playback resolution time containing active RTPC and Switch states.

var rtpc_values: Dictionary = {}    # StringName -> float
var switch_states: Dictionary = {}  # StringName -> StringName

func _init(p_rtpcs: Dictionary = {}, p_switches: Dictionary = {}) -> void:
	rtpc_values = p_rtpcs.duplicate()
	switch_states = p_switches.duplicate()

## Sets an RTPC float value in the context.
func set_rtpc(param_name: StringName, value: float) -> void:
	rtpc_values[param_name] = value

## Alias for set_rtpc
func set_rtpc_value(param_name: StringName, value: float) -> void:
	rtpc_values[param_name] = value

## Gets an RTPC float value, returning default_value if not found.
func get_rtpc(param_name: StringName, default_value: float = 0.0) -> float:
	return rtpc_values.get(param_name, default_value)

## Sets a discrete switch state in the context.
func set_switch(group_name: StringName, state_name: StringName) -> void:
	switch_states[group_name] = state_name

## Gets a switch state, returning default_state if not found.
func get_switch(group_name: StringName, default_state: StringName = &"") -> StringName:
	return switch_states.get(group_name, default_state)
