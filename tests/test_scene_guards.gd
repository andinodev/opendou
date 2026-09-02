class_name TestSceneGuards
extends RefCounted

## Guardas de la fase 5 sobre scenes/.
##
## Dos son estaticas -texto de los archivos- y una es real: instancia las cuatro escenas
## y recorre el arbol construido. La diferencia importa: contar los preload de un script
## diria que la escena "usa" un nodo que quizas nunca instancia.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")

## Las cuatro escenas de la fase.
const SCENES: Array[String] = [
	"res://scenes/rig_bench/rig_bench.tscn",
	"res://scenes/demos/keel/keel_demo.tscn",
	"res://scenes/demos/monsoon/monsoon_demo.tscn",
	"res://scenes/demos/cabin/cabin_demo.tscn",
	"res://scenes/demos/street/street_demo.tscn",
	"res://scenes/demos/workshop/workshop_demo.tscn",
]

## Los 15 tipos de nodo del plugin. El unico que las demos NO instancian, por decision
## del spec, es opendou_event_player_2d.gd: queda cubierto solo por sus tests.
const NODE_SCRIPTS: Array[String] = [
	"opendou_acoustic_debugger_3d.gd", "opendou_acoustic_geometry_bake.gd",
	"opendou_animation_sync.gd", "opendou_audible_monitor.gd",
	"opendou_event_player.gd", "opendou_event_player_2d.gd",
	"opendou_event_player_3d.gd", "opendou_granular_emitter_3d.gd",
	"opendou_multi_position_emitter_3d.gd", "opendou_music_player.gd",
	"opendou_parameter_area_3d.gd", "opendou_portal_3d.gd",
	"opendou_reflector_3d.gd", "opendou_room_3d.gd",
	"opendou_spline_emitter_3d.gd",
	"opendou_physics_impact_3d.gd", "opendou_dialogue_emitter_3d.gd",
	"opendou_listener_3d.gd", "opendou_acoustic_volume_3d.gd",
	"opendou_sound_indicator.gd", "opendou_ai_hearing_3d.gd",
]

## Sin demo por decision: el 2D (spec de la Fase 5) y los cuatro nodos de la Fase 10 (el
## oyente y el entorno todavia no tienen escena que los luzca; queda anotado en current.md).
const EXPECTED_UNCOVERED: Array[String] = [
	"opendou_event_player_2d.gd", "opendou_listener_3d.gd", "opendou_acoustic_volume_3d.gd",
	"opendou_sound_indicator.gd", "opendou_ai_hearing_3d.gd",
]

## Extensiones de audio que no puede referenciar ningun archivo de scenes/.
const AUDIO_EXTENSIONS: Array[String] = [".wav", ".ogg", ".mp3"]

## Lo que cada escena tiene que DECLARAR en su .tscn.
##
## Se lee el estado empaquetado, no el arbol instanciado, y es deliberado: lo que se
## quiere afirmar es que los nodos estan EN LA ESCENA, no que un _ready() los fabrico.
## Ver .agents/rules/04_scene_composition.md.
const COMPOSITION: Array[Dictionary] = [
	{
		"scene": "res://scenes/rig_bench/rig_bench.tscn",
		"min_nodes": 8,
		"requires": [],
	},
	{
		"scene": "res://scenes/demos/keel/keel_demo.tscn",
		"min_nodes": 20,
		"requires": [
			"opendou_room_3d.gd", "opendou_portal_3d.gd", "opendou_reflector_3d.gd",
			"opendou_parameter_area_3d.gd", "opendou_acoustic_geometry_bake.gd",
			"opendou_acoustic_debugger_3d.gd", "opendou_event_player_3d.gd",
		],
	},
	{
		"scene": "res://scenes/demos/monsoon/monsoon_demo.tscn",
		"min_nodes": 10,
		"requires": [
			"opendou_multi_position_emitter_3d.gd", "opendou_spline_emitter_3d.gd",
			"opendou_granular_emitter_3d.gd", "opendou_audible_monitor.gd",
		],
	},
	{
		"scene": "res://scenes/demos/cabin/cabin_demo.tscn",
		"min_nodes": 10,
		"requires": [
			"opendou_music_player.gd", "opendou_event_player.gd", "opendou_room_3d.gd",
		],
	},
	# La interfaz tambien se compone: el hub construia sus botones en codigo y la guarda
	# no lo veia porque solo miraba las demos.
	{"scene": "res://scenes/demos/demo_hub.tscn", "min_nodes": 12, "requires": []},
	{"scene": "res://scenes/shared/demo_card.tscn", "min_nodes": 6, "requires": []},
	{"scene": "res://scenes/shared/demo_hud.tscn", "min_nodes": 12, "requires": []},
	{"scene": "res://scenes/shared/pause_menu.tscn", "min_nodes": 24, "requires": []},
	{"scene": "res://scenes/shared/bus_row.tscn", "min_nodes": 5, "requires": []},
	{
		"scene": "res://scenes/demos/workshop/workshop_demo.tscn",
		"min_nodes": 40,
		"requires": [
			"opendou_room_3d.gd", "opendou_event_player_3d.gd", "opendou_event_player.gd",
			"opendou_parameter_area_3d.gd", "opendou_physics_impact_3d.gd",
			"opendou_dialogue_emitter_3d.gd", "opendou_multi_position_emitter_3d.gd",
			"opendou_acoustic_geometry_bake.gd", "opendou_acoustic_debugger_3d.gd",
		],
	},
	{
		"scene": "res://scenes/demos/street/street_demo.tscn",
		"min_nodes": 200,
		"requires": [
			"opendou_room_3d.gd", "opendou_portal_3d.gd", "opendou_reflector_3d.gd",
			"opendou_acoustic_geometry_bake.gd", "opendou_event_player_3d.gd",
			"opendou_spline_emitter_3d.gd", "opendou_acoustic_debugger_3d.gd",
		],
	},
]

