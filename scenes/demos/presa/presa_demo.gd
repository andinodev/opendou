class_name PresaDemo
extends Node3D

## «La presa»: un valle entero suena por geometria.
##
## LA ESCENA lleva todo lo que se puede declarar: valle, presa, nave de turbinas, sala de
## control con su cristal, galeria en L, galeria inundada, aliviadero con su compuerta
## dinamica, carretera, rio, bosque; salas, portales, reflectores, areas, volumenes de
## entorno, emisores, jugador con su oyente, vigilantes con oido y voz, HUD, indicador de
## sonidos, monitor y depurador. Ver .agents/rules/04_scene_composition.md.
##
## Este script hace lo dinamico: autorar los eventos (los streams se sintetizan: la unica
## excepcion legitima), el ciclo de tormenta, el camion en ronda, los vigilantes que oyen,
## los cascotes, la compuerta, la megafonia y las teclas.

const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")
const VehicleEngineEventsClass = preload("res://scenes/shared/vehicle_engine_events.gd")
const DemoAudioClass = preload("res://scenes/shared/demo_audio.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioRandomContainerClass = preload("res://addons/opendou/resources/containers/audio_random_container.gd")
const AudioBlendContainerClass = preload("res://addons/opendou/resources/containers/audio_blend_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AmbisonicAudioClass = preload("res://addons/opendou/resources/ambisonic_audio.gd")
const TableClass = preload("res://addons/opendou/core/dialogue/audio_dialogue_table.gd")

const BUSES: Array[StringName] = [&"Music", &"SFX", &"Voice", &"Ambience", &"Radio", &"Turbines", &"Water", &"Wildlife", &"Vehicle", &"Thunder", &"Spillway"]

## Ciclo de tormenta: calma -> nubes -> tormenta -> calma. Segundos por fase (T lo acelera).
enum Storm { CALM, CLOUDS, STORM, CLEARING }
@export var storm_phase_sec: Array[float] = [30.0, 15.0, 30.0, 15.0]
## Camion: velocidad sobre la carretera (m/s) y rpm por velocidad.
@export var truck_speed_mps: float = 9.0
## Rayos al azar durante la tormenta (apagado, solo strike() los dispara).
@export var auto_lightning: bool = true
## Cada cuantos segundos cae un cascote de la pasarela (0 = nunca).
@export var rubble_interval_sec: float = 12.0

@onready var turbines: Array[OpenDouEventPlayer3D] = [$Turbine_0, $Turbine_1]
@onready var horn: OpenDouEventPlayer3D = $Horn
@onready var drip: OpenDouEventPlayer3D = $Drip
@onready var birds: OpenDouEventPlayer3D = $Birds
@onready var thunder: OpenDouEventPlayer3D = $Thunder
@onready var radio_source: OpenDouEventPlayer = $RadioSource
@onready var music: OpenDouMusicPlayer = $Music
@onready var wind_bed: OpenDouAmbisonicBed3D = $WindBed
@onready var rain_bed: OpenDouAmbisonicBed3D = $RainBed
@onready var river: OpenDouSplineEmitter3D = $River
@onready var spillway: OpenDouMultiPositionEmitter3D = $Spillway
@onready var frogs: OpenDouGranularEmitter3D = $Frogs
@onready var crickets: OpenDouGranularEmitter3D = $Crickets
@onready var truck_follow: PathFollow3D = $RoadPath/TruckFollow
@onready var truck: OpenDouEventPlayer3D = $RoadPath/TruckFollow/Truck
@onready var gate: StaticBody3D = $Spillway_Gate
@onready var debugger: OpenDouAcousticDebugger3D = $AcousticDebugger
@onready var player: Node3D = $Player
@onready var guards: Array[Node3D] = [$GuardHall, $GuardYard]
@onready var portals: Array[OpenDouPortal3D] = [$Door_Nave_Galeria, $Gate_Nave_Valle, $Hatch_Galeria_Inundada]

var event_manager: AudioEventManager = null
var storm: Storm = Storm.CALM
var storm_intensity: float = 0.0
var gate_open: bool = true
var rooms: Dictionary = {}
var strikes: int = 0
var heard_log: Array[Dictionary] = []

var _storm_t: float = 0.0
var _rubble_t: float = 0.0
var _rubble_next: int = 0
var _bird_t: float = 3.0
var _strike_t: float = 0.0
var _gate_tween: Tween = null
var _gate_closed_y: float = -12.0

func _ready() -> void:
	for child in get_children():
		if child is OpenDouRoom3D:
			rooms[child.room_name] = child
	event_manager = DemoAudioClass.manager(self)
	for b in BUSES:
		DemoAudioClass.ensure_bus(b)
	if event_manager == null:
		return
	FootstepEventsClass.register(event_manager)
	_author_turbine()
	_author_one_shots()
	_author_rubble()
	_author_radio()
	_author_guards()
	_author_truck()
	_author_beds_and_wildlife()
	for t in turbines:
		t.play_event()
	drip.play_event()
	radio_source.play_event()
	horn.play_event()
	music.load_suite(&"Presa_Storm")
	music.play()
	music.set_combat_intensity(0.0)
	truck.play_event()
	event_manager.set_rtpc(&"StormIntensity", 0.0, true)
	_gate_closed_y = gate.global_position.y
	gate.global_position.y = _gate_closed_y + 8.0   # arranca abierta (levantada)
	for gd in guards:
		var ear: OpenDouAIHearing3D = gd.get_node("Ear")
		ear.sound_heard.connect(_on_guard_heard.bind(gd))

# ==============================================================================
# AUTORIA DE EVENTOS (streams sintetizados: la unica excepcion a componer en la escena)
# ==============================================================================

## Turbina: mezcla de dos capas por carga (RTPC TurbineLoad del area de la nave).
func _author_turbine() -> void:
	# Las curvas del contenedor son OFFSETS EN dB (como las del motor del taller): 0 = la capa
	# suena, -60 = callada.
	var blend = AudioBlendContainerClass.new(&"TurbineLoad")
	var low := Curve.new()
	low.min_value = -60.0
	low.max_value = 0.0
	low.add_point(Vector2(0.0, 0.0)); low.add_point(Vector2(0.6, 0.0)); low.add_point(Vector2(1.0, -18.0))
	var high := Curve.new()
	high.min_value = -60.0
	high.max_value = 0.0
	high.add_point(Vector2(0.0, -60.0)); high.add_point(Vector2(0.4, -60.0)); high.add_point(Vector2(1.0, 0.0))
	blend.add_layer(AudioPhysicalNodeClass.new(AudioSynthesizerClass.create_server_ambient_loop(3.0)), low)
	blend.add_layer(AudioPhysicalNodeClass.new(AudioSynthesizerClass.create_engine_loop(48.0, 2.0)), high)
	var def = AudioEventDefClass.new(&"Turbine")
	def.root_container = blend
	def.is_looping = true
	def.stream_length = 2.0
	def.base_volume_db = -10.0
	def.base_priority = 70.0
	def.hdr_loudness_db = -6.0
	def.target_bus = &"Turbines"
	event_manager.register_event_definition(def)

func _author_one_shots() -> void:
	var drip_def = AudioEventDefClass.new(&"Drip", AudioSynthesizerClass.create_water_droplet())
	drip_def.is_looping = true
	drip_def.stream_length = 1.4
	drip_def.base_volume_db = -8.0
	drip_def.target_bus = &"Water"
	event_manager.register_event_definition(drip_def)
	var bird_def = AudioEventDefClass.new(&"Bird", AudioSynthesizerClass.create_bird_chirp())
	bird_def.stream_length = 0.9
	bird_def.base_volume_db = -10.0
	bird_def.base_priority = 20.0
	bird_def.target_bus = &"Wildlife"
	event_manager.register_event_definition(bird_def)
	var thunder_def = AudioEventDefClass.new(&"Thunder", AudioSynthesizerClass.create_thunder_rumble())
	thunder_def.stream_length = 3.5
	thunder_def.base_volume_db = 4.0
	thunder_def.base_priority = 85.0
	thunder_def.hdr_loudness_db = 6.0
	# Bus propio: para medir su llegada sin el viento ni la lluvia de Ambience.
	thunder_def.target_bus = &"Thunder"
	event_manager.register_event_definition(thunder_def)
	var warn_def = AudioEventDefClass.new(&"GuardWarn", AudioSynthesizerClass.create_tone(660.0, 0.12, 0.25, true))
	warn_def.stream_length = 0.12
	warn_def.target_bus = &"Voice"
	event_manager.register_event_definition(warn_def)

## Cascotes: switch por material con variaciones (Metal en la pasarela, Concrete en el suelo).
func _author_rubble() -> void:
	var sw = AudioSwitchContainerClass.new(&"Material", &"Concrete")
	for mat in [&"Concrete", &"Metal", &"Stone"]:
		var rnd = AudioRandomContainerClass.new()
		rnd.pitch_jitter_range = Vector2(-0.1, 0.1)
		for v in range(1, 4):
			rnd.add_child_node(AudioPhysicalNodeClass.new(AudioSynthesizerClass.create_footstep(mat, v)))
		sw.set_state_node(mat, rnd)
	var def = AudioEventDefClass.new(&"Rubble")
	def.root_container = sw
	def.stream_length = 0.3
	def.base_volume_db = 0.0
	def.base_priority = 55.0
	def.target_bus = &"SFX"
	event_manager.register_event_definition(def)

## La radio de la sala de control es la FUENTE del altavoz de megafonia (BUS_CAPTURE).
func _author_radio() -> void:
	var def = AudioEventDefClass.new(&"RadioProgram", AudioSynthesizerClass.create_music_brass_loop(2.0))
	def.is_looping = true
	def.stream_length = 2.0
	def.base_volume_db = -8.0
	def.target_bus = &"Radio"
	event_manager.register_event_definition(def)

func _author_guards() -> void:
	var table = TableClass.new()
	table.add_entry(&"halt", "es", AudioSynthesizerClass.create_tone(190.0, 1.1, 0.4, true))
	table.add_entry(&"warn", "es", AudioSynthesizerClass.create_tone(160.0, 1.4, 0.4, true))
	for gd in guards:
		var voice: OpenDouDialogueEmitter3D = gd.get_node("Voice")
		voice.dialogue_table = table

func _author_truck() -> void:
	var def = VehicleEngineEventsClass.register(event_manager)
	def.target_bus = &"Vehicle"
	truck.event_name = def.event_name
	truck.event_def = def

## Camas ambisonicas (viento y lluvia) y fauna granular. El viento se codifica al frente-arriba.
func _author_beds_and_wildlife() -> void:
	var rate: int = int(AudioServer.get_mix_rate())
	var wind_wav: AudioStreamWAV = AudioSynthesizerClass.create_canopy_wind_loop(4.0)
	var wind_audio = AmbisonicAudioClass.encode_point(_wav_to_floats(wind_wav), Vector3(-0.6, 0.4, -0.7), rate, 1)
	if wind_audio != null:
		wind_bed.audio = wind_audio
		wind_bed.rebuild_stream()
		wind_bed.volume_db = -14.0
		wind_bed.play()
	var rain_wav: AudioStreamWAV = AudioSynthesizerClass.create_rain_ambient_loop(4.0)
	var rain_audio = AmbisonicAudioClass.encode_point(_wav_to_floats(rain_wav), Vector3(0.0, 1.0, -0.2), rate, 1)
	if rain_audio != null:
		rain_bed.audio = rain_audio
		rain_bed.rebuild_stream()
		rain_bed.volume_db = -80.0
		rain_bed.play()
	frogs.source_stream = AudioSynthesizerClass.create_frog_croak()
	frogs.play_granular()
	crickets.source_stream = AudioSynthesizerClass.create_cicada_swarm_loop(2.0)
	crickets.play_granular()
	river.stream = AudioSynthesizerClass.create_water_stream_ambient_loop(4.0)
	river.volume_db = -6.0
	spillway.stream = AudioSynthesizerClass.create_water_stream_ambient_loop(3.0)
	spillway.volume_db = 2.0

static func _wav_to_floats(wav: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if wav == null:
		return out
	var bytes: PackedByteArray = wav.data
	var n: int = bytes.size() / 2
	out.resize(n)
	for i in range(n):
		out[i] = float(bytes.decode_s16(i * 2)) / 32768.0
	return out

# ==============================================================================
# VIDA
# ==============================================================================

func _process(delta: float) -> void:
	if event_manager == null:
		return
	_tick_storm(delta)
	_tick_truck(delta)
	_tick_rubble(delta)
	_tick_birds(delta)

func _tick_storm(delta: float) -> void:
	_storm_t += delta
	var target: float = 0.0
	match storm:
		Storm.CALM: target = 0.0
		Storm.CLOUDS: target = 0.4
		Storm.STORM: target = 1.0
		Storm.CLEARING: target = 0.3
	storm_intensity = move_toward(storm_intensity, target, delta * 0.25)
	event_manager.set_rtpc(&"StormIntensity", storm_intensity)
	music.set_combat_intensity(storm_intensity)
	rain_bed.volume_db = lerpf(-80.0, -10.0, clampf((storm_intensity - 0.3) / 0.7, 0.0, 1.0))
	# La fauna calla con la lluvia.
	frogs.volume_db = lerpf(-4.0, -30.0, storm_intensity)
	crickets.volume_db = lerpf(-6.0, -30.0, storm_intensity)
	if storm == Storm.STORM and auto_lightning:
		_strike_t -= delta
		if _strike_t <= 0.0:
			_strike_t = randf_range(6.0, 12.0)
			strike()
	if _storm_t >= storm_phase_sec[int(storm)]:
		advance_storm()

## Un rayo: el trueno suena a 300-400 m con retardo por distancia, en una direccion al azar.
func strike() -> void:
	strikes += 1
	var ang: float = randf() * TAU
	var d: float = randf_range(300.0, 400.0)
	thunder.global_position = Vector3(cos(ang) * d, 60.0, sin(ang) * d - 20.0)
	thunder.play_event()
	if music != null:
		music.trigger_stinger(&"Impact")

func advance_storm() -> void:
	storm = ((int(storm) + 1) % 4) as Storm
	_storm_t = 0.0
	if storm == Storm.STORM:
		_strike_t = 1.0

func _tick_truck(delta: float) -> void:
	truck_follow.progress += truck_speed_mps * delta
	# RPM por velocidad y una carga que sube en las curvas (los extremos de la carretera).
	var along: float = fmod(truck_follow.progress, maxf(truck_follow.get_parent().curve.get_baked_length(), 1.0))
	var curve_t: float = along / maxf(truck_follow.get_parent().curve.get_baked_length(), 1.0)
	var in_turn: bool = absf(fmod(curve_t * 4.0, 1.0) - 0.5) > 0.42
	truck.set_rtpc(VehicleEngineEventsClass.RPM_RTPC, 2400.0 if in_turn else 3600.0)
	truck.set_switch(VehicleEngineEventsClass.LOAD_SWITCH, &"Load" if in_turn else &"Idle")

func _tick_rubble(delta: float) -> void:
	if rubble_interval_sec <= 0.0:
		return
	_rubble_t += delta
	if _rubble_t >= rubble_interval_sec:
		_rubble_t = 0.0
		drop_rubble()

## Suelta el siguiente cascote de la pasarela (vuelve a su sitio al agotarlos).
func drop_rubble() -> void:
	var body: RigidBody3D = get_node_or_null("Debris_%d" % (_rubble_next % 3))
	_rubble_next += 1
	if body == null:
		return
	if not body.freeze:
		body.freeze = true
		body.global_position = Vector3(-12 + 10 * (_rubble_next % 3), -7.6, 6)
		body.linear_velocity = Vector3.ZERO
	body.freeze = false

func _tick_birds(delta: float) -> void:
	_bird_t -= delta
	if _bird_t <= 0.0:
		_bird_t = randf_range(4.0, 9.0) * (1.0 + 3.0 * storm_intensity)
		birds.global_position = Vector3(randf_range(22.0, 44.0), -8.0, randf_range(31.0, 44.0))
		birds.play_event()

## Un vigilante oye algo: si son pisadas del jugador, se lo dice (con ducking de la musica).
func _on_guard_heard(event_name: StringName, loudness_db: float, from_position: Vector3, guard_node: Node3D) -> void:
	heard_log.append({"guard": guard_node.name, "event": event_name, "db": loudness_db, "from": from_position})
	if event_name != FootstepEventsClass.EVENT_NAME:
		return
	if from_position.distance_to(player.global_position) > 2.0:
		return
	var voice: OpenDouDialogueEmitter3D = guard_node.get_node("Voice")
	if voice != null and not voice.is_speaking():
		voice.speak(&"halt" if guard_node.name == "GuardHall" else &"warn")

## Compuerta: baja (cierra) o sube (abre) en dos segundos; el bake la sigue como ocluidor dinamico.
func toggle_gate() -> void:
	gate_open = not gate_open
	if _gate_tween != null:
		_gate_tween.kill()
	_gate_tween = create_tween()
	_gate_tween.tween_property(gate, "global_position:y", _gate_closed_y if not gate_open else _gate_closed_y + 8.0, 2.0)

func set_gate_open(open: bool, instant: bool = false) -> void:
	gate_open = open
	if instant:
		if _gate_tween != null:
			_gate_tween.kill()
		gate.global_position.y = _gate_closed_y if not open else _gate_closed_y + 8.0
	else:
		gate_open = not open
		toggle_gate()

func toggle_nearest_portal() -> void:
	var best: OpenDouPortal3D = null
	var best_d: float = 6.0
	for p in portals:
		var d: float = p.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = p
	if best != null:
		best.open_factor = 0.0 if best.open_factor > 0.5 else 1.0

func toggle_debugger() -> bool:
	debugger.enabled = not debugger.enabled
	return debugger.enabled

func _exit_tree() -> void:
	if event_manager != null:
		event_manager.stop_all()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_G: toggle_gate()
			KEY_T: advance_storm()
			KEY_E: toggle_nearest_portal()
			KEY_F9: toggle_debugger()
