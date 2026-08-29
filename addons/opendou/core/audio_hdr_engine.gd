@tool
class_name AudioHDREngine
extends RefCounted

## High Dynamic Range (HDR) Audio Engine modeling a dynamic loudness window to prevent digital clipping and create visceral acoustic contrast.

signal hdr_window_updated(window_top_db: float, window_bottom_db: float)

## Dynamic loudness window parameters
var hdr_window_size_db: float = 40.0 # Range of audible dynamics (Window Width)
var hdr_window_top_db: float = 0.0   # Current movable top ceiling (0.0 dB default)
var min_window_top_db: float = 0.0   # Floor for top of window
var max_window_top_db: float = 36.0  # Max ceiling for extreme ballistic peaks (+36 dB HDR)

var attack_rate: float = 200.0       # dB per second window can rise
var release_rate: float = 35.0       # dB per second window descends

# Current frame peak tracking
var current_frame_peak_loudness_db: float = 0.0

func _init(p_window_size: float = 40.0, p_release_rate: float = 35.0) -> void:
	hdr_window_size_db = p_window_size
	release_rate = p_release_rate
	hdr_window_top_db = min_window_top_db

## Feeds the loudness of active voices/events in the current frame (in HDR dB, where loud sounds exceed 0 dB, e.g. Explosion = +18 dB, Gunfire = +6 dB).
func push_event_loudness(loudness_hdr_db: float) -> void:
	if loudness_hdr_db > current_frame_peak_loudness_db:
		current_frame_peak_loudness_db = loudness_hdr_db

## Updates the dynamic HDR window position with attack/release physics.
func update(delta: float) -> void:
	var target_top = clampf(current_frame_peak_loudness_db, min_window_top_db, max_window_top_db)
	
	if target_top > hdr_window_top_db:
		# Attack (Window rises quickly with explosions)
		hdr_window_top_db = move_toward(hdr_window_top_db, target_top, attack_rate * delta)
	else:
		# Release (Window returns down smoothly)
		hdr_window_top_db = move_toward(hdr_window_top_db, target_top, release_rate * delta)
		
	# Reset peak for next frame
	current_frame_peak_loudness_db = -80.0
	hdr_window_updated.emit(hdr_window_top_db, hdr_window_top_db - hdr_window_size_db)

## Calculates the output gain (in linear 0.0-1.0 multiplier or dB) for any sound based on the current HDR window position.
func calculate_voice_gain(voice_loudness_hdr_db: float) -> float:
	var window_bottom_db = hdr_window_top_db - hdr_window_size_db
	
	if voice_loudness_hdr_db <= window_bottom_db:
		# Sound is below the audible window -> completely ducked / inaudible
		return 0.0
		
	# Calculate offset relative to window top (0 dB output at window top)
	var output_db = voice_loudness_hdr_db - hdr_window_top_db
	output_db = clampf(output_db, -80.0, 0.0)
	
	return db_to_linear(output_db)

## Calculates output volume in dB.
func calculate_voice_gain_db(voice_loudness_hdr_db: float) -> float:
	var window_bottom_db = hdr_window_top_db - hdr_window_size_db
	if voice_loudness_hdr_db <= window_bottom_db:
		return -80.0
	return clampf(voice_loudness_hdr_db - hdr_window_top_db, -80.0, 0.0)

## Returns current window bounds (top, bottom).
func get_window_bounds() -> Vector2:
	return Vector2(hdr_window_top_db, hdr_window_top_db - hdr_window_size_db)
