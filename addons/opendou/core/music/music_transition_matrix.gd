@tool
class_name MusicTransitionMatrix
extends RefCounted

## Handles quantized transition rules and synchronous crossfades between musical segments.

enum SyncMode {
	IMMEDIATE,
	NEXT_BEAT,
	NEXT_BAR,
	END_OF_SEGMENT
}

signal transition_queued(from_segment: MusicSegment, to_segment: MusicSegment, mode: SyncMode)
signal transition_started(from_segment: MusicSegment, to_segment: MusicSegment)
signal transition_completed(active_segment: MusicSegment)

var current_segment: MusicSegment = null
var target_segment: MusicSegment = null
var pending_sync_mode: SyncMode = SyncMode.NEXT_BAR

var is_waiting_for_quantize: bool = false
var is_crossfading: bool = false
var crossfade_duration: float = 1.5
var crossfade_progress: float = 1.0

# Gain multipliers (0.0 to 1.0)
var current_segment_fade_gain: float = 1.0
var target_segment_fade_gain: float = 0.0

func _init(initial_segment: MusicSegment = null) -> void:
	current_segment = initial_segment
	current_segment_fade_gain = 1.0

## Requests a transition to a target segment respecting rhythmic quantization.
func request_transition(to_segment: MusicSegment, sync_mode: SyncMode = SyncMode.NEXT_BAR, fade_time: float = 1.5) -> void:
	if to_segment == current_segment and not is_crossfading:
		return
		
	target_segment = to_segment
	pending_sync_mode = sync_mode
	crossfade_duration = maxf(fade_time, 0.05)
	
	if sync_mode == SyncMode.IMMEDIATE:
		_start_crossfade()
	else:
		is_waiting_for_quantize = true
		transition_queued.emit(current_segment, target_segment, sync_mode)

func notify_beat() -> void:
	if is_waiting_for_quantize and pending_sync_mode == SyncMode.NEXT_BEAT:
		_start_crossfade()

func notify_bar() -> void:
	if is_waiting_for_quantize and (pending_sync_mode == SyncMode.NEXT_BAR or pending_sync_mode == SyncMode.END_OF_SEGMENT):
		_start_crossfade()

func _start_crossfade() -> void:
	is_waiting_for_quantize = false
	is_crossfading = true
	crossfade_progress = 0.0
	transition_started.emit(current_segment, target_segment)

func update(delta: float) -> void:
	if not is_crossfading:
		return
		
	crossfade_progress += delta / crossfade_duration
	var t = clampf(crossfade_progress, 0.0, 1.0)
	
	# Equal-power sine crossfade
	current_segment_fade_gain = cos(t * PI * 0.5)
	target_segment_fade_gain = sin(t * PI * 0.5)
	
	if crossfade_progress >= 1.0:
		is_crossfading = false
		current_segment = target_segment
		target_segment = null
		current_segment_fade_gain = 1.0
		target_segment_fade_gain = 0.0
		transition_completed.emit(current_segment)
