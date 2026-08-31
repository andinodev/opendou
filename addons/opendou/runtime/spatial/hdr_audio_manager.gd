@tool
class_name HDRAudioManager
extends RefCounted

## AAA High Dynamic Range (HDR) Audio Loudness Window & Transient Ducking Manager.
## Dynamically raises the loudness window when high-impact transient audio occurs (e.g. explosions, heavy cannon fire),
## seamlessly compressing and ducking quiet ambient background sounds with exponential release recovery.

## Dynamic range window span in dB (difference between top threshold and floor).
var window_range_db: float = 40.0

## Default baseline top threshold in dB FS.
var top_threshold_db: float = -6.0

## Release recovery time in seconds.
var release_time_sec: float = 0.35

## Current real-time floating window top in dB FS.
var current_window_top_db: float = -6.0

## Current real-time dynamic floor in dB FS.
var current_floor_db: float = -46.0

func _init() -> void:
	current_window_top_db = top_threshold_db
	current_floor_db = current_window_top_db - window_range_db

## Ingests an audio loudness event and expands the HDR window if the event exceeds the current ceiling.
func register_loudness_event(event_loudness_db: float) -> void:
	if event_loudness_db > current_window_top_db:
		current_window_top_db = clampf(event_loudness_db, -60.0, 12.0)
		current_floor_db = current_window_top_db - window_range_db

## Calculates the output linear gain for a voice given its nominal level in dB FS.
## Voices within the active window receive 1.0 (unaltered); voices falling below the floor are smoothly ducked.
func calculate_voice_gain(voice_nominal_db: float) -> float:
	if voice_nominal_db >= current_floor_db:
		return 1.0
	var under_db: float = current_floor_db - voice_nominal_db
	var duck_linear: float = db_to_linear(-under_db)
	return clampf(duck_linear, 0.0, 1.0)

## Smoothly recovers the HDR window top back to baseline over elapsed time.
func process_decay(delta: float) -> void:
	if current_window_top_db > top_threshold_db:
		var decay_speed: float = (delta / maxf(0.001, release_time_sec)) * 20.0
		current_window_top_db = maxf(top_threshold_db, current_window_top_db - decay_speed)
		current_floor_db = current_window_top_db - window_range_db
