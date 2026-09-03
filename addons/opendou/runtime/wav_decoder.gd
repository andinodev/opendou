class_name OpenDouWavDecoder
extends RefCounted

## Decodifica un AudioStreamWAV a muestras float mono normalizadas en [-1, 1].
##
## Existe porque tres sitios del proyecto decodificaban a mano asumiendo 16 bits
## mono, y el formato POR DEFECTO de AudioStreamWAV es de 8 bits: con un WAV
## estereo, de 8 bits, IMA-ADPCM o QOA se leia basura.
##
## El formato de 8 bits de Godot es CON SIGNO. Verificado midiendo el pico de un
## WAV con todos los bytes a 128: da 1.0, o sea -1.0 de amplitud plena, no
## silencio. Tratarlo como sin signo mete un offset de DC del 100 %.

## Decodifica a mono en [-1, 1]. Devuelve un array vacio si el formato no se
## puede decodificar desde GDScript, avisando de cual era.
static func to_mono_floats(wav: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if wav == null:
		return out
	var data: PackedByteArray = wav.data
	if data.is_empty():
		return out

	match wav.format:
		AudioStreamWAV.FORMAT_8_BITS:
			return _decode_8_bits(data, wav.stereo)
		AudioStreamWAV.FORMAT_16_BITS:
			return _decode_16_bits(data, wav.stereo)
		AudioStreamWAV.FORMAT_IMA_ADPCM:
			push_warning("[OpenDou] AudioStreamWAV en IMA-ADPCM: GDScript no puede decodificarlo. Reimporta el WAV sin compresion si necesitas sus muestras.")
			return out
		AudioStreamWAV.FORMAT_QOA:
			push_warning("[OpenDou] AudioStreamWAV en QOA: GDScript no puede decodificarlo. Reimporta el WAV sin compresion si necesitas sus muestras.")
			return out
		_:
			push_warning("[OpenDou] formato de AudioStreamWAV no reconocido: %d" % wav.format)
			return out

static func _decode_8_bits(data: PackedByteArray, stereo: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var step: int = 2 if stereo else 1
	var frames: int = data.size() / step
	out.resize(frames)
	for i in range(frames):
		var base: int = i * step
		var value: float = _signed_8(data[base])
		if stereo:
			value = (value + _signed_8(data[base + 1])) * 0.5
		out[i] = value
	return out

static func _decode_16_bits(data: PackedByteArray, stereo: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var bytes_per_frame: int = 4 if stereo else 2
	var frames: int = data.size() / bytes_per_frame
	out.resize(frames)
	for i in range(frames):
		var base: int = i * bytes_per_frame
		var value: float = _signed_16(data[base], data[base + 1])
		if stereo:
			value = (value + _signed_16(data[base + 2], data[base + 3])) * 0.5
		out[i] = value
	return out

## Un byte de 8 bits con signo, normalizado a [-1, 1].
static func _signed_8(b: int) -> float:
	var v: int = b - 256 if b >= 128 else b
	return float(v) / 128.0

## Dos bytes little-endian de 16 bits con signo, normalizados a [-1, 1].
static func _signed_16(lo: int, hi: int) -> float:
	var v: int = lo | (hi << 8)
	if v >= 32768:
		v -= 65536
	return float(v) / 32768.0

## Lee un WAV PCM (16 o 24 bits, cualquier numero de canales) de disco y devuelve
## {"channels": Array de PackedFloat32Array, "mix_rate": int}. Godot no importa WAV multicanal;
## las camas ambisonicas (4 o 9 canales, Fase 13) lo necesitan. Vacio si no se puede leer.
static func read_multichannel(path: String) -> Dictionary:
	var empty := {"channels": [], "mix_rate": 0}
	if not FileAccess.file_exists(path):
		return empty
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return empty
	var channels: int = 0
	var rate: int = 0
	var bits: int = 0
	var fmt_tag: int = 0
	var pos: int = 12
	var out: Array = []
	while pos + 8 <= bytes.size():
		var cid: String = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size: int = bytes.decode_u32(pos + 4)
		var body: int = pos + 8
		if body + size > bytes.size():
			break
		if cid == "fmt ":
			fmt_tag = bytes.decode_u16(body)
			channels = bytes.decode_u16(body + 2)
			rate = bytes.decode_u32(body + 4)
			bits = bytes.decode_u16(body + 14)
		elif cid == "data" and channels > 0 and (bits == 16 or bits == 24) and (fmt_tag == 1 or fmt_tag == 0xFFFE):
			var frame_bytes: int = channels * bits / 8
			var frames: int = size / frame_bytes
			for c in range(channels):
				var pf := PackedFloat32Array()
				pf.resize(frames)
				out.append(pf)
			for f in range(frames):
				var base: int = body + f * frame_bytes
				for c in range(channels):
					var off: int = base + c * bits / 8
					var v: float
					if bits == 16:
						v = float(bytes.decode_s16(off)) / 32768.0
					else:
						var raw: int = bytes[off] | (bytes[off + 1] << 8) | (bytes[off + 2] << 16)
						if raw >= 0x800000:
							raw -= 0x1000000
						v = float(raw) / 8388608.0
					out[c][f] = v
		pos = body + size + (size % 2)
	if out.is_empty():
		return empty
	return {"channels": out, "mix_rate": rate}
