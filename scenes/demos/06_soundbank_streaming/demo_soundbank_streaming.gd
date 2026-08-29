class_name DemoSoundBankStreaming
extends Node

## Demo 06: Monolithic SoundBank Prefetch & Streaming Handshake

const SoundBankCompilerClass = preload("res://addons/opendou/tools/soundbank_compiler.gd")
const SoundBankClass = preload("res://addons/opendou/runtime/soundbank.gd")
const BankStreamPlaybackClass = preload("res://addons/opendou/runtime/bank_stream_playback.gd")

var soundbank: SoundBank
var playback: BankStreamPlayback
var is_stream_ready: bool = false

func _ready() -> void:
	setup_streaming_demo()

func setup_streaming_demo(bank_file_path: String = "user://demo_stream.bank") -> void:
	# 1. Compile test monolithic soundbank
	var compiler = SoundBankCompilerClass.new()
	var prefetch_size = 1024 # 1 KB instant RAM attack slice
	var stream_data = PackedByteArray()
	stream_data.resize(8192) # 8 KB total sound stream
	for i in range(8192):
		stream_data[i] = (i * 7) % 256
		
	compiler.add_audio_stream(&"Epic_Music_Intro", stream_data, prefetch_size)
	var err = compiler.compile_to_file(bank_file_path, &"Demo_Music_Bank")
	if err != OK:
		push_error("Demo 06: Failed to compile demo bank")
		return
		
	# 2. Load SoundBank into single contiguous RAM chunk
	soundbank = SoundBankClass.new()
	var load_err = soundbank.load_from_file(bank_file_path)
	if load_err != OK:
		push_error("Demo 06: Failed to load demo bank")
		return
		
	# 3. Instantiate BankStreamPlayback with prefetch slice
	var meta = soundbank.get_stream_metadata(&"Epic_Music_Intro")
	var prefetch_slice = soundbank.get_prefetch_slice(&"Epic_Music_Intro")
	
	playback = BankStreamPlaybackClass.new(soundbank, meta, prefetch_slice, 4096)
	is_stream_ready = true

## Simulates feeding mixed audio frames, transitioning from Phase 1 (Prefetch) to Phase 2 (Disk stream).
func mix_audio_chunk(chunk_bytes: int) -> PackedByteArray:
	if not playback:
		return PackedByteArray()
	return playback.mix(chunk_bytes)

func is_reading_prefetch() -> bool:
	return playback.is_reading_prefetch if playback else false
