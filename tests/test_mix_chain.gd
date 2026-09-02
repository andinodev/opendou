class_name TestMixChain
extends RefCounted

## Fase 8: un seno a 0 dBFS por dos reproductores a +6 dB: sin cadena, el bus pica muy por
## encima de 1.0; con la cadena GAME, no. Se hace en un bus propio para no tocar la cadena
## que el autoload instala en Master.

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const OpenDouAudioProbeClass = preload("res://tests/support/audio_probe.gd")
const MixChainClass = preload("res://addons/opendou/resources/mix_chain.gd")
const InstallerClass = preload("res://addons/opendou/runtime/mix_chain_installer.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("mix_chain")
	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)
	var bus: String = String(probe.bus_name())

	var sine := AudioStreamWAV.new()
	var rate: int = int(AudioServer.get_mix_rate())
	var bytes := PackedByteArray()
	bytes.resize(rate * 2)
	for i in range(rate):
		bytes.encode_s16(i * 2, int(sin(TAU * 440.0 * i / rate) * 32000.0))
	sine.format = AudioStreamWAV.FORMAT_16_BITS
	sine.mix_rate = rate
	sine.data = bytes
	sine.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sine.loop_end = rate

	var players: Array[AudioStreamPlayer] = []
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.stream = sine
		p.bus = bus
		p.volume_db = 6.0
		tree.root.add_child(p)
		p.play()
		players.append(p)
	for i in range(6):
		await tree.process_frame
		probe.drain()
	var peak_raw: float = await probe.measure_peak_over_frames(tree, 20)
	a.gt(peak_raw, 1.2, "sin cadena, dos senos a +6 dB pican muy por encima de 0 dBFS (control)")

	# La captura de la sonda esta al final del bus; el instalador inserta al principio, asi
	# que la sonda mide DESPUES del limitador.
	var chain = MixChainClass.from_preset(MixChainClass.Preset.GAME)
	a.ok(InstallerClass.install(chain, bus), "la cadena GAME se instala")
	a.ok(InstallerClass.is_installed(bus), "y se reconoce instalada por sus marcas")
	for i in range(6):
		await tree.process_frame
		probe.drain()
	var peak_chain: float = await probe.measure_peak_over_frames(tree, 20)
	print("[OpenDou] cadena de masterizacion: pico sin cadena %.2f, con GAME %.3f" % [peak_raw, peak_chain])
	a.lt(peak_chain, 1.0, "con la cadena GAME el pico no supera 0 dBFS")

	InstallerClass.install(chain, bus)
	var idx: int = AudioServer.get_bus_index(bus)
	var marked: int = 0
	for e in range(AudioServer.get_bus_effect_count(idx)):
		if AudioServer.get_bus_effect(idx, e).resource_name.begins_with("OpenDou_MixChain_"):
			marked += 1
	a.eq(marked, 2, "instalar dos veces deja dos efectos marcados, no cuatro")

	InstallerClass.uninstall(bus)
	a.ok(not InstallerClass.is_installed(bus), "desinstalar los quita")

	a.eq(str(ProjectSettings.get_setting(InstallerClass.SETTING, "")), "GAME", "el proyecto declara la cadena GAME")
	a.ok(InstallerClass.is_installed("Master"), "y Master la lleva instalada por el autoload")

	for p in players:
		p.stop()
		tree.root.remove_child(p)
		p.free()
	probe.teardown()
	return a
