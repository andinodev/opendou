class_name CabinDemo
extends Node3D

## «La cabina»: eventos y syncs conduciendo un momento.
##
## Torre de control aerea, de noche. La situacion se degrada: Routine -> Alert ->
## Emergency. La musica cruza sus stems, la radio cambia de estacion, los stingers
## entran por trigger, y las pisadas del operador cambian al pasar de la tarima de
## madera a la rejilla metalica.
##
## LA TESIS: un solo valor de RTPC -Tension- conduce TRES cosas distintas de forma
## coherente, y los estados CRUZAN en lugar de cortar.
##
## Nota de vocabulario: el diseno hablaba de moqueta. Carpet no existe entre las ocho
## superficies, y usarlo daria pisadas sin acustica. La cabina tiene Wood y Metal.

const SurfacePatchClass = preload("res://scenes/shared/surface_patch.gd")
const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const PlayerControllerClass = preload("res://scenes/shared/player_controller.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")
const RadioEventsClass = preload("res://scenes/demos/cabin/radio_events.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const RTPCBindingClass = preload("res://addons/opendou/resources/rtpc_binding.gd")
const OpenDouMusicPlayerClass = preload("res://addons/opendou/nodes/opendou_music_player.gd")
const OpenDouEventPlayerClass = preload("res://addons/opendou/nodes/opendou_event_player.gd")
const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
const AudioDialogueTableClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_table.gd")
const AudioDialogueManagerClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_manager.gd")

## Nombre del banco de locuciones y ruta donde se escribe.
const BANK_NAME: StringName = &"TowerAnnouncements"
const BANK_PATH: String = "user://opendou_tower_announcements.bnk"

const RADIO_BUS: StringName = &"Radio"
const MUSIC_BUS: StringName = &"Music"
const STEM_BUSES: Array[StringName] = [&"MusicPads", &"MusicBass", &"MusicDrums", &"MusicBrass"]

const SUITE_NAME: StringName = &"Tower_Night_Watch"

## El RTPC que conduce las tres cosas.
const TENSION: StringName = &"Tension"

## Envio de reverb de la cabina en calma y en tension.
const SEND_CALM: float = 0.55
const SEND_TENSE: float = 0.12

var event_manager = null
var music: OpenDouMusicPlayer = null
var radio_player: OpenDouEventPlayer = null
var radio_def: AudioEventDef = null
var cabin_room: OpenDouRoom3D = null
var dialogue: AudioDialogueManager = null
var bank_loaded: bool = false

var _built: bool = false

func _ready() -> void:
	build()

## Construye la escena. Idempotente.
func build() -> void:
	if _built:
		return
	_built = true

	DemoAudioClass.ensure_bus(MUSIC_BUS)
	DemoAudioClass.ensure_bus(RADIO_BUS)
	# Los stems envian a Master y NO a Music, para que el bus de stingers -que es Music,
	# porque trigger_stinger() usa master_bus- mida SOLO stingers.
	for bus in STEM_BUSES:
		DemoAudioClass.ensure_bus(bus)

	# El autoload, no una copia. Ver DemoAudio.manager().
	event_manager = DemoAudioClass.manager(self)
	if event_manager == null:
		push_error("[CabinDemo] no hay autoload OpenDou: la escena no puede sonar")
		return
	FootstepEventsClass.register(event_manager)

	_build_cabin()
	_build_music()
	_build_radio()
	_build_bank_and_dialogue()
	_build_triggers()
	_build_operator()

	# Estado inicial explicito: sin esto, el primer escalate() no tendria de donde
	# cruzar y la transicion arrancaria desde un estado vacio.
	event_manager.set_state(&"Situation", &"Routine", 0.0)
	set_tension(0.0)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 20.0, 0.0)
	light.light_energy = 0.2
	light.light_color = Color(0.7, 0.75, 0.95)
	add_child(light)

## La cabina: una sala con su reverb, tarima de madera y una pasarela de rejilla.
func _build_cabin() -> void:
	cabin_room = OpenDouRoom3DClass.new()
	cabin_room.name = "Cabin"
	cabin_room.room_name = &"Cabin"
	cabin_room.material_preset = "Glass"
	cabin_room.floor_surface = &"Wood"
	cabin_room.reverb_send_amount = SEND_CALM
	cabin_room.position = Vector3(0.0, 1.8, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 3.5, 10.0)
	shape.shape = box
	cabin_room.add_child(shape)
	add_child(cabin_room)

	# Tarima de madera en la cabina y rejilla metalica en la pasarela de salida.
	add_child(SurfacePatchClass.make(&"Wood", Vector3(10.0, 0.4, 10.0), Vector3(0.0, -0.2, 0.0)))
	add_child(SurfacePatchClass.make(&"Metal", Vector3(3.0, 0.4, 8.0), Vector3(0.0, -0.2, 9.0)))

func _build_music() -> void:
	music = OpenDouMusicPlayerClass.new()
	music.name = "Music"
	# Las propiedades van ANTES de add_child: _ready() carga la suite y arranca.
	music.suite_name = SUITE_NAME
	music.master_bus = MUSIC_BUS
	music.auto_play = true
	music.enable_ducking = false
	music.combat_intensity = 0.0
	add_child(music)

