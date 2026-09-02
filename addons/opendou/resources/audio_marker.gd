@tool
class_name AudioMarker
extends Resource

## Un punto con nombre dentro del audio de un evento. La instancia emite marker_reached(name)
## al cruzarlo con su reloj logico. Se autoran aqui o se leen del chunk `cue` de un WAV.

@export var name: StringName = &""
@export var time_sec: float = 0.0
