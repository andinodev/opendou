class_name DemoAudio
extends RefCounted

## Como llegan las demos a OpenDou: al manager y a los buses.

const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")

## El manager autoload, o null si no esta.
##
## Es el MISMO que resuelven los nodos declarativos en _get_manager(). Una demo que
## creara su propio AudioEventManager tendria dos a la vez: los emisores del rig
## postearian al autoload y la demo a su copia, con el estado partido en dos.
static func manager(node: Node) -> AudioEventManager:
	if node == null or not node.is_inside_tree():
		return null
	var root := node.get_tree().root
	if root != null and root.has_node("OpenDou"):
		var found = root.get_node("OpenDou")
		if found is AudioEventManager:
			return found
	return null

## Devuelve el nombre del bus, creandolo si hace falta. Idempotente.
##
## El proyecto no tiene default_bus_layout.tres: solo existe Master. Poner
## bus = "Music" sin crearlo antes produce un error del motor, y el runner de tests
## trata los errores del motor como fatales.
##
## Los buses NO se destruyen nunca. AudioServer.remove_bus(i) desplaza los indices
## siguientes, asi que un bus creado por una escena y borrado al salir romperia las
## rutas de las demas, incluidos los buses de reverb del pool de la Fase 2.
static func ensure_bus(bus_name: StringName, send_to: StringName = &"Master") -> StringName:
	if AudioServer.get_bus_index(String(bus_name)) >= 0:
		return bus_name
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, String(bus_name))
	AudioServer.set_bus_send(idx, String(send_to))
	return bus_name
