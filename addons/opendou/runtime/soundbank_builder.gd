class_name SoundBankBuilder
extends RefCounted

## Utility class to pack audio assets into binary monolithic .bnk files compatible with OpenDou SoundBank.

static func build_bank(target_path: String, entries: Dictionary) -> bool:
	var file = FileAccess.open(target_path, FileAccess.WRITE)
	if not file:
		push_error("[SoundBankBuilder] Cannot open destination file for write: %s" % target_path)
		return false

	var num_streams: int = entries.size()
	var prefetch_block = PackedByteArray()
	var stream_block = PackedByteArray()

	# Intermediate metadata entries
	var toc_entries: Array[Dictionary] = []

	var sorted_keys = entries.keys()
	sorted_keys.sort()

	for k in sorted_keys:
		var entry = entries[k]
		var stream_id: int = int(k)
		var codec: int = entry.get("codec", 0) # 0 = PCM16
		var channels: int = entry.get("channels", 1)
		var sample_rate: int = entry.get("sample_rate", 44100)
		var is_prefetch: bool = entry.get("is_prefetch", false)

		var raw_pcm = PackedByteArray()
		if entry.has("samples") and entry["samples"] is PackedFloat32Array:
			var samples: PackedFloat32Array = entry["samples"]
			raw_pcm.resize(samples.size() * 2)
			for i in range(samples.size()):
				var s = clampf(samples[i], -1.0, 1.0)
				var val16 = int(s * 32767.0)
				if val16 < 0:
					val16 += 65536
				raw_pcm[i * 2] = val16 & 0xFF
				raw_pcm[i * 2 + 1] = (val16 >> 8) & 0xFF
		elif entry.has("data") and entry["data"] is PackedByteArray:
			raw_pcm = entry["data"]

		var pref_off: int = 0
		var pref_len: int = 0
		var disk_off: int = 0
		var disk_len: int = 0

		if is_prefetch:
			pref_off = prefetch_block.size()
			pref_len = raw_pcm.size()
			prefetch_block.append_array(raw_pcm)
		else:
			disk_off = stream_block.size()
			disk_len = raw_pcm.size()
			stream_block.append_array(raw_pcm)

		toc_entries.append({
			"id": stream_id,
			"codec": codec,
			"channels": channels,
			"sample_rate": sample_rate,
			"pref_off": pref_off,
			"pref_len": pref_len,
			"disk_off": disk_off,
			"disk_len": disk_len
		})

	# Calculate offsets:
	# Cabecera: 4 (magic) + 4 (version) + 4 (num) + 4 (pref_size) + 8 (stream_off) = 24 bytes
	# TOC: 40 bytes por entrada = 4 (id) + 2 (codec) + 2 (channels) + 4 (rate)
	#      + 4 (pref_off) + 4 (pref_len) + 8 (disk_off) + 8 (disk_len) + 4 (relleno)
	#
	# Aqui decia 36 mientras el comentario de al lado enumeraba campos que suman
	# 40: stream_block_offset y cada disk_offset salian 4 bytes por stream
	# desplazados, y read_stream_chunk() leia del sitio equivocado.
	# soundbank_compiler.gd ya usaba 40.
	const TOC_ENTRY_SIZE: int = 40
	var header_size: int = 24
	var toc_size: int = num_streams * TOC_ENTRY_SIZE
	var prefetch_block_size: int = prefetch_block.size()
	var stream_block_offset: int = header_size + toc_size + prefetch_block_size

	# Fix disk_offsets to be absolute file positions
	for item in toc_entries:
		if item["disk_len"] > 0:
			item["disk_off"] += stream_block_offset

	# 1. WRITE HEADER
	file.store_buffer("ODBK".to_ascii_buffer())
	file.store_32(1) # version
	file.store_32(num_streams)
	file.store_32(prefetch_block_size)
	file.store_64(stream_block_offset)

	# 2. WRITE TOC
	for item in toc_entries:
		file.store_32(item["id"])
		file.store_16(item["codec"])
		file.store_16(item["channels"])
		file.store_32(item["sample_rate"])
		file.store_32(item["pref_off"])
		file.store_32(item["pref_len"])
		file.store_64(item["disk_off"])
		file.store_64(item["disk_len"])
		file.store_32(0) # padding

	# 3. WRITE PREFETCH BLOCK
	if prefetch_block_size > 0:
		file.store_buffer(prefetch_block)

	# 4. WRITE STREAMING BLOCK
	if stream_block.size() > 0:
		file.store_buffer(stream_block)

	file.close()
	return true
