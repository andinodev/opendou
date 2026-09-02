class_name TestWavDecoder
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")

static func _make_wav(fmt: int, stereo: bool, bytes: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = fmt
	w.stereo = stereo
	w.mix_rate = 44100
	w.data = bytes
	return w

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("wav_decoder")

	# 16 bits mono, little-endian con signo. 0x7FFF ~ +1.0, 0x8000 = -1.0.
	var b16 := PackedByteArray([0x00, 0x00, 0xFF, 0x7F, 0x00, 0x80])
	var s16 := WavDecoderClass.to_mono_floats(_make_wav(AudioStreamWAV.FORMAT_16_BITS, false, b16))
	a.eq(s16.size(), 3, "16 bits mono: tres muestras")
	a.approx(s16[0], 0.0, "16 bits: 0x0000 es silencio", 0.001)
	a.approx(s16[1], 1.0, "16 bits: 0x7FFF es +1.0", 0.001)
	a.approx(s16[2], -1.0, "16 bits: 0x8000 es -1.0", 0.001)

	# 8 bits mono CON SIGNO: el byte 128 vale -1.0, no silencio. Verificado
	# empiricamente midiendo el pico de un WAV con todos los bytes a 128: da 1.0.
	var b8 := PackedByteArray([0, 127, 128])
	var s8 := WavDecoderClass.to_mono_floats(_make_wav(AudioStreamWAV.FORMAT_8_BITS, false, b8))
	a.eq(s8.size(), 3, "8 bits mono: tres muestras")
	a.approx(s8[0], 0.0, "8 bits: 0 es silencio", 0.001)
	a.approx(s8[1], 127.0 / 128.0, "8 bits: 127 es casi +1.0", 0.001)
	a.approx(s8[2], -1.0, "8 bits: 128 es -1.0 porque el formato es con signo", 0.001)

	# 16 bits estereo: los canales se promedian a mono. L=+1.0, R=-1.0 -> 0.0.
	var b16s := PackedByteArray([0xFF, 0x7F, 0x00, 0x80, 0xFF, 0x7F, 0xFF, 0x7F])
	var s16s := WavDecoderClass.to_mono_floats(_make_wav(AudioStreamWAV.FORMAT_16_BITS, true, b16s))
	a.eq(s16s.size(), 2, "16 bits estereo: dos frames")
	a.approx(s16s[0], 0.0, "estereo: +1.0 y -1.0 promedian a 0", 0.001)
	a.approx(s16s[1], 1.0, "estereo: +1.0 en ambos canales da +1.0", 0.001)

	# 8 bits estereo.
	var b8s := PackedByteArray([127, 128, 0, 0])
	var s8s := WavDecoderClass.to_mono_floats(_make_wav(AudioStreamWAV.FORMAT_8_BITS, true, b8s))
	a.eq(s8s.size(), 2, "8 bits estereo: dos frames")
	a.lt(absf(s8s[0]), 0.01, "8 bits estereo: 127 y 128 casi se cancelan")

	# Formatos que GDScript no puede decodificar: vacio, no basura.
	for fmt in [AudioStreamWAV.FORMAT_IMA_ADPCM, AudioStreamWAV.FORMAT_QOA]:
		var comp := WavDecoderClass.to_mono_floats(_make_wav(fmt, false, PackedByteArray([1, 2, 3, 4])))
		a.eq(comp.size(), 0, "formato comprimido %d devuelve vacio" % fmt)

	# Entradas degeneradas.
	a.eq(WavDecoderClass.to_mono_floats(null).size(), 0, "null devuelve vacio")
	a.eq(WavDecoderClass.to_mono_floats(_make_wav(AudioStreamWAV.FORMAT_16_BITS, false, PackedByteArray())).size(),
		0, "datos vacios devuelven vacio")

	return a
