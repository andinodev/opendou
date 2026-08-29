class_name BankStreamPlayback
extends RefCounted

## Zero-latency audio stream playback with prefetch RAM attack and disk ring-buffer stitching.

const AudioRingBufferClass = preload("res://addons/opendou/runtime/audio_ring_buffer.gd")
const SoundBankClass = preload("res://addons/opendou/runtime/soundbank.gd")
const SoundBankMetadataClass = preload("res://addons/opendou/resources/soundbank_metadata.gd")

var sound_bank: SoundBank
var stream_id: int = 0
var metadata: SoundBankMetadata

var disk_ring_buffer: AudioRingBuffer
var is_reading_prefetch: bool = true
var prefetch_slice: PackedByteArray = PackedByteArray()
var prefetch_cursor: int = 0
var disk_bytes_streamed: int = 0

func _init(p_bank: SoundBank, p_stream_id: int, ring_buffer_size: int = 65536) -> void:
	sound_bank = p_bank
	stream_id = p_stream_id
	disk_ring_buffer = AudioRingBufferClass.new(ring_buffer_size)
	
	if sound_bank and sound_bank.stream_registry.has(stream_id):
		metadata = sound_bank.stream_registry[stream_id]
		prefetch_slice = sound_bank.get_prefetch_slice(stream_id)
	else:
		metadata = null
		prefetch_slice = PackedByteArray()

## Starts playback from beginning or offset.
func start(_from_pos: float = 0.0) -> void:
	is_reading_prefetch = true
	prefetch_cursor = 0
	disk_bytes_streamed = 0
	disk_ring_buffer.clear()

## Feeds a chunk of streamed disk bytes into the ring buffer.
func feed_disk_chunk(chunk: PackedByteArray) -> int:
	return disk_ring_buffer.push(chunk)

## Mixes and extracts requested bytes, seamlessly stitching prefetch RAM to disk ring-buffer.
func mix(bytes_requested: int) -> PackedByteArray:
	var out = PackedByteArray()
	out.resize(bytes_requested)
	var bytes_filled: int = 0
	
	# FASE 1: Zero-latency RAM Prefetch
	if is_reading_prefetch:
		var pref_available = prefetch_slice.size() - prefetch_cursor
		var to_read = min(bytes_requested, pref_available)
		
		for i in range(to_read):
			out[bytes_filled + i] = prefetch_slice[prefetch_cursor + i]
			
		prefetch_cursor += to_read
		bytes_filled += to_read
		
		if prefetch_cursor >= prefetch_slice.size():
			is_reading_prefetch = false # Seamless transition to disk stream
			
	# FASE 2: Streaming from Disk RingBuffer
	if not is_reading_prefetch and bytes_filled < bytes_requested:
		var remaining_needed = bytes_requested - bytes_filled
		var ring_data = disk_ring_buffer.pop(remaining_needed)
		
		for i in range(ring_data.size()):
			out[bytes_filled + i] = ring_data[i]
			
		bytes_filled += ring_data.size()
		disk_bytes_streamed += ring_data.size()
		
		# FASE 3: Buffer Underrun Protection (Zero-fill / Silence)
		if bytes_filled < bytes_requested:
			for i in range(bytes_filled, bytes_requested):
				out[i] = 0 # Injects clean digital silence to prevent pops
				
	return out
