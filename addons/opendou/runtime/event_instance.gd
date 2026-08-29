class_name EventInstance
extends RefCounted

## Dynamic runtime instance of an AudioEventDef, managing playback, local RTPCs, modulators, voice state, spatial occlusion and virtualization.

const RTPCValueClass = preload("res://addons/opendou/runtime/rtpc_value.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const RTPCBindingClass = preload("res://addons/opendou/resources/rtpc_binding.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const ResolvedVoiceClass = preload("res://addons/opendou/runtime/resolved_voice.gd")
const AudioModulatorClass = preload("res://addons/opendou/resources/modulators/audio_modulator.gd")
const AHDSRStateClass = preload("res://addons/opendou/runtime/modulators/ahdsr_state.gd")
const LFOStateClass = preload("res://addons/opendou/runtime/modulators/lfo_state.gd")

enum VoiceState {
	STATE_STOPPED,  ## Sound has ended or stopped
	STATE_PHYSICAL, ## Playing on an active hardware/audio channel
	STATE_VIRTUAL,  ## Inaudible or stolen; tracking time logically at 0 CPU cost
	STATE_KILLED    ## Discarded permanently due to resource starvation
}

var definition: AudioEventDef
var caller_id: int = 0
var caller_node_ref: WeakRef = null

# Local RTPC parameters specific to this entity instance
var local_rtpcs: Dictionary = {} # StringName -> RTPCValue

# Modulator runtime states (Array of Dictionaries with {"def": AudioModulator, "state": RefCounted})
var modulator_states: Array[Dictionary] = []

# Spatial Occlusion & Filtering
var current_spatial_lpf: float = 20000.0
var target_spatial_lpf: float = 20000.0
var occlusion_smoothing_speed: float = 8.0
var occlusion_attenuation_db: float = 0.0

# Calculated outputs after curve evaluation, RTPCs, modulators and occlusion
var calculated_volume_db: float = 0.0
var calculated_pitch_scale: float = 1.0
var calculated_properties: Dictionary = {} # StringName -> float

# Voice & Virtualization State
var voice_state: VoiceState = VoiceState.STATE_STOPPED
var virtualization_mode: AudioEventDef.VirtualizationMode = AudioEventDef.VirtualizationMode.VIRTUAL_ELAPSED_TIME
var assigned_channel_id: int = -1
var current_weight: float = 0.0
var logical_playback_position: float = 0.0
var max_distance: float = 100.0

# 3D / Spatial Positioning
var emitter_position: Vector3 = Vector3.ZERO
var has_spatial_position: bool = false

var is_paused_state: bool = false
var is_key_on: bool = true
var elapsed_time: float = 0.0

func _init(p_definition: AudioEventDef, p_caller: Node = null) -> void:
	definition = p_definition
	if p_caller:
		caller_id = p_caller.get_instance_id()
		caller_node_ref = weakref(p_caller)
		if p_caller is Node3D:
			emitter_position = p_caller.global_position
			has_spatial_position = true
		elif p_caller is Node2D:
			emitter_position = Vector3(p_caller.global_position.x, p_caller.global_position.y, 0.0)
			has_spatial_position = true
	
	if definition:
		calculated_volume_db = definition.base_volume_db
		calculated_pitch_scale = definition.base_pitch_scale
		virtualization_mode = definition.virtualization_mode
		
		# Instantiate modulator runtime states
		modulator_states = []
		for mod in definition.modulators:
			if mod:
				var state = mod.create_runtime_state()
				if state:
					modulator_states.append({"def": mod, "state": state})

## Sets a 3D emitter position directly.
func set_position(pos: Vector3) -> void:
	emitter_position = pos
	has_spatial_position = true

## Sets the target spatial low-pass filter cutoff in Hz.
func set_target_lpf(lpf_hz: float, atten_db: float = 0.0) -> void:
	target_spatial_lpf = clampf(lpf_hz, 20.0, 20000.0)
	occlusion_attenuation_db = atten_db

## Calculates the dynamic priority weight for voice stealing.
func calculate_dynamic_weight(listener_pos: Vector3) -> float:
	if not is_playing():
		return 0.0
		
	var base_priority: float = definition.base_priority if definition else 50.0
	
	# Convert volume dB to linear amplitude [0.0, 1.0+]
	var linear_vol: float = db_to_linear(calculated_volume_db)
	
	var distance_factor: float = 1.0
	if has_spatial_position:
		var dist: float = emitter_position.distance_to(listener_pos)
		if dist >= max_distance and max_distance > 0.0:
			return 0.0
		elif max_distance > 0.0:
			distance_factor = maxf(0.0, 1.0 - (dist / max_distance))
			
	return base_priority * linear_vol * distance_factor

## Sets a local RTPC parameter value on this instance.
func set_parameter(param_name: StringName, value: float, immediate: bool = false) -> void:
	if not local_rtpcs.has(param_name):
		local_rtpcs[param_name] = RTPCValueClass.new(value)
	else:
		var rtpc: RTPCValue = local_rtpcs[param_name]
		if immediate:
			rtpc.set_value_immediate(value)
		else:
			rtpc.set_target(value)

## Gets the current parameter value, checking local first, then falling back to global.
func get_parameter(param_name: StringName, global_rtpcs: Dictionary = {}) -> float:
	if local_rtpcs.has(param_name):
		var rtpc: RTPCValue = local_rtpcs[param_name]
		return rtpc.current_value
	elif global_rtpcs.has(param_name):
		var rtpc: RTPCValue = global_rtpcs[param_name]
		return rtpc.current_value
	return 0.0

## Interpolates local RTPC values by delta.
func interpolate_locals(delta: float) -> void:
	for param_name in local_rtpcs:
		var rtpc: RTPCValue = local_rtpcs[param_name]
		rtpc.interpolate(delta)

## Evaluates all RTPC bindings, modulators, spatial occlusion and computes final output properties.
func update_parameters(delta: float, global_rtpcs: Dictionary = {}) -> void:
	if not definition:
		return
		
	elapsed_time += delta
	
	# Update spatial position if caller node is valid
	if caller_node_ref:
		var caller: Object = caller_node_ref.get_ref()
		if caller and caller is Node3D:
			emitter_position = caller.global_position
			has_spatial_position = true
		elif caller and caller is Node2D:
			emitter_position = Vector3(caller.global_position.x, caller.global_position.y, 0.0)
			has_spatial_position = true
	
	# 1. Start from base definition values and apply occlusion volume attenuation
	var vol: float = definition.base_volume_db + occlusion_attenuation_db
	var pitch: float = definition.base_pitch_scale
	calculated_properties.clear()
	
	# 2. Smooth spatial Low-Pass Filter (Slew-rate limit)
	current_spatial_lpf += (target_spatial_lpf - current_spatial_lpf) * clampf(occlusion_smoothing_speed * delta, 0.0, 1.0)
	calculated_properties[&"cutoff_hz"] = current_spatial_lpf
	
	# 3. Evaluate RTPC bindings
	for binding in definition.rtpc_bindings:
		if not binding or binding.parameter_id.is_empty():
			continue
			
		var param_val: float = get_parameter(binding.parameter_id, global_rtpcs)
		var curve_out: float = binding.evaluate(param_val)
		
		match binding.target_property:
			&"volume_db", &"volume", &"Volume":
				vol = binding.apply_to(vol, curve_out)
			&"pitch_scale", &"pitch", &"Pitch":
				pitch = binding.apply_to(pitch, curve_out)
			_:
				var cur_prop: float = calculated_properties.get(binding.target_property, 0.0)
				calculated_properties[binding.target_property] = binding.apply_to(cur_prop, curve_out)
				
	# 4. Evaluate Modulators (AHDSR, LFO)
	var all_modulators_idle: bool = true
	for entry in modulator_states:
		var mod: AudioModulator = entry["def"]
		var state: RefCounted = entry["state"]
		var mod_out: float = 0.0
		
		if state is AHDSRStateClass:
			mod_out = state.process(delta, is_key_on)
			if state.current_state != AHDSRStateClass.State.IDLE:
				all_modulators_idle = false
		elif state is LFOStateClass:
			mod_out = state.process(delta)
			all_modulators_idle = false
			
		match mod.target_property:
			&"volume_db", &"volume", &"Volume":
				vol = mod.apply_to(vol, mod_out)
			&"pitch_scale", &"pitch", &"Pitch":
				pitch = mod.apply_to(pitch, mod_out)
			_:
				var cur_p: float = calculated_properties.get(mod.target_property, 0.0)
				calculated_properties[mod.target_property] = mod.apply_to(cur_p, mod_out)
				
	# If stop was requested and all AHDSR modulators reached IDLE, conclude playback
	if not is_key_on and (modulator_states.is_empty() or all_modulators_idle):
		voice_state = VoiceState.STATE_STOPPED
		
	calculated_volume_db = vol
	calculated_pitch_scale = pitch

## Advances logical playback position for virtual voices with pitch scaling and loop wrapping.
func advance_virtual_time(delta: float) -> void:
	if voice_state != VoiceState.STATE_VIRTUAL or is_paused_state:
		return
		
	match virtualization_mode:
		AudioEventDef.VirtualizationMode.VIRTUAL_ELAPSED_TIME:
			var effective_pitch: float = maxf(0.01, calculated_pitch_scale)
			logical_playback_position += (delta * effective_pitch)
			
			if definition and definition.stream_length > 0.0:
				if definition.is_looping:
					logical_playback_position = fmod(logical_playback_position, definition.stream_length)
				else:
					if logical_playback_position >= definition.stream_length:
						voice_state = VoiceState.STATE_STOPPED
		AudioEventDef.VirtualizationMode.VIRTUAL_PLAY_FROM_START:
			logical_playback_position = 0.0
		AudioEventDef.VirtualizationMode.VIRTUAL_RESUME:
			pass
		AudioEventDef.VirtualizationMode.VIRTUAL_KILL_VOICE:
			voice_state = VoiceState.STATE_KILLED

## Starts playback of the event instance.
func play() -> void:
	voice_state = VoiceState.STATE_VIRTUAL # Starts virtual until pool assigns physical channel
	is_paused_state = false
	is_key_on = true
	logical_playback_position = 0.0
	elapsed_time = 0.0

## Stops playback of the event instance (triggers AHDSR Release phase).
func stop(_fade_time: float = 0.0) -> void:
	is_key_on = false
	if modulator_states.is_empty():
		voice_state = VoiceState.STATE_STOPPED
		assigned_channel_id = -1

## Pauses playback of the event instance.
func pause() -> void:
	if is_playing():
		is_paused_state = true

## Resumes playback of the event instance.
func resume() -> void:
	if is_paused_state:
		is_paused_state = false

func is_playing() -> bool:
	return (voice_state == VoiceState.STATE_PHYSICAL or voice_state == VoiceState.STATE_VIRTUAL) and not is_paused_state

func is_finished() -> bool:
	return voice_state == VoiceState.STATE_STOPPED or voice_state == VoiceState.STATE_KILLED
