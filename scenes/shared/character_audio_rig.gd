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

const FootstepEventsClass = preload("res://scenes/shared/footstep_events.gd")

## Metros recorridos entre pisada y pisada.
@export var stride_meters: float = 1.6

## Pasos dados desde que existe el rig. Solo informativo y para los tests.
var steps_taken: int = 0

var rig_emitter: OpenDouEventPlayer3D = null
var animation_sync: OpenDouAnimationSync = null

var _distance_accumulator: float = 0.0

func _ready() -> void:
	# Los nodos vienen de la ESCENA, no se fabrican aqui. Ver
	# .agents/rules/04_scene_composition.md.
	rig_emitter = $RigEmitter
	animation_sync = $FootstepSync

	# El nombre del evento vive en FootstepEvents y se escribe tambien en la escena, que
	# es donde un disenador lo veria. Si alguna vez divergen, este aviso lo dice en lugar
	# de dejar pisadas mudas sin explicacion.
	if rig_emitter.event_name != FootstepEventsClass.EVENT_NAME:
		push_warning("[CharacterAudioRig] la escena dice event_name='%s' y FootstepEvents dice '%s'." % [
			str(rig_emitter.event_name), str(FootstepEventsClass.EVENT_NAME)])

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
