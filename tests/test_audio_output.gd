class_name TestAudioOutput
extends RefCounted

## Aserciones de audio REAL: miden lo que llega a la mezcla, no banderas internas.
##
## Verificado en Godot 4.7.2 que el driver Dummy de --headless si mezcla y que
## AudioEffectCapture devuelve el pico correcto, asi que estas aserciones
## funcionan en CI sin tarjeta de sonido.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")
const PhysicalVoiceChannelClass = preload("res://addons/opendou/runtime/physical_voice_channel.gd")
const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")

## Punto de entrada de la suite asincrona de audio.
static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new()
	a.absorb(await run_probe_selftest_async(tree))
	a.absorb(await run_channel_audio_async(tree))
	a.absorb(await run_budget_async(tree))
	a.absorb(await run_lifecycle_async(tree))
	a.absorb(await run_rtpc_affects_output_async(tree))
	a.absorb(await run_single_voice_async(tree))
	a.absorb(await run_listener_drives_priority_async(tree))
	return a

## La sonda debe medir una senal conocida. Si esto falla, ninguna otra asercion
## de audio de la suite es fiable, asi que se comprueba antes que nada.
##
## Se usa un AudioStreamWAV y no un AudioStreamGenerator a proposito: el servidor
## de audio retiene el AudioStreamGeneratorPlayback incluso despues de stop(), y
## el trinquete de fugas lo detecta como un objeto filtrado. Un WAV real ademas
## se parece mas a como suenan las voces de verdad.
static func run_probe_selftest_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("probe_selftest")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	# Tono constante de amplitud 0.8, sin decaimiento, para que el pico sea
	# estable durante toda la medicion.
	var tone := AudioSynthesizerClass.create_tone(440.0, 2.0, 0.8, false)
	a.gt(float(tone.get_length()), 0.5, "el tono de prueba tiene duracion")

	var player := AudioStreamPlayer.new()
	player.stream = tone
	player.bus = String(probe.bus_name())
	tree.root.add_child(player)
	await tree.process_frame
	player.play()

	probe.drain()
	var peak: float = await probe.measure_peak_over_frames(tree, 20)

	a.gt(peak, 0.05, "la sonda mide senal audible")
	a.approx(peak, 0.8, "pico de un tono de amplitud 0.8", 0.08)

	# Detener debe silenciar de verdad: es la reciproca, y sin ella la sonda
	# podria estar midiendo cualquier cosa menos este reproductor.
	#
	# Hay que dejar que se vacie la cola antes de medir: el audio ya empujado al
	# bus se sigue capturando varios frames despues de stop(), asi que drenar de
	# inmediato mediria la senal anterior y daria un falso positivo.
	player.stop()
	a.ok(await probe.await_silence(tree), "tras stop() el bus queda en silencio")

	player.stream = null
	probe.teardown()
	player.free()
	return a

## Un canal fisico vinculado a un reproductor real debe producir audio medible.
## Este es el test que la observacion n1 no habria pasado nunca: play_stream()
## almacenaba el stream y activaba banderas, sin emitir nada.
static func run_channel_audio_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("channel_audio")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	var pool = NativePlayerPoolClass.new(4)
	tree.root.add_child(pool)
	await tree.process_frame

	var player = pool.acquire(NativePlayerPoolClass.PlayerKind.NON_SPATIAL)
	a.ok(player != null, "el pool entrego un reproductor")

	var tone := AudioSynthesizerClass.create_tone(440.0, 2.0, 0.8, false)

	var channel = PhysicalVoiceChannelClass.new(0)
	channel.bind(player, false)
	channel.play_stream(tone, 0.0, 0.0, 1.0, probe.bus_name())

	# El fade de entrada arranca en 0, asi que hay que procesarlo para que la
	# ganancia suba: sin apply() el reproductor se queda en el suelo de -80 dB.
	probe.drain()
	var peak := 0.0
	for _f in range(24):
		channel.process_fade(0.016)
		channel.apply(0.0, 1.0, 20000.0, Vector3.ZERO)
		await tree.process_frame
		peak = maxf(peak, probe.drain_peak())

	a.gt(peak, 0.05, "el canal fisico produce audio audible")

	# Detener debe silenciar de verdad.
	channel.stop_immediate()
	a.ok(await probe.await_silence(tree), "tras stop_immediate el bus queda en silencio")

	# Soltar el vinculo y dejar pasar un frame antes de liberar: si el reproductor
	# se libera en el mismo frame en que se detuvo, el servidor de audio retiene
	# su objeto de playback y el trinquete de fugas lo detecta.
	channel.bind(null, false)
	pool.release(player)
	await tree.process_frame
	probe.teardown()
	pool.free()
	return a