## Criterio de composicion: los nodos van en la escena, no en un build().
static func run_composition() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("scene_composition")

	for entry in COMPOSITION:
		var path: String = str(entry["scene"])
		var packed: PackedScene = load(path)
		a.ok(packed != null, "la escena '%s' carga" % path)
		if packed == null:
			continue
		var state: SceneState = packed.get_state()

		# Una escena con un solo nodo es un script disfrazado de escena.
		a.gt(float(state.get_node_count()), 1.0,
			"'%s' declara mas de un nodo: una raiz sola es un build() disfrazado" % path)
		a.gt(float(state.get_node_count()), float(entry["min_nodes"]) - 0.5,
			"'%s' declara al menos %d nodos, y declara %d" % [path, int(entry["min_nodes"]), state.get_node_count()])

		var declared: Dictionary = _declared_opendou_scripts(state)
		for required in entry["requires"]:
			a.ok(declared.has(required),
				"'%s' declara %s en la escena, no lo fabrica en codigo" % [path, required])

	return a

## Nombres de archivo de los scripts de addons/opendou/nodes/ declarados en la escena.
##
## SceneState.get_node_type() devuelve el tipo BASE -Node3D, Area3D-, no el class_name,
## asi que hay que mirar la propiedad `script` de cada nodo.
static func _declared_opendou_scripts(state: SceneState) -> Dictionary:
	var out: Dictionary = {}
	for i in range(state.get_node_count()):
		for p in range(state.get_node_property_count(i)):
			if state.get_node_property_name(i, p) != &"script":
				continue
			var value = state.get_node_property_value(i, p)
			if value == null:
				continue
			var script_path: String = str(value.resource_path)
			if script_path.begins_with("res://addons/opendou/nodes/"):
				out[script_path.get_file()] = true
	return out

## Guardas estaticas de los criterios 2 y 3.
static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("scene_guards")

	var scripts: Array[String] = _files_in("res://scenes", ".gd")
	a.gt(float(scripts.size()), 5.0, "la guarda inspecciono los scripts de scenes/")

	# Criterio 2, que cierra la observacion 2: cero llamadas a .play() nativo. La
	# medicion original fue 26 llamadas nativas frente a 6 a play_event().
	var play_offenders: Array[String] = []
	for path in scripts:
		var text: String = _read(path)
		# Los nodos de OpenDou tienen su propio play(): el MusicPlayer arranca su suite,
		# el granular sus granos. Llamarlos NO es saltarse el plugin, es usarlo. Se
		# permiten leyendo el TIPO DECLARADO de cada variable del archivo, que es una
		# comprobacion real y no una excepcion escrita a dedo.
		var opendou_vars: Dictionary = _opendou_typed_vars(text)
		for line in text.split("\n"):
			var l: String = line.strip_edges()
			if l.begins_with("#"):
				continue
			# ".play(" NO coincide con ".play_event(" ni con ".play_granular(", que son
			# los caminos permitidos. autoplay y auto_play_event son propiedades.
			if not l.contains(".play("):
				continue
			var allowed: bool = false
			for var_name in opendou_vars:
				if l.contains("%s.play(" % var_name):
					allowed = true
					break
			if not allowed:
				play_offenders.append("%s: %s" % [path, l])
	a.eq(play_offenders.size(), 0,
		"ningun script de scenes/ llama a .play() nativo, sobran: %s" % str(play_offenders))

	# Criterio 3: cero assets de audio referenciados, ni en .gd ni en .tscn.
	var all_files: Array[String] = _files_in("res://scenes", "")
	a.gt(float(all_files.size()), float(scripts.size()) - 0.5,
		"la guarda de assets inspecciono al menos los scripts")
	var asset_offenders: Array[String] = []
	for path in all_files:
		var text: String = _read(path)
		for ext in AUDIO_EXTENSIONS:
			if text.contains(ext):
				asset_offenders.append("%s -> %s" % [path, ext])
	a.eq(asset_offenders.size(), 0,
		"ningun archivo de scenes/ referencia audio pregrabado, sobran: %s" % str(asset_offenders))

	return a

