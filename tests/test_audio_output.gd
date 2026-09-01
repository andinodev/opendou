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
const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const SoundBankBuilderClass = preload("res://addons/opendou/runtime/soundbank_builder.gd")

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
	a.absorb(await run_room_reverb_async(tree))
	a.absorb(await run_bank_event_audio_async(tree))
	a.absorb(await run_hdr_ducking_async(tree))
	a.absorb(await run_stop_all_async(tree))
	a.absorb(await run_voice_budget_change_async(tree))
	return a


## Cambiar el presupuesto de voces no puede dejar el motor mudo.
##
## Observacion 30: set_max_physical_voices() sustituia el VoicePoolManager entero y no
## le pasaba el pool de reproductores, asi que el pool nuevo nacia con player_pool en
## null, devirtualize() salia temprano y NADA volvia a sonar. Es la llamada mas obvia
## que haria un juego al arrancar.
static func run_voice_budget_change_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("voice_budget_change")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	var tone := AudioSynthesizerClass.create_tone(520.0, 0.4, 0.8, false)
	var def = AudioEventDefClass.new(&"BudgetTone", tone)
	def.is_looping = true
	def.stream_length = 0.4
	def.target_bus = probe.bus_name()
	manager.register_event_definition(def)

	# El presupuesto se cambia ANTES de postear, que es lo que haria un juego al
	# arrancar.
	manager.set_max_physical_voices(4)
	a.eq(manager.voice_pool.max_physical_voices, 4, "el presupuesto quedo en 4")
	a.ok(manager.voice_pool.player_pool != null,
		"y el pool nuevo tiene reproductores: sin esto el motor se queda mudo")

	manager.post_event(&"BudgetTone", null)
	probe.drain()
	var peak: float = await probe.measure_peak_over_frames(tree, 30)
	a.gt(peak, 0.001, "tras cambiar el presupuesto el evento SUENA")
	a.eq(manager.voice_pool.get_active_physical_count(), 1, "y ocupa una voz")

	# Y cambiarlo mientras algo suena no deja el reproductor viejo sonando.
	manager.set_max_physical_voices(8)
	a.eq(manager.voice_pool.get_active_physical_count(), 0,
		"el pool nuevo empieza sin voces ocupadas")
	a.ok(await probe.await_silence(tree),
		"y las voces del pool viejo no siguen sonando huerfanas")

	manager.stop_all()
	probe.teardown()
	tree.root.remove_child(manager)
	manager.free()
	return a


## stop_all() tiene que PARAR de verdad, incluido un bucle infinito.
##
## Observacion 29: EventInstance.stop() pone assigned_channel_id = -1 sin pasar por
## virtualize(), y stop_all() solo llamaba a stop() y limpiaba la lista. El canal
## seguia ocupado, el reproductor seguia sonando -para siempre si el evento era un
## loop- y el Callable de la senal finished retenia la instancia.
##
## Importa para las demos: cambiar de escena desde el hub llama a stop_all() sobre
## cientos de ambientes en bucle.
static func run_stop_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("stop_all")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	# Un evento en BUCLE: es el caso que no se paraba nunca.
	var loop_stream := AudioSynthesizerClass.create_tone(440.0, 0.4, 0.8, false)
	var def = AudioEventDefClass.new(&"EndlessTone", loop_stream)
	def.is_looping = true
	def.stream_length = 0.4
	def.target_bus = probe.bus_name()
	manager.register_event_definition(def)

	manager.post_event(&"EndlessTone", null)
	probe.drain()
	var peak_playing: float = await probe.measure_peak_over_frames(tree, 30)
	a.gt(peak_playing, 0.001, "el evento en bucle suena")
	a.eq(manager.voice_pool.get_active_physical_count(), 1, "y ocupa una voz fisica")

	manager.stop_all()
	a.eq(manager.active_instances.size(), 0, "stop_all vacia la lista de instancias")
	a.eq(manager.voice_pool.get_active_physical_count(), 0,
		"y libera el canal fisico, que antes se quedaba ocupado")
	# La asercion que importa: el bus se calla. Contar frames no serviria, porque en
	# headless el bucle corre a maxima velocidad.
	a.ok(await probe.await_silence(tree), "tras stop_all el bus queda en silencio")

	probe.teardown()
	tree.root.remove_child(manager)
	manager.free()
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

