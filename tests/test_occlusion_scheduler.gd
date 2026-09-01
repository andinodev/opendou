class_name TestOcclusionScheduler
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OcclusionSchedulerClass = preload("res://addons/opendou/runtime/spatial/occlusion_scheduler.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")

func run_all_async(tree: SceneTree):
	var a := OpenDouAssertClass.new("occlusion_scheduler")

	var sched = OcclusionSchedulerClass.new()
	sched.raycasts_per_frame = 3

	var node := Node3D.new()
	tree.root.add_child(node)
	await tree.process_frame
	await tree.physics_frame
	var world := node.get_world_3d()

	# 20 voces cercanas al oyente: todas elegibles, pero el presupuesto manda.
	var near_instances: Array = []
	for i in range(20):
		var def = AudioEventDefClass.new(&"Occ")
		var inst = EventInstanceClass.new(def)
		inst.set_position(Vector3(float(i) * 0.2, 0.0, 1.0))
		inst.play()
		near_instances.append(inst)

	var launched: int = sched.process(near_instances, Vector3.ZERO, world)
	a.eq(launched, 3, "no se lanzan mas raycasts que el presupuesto")
	a.eq(sched.raycasts_this_frame, 3, "el contador refleja el presupuesto")
	a.eq(sched.last_processed_ids.size(), 3, "se atendieron exactamente 3 voces")

	# En frames sucesivos el cursor avanza y atiende a otras voces: sin reparto
	# round-robin, las mismas 3 monopolizarian el presupuesto para siempre.
	var first_batch: Array = sched.last_processed_ids.duplicate()
	sched.process(near_instances, Vector3.ZERO, world)
	a.ok(sched.last_processed_ids != first_batch, "el reparto round-robin avanza")

	# Las voces en LOD culleado no consumen presupuesto.
	var far_instances: Array = []
	for i in range(10):
		var fdef = AudioEventDefClass.new(&"FarOcc")
		var finst = EventInstanceClass.new(fdef)
		finst.set_position(Vector3(500.0, 0.0, 0.0))
		finst.play()
		far_instances.append(finst)
	a.eq(sched.process(far_instances, Vector3.ZERO, world), 0,
		"las voces lejanas no gastan raycasts")

	# Sin mundo fisico no se lanza nada, en lugar de fallar.
	a.eq(sched.process(near_instances, Vector3.ZERO, null), 0, "sin mundo 3D no lanza raycasts")

	# Ningun emisor debe crear su propio OcclusionManager: con 200 emisores eran
	# 200 managers y un coste que crecia sin limite.
	var emitter = OpenDouEventPlayer3DClass.new()
	a.has_no_property(emitter, "_occlusion_manager", "el emisor ya no tiene manager propio")
	emitter.free()

	tree.root.remove_child(node)
	node.free()
	return a