## Superado el presupuesto, las voces de menor prioridad se virtualizan y
## liberan su canal; las de mayor prioridad se quedan con el permiso.
static func run_budget_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("budget")

	var pool = NativePlayerPoolClass.new(4)
	tree.root.add_child(pool)
	await tree.process_frame

	# Presupuesto de UNA sola voz fisica.
	var vpool = VoicePoolManagerClass.new(1)
	vpool.set_player_pool(pool)

	var tone := AudioSynthesizerClass.create_tone(440.0, 3.0, 0.8, false)

	var near_def = AudioEventDefClass.new(&"Near", tone)
	near_def.base_priority = 90.0
	var far_def = AudioEventDefClass.new(&"Far", tone)
	far_def.base_priority = 10.0

	var near = EventInstanceClass.new(near_def)
	near.set_position(Vector3(1.0, 0.0, 0.0))
	near.max_distance = 100.0
	near.play()
	var far = EventInstanceClass.new(far_def)
	far.set_position(Vector3(80.0, 0.0, 0.0))
	far.max_distance = 100.0
	far.play()

	var instances: Array[EventInstance] = [near, far]
	vpool.resolve_voice_stealing(instances, Vector3.ZERO, 0.016)

	a.eq(near.voice_state, EventInstanceClass.VoiceState.STATE_PHYSICAL, "la voz cercana gana el permiso")
	a.eq(far.voice_state, EventInstanceClass.VoiceState.STATE_VIRTUAL, "la voz lejana queda virtual")
	a.eq(far.assigned_channel_id, -1, "la voz virtual no retiene canal")
	a.gt(float(pool.busy_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)), 0.0,
		"la voz fisica consumio un reproductor del pool")

	# Reanudacion de loops: sin fmod, un ambiente virtualizado mucho tiempo
	# intentaria arrancar mas alla del final del loop y no sonaria.
	var loop_def = AudioEventDefClass.new(&"Looped", tone)
	loop_def.is_looping = true
	loop_def.stream_length = float(tone.get_length())
	var looped = EventInstanceClass.new(loop_def)
	looped.set_position(Vector3.ZERO)
	looped.play()
	looped.logical_playback_position = 180.0
	var vpool2 = VoicePoolManagerClass.new(4)
	vpool2.set_player_pool(pool)
	vpool2.devirtualize(looped)
	var ch = vpool2.get_channel(looped.assigned_channel_id)
	a.ok(ch != null, "la voz en bucle recibio un canal")
	if ch != null:
		a.lt(ch.playback_start_offset, float(tone.get_length()),
			"el offset de reanudacion queda dentro del loop")

	# Virtualizar devuelve el reproductor al pool.
	var busy_before: int = pool.busy_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)
	vpool2.virtualize(looped)
	a.lt(float(pool.busy_count(NativePlayerPoolClass.PlayerKind.SPATIAL_3D)), float(busy_before),
		"virtualizar devuelve el reproductor al pool")

	vpool.virtualize(near)
	probe_free_all(pool)
	await tree.process_frame
	pool.free()
	return a

## Detiene todos los reproductores del pool antes de liberarlo.
static func probe_free_all(pool) -> void:
	for child in pool.get_children():
		if child.has_method("stop"):
			child.stop()
		child.stream = null

