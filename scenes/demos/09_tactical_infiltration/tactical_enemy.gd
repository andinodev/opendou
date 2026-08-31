class_name OpenDouTacticalEnemy
extends CharacterBody3D

## Tactical AI Controller for OpenDou Infiltration Demo
## Handles autonomous patrolling, sound and line-of-sight perception,
## state transitions, procedural footsteps, voice callouts and weapon attacks.

enum State { IDLE, PATROL, SUSPICIOUS, CHASE, ATTACK }

const OpenDouAnimationSyncClass = preload("res://addons/opendou/nodes/opendou_animation_sync.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

@export var move_speed: float = 3.0
@export var chase_speed: float = 5.2
@export var vision_range: float = 24.0
@export var vision_angle_deg: float = 75.0
@export var attack_range: float = 14.0
@export var patrol_points: Array[Vector3] = [
	Vector3(75.0, 1.0, -4.0),
	Vector3(95.0, 1.0, -4.0),
	Vector3(95.0, 1.0, 4.0),
	Vector3(75.0, 1.0, 4.0)
]

# Runtime AI State
var current_state: State = State.PATROL
var current_patrol_idx: int = 0
var suspicious_target_pos: Vector3 = Vector3.ZERO
var target_player: Node3D = null
var footstep_timer: float = 0.0
var footstep_interval: float = 0.42
var shoot_timer: float = 0.0
var alert_cooldown: float = 0.0
var muzzle_timer: float = 0.0
var gravity: float = 9.8

# Node References
var voice_emitter: Node = null
var anim_sync: OpenDouAnimationSync = null
var vision_light: SpotLight3D = null
var muzzle_light: OmniLight3D = null
var weapon_player: AudioStreamPlayer3D = null

func _ready() -> void:
	_init_references()

func _init_references() -> void:
	if voice_emitter == null: voice_emitter = get_node_or_null("VoiceEmitter")
	if anim_sync == null: anim_sync = get_node_or_null("EnemyAnimationSync")
	if vision_light == null: vision_light = get_node_or_null("VisionConeLight")
	if muzzle_light == null: muzzle_light = get_node_or_null("MuzzleLight")
	if weapon_player == null: weapon_player = get_node_or_null("WeaponAudio")

func _physics_process(delta: float) -> void:
	_init_references()
	
	# Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Find Player if null
	if target_player == null:
		var root = get_tree().current_scene if get_tree() else get_parent()
		if root:
			target_player = root.get_node_or_null("Player_Rig")

	# Update timers
	if alert_cooldown > 0.0: alert_cooldown -= delta
	if shoot_timer > 0.0: shoot_timer -= delta
	if muzzle_timer > 0.0:
		muzzle_timer -= delta
		if muzzle_light and muzzle_timer <= 0.0:
			muzzle_light.visible = false

	# State Machine Execution
	match current_state:
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
			if can_see_player():
				trigger_alert()
		State.PATROL:
			_process_patrol(delta)
			if can_see_player():
				trigger_alert()
		State.SUSPICIOUS:
			_process_suspicious(delta)
			if can_see_player():
				trigger_alert()
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	move_and_slide()

# ─── STATE PROCESSING ─────────────────────────────────────────────────────────

func _process_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return

	var target = patrol_points[current_patrol_idx]
	var cur_pos = global_position if is_inside_tree() else position
	var to_target = (target - cur_pos)
	to_target.y = 0.0

	if to_target.length() < 1.2:
		current_patrol_idx = (current_patrol_idx + 1) % patrol_points.size()
	else:
		var dir = to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_look_towards(cur_pos + dir)
		_process_footstep_audio(delta)

	if vision_light:
		vision_light.light_color = Color(0.9, 0.85, 0.4, 1) # Yellow / Patrol

func _process_suspicious(delta: float) -> void:
	var cur_pos = global_position if is_inside_tree() else position
	var to_target = (suspicious_target_pos - cur_pos)
	to_target.y = 0.0

	if to_target.length() < 1.5:
		current_state = State.PATROL
	else:
		var dir = to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_look_towards(cur_pos + dir)
		_process_footstep_audio(delta)

	if vision_light:
		vision_light.light_color = Color(1.0, 0.5, 0.1, 1) # Orange / Suspicious

func _process_chase(delta: float) -> void:
	if target_player == null:
		current_state = State.PATROL
		return

	var p_pos = target_player.global_position if target_player.is_inside_tree() else target_player.position
	var cur_pos = global_position if is_inside_tree() else position
	var dist = cur_pos.distance_to(p_pos)

	if dist <= attack_range:
		current_state = State.ATTACK
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var to_p = (p_pos - cur_pos)
	to_p.y = 0.0
	var dir = to_p.normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	_look_towards(cur_pos + dir)
	_process_footstep_audio(delta)

	if vision_light:
		vision_light.light_color = Color(1.0, 0.15, 0.15, 1) # Red / Hostile

func _process_attack(_delta: float) -> void:
	if target_player == null:
		current_state = State.PATROL
		return

	var p_pos = target_player.global_position if target_player.is_inside_tree() else target_player.position
	var cur_pos = global_position if is_inside_tree() else position
	var dist = cur_pos.distance_to(p_pos)

	_look_towards(p_pos)
	velocity.x = 0.0
	velocity.z = 0.0

	if dist > attack_range * 1.3:
		current_state = State.CHASE
		return

	# Fire weapon in bursts
	if shoot_timer <= 0.0:
		shoot_timer = 0.8
		_fire_weapon()

# ─── PERCEPTION & ACTIONS ─────────────────────────────────────────────────────

func can_see_player() -> bool:
	if target_player == null:
		return false
	var p_pos = target_player.global_position if target_player.is_inside_tree() else target_player.position
	var cur_pos = global_position if is_inside_tree() else position
	var dist = cur_pos.distance_to(p_pos)
	if dist > vision_range:
		return false

	var forward = -transform.basis.z if is_inside_tree() else Vector3.FORWARD
	var to_player = (p_pos - cur_pos).normalized()
	var angle = rad_to_deg(forward.angle_to(to_player))
	return angle <= (vision_angle_deg * 0.5)

func trigger_alert() -> void:
	current_state = State.CHASE
	if alert_cooldown <= 0.0:
		alert_cooldown = 4.0
		if anim_sync:
			anim_sync.play_audio_event(&"Enemy_Alert_Shout")
		elif voice_emitter and voice_emitter.has_method("play_event"):
			voice_emitter.call("play_event", &"Enemy_Alert_Shout")

func hear_noise(noise_pos: Vector3, noise_intensity: float = 1.0) -> void:
	var cur_pos = global_position if is_inside_tree() else position
	var dist = cur_pos.distance_to(noise_pos)
	if dist < (vision_range * noise_intensity):
		suspicious_target_pos = noise_pos
		if current_state != State.CHASE and current_state != State.ATTACK:
			current_state = State.SUSPICIOUS

func _fire_weapon() -> void:
	if muzzle_light:
		muzzle_light.visible = true
		muzzle_timer = 0.08
	if weapon_player:
		if weapon_player.stream == null:
			weapon_player.stream = AudioSynthesizerClass.create_gunshot()
		weapon_player.play()
	if anim_sync:
		anim_sync.play_audio_event(&"Gunshot_Rifle")

func _process_footstep_audio(delta: float) -> void:
	footstep_timer += delta
	if footstep_timer >= footstep_interval:
		footstep_timer = 0.0
		if anim_sync:
			var cur_surf = &"Metal" if (global_position.x if is_inside_tree() else position.x) >= 50.0 else &"Stone"
			anim_sync.footstep(0, cur_surf)

func _look_towards(target_pt: Vector3) -> void:
	var cur_pos = global_position if is_inside_tree() else position
	var diff = target_pt - cur_pos
	diff.y = 0.0
	if diff.length_squared() > 0.01:
		var target_rot_y = atan2(-diff.x, -diff.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, 0.15)
