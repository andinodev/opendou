class_name GameSyncManager
extends RefCounted

## Centralized Game Syncs Manager for RTPCs, States with crossfades, entity Switches, and Triggers.

const RTPCValueClass = preload("res://addons/opendou/runtime/rtpc_value.gd")

class StateTransition:
	var group_name: StringName
	var previous_state: StringName
	var current_state: StringName
	var transition_duration: float = 0.0
	var transition_timer: float = 0.0
	var transition_weight: float = 1.0 # 0.0 to 1.0 (1.0 = fully transitioned)

	func _init(p_group: StringName, p_state: StringName) -> void:
		group_name = p_group
		previous_state = p_state
		current_state = p_state
		transition_duration = 0.0
		transition_timer = 0.0
		transition_weight = 1.0

# Global game parameters (RTPCs)
var global_rtpcs: Dictionary = {} # StringName -> RTPCValue

# Global game states with transition tracking
var global_states: Dictionary = {} # StringName -> StateTransition

# Global and entity-specific switches
var global_switches: Dictionary = {} # StringName -> StringName
var entity_switches: Dictionary = {} # int (instance_id) -> Dictionary (StringName -> StringName)

# Triggers and listeners
var trigger_listeners: Dictionary = {} # StringName -> Array[Callable]

# Signals
signal state_changed(group_name: StringName, new_state: StringName, previous_state: StringName)
signal trigger_posted(trigger_name: StringName)

# ==============================================================================
# RTPC API
# ==============================================================================

## Sets a global RTPC value with optional immediate override.
func set_rtpc(param_name: StringName, value: float, immediate: bool = false, attack_speed: float = 10.0, release_speed: float = 10.0) -> void:
	if not global_rtpcs.has(param_name):
		global_rtpcs[param_name] = RTPCValueClass.new(value, attack_speed, release_speed)
	else:
		var rtpc: RTPCValue = global_rtpcs[param_name]
		if immediate:
			rtpc.set_value_immediate(value)
		else:
			rtpc.set_target(value)

## Gets the current value of a global RTPC.
func get_rtpc(param_name: StringName, default_value: float = 0.0) -> float:
	if global_rtpcs.has(param_name):
		var rtpc: RTPCValue = global_rtpcs[param_name]
		return rtpc.current_value
	return default_value

# ==============================================================================
# STATE API (Global Context with smooth transitions)
# ==============================================================================

## Sets a global game state with an optional transition time for crossfading.
func set_state(group_name: StringName, state_name: StringName, transition_duration_sec: float = 0.0) -> void:
	if not global_states.has(group_name):
		var trans = StateTransition.new(group_name, state_name)
		global_states[group_name] = trans
		state_changed.emit(group_name, state_name, &"")
		return
		
	var trans: StateTransition = global_states[group_name]
	if trans.current_state == state_name and trans.transition_weight >= 1.0:
		return
		
	trans.previous_state = trans.current_state
	trans.current_state = state_name
	
	if transition_duration_sec > 0.0:
		trans.transition_duration = transition_duration_sec
		trans.transition_timer = 0.0
		trans.transition_weight = 0.0
	else:
		trans.transition_duration = 0.0
		trans.transition_timer = 0.0
		trans.transition_weight = 1.0
		
	state_changed.emit(group_name, state_name, trans.previous_state)

## Gets the current target state name for a state group.
func get_state(group_name: StringName, default_state: StringName = &"") -> StringName:
	if global_states.has(group_name):
		var trans: StateTransition = global_states[group_name]
		return trans.current_state
	return default_state

## Gets the current interpolation progress weight [0.0, 1.0] of a state transition.
func get_state_transition_weight(group_name: StringName) -> float:
	if global_states.has(group_name):
		var trans: StateTransition = global_states[group_name]
		return trans.transition_weight
	return 1.0

# ==============================================================================
# SWITCH API (Entity-Scoped and Global Defaults)
# ==============================================================================

## Sets a switch value, either globally or scoped to a specific entity node.
func set_switch(group_name: StringName, state_name: StringName, entity: Node = null) -> void:
	if entity:
		var id: int = entity.get_instance_id()
		if not entity_switches.has(id):
			entity_switches[id] = {}
		entity_switches[id][group_name] = state_name
	else:
		global_switches[group_name] = state_name

## Gets a switch value, checking entity scope first, then global, then default.
func get_switch(group_name: StringName, entity: Node = null, default_state: StringName = &"") -> StringName:
	if entity:
		var id: int = entity.get_instance_id()
		if entity_switches.has(id) and entity_switches[id].has(group_name):
			return entity_switches[id][group_name]
			
	if global_switches.has(group_name):
		return global_switches[group_name]
		
	return default_state

## Cleans up switches for a freed entity.
func remove_entity(entity_id: int) -> void:
	entity_switches.erase(entity_id)

# ==============================================================================
# TRIGGER API (One-Shot Events / Stingers)
# ==============================================================================

## Posts a trigger (e.g. musical stinger, sync point).
func post_trigger(trigger_name: StringName) -> void:
	trigger_posted.emit(trigger_name)
	if trigger_listeners.has(trigger_name):
		var callbacks: Array = trigger_listeners[trigger_name]
		for cb in callbacks:
			if cb.is_valid():
				cb.call(trigger_name)

## Registers a callback function to be called when a specific trigger is posted.
func register_trigger_listener(trigger_name: StringName, callback: Callable) -> void:
	if not trigger_listeners.has(trigger_name):
		trigger_listeners[trigger_name] = []
	if not trigger_listeners[trigger_name].has(callback):
		trigger_listeners[trigger_name].append(callback)

# ==============================================================================
# PER-FRAME UPDATE LOOP
# ==============================================================================

## Updates RTPC interpolations and state transitions.
func process(delta: float) -> void:
	# 1. Update RTPC values
	for param_name in global_rtpcs:
		var rtpc: RTPCValue = global_rtpcs[param_name]
		rtpc.interpolate(delta)
		
	# 2. Update State transitions
	for group_name in global_states:
		var trans: StateTransition = global_states[group_name]
		if trans.transition_weight < 1.0:
			trans.transition_timer += delta
			if trans.transition_duration > 0.0:
				trans.transition_weight = clampf(trans.transition_timer / trans.transition_duration, 0.0, 1.0)
			else:
				trans.transition_weight = 1.0
