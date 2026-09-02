class_name OpenDouReverbBusPool
extends RefCounted

## Agrupa salas por perfil acustico y les asigna buses de reverb nativos de Godot.
##
## Se comparten los buses en lugar de dar uno a cada sala porque Godot procesa
## TODOS los buses cada frame: con un bus por sala, cien salas cuestan cien
## reverbs. Agrupando por RT60 en escalones, cien salas siguen costando ocho.
##
## Los buses se crean una vez y NO se destruyen durante la sesion:
## AudioServer.remove_bus() desplaza los indices de los buses posteriores, y eso
## corrompe cualquier referencia por indice que haya viva en el motor.
## release_all() existe solo para los tests, y quita los buses desde el final.

const BUS_NAME_PREFIX: String = "OpenDouReverb_"

## RT60 que satura room_size a 1.0.
##
## calculate_sabine_reverb() ya limita el RT60 a 12 s y los interiores habituales
## caen entre 0,3 y 3 s: 6 s deja margen para naves y cuevas sin aplastar el
## rango util.
const RT60_REFERENCE_SEC: float = 6.0

## Numero maximo de buses de reverb gestionados.
var max_buses: int = 8

## Ancho de cada escalon de RT60, en segundos.
var rt60_step_sec: float = 0.3

var _tier_to_bus: Dictionary = {}

## Ajusta el techo de buses y la resolucion de los escalones.
func configure(p_max_buses: int = 8, p_rt60_step_sec: float = 0.3) -> void:
	max_buses = maxi(1, p_max_buses)
	rt60_step_sec = maxf(0.05, p_rt60_step_sec)

## Escalon al que pertenece un RT60.
func tier_for_rt60(rt60: float) -> int:
	return int(round(maxf(0.0, rt60) / rt60_step_sec))

## Numero de buses que este pool ha creado.
func managed_bus_count() -> int:
	return _tier_to_bus.size()

## Nombre del bus de reverb que corresponde a un RT60, creandolo si hace falta.
##
## Alcanzado el techo, devuelve el bus del escalon existente mas proximo: es
## preferible un reverb ligeramente distinto a un bus mas que procesar cada frame.
func bus_for_rt60(rt60: float, absorption: float) -> StringName:
	var tier: int = tier_for_rt60(rt60)
	if _tier_to_bus.has(tier):
		return _tier_to_bus[tier]

	if _tier_to_bus.size() >= max_buses:
		return _nearest_existing_bus(tier)

	var bus_name: StringName = _create_bus(tier, rt60, absorption)
	if bus_name.is_empty():
		push_error("[OpenDou] no se pudo crear el bus de reverb del escalon %d" % tier)
		return &"Master"
	_tier_to_bus[tier] = bus_name
	return bus_name

## Quita los buses gestionados. Solo para tests.
##
## Va desde el final hacia atras porque remove_bus() desplaza los indices
## posteriores: quitar de delante hacia atras invalidaria los indices restantes.
func release_all() -> void:
	var indices: Array[int] = []
	for n in _tier_to_bus.values():
		var idx: int = AudioServer.get_bus_index(String(n))
		if idx > 0:
			indices.append(idx)
	indices.sort()
	indices.reverse()
	for idx in indices:
		if idx > 0 and idx < AudioServer.bus_count:
			AudioServer.remove_bus(idx)
	_tier_to_bus.clear()

func _nearest_existing_bus(tier: int) -> StringName:
	var best_tier: int = -1
	var best_distance: int = 1 << 30
	for existing in _tier_to_bus.keys():
		var d: int = absi(int(existing) - tier)
		if d < best_distance:
			best_distance = d
			best_tier = int(existing)
	if best_tier < 0:
		return &"Master"
	return _tier_to_bus[best_tier]

func _create_bus(tier: int, rt60: float, absorption: float) -> StringName:
	var bus_name: String = "%s%d" % [BUS_NAME_PREFIX, tier]

	# Si ya existe con ese nombre (por ejemplo tras recargar), se reutiliza en
	# lugar de duplicarlo.
	if AudioServer.get_bus_index(bus_name) != -1:
		return StringName(bus_name)

	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	AudioServer.add_bus_effect(idx, _make_reverb(rt60, absorption), 0)
	return StringName(bus_name)

## Configura un AudioEffectReverb a partir del RT60 y la absorcion.
##
## AudioEffectReverb NO expone RT60: solo room_size, damping, spread, hipass,
## predelay y las mezclas seca y humeda. El mapeo es una APROXIMACION CALIBRADA,
## no una derivacion fisica, y los coeficientes estan en constantes para que se
## puedan ajustar de oido sin tocar la logica.
func _make_reverb(rt60: float, absorption: float) -> AudioEffectReverb:
	var reverb := AudioEffectReverb.new()
	reverb.room_size = clampf(rt60 / RT60_REFERENCE_SEC, 0.05, 1.0)
	reverb.damping = clampf(absorption, 0.0, 1.0)
	# El bus es exclusivamente de reverb: la senal directa llega por el bus del
	# propio emisor, asi que aqui no hay componente seca que mezclar.
	reverb.wet = 1.0
	reverb.dry = 0.0
	return reverb
