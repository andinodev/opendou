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
