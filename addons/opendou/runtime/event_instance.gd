class_name EventInstance
extends RefCounted

## Dynamic runtime instance of an AudioEventDef, managing playback, local RTPCs, modulators, voice state, spatial occlusion and virtualization.

const RTPCValueClass = preload("res://addons/opendou/runtime/rtpc_value.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const RTPCBindingClass = preload("res://addons/opendou/resources/rtpc_binding.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")
const ResolvedVoiceClass = preload("res://addons/opendou/runtime/resolved_voice.gd")
const AudioModulatorClass = preload("res://addons/opendou/resources/modulators/audio_modulator.gd")
const AHDSRStateClass = preload("res://addons/opendou/runtime/modulators/ahdsr_state.gd")
const LFOStateClass = preload("res://addons/opendou/runtime/modulators/lfo_state.gd")

## Un marcador de la definicion (AudioMarker) quedo entre la posicion anterior y la actual
## del reloj logico (Fase 9). En bucle vuelve a emitirse en cada vuelta.
signal marker_reached(name: StringName)

enum VoiceState {
	STATE_STOPPED,  ## Sound has ended or stopped
	STATE_PHYSICAL, ## Playing on an active hardware/audio channel
	STATE_VIRTUAL,  ## Inaudible or stolen; tracking time logically at 0 CPU cost
	STATE_KILLED    ## Discarded permanently due to resource starvation
}

var definition: AudioEventDef
var caller_id: int = 0
var caller_node_ref: WeakRef = null

# Local RTPC parameters specific to this entity instance
var local_rtpcs: Dictionary = {} # StringName -> RTPCValue

# Modulator runtime states (Array of Dictionaries with {"def": AudioModulator, "state": RefCounted})
var modulator_states: Array[Dictionary] = []

# Spatial Occlusion & Filtering
var current_spatial_lpf: float = 20000.0
var target_spatial_lpf: float = 20000.0
var occlusion_smoothing_speed: float = 8.0
var occlusion_attenuation_db: float = 0.0
## Descartada por el entorno (Fase 10): pesa 0 en el robo de voces y no gasta rayos.
var culled: bool = false

# Calculated outputs after curve evaluation, RTPCs, modulators and occlusion
var calculated_volume_db: float = 0.0
var calculated_pitch_scale: float = 1.0
var calculated_properties: Dictionary = {} # StringName -> float

# Voice & Virtualization State
var voice_state: VoiceState = VoiceState.STATE_STOPPED
var virtualization_mode: AudioEventDef.VirtualizationMode = AudioEventDef.VirtualizationMode.VIRTUAL_ELAPSED_TIME
var assigned_channel_id: int = -1
## Capas del arbol de contenedores (Fase 11): indice 0 = la voz principal (assigned_channel_id),
## las demas en layer_channel_ids. Hasta la Fase 11 el runtime reproducia solo voices[0] y
## tiraba los desplazamientos: un AudioBlendContainer no cruzaba nada.
var layer_channel_ids: Array[int] = []
var voice_streams: Array = []
var voice_offsets_db: Array[float] = []
var voice_pitch_mods: Array[float] = []
## True si el arbol es determinista y hay mas de una capa: los desplazamientos se
## re-resuelven cada cuadro (cruce en vivo por RTPC).
var live_blend: bool = false
var current_weight: float = 0.0
var logical_playback_position: float = 0.0
var max_distance: float = 100.0

# Atenuacion por distancia (Fase 7B). Con los defectos de Godot; ver AudioEventDef.
var unit_size: float = 10.0
var attenuation_max_distance: float = 0.0
var attenuation_model: int = 0
var attenuation_filter_cutoff_hz: float = 5000.0
var attenuation_filter_db: float = -24.0
## volume_db del emisor de nodo; 0 en las voces anonimas.
var emitter_volume_db: float = 0.0

# El emisor completo (Fase 9). Copiados de la definicion o del nodo emisor.
var doppler_enabled: bool = false
var propagation_delay_enabled: bool = false
var spread_radius_m: float = 0.0
var near_field_distance_m: float = 0.0
var directivity_dipole_weight: float = 0.0
var directivity_power: float = 1.0
var attenuation_curve: Curve = null
var attenuation_curve_distance_m: float = 50.0
## Hacia donde mira el emisor (eje de la directividad). Los nodos lo actualizan cada frame.
var emitter_forward: Vector3 = Vector3(0, 0, -1)

## Velocidad del emisor (m/s) estimada por diferencia de posicion entre frames; y una
## velocidad de flujo que quien quiera (el spline) puede sumar.
var emitter_velocity: Vector3 = Vector3.ZERO
var flow_velocity: Vector3 = Vector3.ZERO
## Factor de tono por doppler, suavizado. 1.0 sin doppler.
var doppler_pitch: float = 1.0
var _prev_motion_position: Vector3 = Vector3.ZERO
var _has_prev_motion: bool = false

# 3D / Spatial Positioning
var emitter_position: Vector3 = Vector3.ZERO
var has_spatial_position: bool = false

## True mientras el grafo de salas y portales gobierne esta voz.
##
## Cuando lo esta, la oclusion por raycast NO la toca: el grafo ya sabe que hay un
## mamparo y por donde se rodea, y sumar los dos cobraria dos veces por la misma pared.
var room_path_active: bool = false

## Posicion hacia la que se interpola la posicion aparente.
var target_apparent_position: Vector3 = Vector3.ZERO

## Posicion que se pasa al canal fisico.
##
## Es la del emisor casi siempre. Cuando el grafo gobierna la voz es la del portal por el
## que sale el sonido, que es lo que hace que se oiga VINIENDO de la escotilla en lugar
## de atravesando el mamparo.
var current_apparent_position: Vector3 = Vector3.ZERO

## Velocidad de convergencia de la posicion aparente, en unidades de 1/s.
##
## Existe porque al cruzar el portal la posicion aparente pasa del portal al emisor: si
## saltara, se oiria el chasquido del paneo.
var apparent_smoothing_speed: float = 8.0

var is_paused_state: bool = false
var is_key_on: bool = true
var elapsed_time: float = 0.0

## Fundido de salida pedido por stop(fade). > 0 mientras dura; la voz sigue sonando con la
## ganancia de stop_fade_gain() y termina sola. Antes stop() ignoraba su parametro.
var stop_fade_total: float = 0.0
var stop_fade_remaining: float = -1.0

## Reproductor nativo que esta instancia usa como voz fisica, si su emisor es un
## nodo OpenDouEventPlayer*. Null en las voces anonimas, que reciben uno del pool.
var bound_player_ref: WeakRef = null

## Contexto de resolucion de esta instancia: RTPC y switches vivos.
##
## Sin el, AudioSwitchContainer resolvia siempre a su default_state y
## AudioBlendContainer veia siempre RTPC = 0.0, porque devirtualize() invocaba
## resolve_voices() sin argumento y se creaba uno vacio.
##
## Se crea PEREZOSAMENTE y solo si la definicion tiene un arbol de contenedores:
## resolve_voices() no lo mira cuando el evento es un base_stream a secas, asi que
## crearlo para toda instancia era un objeto por instancia que nadie leia -y en la
## demo del monzon serian 200-.
var playback_context: AudioPlaybackContext = null

func _init(p_definition: AudioEventDef, p_caller: Node = null) -> void:
	definition = p_definition
	if p_caller:
		caller_id = p_caller.get_instance_id()
		caller_node_ref = weakref(p_caller)
		if p_caller is Node3D:
			emitter_position = p_caller.global_position if p_caller.is_inside_tree() else p_caller.position
			has_spatial_position = true
		elif p_caller is Node2D:
			var p2d = p_caller.global_position if p_caller.is_inside_tree() else p_caller.position
			emitter_position = Vector3(p2d.x, p2d.y, 0.0)
			has_spatial_position = true
	
	# La posicion aparente arranca donde el emisor. Sin esto cada voz nueva barreria
	# desde el origen del mundo hasta su sitio, y eso se oye.
	target_apparent_position = emitter_position
	current_apparent_position = emitter_position

	if definition:
		calculated_volume_db = definition.base_volume_db
		calculated_pitch_scale = definition.base_pitch_scale
		virtualization_mode = definition.virtualization_mode
		unit_size = definition.unit_size
		attenuation_max_distance = definition.attenuation_max_distance
		attenuation_model = definition.attenuation_model
		attenuation_filter_cutoff_hz = definition.attenuation_filter_cutoff_hz
		attenuation_filter_db = definition.attenuation_filter_db
		doppler_enabled = definition.doppler_enabled
		propagation_delay_enabled = definition.propagation_delay_enabled
		spread_radius_m = definition.spread_radius_m
		near_field_distance_m = definition.near_field_distance_m
		directivity_dipole_weight = definition.directivity_dipole_weight
		directivity_power = definition.directivity_power
		attenuation_curve = definition.attenuation_curve
		attenuation_curve_distance_m = definition.attenuation_curve_distance_m
		
		# Instantiate modulator runtime states
		modulator_states = []
		for mod in definition.modulators:
			if mod:
				var state = mod.create_runtime_state()
				if state:
					modulator_states.append({"def": mod, "state": state})

## Refresca el contexto con los valores vivos: globales primero, locales encima.
##
## Los locales ganan porque un RTPC de instancia es mas especifico que el global, y un
## switch de entidad mas que el de grupo.
func refresh_playback_context(global_rtpcs: Dictionary, sync_manager) -> void:
	# Sin arbol de contenedores nadie lee el contexto: resolve_voices() solo lo usa si
	# hay root_container. No crearlo aqui evita un objeto por instancia.
	if definition == null or definition.root_container == null:
		return
	if playback_context == null:
		playback_context = AudioPlaybackContextClass.new()

	for param_name in global_rtpcs:
		var rtpc = global_rtpcs[param_name]
		playback_context.set_rtpc(param_name, rtpc.current_value)
	for param_name in local_rtpcs:
		var local: RTPCValue = local_rtpcs[param_name]
		playback_context.set_rtpc(param_name, local.current_value)

	if sync_manager == null:
		return
	for group in sync_manager.global_switches:
		playback_context.set_switch(group, sync_manager.global_switches[group])
	# Switches de la entidad que disparo el evento, si sigue viva.
	var caller = caller_node_ref.get_ref() if caller_node_ref != null else null
	if caller != null and is_instance_valid(caller):
		var entity_map: Dictionary = sync_manager.entity_switches.get(caller.get_instance_id(), {})
		for group in entity_map:
			playback_context.set_switch(group, entity_map[group])


## Vincula esta instancia al reproductor de su nodo emisor.
##
## Existe para que el pool no le asigne ademas una voz anonima: el reproductor
## del nodo ES la voz fisica, y crear otra era la doble reproduccion.
func bind_player(player: Node) -> void:
	bound_player_ref = weakref(player) if player != null else null

## Notifica que el reproductor nativo emitio `finished`.
##
## Es la fuente de verdad del fin de reproduccion. advance_virtual_time() vuelve
## temprano si el estado no es VIRTUAL, asi que una voz fisica no avanza su
## posicion logica y por si sola nunca sabria que su stream acabo: sin esta senal,
## is_finished() era siempre falso y active_instances crecia sin limite.
func notify_stream_finished() -> void:
	if not is_key_on or modulator_states.is_empty():
		voice_state = VoiceState.STATE_STOPPED
		# El canal NO se suelta aqui. Antes se ponia assigned_channel_id = -1, y
		# entonces la limpieza del manager -que virtualiza solo si el id es >= 0- no
		# podia soltarlo: el canal se quedaba is_busy para siempre y el reproductor
		# seguia vinculado. Tras suficientes one-shots el pool quedaba lleno de
		# canales ocupados por voces que ya no existian.
		return
	# Con moduladores activos se entra en fase de release, y update_parameters()
	# concluira cuando el AHDSR llegue a IDLE.
	is_key_on = false

## Reproductor vinculado, o null si no hay o el nodo ya no existe.
func get_bound_player() -> Node:
	if bound_player_ref == null:
		return null
	var p = bound_player_ref.get_ref()
	if p != null and is_instance_valid(p):
		return p
	return null

## Sets a 3D emitter position directly.
func set_position(pos: Vector3) -> void:
	emitter_position = pos
	has_spatial_position = true
	if not room_path_active:
		target_apparent_position = pos
		current_apparent_position = pos

## Copia la atenuacion de un reproductor 3D de Godot: es lo que hace que un emisor de nodo
## suene igual en los dos backends. No toca max_distance, que es del robo de voces.
func copy_attenuation_from_player(player: AudioStreamPlayer3D) -> void:
	if player == null:
		return
	unit_size = player.unit_size
	attenuation_max_distance = player.max_distance
	attenuation_model = int(player.attenuation_model)
	attenuation_filter_cutoff_hz = player.attenuation_filter_cutoff_hz
	attenuation_filter_db = player.attenuation_filter_db
	emitter_volume_db = player.volume_db

## Copia los exports del emisor completo de un nodo (OpenDouEventPlayer3D u otro que los
## declare). Los que el nodo no tenga se dejan como estan.
func copy_emitter_settings_from_player(player: Node3D) -> void:
	if player == null:
		return
	for field in ["doppler_enabled", "propagation_delay_enabled", "spread_radius_m", "near_field_distance_m", "directivity_dipole_weight", "directivity_power", "attenuation_curve", "attenuation_curve_distance_m"]:
		if field in player:
			set(field, player.get(field))

## Actualiza la velocidad del emisor desde su posicion actual. Un salto mayor de 50 m en un
## frame es un teletransporte, no una velocidad: ese frame vale 0.
func update_motion(delta: float) -> void:
	if not _has_prev_motion or delta <= 0.0:
		_prev_motion_position = emitter_position
		_has_prev_motion = true
		emitter_velocity = Vector3.ZERO
		return
	var step: Vector3 = emitter_position - _prev_motion_position
	_prev_motion_position = emitter_position
	emitter_velocity = Vector3.ZERO if step.length() > 50.0 else step / delta

## Eje de la directividad para voces anonimas; los nodos lo fijan cada frame desde su base.
func set_orientation(forward: Vector3) -> void:
	if forward.length_squared() > 0.000001:
		emitter_forward = forward.normalized()

## Emite los marcadores cuyo tiempo quedo entre la posicion anterior y la actual. Si el
## bucle envolvio, los del tramo final y los del tramo inicial.
func _emit_markers_crossed(previous: float, current: float, wrapped: bool) -> void:
	if definition == null or definition.markers.is_empty():
		return
	for mk in definition.markers:
		if mk == null:
			continue
		var t: float = mk.time_sec
		var hit: bool = (not wrapped and t > previous and t <= current) or (wrapped and (t > previous or t <= current))
		if hit:
			marker_reached.emit(mk.name)

## Sets the target spatial low-pass filter cutoff in Hz.
func set_target_lpf(lpf_hz: float, atten_db: float = 0.0) -> void:
	target_spatial_lpf = clampf(lpf_hz, 20.0, 20000.0)
	occlusion_attenuation_db = atten_db

## Calculates the dynamic priority weight for voice stealing.
func calculate_dynamic_weight(listener_pos: Vector3) -> float:
	if not is_playing():
		return 0.0
	if culled:
		return 0.0
		
	var base_priority: float = definition.base_priority if definition else 50.0
	
	# Convert volume dB to linear amplitude [0.0, 1.0+]
	var linear_vol: float = db_to_linear(calculated_volume_db)
	
	var distance_factor: float = 1.0
	if has_spatial_position:
		var dist: float = emitter_position.distance_to(listener_pos)
		if dist >= max_distance and max_distance > 0.0:
			return 0.0
		elif max_distance > 0.0:
			distance_factor = maxf(0.0, 1.0 - (dist / max_distance))
			
	return base_priority * linear_vol * distance_factor

## Sets a local RTPC parameter value on this instance.
func set_parameter(param_name: StringName, value: float, immediate: bool = false) -> void:
	if not local_rtpcs.has(param_name):
		local_rtpcs[param_name] = RTPCValueClass.new(value)
	else:
		var rtpc: RTPCValue = local_rtpcs[param_name]
		if immediate:
			rtpc.set_value_immediate(value)
		else:
			# La velocidad escala con el salto: a 10 unidades por segundo fijas, un RPM de 900 a
			# 5000 tardaba siete minutos en llegar. Un RTPC local asienta en un cuarto de segundo.
			var speed: float = maxf(10.0, absf(value - rtpc.current_value) * 4.0)
			rtpc.attack_speed = speed
			rtpc.release_speed = speed
			rtpc.set_target(value)

## Gets the current parameter value, checking local first, then falling back to global.
func get_parameter(param_name: StringName, global_rtpcs: Dictionary = {}) -> float:
	if local_rtpcs.has(param_name):
		var rtpc: RTPCValue = local_rtpcs[param_name]
		return rtpc.current_value
	elif global_rtpcs.has(param_name):
		var rtpc: RTPCValue = global_rtpcs[param_name]
		return rtpc.current_value
	return 0.0

## Interpolates local RTPC values by delta.
func interpolate_locals(delta: float) -> void:
	for param_name in local_rtpcs:
		var rtpc: RTPCValue = local_rtpcs[param_name]
		rtpc.interpolate(delta)

## Evaluates all RTPC bindings, modulators, spatial occlusion and computes final output properties.
func update_parameters(delta: float, global_rtpcs: Dictionary = {}) -> void:
	if stop_fade_remaining > 0.0:
		stop_fade_remaining -= delta
		if stop_fade_remaining <= 0.0:
			stop_fade_remaining = 0.0
			voice_state = VoiceState.STATE_STOPPED
	if not definition:
		return
		
	elapsed_time += delta

	# El reloj logico avanza tambien mientras la voz es FISICA, y un evento no-loop
	# termina al llegar a stream_length.
	#
	# Sin esto, is_looping = false era una mentira en cuanto el AudioStreamWAV traia
	# loop_mode = LOOP_FORWARD -y varios de los sintetizados lo traen, el trueno entre
	# ellos-: el reproductor no emite `finished` jamas, asi que la instancia se quedaba
	# en active_instances para siempre. En un juego que dispare ese evento a menudo es
	# crecimiento sin techo.
	if voice_state == VoiceState.STATE_PHYSICAL and definition.stream_length > 0.0:
		var before_physical: float = logical_playback_position
		logical_playback_position += delta * maxf(0.01, calculated_pitch_scale)
		var wrapped_physical: bool = false
		if definition.is_looping and definition.stream_length > 0.0 and logical_playback_position >= definition.stream_length:
			# El reloj logico envuelve con el bucle tambien mientras la voz es fisica: asi los
			# marcadores vuelven a sonar en cada vuelta (Fase 9).
			logical_playback_position = fmod(logical_playback_position, definition.stream_length)
			wrapped_physical = true
		_emit_markers_crossed(before_physical, logical_playback_position, wrapped_physical)
		if not definition.is_looping and logical_playback_position >= definition.stream_length:
			notify_stream_finished()
	
	# Update spatial position if caller node is valid
	if caller_node_ref:
		var caller: Object = caller_node_ref.get_ref()
		if caller and caller is Node3D:
			emitter_position = caller.global_position if caller.is_inside_tree() else caller.position
			has_spatial_position = true
		elif caller and caller is Node2D:
			var p2d = caller.global_position if caller.is_inside_tree() else caller.position
			emitter_position = Vector3(p2d.x, p2d.y, 0.0)
			has_spatial_position = true
	
	# El destino se fija aqui para las voces que el grafo NO gobierna: el dispatcher solo
	# mira las fisicas, asi que sin esto una voz que deja de estar gobernada se quedaria
	# con la posicion del portal para siempre.
	if not room_path_active:
		target_apparent_position = emitter_position
	current_apparent_position = current_apparent_position.lerp(
		target_apparent_position,
		clampf(apparent_smoothing_speed * delta, 0.0, 1.0)
	)

	# 1. Start from base definition values and apply occlusion volume attenuation
	var vol: float = definition.base_volume_db + occlusion_attenuation_db
	var pitch: float = definition.base_pitch_scale
	calculated_properties.clear()
	
	# 2. Smooth spatial Low-Pass Filter (Slew-rate limit)
	current_spatial_lpf += (target_spatial_lpf - current_spatial_lpf) * clampf(occlusion_smoothing_speed * delta, 0.0, 1.0)
	calculated_properties[&"cutoff_hz"] = current_spatial_lpf
	
	# 3. Evaluate RTPC bindings
	for binding in definition.rtpc_bindings:
		if not binding or binding.parameter_id.is_empty():
			continue
			
		var param_val: float = get_parameter(binding.parameter_id, global_rtpcs)
		var curve_out: float = binding.evaluate(param_val)
		
		match binding.target_property:
			&"volume_db", &"volume", &"Volume":
				vol = binding.apply_to(vol, curve_out)
			&"pitch_scale", &"pitch", &"Pitch":
				pitch = binding.apply_to(pitch, curve_out)
			_:
				var cur_prop: float = calculated_properties.get(binding.target_property, 0.0)
				calculated_properties[binding.target_property] = binding.apply_to(cur_prop, curve_out)
				
	# 4. Evaluate Modulators (AHDSR, LFO)
	var all_modulators_idle: bool = true
	for entry in modulator_states:
		var mod: AudioModulator = entry["def"]
		var state: RefCounted = entry["state"]
		var mod_out: float = 0.0
		
		if state is AHDSRStateClass:
			mod_out = state.process(delta, is_key_on)
			if state.current_state != AHDSRStateClass.State.IDLE:
				all_modulators_idle = false
		elif state is LFOStateClass:
			mod_out = state.process(delta)
			all_modulators_idle = false
			
		match mod.target_property:
			&"volume_db", &"volume", &"Volume":
				vol = mod.apply_to(vol, mod_out)
			&"pitch_scale", &"pitch", &"Pitch":
				pitch = mod.apply_to(pitch, mod_out)
			_:
				var cur_p: float = calculated_properties.get(mod.target_property, 0.0)
				calculated_properties[mod.target_property] = mod.apply_to(cur_p, mod_out)
				
	# If stop was requested and all AHDSR modulators reached IDLE, conclude playback.
	# Durante un fundido de stop(fade) la voz sigue viva: la concluye el fundido al llegar
	# a cero, no esta linea.
	if not is_key_on and not is_stopping() and (modulator_states.is_empty() or all_modulators_idle):
		voice_state = VoiceState.STATE_STOPPED
		
	calculated_volume_db = vol
	calculated_pitch_scale = pitch

## Advances logical playback position for virtual voices with pitch scaling and loop wrapping.
func advance_virtual_time(delta: float) -> void:
	if voice_state != VoiceState.STATE_VIRTUAL or is_paused_state:
		return
		
	match virtualization_mode:
		AudioEventDef.VirtualizationMode.VIRTUAL_ELAPSED_TIME:
			var effective_pitch: float = maxf(0.01, calculated_pitch_scale)
			var before_virtual: float = logical_playback_position
			logical_playback_position += (delta * effective_pitch)
			var wrapped_virtual: bool = false
			if definition and definition.stream_length > 0.0:
				if definition.is_looping:
					if logical_playback_position >= definition.stream_length:
						wrapped_virtual = true
					logical_playback_position = fmod(logical_playback_position, definition.stream_length)
				else:
					if logical_playback_position >= definition.stream_length:
						voice_state = VoiceState.STATE_STOPPED
			_emit_markers_crossed(before_virtual, logical_playback_position, wrapped_virtual)
		AudioEventDef.VirtualizationMode.VIRTUAL_PLAY_FROM_START:
			logical_playback_position = 0.0
		AudioEventDef.VirtualizationMode.VIRTUAL_RESUME:
			pass
		AudioEventDef.VirtualizationMode.VIRTUAL_KILL_VOICE:
			voice_state = VoiceState.STATE_KILLED

## Starts playback of the event instance.
func play() -> void:
	voice_state = VoiceState.STATE_VIRTUAL # Starts virtual until pool assigns physical channel
	is_paused_state = false
	is_key_on = true
	logical_playback_position = 0.0
	elapsed_time = 0.0

## Stops playback of the event instance (triggers AHDSR Release phase).
func stop(fade_time: float = 0.0) -> void:
	is_key_on = false
	# Con fade_time > 0 la voz baja hasta cero durante ese tiempo y termina sola (ver
	# update_parameters); con 0, para en el acto y el canal hace su micro-fade anticlic.
	if fade_time > 0.0 and is_playing():
		stop_fade_total = fade_time
		stop_fade_remaining = fade_time
		return
	if modulator_states.is_empty():
		voice_state = VoiceState.STATE_STOPPED
		# El canal NO se suelta aqui, por lo mismo que en notify_stream_finished(): la
		# limpieza del manager virtualiza a las instancias terminadas y eso es lo que
		# detiene el canal y devuelve el reproductor. Poner el id a -1 aqui dejaba el
		# canal is_busy para siempre.

## Pauses playback of the event instance.
func pause() -> void:
	if is_playing():
		is_paused_state = true

## Resumes playback of the event instance.
func resume() -> void:
	if is_paused_state:
		is_paused_state = false

## true mientras dura el fundido de stop().
func is_stopping() -> bool:
	return stop_fade_remaining > 0.0

## Ganancia lineal del fundido de stop(): 1.0 sin fundido, baja a 0.
func stop_fade_gain() -> float:
	if stop_fade_total <= 0.0 or stop_fade_remaining < 0.0:
		return 1.0
	return clampf(stop_fade_remaining / stop_fade_total, 0.0, 1.0)

func is_playing() -> bool:
	return (voice_state == VoiceState.STATE_PHYSICAL or voice_state == VoiceState.STATE_VIRTUAL) and not is_paused_state

func is_finished() -> bool:
	return voice_state == VoiceState.STATE_STOPPED or voice_state == VoiceState.STATE_KILLED
