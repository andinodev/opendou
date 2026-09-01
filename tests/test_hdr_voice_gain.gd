class_name TestHDRVoiceGain
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const AudioHDREngineClass = preload("res://addons/opendou/core/audio_hdr_engine.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("hdr_voice_gain")

	# La sonoridad es una propiedad de DISENO del evento: cuanto suena esa cosa en
	# el mundo. Explosion +18, pisada -20. No es el nivel de mezcla.
	var def = AudioEventDefClass.new(&"Explosion")
	a.approx(def.hdr_loudness_db, 0.0, "la sonoridad por defecto es 0 dB", 0.001)

	var engine = AudioHDREngineClass.new()

	# Con todo a 0.0, la contribucion es EXACTAMENTE 0 dB. Es lo que hace seguro
	# activar HDR por defecto sin alterar ninguna mezcla existente.
	engine.push_event_loudness(0.0)
	engine.update(0.016)
	a.approx(engine.calculate_voice_gain_db(0.0), 0.0, "con sonoridad 0 la contribucion es nula", 0.01)

	# Con una explosion de +18 sonando, la ventana sube. Su suelo queda en
	# 18 - 40 = -22, asi que una voz de -50 cae por debajo y se atenua al minimo.
	var loud = AudioHDREngineClass.new()
	for _f in range(40):
		loud.push_event_loudness(18.0)
		loud.update(0.05)
	var bounds: Vector2 = loud.get_window_bounds()
	a.gt(bounds.x, 10.0, "la ventana sube con una voz fuerte")
	a.lt(loud.calculate_voice_gain_db(-50.0), -70.0, "una voz muy por debajo del suelo se atenua al minimo")

	# Y una voz en el techo de la ventana no se atenua.
	a.approx(loud.calculate_voice_gain_db(bounds.x), 0.0, "una voz en el techo no se atenua", 0.01)

	# La contribucion nunca es positiva: se suma como atenuacion.
	for loudness in [-80.0, -20.0, 0.0, 18.0, 40.0]:
		a.ok(loud.calculate_voice_gain_db(loudness) <= 0.001,
			"la contribucion con sonoridad %.0f no es positiva" % loudness)

	return a