## Una voz cuyo stream termina debe salir de active_instances.
##
## Antes no salia nunca: advance_virtual_time() vuelve temprano si el estado no es
## VIRTUAL, asi que una voz fisica no avanzaba su posicion logica y jamas detectaba
## el fin del stream. is_finished() era siempre falso, active_instances crecia sin
## limite, y con 64 voces el pool quedaba ocupado de forma permanente.
static func run_lifecycle_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("lifecycle")

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	# Tono corto para que termine dentro del test.
	var tone := AudioSynthesizerClass.create_tone(660.0, 0.12, 0.6, false)
	var def = AudioEventDefClass.new(&"Blip", tone)
	def.stream_length = float(tone.get_length())
	def.is_looping = false
	manager.register_event_definition(def)

	const EVENT_COUNT := 20
	for _i in range(EVENT_COUNT):
		manager.post_event(&"Blip", null)

	a.eq(manager.active_instances.size(), EVENT_COUNT, "las 20 instancias entran en la lista")

	# Esperar a la condicion, no a un numero de frames: en headless el bucle corre
	# a maxima velocidad y los frames no son proporcionales al tiempo de audio.
	var emptied := false
	for _f in range(6000):
		await tree.process_frame
		if manager.active_instances.is_empty():
			emptied = true
			break

	a.ok(emptied, "la lista se vacia al terminar los streams")
	a.eq(manager.active_instances.size(), 0, "no queda ninguna instancia colgada")

	manager.free()
	return a

## Un cambio de volumen debe mover el pico medido en el bus.
##
## Sin el paso «aplicar» del ciclo por frame, calculated_volume_db se recalcula
## cada frame y la salida no se entera: el volumen, el pitch y el cutoff de
## oclusion eran numeros que no afectaban a ningun sonido.
static func run_rtpc_affects_output_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("rtpc_output")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	var tone := AudioSynthesizerClass.create_tone(440.0, 4.0, 0.8, false)
	var def = AudioEventDefClass.new(&"Sustained", tone)
	def.target_bus = probe.bus_name()
	def.stream_length = float(tone.get_length())
	def.is_looping = true
	def.base_volume_db = 0.0
	manager.register_event_definition(def)

	var inst = manager.post_event(&"Sustained", null)
	a.ok(inst != null, "post_event devuelve una instancia")

	probe.drain()
	var loud: float = await probe.measure_peak_over_frames(tree, 40)
	a.gt(loud, 0.05, "a volumen base el evento suena")

	# Bajar 40 dB debe reflejarse en la salida medida.
	def.base_volume_db = -40.0
	for _f in range(30):
		await tree.process_frame
	probe.drain()
	var quiet: float = await probe.measure_peak_over_frames(tree, 40)
	a.lt(quiet, loud * 0.5, "al bajar 40 dB el pico medido cae")

	# Y volver a subirlo debe recuperarlo: descarta que el pico caiga por otra
	# razon, como que el loop hubiera terminado.
	def.base_volume_db = 0.0
	for _f in range(30):
		await tree.process_frame
	probe.drain()
	var loud_again: float = await probe.measure_peak_over_frames(tree, 40)
	a.gt(loud_again, quiet * 2.0, "al subirlo de nuevo el pico se recupera")

	manager.stop_all()
	probe.teardown()
	manager.free()
	return a

