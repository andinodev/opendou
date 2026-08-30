class_name DemoHub
extends Control

## Master Demo Launcher and Interactive Feature Showcase for OpenDou

const DEMO_SCENES = {
	1: "res://scenes/demos/01_spatial_rooms_portals/demo_rooms_portals.tscn",
	2: "res://scenes/demos/02_massive_voice_stress/demo_voice_stress.tscn",
	3: "res://scenes/demos/03_surface_switches_3d/demo_surface_switches.tscn",
	4: "res://scenes/demos/04_vehicle_blend_rpm/demo_vehicle_rpm.tscn",
	5: "res://scenes/demos/05_dynamic_occlusion_ray/demo_dynamic_occlusion.tscn",
	6: "res://scenes/demos/06_soundbank_streaming/demo_soundbank_streaming.tscn",
	7: "res://scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn"
}

const MASTER_SANDBOX_SCENE = "res://scenes/demos/master_sandbox/master_vertical_slice.tscn"

var active_demo_node: Node = null

@onready var btn_master: Button = get_node_or_null("MainContainer/HeaderPanel/Margin/HBox/BtnMasterSandbox")
@onready var btn_launch1: Button = get_node_or_null("MainContainer/GridContainer/Card1/Margin/VBox/BtnLaunch1")
@onready var btn_launch2: Button = get_node_or_null("MainContainer/GridContainer/Card2/Margin/VBox/BtnLaunch2")
@onready var btn_launch3: Button = get_node_or_null("MainContainer/GridContainer/Card3/Margin/VBox/BtnLaunch3")
@onready var btn_launch4: Button = get_node_or_null("MainContainer/GridContainer/Card4/Margin/VBox/BtnLaunch4")
@onready var btn_launch5: Button = get_node_or_null("MainContainer/GridContainer/Card5/Margin/VBox/BtnLaunch5")
@onready var btn_launch6: Button = get_node_or_null("MainContainer/GridContainer/Card6/Margin/VBox/BtnLaunch6")
@onready var btn_launch7: Button = get_node_or_null("MainContainer/HeroCard/Margin/HBox/BtnLaunch7")
@onready var btn_tests: Button = get_node_or_null("MainContainer/HeaderPanel/Margin/HBox/BtnRunTests")

func _ready() -> void:
	_connect_ui()

func _connect_ui() -> void:
	if btn_master:
		btn_master.pressed.connect(func(): get_tree().change_scene_to_file(MASTER_SANDBOX_SCENE))
	if btn_launch1:
		btn_launch1.pressed.connect(func(): switch_to_demo(1))
	if btn_launch2:
		btn_launch2.pressed.connect(func(): switch_to_demo(2))
	if btn_launch3:
		btn_launch3.pressed.connect(func(): switch_to_demo(3))
	if btn_launch4:
		btn_launch4.pressed.connect(func(): switch_to_demo(4))
	if btn_launch5:
		btn_launch5.pressed.connect(func(): switch_to_demo(5))
	if btn_launch6:
		btn_launch6.pressed.connect(func(): switch_to_demo(6))
	if btn_launch7:
		btn_launch7.pressed.connect(func(): switch_to_demo(7))
	if btn_tests:
		btn_tests.pressed.connect(_on_run_tests_pressed)

func switch_to_demo(id: int) -> void:
	if DEMO_SCENES.has(id):
		get_tree().change_scene_to_file(DEMO_SCENES[id])

## Headless / test programmatic launcher
func launch_demo(id: int, _desc: String = "") -> void:
	if DEMO_SCENES.has(id):
		var scene_res = load(DEMO_SCENES[id])
		if scene_res:
			active_demo_node = scene_res.instantiate()

func _on_run_tests_pressed() -> void:
	# Run tests in-editor or print status
	print("Running OpenDou Test Suite...")
