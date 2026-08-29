@tool
class_name SoundBankCompiler
extends RefCounted

## Offline builder that packages raw audio streams into monolithic binary .bank files.

const MAGIC: String = "ODBK"
const FORMAT_VERSION: int = 1

## Compiles an array of audio stream descriptors into a binary .bank file.
## stream_inputs is an Array of Dictionaries:
##   { "id": int, "name": StringName, "data": PackedByteArray, "channels": int, "sample_rate": int, "codec": int, "prefetch_size": int }
static func compile_bank(output_path: String, stream_inputs: Array[Dictionary]) -> bool:
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		push_error("[SoundBankCompiler] Failed to open file for writing at: %s" % output_path)
		return false
		
	var num_streams: int = stream_inputs.size()
	
	# Prepare Slices & Calculate Block Sizes
	var toc_entries: Array[Dictionary] = []
	var prefetch_block = PackedByteArray()
	var stream_block = PackedByteArray()
	
	var cur_prefetch_offset: int = 0
	
	for item in stream_inputs:
		var s_id: int = item.get("id", 0)
		var s_name: StringName = item.get("name", &"")
		var s_data: PackedByteArray = item.get("data", PackedByteArray())
		var s_channels: int = item.get("channels", 2)
		var s_sample_rate: int = item.get("sample_rate", 44100)
		var s_codec: int = item.get("codec", 0)
		var pref_size: int = min(item.get("prefetch_size", 65536), s_data.size())
		
		# Slicing
		var pref_part = s_data.slice(0, pref_size)
		var stream_part = s_data.slice(pref_size)
		
		var entry = {
			"id": s_id,
			"name": s_name,
			"codec": s_codec,
			"channels": s_channels,
			"sample_rate": s_sample_rate,
			"prefetch_offset": cur_prefetch_offset,
			"prefetch_length": pref_part.size(),
			"disk_offset": 0, # Will be computed after TOC length is known
			"disk_length": stream_part.size()
		}
		
		prefetch_block.append_array(pref_part)
		cur_prefetch_offset += pref_part.size()
		
		stream_block.append_array(stream_part)
		toc_entries.append(entry)
		
	var header_size: int = 24
	var toc_entry_size: int = 40 # Fixed bytes per TOC entry
	var toc_block_size: int = num_streams * toc_entry_size
	var prefetch_block_size: int = prefetch_block.size()
	var stream_block_start_offset: int = header_size + toc_block_size + prefetch_block_size
	
	# Compute absolute disk offsets for stream entries
	var cur_disk_offset: int = stream_block_start_offset
	for entry in toc_entries:
		entry["disk_offset"] = cur_disk_offset
		cur_disk_offset += entry["disk_length"]
		
	# --------------------------------------------------------------------------
	# 1. WRITE BLOCK 1: HEADER (24 bytes)
	# --------------------------------------------------------------------------
	file.store_buffer(MAGIC.to_ascii_buffer()) # 4 bytes
	file.store_32(FORMAT_VERSION)              # 4 bytes
	file.store_32(num_streams)                 # 4 bytes
	file.store_32(prefetch_block_size)         # 4 bytes
	file.store_64(stream_block_start_offset)   # 8 bytes
	
	# --------------------------------------------------------------------------
	# 2. WRITE BLOCK 2: TOC ENTRIES
	# --------------------------------------------------------------------------
	for entry in toc_entries:
		file.store_32(entry["id"])
		file.store_16(entry["codec"])
		file.store_16(entry["channels"])
		file.store_32(entry["sample_rate"])
		file.store_32(entry["prefetch_offset"])
		file.store_32(entry["prefetch_length"])
		file.store_64(entry["disk_offset"])
		file.store_64(entry["disk_length"])
		file.store_32(0) # 4-byte alignment padding to reach 40 bytes
		
	# --------------------------------------------------------------------------
	# 3. WRITE BLOCK 3: PREFETCH DATA (RAM Block)
	# --------------------------------------------------------------------------
	if not prefetch_block.is_empty():
		file.store_buffer(prefetch_block)
		
	# --------------------------------------------------------------------------
	# 4. WRITE BLOCK 4: STREAMING DATA (Disk Block)
	# --------------------------------------------------------------------------
	if not stream_block.is_empty():
		file.store_buffer(stream_block)
		
	file.close()
	return true
