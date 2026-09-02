class_name TestInstanceLimiter
extends RefCounted

## Fase 8: max_instances existia y nadie lo aplicaba. Ahora limita por evento, por emisor y
## por radio, con cuatro politicas, y se afirma sobre el bus. Y stop(fade) hace fundido de
## verdad: antes ignoraba su parametro.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const SynthClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

static func _wait_ms(tree: SceneTree, ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await tree.process_frame

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("instance_limiter")
	var ManagerClass = load("res://addons/opendou/runtime/audio_event_manager.gd")
	var manager = ManagerClass.new()
	manager.hdr_enabled = false
	tree.root.add_child(manager)
	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.make_current()
	await tree.process_frame

	var tone: AudioStreamWAV = SynthClass.create_rain_ambient_loop(1.0)
	var def = AudioEventDefClass.new(&"Limited", tone)
	def.is_looping = true
	def.stream_length = 1.0
	def.target_bus = probe.bus_name()
	def.base_volume_db = -12.0
	manager.register_event_definition(def)
	manager.set_listener_position(Vector3.ZERO)

	# Defecto: sin limite. Las cuatro instancias existen.
	a.eq(def.max_instances, 0, "max_instances vale 0 (sin limite) por defecto")
	var instances: Array = []
	for i in range(4):
		var inst = manager.post_event(def, null)
		inst.set_position(Vector3(0, 0, -2))
		instances.append(inst)
	await _wait_ms(tree, 150)
	var peak_four: float = await probe.measure_peak_over_frames(tree, 20)
	var playing: int = 0
	for inst in instances:
		if inst != null and inst.is_playing():
			playing += 1
	a.eq(playing, 4, "sin limite, las cuatro instancias existen")
	manager.stop_all()
	await probe.await_silence(tree, 0.002, 30)

	# STEAL_OLDEST con maximo 3: la cuarta roba la primera; nunca suenan cuatro.
	def.max_instances = 3
	def.limit_policy = AudioEventDefClass.LimitPolicy.STEAL_OLDEST
	def.limit_fade_out_sec = 0.05
	instances.clear()
	for i in range(4):
		var inst = manager.post_event(def, null)
		a.ok(inst != null, "con robo, post_event %d devuelve instancia" % i)
		inst.set_position(Vector3(0, 0, -2))
		instances.append(inst)
		await tree.process_frame
	a.ok(instances[0].is_stopping() or not instances[0].is_playing(), "la primera instancia es la robada")
	await _wait_ms(tree, 150)
	var alive: int = 0
	for inst in instances:
		if inst.is_playing() and not inst.is_stopping():
			alive += 1
	a.eq(alive, 3, "quedan exactamente tres sonando")
	var peak_three: float = await probe.measure_peak_over_frames(tree, 20)
	print("[OpenDou] limites: pico con 4 voces %.3f, con 3 %.3f" % [peak_four, peak_three])
	a.lt(peak_three, peak_four * 0.9, "tres voces pican menos que cuatro (el limite llega al bus)")
	manager.stop_all()
	await probe.await_silence(tree, 0.002, 30)

	# REJECT_NEW: la cuarta no nace.
	def.limit_policy = AudioEventDefClass.LimitPolicy.REJECT_NEW
	for i in range(3):
		manager.post_event(def, null).set_position(Vector3(0, 0, -2))
	var rejected = manager.post_event(def, null)
	a.eq(rejected, null, "REJECT_NEW: la cuarta devuelve null")
	manager.stop_all()
	await probe.await_silence(tree, 0.002, 30)

	# Por radio: dos cerca llenan el cupo de 2; una tercera cerca no nace, una lejana si.
	def.max_instances = 0
	def.max_instances_in_radius = 2
	def.instance_radius_m = 5.0
	var near_a := Node3D.new()
	near_a.position = Vector3(1, 0, 0)
	tree.root.add_child(near_a)
	var near_b := Node3D.new()
	near_b.position = Vector3(-1, 0, 0)
	tree.root.add_child(near_b)
	var near_c := Node3D.new()
	near_c.position = Vector3(0, 0, 1)
	tree.root.add_child(near_c)
	var far_d := Node3D.new()
	far_d.position = Vector3(50, 0, 0)
	tree.root.add_child(far_d)
	a.ok(manager.post_event(def, near_a) != null, "primera cerca nace")
	a.ok(manager.post_event(def, near_b) != null, "segunda cerca nace")
	a.eq(manager.post_event(def, near_c), null, "tercera dentro del radio no nace (REJECT_NEW)")
	a.ok(manager.post_event(def, far_d) != null, "una a 50 m si nace: el radio es local")
	manager.stop_all()
	await probe.await_silence(tree, 0.002, 30)

	# Por emisor: un emisor que postea dos veces roba su propia voz; otro emisor no se toca.
	def.max_instances_in_radius = 0
	def.max_instances_per_emitter = 1
	def.limit_policy = AudioEventDefClass.LimitPolicy.STEAL_OLDEST
	var first_a = manager.post_event(def, near_a)
	var other_b = manager.post_event(def, near_b)
	var second_a = manager.post_event(def, near_a)
	a.ok(second_a != null and first_a.is_stopping(), "el segundo post del mismo emisor roba al primero")
	a.ok(other_b.is_playing() and not other_b.is_stopping(), "y el otro emisor no se ve afectado")
	manager.stop_all()
	await probe.await_silence(tree, 0.002, 30)

	# El fundido de stop() es real: parada con 0.3 s sigue viva a los 0.1 s y ha callado a
	# los 0.6 s. Antes el parametro se ignoraba.
	def.max_instances_per_emitter = 0
	var fading = manager.post_event(def, null)
	fading.set_position(Vector3(0, 0, -2))
	await _wait_ms(tree, 150)
	fading.stop(0.3)
	await _wait_ms(tree, 100)
	a.ok(fading.is_stopping() and fading.is_playing(), "a los 0.1 s la voz sigue viva y en fundido")
	var mid_peak: float = await probe.measure_peak_over_frames(tree, 4)
	a.gt(mid_peak, 0.001, "y aun suena")
	await _wait_ms(tree, 500)
	a.ok(not fading.is_playing(), "a los 0.6 s ha terminado")

	for n in [near_a, near_b, near_c, far_d, cam]:
		tree.root.remove_child(n)
		n.free()
	manager.stop_all()
	tree.root.remove_child(manager)
	manager.free()
	probe.teardown()
	return a
