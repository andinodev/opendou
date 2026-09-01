class_name VoicePoolManager
extends RefCounted

## Manages fixed hardware audio channels, deterministic voice stealing, zero-cost virtual tracking, and bus routing.

const PhysicalVoiceChannelClass = preload("res://addons/opendou/runtime/physical_voice_channel.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")

var max_physical_voices: int = 64
var channels: Array[PhysicalVoiceChannel] = []

# Anti-thrashing hysteresis bonus for currently physical voices
var hysteresis_bonus: float = 1.05
var min_audibility_threshold: float = 0.001

## Pool de reproductores nativos para las voces anonimas. Sin el, solo pueden
## sonar las voces cuyo emisor es un nodo OpenDouEventPlayer*.
var player_pool: OpenDouNativePlayerPool = null

## Inyecta el pool de reproductores nativos.
func set_player_pool(pool: OpenDouNativePlayerPool) -> void:
	player_pool = pool

func _init(p_max_voices: int = 64) -> void:
	max_physical_voices = max(1, p_max_voices)
	channels = []
	for i in range(max_physical_voices):
		channels.append(PhysicalVoiceChannelClass.new(i))

## Finds an available physical channel or returns -1 if all are occupied.
func find_free_channel() -> int:
	for i in range(channels.size()):
		if not channels[i].is_busy:
			return i
	return -1

## Resolves voice stealing and assigns hardware channels to highest priority instances.
func resolve_voice_stealing(active_instances: Array[EventInstance], listener_pos: Vector3, delta: float) -> void:
	# 1. Update channel fade states
	process_channel_fades(delta)
		
	# 2. Calculate dynamic weights and advance virtual times
	var candidates: Array[EventInstance] = []
	for instance in active_instances:
		if not instance or not instance.is_playing():
			continue
			
		instance.advance_virtual_time(delta)
		
		# If instance finished naturally during virtual time, skip
		if not instance.is_playing():
			continue
			
		var weight: float = instance.calculate_dynamic_weight(listener_pos)
		
		# Apply hysteresis bonus to already physical voices
		if instance.voice_state == EventInstanceClass.VoiceState.STATE_PHYSICAL:
			weight *= hysteresis_bonus
			
		instance.current_weight = weight
		candidates.append(instance)
		
	# 3. Sort candidates from HIGHEST to LOWEST weight
	candidates.sort_custom(func(a: EventInstance, b: EventInstance) -> bool:
		return a.current_weight > b.current_weight
	)
	
	# 4. Allocate top candidates to physical channels, virtualize the rest
	for i in range(candidates.size()):
		var instance: EventInstance = candidates[i]
		
		if i < max_physical_voices and instance.current_weight >= min_audibility_threshold:
			if instance.voice_state == EventInstanceClass.VoiceState.STATE_VIRTUAL:
				devirtualize(instance)
		else:
			if instance.voice_state == EventInstanceClass.VoiceState.STATE_PHYSICAL:
				virtualize(instance)

## Pasa una instancia a virtual y libera su canal y su reproductor.
func virtualize(instance: EventInstance) -> void:
	if not instance:
		return

	if instance.assigned_channel_id >= 0 and instance.assigned_channel_id < channels.size():
		var ch: PhysicalVoiceChannel = channels[instance.assigned_channel_id]
		var player: Node = ch.get_player()
		var was_owned: bool = ch.owned_by_node
		# Desconectar antes de detener: un stop() provocado por nosotros no es un
		# fin natural de stream y no debe cerrar la instancia.
		if player != null and player.has_signal("finished"):
			var cb := Callable(instance, "notify_stream_finished")
			if player.is_connected("finished", cb):
				player.disconnect("finished", cb)
		ch.stop_immediate()
		ch.bind(null, false)
		# Los reproductores anonimos vuelven al pool; los de un nodo se quedan
		# donde estan, porque no son nuestros.
		if not was_owned and player != null and player_pool != null:
			player_pool.release(player)
		instance.assigned_channel_id = -1

	if instance.virtualization_mode == AudioEventDefClass.VirtualizationMode.VIRTUAL_KILL_VOICE:
		instance.voice_state = EventInstanceClass.VoiceState.STATE_KILLED
	else:
		instance.voice_state = EventInstanceClass.VoiceState.STATE_VIRTUAL

