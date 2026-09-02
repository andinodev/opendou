class_name TestSoundBankPackagingAndStreaming
extends RefCounted

const SoundBankManagerClass = preload("res://addons/opendou/runtime/soundbank_manager.gd")
const SoundBankBuilderClass = preload("res://addons/opendou/runtime/soundbank_builder.gd")

static func run_all() -> Array[String]:
	var failures: Array[String] = []

	var target_bank_path = "user://test_tactical_pack.bnk"
	var entries: Dictionary = {
		101: {
			"name": &"Gunshot_Rifle",
			"is_prefetch": true,
			"sample_rate": 44100,
			"channels": 1,
			"samples": PackedFloat32Array([0.0, 0.8, -0.6, 0.4, -0.2, 0.0])
		},
		102: {
			"name": &"Radio_Chatter",
			"is_prefetch": false,
			"sample_rate": 44100,
			"channels": 1,
			"samples": PackedFloat32Array([0.1, 0.2, 0.3, 0.2, 0.1, 0.0])
		}
	}

	var build_ok = SoundBankBuilderClass.build_bank(target_bank_path, entries)
	if not build_ok:
		failures.append("Test 1 Failed: SoundBankBuilder failed to create binary bnk file")
		return failures

	var mgr = SoundBankManagerClass.new()
	var bank = mgr.load_bank(target_bank_path, &"test_tactical_pack")
	if bank == null:
		failures.append("Test 2 Failed: SoundBankManager failed to load generated bank")
		return failures

	var telem = mgr.get_bank_telemetry(&"test_tactical_pack")
	if not telem.has("prefetch_ram_bytes") or telem["prefetch_ram_bytes"] <= 0:
		failures.append("Test 3 Failed: SoundBank telemetry missing prefetch_ram_bytes")

	var slice = bank.get_prefetch_slice(101)
	if slice.size() != 12: # 6 samples * 2 bytes PCM16
		failures.append("Test 4 Failed: Prefetch slice size mismatch, expected 12 got %d" % slice.size())

	# Comparar CONTENIDO, no solo tamano. Este test afirmaba unicamente
	# chunk.size() != 12, y con los offsets de disco desplazados la lectura caia en
	# el sitio equivocado y seguia devolviendo 12 bytes: pasaba devolviendo audio
	# incorrecto.
	var chunk = bank.read_stream_chunk(102, 0, 12)
	if chunk.size() != 12:
		failures.append("Test 5 Failed: Disk streaming chunk read mismatch, expected 12 got %d" % chunk.size())
	else:
		var expected := PackedFloat32Array([0.1, 0.2, 0.3, 0.2, 0.1, 0.0])
		for i in range(expected.size()):
			var lo: int = chunk[i * 2]
			var hi: int = chunk[i * 2 + 1]
			var v: int = lo | (hi << 8)
			if v >= 32768:
				v -= 65536
			# El divisor es 32767 porque es el factor que usa build_bank al codificar.
			var decoded: float = float(v) / 32767.0
			if absf(decoded - expected[i]) > 0.001:
				failures.append("Test 5b Failed: muestra %d del stream en disco vale %f, se esperaba %f" % [i, decoded, expected[i]])
				break

	mgr.unload_bank(&"test_tactical_pack")
	DirAccess.remove_absolute(target_bank_path)
	return failures
