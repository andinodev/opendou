class_name SoundBank
extends RefCounted

## Represents a loaded monolithic .bank file in runtime memory.

const SoundBankMetadataClass = preload("res://addons/opendou/resources/soundbank_metadata.gd")

## Codecs que el TOC puede declarar.
const CODEC_PCM16: int = 0
const CODEC_ADPCM: int = 1
const CODEC_VORBIS: int = 2

var bank_path: String = ""
var bank_name: StringName = &""
var version: int = 1
var num_streams: int = 0
var prefetch_block_size: int = 0
var stream_block_offset: int = 0

# Single contiguous RAM allocation holding all sliced prefetch attack buffers
var prefetch_memory: PackedByteArray = PackedByteArray()

# TOC Map: stream_id (int) -> SoundBankMetadata
var stream_registry: Dictionary = {}

# Active file handle for non-blocking stream chunk reads
var file_handle: FileAccess = null

func _init(p_path: String = "", p_name: StringName = &"") -> void:
	bank_path = p_path
	bank_name = p_name

## Loads and parses a monolithic .bank file.
func load_from_file(p_path: String) -> bool:
	bank_path = p_path
	close()
	
	file_handle = FileAccess.open(bank_path, FileAccess.READ)
	if not file_handle:
		push_error("[SoundBank] Failed to open bank file: %s" % bank_path)
		return false
		
	# 1. READ BLOCK 1: HEADER (24 bytes)
	var magic_buf = file_handle.get_buffer(4)
	var magic_str = magic_buf.get_string_from_ascii()
	if magic_str != "ODBK":
		push_error("[SoundBank] Invalid bank magic header: %s" % magic_str)
		close()
		return false
		
	version = file_handle.get_32()
	num_streams = file_handle.get_32()
	prefetch_block_size = file_handle.get_32()
	stream_block_offset = file_handle.get_64()
	
	# 2. READ BLOCK 2: TOC
	stream_registry.clear()
	for i in range(num_streams):
		var s_id: int = file_handle.get_32()
		var codec: int = file_handle.get_16()
		var channels: int = file_handle.get_16()
		var sample_rate: int = file_handle.get_32()
		var pref_off: int = file_handle.get_32()
		var pref_len: int = file_handle.get_32()
		var disk_off: int = file_handle.get_64()
		var disk_len: int = file_handle.get_64()
		file_handle.get_32() # Read 4-byte padding
		
		var meta = SoundBankMetadataClass.new(s_id, &"", codec, channels, sample_rate)
		meta.prefetch_offset = pref_off
		meta.prefetch_length = pref_len
		meta.disk_offset = disk_off
		meta.disk_length = disk_len
		
		stream_registry[s_id] = meta
		
	# 3. READ BLOCK 3: PREFETCH MEMORY (Contiguous single malloc / RAM buffer)
	if prefetch_block_size > 0:
		prefetch_memory = file_handle.get_buffer(prefetch_block_size)
	else:
		prefetch_memory = PackedByteArray()
		
	return true

## Retrieves the instant prefetch RAM buffer slice for a stream.
func get_prefetch_slice(stream_id: int) -> PackedByteArray:
	if not stream_registry.has(stream_id):
		return PackedByteArray()
		
	var meta: SoundBankMetadata = stream_registry[stream_id]
	if meta.prefetch_length <= 0 or prefetch_memory.is_empty():
		return PackedByteArray()
		
	return prefetch_memory.slice(meta.prefetch_offset, meta.prefetch_offset + meta.prefetch_length)

## Reconstruye un stream del banco como AudioStreamWAV reproducible.
##
## Es lo que convierte el pipeline ODBK en algo que suena: antes el banco se leia
## correctamente y sus bytes no llegaban a ninguna salida de audio.
##
## El banco guarda los bytes PCM16 sin transformarlos, asi que la reconstruccion
## es byte-exacta: lo que entro al compilador es lo que sale.
##
## Devuelve null para los codecs que GDScript no puede decodificar, avisando de
## cual era, en lugar de producir ruido.
func build_stream(stream_id: int) -> AudioStreamWAV:
	if not stream_registry.has(stream_id):
		return null
	var meta: SoundBankMetadata = stream_registry[stream_id]

	if meta.codec != CODEC_PCM16:
		push_warning("[OpenDou] el stream %d del banco '%s' declara el codec %d, que GDScript no puede decodificar. Solo PCM16 (codec 0) es reproducible; recompila el banco sin comprimir." % [
			stream_id, str(bank_name), meta.codec])
		return null

	# En los bancos que produce el compilador, prefetch y disco son exclusivos por
	# stream. Se concatenan de todas formas para que un banco que usara ambos
	# bloques siguiera reconstruyendose entero.
	var data := PackedByteArray()
	var pref: PackedByteArray = get_prefetch_slice(stream_id)
	if pref.size() > 0:
		data.append_array(pref)
	if meta.disk_length > 0:
		data.append_array(read_stream_chunk(stream_id, 0, meta.disk_length))

	if data.is_empty():
		return null

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = meta.channels >= 2
	wav.mix_rate = maxi(1, meta.sample_rate)
	wav.data = data
	return wav

## Reads a chunk of audio directly from the streaming body on disk.
func read_stream_chunk(stream_id: int, relative_offset: int, chunk_length: int) -> PackedByteArray:
	if not file_handle or not stream_registry.has(stream_id):
		return PackedByteArray()
		
	var meta: SoundBankMetadata = stream_registry[stream_id]
	if relative_offset >= meta.disk_length:
		return PackedByteArray()
		
	var bytes_to_read: int = min(chunk_length, meta.disk_length - relative_offset)
	var absolute_pos: int = meta.disk_offset + relative_offset
	
	file_handle.seek(absolute_pos)
	return file_handle.get_buffer(bytes_to_read)

## Closes file handle and frees RAM prefetch memory.
func close() -> void:
	if file_handle:
		file_handle.close()
		file_handle = null
	prefetch_memory.clear()
	stream_registry.clear()
