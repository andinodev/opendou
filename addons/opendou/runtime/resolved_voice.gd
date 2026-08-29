class_name ResolvedVoice
extends RefCounted

## Represents a resolved concrete physical audio stream ready for output.

var stream: AudioStream
var volume_offset_db: float = 0.0
var pitch_modifier: float = 1.0

func _init(p_stream: AudioStream = null, p_vol_offset: float = 0.0, p_pitch_mod: float = 1.0) -> void:
	stream = p_stream
	volume_offset_db = p_vol_offset
	pitch_modifier = p_pitch_mod