## Nombres de variables declaradas con un tipo de nodo de OpenDou en este archivo.
##
## Reconoce `var x: OpenDouAlgo`, `@onready var x: OpenDouAlgo` y `var x := OpenDouAlgo`.
static func _opendou_typed_vars(text: String) -> Dictionary:
	var out: Dictionary = {}
	var pattern := RegEx.new()
	pattern.compile("var\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*:=?\\s*:?\\s*(OpenDou[A-Za-z0-9_]*)")
	for m in pattern.search_all(text):
		out[m.get_string(1)] = m.get_string(2)
	return out

## Criterios 10 y 4: recorre el arbol REAL de las cuatro escenas.
static func run_coverage_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("scene_node_coverage")

	var covered: Dictionary = {}
	for scene_path in SCENES:
		a.ok(ResourceLoader.exists(scene_path), "la escena '%s' existe" % scene_path)
		var packed = load(scene_path)
		if packed == null:
			continue
		var root = packed.instantiate()

		# El monzon con sus 200 emisores multiplica el tiempo de esta suite sin cambiar
		# lo que afirma. La propiedad se asigna ANTES de add_child, porque _ready()
		# construye la escena entera.
		if "emitter_count" in root:
			root.emitter_count = 24
		if "physical_voice_budget" in root:
			root.physical_voice_budget = 8
		if "leaves_count" in root:
			root.leaves_count = 6

		tree.root.add_child(root)
		await tree.process_frame
		await tree.physics_frame
		await tree.process_frame

		# Criterio 4: el rig esta en las cuatro escenas.
		a.gt(float(_count_rigs(root)), 0.0, "'%s' instancia el rig de personaje" % scene_path)

		_collect_node_scripts(root, covered)

		# Las escenas postean al autoload, que sobrevive a liberarlas: sin stop_all() la
		# siguiente escena mediria tambien las instancias de la anterior.
		var autoload_manager = tree.root.get_node_or_null("OpenDou")
		if autoload_manager != null:
			autoload_manager.stop_all()

		# La camara del jugador quedo current: sin clear_current() el viewport la sigue
		# referenciando y queda una fuga.
		_release_current(root)
		tree.root.remove_child(root)
		root.free()
		await tree.process_frame

	# Todos menos los no cubiertos por decision, y ninguno de esos aparece.
	a.eq(covered.size(), NODE_SCRIPTS.size() - EXPECTED_UNCOVERED.size(),
		"las escenas instancian %d de los %d tipos de nodo, cubiertos: %s" % [NODE_SCRIPTS.size() - EXPECTED_UNCOVERED.size(), NODE_SCRIPTS.size(), str(covered.keys())])
	for script_name in EXPECTED_UNCOVERED:
		a.ok(not covered.has(script_name), "%s no lo instancia ninguna demo, por decision" % script_name)
	for script_name in NODE_SCRIPTS:
		if EXPECTED_UNCOVERED.has(script_name):
			continue
		a.ok(covered.has(script_name), "alguna escena instancia %s" % script_name)

	return a

## Cuenta los CharacterAudioRig del arbol.
static func _count_rigs(node: Node) -> int:
	var count: int = 0
	if node.get_script() != null and str(node.get_script().resource_path).ends_with("character_audio_rig.gd"):
		count += 1
	for child in node.get_children():
		count += _count_rigs(child)
	return count

## Acumula los nombres de archivo de los scripts de addons/opendou/nodes/ presentes.
static func _collect_node_scripts(node: Node, out: Dictionary) -> void:
	var script = node.get_script()
	if script != null:
		var path: String = str(script.resource_path)
		if path.begins_with("res://addons/opendou/nodes/"):
			out[path.get_file()] = true
	for child in node.get_children():
		_collect_node_scripts(child, out)

## Suelta camaras y oyentes antes de liberar la escena.
static func _release_current(node: Node) -> void:
	if node is Camera3D and node.is_current():
		node.clear_current()
	elif node is AudioListener3D and node.is_current():
		node.clear_current()
	for child in node.get_children():
		_release_current(child)

static func _read(path: String) -> String:
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text

## Archivos bajo dir_path, recursivo. suffix vacio devuelve todos.
static func _files_in(dir_path: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full: String = dir_path.path_join(name)
		if dir.current_is_dir():
			out.append_array(_files_in(full, suffix))
		elif suffix.is_empty() or name.ends_with(suffix):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out
