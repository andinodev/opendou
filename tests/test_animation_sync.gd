class_name TestAnimationSyncClass
extends RefCounted

## Aserciones de OpenDouAnimationSync.
##
## La version anterior tenia diez "tests" y solo cuatro afirmaban algo -que un setter
## habia asignado una variable-. Los otros seis llamaban al metodo y seguian, con
## comentarios del tipo "should query surface without crashing". Por eso no pudo
## detectar ni la observacion 27 ni la 28, que llevaban ahi desde que el nodo existe.
##
## Ahora cada bloque afirma un comportamiento observable: a donde va el evento, que
## superficie queda en el switch, que definicion se eligio, y si el RTPC se movio.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAnimationSyncClass = preload("res://addons/opendou/nodes/opendou_animation_sync.gd")
const AudioEventManagerClass = preload("res://addons/opendou/runtime/audio_event_manager.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

## Bloques que no necesitan el arbol.
static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("animation_sync")

	# Valores por defecto. Los declara el contrato del nodo, asi que se afirman.
	var sync_node = OpenDouAnimationSyncClass.new()
	a.ok(sync_node != null, "OpenDouAnimationSync se instancia")
	a.ok(sync_node.auto_detect_surface, "auto_detect_surface por defecto activo")
	a.eq(str(sync_node.default_footstep_event), "Footstep", "evento de pisada por defecto")
	a.ok(sync_node.blend_space_sync_enabled, "sincronizacion de blend space activa")

	# Fuera del arbol _ready no corre, asi que no hay manager y las llamadas se quedan
	# calladas. Antes se creaba aqui un AudioEventManager huerfano que nunca se liberaba.
	a.ok(sync_node.get_event_manager() == null,
		"fuera del arbol no hay manager, y no se fabrica uno huerfano")

	# bind_* asigna, y ademas conecta la senal de cambio de animacion: sin esa conexion
	# los indices de la linea de tiempo no se reinician al cambiar de animacion y la
	# segunda vuelta de la misma animacion no dispara nada.
	var anim_player := AnimationPlayer.new()
	var anim_lib := AnimationLibrary.new()
	var anim := Animation.new()
	anim.length = 1.0
	anim_lib.add_animation(&"Run", anim)
	anim_player.add_animation_library(&"", anim_lib)
	sync_node.bind_animation_player(anim_player)
	a.ok(sync_node.animation_player == anim_player, "bind_animation_player asigna")
	a.ok(anim_player.animation_changed.is_connected(sync_node._on_animation_changed),
		"y conecta animation_changed, sin lo cual los indices no se reinician")

	# Llamarlo dos veces no duplica la conexion.
	sync_node.bind_animation_player(anim_player)
	a.eq(anim_player.animation_changed.get_connections().size(), 1,
		"volver a atar el mismo AnimationPlayer no duplica la conexion")

	var emitter = OpenDouEventPlayer3DClass.new()
	sync_node.bind_target_emitter(emitter)
	a.ok(sync_node.target_emitter == emitter, "bind_target_emitter asigna")

	# Robustez: con los objetivos liberados no revienta Y no deja el nodo inservible.
	# La version anterior afirmaba esto en un comentario.
	anim_player.free()
	emitter.free()
	sync_node.trigger_audio_event(&"Explosion")
	sync_node.trigger_footstep(0)
	sync_node.process_blend_space_rtpcs()
	a.ok(not is_instance_valid(sync_node.animation_player),
		"el AnimationPlayer liberado se detecta como invalido")
	a.ok(sync_node.get_event_manager() == null, "y el nodo sigue en pie tras las llamadas")

	sync_node.free()
	return a


## Bloques que necesitan el arbol: es donde se ve a donde va cada cosa.
static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("animation_sync_wired")

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	var host := Node3D.new()
	host.position = Vector3(5.0, 0.0, -3.0)
	tree.root.add_child(host)
	var sync = OpenDouAnimationSyncClass.new()
	host.add_child(sync)
	await tree.process_frame

	# Observacion 28: dentro del arbol resuelve el autoload.
	var autoload_manager = tree.root.get_node_or_null("OpenDou")
	a.ok(autoload_manager != null, "el autoload OpenDou existe")
	a.ok(sync.get_event_manager() == autoload_manager,
		"dentro del arbol resuelve el autoload, no una copia huerfana")

	# Y se le puede imponer otro, que es como esta suite mide sin tocar el global.
	sync.set_event_manager(manager)
	a.ok(sync.get_event_manager() == manager, "set_event_manager impone el manager")

	var tone := AudioSynthesizerClass.create_tone(660.0, 0.15, 0.5)
	var beep = AudioEventDefClass.new(&"Beep", tone)
	beep.stream_length = 0.15
	manager.register_event_definition(beep)

	# Observacion 27: sin emisor atado, postea al manager con la posicion del padre.
	# Antes pasaba un Vector3 al parametro caller: Node y la llamada abortaba.
	var before: int = manager.active_instances.size()
	sync.trigger_audio_event(&"Beep")
	a.eq(manager.active_instances.size(), before + 1, "sin emisor atado postea al manager")
	var posted = manager.active_instances[manager.active_instances.size() - 1]
	a.approx(posted.emitter_position.x, 5.0, "con la posicion del padre", 0.01)
	a.ok(posted.has_spatial_position, "marcada como espacial")

	# Con emisor atado el evento va POR el emisor, no por el manager a pelo: es lo que
	# hace que herede unit_size, atenuacion y area_mask del inspector.
	var emitter = OpenDouEventPlayer3DClass.new()
	emitter.set_event_manager(manager)
	host.add_child(emitter)
	await tree.process_frame
	sync.bind_target_emitter(emitter)
	sync.trigger_audio_event(&"Beep")
	a.ok(emitter.active_instance != null, "con emisor atado el evento pasa por el emisor")
	a.ok(emitter.active_instance.get_bound_player() == emitter,
		"y el emisor queda como su voz fisica")

	# El surface_override no raycastea: fija el switch tal cual, sin suelo debajo.
	sync.trigger_footstep(0, &"Glass")
	a.eq(str(manager.get_switch(&"SurfaceType")), "Glass",
		"surface_override fija el switch sin necesidad de suelo")

	# Y si existe un evento Footstep_<Superficie>, lo elige por encima del de por
	# defecto. Nadie lo habia comprobado nunca.
	var glass_def = AudioEventDefClass.new(&"Footstep_Glass", AudioSynthesizerClass.create_tone(1800.0, 0.1, 0.4))
	glass_def.stream_length = 0.1
	manager.register_event_definition(glass_def)
	var default_def = AudioEventDefClass.new(&"Footstep", AudioSynthesizerClass.create_tone(200.0, 0.1, 0.4))
	default_def.stream_length = 0.1
	manager.register_event_definition(default_def)

	emitter.active_instance = null
	sync.trigger_footstep(0, &"Glass")
	a.ok(emitter.active_instance != null, "la pisada con superficie produjo instancia")
	a.eq(str(emitter.active_instance.definition.event_name), "Footstep_Glass",
		"elige el evento por superficie sobre el de por defecto")

	# Sin evento por superficie cae al de por defecto.
	emitter.active_instance = null
	sync.trigger_footstep(0, &"Asphalt")
	a.ok(emitter.active_instance != null, "la pisada sin evento por superficie produjo instancia")
	a.eq(str(emitter.active_instance.definition.event_name), "Footstep",
		"sin evento por superficie cae a default_footstep_event")

	# set_rtpc desde animacion llega al manager. Va interpolado, asi que se mide tras
	# unos frames: afirmarlo en el mismo frame seria afirmar el valor inicial.
	sync.set_rtpc(&"Movement_Speed", 12.0)
	for i in range(20):
		await tree.process_frame
	var speed: float = manager.get_rtpc(&"Movement_Speed")
	a.gt(speed, 1.0, "el RTPC de animacion llego al manager y se esta moviendo")
	a.lt(speed, 12.01, "sin pasarse del valor pedido")

	# La linea de tiempo declarativa dispara los eventos en su instante, UNA sola vez.
	sync.event_bindings = {
		&"Run": [
			{"time": 0.2, "event": &"Beep"},
			{"time": 0.6, "event": &"Beep"},
		]
	}
	var timeline_player := AnimationPlayer.new()
	var timeline_lib := AnimationLibrary.new()
	var timeline_anim := Animation.new()
	timeline_anim.length = 1.0
	timeline_lib.add_animation(&"Run", timeline_anim)
	timeline_player.add_animation_library(&"", timeline_lib)
	host.add_child(timeline_player)
	await tree.process_frame
	sync.bind_animation_player(timeline_player)

	emitter.active_instance = null
	timeline_player.play(&"Run")
	timeline_player.seek(0.3, true)
	await tree.process_frame
	a.ok(emitter.active_instance != null,
		"el primer marcador de la linea de tiempo disparo su evento")

	# El mismo marcador no vuelve a disparar mientras siga la misma animacion.
	emitter.active_instance = null
	await tree.process_frame
	a.ok(emitter.active_instance == null, "y no vuelve a disparar el mismo marcador")

	# Al pasar por el segundo instante, si.
	timeline_player.seek(0.7, true)
	await tree.process_frame
	a.ok(emitter.active_instance != null, "el segundo marcador disparo al llegar su instante")

	# Blend space: una propiedad real del AnimationTree se mapea a un RTPC.
	var blend_tree := AnimationNodeBlendTree.new()
	blend_tree.add_node(&"mix", AnimationNodeBlend2.new(), Vector2.ZERO)
	var anim_tree := AnimationTree.new()
	# active = false: sin AnimationPlayer valido un AnimationTree activo emite errores
	# del motor, y el runner los trata como fatales. Los parametros existen igual.
	anim_tree.active = false
	anim_tree.tree_root = blend_tree
	host.add_child(anim_tree)
	await tree.process_frame

	sync.bind_animation_tree(anim_tree)
	sync.blend_space_rtpc_map = {"parameters/mix/blend_amount": &"Locomotion_Intensity"}
	anim_tree.set("parameters/mix/blend_amount", 0.75)
	sync.process_blend_space_rtpcs()
	for i in range(20):
		await tree.process_frame
	var intensity: float = manager.get_rtpc(&"Locomotion_Intensity")
	a.gt(intensity, 0.05, "el parametro del blend tree llego al RTPC")
	a.lt(intensity, 0.76, "sin pasarse del valor del parametro")

	# Una ruta que no existe no inventa un RTPC.
	sync.blend_space_rtpc_map = {"parameters/no/existe": &"Ghost_Param"}
	sync.process_blend_space_rtpcs()
	await tree.process_frame
	a.ok(not manager.sync_manager.global_rtpcs.has(&"Ghost_Param"),
		"una ruta inexistente no crea un RTPC fantasma")

	manager.stop_all()
	tree.root.remove_child(host)
	host.free()
	tree.root.remove_child(manager)
	manager.free()
	return a
