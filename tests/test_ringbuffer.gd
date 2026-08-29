class_name TestRingBuffer
extends RefCounted

const AudioRingBufferClass = preload("res://addons/opendou/runtime/audio_ring_buffer.gd")
const SoundBankClass = preload("res://addons/opendou/runtime/soundbank.gd")
const SoundBankCompilerClass = preload("res://addons/opendou/tools/soundbank_compiler.gd")
const BankStreamPlaybackClass = preload("res://addons/opendou/runtime/bank_stream_playback.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: RingBuffer Push, Pop & Wrap-Around
	var ring = AudioRingBufferClass.new(10) # Tiny 10-byte capacity
	var data_in = PackedByteArray([1, 2, 3, 4, 5, 6, 7])
	
	var pushed = ring.push(data_in)
	if pushed != 7 or ring.available_to_read() != 7:
		failures.append("Test 1a Failed: Expected 7 bytes pushed, got %d" % pushed)
		
	var popped = ring.pop(4)
	if popped != PackedByteArray([1, 2, 3, 4]) or ring.available_to_read() != 3:
		failures.append("Test 1b Failed: Expected popped [1,2,3,4]")
		
	# Push across wrap-around boundary (3 remaining + 6 new = 9 / 10 capacity)
	var wrap_data = PackedByteArray([8, 9, 10, 11, 12, 13])
	var pushed_wrap = ring.push(wrap_data)
	if pushed_wrap != 6 or ring.available_to_read() != 9:
		failures.append("Test 1c Failed: Expected wrap-around push of 6 bytes, got %d" % pushed_wrap)
		
	var popped_all = ring.pop(9)
	if popped_all != PackedByteArray([5, 6, 7, 8, 9, 10, 11, 12, 13]):
		failures.append("Test 1d Failed: Wrap-around data mismatch")
		
	# Test 2: BankStreamPlayback Prefetch-to-Disk Stitching Handshake
	var test_bank_path = "user://temp_stitching.bank"
	var total_audio = PackedByteArray([10, 20, 30, 40, 50, 60, 70, 80, 90, 100])
	
	SoundBankCompilerClass.compile_bank(test_bank_path, [
		{
			"id": 5001,
			"name": &"Explosion",
			"data": total_audio,
			"channels": 1,
			"sample_rate": 44100,
			"codec": 0,
			"prefetch_size": 4 # First 4 bytes (10, 20, 30, 40) in RAM, remaining 6 on disk
		}
	])
	
	var bank = SoundBankClass.new(test_bank_path, &"StitchingBank")
	bank.load_from_file(test_bank_path)
	
	var playback = BankStreamPlaybackClass.new(bank, 5001, 128)
	playback.start()
	
	# Simulate async disk feed of remaining 6 bytes
	var disk_chunk = bank.read_stream_chunk(5001, 0, 6)
	playback.feed_disk_chunk(disk_chunk)
	
	# Request entire 10 bytes in a single mix call
	var mixed_data = playback.mix(10)
	if mixed_data != total_audio:
		failures.append("Test 2 Failed: Stitching mix mismatch, expected %s, got %s" % [str(total_audio), str(mixed_data)])
		
	# Test 3: Underrun Protection (Zero-fill silence)
	playback.start()
	# Don't feed disk chunks -> prefetch only has 4 bytes, request 6
	var starved_mix = playback.mix(6)
	if starved_mix != PackedByteArray([10, 20, 30, 40, 0, 0]):
		failures.append("Test 3 Failed: Underrun silence injection mismatch, got %s" % str(starved_mix))
		
	bank.close()
	DirAccess.remove_absolute(test_bank_path)
	
	return failures
