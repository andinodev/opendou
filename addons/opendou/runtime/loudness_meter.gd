class_name OpenDouLoudnessMeter
extends RefCounted

## Medidor de sonoridad segun ITU-R BS.1770-4 / EBU R128 sobre un AudioEffectCapture.
##
## Filtro K (high-shelf +4 dB a 1681 Hz y paso-alto a 38 Hz) por canal, potencia media por
## bloques de 100 ms, momentanea (400 ms), a corto plazo (3 s) e integrada con compuerta
## absoluta (-70 LUFS) y relativa (-10 LU). El pico es MUESTRAL: un pico verdadero exige
## sobremuestreo x4 y no esta hecho, por eso se llama sample_peak_db.
##
## Va apagado por defecto: procesar 44 100 muestras por segundo en GDScript no es gratis.
## last_process_usec deja el coste a la vista.

const MARK: String = "OpenDou_LoudnessMeter_Capture"
const MARK_TAP: String = "OpenDou_LoudnessMeter_Tap"
## Fase 15 (C4): con la extension, el filtro K y los bloques los hace OpenDouLoudnessTap en el
## hilo de audio y aqui solo quedan la compuerta y las ventanas (10 numeros por segundo).
var use_native: bool = false
## Fuerza el camino GDScript aunque exista la extension (tests de equivalencia).
var force_gdscript: bool = false
var _tap = null
const BLOCK_SEC: float = 0.1
const ABS_GATE: float = -70.0
const REL_GATE: float = -10.0

var momentary_lufs: float = -INF
var short_term_lufs: float = -INF
var integrated_lufs: float = -INF
var sample_peak_db: float = -INF
var processed_seconds: float = 0.0
var last_process_usec: int = 0

var _capture: AudioEffectCapture = null
var _bus_index: int = -1
var _rate: float = 44100.0
var _k: Array = []          # [ [b0,b1,b2,a1,a2] shelf, [..] hpf ]
var _z: Array = []          # [canal][etapa] -> [z1, z2]
var _block_samples: int = 4410
var _block_acc: Array = [0.0, 0.0]
var _block_count: int = 0
var _blocks: Array[float] = []   # potencia (suma de canales) por bloque de 100 ms
var _peak: float = 0.0

func attach(bus: StringName) -> bool:
	var idx: int = AudioServer.get_bus_index(String(bus))
	if idx < 0:
		return false
	if (_capture != null or _tap != null) and _bus_index == idx:
		return true
	detach()
	use_native = ClassDB.class_exists("OpenDouLoudnessTap") and not force_gdscript
	if use_native:
		for e in range(AudioServer.get_bus_effect_count(idx)):
			var fx := AudioServer.get_bus_effect(idx, e)
			if fx != null and fx.resource_name == MARK_TAP:
				_tap = fx
		if _tap == null:
			_tap = ClassDB.instantiate("OpenDouLoudnessTap")
			_tap.resource_name = MARK_TAP
			AudioServer.add_bus_effect(idx, _tap)
	else:
		for e in range(AudioServer.get_bus_effect_count(idx)):
			var fx := AudioServer.get_bus_effect(idx, e)
			if fx != null and fx.resource_name == MARK:
				_capture = fx
		if _capture == null:
			_capture = AudioEffectCapture.new()
			_capture.resource_name = MARK
			_capture.buffer_length = 2.0
			AudioServer.add_bus_effect(idx, _capture)
	_bus_index = idx
	_rate = AudioServer.get_mix_rate()
	_block_samples = int(_rate * BLOCK_SEC)
	_design_k_filter()
	reset()
	return true

func detach() -> void:
	if (_capture != null or _tap != null) and _bus_index >= 0 and _bus_index < AudioServer.bus_count:
		for e in range(AudioServer.get_bus_effect_count(_bus_index) - 1, -1, -1):
			var fx := AudioServer.get_bus_effect(_bus_index, e)
			if fx == _capture or fx == _tap:
				AudioServer.remove_bus_effect(_bus_index, e)
	_capture = null
	_tap = null
	_bus_index = -1

func is_attached() -> bool:
	return _capture != null or _tap != null

func reset() -> void:
	_blocks.clear()
	_block_acc = [0.0, 0.0]
	_block_count = 0
	_z = [[[0.0, 0.0], [0.0, 0.0]], [[0.0, 0.0], [0.0, 0.0]]]
	_peak = 0.0
	momentary_lufs = -INF
	short_term_lufs = -INF
	integrated_lufs = -INF
	sample_peak_db = -INF
	processed_seconds = 0.0
	if _tap != null:
		_tap.reset()

