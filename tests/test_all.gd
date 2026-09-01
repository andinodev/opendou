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
const TestHDRSnapshotsClass = preload("res://tests/test_hdr_snapshots.gd")
const TestInteractiveMusicClass = preload("res://tests/test_interactive_music.gd")
const TestDialogueLocalizationClass = preload("res://tests/test_dialogue_localization.gd")
const TestEarlyReflectionsHRTFClass = preload("res://tests/test_early_reflections_hrtf.gd")
const TestDSPAdvancedClass = preload("res://tests/test_dsp_advanced.gd")
const TestProfilerRewindClass = preload("res://tests/test_profiler_rewind.gd")
const TestStudioAdvancedUIClass = preload("res://tests/test_studio_advanced_ui.gd")
const TestCyberpunkDemoClass = preload("res://tests/test_cyberpunk_demo.gd")
const TestDeclarativeNodesClass = preload("res://tests/test_declarative_nodes.gd")
const TestAudibleMonitorClass = preload("res://tests/test_audible_monitor.gd")
const TestSynthNatureClass = preload("res://tests/test_synth_nature.gd")
const TestModularSynthEngineClass = preload("res://tests/test_modular_synth_engine.gd")
const TestSynthPresetRegistryClass = preload("res://tests/test_synth_preset_registry.gd")
const TestSynthVstWorkspaceClass = preload("res://tests/test_synth_vst_workspace.gd")
const TestAcousticDebuggerClass = preload("res://tests/test_acoustic_debugger.gd")
const TestSpatialAcousticsPhase1Class = preload("res://tests/test_spatial_acoustics_phase1.gd")
const TestSpatialAcousticsPhase2Class = preload("res://tests/test_spatial_acoustics_phase2.gd")
const TestTacticalCanyonDemoClass = preload("res://tests/test_tactical_canyon_demo.gd")
const TestGranularEmitter3DClass = preload("res://tests/test_granular_emitter_3d.gd")
const TestRoomConvolutionClass = preload("res://tests/test_room_convolution.gd")
const TestSoundBankPackagingAndStreamingClass = preload("res://tests/test_soundbank_packaging_and_streaming.gd")
const TestParameterArea3DClass = preload("res://tests/test_parameter_area_3d.gd")
const TestMultiPositionEmitter3DClass = preload("res://tests/test_multi_position_emitter_3d.gd")
const TestAcousticGeometryBakeClass = preload("res://tests/test_acoustic_geometry_bake.gd")
const TestAnimationSyncClass = preload("res://tests/test_animation_sync.gd")
const TestTacticalInfiltrationDemoClass = preload("res://tests/test_tactical_infiltration_demo.gd")
const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TestAudioOutputClass = preload("res://tests/test_audio_output.gd")
const TestNativePlayerPoolClass = preload("res://tests/test_native_player_pool.gd")
const TestListenerResolverClass = preload("res://tests/test_listener_resolver.gd")
const TestOcclusionSchedulerClass = preload("res://tests/test_occlusion_scheduler.gd")
const TestEarlyReflectionsClass = preload("res://tests/test_early_reflections.gd")
const TestNoUnfulfilledClaimsClass = preload("res://tests/test_no_unfulfilled_claims.gd")
const TestTransformUtilsClass = preload("res://tests/test_transform_utils.gd")
const TestWavDecoderClass = preload("res://tests/test_wav_decoder.gd")

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
	
	var r26 = TestHDRSnapshotsClass.run_all()
	total_tests += 9
	all_failures.append_array(r26)
	
	var r27 = TestInteractiveMusicClass.run_all()
	total_tests += 10
	all_failures.append_array(r27)
	
	var r28 = TestDialogueLocalizationClass.run_all()
	total_tests += 7
	all_failures.append_array(r28)
	
	var r29 = TestEarlyReflectionsHRTFClass.run_all()
	total_tests += 7
	all_failures.append_array(r29)
	
	var r30 = TestDSPAdvancedClass.run_all()
	total_tests += 5
	all_failures.append_array(r30)
	
	var r31 = TestProfilerRewindClass.run_all()
	total_tests += 6
	all_failures.append_array(r31)
	
	var r32 = TestStudioAdvancedUIClass.run_all()
	total_tests += 12
	all_failures.append_array(r32)
	
	var r33 = TestCyberpunkDemoClass.run_all()
	total_tests += 25
	all_failures.append_array(r33)
	
	var r34 = TestDeclarativeNodesClass.run_all()
	total_tests += 20
	all_failures.append_array(r34)
	
	var r35 = TestAudibleMonitorClass.run_all()
	total_tests += 7
	all_failures.append_array(r35)
	
	var r36 = TestSynthNatureClass.run_all()
	total_tests += 6
	all_failures.append_array(r36)
	
	var r37 = TestModularSynthEngineClass.run_all()
	total_tests += 16
	all_failures.append_array(r37)
	
	var r38 = TestSynthPresetRegistryClass.run_all()
	total_tests += 8
	all_failures.append_array(r38)
	
	var r39 = TestSynthVstWorkspaceClass.run_all()
	total_tests += 10
	all_failures.append_array(r39)
	
	var r40 = TestAcousticDebuggerClass.run_all()
	total_tests += 6
	all_failures.append_array(r40)
	
	var r41 = TestSpatialAcousticsPhase1Class.run_all()
	total_tests += 8
	all_failures.append_array(r41)
	
	var r42 = TestSpatialAcousticsPhase2Class.run_all()
	total_tests += 10
	all_failures.append_array(r42)
	
	var r43 = TestTacticalCanyonDemoClass.run_all()
	total_tests += 11
	all_failures.append_array(r43)
	
	var r44 = TestGranularEmitter3DClass.run_all()
	total_tests += 5
	all_failures.append_array(r44)
	
	var r45 = TestRoomConvolutionClass.run_all()
	total_tests += 5
	all_failures.append_array(r45)
	
	var r46 = TestSoundBankPackagingAndStreamingClass.run_all()
	total_tests += 5
	all_failures.append_array(r46)
	
	var r47 = TestParameterArea3DClass.run_all()
	total_tests += 11
	all_failures.append_array(r47)
	
	var r48 = TestMultiPositionEmitter3DClass.run_all()
	total_tests += 8
	all_failures.append_array(r48)
	
	var r49 = TestAcousticGeometryBakeClass.run_all()
	total_tests += 10
	all_failures.append_array(r49)
	
	var r50 = TestAnimationSyncClass.run_all()
	total_tests += 10
	all_failures.append_array(r50)
	
	var r51 = TestTacticalInfiltrationDemoClass.run_all()
	total_tests += 10
	all_failures.append_array(r51)
	
	# Suites nuevas de la Fase 1: cuentan aserciones reales en lugar de un total
	# escrito a mano.
	var pool_res = TestNativePlayerPoolClass.run_all()
	total_tests += pool_res.assertions_run
	all_failures.append_array(pool_res.failures)

	var claims_res = TestNoUnfulfilledClaimsClass.run_all()
	total_tests += claims_res.assertions_run
	all_failures.append_array(claims_res.failures)

	var xform_res = TestTransformUtilsClass.run_all()
	total_tests += xform_res.assertions_run
	all_failures.append_array(xform_res.failures)

	var wav_res = TestWavDecoderClass.run_all()
	total_tests += wav_res.assertions_run
	all_failures.append_array(wav_res.failures)

	return {
		"total": total_tests,
		"failures": all_failures,
		"passed": total_tests - all_failures.size()
	}

## Suite asincrona: tests que necesitan avanzar frames del SceneTree, como todas
## las aserciones de audio real. Se ejecuta despues de la suite sincrona.
##
## Cada funcion run_*_async que se anada a un test de audio hay que invocarla
## desde aqui (o desde el run_all_async de su archivo), o quedara escrita y nunca
## se ejecutara, que es exactamente el tipo de ceguera que esta fase corrige.
static func run_async_suite(tree: SceneTree):
	var acc := OpenDouAssertClass.new()
	acc.absorb(await TestAudioOutputClass.run_all_async(tree))
	acc.absorb(await TestListenerResolverClass.run_all_async(tree))
	acc.absorb(await TestOcclusionSchedulerClass.run_all_async(tree))
	acc.absorb(await TestEarlyReflectionsClass.run_all_async(tree))
	return {
		"total": acc.assertions_run,
		"failures": acc.failures,
		"passed": acc.assertions_run - acc.failures.size(),
	}
