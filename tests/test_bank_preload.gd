class_name TestBankPreload
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const SoundBankBuilderClass = preload("res://addons/opendou/runtime/soundbank_builder.gd")
const SoundBankManagerClass = preload("res://addons/opendou/runtime/soundbank_manager.gd")
const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")

const BANK_PATH: String = "user://test_preload_bank.bnk"

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("bank_preload")

	# Un stream en prefetch y otro en disco, para cubrir las dos rutas.
	var pref_samples := PackedFloat32Array([0.0, 0.5, -0.5, 0.25, -0.25, 0.0])
	var disk_samples := PackedFloat32Array([0.1, 0.2, 0.3, 0.2, 0.1, 0.0])
	var entries: Dictionary = {
		201: {
			"name": &"EnPrefetch", "is_prefetch": true,
			"sample_rate": 22050, "channels": 1, "samples": pref_samples
		},
		202: {
			"name": &"EnDisco", "is_prefetch": false,
			"sample_rate": 44100, "channels": 1, "samples": disk_samples
		},
	}
	a.ok(SoundBankBuilderClass.build_bank(BANK_PATH, entries), "el banco se compila")

	var mgr = SoundBankManagerClass.new()
	var bank = mgr.load_bank(BANK_PATH, &"preload_bank")
	a.ok(bank != null, "el banco se carga")
	if bank == null:
		return a

	# El stream de prefetch se reconstruye con sus metadatos correctos.
	var wav_pref = bank.build_stream(201)
	a.ok(wav_pref is AudioStreamWAV, "build_stream devuelve un AudioStreamWAV")
	if wav_pref != null:
		a.eq(wav_pref.format, AudioStreamWAV.FORMAT_16_BITS, "el formato es PCM16")
		a.eq(wav_pref.mix_rate, 22050, "el mix_rate viene del TOC")
		a.eq(wav_pref.stereo, false, "un stream mono no se marca estereo")
		# El banco guarda los bytes PCM16 sin transformarlos, asi que la
		# reconstruccion es byte-exacta salvo la cuantizacion del propio PCM16.
		var decoded := WavDecoderClass.to_mono_floats(wav_pref)
		a.eq(decoded.size(), pref_samples.size(), "se recuperan todas las muestras")
		for i in range(mini(decoded.size(), pref_samples.size())):
			a.approx(decoded[i], pref_samples[i], "muestra %d del stream en prefetch" % i, 0.0001)

	# El stream en disco tambien, que es la ruta que el desplazamiento del TOC
	# rompia.
	var wav_disk = bank.build_stream(202)
	a.ok(wav_disk is AudioStreamWAV, "build_stream reconstruye el stream en disco")
	if wav_disk != null:
		a.eq(wav_disk.mix_rate, 44100, "el mix_rate del stream en disco viene del TOC")
		var decoded_disk := WavDecoderClass.to_mono_floats(wav_disk)
		a.eq(decoded_disk.size(), disk_samples.size(), "se recuperan todas las muestras del disco")
		for i in range(mini(decoded_disk.size(), disk_samples.size())):
			a.approx(decoded_disk[i], disk_samples[i], "muestra %d del stream en disco" % i, 0.0001)

	# Un id que no existe devuelve null en lugar de reventar.
	a.eq(bank.build_stream(9999), null, "un stream inexistente devuelve null")

	# Un codec que GDScript no puede decodificar devuelve null y avisa, en lugar de
	# producir ruido.
	var meta = bank.stream_registry[201]
	var original_codec: int = meta.codec
	meta.codec = bank.CODEC_VORBIS
	a.eq(bank.build_stream(201), null, "un codec no soportado devuelve null")
	meta.codec = original_codec

	mgr.unload_bank(&"preload_bank")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BANK_PATH))
	return a
