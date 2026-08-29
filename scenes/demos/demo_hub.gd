class_name DemoHub
extends Control

## Master Showcase Launcher and Navigation Hub for all OpenDou AAA Demo Scenes.

const DemoRoomsPortalsClass = preload("res://scenes/demos/01_spatial_rooms_portals/demo_rooms_portals.gd")
const DemoVoiceStressClass = preload("res://scenes/demos/02_massive_voice_stress/demo_voice_stress.gd")
const DemoSurfaceSwitchesClass = preload("res://scenes/demos/03_surface_switches_3d/demo_surface_switches.gd")
const DemoVehicleRPMClass = preload("res://scenes/demos/04_vehicle_blend_rpm/demo_vehicle_rpm.gd")
const DemoDynamicOcclusionClass = preload("res://scenes/demos/05_dynamic_occlusion_ray/demo_dynamic_occlusion.gd")
const DemoSoundBankStreamingClass = preload("res://scenes/demos/06_soundbank_streaming/demo_soundbank_streaming.gd")

var active_demo_node: Node = null

var description_label: Label
var active_demo_container: SubViewportContainer
var active_viewport: SubViewport

func _init() -> void:
	custom_minimum_size = Vector2(800, 600)
	_build_ui()

func _build_ui() -> void:
	var hsplit = HSplitContainer.new()
	hsplit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hsplit)
	
	# Left Sidebar (Demo Selection List)
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(280, 0)
	
	var title = Label.new()
	title.text = "🎯 OpenDou AAA Demo Hub"
	title.add_theme_font_size_override("font_size", 16)
	left_vbox.add_child(title)
	left_vbox.add_child(HSeparator.new())
	
	var demos = [
		{"id": 1, "name": "01. Macro-Acoustics & Portals", "desc": "Calculates sound diffraction across doorways and accumulates LPF filtering when opening/closing doors."},
		{"id": 2, "name": "02. Massive Voice Stress (250)", "desc": "Constrains 250 active sound emitters into a 16-channel hardware pool with zero-cost virtual tracking and micro-fades."},
		{"id": 3, "name": "03. Footstep Surface Switches", "desc": "Dynamic footstep audio resolving surface switches (Wood, Concrete, Metal, Water) with shuffle-bag anti-repetition."},
		{"id": 4, "name": "04. Vehicle Engine RPM Crossfade", "desc": "Smooth multilayer RPM crossfading with spline curves, silence culling (≤ -80 dB), and O(1) LUT evaluation."},
		{"id": 5, "name": "05. Dynamic Moving Obstacle Occlusion", "desc": "Multi-ray physics raycasting and slew-rate LPF smoothing preventing clicks and zipper noise."},
		{"id": 6, "name": "06. SoundBank Prefetch & Streaming", "desc": "Zero-latency RAM prefetch attack slice transitioning seamlessly to disk ring-buffer streaming."}
	]
	
	for d in demos:
		var btn = Button.new()
		btn.text = d["name"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var d_id = d["id"]
		var d_desc = d["desc"]
		btn.pressed.connect(func(): launch_demo(d_id, d_desc))
		left_vbox.add_child(btn)
		
	hsplit.add_child(left_vbox)
	
	# Right Viewport & Details Area
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	description_label = Label.new()
	description_label.text = "Select a demo from the left menu to view technical features and live audio execution."
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(description_label)
	right_vbox.add_child(HSeparator.new())
	
	active_demo_container = SubViewportContainer.new()
	active_demo_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_demo_container.stretch = true
	active_viewport = SubViewport.new()
	active_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	active_demo_container.add_child(active_viewport)
	right_vbox.add_child(active_demo_container)
	
	hsplit.add_child(right_vbox)

## Launches a specific demo scene inside the viewport.
func launch_demo(demo_id: int, desc: String) -> void:
	description_label.text = "💡 Feature: %s" % desc
	
	if active_demo_node:
		active_demo_node.queue_free()
		active_demo_node = null
		
	match demo_id:
		1: active_demo_node = DemoRoomsPortalsClass.new()
		2: active_demo_node = DemoVoiceStressClass.new()
		3: active_demo_node = DemoSurfaceSwitchesClass.new()
		4: active_demo_node = DemoVehicleRPMClass.new()
		5: active_demo_node = DemoDynamicOcclusionClass.new()
		6: active_demo_node = DemoSoundBankStreamingClass.new()
		
	if active_demo_node:
		active_viewport.add_child(active_demo_node)
