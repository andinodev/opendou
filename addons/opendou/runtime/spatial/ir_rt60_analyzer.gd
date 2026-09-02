class_name OpenDouIRRT60Analyzer
extends RefCounted

## Deriva el RT60 de una respuesta al impulso medida.
##
## Existe porque la convolucion en GDScript no era viable: 512 taps por muestra
## es DSP interpretado, justo lo que la arquitectura evita. Pero un IR medido
## sigue siendo informacion valiosa, y de el se puede sacar el RT60 que alimenta
## el reverb nativo. Eso es lo que hace un disenador de audio con una medicion
## real de sala.
##
## Metodo: integracion de Schroeder mas extrapolacion T20. Buscar ingenuamente la
## caida de 60 dB no funciona, porque el ruido de fondo de cualquier IR medido la
## enmascara mucho antes de llegar.

const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")

## Nivel al que empieza el tramo que se ajusta, en dB bajo el maximo.
const T20_START_DB: float = -5.0

## Nivel al que acaba el tramo que se ajusta, en dB bajo el maximo.
const T20_END_DB: float = -25.0

## Muestras minimas para intentar una medida.
const MIN_SAMPLES: int = 64

## RT60 de una respuesta al impulso, en segundos. Devuelve 0.0 si no se puede
## medir.
static func rt60_from_ir(wav: AudioStreamWAV) -> float:
	if wav == null:
		return 0.0
	var samples: PackedFloat32Array = WavDecoderClass.to_mono_floats(wav)
	if samples.size() < MIN_SAMPLES:
		return 0.0
	var rate: float = float(wav.mix_rate)
	if rate <= 0.0:
		return 0.0

	# Curva de decaimiento de energia por integracion de Schroeder: se acumula la
	# energia desde el final hacia el principio. Es el metodo estandar; medir el
	# envolvente instantaneo daria una curva demasiado ruidosa para ajustar.
	var n: int = samples.size()
	var edc := PackedFloat64Array()
	edc.resize(n)
	var acc: float = 0.0
	for i in range(n - 1, -1, -1):
		var s: float = samples[i]
		acc += s * s
		edc[i] = acc

	var total: float = edc[0]
	if total <= 0.0:
		return 0.0

	var t_start: float = -1.0
	var t_end: float = -1.0
	for i in range(n):
		var ratio: float = edc[i] / total
		if ratio <= 0.0:
			break
		var db: float = 10.0 * (log(ratio) / log(10.0))
		if t_start < 0.0 and db <= T20_START_DB:
			t_start = float(i) / rate
		if db <= T20_END_DB:
			t_end = float(i) / rate
			break

	if t_start < 0.0 or t_end < 0.0 or t_end <= t_start:
		return 0.0

	# La pendiente se mide sobre el tramo de 20 dB y se extrapola a 60: de ahi el
	# factor 3.
	var span_db: float = absf(T20_END_DB - T20_START_DB)
	return 60.0 * (t_end - t_start) / span_db
