@tool
class_name AudioPhysicalNode
extends AudioLogicNode

## Leaf node in the audio logic tree representing a physical AudioStream asset.

@export var stream: AudioStream
@export var volume_offset_db: float = 0.0
@export var pitch_modifier: float = 1.0

func _init(p_stream: AudioStream = null, p_vol_offset: float = 0.0, p_pitch_mod: float = 1.0) -> void:
	stream = p_stream
	volume_offset_db = p_vol_offset
	pitch_modifier = p_pitch_mod

func resolve(_context: AudioPlaybackContext, out_voices: Array[ResolvedVoice]) -> bool:
	if stream:
		out_voices.append(ResolvedVoiceClass.new(stream, volume_offset_db, pitch_modifier))
		return true
	return false
