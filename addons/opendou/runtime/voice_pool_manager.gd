class_name VoicePoolManager
extends RefCounted

## Manages fixed hardware audio channels, deterministic voice stealing, zero-cost virtual tracking, and bus routing.

const PhysicalVoiceChannelClass = preload("res://addons/opendou/runtime/physical_voice_channel.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")

var max_physical_voices: int = 64
var channels: Array[PhysicalVoiceChannel] = []

# Anti-thrashing hysteresis bonus for currently physical voices
var hysteresis_bonus: float = 1.05
var min_audibility_threshold: float = 0.001

func _init(p_max_voices: int = 64) -> void:
	max_physical_voices = max(1, p_max_voices)
	channels = []
	for i in range(max_physical_voices):
		channels.append(PhysicalVoiceChannelClass.new(i))

## Finds an available physical channel or returns -1 if all are occupied.
func find_free_channel() -> int:
	for i in range(channels.size()):
		if not channels[i].is_busy:
			return i
	return -1

## Resolves voice stealing and assigns hardware channels to highest priority instances.
func resolve_voice_stealing(active_instances: Array[EventInstance], listener_pos: Vector3, delta: float) -> void:
	# 1. Update channel fade states
	for ch in channels:
		ch.process_fade(delta)
		
	# 2. Calculate dynamic weights and advance virtual times
	var candidates: Array[EventInstance] = []
	for instance in active_instances:
		if not instance or not instance.is_playing():
			continue
			
		instance.advance_virtual_time(delta)
		
		# If instance finished naturally during virtual time, skip
		if not instance.is_playing():
			continue
			
		var weight: float = instance.calculate_dynamic_weight(listener_pos)
		
		# Apply hysteresis bonus to already physical voices
		if instance.voice_state == EventInstanceClass.VoiceState.STATE_PHYSICAL:
			weight *= hysteresis_bonus
			
		instance.current_weight = weight
		candidates.append(instance)
		
	# 3. Sort candidates from HIGHEST to LOWEST weight
	candidates.sort_custom(func(a: EventInstance, b: EventInstance) -> bool:
		return a.current_weight > b.current_weight
	)
	
	# 4. Allocate top candidates to physical channels, virtualize the rest
	for i in range(candidates.size()):
		var instance: EventInstance = candidates[i]
		
		if i < max_physical_voices and instance.current_weight >= min_audibility_threshold:
			if instance.voice_state == EventInstanceClass.VoiceState.STATE_VIRTUAL:
				devirtualize(instance)
		else:
			if instance.voice_state == EventInstanceClass.VoiceState.STATE_PHYSICAL:
				virtualize(instance)

## Transitions an instance to virtual state and frees its physical channel.
func virtualize(instance: EventInstance) -> void:
	if not instance:
		return
		
	if instance.assigned_channel_id >= 0 and instance.assigned_channel_id < channels.size():
		var ch: PhysicalVoiceChannel = channels[instance.assigned_channel_id]
		ch.stop_with_fade()
		instance.assigned_channel_id = -1
		
	if instance.virtualization_mode == AudioEventDefClass.VirtualizationMode.VIRTUAL_KILL_VOICE:
		instance.voice_state = EventInstanceClass.VoiceState.STATE_KILLED
	else:
		instance.voice_state = EventInstanceClass.VoiceState.STATE_VIRTUAL

## Transitions an instance from virtual to physical state, configuring the mercenary channel.
func devirtualize(instance: EventInstance) -> void:
	if not instance:
		return
		
	var free_ch_id: int = find_free_channel()
	if free_ch_id < 0:
		return
		
	instance.assigned_channel_id = free_ch_id
	instance.voice_state = EventInstanceClass.VoiceState.STATE_PHYSICAL
	
	var ch: PhysicalVoiceChannel = channels[free_ch_id]
	ch.assigned_instance_ref = weakref(instance)
	
	var voices = instance.definition.resolve_voices() if instance.definition else []
	var stream = voices[0].stream if not voices.is_empty() else (instance.definition.base_stream if instance.definition else null)
	
	var start_offset: float = 0.0
	if instance.virtualization_mode == AudioEventDefClass.VirtualizationMode.VIRTUAL_ELAPSED_TIME:
		start_offset = instance.logical_playback_position
		
	var bus_name: StringName = instance.definition.target_bus if instance.definition else &"Master"
	
	ch.play_stream(stream, start_offset, instance.calculated_volume_db, instance.calculated_pitch_scale, bus_name)

## Returns the number of active physical voices.
func get_active_physical_count() -> int:
	var count: int = 0
	for ch in channels:
		if ch.is_busy:
			count += 1
	return count

## Returns the number of active virtual voices.
func get_active_virtual_count(active_instances: Array[EventInstance]) -> int:
	var count: int = 0
	for inst in active_instances:
		if inst and inst.voice_state == EventInstanceClass.VoiceState.STATE_VIRTUAL:
			count += 1
	return count
