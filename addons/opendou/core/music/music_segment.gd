@tool
class_name MusicSegment
extends RefCounted

## Represents an interactive musical section (e.g. Combat_Loop, Stealth_Intro, Boss_Phase) composed of multiple synchronous tracks.

var segment_name: StringName = &"Segment"
var tracks: Array[MusicTrack] = []
var duration_bars: int = 8
var is_looping: bool = true

func _init(p_name: StringName = &"Segment", p_duration_bars: int = 8, p_loop: bool = true) -> void:
	segment_name = p_name
	duration_bars = p_duration_bars
	is_looping = p_loop

func add_track(track: MusicTrack) -> void:
	tracks.append(track)

## Evaluates volume gains for all child tracks according to game intensity.
func evaluate_tracks(global_intensity: float) -> Dictionary:
	var results: Dictionary = {}
	for trk in tracks:
		results[trk.track_name] = trk.evaluate_gain(global_intensity)
	return results
