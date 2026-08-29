class_name SoundBankMetadata
extends RefCounted

## Metadata descriptor for a single audio stream inside a monolithic .bank file.

var stream_id: int = 0
var stream_name: StringName = &""
var codec: int = 0         # 0 = PCM16, 1 = ADPCM, 2 = Vorbis
var channels: int = 2      # 1 (Mono), 2 (Stereo)
var sample_rate: int = 44100

# RAM Prefetch Slice pointers
var prefetch_offset: int = 0
var prefetch_length: int = 0

# Disk Streaming pointers
var disk_offset: int = 0
var disk_length: int = 0

func _init(p_id: int = 0, p_name: StringName = &"", p_codec: int = 0, p_channels: int = 2, p_sample_rate: int = 44100) -> void:
	stream_id = p_id
	stream_name = p_name
	codec = p_codec
	channels = p_channels
	sample_rate = p_sample_rate
