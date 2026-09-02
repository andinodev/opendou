class_name PhysicalVoiceChannel
extends RefCounted

## Un canal de voz fisica: envoltorio delgado sobre un reproductor nativo de Godot.
##
## Antes este objeto solo llevaba la contabilidad: play_stream() almacenaba el
## stream y activaba banderas, y nunca emitia nada. Ahora es dueno de la
## reproduccion: play_stream() invoca play() de verdad sobre el reproductor, y
## apply() empuja los valores calculados una vez por frame.
##
## El reproductor puede ser de dos procedencias:
##  - propiedad de un nodo OpenDouEventPlayer* (owned_by_node = true), en cuyo
##    caso NO se toca su transform: lo posiciona el juego.
##  - anonimo del OpenDouNativePlayerPool (owned_by_node = false), reposicionado
##    cada frame desde la posicion del emisor.

const DistanceModelClass = preload("res://addons/opendou/runtime/spatial/distance_model.gd")

var channel_id: int = -1
var is_busy: bool = false
var assigned_instance_ref: WeakRef = null

## Verdadero si el reproductor pertenece a un nodo del usuario y no al pool.
var owned_by_node: bool = false

## Nodo 3D cuya posicion global es la de la voz cada frame, sin ser su reproductor. Es
## como suenan los OpenDouEventPlayer3D en steam_audio: el nodo dice DONDE, el pool dice
## COMO. Null en las voces anonimas y en el backend godot.
var position_node_ref: WeakRef = null

# Bus de mezcla destino en el AudioServer de Godot.
var target_bus: StringName = &"Master"

# Micro-fades para evitar chasquidos al robar o detener voces.
var is_fading_out: bool = false
var is_fading_in: bool = false
var fade_duration_sec: float = 0.015
var fade_timer: float = 0.0
var current_fade_gain: float = 1.0

var current_stream: AudioStream = null
var current_volume_db: float = 0.0
var current_pitch: float = 1.0
var playback_start_offset: float = 0.0

var _player: Node = null

func _init(p_channel_id: int = -1) -> void:
	channel_id = p_channel_id
	is_busy = false
	target_bus = &"Master"

## Vincula el canal a un reproductor nativo concreto.
func bind(player: Node, p_owned_by_node: bool) -> void:
	_player = player
	owned_by_node = p_owned_by_node
	position_node_ref = null

## Nodo que aporta la posicion de la voz, o null si no hay o dejo de ser valido.
func get_position_node() -> Node3D:
	if position_node_ref == null:
		return null
	var n = position_node_ref.get_ref()
	if n != null and is_instance_valid(n) and n is Node3D and n.is_inside_tree():
		return n
	return null

## Reproductor vinculado, o null si no hay o dejo de ser valido.
func get_player() -> Node:
	if _player != null and is_instance_valid(_player):
		return _player
	return null

## Fija el bus de mezcla destino.
func set_bus(p_bus: StringName) -> void:
	target_bus = p_bus if not p_bus.is_empty() else &"Master"

## Asigna el stream al reproductor vinculado y arranca la reproduccion real.
func play_stream(stream: AudioStream, start_offset: float = 0.0, volume_db: float = 0.0, pitch: float = 1.0, bus_name: StringName = &"Master") -> void:
	current_stream = stream
	playback_start_offset = start_offset
	current_volume_db = volume_db
	current_pitch = pitch
	set_bus(bus_name)

	is_busy = true
	is_fading_out = false
	is_fading_in = true
	fade_duration_sec = 0.010
	fade_timer = 0.0
	current_fade_gain = 0.0

	var player := get_player()
	if player == null or stream == null:
		return
	if not player.is_inside_tree():
		return

	if _has_spatial_stream(player):
		# Backend steam_audio: el stream del reproductor es el envoltorio nativo permanente.
		player.stream.source = stream
	else:
		player.stream = stream
	if AudioServer.get_bus_index(String(target_bus)) != -1:
		player.bus = String(target_bus)
	# Se arranca con el fade en 0 y apply() sube la ganancia, asi que el volumen
	# inicial se fija en el suelo para no soltar un chasquido.
	player.volume_db = -80.0
	player.pitch_scale = clampf(pitch, 0.01, 4.0)
	player.play(maxf(0.0, start_offset))

## Empuja los valores calculados al reproductor. Se llama una vez por frame.
func apply(volume_db: float, pitch: float, cutoff_hz: float, position: Vector3) -> void:
	var player := get_player()
	if player == null or not is_busy:
		return

	# El fade anti-click es un multiplicador de amplitud: se convierte a dB y se
	# suma. Sin el suelo de 0.0001, un fade en 0 daria -INF dB.
	var gain_db: float = linear_to_db(maxf(current_fade_gain, 0.0001))
	player.volume_db = clampf(volume_db + gain_db, -80.0, 24.0)
	player.pitch_scale = clampf(pitch, 0.01, 4.0)

	if player is AudioStreamPlayer3D:
		# attenuation_filter_cutoff_hz existe SOLO en 3D. Es el LPF de oclusion
		# por voz, y lo aplica Godot en C++.
		player.attenuation_filter_cutoff_hz = clampf(cutoff_hz, 20.0, 20000.0)
		if not owned_by_node:
			player.global_position = position
	elif player is AudioStreamPlayer2D:
		# En 2D no hay filtro por voz: la oclusion llega ya como atenuacion de
		# volumen dentro de volume_db.
		if not owned_by_node:
			player.global_position = Vector2(position.x, position.y)