## Un emisor declarativo debe producir UNA voz, no dos.
##
## Antes creaba un EventInstance y ADEMAS llamaba a su propio play(): dos
## reproducciones simultaneas del mismo sonido, con el sumado de +6 dB y el
## comb filtering que eso implica.
static func run_single_voice_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("single_voice")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	var tone := AudioSynthesizerClass.create_tone(440.0, 4.0, 0.5, false)
	var def = AudioEventDefClass.new(&"EmitterTone", tone)
	def.target_bus = probe.bus_name()
	def.stream_length = float(tone.get_length())
	def.is_looping = true

	var emitter = OpenDouEventPlayer3DClass.new()
	emitter.event_def = def
	emitter.set_event_manager(manager)
	tree.root.add_child(emitter)
	await tree.process_frame

	var K = NativePlayerPoolClass.PlayerKind
	var busy_before: int = manager.player_pool.busy_count(K.SPATIAL_3D)
	emitter.play_event()
	for _f in range(6):
		await tree.process_frame

	# La voz sale del propio nodo, no del pool anonimo.
	a.eq(manager.player_pool.busy_count(K.SPATIAL_3D), busy_before,
		"el emisor no consume una voz anonima del pool")
	a.eq(manager.active_instances.size(), 1, "una sola instancia activa")
	a.ok(emitter.active_instance != null, "el emisor guarda su instancia")
	if emitter.active_instance != null:
		a.eq(emitter.active_instance.get_bound_player(), emitter,
			"la instancia esta vinculada al propio emisor")

	# El toggle de HRTF debe haber desaparecido: no se puede cumplir en esta
	# arquitectura y prometerlo era deshonesto.
	a.has_no_property(emitter, "enable_binaural_hrtf", "toggle de HRTF retirado")

	manager.stop_all()
	probe.teardown()
	tree.root.remove_child(emitter)
	emitter.free()
	manager.free()
	return a

## Mover el oyente debe cambiar a que voz se le concede el permiso.
##
## Es el criterio que cierra la observacion 5 por el lado del gameplay: con el
## oyente clavado en Vector3.ZERO, dos voces equidistantes del origen pero a
## distancias muy distintas del jugador competian con el peso equivocado.
static func run_listener_drives_priority_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("listener_priority")

	var pool = NativePlayerPoolClass.new(4)
	tree.root.add_child(pool)
	await tree.process_frame

	var tone := AudioSynthesizerClass.create_tone(440.0, 3.0, 0.6, false)

	# Misma prioridad base en las dos: asi decide la distancia, no el ajuste.
	var def_a = AudioEventDefClass.new(&"VoiceA", tone)
	def_a.base_priority = 50.0
	var def_b = AudioEventDefClass.new(&"VoiceB", tone)
	def_b.base_priority = 50.0

	var voice_a = EventInstanceClass.new(def_a)
	voice_a.set_position(Vector3.ZERO)
	voice_a.max_distance = 200.0
	voice_a.play()
	var voice_b = EventInstanceClass.new(def_b)
	voice_b.set_position(Vector3(100.0, 0.0, 0.0))
	voice_b.max_distance = 200.0
	voice_b.play()

	var instances: Array[EventInstance] = [voice_a, voice_b]

	# Presupuesto de una sola voz: con el oyente en el origen gana la voz A.
	var vpool = VoicePoolManagerClass.new(1)
	vpool.set_player_pool(pool)
	vpool.resolve_voice_stealing(instances, Vector3.ZERO, 0.016)
	a.eq(voice_a.voice_state, EventInstanceClass.VoiceState.STATE_PHYSICAL,
		"con el oyente en el origen gana la voz cercana al origen")
	a.eq(voice_b.voice_state, EventInstanceClass.VoiceState.STATE_VIRTUAL,
		"la voz lejana al oyente queda virtual")

	# Mover el oyente junto a la voz B debe invertir el reparto.
	var vpool2 = VoicePoolManagerClass.new(1)
	vpool2.set_player_pool(pool)
	vpool2.virtualize(voice_a)
	voice_a.play()
	voice_b.play()
	vpool2.resolve_voice_stealing(instances, Vector3(100.0, 0.0, 0.0), 0.016)
	a.eq(voice_b.voice_state, EventInstanceClass.VoiceState.STATE_PHYSICAL,
		"al mover el oyente gana la voz que ahora esta cerca")
	a.eq(voice_a.voice_state, EventInstanceClass.VoiceState.STATE_VIRTUAL,
		"la que antes ganaba pasa a virtual")

	vpool2.virtualize(voice_b)
	tree.root.remove_child(pool)
	pool.free()
	return a
