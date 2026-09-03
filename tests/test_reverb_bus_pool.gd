class_name TestReverbBusPool
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const ReverbBusPoolClass = preload("res://addons/opendou/runtime/spatial/reverb_bus_pool.gd")

## El reverb del bus: desde la Fase 15 la posicion 0 puede ser la entrada de envio nativa.
static func _reverb_of(idx: int) -> AudioEffectReverb:
	for e in range(AudioServer.get_bus_effect_count(idx)):
		var fx := AudioServer.get_bus_effect(idx, e)
		if fx is AudioEffectReverb:
			return fx
	return null

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("reverb_bus_pool")
	var buses_before: int = AudioServer.bus_count

	var pool = ReverbBusPoolClass.new()
	pool.configure(3, 0.3)

	# Dos salas con RT60 dentro del mismo escalon comparten bus: con 100 salas
	# siguen siendo unos pocos buses, y Godot procesa cada bus cada frame.
	var bus_a: StringName = pool.bus_for_rt60(1.20, 0.1)
	var bus_b: StringName = pool.bus_for_rt60(1.28, 0.1)
	a.eq(bus_a, bus_b, "RT60 del mismo escalon comparten bus")
	a.eq(pool.managed_bus_count(), 1, "solo se creo un bus")

	# RT60 de escalones distintos no comparten.
	var bus_c: StringName = pool.bus_for_rt60(3.0, 0.1)
	a.ok(bus_c != bus_a, "RT60 de escalones distintos usan buses distintos")
	a.eq(pool.managed_bus_count(), 2, "ya hay dos buses")

	# El bus existe de verdad en el AudioServer y lleva un reverb insertado.
	var idx: int = AudioServer.get_bus_index(String(bus_a))
	a.gt(float(idx), 0.0, "el bus existe en el AudioServer")
	if idx >= 0:
		a.gt(float(AudioServer.get_bus_effect_count(idx)), 0.0, "el bus lleva al menos un efecto")
		a.ok(_reverb_of(idx) is AudioEffectReverb, "el bus tiene un AudioEffectReverb (tras la entrada de envio si hay extension)")

	# Superado el techo, una sala nueva reutiliza el escalon mas proximo en lugar
	# de crear buses sin limite.
	pool.bus_for_rt60(0.3, 0.5)
	a.eq(pool.managed_bus_count(), 3, "se alcanza el techo de 3 buses")
	var overflow: StringName = pool.bus_for_rt60(9.0, 0.02)
	a.eq(pool.managed_bus_count(), 3, "el techo no se supera")
	a.ok(not String(overflow).is_empty(), "aun asi devuelve un bus utilizable")
	a.ok(AudioServer.get_bus_index(String(overflow)) != -1, "el bus de desborde existe")

	# El escalon se calcula por redondeo sobre el paso configurado.
	a.eq(pool.tier_for_rt60(1.20), 4, "1.20 s con paso 0.3 cae en el escalon 4")
	a.eq(pool.tier_for_rt60(0.0), 0, "un RT60 nulo cae en el escalon 0")

	# Un RT60 mas alto produce un reverb de sala mas grande: el mapeo tiene que
	# ser monotono o el escalonado no significaria nada.
	var idx_small: int = AudioServer.get_bus_index(String(pool.bus_for_rt60(0.3, 0.5)))
	var idx_big: int = AudioServer.get_bus_index(String(bus_c))
	if idx_small > 0 and idx_big > 0:
		var small_reverb = _reverb_of(idx_small)
		var big_reverb = _reverb_of(idx_big)
		a.gt(big_reverb.room_size, small_reverb.room_size, "mas RT60 da mas room_size")

	pool.release_all()
	a.eq(AudioServer.bus_count, buses_before, "release_all deja el AudioServer como estaba")
	return a
