class_name TestGamePresets
extends RefCounted

## Los presets del juego (pisadas, Mindy, armas) medidos en el audio que sintetizan.
##
## La libreria de presets se autora contra la convencion que fija el juego
## (`SfxPresets.footstep_name`: `step_heavy_Metal`, `step_light_Concrete`). Estos
## tests afirman lo que cada preset promete con numeros sacados del WAV, no con
## su nombre: que una pisada pesada tiene mas graves que una ligera, que el metal
## resuena mas arriba y mas tiempo que el hormigon, que un disparo es un
## transitorio y que el apagon de Mindy dura mas que su pulso.

const SynthPresetRegistryClass = preload("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
const ModularSynthEngineClass = preload("res://addons/opendou/runtime/synth/modular_synth_engine.gd")

const WEIGHTS := ["heavy", "normal", "light"]
const SURFACES := ["Concrete", "Metal"]

const MINDY := [
	"shot_Revolver", "reload_start_Revolver", "reload_end_Revolver",
	"mindy_emp", "mindy_mine_arm", "mindy_mine_blast", "mindy_blackout",
]

## Techo y suelo del pico de cada preset, en dBFS. Por encima del techo el WAV
## recorta (el motor satura a 1.0); por debajo del suelo el sonido llega
## enterrado en la mezcla del juego.
const PEAK_MAX_DB := -0.3
const PEAK_MIN_DB := -12.0

static var last_assertions: int = 0


static func run_all() -> Array[String]:
	var failures: Array[String] = []
	last_assertions = 0
	var registry = SynthPresetRegistryClass.get_singleton()
	registry.load_presets()

	_footsteps(registry, failures)
	_mindy(registry, failures)
	return failures


# ── Pisadas ──────────────────────────────────────────────────────────────────

static func _footsteps(registry, failures: Array[String]) -> void:
	var expected := {}
	for w in WEIGHTS:
		for s in SURFACES:
			expected["step_%s_%s" % [w, s]] = true

	# Las seis existen, son contenedores por capas y llevan su categoria
	for name in expected:
		var p: Dictionary = registry.get_preset(StringName(name))
		_check(failures, not p.is_empty(), "pisadas: existe %s" % name)
		if p.is_empty():
			continue
		_check(failures, str(p.get("category", "")) == "Game/Footsteps", "pisadas: %s en Game/Footsteps" % name)
		_check(failures, str(p.get("type", "")) == "Layer_Container", "pisadas: %s es Layer_Container" % name)

	# Y la categoria no tiene nombres fuera de la convencion
	var in_cat: Array[StringName] = registry.get_presets_by_category("Game/Footsteps")
	for n in in_cat:
		_check(failures, expected.has(str(n)), "pisadas: '%s' no sigue step_<peso>_<Superficie>" % str(n))

	var streams := {}
	for name in expected:
		var wav = registry.get_preset_stream(StringName(name), absi(hash(name)))
		if wav == null or wav.data.is_empty():
			failures.append("pisadas: %s no sintetiza" % name)
			continue
		streams[name] = _samples(wav)
		var peak_db := _peak_db(streams[name])
		_check(failures, peak_db <= PEAK_MAX_DB and peak_db >= PEAK_MIN_DB,
			"pisadas: pico de %s en [%.1f, %.1f] dBFS (%.1f)" % [name, PEAK_MIN_DB, PEAK_MAX_DB, peak_db])

	# El peso se oye en los graves: heavy > normal > light bajo 200 Hz
	for s in SURFACES:
		var low := []
		for w in WEIGHTS:
			var n := "step_%s_%s" % [w, s]
			low.append(_band_rms(streams.get(n, PackedFloat32Array()), "LowPass", 200.0))
		_check(failures, low[0] > low[1] and low[1] > low[2],
			"pisadas %s: graves heavy > normal > light (%.4f > %.4f > %.4f)" % [s, low[0], low[1], low[2]])

	# El metal resuena: mas energia sobre 2 kHz y mas duracion que el hormigon
	for w in WEIGHTS:
		var c := "step_%s_Concrete" % w
		var m := "step_%s_Metal" % w
		var sc: PackedFloat32Array = streams.get(c, PackedFloat32Array())
		var sm: PackedFloat32Array = streams.get(m, PackedFloat32Array())
		var hi_c := _band_fraction(sc, "HighPass", 2000.0)
		var hi_m := _band_fraction(sm, "HighPass", 2000.0)
		_check(failures, hi_m > hi_c, "pisadas %s: Metal mas agudo que Concrete (%.3f > %.3f)" % [w, hi_m, hi_c])
		_check(failures, sm.size() > sc.size(), "pisadas %s: Metal dura mas que Concrete (%d > %d muestras)" % [w, sm.size(), sc.size()])


# ── Mindy ────────────────────────────────────────────────────────────────────

static func _mindy(registry, failures: Array[String]) -> void:
	var streams := {}
	for name in MINDY:
		var p: Dictionary = registry.get_preset(StringName(name))
		_check(failures, not p.is_empty(), "mindy: existe %s" % name)
		if p.is_empty():
			continue
		_check(failures, str(p.get("category", "")) == "Game/Mindy", "mindy: %s en Game/Mindy" % name)
		var wav = registry.get_preset_stream(StringName(name), absi(hash(name)))
		if wav == null or wav.data.is_empty():
			failures.append("mindy: %s no sintetiza" % name)
			continue
		streams[name] = _samples(wav)
		var peak_db := _peak_db(streams[name])
		_check(failures, peak_db <= PEAK_MAX_DB and peak_db >= PEAK_MIN_DB,
			"mindy: pico de %s en [%.1f, %.1f] dBFS (%.1f)" % [name, PEAK_MIN_DB, PEAK_MAX_DB, peak_db])

	if streams.size() < MINDY.size():
		return

	# Un disparo es un transitorio: el pico cae en los primeros 15 ms
	var shot: PackedFloat32Array = streams["shot_Revolver"]
	var peak_at := _peak_index(shot)
	_check(failures, peak_at < int(0.015 * 44100), "mindy: el pico del disparo cae en los primeros 15 ms (%.1f ms)" % (peak_at * 1000.0 / 44100.0))

	# El apagon es la version grande del pulso: dura mas
	_check(failures, streams["mindy_blackout"].size() > streams["mindy_emp"].size(),
		"mindy: el apagon dura mas que el EMP (%d > %d muestras)" % [streams["mindy_blackout"].size(), streams["mindy_emp"].size()])

	# La mina que explota tiene cuerpo grave; la que se arma es un aviso agudo
	var low_blast := _band_fraction(streams["mindy_mine_blast"], "LowPass", 200.0)
	var low_arm := _band_fraction(streams["mindy_mine_arm"], "LowPass", 200.0)
	_check(failures, low_blast > low_arm, "mindy: la explosion de la mina es mas grave que su armado (%.3f > %.3f)" % [low_blast, low_arm])

	# Cerrar el tambor suena mas metalico (agudo) que abrirlo
	var hi_end := _band_fraction(streams["reload_end_Revolver"], "HighPass", 2000.0)
	var hi_start := _band_fraction(streams["reload_start_Revolver"], "HighPass", 2000.0)
	_check(failures, hi_end > hi_start, "mindy: cerrar el tambor es mas agudo que abrirlo (%.3f > %.3f)" % [hi_end, hi_start])


# ── Medidas ──────────────────────────────────────────────────────────────────

static func _check(failures: Array[String], cond: bool, msg: String) -> void:
	last_assertions += 1
	if not cond:
		failures.append("TestGamePresets: " + msg)


## Muestras en [-1, 1] del canal izquierdo (o del mono) de un WAV de 16 bits.
static func _samples(wav: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var stride: int = 4 if wav.stereo else 2
	var n: int = wav.data.size() / stride
	out.resize(n)
	for i in range(n):
		out[i] = float(wav.data.decode_s16(i * stride)) / 32768.0
	return out


static func _peak_index(s: PackedFloat32Array) -> int:
	var best := 0
	var best_v := 0.0
	for i in range(s.size()):
		var v := absf(s[i])
		if v > best_v:
			best_v = v
			best = i
	return best


static func _peak_db(s: PackedFloat32Array) -> float:
	if s.is_empty():
		return -200.0
	var v := absf(s[_peak_index(s)])
	return linear_to_db(maxf(v, 1e-9))


static func _rms(s: PackedFloat32Array) -> float:
	if s.is_empty():
		return 0.0
	var acc := 0.0
	for v in s:
		acc += v * v
	return sqrt(acc / s.size())


## RMS de la banda que deja pasar un biquad del propio motor (LowPass/HighPass a cutoff).
static func _band_rms(s: PackedFloat32Array, kind: String, cutoff_hz: float) -> float:
	if s.is_empty():
		return 0.0
	var bq = ModularSynthEngineClass.Biquad.new()
	bq.setup(kind, cutoff_hz, 0.707, 44100.0)
	var acc := 0.0
	for v in s:
		var y: float = bq.process(v)
		acc += y * y
	return sqrt(acc / s.size())


## Fraccion de la energia total que cae en la banda: independiente del nivel.
static func _band_fraction(s: PackedFloat32Array, kind: String, cutoff_hz: float) -> float:
	var total := _rms(s)
	if total <= 0.0:
		return 0.0
	var band := _band_rms(s, kind, cutoff_hz)
	return (band * band) / (total * total)
