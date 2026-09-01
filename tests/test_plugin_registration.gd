class_name TestPluginRegistration
extends RefCounted

## Verifica el registro de tipos del plugin y que no use API deprecada.
##
## Las aserciones sobre plugin.gd son estaticas, leyendo el archivo como texto: un
## EditorPlugin no se puede instanciar de forma util en headless.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")

const PLUGIN_PATH: String = "res://addons/opendou/plugin.gd"

## Los 15 nodos declarativos que el plugin expone.
const DECLARATIVE_NODES: Array[String] = [
	"OpenDouEventPlayer", "OpenDouEventPlayer2D", "OpenDouEventPlayer3D",
	"OpenDouRoom3D", "OpenDouPortal3D", "OpenDouReflector3D",
	"OpenDouMusicPlayer", "OpenDouAudibleMonitor", "OpenDouAcousticDebugger3D",
	"OpenDouSplineEmitter3D", "OpenDouGranularEmitter3D", "OpenDouParameterArea3D",
	"OpenDouMultiPositionEmitter3D", "OpenDouAcousticGeometryBake", "OpenDouAnimationSync",
]

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("plugin_registration")

	# Los 15 nodos siguen en el registro global CON icono. Es lo que hace que
	# retirar add_custom_type no pierda nada: el dialogo "Crear nodo" toma la clase
	# y el icono de aqui.
	var registered: Dictionary = {}
	for entry in ProjectSettings.get_global_class_list():
		registered[str(entry.get("class", ""))] = str(entry.get("icon", ""))

	for node_class in DECLARATIVE_NODES:
		a.ok(registered.has(node_class), "%s esta en el registro global" % node_class)
		if registered.has(node_class):
			a.ok(not String(registered[node_class]).is_empty(),
				"%s tiene icono registrado" % node_class)

	# El plugin no debe registrar los tipos por segunda via.
	var f = FileAccess.open(PLUGIN_PATH, FileAccess.READ)
	if f == null:
		a.ok(false, "no se pudo leer plugin.gd")
		return a
	var src: String = f.get_as_text()
	f.close()

	a.ok(not src.contains("add_custom_type("),
		"el plugin no usa add_custom_type: duplicaba las entradas del dialogo")
	a.ok(not src.contains("remove_custom_type("),
		"el plugin no usa remove_custom_type")

	# API deprecada desde Godot 4.2.
	a.ok(not src.contains("get_editor_interface()"),
		"el plugin usa el singleton EditorInterface y no get_editor_interface()")

	# No debe anunciar un main screen que no existe.
	#
	# Una sola asercion precisa, no una compuesta con `or`: un `or` entre dos
	# comprobaciones puede pasar por el lado equivocado y no probar lo que dice.
	a.ok(src.contains("func _has_main_screen() -> bool:\n\treturn false"),
		"_has_main_screen devuelve false")

	# Y el docstring no debe prometerlo.
	a.ok(not src.contains("Main Screen workspace"),
		"el docstring del plugin no promete un Main Screen workspace")

	return a
