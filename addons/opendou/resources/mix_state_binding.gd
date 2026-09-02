@tool
class_name MixStateBinding
extends Resource

## Mientras el grupo de estado este en state_name, la instantanea snapshot_name esta apilada.
## Es la forma correcta de "baja salud" o "pausa": un estado del juego arrastra una mezcla.
## Recurso y no nodo porque no tiene posicion ni ciclo de vida en la escena.

@export var state_group: StringName = &""
@export var state_name: StringName = &""
@export var snapshot_name: StringName = &""
@export var blend_sec: float = -1.0
@export var priority: int = 0
