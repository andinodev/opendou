class_name DemoVoiceStress
extends Node3D

## Demo 02: Massive Voice Starvation & Zero-Cost Virtual Tracking (250+ Emitters Stress Test)

const VoicePoolManagerClass = preload("res://addons/opendou/runtime/voice_pool_manager.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")
const EventInstanceClass = preload("res://addons/opendou/runtime/event_instance.gd")
const AudioSynthesizerClass = preload("res://addons/opendou/runtime/audio_synthesizer.gd")
const NativePlayerPoolClass = preload("res://addons/opendou/runtime/native_player_pool.gd")

var pool: VoicePoolManager
var instances: Array[EventInstance] = []
var listener_position: Vector3 = Vector3.ZERO

var total_emitters_count: int = 250
var physical_capacity: int = 16
var gunshot_sample: AudioStreamWAV

# Scene UI & Node References
@onready var audio_player: AudioStreamPlayer = get_node_or_null("AudioPlayer")
@onready var emitters_parent: Node3D = get_node_or_null("Environment3D/EmittersParent")
@onready var btn_back: Button = get_node_or_null("UI/HeaderPanel/Margin/HBox/BtnBack")

@onready var lbl_total: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblTotal")
@onready var lbl_phys: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblPhysical")
@onready var bar_phys: ProgressBar = get_node_or_null("UI/HUDPanel/Margin/VBox/PhysicalBar")
@onready var lbl_virt: Label = get_node_or_null("UI/HUDPanel/Margin/VBox/LblVirtual")
@onready var bar_virt: ProgressBar = get_node_or_null("UI/HUDPanel/Margin/VBox/VirtualBar")

@onready var btn_50: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/Btn50")
@onready var btn_100: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/Btn100")
@onready var btn_250: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/Btn250")

@onready var btn_pool_8: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnPool8")
@onready var btn_pool_16: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnPool16")
@onready var btn_pool_32: Button = get_node_or_null("UI/ControlsPanel/Margin/HBox/BtnPool32")

func _init() -> void:
	gunshot_sample = AudioSynthesizerClass.create_gunshot()
	setup_stress_test(250, 16)

func _ready() -> void:
	if not pool:
		setup_stress_test(250, 16)
	_connect_ui()
	_update_ui()

func setup_stress_test(emitter_count: int = 250, hardware_channels: int = 16) -> void:
	total_emitters_count = emitter_count
	physical_capacity = hardware_channels
	
	pool = VoicePoolManagerClass.new(physical_capacity)
	# Sin pool de reproductores ninguna voz puede volverse fisica: un canal solo
	# se concede si hay algo real que reproduzca.
	var np := NativePlayerPoolClass.new(physical_capacity)
	pool.set_player_pool(np)
	add_child(np)
	instances.clear()
	
	if emitters_parent:
		for child in emitters_parent.get_children():
			child.queue_free()
			
	var def = AudioEventDefClass.new(&"Battlefield_Gunfire", AudioSynthesizerClass.create_tone(220.0, 0.2, 0.5, false))
	def.base_priority = 50.0
	def.base_volume_db = 0.0
	def.stream_length = 4.0
	def.is_looping = true
	def.virtualization_mode = AudioEventDefClass.VirtualizationMode.VIRTUAL_ELAPSED_TIME
	if gunshot_sample:
		def.base_stream = gunshot_sample
	
	var side = int(ceil(sqrt(total_emitters_count)))
	var spacing = 4.0
	
	for i in range(total_emitters_count):
		var ix = i % side
		var iz = int(i / side)
		var pos = Vector3((ix - side * 0.5) * spacing, 0.5, (iz - side * 0.5) * spacing)
		
		var inst = EventInstanceClass.new(def)
		inst.set_position(pos)
		inst.play()
		instances.append(inst)
		
		if emitters_parent:
			var sphere = CSGSphere3D.new()
			sphere.radius = 0.3
			sphere.position = pos
			emitters_parent.add_child(sphere)
			
	update_frame(0.016)

func _connect_ui() -> void:
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_50:
		btn_50.pressed.connect(func(): setup_stress_test(50, physical_capacity); _play_audible_burst(); _update_ui())
	if btn_100:
		btn_100.pressed.connect(func(): setup_stress_test(100, physical_capacity); _play_audible_burst(); _update_ui())
	if btn_250:
		btn_250.pressed.connect(func(): setup_stress_test(250, physical_capacity); _play_audible_burst(); _update_ui())
	if btn_pool_8:
		btn_pool_8.pressed.connect(func(): setup_stress_test(total_emitters_count, 8); _play_audible_burst(); _update_ui())
	if btn_pool_16:
		btn_pool_16.pressed.connect(func(): setup_stress_test(total_emitters_count, 16); _play_audible_burst(); _update_ui())
	if btn_pool_32:
		btn_pool_32.pressed.connect(func(): setup_stress_test(total_emitters_count, 32); _play_audible_burst(); _update_ui())

func _play_audible_burst() -> void:
	if audio_player and gunshot_sample:
		audio_player.stream = gunshot_sample
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.play()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/demos/demo_hub.tscn")

func update_frame(delta: float, new_listener_pos: Vector3 = Vector3.ZERO) -> void:
	listener_position = new_listener_pos
	for inst in instances:
		inst.update_parameters(delta)
	if pool:
		pool.resolve_voice_stealing(instances, listener_position, delta)
	_update_ui()

func get_active_physical_count() -> int:
	return pool.get_active_physical_count() if pool else 0

func get_active_virtual_count() -> int:
	return pool.get_active_virtual_count(instances) if pool else 0

func _update_ui() -> void:
	var phys = get_active_physical_count()
	var virt = get_active_virtual_count()
	
	if lbl_total:
		lbl_total.text = "Total Emitters: %d instances" % total_emitters_count
	if lbl_phys:
		lbl_phys.text = "Physical Channels: %d / %d" % [phys, physical_capacity]
	if bar_phys:
		bar_phys.max_value = physical_capacity
		bar_phys.value = phys
	if lbl_virt:
		lbl_virt.text = "Virtual Tracked: %d voices" % virt
	if bar_virt:
		bar_virt.max_value = total_emitters_count
		bar_virt.value = virt
