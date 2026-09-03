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
	release_sends()
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
	install_send_input(StringName(bus_name))
	return StringName(bus_name)

const MARK_CONV: String = "OpenDou_ConvReverb"
const SEND_PLAYER_PREFIX: String = "OpenDou_Send_"
## Nodo que hospeda los reproductores de envio (lo fija el manager). Sin el, no hay envio.
var host: Node = null
## Envios por bus, compartidos por todos los pools del proceso (los buses sobreviven al manager).
static var _bus_send_ids: Dictionary = {}
var _send_players: Dictionary = {}

## Envio propio (Fase 15): id del acumulador nativo del bus, -1 si no lo hay.
func send_id_for(bus: StringName) -> int:
	return int(_bus_send_ids.get(bus, -1))

func has_send_input(bus: StringName) -> bool:
	return send_id_for(bus) >= 0

## Fase 15: para y libera los reproductores de envio de este pool y sus acumuladores nativos.
## Lo llama el manager al salir del arbol: un reproductor que siga sonando al cerrar deja su
## playback vivo en el AudioServer y el trinquete de fugas lo cuenta.
func release_sends() -> void:
	for b in _send_players:
		var p = _send_players[b]
		if is_instance_valid(p):
			p.stop()
			p.stream = null
			if p.get_parent() != null:
				p.get_parent().remove_child(p)
			p.free()
		if ClassDB.class_exists("OpenDouSendBus") and _bus_send_ids.has(b):
			ClassDB.class_call_static("OpenDouSendBus", "release", int(_bus_send_ids[b]))
			_bus_send_ids.erase(b)
	_send_players.clear()

## Un AudioStreamPlayer en el bus de reverb reproduce OpenDouSendStream: vuelca el envio acumulado
## y mantiene el bus activo (un bus sin reproductores no llega a Master). false sin extension.
func install_send_input(bus: StringName) -> bool:
	if not ClassDB.class_exists("OpenDouSendStream") or not ClassDB.class_exists("OpenDouSendBus"):
		return false
	if has_send_input(bus) and _send_players.has(bus) and is_instance_valid(_send_players[bus]):
		return true
	if host == null or not host.is_inside_tree() or AudioServer.get_bus_index(String(bus)) < 0:
		return false
	var id: int = send_id_for(bus)
	if id < 0:
		id = int(ClassDB.class_call_static("OpenDouSendBus", "create"))
		if id < 0:
			return false
		_bus_send_ids[bus] = id
	var stream = ClassDB.instantiate("OpenDouSendStream")
	stream.set("send_id", id)
	var player := AudioStreamPlayer.new()
	player.name = SEND_PLAYER_PREFIX + String(bus)
	player.stream = stream
	player.bus = String(bus)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(player)
	player.play()
	_send_players[bus] = player
	return true

## Sustituye el reverb del bus por la convolucion nativa de Steam Audio (Fase 13), alimentada
## por la fuente de oyente `room_handle`. Devuelve false sin extension.
func install_convolution(bus: StringName, room_handle: int, wet: float) -> bool:
	if not ClassDB.class_exists("OpenDouConvolutionReverb"):
		return false
	var idx: int = AudioServer.get_bus_index(String(bus))
	if idx < 0:
		return false
	var fx = null
	for e in range(AudioServer.get_bus_effect_count(idx)):
		var cand := AudioServer.get_bus_effect(idx, e)
		if cand != null and cand.resource_name == MARK_CONV:
			fx = cand
	if fx == null:
		for e in range(AudioServer.get_bus_effect_count(idx) - 1, -1, -1):
			if AudioServer.get_bus_effect(idx, e) is AudioEffectReverb:
				AudioServer.remove_bus_effect(idx, e)
		fx = ClassDB.instantiate("OpenDouConvolutionReverb")
		fx.resource_name = MARK_CONV
		AudioServer.add_bus_effect(idx, fx, 0)
	# Con entrada de envio el bus solo lleva el envio: nada de seco (la voz va por su target_bus).
	fx.dry = 0.0 if has_send_input(bus) else 1.0
	fx.wet = clampf(wet, 0.0, 1.0)
	fx.room_handle = room_handle
	return true

## Vuelve al AudioEffectReverb de Godot en el bus (fallback, o al salir de CONVOLUTION).
func install_sabine(bus: StringName, rt60: float, absorption: float) -> void:
	var idx: int = AudioServer.get_bus_index(String(bus))
	if idx < 0:
		return
	for e in range(AudioServer.get_bus_effect_count(idx) - 1, -1, -1):
		var cand := AudioServer.get_bus_effect(idx, e)
		if cand != null and (cand.resource_name == MARK_CONV or cand is AudioEffectReverb):
			AudioServer.remove_bus_effect(idx, e)
	AudioServer.add_bus_effect(idx, _make_reverb(rt60, absorption), 0)

## Cambia la mezcla humeda del efecto de convolucion del bus, si lo hay.
func set_convolution_wet(bus: StringName, wet: float) -> void:
	var idx: int = AudioServer.get_bus_index(String(bus))
	if idx < 0:
		return
	for e in range(AudioServer.get_bus_effect_count(idx)):
		var cand := AudioServer.get_bus_effect(idx, e)
		if cand != null and cand.resource_name == MARK_CONV:
			cand.wet = clampf(wet, 0.0, 1.0)

func has_convolution(bus: StringName) -> bool:
	var idx: int = AudioServer.get_bus_index(String(bus))
	if idx < 0:
		return false
	for e in range(AudioServer.get_bus_effect_count(idx)):
		var cand := AudioServer.get_bus_effect(idx, e)
		if cand != null and cand.resource_name == MARK_CONV:
			return true
	return false

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
