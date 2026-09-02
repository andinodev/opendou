class_name TestPhysicsImpact
extends RefCounted

## Fase 11: un RigidBody3D con OpenDouPhysicsImpact3D suena solo al chocar, con la fuerza,
## la masa y el material del otro cuerpo. Fisica headless real.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const AudioSwitchContainerClass = preload("res://addons/opendou/resources/containers/audio_switch_container.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const ImpactScript = preload("res://addons/opendou/nodes/opendou_physics_impact_3d.gd")

static func _floor(tree: SceneTree, surface: StringName) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	cs.shape = box
	body.add_child(cs)
	body.set_meta("surface_type", surface)
	tree.root.add_child(body)
	body.global_position = Vector3(0, -0.5, 0)
	return body

## Cuerpo de 1 kg a `height` m sobre el suelo, cayendo a `speed` m/s, con el nodo de impacto.
## Devuelve [cuerpo, nodo de impacto, golpes].
static func _drop(tree: SceneTree, manager, x: float, height: float, speed: float, threshold: float = 0.5) -> Array:
	var rb := RigidBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.4, 0.4)
	cs.shape = box
	rb.add_child(cs)
	rb.mass = 1.0
	var impact = ImpactScript.new()
	impact.event_name = &"Clank"
	impact.min_speed_mps = threshold
	rb.add_child(impact)
	tree.root.add_child(rb)
	impact.set_event_manager(manager)
	rb.global_position = Vector3(x, 0.2 + height, 0)
	rb.linear_velocity = Vector3(0, -speed, 0)
	var hits: Array = []
	impact.impact_posted.connect(func(s, m, mat, p): hits.append({"speed": s, "mass": m, "material": mat, "position": p, "active": manager.active_instances.size()}))
	return [rb, impact, hits]

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("physics_impact")
	var manager = load("res://addons/opendou/runtime/audio_event_manager.gd").new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.make_current()
	# Evento con switch de material: la rama Metal y la rama Concrete son tonos distintos.
	var tone_src = load("res://tests/test_emitter_physics.gd")
	var sw = AudioSwitchContainerClass.new(&"Material", &"Concrete")
	sw.set_state_node(&"Concrete", AudioPhysicalNodeClass.new(tone_src._tone(300.0, 0.3)))
	sw.set_state_node(&"Metal", AudioPhysicalNodeClass.new(tone_src._tone(2000.0, 0.3)))
	var def = AudioEventDefClass.new(&"Clank")
	def.root_container = sw
	def.stream_length = 0.3
	manager.register_event_definition(def)
	var floor := _floor(tree, &"Metal")

	var slow = _drop(tree, manager, 0.0, 0.02, 2.0)
	var fast = _drop(tree, manager, 3.0, 0.02, 8.0)
	for i in range(30):
		await tree.physics_frame
	var slow_hits: Array = slow[2]
	var fast_hits: Array = fast[2]
	a.ok(slow_hits.size() >= 1, "el cuerpo lento choca y postea (%d)" % slow_hits.size())
	a.ok(fast_hits.size() >= 1, "el rapido tambien (%d)" % fast_hits.size())
	if slow_hits.size() >= 1 and fast_hits.size() >= 1:
		var ratio: float = fast_hits[0].speed / maxf(slow_hits[0].speed, 0.001)
		print("[OpenDou] impactos: lento %.2f m/s, rapido %.2f m/s (x%.2f), material %s, masa %.1f, punto %s" % [slow_hits[0].speed, fast_hits[0].speed, ratio, str(fast_hits[0].material), fast_hits[0].mass, str(fast_hits[0].position)])
		a.ok(ratio >= 3.2 and ratio <= 4.8, "ImpactForce del rapido entre 3.2 y 4.8 veces la del lento (x%.2f)" % ratio)
		a.eq(String(fast_hits[0].material), "Metal", "el material es el del otro cuerpo")
		a.approx(fast_hits[0].mass, 1.0, "y la masa la del propio", 0.01)
		a.eq(String(manager.sync_manager.get_switch(&"Material", fast[1])), "Metal", "el switch de material quedo en la entidad")
		a.ok(int(fast_hits[0].active) >= 1, "el evento sonaba al postear (%d voces activas)" % int(fast_hits[0].active))
	# Bajo el umbral: nada. La gravedad en 2 cm suma hasta 0.66 m/s a los 0.2 iniciales, asi
	# que el umbral de este caso es 1.0.
	var soft = _drop(tree, manager, -3.0, 0.02, 0.2, 1.0)
	for i in range(30):
		await tree.physics_frame
	a.eq((soft[2] as Array).size(), 0, "a 0.2 m/s (0.66 con la gravedad) con umbral 1.0, ningun evento")
	for trio in [slow, fast, soft]:
		tree.root.remove_child(trio[0]); trio[0].free()
	tree.root.remove_child(floor); floor.free()
	manager.stop_all()
	tree.root.remove_child(cam); cam.free()
	tree.root.remove_child(manager); manager.free()
	return a
