class_name TestAll
extends RefCounted

const TestRTPCValueClass = preload("res://tests/test_rtpc_value.gd")
const TestRTPCBindingClass = preload("res://tests/test_rtpc_binding.gd")
const TestEventInstanceClass = preload("res://tests/test_event_instance.gd")
const TestEventManagerClass = preload("res://tests/test_event_manager.gd")
const TestRandomContainerClass = preload("res://tests/test_random_container.gd")
const TestSwitchContainerClass = preload("res://tests/test_switch_container.gd")
const TestBlendContainerClass = preload("res://tests/test_blend_container.gd")
const TestCompositeTreeClass = preload("res://tests/test_composite_tree.gd")
const TestVoicePoolClass = preload("res://tests/test_voice_pool.gd")
const TestVirtualTrackingClass = preload("res://tests/test_virtual_tracking.gd")
const TestGameSyncsClass = preload("res://tests/test_game_syncs.gd")
const TestModulatorsClass = preload("res://tests/test_modulators.gd")
const TestSoundBanksClass = preload("res://tests/test_soundbanks.gd")
const TestRingBufferClass = preload("res://tests/test_ringbuffer.gd")
const TestSpatialAcousticsClass = preload("res://tests/test_spatial_acoustics.gd")
const TestMicroAcousticsClass = preload("res://tests/test_micro_acoustics.gd")
const TestLiveUpdateClass = preload("res://tests/test_live_update.gd")
const TestVoiceTelemetryClass = preload("res://tests/test_voice_telemetry.gd")
const TestEditorNodesClass = preload("res://tests/test_editor_nodes.gd")
const TestGraphSerializerClass = preload("res://tests/test_graph_serializer.gd")
const TestTransportBarClass = preload("res://tests/test_transport_bar.gd")
const TestRadarViewClass = preload("res://tests/test_radar_view.gd")
const TestBankPanelClass = preload("res://tests/test_bank_panel.gd")
const TestStudioMainClass = preload("res://tests/test_studio_main.gd")
const TestDemoSuiteClass = preload("res://tests/test_demo_suite.gd")

static func run_suite() -> Dictionary:
	var total_tests: int = 0
	var all_failures: Array[String] = []
	
	var r1 = TestRTPCValueClass.run_all()
	total_tests += 5
	all_failures.append_array(r1)
	
	var r2 = TestRTPCBindingClass.run_all()
	total_tests += 5
	all_failures.append_array(r2)
	
	var r3 = TestEventInstanceClass.run_all()
	total_tests += 5
	all_failures.append_array(r3)
	
	var r4 = TestEventManagerClass.run_all()
	total_tests += 4
	all_failures.append_array(r4)
	
	var r5 = TestRandomContainerClass.run_all()
	total_tests += 3
	all_failures.append_array(r5)
	
	var r6 = TestSwitchContainerClass.run_all()
	total_tests += 3
	all_failures.append_array(r6)
	
	var r7 = TestBlendContainerClass.run_all()
	total_tests += 3
	all_failures.append_array(r7)
	
	var r8 = TestCompositeTreeClass.run_all()
	total_tests += 2
	all_failures.append_array(r8)
	
	var r9 = TestVoicePoolClass.run_all()
	total_tests += 4
	all_failures.append_array(r9)
	
	var r10 = TestVirtualTrackingClass.run_all()
	total_tests += 5
	all_failures.append_array(r10)
	
	var r11 = TestGameSyncsClass.run_all()
	total_tests += 5
	all_failures.append_array(r11)
	
	var r12 = TestModulatorsClass.run_all()
	total_tests += 3
	all_failures.append_array(r12)
	
	var r13 = TestSoundBanksClass.run_all()
	total_tests += 4
	all_failures.append_array(r13)
	
	var r14 = TestRingBufferClass.run_all()
	total_tests += 3
	all_failures.append_array(r14)
	
	var r15 = TestSpatialAcousticsClass.run_all()
	total_tests += 3
	all_failures.append_array(r15)
	
	var r16 = TestMicroAcousticsClass.run_all()
	total_tests += 2
	all_failures.append_array(r16)
	
	var r17 = TestLiveUpdateClass.run_all()
	total_tests += 4
	all_failures.append_array(r17)
	
	var r18 = TestVoiceTelemetryClass.run_all()
	total_tests += 2
	all_failures.append_array(r18)
	
	var r19 = TestEditorNodesClass.run_all()
	total_tests += 5
	all_failures.append_array(r19)
	
	var r20 = TestGraphSerializerClass.run_all()
	total_tests += 2
	all_failures.append_array(r20)
	
	var r21 = TestTransportBarClass.run_all()
	total_tests += 3
	all_failures.append_array(r21)
	
	var r22 = TestRadarViewClass.run_all()
	total_tests += 3
	all_failures.append_array(r22)
	
	var r23 = TestBankPanelClass.run_all()
	total_tests += 2
	all_failures.append_array(r23)
	
	var r24 = TestStudioMainClass.run_all()
	total_tests += 3
	all_failures.append_array(r24)
	
	var r25 = TestDemoSuiteClass.run_all()
	total_tests += 7
	all_failures.append_array(r25)
	
	return {
		"total": total_tests,
		"failures": all_failures,
		"passed": total_tests - all_failures.size()
	}