## Version espacial de apply(): recibe la instancia y el oyente, y decide por tipo de
## reproductor. Con AudioStreamPlayer3D (backend godot) Godot atenua y filtra por su
## cuenta; lo unico que OpenDou fija es el corte del filtro.
##
## Observacion 42: antes se escribia el corte de oclusion tal cual, y sin oclusion vale
## 20 000 Hz, lo que dejaba el shelf de distancia de Godot por encima del oido. Ahora se
## escribe el MINIMO entre el corte de oclusion y el de la instancia (5 kHz por defecto),
## asi que Godot vuelve a oscurecer con la distancia y la oclusion baja desde ahi.
func apply_spatial(instance: EventInstance, volume_db: float, pitch: float, cutoff_hz: float, listener_position: Vector3, listener_basis: Basis) -> void:
	var player := get_player()
	if player == null or not is_busy or instance == null:
		return
	var gain_db: float = linear_to_db(maxf(current_fade_gain, 0.0001))
	player.pitch_scale = clampf(pitch, 0.01, 4.0)

	if _has_spatial_stream(player):
		# Backend steam_audio: OpenDou calcula lo que Godot calculaba por su cuenta, con las
		# mismas formulas (OpenDouDistanceModel), y lo empuja al stream nativo. El anfitrion
		# es un AudioStreamPlayer3D neutralizado y su posicion solo sirve para que el Area3D
		# de la sala lo envie a su bus de reverb: va en la posicion REAL del emisor, igual que
		# el nodo en el backend godot. La direccion que se OYE sale del stream, con la
		# posicion aparente (el portal cuando el grafo gobierna).
		var s = player.stream
		var p: Vector3 = instance.current_apparent_position
		if player is Node3D and not owned_by_node:
			player.global_position = instance.emitter_position
		var distance: float = p.distance_to(listener_position)
		var v_total: float = volume_db + instance.emitter_volume_db
		player.volume_db = clampf(v_total + gain_db, -80.0, 24.0)
		s.direction = DistanceModelClass.listener_direction(p, listener_position, listener_basis)
		s.distance_gain = db_to_linear(DistanceModelClass.gain_db_for_stream(distance, instance.attenuation_model, instance.unit_size, v_total, instance.attenuation_max_distance))
		var mult: float = DistanceModelClass.multiplier(distance, instance.attenuation_model, instance.unit_size, v_total, DistanceModelClass.MAX_DB, instance.attenuation_max_distance)
		s.shelf_db = DistanceModelClass.shelf_db(mult, instance.attenuation_filter_db)
		s.shelf_cutoff_hz = instance.attenuation_filter_cutoff_hz
		s.cutoff_hz = clampf(cutoff_hz, 20.0, 20000.0)
	elif player is AudioStreamPlayer3D:
		player.volume_db = clampf(volume_db + gain_db, -80.0, 24.0)
		player.attenuation_filter_cutoff_hz = clampf(minf(cutoff_hz, instance.attenuation_filter_cutoff_hz), 20.0, 20000.0)
		if not owned_by_node:
			player.global_position = instance.current_apparent_position
	elif player is AudioStreamPlayer2D:
		player.volume_db = clampf(volume_db + gain_db, -80.0, 24.0)
		if not owned_by_node:
			player.global_position = Vector2(instance.current_apparent_position.x, instance.current_apparent_position.y)
	else:
		# Reproductor estereo plano sin stream nativo: suena centrado y sin atenuacion.
		player.volume_db = clampf(volume_db + gain_db, -80.0, 24.0)

## Corte de paso-bajo que de verdad llega al mezclador para esta voz, sea cual sea el
## backend: el del stream nativo, o el filtro de atenuacion del reproductor 3D de Godot.
func get_effective_cutoff_hz() -> float:
	var player := get_player()
	if player == null:
		return 20000.0
	if _has_spatial_stream(player):
		return player.stream.cutoff_hz
	if player is AudioStreamPlayer3D:
		return player.attenuation_filter_cutoff_hz
	return 20000.0

static func _has_spatial_stream(player: Node) -> bool:
	return (player is AudioStreamPlayer3D or player is AudioStreamPlayer) and player.stream != null and player.stream.get_class() == "OpenDouSpatialStream"

## Inicia un micro-fade de salida antes de liberar el canal.
func stop_with_fade(fade_time_sec: float = 0.015) -> void:
	if not is_busy:
		return
	fade_duration_sec = maxf(0.005, fade_time_sec)
	is_fading_out = true
	is_fading_in = false
	fade_timer = fade_duration_sec

## Detiene y libera el canal de inmediato.
func stop_immediate() -> void:
	var player := get_player()
	if player != null and player.has_method("stop"):
		player.stop()
	is_busy = false
	is_fading_out = false
	is_fading_in = false
	current_stream = null
	assigned_instance_ref = null
	current_fade_gain = 0.0

## Procesa los multiplicadores de fade de entrada y salida por frame.
func process_fade(delta: float) -> void:
	if not is_busy:
		return

	if is_fading_out:
		fade_timer -= delta
		current_fade_gain = clampf(fade_timer / fade_duration_sec, 0.0, 1.0)
		if fade_timer <= 0.0:
			stop_immediate()
	elif is_fading_in:
		fade_timer += delta
		current_fade_gain = clampf(fade_timer / fade_duration_sec, 0.0, 1.0)
		if fade_timer >= fade_duration_sec:
			is_fading_in = false
			current_fade_gain = 1.0
	else:
		current_fade_gain = 1.0
