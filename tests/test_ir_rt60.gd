class_name TestIRRT60
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const IRAnalyzerClass = preload("res://addons/opendou/runtime/spatial/ir_rt60_analyzer.gd")

## Construye un IR sintetico cuyo nivel cae exactamente 60 dB en rt60 segundos.
##
## El nivel en dB es 20*log10(amplitud), asi que caer 60 dB es multiplicar la
## amplitud por 0.001: a = ln(1000) / rt60.
##
## El rate es bajo a proposito: el metodo es independiente de la frecuencia de
## muestreo, y con 44100 las tres mediciones suman medio millon de iteraciones de
## GDScript sin aportar nada a la prueba.
static func _make_ir(rt60: float, rate: int = 11025) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = false
	w.mix_rate = rate
	var n: int = int(rt60 * 1.5 * float(rate))
	var decay: float = log(1000.0) / rt60
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	# Generador congruencial lineal: ruido determinista y bien condicionado para
	# cualquier n. Un fract(sin(i)*K) degrada su distribucion con i grande, y aqui
	# n llega a decenas de miles.
	var seed_state: int = 12345
	for i in range(n):
		var t: float = float(i) / float(rate)
		seed_state = (seed_state * 1103515245 + 12345) & 0x7FFFFFFF
		var noise: float = (float(seed_state) / float(0x7FFFFFFF)) * 2.0 - 1.0
		# Un IR real es ruidoso, no una sinusoide limpia.
		var amp: float = exp(-decay * t) * noise
		var v: int = clampi(int(amp * 32767.0), -32768, 32767)
		if v < 0:
			v += 65536
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	w.data = bytes
	return w

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("ir_rt60")

	# Tolerancia del +-15 %: la extrapolacion T20 mide una pendiente sobre 20 dB
	# y la proyecta a 60, asi que triplica cualquier error de la medida. Exigir
	# mas precision seria afirmar algo que el metodo no da.
	for target in [0.5, 1.0, 2.5]:
		var measured: float = IRAnalyzerClass.rt60_from_ir(_make_ir(target))
		a.gt(measured, target * 0.85, "RT60 de %.1f s medido por encima del -15%%" % target)
		a.lt(measured, target * 1.15, "RT60 de %.1f s medido por debajo del +15%%" % target)

	# Entradas que no se pueden medir devuelven 0.0 en lugar de un numero
	# inventado.
	a.eq(IRAnalyzerClass.rt60_from_ir(null), 0.0, "null devuelve 0.0")
	var empty := AudioStreamWAV.new()
	empty.format = AudioStreamWAV.FORMAT_16_BITS
	empty.data = PackedByteArray()
	a.eq(IRAnalyzerClass.rt60_from_ir(empty), 0.0, "un IR vacio devuelve 0.0")

	# Silencio absoluto tampoco se puede medir.
	var silent := AudioStreamWAV.new()
	silent.format = AudioStreamWAV.FORMAT_16_BITS
	silent.stereo = false
	silent.mix_rate = 44100
	var zeros := PackedByteArray()
	zeros.resize(4096)
	silent.data = zeros
	a.eq(IRAnalyzerClass.rt60_from_ir(silent), 0.0, "un IR en silencio devuelve 0.0")

	return a
