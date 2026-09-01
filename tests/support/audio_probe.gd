class_name OpenDouAudioProbe
extends RefCounted

## Sonda de audio para aserciones reales en modo headless.
## Crea un bus dedicado con un AudioEffectCapture y mide el pico de la senal que
## realmente llega a la mezcla.
##
## Verificado en Godot 4.7.2 con --headless: el driver Dummy SI mezcla, y la
## captura devuelve el pico correcto (0.8000 para un seno de amplitud 0.8).

const BUS_NAME: StringName = &"OpenDouTestProbe"

var bus_index: int = -1

## Verdadero si el bus lo creo esta sonda; falso si solo se engancho a uno ajeno.
var _owns_bus: bool = false

var _capture: AudioEffectCapture = null

## Crea el bus de sonda con la captura insertada. Devuelve el indice del bus.
func setup(buffer_length_sec: float = 2.0) -> int:
	teardown()
	bus_index = AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, String(BUS_NAME))
	AudioServer.set_bus_send(bus_index, "Master")
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = buffer_length_sec
	AudioServer.add_bus_effect(bus_index, _capture, 0)
	_owns_bus = true
	return bus_index

## Inserta una captura en un bus que YA existe, sin crear ninguno.
##
## Sirve para medir cuanta energia llega a un bus que gestiona otro, por ejemplo
## el bus de reverb que el pool asigno a una sala. Devuelve false si no existe.
func attach_to_existing_bus(target_bus: StringName, buffer_length_sec: float = 2.0) -> bool:
	teardown()
	var idx: int = AudioServer.get_bus_index(String(target_bus))
	if idx == -1:
		return false
	bus_index = idx
	_owns_bus = false
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = buffer_length_sec
	# Al final de la cadena: interesa medir la salida del bus, ya procesada por el
	# reverb, no su entrada.
	AudioServer.add_bus_effect(idx, _capture, AudioServer.get_bus_effect_count(idx))
	return true

## Nombre del bus al que deben enrutarse los reproductores bajo prueba.
func bus_name() -> StringName:
	if not _owns_bus and bus_index >= 0 and bus_index < AudioServer.bus_count:
		return StringName(AudioServer.get_bus_name(bus_index))
	return BUS_NAME

## Vacia la captura sin medir. Usalo antes de empezar una medicion para descartar
## la senal previa.
func drain() -> void:
	if _capture == null:
		return
	var avail: int = _capture.get_frames_available()
	if avail > 0:
		_capture.get_buffer(avail)

## Drena TODO lo disponible y devuelve el pico absoluto de ese lote.
##
## Drenar por completo es obligatorio: get_buffer() devuelve los frames MAS
## ANTIGUOS, asi que leer solo un trozo devolveria el silencio anterior al
## arranque del sonido y daria un falso 0.
func drain_peak() -> float:
	if _capture == null:
		return 0.0
	var avail: int = _capture.get_frames_available()
	if avail <= 0:
		return 0.0
	var peak: float = 0.0
	for v in _capture.get_buffer(avail):
		peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
	return peak

## Avanza n frames drenando cada uno, y devuelve el pico global observado.
## Es una corrutina: hay que hacerle await.
func measure_peak_over_frames(tree: SceneTree, frames: int = 12) -> float:
	var peak: float = 0.0
	for _i in range(maxi(1, frames)):
		await tree.process_frame
		peak = maxf(peak, drain_peak())
	return peak

## Igual que measure_peak_over_frames pero en dBFS. Devuelve -INF en silencio.
func measure_peak_db_over_frames(tree: SceneTree, frames: int = 12) -> float:
	var peak: float = await measure_peak_over_frames(tree, frames)
	if peak <= 0.0:
		return -INF
	return linear_to_db(peak)

## Espera a que el bus quede en silencio. Devuelve true si lo consiguio dentro
## del limite de iteraciones.
##
## Contar frames fijos NO sirve para afirmar silencio: en headless el bucle
## principal corre a maxima velocidad, asi que el numero de frames no es
## proporcional al tiempo de audio y la cola del bus tarda un numero
## impredecible de frames en vaciarse. Un test que cuente frames pasa o falla
## por suerte. Aqui se drena hasta ver varias lecturas consecutivas por debajo
## del umbral, que es la condicion que de verdad se quiere afirmar.
func await_silence(tree: SceneTree, threshold: float = 0.01, consecutive: int = 4, max_iterations: int = 2000) -> bool:
	var quiet_streak: int = 0
	for _i in range(maxi(1, max_iterations)):
		await tree.process_frame
		if drain_peak() < threshold:
			quiet_streak += 1
			if quiet_streak >= consecutive:
				return true
		else:
			quiet_streak = 0
	return false

## Elimina la captura, y el bus solo si lo creo esta sonda.
func teardown() -> void:
	if bus_index >= 0 and bus_index < AudioServer.bus_count:
		if _owns_bus:
			AudioServer.remove_bus(bus_index)
		elif _capture != null:
			# Quitar solo nuestra captura: el bus es de otro.
			for i in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
				if AudioServer.get_bus_effect(bus_index, i) == _capture:
					AudioServer.remove_bus_effect(bus_index, i)
					break
	bus_index = -1
	_owns_bus = false
	_capture = null