## La radio: un OpenDouEventPlayer NO espacial, porque suena en el altavoz de la mesa,
## no en un punto del mundo.
func _build_radio() -> void:
	radio_def = RadioEventsClass.register(event_manager, RADIO_BUS)

	# El MISMO RTPC que mueve la musica cierra el filtro de la radio. cutoff_hz es una
	# propiedad que el motor aplica de verdad: _apply_voices() la lee de
	# calculated_properties y la pasa al canal fisico.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.06))
	curve.bake()
	var binding = RTPCBindingClass.new(TENSION, &"cutoff_hz", curve,
		RTPCBindingClass.Operation.MULTIPLY, 0.0, 1.0)
	binding.bake_lut()
	radio_def.add_rtpc_binding(binding)

	radio_player = OpenDouEventPlayerClass.new()
	radio_player.name = "Radio"
	radio_player.event_def = radio_def
	radio_player.auto_play_event = true
	# El enrutado real lo hace def.target_bus: PhysicalVoiceChannel.play_stream() asigna
	# player.bus desde ahi cada vez que la instancia se desvirtualiza, y eso ocurre
	# DESPUES de que play_event() aplique bus_category. Se deja en Master para que las
	# dos fuentes digan lo mismo.
	radio_player.bus_category = "Master"
	add_child(radio_player)

## Escribe y carga el banco de locuciones, y monta la tabla de dialogo sobre el.
##
## El banco se escribe en user:// porque res:// es de solo lectura en un juego
## exportado: un banco generado en tiempo de ejecucion no puede vivir ahi.
func _build_bank_and_dialogue() -> void:
	if not FileAccess.file_exists(BANK_PATH):
		RadioEventsClass.build_announcement_bank(BANK_PATH)
	bank_loaded = event_manager.load_bank(BANK_PATH, BANK_NAME) != null

	var table = AudioDialogueTableClass.new()
	if bank_loaded:
		table.add_entry(&"ClearedToLand", "es", event_manager.get_bank_stream(BANK_NAME, 0))
		table.add_entry(&"ClearedToLand", "en", event_manager.get_bank_stream(BANK_NAME, 1))
		table.add_entry(&"GoAround", "es", event_manager.get_bank_stream(BANK_NAME, 2))
		table.add_entry(&"GoAround", "en", event_manager.get_bank_stream(BANK_NAME, 2))
	dialogue = AudioDialogueManagerClass.new("es", table)

## Los triggers: un nombre posteado produce un stinger. La demo no llama al stinger
## desde el sitio que sube la tension; lo hace el listener.
func _build_triggers() -> void:
	var sync = event_manager.sync_manager
	if sync == null:
		return
	sync.register_trigger_listener(&"AlertRaised", func(_name):
		if music != null:
			music.trigger_stinger(&"Impact")
	)
	sync.register_trigger_listener(&"Resolved", func(_name):
		if music != null:
			music.trigger_stinger(&"Fanfare")
	)

func _build_operator() -> void:
	var player = PlayerControllerClass.new()
	player.name = "Operator"
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child(player)

## Mueve la tension. UN valor, TRES efectos.
func set_tension(value: float) -> void:
	var t := clampf(value, 0.0, 1.0)
	if event_manager != null:
		# 1. El RTPC, que las bindings de la radio leen.
		event_manager.set_rtpc(TENSION, t, true)
	if music != null:
		# 2. La intensidad musical, que decide que stems estan dentro de su ventana.
		music.set_combat_intensity(t)
	if cabin_room != null:
		# 3. El envio de reverb: la cabina se cierra sobre el operador.
		cabin_room.reverb_send_amount = lerpf(SEND_CALM, SEND_TENSE, t)

## Escala la situacion con crossfade. Dos segundos: se oye cruzar.
func escalate(situation: StringName) -> void:
	if event_manager == null:
		return
	event_manager.set_state(&"Situation", situation, 2.0)
	if situation == &"Alert":
		event_manager.post_trigger(&"AlertRaised")
		set_tension(0.55)
	elif situation == &"Emergency":
		event_manager.post_trigger(&"AlertRaised")
		set_tension(1.0)
	else:
		event_manager.post_trigger(&"Resolved")
		set_tension(0.0)

## Cambia de estacion. Es un switch, no un evento distinto.
func tune_radio(station: StringName) -> void:
	if event_manager != null:
		event_manager.set_switch(RadioEventsClass.SWITCH_GROUP, station)

## Contexto de reproduccion con los syncs actuales, para resolver el evento de radio.
func radio_context() -> AudioPlaybackContext:
	var context = AudioPlaybackContextClass.new()
	var sync = event_manager.sync_manager if event_manager != null else null
	if sync != null:
		for group in sync.global_switches:
			context.set_switch(group, sync.global_switches[group])
	return context

## Corte actual de la radio, en Hz. Es lo que el motor va a aplicar al canal.
func get_radio_cutoff() -> float:
	if radio_player == null or radio_player.active_instance == null:
		return 0.0
	return float(radio_player.active_instance.calculated_properties.get(&"cutoff_hz", 0.0))

## Retira las instancias de esta escena del autoload, que sobrevive al cambio de escena.
func _exit_tree() -> void:
	if event_manager != null:
		event_manager.stop_all()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			escalate(&"Routine")
		KEY_2:
			escalate(&"Alert")
		KEY_3:
			escalate(&"Emergency")
		KEY_R:
			var stations := RadioEventsClass.STATIONS
			# El tipo va explicito: event_manager esta sin tipar, asi que := no puede
			# inferir el retorno.
			var current: StringName = event_manager.get_switch(RadioEventsClass.SWITCH_GROUP, null, stations[0])
			var idx: int = stations.find(current)
			tune_radio(stations[(idx + 1) % stations.size()])
