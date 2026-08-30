class_name TestCyberpunkDemo
extends RefCounted

const SCENE_PATH: String = "res://scenes/demos/07_cyberpunk_infiltration/demo_cyberpunk_infiltration.tscn"

static func run_all() -> Array[String]:
	var failures: Array[String] = []
	
	# Test 1: File existence
	if not ResourceLoader.exists(SCENE_PATH):
		failures.append("Test 1a Failed: demo_cyberpunk_infiltration.tscn does not exist")
		return failures
		
	# Test 2: PackedScene loading
	var scene_res = load(SCENE_PATH)
	if not scene_res or not (scene_res is PackedScene):
		failures.append("Test 1b Failed: demo_cyberpunk_infiltration.tscn failed to load as PackedScene")
		return failures
		
	# Test 3: Scene instantiation
	var instance = scene_res.instantiate()
	if not instance:
		failures.append("Test 1c Failed: demo_cyberpunk_infiltration scene instantiation failed")
		return failures
		
	# Test 4: Sector 1 & Sector 2 presence
	if not instance.has_node("LevelGeometry/Sector1_Rooftop") or not instance.has_node("LevelGeometry/Sector2_ServerRoom"):
		failures.append("Test 1d Failed: Scene missing Sector 1 or Sector 2 geometry nodes")
		
	# Test 5: Sector 3 & Sector 4 presence
	if not instance.has_node("LevelGeometry/Sector3_FloodedDrainage") or not instance.has_node("LevelGeometry/Sector4_ExtractionArena"):
		failures.append("Test 1e Failed: Scene missing Sector 3 or Sector 4 geometry nodes")
		
	# Test 6: TacticalHUD CanvasLayer presence
	if not instance.has_node("TacticalHUD"):
		failures.append("Test 1f Failed: Scene missing TacticalHUD CanvasLayer node")
		
	# Test 7: Player controller, Camera3D, and AudioListener3D
	if not instance.has_node("Player") or not instance.has_node("Player/Camera3D") or not instance.has_node("Player/Camera3D/AudioListener3D"):
		failures.append("Test 1g Failed: Scene missing Player, Camera3D, or AudioListener3D")
		
	# Test 8: Emitters presence
	if not instance.has_node("LevelGeometry/Sector1_Rooftop/RainEmitter") or not instance.has_node("LevelGeometry/Sector2_ServerRoom/ServerEmitter"):
		failures.append("Test 1h Failed: Scene missing RainEmitter or ServerEmitter")
	if not instance.has_node("LevelGeometry/Sector3_FloodedDrainage/WaterEmitter") or not instance.has_node("LevelGeometry/Sector4_ExtractionArena/TurretEmitter"):
		failures.append("Test 1i Failed: Scene missing WaterEmitter or TurretEmitter")
		
	instance.free()
	return failures
