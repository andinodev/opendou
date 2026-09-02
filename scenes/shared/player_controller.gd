class_name PlayerController
extends CharacterBody3D

## Jugador: entrada WASD, camara y EL OYENTE.
##
## Es andamio, no un sistema de personaje: caminar y mirar. Ni salto, ni escalada, ni
## maquina de estados de combate, que no es trabajo de audio.

@export var move_speed: float = 4.0
@export var look_sensitivity: float = 0.0025

## Si es falso, el jugador ignora teclado y raton. Lo apaga el menu de pausa: congela al
## jugador sin pausar el arbol, para que el audio siga sonando mientras se ajusta.
@export var input_enabled: bool = true

## El oyente. Vive aqui y NO en el rig, para que instanciar NPC no cree oyentes.
var listener: AudioListener3D = null
var camera: Camera3D = null
var rig: CharacterAudioRig = null

func _ready() -> void:
	# Los nodos vienen de la ESCENA. Ver .agents/rules/04_scene_composition.md.
	camera = $Camera
	listener = $Listener
	rig = $CharacterAudioRig
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# make_current() se llama aqui y no se marca en la escena porque AudioListener3D no
	# expone `current` como propiedad guardable: solo tiene el metodo.
	listener.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and camera != null:
		rotate_y(-event.relative.x * look_sensitivity)
		camera.rotate_x(-event.relative.y * look_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -1.2, 1.2)

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if input_enabled:
		input_dir = Vector2(
			Input.get_axis("ui_left", "ui_right"),
			Input.get_axis("ui_up", "ui_down")
		)
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	velocity.y -= 9.8 * delta
	var before := global_position
	move_and_slide()

	# La distancia horizontal real recorrida alimenta las pisadas: si choca con una
	# pared y no avanza, no hay pasos.
	if rig != null:
		var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
		rig.notify_moved(moved)
