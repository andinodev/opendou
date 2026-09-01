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

## Punto de entrada de la suite asincrona de audio.
##
## Son metodos de instancia y sin anotacion de tipo de retorno a proposito:
## GDScript no resuelve el tipo de retorno de una funcion estatica que contiene
## await cuando se la invoca desde otro script, y falla al compilar.
func run_all_async(tree: SceneTree):
	var a := OpenDouAssertClass.new()
	a.absorb(await run_probe_selftest_async(tree))
	a.absorb(await run_channel_audio_async(tree))
	return a

## La sonda debe medir una senal conocida. Si esto falla, ninguna otra asercion
## de audio de la suite es fiable, asi que se comprueba antes que nada.
##
## Se usa un AudioStreamWAV y no un AudioStreamGenerator a proposito: el servidor
## de audio retiene el AudioStreamGeneratorPlayback incluso despues de stop(), y
## el trinquete de fugas lo detecta como un objeto filtrado. Un WAV real ademas
## se parece mas a como suenan las voces de verdad.
func run_probe_selftest_async(tree: SceneTree):
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
func run_channel_audio_async(tree: SceneTree):
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
