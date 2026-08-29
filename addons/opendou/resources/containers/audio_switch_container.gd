@tool
class_name AudioSwitchContainer
extends AudioLogicNode

## Routes audio execution based on a discrete game switch state (e.g. Surface_Type = Metal).

@export var switch_group_name: StringName = &""
@export var default_state: StringName = &""
@export var state_mappings: Dictionary = {} # StringName -> AudioLogicNode

var switch_group: StringName:
	get: return switch_group_name
	set(val): switch_group_name = val

func _init(p_switch_group: StringName = &"", p_default_state: StringName = &"") -> void:
	switch_group_name = p_switch_group
	default_state = p_default_state
	state_mappings = {}

## Maps a discrete switch state to a child logic node.
func set_state_node(state_name: StringName, node: AudioLogicNode) -> void:
	if node:
		state_mappings[state_name] = node

func resolve(context: AudioPlaybackContext, out_voices: Array[ResolvedVoice]) -> bool:
	var current_state: StringName = default_state
	
	if context:
		current_state = context.get_switch(switch_group_name, default_state)
		
	var target_node: AudioLogicNode = null
	if state_mappings.has(current_state):
		target_node = state_mappings[current_state]
	elif state_mappings.has(default_state):
		target_node = state_mappings[default_state]
		
	if target_node:
		return target_node.resolve(context, out_voices)
		
	return false