## Pasa una instancia de virtual a fisica, consiguiendole un reproductor real.
##
## El reproductor puede venir del nodo emisor (si es un OpenDouEventPlayer*, su
## propio reproductor ES la voz) o del pool anonimo. Antes este metodo solo
## rellenaba campos de un objeto contable que no emitia nada.
func devirtualize(instance: EventInstance) -> void:
	if not instance:
		return

	var free_ch_id: int = find_free_channel()
	if free_ch_id < 0:
		return

	var player: Node = instance.get_bound_player()
	var owned_by_node: bool = player != null

	# Un reproductor de nodo solo puede hospedar UNA voz: es un unico
	# AudioStreamPlayer. Si ya hay un canal ocupado con este mismo reproductor, esa voz
	# queda superada y hay que virtualizarla ANTES.
	#
	# Sin esto quedaban dos canales apuntando al mismo reproductor, y cuando el primero
	# terminaba su stop_immediate() paraba el audio por debajo del segundo: la segunda
	# pisada del mismo emisor se quedaba muda.
	if owned_by_node:
		for ch_existing in channels:
			if not ch_existing.is_busy or ch_existing.get_player() != player:
				continue
			var previous = ch_existing.assigned_instance_ref.get_ref() if ch_existing.assigned_instance_ref != null else null
			if previous != null and previous != instance:
				virtualize(previous)

	if player == null:
		if player_pool == null:
			return
		player = player_pool.acquire(_kind_for_instance(instance))
		if player == null:
			return

	# El contexto es obligatorio: sin el, AudioSwitchContainer resuelve a su rama por
	# defecto y AudioBlendContainer ve RTPC = 0.0.
	var voices = instance.definition.resolve_voices(instance.playback_context) if instance.definition else []
	var stream = voices[0].stream if not voices.is_empty() else (instance.definition.base_stream if instance.definition else null)
	if stream == null:
		if not owned_by_node and player_pool != null:
			player_pool.release(player)
		return

	var start_offset: float = 0.0
	if instance.virtualization_mode == AudioEventDefClass.VirtualizationMode.VIRTUAL_ELAPSED_TIME:
		start_offset = instance.logical_playback_position
		var length: float = instance.definition.stream_length if instance.definition else 0.0
		if length <= 0.0:
			length = float(stream.get_length())
		# Sin el modulo, un ambiente virtualizado tres minutos intentaria arrancar
		# en el segundo 180 de un loop de cuatro segundos y no sonaria.
		if instance.definition != null and instance.definition.is_looping and length > 0.0:
			start_offset = fmod(start_offset, length)
		elif length > 0.0:
			start_offset = clampf(start_offset, 0.0, maxf(0.0, length - 0.001))

	instance.assigned_channel_id = free_ch_id
	instance.voice_state = EventInstanceClass.VoiceState.STATE_PHYSICAL

	var ch: PhysicalVoiceChannel = channels[free_ch_id]
	ch.assigned_instance_ref = weakref(instance)
	ch.bind(player, owned_by_node)

	# La senal `finished` es la unica fuente fiable del fin de reproduccion. Va en
	# ONE_SHOT para que no se acumulen conexiones al virtualizar y desvirtualizar
	# la misma instancia repetidamente.
	if player.has_signal("finished"):
		var cb := Callable(instance, "notify_stream_finished")
		if not player.is_connected("finished", cb):
			player.connect("finished", cb, CONNECT_ONE_SHOT)

	var bus_name: StringName = instance.definition.target_bus if instance.definition else &"Master"
	ch.play_stream(stream, start_offset, instance.calculated_volume_db, instance.calculated_pitch_scale, bus_name)

## Returns the number of active physical voices.
func get_active_physical_count() -> int:
	var count: int = 0
	for ch in channels:
		if ch.is_busy:
			count += 1
	return count

## Returns the number of active virtual voices.
##
## El parametro va SIN tipar a proposito: AudioTelemetryCollector.collect_snapshot()
## reenvia aqui un Array generico mediante call(), y exigir un array tipado
## provocaba un error que abortaba la recoleccion entera y la hacia devolver null,
## de donde salia en cascada el acceso a physical_voices sobre Nil.
func get_active_virtual_count(active_instances: Array) -> int:
	var count: int = 0
	for inst in active_instances:
		if inst and inst.voice_state == EventInstanceClass.VoiceState.STATE_VIRTUAL:
			count += 1
	return count

## Procesa los fades de todos los canales ocupados.
func process_channel_fades(delta: float) -> void:
	for ch in channels:
		ch.process_fade(delta)

## Canal por indice, o null si el indice no es valido.
func get_channel(channel_id: int) -> PhysicalVoiceChannel:
	if channel_id < 0 or channel_id >= channels.size():
		return null
	return channels[channel_id]

## Tipo de reproductor que necesita una instancia: con posicion espacial suena en
## 3D, sin ella no espacial.
func _kind_for_instance(instance: EventInstance) -> int:
	if instance.has_spatial_position:
		return NativePlayerPoolClass.PlayerKind.SPATIAL_3D
	return NativePlayerPoolClass.PlayerKind.NON_SPATIAL
