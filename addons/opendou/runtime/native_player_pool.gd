class_name OpenDouNativePlayerPool
extends Node

## Pool de reproductores nativos de Godot para las voces anonimas de OpenDou.
##
## Existe porque post_event() sin nodo dedicado necesita algo que reproduzca de
## verdad. Los reproductores permanecen hijos de este nodo durante toda su vida y
## se reposicionan asignando global_position; nunca se reparentan, porque
## reparentar cada frame seria costoso.
##
## El crecimiento es perezoso y con cupo: acquire() devuelve null cuando se agota,
## en lugar de crear nodos sin limite.

enum PlayerKind {
	NON_SPATIAL, ## AudioStreamPlayer: UI, musica, narracion
	SPATIAL_2D,  ## AudioStreamPlayer2D
	SPATIAL_3D,  ## AudioStreamPlayer3D (backend godot)
	BINAURAL_3D, ## AudioStreamPlayer3D NEUTRALIZADO con OpenDouSpatialStream (backend steam_audio)
}

## Cupo maximo de reproductores por tipo.
var max_players_per_kind: int = 64

## Ajustes vigentes con los que nace cada stream nativo nuevo (los fija el manager).
var default_spatial_blend: float = 1.0
var default_output_mode: int = 0

var _free: Dictionary = {}
var _busy: Dictionary = {}

func _init(p_max_per_kind: int = 64) -> void:
	name = "OpenDouNativePlayerPool"
	max_players_per_kind = maxi(1, p_max_per_kind)
	for kind in [PlayerKind.NON_SPATIAL, PlayerKind.SPATIAL_2D, PlayerKind.SPATIAL_3D, PlayerKind.BINAURAL_3D]:
		_free[kind] = []
		_busy[kind] = []

## Obtiene un reproductor libre del tipo pedido, creandolo si hace falta.
## Devuelve null si se alcanzo el cupo.
func acquire(kind: int) -> Node:
	if not _free.has(kind):
		return null
	var free_list: Array = _free[kind]
	var busy_list: Array = _busy[kind]
	var player: Node = null

	while not free_list.is_empty() and player == null:
		var candidate = free_list.pop_back()
		if is_instance_valid(candidate):
			player = candidate

	if player == null:
		if busy_list.size() >= max_players_per_kind:
			return null
		player = _instantiate(kind)
		if player == null:
			return null
		add_child(player)

	busy_list.append(player)
	return player

## Devuelve un reproductor al pool, deteniendolo y dejandolo limpio.
func release(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	var kind: int = _kind_of(player)
	if kind < 0:
		return
	var busy_list: Array = _busy[kind]
	var idx: int = busy_list.find(player)
	if idx >= 0:
		busy_list.remove_at(idx)
	if player.has_method("stop"):
		player.stop()
	if _is_binaural(player):
		# El stream nativo es permanente: se suelta solo la fuente.
		player.stream.source = null
	else:
		player.stream = null
	(_free[kind] as Array).append(player)

## Numero de reproductores actualmente asignados de un tipo.
func busy_count(kind: int) -> int:
	if not _busy.has(kind):
		return 0
	return (_busy[kind] as Array).size()

## Numero total de reproductores instanciados de un tipo (libres + ocupados).
func total_count(kind: int) -> int:
	if not _busy.has(kind):
		return 0
	return (_busy[kind] as Array).size() + (_free[kind] as Array).size()

func _instantiate(kind: int) -> Node:
	match kind:
		PlayerKind.SPATIAL_3D:
			var p3 := AudioStreamPlayer3D.new()
			# Doppler nativo desactivado por defecto: OpenDou controla el pitch y
			# dejarlo activo produciria doble modulacion.
			p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
			# Sin mascara de areas el reproductor no encuentra ninguna sala y no alimenta
			# su bus de reverb (medido en la Fase 7B: un reproductor creado por codigo puede
			# nacer con area_mask = 0). La capa 1 es la de los OpenDouRoom3D por defecto.
			p3.area_mask = 1
			return p3
		PlayerKind.SPATIAL_2D:
			return AudioStreamPlayer2D.new()
		PlayerKind.BINAURAL_3D:
			if not ClassDB.class_exists("OpenDouSpatialStream"):
				push_error("[OpenDou] se pidio un reproductor binaural sin la extension nativa cargada")
				return null
			# El anfitrion es un AudioStreamPlayer3D con su espacializacion APAGADA: sin paneo,
			# sin atenuacion, sin filtro. Godot no toca el estereo binaural que produce el
			# stream, pero si lo ENVIA al bus de reverb del Area3D de la sala, que es un
			# mecanismo exclusivo de los reproductores 3D y que GDExtension no expone de otra
			# forma (AudioServer solo publica la velocidad de reproduccion). Un
			# AudioStreamPlayer plano perdia el reverb por sala de la Fase 2.
			var p := AudioStreamPlayer3D.new()
			p.panning_strength = 0.0
			p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
			p.attenuation_filter_db = 0.0
			p.max_db = 24.0
			p.max_distance = 0.0
			p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
			p.area_mask = 1
			# El stream nativo es PERMANENTE: por voz solo cambia su fuente. Crear uno por voz
			# seria crear y destruir efectos de Steam Audio a cada disparo.
			p.stream = ClassDB.instantiate("OpenDouSpatialStream")
			p.stream.spatial_blend = default_spatial_blend
			p.stream.output_mode = default_output_mode
			return p
		_:
			return AudioStreamPlayer.new()

static func _is_binaural(player: Node) -> bool:
	return (player is AudioStreamPlayer3D or player is AudioStreamPlayer) and player.stream != null and player.stream.get_class() == "OpenDouSpatialStream"

func _kind_of(player: Node) -> int:
	if _is_binaural(player):
		return PlayerKind.BINAURAL_3D
	if player is AudioStreamPlayer3D:
		return PlayerKind.SPATIAL_3D
	if player is AudioStreamPlayer2D:
		return PlayerKind.SPATIAL_2D
	if player is AudioStreamPlayer:
		return PlayerKind.NON_SPATIAL
	return -1

## Recorre los streams nativos de todos los reproductores binaurales, libres y ocupados.
## Es lo que aplica en vivo la mezcla, la salida y el HRTF (ajustes del jugador).
func for_each_spatial_stream(callable: Callable) -> void:
	for p in (_free[PlayerKind.BINAURAL_3D] as Array) + (_busy[PlayerKind.BINAURAL_3D] as Array):
		if is_instance_valid(p) and p.stream != null:
			callable.call(p.stream)
