@tool
class_name MusicClock
extends RefCounted

## High-precision musical tempo and meter clock tracking BPM, beats, bars, and quantized rhythmic triggers.

signal beat_hit(beat_index: int, bar_index: int)
signal bar_hit(bar_index: int)

var bpm: float = 120.0
var time_signature_num: int = 4
var time_signature_den: int = 4

var current_time_sec: float = 0.0
var is_playing: bool = false

var current_beat: int = 0
var current_bar: int = 0
var prev_beat: int = -1
var prev_bar: int = -1

func _init(p_bpm: float = 120.0, p_num: int = 4, p_den: int = 4) -> void:
	bpm = p_bpm
	time_signature_num = p_num
	time_signature_den = p_den

func get_seconds_per_beat() -> float:
	return 60.0 / maxf(bpm, 1.0)

func get_seconds_per_bar() -> float:
	return get_seconds_per_beat() * float(time_signature_num)

func start() -> void:
	is_playing = true
	current_time_sec = 0.0
	current_beat = 0
	current_bar = 0
	prev_beat = -1
	prev_bar = -1

func stop() -> void:
	is_playing = false
	current_time_sec = 0.0

func seek(time_sec: float) -> void:
	current_time_sec = maxf(time_sec, 0.0)
	_recalculate_position()

func update(delta: float) -> void:
	if not is_playing:
		return
		
	current_time_sec += delta
	_recalculate_position()

func _recalculate_position() -> void:
	var sec_per_beat = get_seconds_per_beat()
	var total_beats = int(current_time_sec / sec_per_beat)
	
	current_bar = int(total_beats / time_signature_num)
	current_beat = total_beats % time_signature_num
	
	if current_beat != prev_beat:
		prev_beat = current_beat
		beat_hit.emit(current_beat, current_bar)
		
	if current_bar != prev_bar:
		prev_bar = current_bar
		bar_hit.emit(current_bar)

## Returns the time in seconds remaining until the next quantized beat boundary.
func get_time_to_next_beat() -> float:
	var sec_per_beat = get_seconds_per_beat()
	var beat_pos = fposmod(current_time_sec, sec_per_beat)
	return sec_per_beat - beat_pos

## Returns the time in seconds remaining until the next quantized bar boundary.
func get_time_to_next_bar() -> float:
	var sec_per_bar = get_seconds_per_bar()
	var bar_pos = fposmod(current_time_sec, sec_per_bar)
	return sec_per_bar - bar_pos
