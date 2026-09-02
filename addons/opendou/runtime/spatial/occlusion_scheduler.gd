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

func _init() -> void:
	occlusion_manager = OcclusionManagerClass.new()
	lod_controller = AcousticLODControllerClass.new()

## Atiende un lote de instancias dentro del presupuesto.
## Devuelve el numero de raycasts realmente lanzados.
func process(instances: Array, listener_pos: Vector3, world_3d: World3D, occluder_volumes: Array = []) -> int:
	raycasts_this_frame = 0
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
	for pr in pairs:
		eligible.append(pr[1])

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
		var extra_db: float = 0.0
		var extra_cut: float = 0.0
		for v in occluder_volumes:
			if v == null or not is_instance_valid(v) or v.environment == null or not v.environment.occluder_enabled:
				continue
			var l: float = v.segment_length_inside(inst.emitter_position, listener_pos)
			if l > 0.0:
				extra_db -= v.environment.occluder_db_per_m * l
				extra_cut += v.environment.occluder_cutoff_hz_per_m * l
		var lpf: float = result.target_lpf if extra_cut <= 0.0 else maxf(500.0, minf(result.target_lpf, 20000.0 - extra_cut))
		inst.set_target_lpf(lpf, result.volume_attenuation_db + extra_db)
		raycasts_this_frame += 1
		last_processed_ids.append(idx)

	_cursor = (_cursor + budget) % eligible.size()
	return raycasts_this_frame
