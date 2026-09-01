class_name CharacterAudioRig
extends Node3D

## Rig de audio de un personaje: emisor de pisadas y foley, mas AnimationSync.
##
## NO lleva oyente. El oyente es del jugador: si el rig incluyera un AudioListener3D y
## se instanciase para tres NPC, el resolutor de la Fase 1 tendria cuatro candidatos y
## el resultado dependeria del orden del arbol.
##
## No sabe si lo mueve un humano o una IA. Los controladores le notifican distancia
## recorrida y el decide cuando hay un paso.

const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")
const OpenDouAnimationSyncClass = preload("res://addons/opendou/nodes/opendou_animation_sync.gd")
const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")

## Metros recorridos entre pisada y pisada.
@export var stride_meters: float = 1.6

## Pasos dados desde que existe el rig. Solo informativo y para los tests.
var steps_taken: int = 0

var rig_emitter: OpenDouEventPlayer3D = null
var animation_sync: OpenDouAnimationSync = null

var _distance_accumulator: float = 0.0

func _ready() -> void:
	name = "CharacterAudioRig"

	# El emisor existe para que las pisadas tengan una posicion 3D propia y hereden
	# las propiedades nativas del inspector: unit_size, atenuacion, area_mask.
	rig_emitter = OpenDouEventPlayer3DClass.new()
	rig_emitter.name = "RigEmitter"
	rig_emitter.event_name = FootstepEventsClass.EVENT_NAME
	rig_emitter.unit_size = 6.0
	rig_emitter.area_mask = 1
	add_child(rig_emitter)

	animation_sync = OpenDouAnimationSyncClass.new()
	animation_sync.name = "FootstepSync"
	animation_sync.default_footstep_event = FootstepEventsClass.EVENT_NAME
	animation_sync.auto_detect_surface = true
	add_child(animation_sync)
	animation_sync.bind_target_emitter(rig_emitter)

## Acumula distancia y dispara un paso cada stride_meters.
##
## El paso lo dispara la distancia y no una animacion porque no hay assets de
## animacion, igual que no hay de audio. En un proyecto real esto lo haria un method
## track de AnimationPlayer, que es para lo que AnimationSync esta construido.
func notify_moved(distance: float) -> void:
	if distance <= 0.0:
		return
	_distance_accumulator += distance
	while _distance_accumulator >= stride_meters:
		_distance_accumulator -= stride_meters
		step()

## Dispara una pisada con la superficie que haya bajo los pies.
func step() -> void:
	steps_taken += 1
	if animation_sync != null:
		animation_sync.trigger_footstep(steps_taken % 2)

## Ata el rig a un manager concreto.
##
## En una escena real no hace falta: el emisor y AnimationSync resuelven el autoload
## /root/OpenDou por su cuenta. Existe para que un test pueda medir contra su propio
## manager en lugar de contra el global, que otras suites comparten.
func bind_event_manager(manager) -> void:
	if rig_emitter != null:
		rig_emitter.set_event_manager(manager)
	if animation_sync != null:
		animation_sync.set_event_manager(manager)
