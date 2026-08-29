class_name PhysicalVoiceChannel
extends RefCounted

## Represents a single hardware-level voice channel capable of playing audio with anti-click micro-fades and dynamic bus routing.

var channel_id: int = -1
var is_busy: bool = false
var assigned_instance_ref: WeakRef = null

# Target mixing bus in Godot AudioServer
var target_bus: StringName = &"Master"

# Micro-fade tracking to avoid audio pops on voice stealing / stopping
var is_fading_out: bool = false
var is_fading_in: bool = false
var fade_duration_sec: float = 0.015 # 15ms default
var fade_timer: float = 0.0
var current_fade_gain: float = 1.0 # 0.0 to 1.0 multiplier

var current_stream: AudioStream = null
var current_volume_db: float = 0.0
var current_pitch: float = 1.0
var playback_start_offset: float = 0.0

func _init(p_channel_id: int = -1) -> void:
	channel_id = p_channel_id
	is_busy = false
	target_bus = &"Master"

## Sets the destination audio mixing bus for this channel.
func set_bus(p_bus: StringName) -> void:
	target_bus = p_bus if not p_bus.is_empty() else &"Master"

## Assigns and plays a stream on this physical channel with an optional micro-fade in.
func play_stream(stream: AudioStream, start_offset: float = 0.0, volume_db: float = 0.0, pitch: float = 1.0, bus_name: StringName = &"Master") -> void:
	current_stream = stream
	playback_start_offset = start_offset
	current_volume_db = volume_db
	current_pitch = pitch
	set_bus(bus_name)
	
	is_busy = true
	is_fading_out = false
	is_fading_in = true
	fade_duration_sec = 0.010 # 10ms micro-fade in
	fade_timer = 0.0
	current_fade_gain = 0.0

## Triggers a soft micro-fade out before fully releasing the channel.
func stop_with_fade(fade_time_sec: float = 0.015) -> void:
	if not is_busy:
		return
	fade_duration_sec = maxf(0.005, fade_time_sec)
	is_fading_out = true
	is_fading_in = false
	fade_timer = fade_duration_sec

## Stops and frees the channel immediately.
func stop_immediate() -> void:
	is_busy = false
	is_fading_out = false
	is_fading_in = false
	current_stream = null
	assigned_instance_ref = null
	current_fade_gain = 0.0

## Processes fade-out and fade-in gain multipliers per frame.
func process_fade(delta: float) -> void:
	if not is_busy:
		return
		
	if is_fading_out:
		fade_timer -= delta
		current_fade_gain = clampf(fade_timer / fade_duration_sec, 0.0, 1.0)
		if fade_timer <= 0.0:
			stop_immediate()
	elif is_fading_in:
		fade_timer += delta
		current_fade_gain = clampf(fade_timer / fade_duration_sec, 0.0, 1.0)
		if fade_timer >= fade_duration_sec:
			is_fading_in = false
			current_fade_gain = 1.0
	else:
		current_fade_gain = 1.0
