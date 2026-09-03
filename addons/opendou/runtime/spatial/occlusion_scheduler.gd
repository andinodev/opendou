class_name OpenDouOcclusionScheduler
extends RefCounted

## Programa los raycasts de oclusion con un presupuesto fijo por frame.
##
## Antes cada OpenDouEventPlayer3D creaba su propio OcclusionManager en _init() y
## lanzaba su propio raycast cada 50 ms: con 200 emisores eran 200 managers y unos
## 4.000 raycasts por segundo, con un coste que crecia sin limite con el numero de
## emisores. Ahora hay un unico manager y un techo duro de raycasts por frame,
## repartidos round-robin entre las voces elegibles.
##
## La elegibilidad la decide AcousticLODController por distancia, que hasta ahora
## era codigo huerfano sin ningun consumidor: las voces demasiado lejanas no
## gastan presupuesto.

const OcclusionManagerClass = preload("res://addons/opendou/runtime/spatial/occlusion_manager.gd")
const AcousticLODControllerClass = preload("res://addons/opendou/runtime/spatial/acoustic_lod_controller.gd")

## Techo de raycasts por frame.
var raycasts_per_frame: int = 8

## Capa fisica contra la que se comprueba la linea de vision.
var collision_mask: int = 1

var occlusion_manager: OcclusionManager = null
var lod_controller: AcousticLODController = null

## Raycasts lanzados en la ultima llamada a process().
var raycasts_this_frame: int = 0

## Identificadores de las instancias atendidas en la ultima llamada. Existe para
## que se pueda comprobar que el reparto round-robin avanza de verdad.
var last_processed_ids: Array = []

var _cursor: int = 0

## Fase 12: en steam_audio con escena de Steam Audio lista, las voces cercanas (LOD) tienen una
## fuente del simulador y su oclusion la calcula el efecto directo; las demas siguen con el
## rayo de Godot. El manager fija use_simulator y voice_pool.
var use_simulator: bool = false
var voice_pool = null
## Fuentes simuladas en la ultima llamada.
var simulated_this_frame: int = 0
var _warned_no_sim: bool = false

## Configura el simulador si la escena esta lista (lo llama tambien el manager para la sala del
## oyente: sin voces, process() vuelve antes de llegar aqui).
func ensure_simulator() -> bool:
	if not use_simulator or voice_pool == null or not ClassDB.class_exists("OpenDouSimulator"):
		return false
	if not bool(ClassDB.class_call_static("OpenDouAcousticScene", "is_ready")):
		return false
	if not bool(ClassDB.class_call_static("OpenDouSimulator", "is_ready")):
		# Con reflexiones (Fase 13): el hilo solo corre si alguna sala lo pide.
		if not bool(ClassDB.class_call_static("OpenDouSimulator", "configure", voice_pool.max_physical_voices + 8, 16, 2, true, 2.0, 4096)):
			if not _warned_no_sim:
				_warned_no_sim = true
				push_warning("[OpenDou] el simulador de Steam Audio no se pudo configurar: oclusion por rayo")
			return false
	return true

## [dB extra, Hz de corte extra] por los volumenes de entorno con oclusion parcial (Fase 10).
func _occluder_extra(inst, listener_pos: Vector3, occluder_volumes: Array) -> Array:
	var extra_db: float = 0.0
	var extra_cut: float = 0.0
	for v in occluder_volumes:
		if v == null or not is_instance_valid(v) or v.environment == null or not v.environment.occluder_enabled:
			continue
		var l: float = v.segment_length_inside(inst.emitter_position, listener_pos)
		if l > 0.0:
			extra_db -= v.environment.occluder_db_per_m * l
			extra_cut += v.environment.occluder_cutoff_hz_per_m * l
	return [extra_db, extra_cut]

## Da o quita la fuente del simulador a la voz segun este dentro del alcance del LOD. Devuelve
## true si la voz queda simulada (y no necesita rayo).
func _assign_source(inst, ch, within_direct: bool) -> bool:
	if within_direct:
		if ch.sim_source < 0:
			ch.sim_source = int(ClassDB.class_call_static("OpenDouSimulator", "create_source"))
		return ch.sim_source >= 0
	if ch.sim_source >= 0:
		ClassDB.class_call_static("OpenDouSimulator", "release_source", ch.sim_source)
		ch.sim_source = -1
	return false

func _init() -> void:
	occlusion_manager = OcclusionManagerClass.new()
	lod_controller = AcousticLODControllerClass.new()

## Atiende un lote de instancias dentro del presupuesto.
## Devuelve el numero de raycasts realmente lanzados.
## Orientacion del oyente para el simulador (la fija el manager cada cuadro).
var _listener_basis: Basis = Basis.IDENTITY

func set_listener_basis(b: Basis) -> void:
	_listener_basis = b