## Drena la captura y actualiza las medidas. Llamar una vez por frame.
func process() -> void:
	if _tap != null:
		var t0n: int = Time.get_ticks_usec()
		var blocks: PackedFloat32Array = _tap.take_blocks()
		for p in blocks:
			_blocks.append(p)
			_after_block()
		var pk: float = _tap.take_peak()
		if pk > _peak:
			_peak = pk
		processed_seconds += float(blocks.size()) * BLOCK_SEC
		sample_peak_db = linear_to_db(_peak) if _peak > 0.0 else -INF
		last_process_usec = Time.get_ticks_usec() - t0n
		return
	if _capture == null:
		return
	var t0: int = Time.get_ticks_usec()
	var avail: int = _capture.get_frames_available()
	if avail <= 0:
		last_process_usec = Time.get_ticks_usec() - t0
		return
	var frames: PackedVector2Array = _capture.get_buffer(avail)
	var kl: Array = _k[0]
	var kh: Array = _k[1]
	var zl0: Array = _z[0][0]
	var zl1: Array = _z[0][1]
	var zr0: Array = _z[1][0]
	var zr1: Array = _z[1][1]
	var acc_l: float = _block_acc[0]
	var acc_r: float = _block_acc[1]
	var peak: float = _peak
	for f in frames:
		# Filtro K, izquierda: shelf y luego paso-alto (forma directa II transpuesta).
		var x: float = f.x
		var y: float = kl[0] * x + zl0[0]
		zl0[0] = kl[1] * x - kl[3] * y + zl0[1]
		zl0[1] = kl[2] * x - kl[4] * y
		var y2: float = kh[0] * y + zl1[0]
		zl1[0] = kh[1] * y - kh[3] * y2 + zl1[1]
		zl1[1] = kh[2] * y - kh[4] * y2
		acc_l += y2 * y2
		# Derecha.
		x = f.y
		y = kl[0] * x + zr0[0]
		zr0[0] = kl[1] * x - kl[3] * y + zr0[1]
		zr0[1] = kl[2] * x - kl[4] * y
		y2 = kh[0] * y + zr1[0]
		zr1[0] = kh[1] * y - kh[3] * y2 + zr1[1]
		zr1[1] = kh[2] * y - kh[4] * y2
		acc_r += y2 * y2
		var ax: float = absf(f.x)
		var ay: float = absf(f.y)
		if ax > peak:
			peak = ax
		if ay > peak:
			peak = ay
		_block_count += 1
		if _block_count >= _block_samples:
			_block_acc[0] = acc_l
			_block_acc[1] = acc_r
			_close_block()
			acc_l = 0.0
			acc_r = 0.0
	_block_acc[0] = acc_l
	_block_acc[1] = acc_r
	_peak = peak
	processed_seconds += float(avail) / _rate
	sample_peak_db = linear_to_db(_peak) if _peak > 0.0 else -INF
	last_process_usec = Time.get_ticks_usec() - t0

func _close_block() -> void:
	var n: float = float(_block_count)
	_blocks.append(_block_acc[0] / n + _block_acc[1] / n)
	_block_acc = [0.0, 0.0]
	_block_count = 0
	_after_block()

## Ventanas y compuerta tras anadir un bloque (camino GDScript y nativo).
func _after_block() -> void:
	momentary_lufs = _lufs_of_last(4)
	short_term_lufs = _lufs_of_last(30)
	integrated_lufs = _gated_integrated()

static func _power_to_lufs(p: float) -> float:
	if p <= 0.0:
		return -INF
	return -0.691 + 10.0 * log(p) / log(10.0)

func _lufs_of_last(count: int) -> float:
	if _blocks.size() < count:
		return -INF
	var acc: float = 0.0
	for i in range(_blocks.size() - count, _blocks.size()):
		acc += _blocks[i]
	return _power_to_lufs(acc / float(count))

## Integrada con compuerta: se promedian las ventanas de 400 ms (4 bloques solapados a 100
## ms) que superan -70 LUFS, y de esas, las que superan la media provisional menos 10 LU.
func _gated_integrated() -> float:
	if _blocks.size() < 4:
		return -INF
	var passing: Array[float] = []
	for i in range(3, _blocks.size()):
		var w: float = (_blocks[i - 3] + _blocks[i - 2] + _blocks[i - 1] + _blocks[i]) * 0.25
		if _power_to_lufs(w) > ABS_GATE:
			passing.append(w)
	if passing.is_empty():
		return -INF
	var mean: float = 0.0
	for w in passing:
		mean += w
	mean /= float(passing.size())
	var rel_gate: float = _power_to_lufs(mean) + REL_GATE
	var acc: float = 0.0
	var n: int = 0
	for w in passing:
		if _power_to_lufs(w) > rel_gate:
			acc += w
			n += 1
	return _power_to_lufs(acc / float(n)) if n > 0 else -INF

## Coeficientes del filtro K para la mix_rate real (RBJ con los parametros de la norma:
## shelf f0 = 1681.97 Hz, Q = 0.7071752, +3.99984 dB; paso-alto f0 = 38.13547 Hz, Q = 0.5003270).
func _design_k_filter() -> void:
	_k = [_rbj_highshelf(1681.974450955533, 0.7071752369554196, 3.999843853973347), _rbj_highpass(38.13547087602444, 0.5003270373238773)]

func _rbj_highshelf(f0: float, q: float, gain_db: float) -> Array:
	var A: float = pow(10.0, gain_db / 40.0)
	var w0: float = TAU * f0 / _rate
	var cw: float = cos(w0)
	var sw: float = sin(w0)
	var alpha: float = sw / (2.0 * q)
	var s2a: float = 2.0 * sqrt(A) * alpha
	var a0: float = (A + 1.0) - (A - 1.0) * cw + s2a
	return [
		A * ((A + 1.0) + (A - 1.0) * cw + s2a) / a0,
		-2.0 * A * ((A - 1.0) + (A + 1.0) * cw) / a0,
		A * ((A + 1.0) + (A - 1.0) * cw - s2a) / a0,
		2.0 * ((A - 1.0) - (A + 1.0) * cw) / a0,
		((A + 1.0) - (A - 1.0) * cw - s2a) / a0,
	]

func _rbj_highpass(f0: float, q: float) -> Array:
	var w0: float = TAU * f0 / _rate
	var cw: float = cos(w0)
	var sw: float = sin(w0)
	var alpha: float = sw / (2.0 * q)
	var a0: float = 1.0 + alpha
	return [(1.0 + cw) * 0.5 / a0, -(1.0 + cw) / a0, (1.0 + cw) * 0.5 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0]
