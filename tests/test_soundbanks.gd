class_name TestSoundBanks
extends RefCounted

const SoundBankCompilerClass = preload("res://addons/opendou/tools/soundbank_compiler.gd")
const SoundBankClass = preload("res://addons/opendou/runtime/soundbank.gd")
const SoundBankManagerClass = preload("res://addons/opendou/runtime/soundbank_manager.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	var test_bank_path: String = "user://temp_weapons.bank"
	
	# Generate mock audio stream bytes
	# Stream 1: 100 bytes (40 prefetch, 60 stream)
	var data1 = PackedByteArray()
	for i in range(100):
		data1.append(i % 256)
		
	# Stream 2: 80 bytes (30 prefetch, 50 stream)
	var data2 = PackedByteArray()
	for i in range(80):
		data2.append((i * 2) % 256)
		
	var stream_inputs: Array[Dictionary] = [
		{
			"id": 1001,
			"name": &"Pistol_Shot",
			"data": data1,
			"channels": 1,
			"sample_rate": 44100,
			"codec": 0,
			"prefetch_size": 40
		},
		{
			"id": 1002,
			"name": &"Rifle_Burst",
			"data": data2,
			"channels": 2,
			"sample_rate": 48000,
			"codec": 0,
			"prefetch_size": 30
		}
	]
	
	# Test 1: Compilation
	var compile_success = SoundBankCompilerClass.compile_bank(test_bank_path, stream_inputs)
	if not compile_success or not FileAccess.file_exists(test_bank_path):
		failures.append("Test 1 Failed: SoundBank compilation failed")
		return failures
		
	# Test 2: SoundBank Parsing & Prefetch Extraction
	var bank = SoundBankClass.new(test_bank_path, &"Weapons")
	var load_success = bank.load_from_file(test_bank_path)
	if not load_success:
		failures.append("Test 2a Failed: Failed to parse generated .bank file")
		return failures
		
	if bank.num_streams != 2:
		failures.append("Test 2b Failed: Expected 2 streams, got %d" % bank.num_streams)
		
	if bank.prefetch_block_size != 70: # 40 + 30
		failures.append("Test 2c Failed: Expected prefetch block size 70, got %d" % bank.prefetch_block_size)
		
	var pref_slice_1 = bank.get_prefetch_slice(1001)
	if pref_slice_1.size() != 40:
		failures.append("Test 2d Failed: Expected prefetch slice 1 size 40, got %d" % pref_slice_1.size())
	elif pref_slice_1 != data1.slice(0, 40):
		failures.append("Test 2e Failed: Prefetch slice 1 data mismatch")
		
	var pref_slice_2 = bank.get_prefetch_slice(1002)
	if pref_slice_2.size() != 30:
		failures.append("Test 2f Failed: Expected prefetch slice 2 size 30, got %d" % pref_slice_2.size())
	elif pref_slice_2 != data2.slice(0, 30):
		failures.append("Test 2g Failed: Prefetch slice 2 data mismatch")
		
	# Test 3: Disk Chunk Streaming
	var stream_chunk_1 = bank.read_stream_chunk(1001, 0, 60)
	if stream_chunk_1.size() != 60:
		failures.append("Test 3a Failed: Expected stream chunk 1 size 60, got %d" % stream_chunk_1.size())
	elif stream_chunk_1 != data1.slice(40):
		failures.append("Test 3b Failed: Stream chunk 1 data mismatch")
		
	bank.close()
	
	# Test 4: SoundBankManager Caching & Unload
	var manager = SoundBankManagerClass.new()
	var mgr_bank = manager.load_bank(test_bank_path, &"Weapons_Bank")
	if not mgr_bank or manager.get_bank(&"Weapons_Bank") == null:
		failures.append("Test 4a Failed: SoundBankManager failed to cache bank")
		
	manager.unload_bank(&"Weapons_Bank")
	if manager.get_bank(&"Weapons_Bank") != null:
		failures.append("Test 4b Failed: SoundBankManager failed to unload bank")
		
	# Cleanup temp file
	DirAccess.remove_absolute(test_bank_path)
	
	return failures
