@tool
class_name MusicSegment
extends RefCounted

## Represents an interactive musical section (e.g. Combat_Loop, Stealth_Intro, Boss_Phase) composed of multiple synchronous tracks, structural cues (Pre-Entry, Exit), and post-exit reverb tails.

var segment_name: StringName = &"Segment"
var tracks: Array[MusicTrack] = []
var duration_bars: int = 8
var is_looping: bool = true

# Structural Cues & Post-Exit Tails (Wwise / FMOD Standard)
var entry_cue_bar: float = 0.0 # 0.0 = Bar 1 Beat 1 (can be negative, e.g. -1.0 for pickups/anacrusas)
var exit_cue_bar: float = 8.0 # Bar position where loop cycles or exits
var post_exit_tail_sec: float = 2.0 # Reverb/cymbal decay overflow duration in seconds

func _init(p_name: StringName = &"Segment", p_duration_bars: int = 8, p_loop: bool = true, p_entry: float = 0.0, p_exit: float = 8.0, p_tail: float = 2.0) -> void:
	segment_name = p_name
	duration_bars = p_duration_bars
	is_looping = p_loop
	entry_cue_bar = p_entry
	exit_cue_bar = p_exit
	post_exit_tail_sec = p_tail

func add_track(track: MusicTrack) -> void:
	tracks.append(track)

## Evaluates volume gains for all child tracks according to game intensity.
func evaluate_tracks(global_intensity: float) -> Dictionary:
	var results: Dictionary = {}
	for trk in tracks:
		results[trk.track_name] = trk.evaluate_gain(global_intensity)
	return results
