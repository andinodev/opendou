class_name MonsoonTelemetry
extends CanvasLayer

## Muestra en pantalla lo que el pool esta decidiendo cada frame.
##
## Existe porque la tesis de la demo es un numero: 200 emisores y 32 voces. Sin verlo,
## la escena solo suena a lluvia.

var label: Label = null

var _demo: Node = null

func _ready() -> void:
	layer = 10
	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(280.0, 0.0)
	add_child(panel)

	label = Label.new()
	label.text = "..."
	panel.add_child(label)

## Ata la telemetria a la demo que la alimenta.
func bind_demo(demo: Node) -> void:
	_demo = demo

func _process(_delta: float) -> void:
	if _demo == null or label == null or not _demo.has_method("get_telemetry"):
		return
	var t: Dictionary = _demo.get_telemetry()
	label.text = "\n".join([
		"OpenDou — El monzon",
		"instancias : %d" % int(t.get("instances", 0)),
		"fisicas    : %d / %d" % [int(t.get("physical", 0)), int(t.get("budget", 0))],
		"virtuales  : %d" % int(t.get("virtual", 0)),
		"raycasts   : %d / %d" % [int(t.get("raycasts", 0)), int(t.get("raycast_budget", 0))],
		"ventana HDR: %.1f dB" % float(t.get("hdr_top_db", 0.0)),
		"",
		"T = trueno   F8 = monitor",
	])
