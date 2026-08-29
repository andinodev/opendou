class_name DemoVehicleRPM
extends Node

## Demo 04: Vehicle Engine RPM Multilayer Crossfading (AudioBlendContainer & O(1) LUT)

const AudioBlendContainerClass = preload("res://addons/opendou/resources/containers/audio_blend_container.gd")
const BlendLayerClass = preload("res://addons/opendou/resources/containers/blend_layer.gd")
const AudioPhysicalNodeClass = preload("res://addons/opendou/resources/containers/audio_physical_node.gd")
const AudioPlaybackContextClass = preload("res://addons/opendou/runtime/audio_playback_context.gd")

var blend_container: AudioBlendContainer
var current_rpm: float = 1000.0

func _ready() -> void:
	setup_engine_blend()

func setup_engine_blend() -> void:
	blend_container = AudioBlendContainerClass.new()
	blend_container.rtpc_parameter = &"RPM"
	blend_container.silence_threshold_db = -80.0
	
	# Layer 1: Idle (800 - 1800 RPM)
	var idle_layer = BlendLayerClass.new()
	idle_layer.node = AudioPhysicalNodeClass.new()
	idle_layer.node.resource_path = "res://sfx/engine/idle.wav"
	idle_layer.volume_curve = Curve.new()
	idle_layer.volume_curve.add_point(Vector2(800.0 / 8000.0, 1.0))
	idle_layer.volume_curve.add_point(Vector2(1800.0 / 8000.0, 0.0))
	blend_container.layers.append(idle_layer)
	
	# Layer 2: Low-Mid (1400 - 4500 RPM)
	var mid_layer = BlendLayerClass.new()
	mid_layer.node = AudioPhysicalNodeClass.new()
	mid_layer.node.resource_path = "res://sfx/engine/mid.wav"
	mid_layer.volume_curve = Curve.new()
	mid_layer.volume_curve.add_point(Vector2(1400.0 / 8000.0, 0.0))
	mid_layer.volume_curve.add_point(Vector2(3000.0 / 8000.0, 1.0))
	mid_layer.volume_curve.add_point(Vector2(4500.0 / 8000.0, 0.0))
	blend_container.layers.append(mid_layer)
	
	# Layer 3: High-Redline (4000 - 8000 RPM)
	var high_layer = BlendLayerClass.new()
	high_layer.node = AudioPhysicalNodeClass.new()
	high_layer.node.resource_path = "res://sfx/engine/high.wav"
	high_layer.volume_curve = Curve.new()
	high_layer.volume_curve.add_point(Vector2(4000.0 / 8000.0, 0.0))
	high_layer.volume_curve.add_point(Vector2(8000.0 / 8000.0, 1.0))
	blend_container.layers.append(high_layer)

## Sets the simulated vehicle engine RPM and returns the active resolved layers with volumes.
func set_rpm(rpm: float) -> Array:
	current_rpm = clampf(rpm, 0.0, 8000.0)
	var ctx = AudioPlaybackContextClass.new()
	# Normalized 0.0 to 1.0 parameter input
	ctx.parameters[&"RPM"] = current_rpm / 8000.0
	
	return blend_container.resolve_voices(ctx)
