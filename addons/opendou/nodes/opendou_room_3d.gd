@icon("res://addons/opendou/icons/icon_room.svg")
@tool
class_name OpenDouRoom3D
extends Area3D

## Declarative 3D Acoustic Room Node for OpenDou.
## Automatically calculates Sabine RT60 reverberation based on geometry and materials,
## registers in the spatial acoustic manager, and supports mix snapshots on entry.

const AudioRoomClass = preload("res://addons/opendou/runtime/spatial/audio_room.gd")
const SpatialAcousticsManagerClass = preload("res://addons/opendou/runtime/spatial/spatial_acoustics_manager.gd")
const ConvolutionReverbNodeClass = preload("res://addons/opendou/core/dsp/convolution_reverb_node.gd")
const TransformUtilsClass = preload("res://addons/opendou/runtime/spatial/transform_utils.gd")

enum ReverbMode {
	ALGORITHMIC,
	CONVOLUTION_IR,
	HYBRID
}

# ==============================================================================
# EXPORT GROUPS
# ==============================================================================

@export_group("Room Acoustics")
@export var room_name: StringName = &"Room"
@export_enum("Concrete", "Metal", "Wood", "Glass", "Water", "Curtains", "Foliage", "Outdoor", "Custom") var material_preset: String = "Concrete"
@export var floor_surface: StringName = &"Concrete"
@export_range(0.01, 1.0, 0.01) var absorption_coefficient: float = 0.15
@export var custom_reverb_time: float = 0.0
@export var calculated_rt60: float = 0.0
@export var snapshot_on_enter: StringName = &""

@export_group("Reverb & Convolution IR")
@export var reverb_mode: ReverbMode = ReverbMode.ALGORITHMIC:
	set(val):
		reverb_mode = val
		if runtime_room != null:
			runtime_room.reverb_mode = int(val)

@export var impulse_response_stream: AudioStreamWAV = null:
	set(val):
		impulse_response_stream = val
		_update_ir_kernel()

@export_range(-60.0, 0.0, 0.5) var convolution_wet_db: float = -6.0:
	set(val):
		convolution_wet_db = val
		if runtime_room != null:
			runtime_room.convolution_wet_db = val
		if _convolution_node:
			_convolution_node.wet_gain_db = val

@export_range(-60.0, 0.0, 0.5) var convolution_dry_db: float = 0.0:
	set(val):
		convolution_dry_db = val
		if runtime_room != null:
			runtime_room.convolution_dry_db = val
		if _convolution_node:
			_convolution_node.dry_gain_db = val

# ==============================================================================
# RUNTIME STATE
# ==============================================================================

var runtime_room: AudioRoom = null
var _acoustics_manager: SpatialAcousticsManager = null
var _dimensions: Vector3 = Vector3.ZERO
var _convolution_node: ConvolutionReverbNode = null

func _ready() -> void:
	# Auto-detect child CollisionShape3D box dimensions
	for child in get_children():
		if child is CollisionShape3D and child.shape != null:
			if child.shape is BoxShape3D:
				var box: BoxShape3D = child.shape as BoxShape3D
				calculate_sabine_reverb(box.size)
				break

	register_in_manager()

	if not Engine.is_editor_hint() and not snapshot_on_enter.is_empty():
		body_entered.connect(_on_body_entered)

# ==============================================================================
# PUBLIC API
# ==============================================================================

## Calculates Sabine RT60 reverberation decay time given 3D dimensions (width, height, depth).
func calculate_sabine_reverb(dimensions: Vector3) -> float:
	_dimensions = dimensions
	var w: float = maxf(dimensions.x, 0.001)
	var h: float = maxf(dimensions.y, 0.001)
	var d: float = maxf(dimensions.z, 0.001)
	
	var volume: float = w * h * d
	var surface_area: float = 2.0 * (w * h + w * d + h * d)
	var alpha: float = get_absorption()
	var total_absorption: float = maxf(surface_area * alpha, 0.001)
	
	var rt60: float = (0.161 * volume) / total_absorption
	calculated_rt60 = clampf(rt60, 0.05, 12.0)
	
	if runtime_room != null:
		runtime_room.reverb_decay_time = get_effective_reverb_time()
		runtime_room.damping = alpha
		runtime_room.floor_surface = floor_surface
		runtime_room.material_preset = material_preset
		var center_pos: Vector3 = global_position if is_inside_tree() else position
		runtime_room.set_bounds(AABB(center_pos - _dimensions * 0.5, _dimensions))
		
	return calculated_rt60