func process(instances: Array, listener_pos: Vector3, world_3d: World3D, occluder_volumes: Array = []) -> int:
	raycasts_this_frame = 0
	simulated_this_frame = 0
	last_processed_ids = []

	if world_3d == null or instances.is_empty() or raycasts_per_frame <= 0:
		return 0
	var space_state := world_3d.direct_space_state
	if space_state == null:
		return 0

	# Elegibles: con posicion espacial y dentro del alcance de fisica segun LOD. El alcance
	# es una distancia (una vez por cuadro), no un Dictionary de rasgos por instancia.
	var max_d: float = lod_controller.physics_occlusion_max_distance()
	var max_d2: float = max_d * max_d
	var pairs: Array = []
	for inst in instances:
		if inst == null or not inst.has_spatial_position:
			continue
		# Las voces que gobierna el grafo de salas ya tienen su filtro y su atenuacion:
		# volver a calcularlas cobraria dos veces por el mismo mamparo, y gastaria
		# raycasts que otras voces si necesitan.
		if inst.room_path_active or inst.culled:
			continue
		var d2: float = inst.emitter_position.distance_squared_to(listener_pos)
		if d2 <= max_d2:
			pairs.append([d2, inst])

	if pairs.is_empty():
		return 0

	# Las mas cercanas al oyente primero: son las que mas se notan. Pares [d2, voz] con el
	# sort() nativo: la lambda costaba mas que los rayos.
	pairs.sort()
	var eligible: Array = []
	# Fase 12: las voces dentro del alcance del efecto directo van al simulador; el resto, al rayo.
	var sim: bool = ensure_simulator()
	if not sim and voice_pool != null:
		# Sin simulador (la escena se fue), ninguna voz conserva una fuente rancia.
		for ch in voice_pool.channels:
			if ch.sim_source >= 0:
				if ClassDB.class_exists("OpenDouSimulator"):
					ClassDB.class_call_static("OpenDouSimulator", "release_source", ch.sim_source)
				ch.sim_source = -1
	var direct_d2: float = 0.0
	if sim:
		var dd: float = lod_controller.direct_simulation_max_distance()
		direct_d2 = dd * dd
	for pr in pairs:
		var inst = pr[1]
		if sim and inst.assigned_channel_id >= 0:
			var ch = voice_pool.get_channel(inst.assigned_channel_id)
			if ch != null and _assign_source(inst, ch, float(pr[0]) <= direct_d2):
				ClassDB.class_call_static("OpenDouSimulator", "set_source_inputs", ch.sim_source, inst.emitter_position, inst.emitter_forward, Vector3.UP, inst.directivity_dipole_weight, inst.directivity_power, 0.5)
				# La geometria la ve el simulador; los volumenes de entorno (no son geometria) se
				# siguen sumando aqui, sin rayo.
				var extra: Array = _occluder_extra(inst, listener_pos, occluder_volumes)
				inst.set_target_lpf(20000.0 if extra[1] <= 0.0 else maxf(500.0, 20000.0 - extra[1]), extra[0])
				simulated_this_frame += 1
				continue
		eligible.append(inst)
	if simulated_this_frame > 0:
		ClassDB.class_call_static("OpenDouSimulator", "set_listener", listener_pos, -_listener_basis.z, _listener_basis.y)
		ClassDB.class_call_static("OpenDouSimulator", "run_direct")
	if eligible.is_empty():
		return 0

	# Reparto round-robin desde el cursor: sin el, las mismas voces cercanas
	# monopolizarian el presupuesto y las demas nunca se actualizarian.
	var budget: int = mini(raycasts_per_frame, eligible.size())
	if _cursor >= eligible.size():
		_cursor = 0

	for i in range(budget):
		var idx: int = (_cursor + i) % eligible.size()
		var inst = eligible[idx]
		var query := PhysicsRayQueryParameters3D.create(inst.emitter_position, listener_pos, collision_mask)
		var hit: Dictionary = space_state.intersect_ray(query)
		var ray_hits: Array[bool] = [not hit.is_empty()]
		var result = occlusion_manager.evaluate_occlusion(inst.emitter_position, listener_pos, ray_hits)
		# Oclusion parcial por volumen (Fase 10): dB/m y Hz/m por la longitud del segmento que
		# atraviesa cada volumen. Viaja en este mismo rayo, sin gastar otro.
		var extra: Array = _occluder_extra(inst, listener_pos, occluder_volumes)
		var lpf: float = result.target_lpf if extra[1] <= 0.0 else maxf(500.0, minf(result.target_lpf, 20000.0 - extra[1]))
		inst.set_target_lpf(lpf, result.volume_attenuation_db + extra[0])
		raycasts_this_frame += 1
		last_processed_ids.append(idx)

	_cursor = (_cursor + budget) % eligible.size()
	return raycasts_this_frame
