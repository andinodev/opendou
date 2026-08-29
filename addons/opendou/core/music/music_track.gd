@tool
class_name MusicTrack
extends RefCounted

## Represents a single synchronous audio layer (e.g. Drums, Bass, Leads) within a musical segment.

var track_name: StringName = &"Layer"
var stream: AudioStream = null

var min_intensity: float = 0.0
var max_intensity: float = 1.0
var volume_db: float = 0.0
var is_muted: bool = false

func _init(p_name: StringName = &"Layer", p_stream: AudioStream = null, p_min_int: float = 0.0, p_max_int: float = 1.0) -> void:
	track_name = p_name
	stream = p_stream
	min_intensity = p_min_int
	max_intensity = p_max_int

## Evaluates the active volume multiplier (0.0 to 1.0) based on dynamic game intensity.
func evaluate_gain(global_intensity: float) -> float:
	if is_muted:
		return 0.0
		
	if global_intensity < min_intensity or global_intensity > max_intensity:
		# Layer is outside active intensity zone
		return 0.0
		
	# Smooth fade-in and fade-out at borders
	var fade_range = 0.15
	var gain = 1.0
	
	if global_intensity < min_intensity + fade_range:
		gain = (global_intensity - min_intensity) / fade_range
	elif global_intensity > max_intensity - fade_range:
		gain = (max_intensity - global_intensity) / fade_range
		
	var base_linear = db_to_linear(volume_db)
	return clampf(gain, 0.0, 1.0) * base_linear
