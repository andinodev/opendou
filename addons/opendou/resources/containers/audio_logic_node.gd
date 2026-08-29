@tool
class_name AudioLogicNode
extends Resource

## Abstract base class for all logical audio containers and physical leaf nodes (Composite Pattern).

const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const ResolvedVoiceClass = preload("res://addons/opendou/runtime/resolved_voice.gd")

## Resolves the logic node against the current playback context, populating out_voices.
## Returns true if at least one voice was resolved, false otherwise.
func resolve(_context: AudioPlaybackContext, _out_voices: Array[ResolvedVoice]) -> bool:
	return false