## Una voz dentro de una sala debe producir energia medible en el bus de reverb de
## esa sala. Es la asercion que demuestra que el reverb por sala existe de verdad,
## en lugar de ser un ConvolutionReverbNode desconectado calculando 512 taps que
## nadie reproducia.
static func run_room_reverb_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("room_reverb")

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	# Una sala grande y reflectante, con su colisionador para que se detecten sus
	# dimensiones.
	var room = OpenDouRoom3DClass.new()
	room.room_name = &"NaveIndustrial"
	room.material_preset = "Metal"
	room.reverb_send_amount = 1.0
	room.reverb_uniformity = 1.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 12.0, 30.0)
	shape.shape = box
	room.add_child(shape)
	tree.root.add_child(room)
	await tree.process_frame
	await tree.physics_frame

	var bus: StringName = room.get_assigned_reverb_bus()
	a.ok(not String(bus).is_empty(), "la sala tiene un bus de reverb asignado")
	# La trampa: si el bus no existiera, Godot habria coaccionado el nombre a
	# Master sin avisar y el reverb de la sala se iria al bus maestro.
	a.ok(String(bus) != "Master", "el nombre del bus no quedo coaccionado a Master")
	a.ok(room.reverb_bus_enabled, "el reverb del Area3D quedo activado")
	a.eq(String(room.reverb_bus_name), String(bus), "Area3D conserva el nombre asignado")

	# Sonda enganchada al bus de reverb de la sala.
	var probe = OpenDouAudioProbeClass.new()
	a.ok(probe.attach_to_existing_bus(bus, 2.0), "la sonda se engancha al bus de reverb")

	# Hace falta un oyente: un AudioStreamPlayer3D sin Camera3D ni AudioListener3D
	# activos no emite nada, porque no tiene contra que calcular atenuacion ni
	# paneo. Es la diferencia entre este test y los de voces no espaciales.
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.global_position = Vector3(0.0, 0.0, 5.0)
	cam.make_current()
	await tree.process_frame

	# Un emisor dentro de la sala, con area_mask 1 para que el reverb nativo de
	# Area3D lo alcance.
	var emitter := AudioStreamPlayer3D.new()
	emitter.stream = AudioSynthesizerClass.create_tone(440.0, 4.0, 0.9, false)
	emitter.area_mask = 1
	emitter.unit_size = 60.0
	tree.root.add_child(emitter)
	await tree.process_frame
	emitter.global_position = Vector3.ZERO
	await tree.physics_frame
	await tree.physics_frame
	emitter.play()

	probe.drain()
	var peak: float = await probe.measure_peak_over_frames(tree, 60)
	a.gt(peak, 0.001, "la voz dentro de la sala produce energia en su bus de reverb")

	emitter.stop()
	emitter.stream = null
	probe.teardown()
	tree.root.remove_child(emitter)
	emitter.free()
	tree.root.remove_child(room)
	room.free()
	# clear_current() antes de liberar: un make_current() deja al viewport
	# referenciando la camara y el trinquete de fugas la detecta.
	cam.clear_current()
	tree.root.remove_child(cam)
	cam.free()
	manager.free()
	return a

