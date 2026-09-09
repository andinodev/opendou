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

	_library_is_clean(registry, failures)
	_footsteps(registry, failures)
	_mindy(registry, failures)
	_weapons(registry, failures)
	return failures


# ── Libreria ─────────────────────────────────────────────────────────────────

## La libreria que se entrega no lleva rellenos: 90 `Synth_Preset_NN` sin disenar
## (todos Basic_Wave con el mismo esqueleto) tapaban los 14 con nombre propio.
## `Synth_Preset_%d` sigue siendo el nombre que da el editor a un preset nuevo, asi
## que uno que aparezca aqui es uno que alguien guardo sin bautizar.
static func _library_is_clean(registry, failures: Array[String]) -> void:
	var fillers: Array[String] = []
	for n in registry.get_preset_names():
		if str(n).begins_with("Synth_Preset_"):
			fillers.append(str(n))
	_check(failures, fillers.is_empty(), "libreria: sin rellenos Synth_Preset_NN (quedan %d: %s)" % [fillers.size(), ", ".join(fillers.slice(0, 5))])
	# Y todo preset del juego vive en una categoria Game/*
	for prefix in ["step_", "shot_", "reload_", "mindy_", "swing_", "proj_", "explosion_", "hit_"]:
		for n in registry.get_preset_names():
			if str(n).begins_with(prefix):
				_check(failures, registry.get_preset_category(n).begins_with("Game/"),
					"libreria: %s deberia estar en una categoria Game/* (%s)" % [str(n), registry.get_preset_category(n)])


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

	# Un disparo es un transitorio: su frente de energia (la ventana de 5 ms mas
	# fuerte) cae en los primeros 20 ms
	var front_ms := _loudest_window_ms(streams["shot_Revolver"])
	_check(failures, front_ms < 20.0, "mindy: el frente del disparo cae en los primeros 20 ms (%.1f ms)" % front_ms)

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


# ── Armas y proyectiles ──────────────────────────────────────────────────────

## Del catalogo real de heroshooter (WeaponCatalog.BY_HERO y los kits): un disparo
## por arma, dos de cuerpo a cuerpo, dos proyectiles, tres explosiones por tamano y
## los cuatro impactos que hoy son formulas del juego.
const HITSCAN_SHOTS := ["shot_Pistol", "shot_Smg", "shot_AssaultRifle", "shot_Bullpup", "shot_Shotgun", "shot_Sniper"]
const WEAPONS := HITSCAN_SHOTS + [
	"shot_GrenadeLauncher", "shot_Beam",
	"swing_Sword", "swing_Fists",
	"proj_Knife", "proj_GrenadeBounce",
	"explosion_Small", "explosion_Medium", "explosion_Large",
	"hit_Body", "hit_Armor", "hit_Shield", "hit_Headshot",
]

static func _weapons(registry, failures: Array[String]) -> void:
	var streams := {}
	for name in WEAPONS:
		var p: Dictionary = registry.get_preset(StringName(name))
		_check(failures, not p.is_empty(), "armas: existe %s" % name)
		if p.is_empty():
			continue
		_check(failures, str(p.get("category", "")) == "Game/Weapons", "armas: %s en Game/Weapons" % name)
		var wav = registry.get_preset_stream(StringName(name), absi(hash(name)))
		if wav == null or wav.data.is_empty():
			failures.append("armas: %s no sintetiza" % name)
			continue
		streams[name] = _samples(wav)
		var peak_db := _peak_db(streams[name])
		_check(failures, peak_db <= PEAK_MAX_DB and peak_db >= PEAK_MIN_DB,
			"armas: pico de %s en [%.1f, %.1f] dBFS (%.1f)" % [name, PEAK_MIN_DB, PEAK_MAX_DB, peak_db])

	if streams.size() < WEAPONS.size():
		return

	# Un arma de fuego estalla: su frente de energia (la ventana de 5 ms mas fuerte)
	# cae en los primeros 20 ms. Un golpe de espada o de puno hincha el aire: el
	# frente llega despues de 20 ms. Se mide por ventana y no por la muestra mas
	# alta porque un estallido saturado es una meseta y su maximo cae en ruido.
	for name in HITSCAN_SHOTS:
		var front_ms := _loudest_window_ms(streams[name])
		_check(failures, front_ms < 20.0, "armas: %s estalla en los primeros 20 ms (%.1f ms)" % [name, front_ms])
	for name in ["swing_Sword", "swing_Fists"]:
		var front_ms := _loudest_window_ms(streams[name])
		_check(failures, front_ms > 20.0, "armas: %s se hincha, frente despues de 20 ms (%.1f ms)" % [name, front_ms])

	# Calibre: la escopeta tiene mas graves que la pistola; el francotirador dura mas que el subfusil
	var low_shotgun := _band_rms(streams["shot_Shotgun"], "LowPass", 200.0)
	var low_pistol := _band_rms(streams["shot_Pistol"], "LowPass", 200.0)
	_check(failures, low_shotgun > low_pistol, "armas: la escopeta tiene mas graves que la pistola (%.4f > %.4f)" % [low_shotgun, low_pistol])
	_check(failures, streams["shot_Sniper"].size() > streams["shot_Smg"].size(), "armas: el francotirador dura mas que el subfusil")

	# Las explosiones crecen en graves y en duracion con su tamano
	var sizes := ["explosion_Small", "explosion_Medium", "explosion_Large"]
	var low := []
	for n in sizes:
		low.append(_band_rms(streams[n], "LowPass", 200.0))
	_check(failures, low[2] > low[1] and low[1] > low[0],
		"armas: graves Large > Medium > Small (%.4f > %.4f > %.4f)" % [low[2], low[1], low[0]])
	_check(failures, streams["explosion_Large"].size() > streams["explosion_Medium"].size() and streams["explosion_Medium"].size() > streams["explosion_Small"].size(),
		"armas: duracion Large > Medium > Small")

	# Impactos: el headshot brilla, la armadura apaga
	var hi_head := _band_fraction(streams["hit_Headshot"], "HighPass", 2000.0)
	var hi_body := _band_fraction(streams["hit_Body"], "HighPass", 2000.0)
	_check(failures, hi_head > hi_body, "armas: el headshot es mas brillante que el impacto en cuerpo (%.3f > %.3f)" % [hi_head, hi_body])
	var lo_armor := _band_fraction(streams["hit_Armor"], "LowPass", 600.0)
	var lo_body := _band_fraction(streams["hit_Body"], "LowPass", 600.0)
	_check(failures, lo_armor > lo_body, "armas: la armadura suena mas apagada que el cuerpo (%.3f > %.3f)" % [lo_armor, lo_body])


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


## Instante (ms) en que empieza la ventana de `window_sec` con mas energia.
static func _loudest_window_ms(s: PackedFloat32Array, window_sec: float = 0.005) -> float:
	var w: int = maxi(1, int(window_sec * 44100.0))
	if s.size() <= w:
		return 0.0
	var acc := 0.0
	for i in range(w):
		acc += s[i] * s[i]
	var best := acc
	var best_at := 0
	for i in range(w, s.size()):
		acc += s[i] * s[i] - s[i - w] * s[i - w]
		if acc > best:
			best = acc
			best_at = i - w + 1
	return best_at * 1000.0 / 44100.0


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
