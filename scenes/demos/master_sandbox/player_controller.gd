class_name OpenDouPlayerController
extends CharacterBody3D

## First-person player controller with dynamic footstep surface resolution and weapon firing.

const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")

@export var speed: float = 6.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Dynamic Audio Cache
var footstep_samples: Dictionary = {}
var gunshot_samples: Array[AudioStreamWAV] = []
var step_timer: float = 0.0
var step_interval: float = 0.42
var current_surface: StringName = &"Asphalt"

@onready var camera: Camera3D = $Camera3D
@onready var floor_ray: RayCast3D = $FloorRay
@onready var footstep_audio: AudioStreamPlayer = $FootstepAudio
@onready var weapon_audio: AudioStreamPlayer = $WeaponAudio
@onready var muzzle_light: OmniLight3D = $Camera3D/MuzzleLight

signal surface_changed(new_surface: StringName)
signal weapon_fired(bullet_pos: Vector3)

func _ready() -> void:
	_init_audio_samples()
	if muzzle_light:
		muzzle_light.visible = false

func _init_audio_samples() -> void:
	# Pre-synthesize material footstep variations
	var surfaces = [&"Asphalt", &"Mud", &"Metal", &"Stone", &"Wood", &"Concrete", &"Water"]
	for s in surfaces:
		footstep_samples[s] = []
		for i in range(1, 4):
			var sample_name = s
			if s == &"Asphalt": sample_name = &"Concrete"
			elif s == &"Mud": sample_name = &"Water"
			elif s == &"Stone": sample_name = &"Concrete"
			footstep_samples[s].append(AudioSynthesizerClass.create_footstep(sample_name, i))
			
	# Synthesize weapon variations for shuffle container simulation
	for i in range(4):
		gunshot_samples.append(AudioSynthesizerClass.create_gunshot())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
		
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if camera:
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(80), deg_to_rad(80))
			
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			fire_weapon()

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
		
	# Movement input
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	input_dir = input_dir.normalized()
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Footstep cadence
		if is_on_floor():
			step_timer += delta
			if step_timer >= step_interval:
				step_timer = 0.0
				play_footstep()
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		step_timer = step_interval * 0.5
		
	move_and_slide()
	_detect_surface()

func _detect_surface() -> void:
	var new_surface: StringName = &"Asphalt"
	
	if floor_ray and floor_ray.is_colliding():
		var col = floor_ray.get_collider()
		if col:
			var col_name = col.name.to_lower()
			if "mud" in col_name:
				new_surface = &"Mud"
			elif "metal" in col_name or "bunker" in col_name or "generator" in col_name or "steel" in col_name:
				new_surface = &"Metal"
			elif "crypt" in col_name or "pillar" in col_name or "stone" in col_name or "cavern" in col_name or "rock" in col_name:
				new_surface = &"Stone"
			elif "glass" in col_name or "concrete" in col_name or "corridor" in col_name or "toxic" in col_name or "lab" in col_name:
				new_surface = &"Concrete"
			elif "asphalt" in col_name or "floor" in col_name:
				new_surface = &"Asphalt"
	else:
		# Fallback based on global coordinates
		if global_position.x > 20.0:
			new_surface = &"Stone" # Inside Crypt
		elif global_position.z > 25.0:
			new_surface = &"Concrete" # Inside Calibration Lab
		elif global_position.x < -15.0 and global_position.z < -5.0:
			new_surface = &"Mud"   # Outpost Mud Trench
		elif global_position.x < -15.0 and global_position.z >= 5.0:
			new_surface = &"Metal" # Debris Platform
		else:
			new_surface = &"Asphalt"
		
	if new_surface != current_surface:
		current_surface = new_surface
		surface_changed.emit(current_surface)

func play_footstep() -> void:
	if not footstep_audio:
		return
		
	var pool = footstep_samples.get(current_surface, footstep_samples[&"Asphalt"])
	if pool.size() > 0:
		var sample: AudioStreamWAV = pool[randi() % pool.size()]
		footstep_audio.stream = sample
		footstep_audio.pitch_scale = randf_range(0.92, 1.08)
		footstep_audio.volume_db = randf_range(-3.0, 0.0)
		footstep_audio.play()

func fire_weapon() -> void:
	if not weapon_audio or gunshot_samples.is_empty():
		return
		
	# Shuffle bag pick
	var sample = gunshot_samples[randi() % gunshot_samples.size()]
	weapon_audio.stream = sample
	weapon_audio.pitch_scale = randf_range(0.95, 1.05)
	weapon_audio.volume_db = randf_range(-1.0, 1.0)
	weapon_audio.play()
	
	# Muzzle flash
	if muzzle_light:
		muzzle_light.visible = true
		get_tree().create_timer(0.05).timeout.connect(func(): if muzzle_light: muzzle_light.visible = false)
		
	weapon_fired.emit(global_position + Vector3(0, 1.5, 0))