## Returns the absorption coefficient corresponding to the current material preset.
func get_absorption() -> float:
	match material_preset:
		"Concrete":
			return 0.05
		"Metal":
			return 0.02
		"Wood":
			return 0.15
		"Glass":
			return 0.03
		"Water":
			return 0.01
		"Curtains":
			return 0.60
		"Foliage":
			return 0.85
		"Outdoor":
			return 0.95
		"Custom":
			return absorption_coefficient
		_:
			return absorption_coefficient

## Returns custom reverb time if set (> 0.0), otherwise calculated Sabine RT60.
func get_effective_reverb_time() -> float:
	if custom_reverb_time > 0.0:
		return custom_reverb_time
	return calculated_rt60

## Explicitly injects a SpatialAcousticsManager for isolated testing.
func set_acoustics_manager(manager: SpatialAcousticsManager) -> void:
	_acoustics_manager = manager

## Registers or updates this room inside the spatial acoustics manager.
func register_in_manager(manager: SpatialAcousticsManager = null) -> AudioRoom:
	var mgr: SpatialAcousticsManager = manager if manager != null else _get_acoustics_manager()
	var alpha: float = get_absorption()
	var reverb_time: float = get_effective_reverb_time()
	
	if runtime_room == null:
		runtime_room = AudioRoomClass.new(room_name, reverb_time, alpha, floor_surface)
		runtime_room.material_preset = material_preset
		runtime_room.reverb_mode = int(reverb_mode)
		runtime_room.convolution_wet_db = convolution_wet_db
		runtime_room.convolution_dry_db = convolution_dry_db
	else:
		runtime_room.room_name = room_name
		runtime_room.reverb_decay_time = reverb_time
		runtime_room.damping = alpha
		runtime_room.floor_surface = floor_surface
		runtime_room.material_preset = material_preset
		runtime_room.reverb_mode = int(reverb_mode)
		runtime_room.convolution_wet_db = convolution_wet_db
		runtime_room.convolution_dry_db = convolution_dry_db

	if _dimensions == Vector3.ZERO:
		for child in get_children():
			if child is CollisionShape3D and child.shape != null:
				if child.shape is BoxShape3D:
					_dimensions = (child.shape as BoxShape3D).size
					break

	if _dimensions != Vector3.ZERO:
		var center_pos: Vector3 = TransformUtilsClass.world_position_of(self)
		runtime_room.set_bounds(AABB(center_pos - _dimensions * 0.5, _dimensions))

	if mgr != null:
		mgr.register_room(runtime_room)

	return runtime_room

func _update_ir_kernel() -> void:
	if _convolution_node == null:
		_convolution_node = ConvolutionReverbNodeClass.new()
	_convolution_node.wet_gain_db = convolution_wet_db
	_convolution_node.dry_gain_db = convolution_dry_db

	var kernel: PackedFloat32Array = PackedFloat32Array()
	if impulse_response_stream != null and impulse_response_stream.data.size() > 0:
		var raw = impulse_response_stream.data
		var count = min(raw.size() / 2, 512)
		kernel.resize(count)
		for i in range(count):
			var b0 = raw[i * 2]
			var b1 = raw[i * 2 + 1]
			var val16 = b0 | (b1 << 8)
			if val16 >= 32768:
				val16 -= 65536
			kernel[i] = float(val16) / 32768.0
	else:
		# Calibrated default concrete bunker IR kernel (exponential decay)
		kernel.resize(512)
		for i in range(512):
			kernel[i] = exp(-float(i) / 64.0) * sin(float(i) * 0.2)

	_convolution_node.set_impulse_response(kernel)
	if runtime_room != null:
		runtime_room.ir_kernel = kernel

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

func _get_acoustics_manager() -> SpatialAcousticsManager:
	if _acoustics_manager != null and is_instance_valid(_acoustics_manager):
		return _acoustics_manager
	if is_inside_tree():
		var root: Window = get_tree().root
		if root != null and root.has_node("OpenDou"):
			var node = root.get_node("OpenDou")
			if "spatial_acoustics" in node and node.spatial_acoustics != null:
				return node.spatial_acoustics
	if Engine.has_singleton("OpenDou"):
		var s = Engine.get_singleton("OpenDou")
		if "spatial_acoustics" in s and s.spatial_acoustics != null:
			return s.spatial_acoustics
	return null

func _on_body_entered(_body: Node) -> void:
	if not snapshot_on_enter.is_empty():
		if is_inside_tree():
			var root: Window = get_tree().root
			if root != null and root.has_node("OpenDou"):
				var node = root.get_node("OpenDou")
				if node != null and node.has_method("set_state"):
					node.set_state(&"MixSnapshot", snapshot_on_enter)
