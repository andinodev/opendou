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
##
## LA ESCENA lleva la sala con su colisionador, la tarima y la rejilla con su metadata,
## el reproductor de musica, la radio, el operador, la luz y el cartel. Este script solo
## hace lo dinamico: crear los buses, autorar los eventos -sus streams se sintetizan-,
## arrancar musica y radio DESPUES de que existan los buses, y las teclas.
## Ver .agents/rules/04_scene_composition.md.

const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")
const RadioEventsClass = preload("res://scenes/demos/cabin/radio_events.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const RTPCBindingClass = preload("res://addons/opendou/resources/rtpc_binding.gd")
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

@onready var music: OpenDouMusicPlayer = $Music
@onready var radio_player: OpenDouEventPlayer = $Radio
@onready var cabin_room: OpenDouRoom3D = $Cabin

var event_manager = null
var radio_def: AudioEventDef = null
var dialogue: AudioDialogueManager = null
var bank_loaded: bool = false


func _ready() -> void:
	# Los buses PRIMERO: los hijos ya hicieron su _ready, y por eso la escena deja el
	# reproductor de musica y la radio en auto_play = false. Si arrancaran solos,
	# intentarian usar buses que todavia no existen y Godot daria error al cargar.
	DemoAudioClass.ensure_bus(MUSIC_BUS)
	DemoAudioClass.ensure_bus(RADIO_BUS)
	# Los stems envian a Master y NO a Music, para que el bus de stingers -que es Music,
	# porque trigger_stinger() usa master_bus- mida SOLO stingers.
	for bus in STEM_BUSES:
		DemoAudioClass.ensure_bus(bus)

	event_manager = DemoAudioClass.manager(self)
	if event_manager == null:
		push_error("[CabinDemo] no hay autoload OpenDou: la escena no puede sonar")
		return
	FootstepEventsClass.register(event_manager)

	music.load_suite(SUITE_NAME)
	music.play()

	_build_radio()
	_build_bank_and_dialogue()
	_build_triggers()

	# Estado inicial explicito: sin esto, el primer escalate() no tendria de donde
	# cruzar y la transicion arrancaria desde un estado vacio.
	event_manager.set_state(&"Situation", &"Routine", 0.0)
	set_tension(0.0)

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

	# El nodo ya esta en la escena; aqui solo recibe su definicion y arranca. El
	# enrutado real lo hace def.target_bus: PhysicalVoiceChannel.play_stream() asigna
	# player.bus desde ahi cada vez que la instancia se desvirtualiza, y eso ocurre
	# DESPUES de que play_event() aplique bus_category.
	radio_player.event_def = radio_def
	radio_player.play_event()

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