## Un evento cuyo stream viene de un banco debe sonar.
##
## Es la asercion que demuestra que el pipeline ODBK produce audio: antes el banco
## se leia bien y sus bytes no llegaban a ninguna salida.
static func run_bank_event_audio_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("bank_event_audio")

	# Un banco con un tono sostenido, empaquetado desde sus bytes PCM16.
	var tone := AudioSynthesizerClass.create_tone(440.0, 2.0, 0.8, false)
	var bank_path := "user://test_event_bank.bnk"
	var entries: Dictionary = {
		301: {
			"name": &"TonoDeBanco", "is_prefetch": true,
			"sample_rate": 44100, "channels": 1, "data": tone.data
		},
	}
	a.ok(SoundBankBuilderClass.build_bank(bank_path, entries), "el banco del evento se compila")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	a.ok(manager.load_bank(bank_path, &"event_bank") != null, "el manager carga el banco")
	var bank_stream = manager.get_bank_stream(&"event_bank", 301)
	a.ok(bank_stream is AudioStreamWAV, "get_bank_stream devuelve un AudioStreamWAV")

	var def = AudioEventDefClass.new(&"DesdeBanco", bank_stream)
	def.target_bus = probe.bus_name()
	def.stream_length = float(bank_stream.get_length()) if bank_stream != null else 0.0
	def.is_looping = true
	manager.register_event_definition(def)
	manager.post_event(&"DesdeBanco", null)

	probe.drain()
	var peak: float = await probe.measure_peak_over_frames(tree, 40)
	a.gt(peak, 0.01, "un evento cuyo stream viene de un banco suena")

	manager.stop_all()
	manager.unload_bank(&"event_bank")
	probe.teardown()
	manager.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bank_path))
	return a

## HDR debe atenuar de verdad una voz debil cuando suena una fuerte.
static func run_hdr_ducking_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("hdr_ducking")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)
	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	var tone := AudioSynthesizerClass.create_tone(440.0, 4.0, 0.6, false)

	# Control: una voz debil sola, con HDR activo.
	var quiet_def = AudioEventDefClass.new(&"VozDebil", tone)
	quiet_def.target_bus = probe.bus_name()
	quiet_def.stream_length = float(tone.get_length())
	quiet_def.is_looping = true
	# -30 dB esta DENTRO de la ventana por defecto, que va de 0 a -40: la voz suena
	# atenuada pero audible. Elegir -50 la habria dejado por debajo del suelo y
	# ducked incluso estando sola, que es comportamiento HDR correcto pero no
	# prueba nada sobre el ducking.
	quiet_def.hdr_loudness_db = -30.0
	manager.register_event_definition(quiet_def)

	manager.post_event(&"VozDebil", null)
	probe.drain()
	var alone: float = await probe.measure_peak_over_frames(tree, 30)
	a.gt(alone, 0.001, "la voz debil suena cuando esta sola")

	# Ahora entra una voz fuerte, enrutada a Master y NO al bus de sonda.
	#
	# Ese enrutado es lo que hace valida la medida: la voz fuerte sube la ventana
	# HDR pero no aporta senal al bus que se mide, asi que el pico del bus sigue
	# siendo el de la voz debil y solo. Si las dos fueran al mismo bus, la senal de
	# la fuerte enmascararia la atenuacion de la debil y la asercion no probaria
	# nada.
	var loud_def = AudioEventDefClass.new(&"VozFuerte", tone)
	loud_def.target_bus = &"Master"
	loud_def.stream_length = float(tone.get_length())
	loud_def.is_looping = true
	loud_def.hdr_loudness_db = 18.0
	manager.register_event_definition(loud_def)
	manager.post_event(&"VozFuerte", null)

	# Con la fuerte en +18 el suelo de la ventana pasa a -22, asi que la voz de -30
	# cae por debajo y se atenua al minimo.
	# La ventana sube con el ataque del motor; se le dan frames para llegar.
	for _f in range(40):
		await tree.process_frame
	probe.drain()
	var with_loud: float = await probe.measure_peak_over_frames(tree, 30)
	a.lt(with_loud, alone * 0.5, "la voz debil se atenua cuando suena la fuerte")

	# Con HDR desactivado la contribucion desaparece.
	manager.hdr_enabled = false
	for _f in range(40):
		await tree.process_frame
	probe.drain()
	var disabled: float = await probe.measure_peak_over_frames(tree, 30)
	a.gt(disabled, with_loud, "al desactivar HDR la voz debil recupera nivel")

	manager.stop_all()
	probe.teardown()
	manager.free()
	return a
