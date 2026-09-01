# Fase 3 — Rendimiento y consolidación: plan de implementación

> **Para trabajadores agénticos:** SUB-SKILL REQUERIDA: usa superpowers:subagent-driven-development (recomendado) o superpowers:executing-plans para implementar este plan tarea a tarea. Los pasos usan sintaxis de checkbox (`- [ ]`) para seguimiento.

**Goal:** Que el pipeline de SoundBanks produzca audio real, que el búfer byte a byte y la afirmación de "SPSC lock-free" desaparezcan con el código muerto del que hablaban, que el inspector deje de leer disco en cada refresco, y que las dos implementaciones duplicadas de HDR se conviertan en una cableada al ciclo por frame.

**Architecture:** Casi todo se resuelve borrando. El pipeline ODBK pasa de un `mix()` que nadie consumía a precarga real a `AudioStreamWAV`, y con él se van el ring buffer y `BankStreamPlayback`. El HDR se consolida en `AudioHDREngine` y se cablea **por voz** en el paso «aplicar» que la Fase 1 construyó, no por bus.

**Tech Stack:** Godot 4.7.2, GDScript. Sin GDExtension. Sin dependencias externas.

**Spec:** `docs/superpowers/specs/2026-09-01-fase3-rendimiento-design.md`

## Global Constraints

- **Godot 4.7.2** exactamente. El binario está en `/Users/Daniel/Downloads/Godot.app/Contents/MacOS/Godot`.
- **Rama `main`.** Este proyecto trabaja en una sola rama, por indicación explícita del usuario. No crees ramas.
- **Ejecuta siempre `./run_tests.sh`**, nunca Godot a mano. Hace tres comprobaciones que la suite no hace: `SCRIPT ERROR`/`Parse Error` fatales, trinquete de fugas de ObjectDB y regeneración de la caché de clases.
- **Comentarios y docstrings en español**, identificadores en inglés, **indentación con tabuladores**.
- **Una entrada de TOC del formato ODBK son 40 bytes**: `id`(4) + `codec`(2) + `channels`(2) + `sample_rate`(4) + `prefetch_offset`(4) + `prefetch_length`(4) + `disk_offset`(8) + `disk_length`(8) + relleno(4). La cabecera son 24 bytes.
- **`calculate_voice_gain_db()` devuelve el nivel de salida absoluto**, no una ganancia que sumar: su cuerpo es `clampf(loudness - window_top, -80.0, 0.0)`. Es siempre ≤ 0, así que funciona como atenuación al sumarse.
- **La entrada del HDR es la sonoridad de diseño del evento**, no el nivel de mezcla. Son magnitudes distintas.
- **Las funciones estáticas con `await` y tipo de retorno propio funcionan** entre scripts. Si una falla al compilar, la causa es la caché de clases.
- **No cuentes frames fijos para afirmar silencio.** Usa `OpenDouAudioProbe.await_silence()`.
- **Un `AudioStreamPlayer3D` sin `Camera3D` ni `AudioListener3D` activos no emite nada.** Si mides cero en un test 3D, comprueba eso antes de sospechar del código.
- **Una cámara con `make_current()` queda referenciada por el viewport**: llama `clear_current()` antes de liberarla.
- **Prohibido tocar** lo que pertenece a fases posteriores: empaquetado, rutas `res://` del addon, doble registro de tipos, `class_name` globales, main screen, `.gitignore`, y las demos salvo lo mínimo que exija el runner.
- **Cada tarea acaba en commit** con el estilo del repo (`feat(scope):`, `fix(scope):`, `perf(scope):`).

## Notas de arranque

El baseline al empezar es `495/495 PASSED`, cero `SCRIPT ERROR`, fugas **595** (techo en `tests/leak_budget.txt`), árbol de git limpio. Si no es eso, para y averigua por qué.

**Hallazgo nuevo que este plan incorpora.** Al preparar la fase se descubrió un defecto que no estaba entre las 24 observaciones: `soundbank_builder.gd:73` calcula `toc_size = num_streams * 36` cuando una entrada de TOC son **40 bytes**, y su propio comentario enumera los campos como `(4 + 2 + 2 + 4 + 4 + 4 + 8 + 8 + 4)`, que suma 40. `soundbank_compiler.gd` sí usa 40. Consecuencia: en bancos escritos con `build_bank` que tengan streams en disco, `stream_block_offset` y cada `disk_offset` quedan 4 bytes por stream desplazados, y `read_stream_chunk()` lee del sitio equivocado.

El test no lo caza porque afirma `chunk.size() != 12`, o sea **solo el tamaño y nunca el contenido**: la lectura desplazada sigue devolviendo 12 bytes. Es la Tarea 1 de este plan, y va primera porque `build_stream()` depende de que los offsets de disco sean correctos.

**Aviso sobre el conteo:** borrar `tests/test_ringbuffer.gd` **baja** el número de aserciones, y eso es correcto: cubrían código que deja de existir. No intentes compensarlo.

**Aviso sobre fugas:** si el trinquete sube, investiga antes de tocar el número. En las fases anteriores cada subida delató fugas preexistentes.

---

## File Structure

### Archivos nuevos

| Archivo | Responsabilidad |
|---|---|
| `tests/test_bank_preload.gd` | Round-trip byte-exacto del formato, construcción de `AudioStreamWAV`, rechazo de codecs, caché de streams. |
| `tests/test_hdr_voice_gain.gd` | Contribución nula con la sonoridad por defecto, ducking real con una voz fuerte, interruptor. |
| `tests/test_preset_hint_cache.gd` | La caché no invoca `load()` y se invalida al cambiar los presets. |

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `addons/opendou/runtime/soundbank_builder.gd:73` | `36` → `40` en el cálculo del TOC. |
| `tests/test_soundbank_packaging_and_streaming.gd:47` | Comparar **contenido** del chunk de disco, no solo su tamaño. |
| `addons/opendou/runtime/soundbank.gd` | `build_stream()` y las constantes de codec. |
| `addons/opendou/runtime/soundbank_manager.gd` | Caché perezosa de streams y purga al descargar. |
| `addons/opendou/runtime/audio_event_manager.gd` | `get_bank_stream()`, motor HDR, `hdr_enabled`, cableado por voz en el ciclo. |
| `addons/opendou/resources/audio_event_def.gd` | `hdr_loudness_db`. |
| `addons/opendou/runtime/synth/synth_preset_registry.gd` | Caché del `hint_string` con invalidación automática. |
| `addons/opendou/nodes/opendou_event_player{,_2d,_3d}.gd` | `_get_property_list()` usa la caché en vez de `load()`. |
| `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd` | Pierde `hdr_manager`. |
| `scenes/demos/06_soundbank_streaming/demo_soundbank_streaming.gd` | Deja de usar `BankStreamPlayback`. |
| `scenes/demos/08_tactical_canyon/demo_tactical_canyon.gd`, `tests/test_tactical_canyon_demo.gd` | Usan el motor HDR consolidado. |
| `README.md`, `docs/tasks/roadmap.md` | Sin streaming asíncrono desde disco. |
| **Eliminados** | `runtime/audio_ring_buffer.gd`, `runtime/bank_stream_playback.gd`, `runtime/spatial/hdr_audio_manager.gd`, `tests/test_ringbuffer.gd` (y sus `.uid`) |

---

## Task 1: El TOC son 40 bytes, no 36

**Hallazgo nuevo, no estaba entre las 24 observaciones.**

**Files:**
- Modify: `addons/opendou/runtime/soundbank_builder.gd:71-73`
- Modify: `tests/test_soundbank_packaging_and_streaming.gd:47-49`

**Interfaces:**
- No cambia ninguna firma. Cambia el contenido binario que produce `build_bank()` para bancos con streams en disco.

- [ ] **Step 1: Convierte el test en una comprobación de contenido**

En `tests/test_soundbank_packaging_and_streaming.gd`, sustituye:

```gdscript
	var chunk = bank.read_stream_chunk(102, 0, 12)
	if chunk.size() != 12:
		failures.append("Test 5 Failed: Disk streaming chunk read mismatch, expected 12 got %d" % chunk.size())
```

por:

```gdscript
	# Comparar CONTENIDO, no solo tamano. Este test afirmaba unicamente
	# chunk.size() != 12, y con los offsets de disco desplazados la lectura caia
	# en el sitio equivocado y seguia devolviendo 12 bytes: pasaba devolviendo
	# audio incorrecto.
	var chunk = bank.read_stream_chunk(102, 0, 12)
	if chunk.size() != 12:
		failures.append("Test 5 Failed: Disk streaming chunk read mismatch, expected 12 got %d" % chunk.size())
	else:
		var expected := PackedFloat32Array([0.1, 0.2, 0.3, 0.2, 0.1, 0.0])
		for i in range(expected.size()):
			var lo: int = chunk[i * 2]
			var hi: int = chunk[i * 2 + 1]
			var v: int = lo | (hi << 8)
			if v >= 32768:
				v -= 65536
			var decoded: float = float(v) / 32767.0
			if absf(decoded - expected[i]) > 0.001:
				failures.append("Test 5b Failed: muestra %d del stream en disco vale %f, se esperaba %f" % [i, decoded, expected[i]])
				break
```

El divisor es 32767 y no 32768 porque es el factor que usa `build_bank` al codificar (`int(s * 32767.0)`).

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `Test 5b Failed: muestra 0 del stream en disco vale ...`. El desplazamiento es de 8 bytes (2 streams × 4), así que la lectura arranca 4 muestras antes de donde debe y devuelve datos del bloque de prefetch o del relleno.

- [ ] **Step 3: Corrige el cálculo**

En `addons/opendou/runtime/soundbank_builder.gd`, sustituye:

```gdscript
	# Header size: 4 (magic) + 4 (ver) + 4 (num) + 4 (pref_size) + 8 (stream_off) = 24 bytes
	# TOC size: num_streams * 36 bytes (4 + 2 + 2 + 4 + 4 + 4 + 8 + 8 + 4)
	var header_size: int = 24
	var toc_size: int = num_streams * 36
```

por:

```gdscript
	# Cabecera: 4 (magic) + 4 (version) + 4 (num) + 4 (pref_size) + 8 (stream_off) = 24 bytes
	# TOC: 40 bytes por entrada = 4 (id) + 2 (codec) + 2 (channels) + 4 (rate)
	#      + 4 (pref_off) + 4 (pref_len) + 8 (disk_off) + 8 (disk_len) + 4 (relleno)
	#
	# Aqui decia 36 mientras el comentario de al lado enumeraba campos que suman
	# 40: stream_block_offset y cada disk_offset salian 4 bytes por stream
	# desplazados, y read_stream_chunk() leia del sitio equivocado.
	# soundbank_compiler.gd ya usaba 40.
	const TOC_ENTRY_SIZE: int = 40
	var header_size: int = 24
	var toc_size: int = num_streams * TOC_ENTRY_SIZE
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Si `tests/test_soundbanks.gd` empieza a fallar, mira qué afirmaba: usa `compile_bank`, que ya calculaba bien, así que no debería cambiar.

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/soundbank_builder.gd tests/test_soundbank_packaging_and_streaming.gd
git commit -m "fix(soundbank): TOC entries are 40 bytes, not 36

build_bank() calculaba toc_size = num_streams * 36 mientras su propio comentario
enumeraba los campos como (4+2+2+4+4+4+8+8+4), que suma 40. soundbank_compiler.gd
si usaba 40. Consecuencia: en bancos con streams en disco, stream_block_offset y
cada disk_offset quedaban 4 bytes por stream desplazados y read_stream_chunk()
leia del sitio equivocado.

El test no lo cazaba porque afirmaba unicamente chunk.size() != 12: la lectura
desplazada seguia devolviendo 12 bytes. Ahora compara el contenido decodificado.

Defecto encontrado al preparar la Fase 3; no estaba entre las 24 observaciones
del analisis original."
```

---

## Task 2: `SoundBank.build_stream()`

**Files:**
- Modify: `addons/opendou/runtime/soundbank.gd`
- Create: `tests/test_bank_preload.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `SoundBank.build_stream(stream_id: int) -> AudioStreamWAV` (null si no se puede), y las constantes `CODEC_PCM16 = 0`, `CODEC_ADPCM = 1`, `CODEC_VORBIS = 2`.
- Consumes: `SoundBank.get_prefetch_slice()` y `read_stream_chunk()`, ya existentes; `OpenDouWavDecoder.to_mono_floats()` de la Fase 2 para las aserciones del test.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_bank_preload.gd`:

```gdscript
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

	# Un codec que GDScript no puede decodificar devuelve null y avisa, en lugar
	# de producir ruido.
	var meta = bank.stream_registry[201]
	var original_codec: int = meta.codec
	meta.codec = bank.CODEC_VORBIS
	a.eq(bank.build_stream(201), null, "un codec no soportado devuelve null")
	meta.codec = original_codec

	mgr.unload_bank(&"preload_bank")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BANK_PATH))
	return a
```

Registra la suite en `run_suite()` de `tests/test_all.gd` con su `preload`, siguiendo el patrón de las demás:

```gdscript
const TestBankPreloadClass = preload("res://tests/test_bank_preload.gd")
```

```gdscript
	var bank_res = TestBankPreloadClass.run_all()
	total_tests += bank_res.assertions_run
	all_failures.append_array(bank_res.failures)
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO con `SCRIPT ERROR` por `build_stream` y `CODEC_VORBIS` inexistentes, que el runner marca como fatales.

- [ ] **Step 3: Implementa `build_stream()`**

En `addons/opendou/runtime/soundbank.gd`, añade las constantes junto a la cabecera:

```gdscript
## Codecs que el TOC puede declarar.
const CODEC_PCM16: int = 0
const CODEC_ADPCM: int = 1
const CODEC_VORBIS: int = 2
```

Y el método, tras `get_prefetch_slice()`:

```gdscript
## Reconstruye un stream del banco como AudioStreamWAV reproducible.
##
## Es lo que convierte el pipeline ODBK en algo que suena: antes el banco se leia
## correctamente y sus bytes no llegaban a ninguna salida de audio.
##
## El banco guarda los bytes PCM16 sin transformarlos, asi que la reconstruccion
## es byte-exacta: lo que entro al compilador es lo que sale.
##
## Devuelve null para los codecs que GDScript no puede decodificar, avisando de
## cual era, en lugar de producir ruido.
func build_stream(stream_id: int) -> AudioStreamWAV:
	if not stream_registry.has(stream_id):
		return null
	var meta: SoundBankMetadata = stream_registry[stream_id]

	if meta.codec != CODEC_PCM16:
		push_warning("[OpenDou] el stream %d del banco '%s' declara el codec %d, que GDScript no puede decodificar. Solo PCM16 (codec 0) es reproducible; recompila el banco sin comprimir." % [
			stream_id, str(bank_name), meta.codec])
		return null

	# En los bancos que produce el compilador, prefetch y disco son exclusivos por
	# stream. Se concatenan de todas formas para que un banco que usara ambos
	# bloques siguiera reconstruyendose entero.
	var data := PackedByteArray()
	var pref: PackedByteArray = get_prefetch_slice(stream_id)
	if pref.size() > 0:
		data.append_array(pref)
	if meta.disk_length > 0:
		data.append_array(read_stream_chunk(stream_id, 0, meta.disk_length))

	if data.is_empty():
		return null

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = meta.channels >= 2
	wav.mix_rate = maxi(1, meta.sample_rate)
	wav.data = data
	return wav
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Las muestras del stream en disco solo coinciden si la Tarea 1 está hecha; si fallan, comprueba que `toc_size` usa 40.

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/soundbank.gd tests/test_bank_preload.gd tests/test_all.gd
git commit -m "feat(soundbank): rebuild bank streams as playable AudioStreamWAV

Es lo que convierte el pipeline ODBK en algo que suena: el banco se leia
correctamente y sus bytes no llegaban a ninguna salida de audio.

El banco guarda los bytes PCM16 sin transformarlos, asi que la reconstruccion es
byte-exacta y el test la compara muestra a muestra por las dos rutas, prefetch y
disco. Los codecs que GDScript no puede decodificar devuelven null con un aviso
que los nombra, igual que hace el decodificador WAV."
```

---

## Task 3: Caché de streams y un evento que suena desde un banco

**Files:**
- Modify: `addons/opendou/runtime/soundbank_manager.gd`
- Modify: `addons/opendou/runtime/audio_event_manager.gd`
- Modify: `tests/test_bank_preload.gd`
- Modify: `tests/test_audio_output.gd`

**Interfaces:**
- Produces: `SoundBankManager.get_stream(bank_name: StringName, stream_id: int) -> AudioStreamWAV` con caché perezosa; `unload_bank()` purga la caché de ese banco.
- Produces: `AudioEventManager.get_bank_stream(bank_name: StringName, stream_id: int) -> AudioStreamWAV`.
- Consumes: `SoundBank.build_stream()` de la Tarea 2.

- [ ] **Step 1: Escribe las dos aserciones que faltan**

Añade a `tests/test_bank_preload.gd`, antes del `mgr.unload_bank(...)`:

```gdscript
	# La cache devuelve el MISMO objeto: reconstruir el AudioStreamWAV en cada
	# peticion desperdiciaria memoria y tiempo.
	var cached_a = mgr.get_stream(&"preload_bank", 201)
	var cached_b = mgr.get_stream(&"preload_bank", 201)
	a.ok(cached_a != null, "get_stream devuelve un stream")
	a.eq(cached_a, cached_b, "dos llamadas devuelven el mismo objeto cacheado")
	a.eq(mgr.get_stream(&"banco_que_no_existe", 1), null, "un banco inexistente devuelve null")
```

Y en `tests/test_audio_output.gd`, la aserción que demuestra que el pipeline es real. Cableala en `run_all_async` con `a.absorb(await run_bank_event_audio_async(tree))`:

```gdscript
## Un evento cuyo stream viene de un banco debe sonar.
##
## Es la asercion que demuestra que el pipeline ODBK produce audio: antes el banco
## se leia bien y sus bytes no llegaban a ninguna salida.
static func run_bank_event_audio_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("bank_event_audio")

	# Un banco con un tono sostenido, empaquetado desde sus bytes PCM16.
	var tone := AudioSynthesizerClass.create_tone(440.0, 2.0, 0.8, false)
	var bank_path := "user://test_event_bank.bnk"
	var entries: Dictionary = {
		301: {
			"name": &"TonoDeBanco", "is_prefetch": true,
			"sample_rate": 44100, "channels": 1, "data": tone.data
		},
	}
	a.ok(SoundBankBuilderClass.build_bank(bank_path, entries), "el banco del evento se compila")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	a.ok(manager.load_bank(bank_path, &"event_bank") != null, "el manager carga el banco")
	var bank_stream = manager.get_bank_stream(&"event_bank", 301)
	a.ok(bank_stream is AudioStreamWAV, "get_bank_stream devuelve un AudioStreamWAV")

	var def = AudioEventDefClass.new(&"DesdeBanco", bank_stream)
	def.target_bus = probe.bus_name()
	def.stream_length = float(bank_stream.get_length()) if bank_stream != null else 0.0
	def.is_looping = true
	manager.register_event_definition(def)
	manager.post_event(&"DesdeBanco", null)

	probe.drain()
	var peak: float = await probe.measure_peak_over_frames(tree, 40)
	a.gt(peak, 0.01, "un evento cuyo stream viene de un banco suena")

	manager.stop_all()
	manager.unload_bank(&"event_bank")
	probe.teardown()
	manager.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(bank_path))
	return a
```

Añade a la cabecera de `tests/test_audio_output.gd`:

```gdscript
const SoundBankBuilderClass = preload("res://addons/opendou/runtime/soundbank_builder.gd")
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO por `get_stream` y `get_bank_stream` inexistentes.

- [ ] **Step 3: Añade la caché al gestor de bancos**

En `addons/opendou/runtime/soundbank_manager.gd`, añade el estado y el método:

```gdscript
## Streams ya reconstruidos, indexados por "banco/id".
##
## Reconstruir el AudioStreamWAV en cada peticion recomponeria los mismos bytes
## una y otra vez. La carga es perezosa: solo se materializa lo que se pide.
var _stream_cache: Dictionary = {}

## AudioStreamWAV de un stream de un banco cargado, reconstruyendolo la primera
## vez. Devuelve null si el banco no esta cargado o el stream no es reproducible.
func get_stream(bank_name: StringName, stream_id: int) -> AudioStreamWAV:
	var key: String = "%s/%d" % [String(bank_name), stream_id]
	if _stream_cache.has(key):
		return _stream_cache[key]
	var bank: SoundBank = get_bank(bank_name)
	if bank == null:
		return null
	var wav: AudioStreamWAV = bank.build_stream(stream_id)
	if wav != null:
		_stream_cache[key] = wav
	return wav
```

Y en `unload_bank()`, purga la caché de ese banco antes de cerrarlo:

```gdscript
func unload_bank(bank_name: StringName) -> void:
	if loaded_banks.has(bank_name):
		# Purgar la cache de ese banco: si no, get_stream() seguiria devolviendo
		# streams de un banco ya descargado.
		var prefix: String = "%s/" % String(bank_name)
		for key in _stream_cache.keys():
			if String(key).begins_with(prefix):
				_stream_cache.erase(key)
		var bank: SoundBank = loaded_banks[bank_name]
		bank.close()
		loaded_banks.erase(bank_name)
```

En `clear_all()`, añade `_stream_cache.clear()`.

- [ ] **Step 4: Expón la API en el manager de eventos**

En `addons/opendou/runtime/audio_event_manager.gd`, junto a `load_bank` y `unload_bank`:

```gdscript
## AudioStreamWAV de un stream de un banco cargado, listo para usar como
## base_stream de un AudioEventDef.
func get_bank_stream(bank_name: StringName, stream_id: int) -> AudioStreamWAV:
	if bank_manager == null:
		return null
	return bank_manager.get_stream(bank_name, stream_id)
```

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK, con `un evento cuyo stream viene de un banco suena` en verde. Si el pico sale 0, comprueba que `def.target_bus` es el bus de la sonda y que el evento no se está culleando por distancia: la voz es no espacial, así que no debería.

- [ ] **Step 6: Commit**

```bash
git add addons/opendou/runtime/soundbank_manager.gd addons/opendou/runtime/audio_event_manager.gd tests/test_bank_preload.gd tests/test_audio_output.gd
git commit -m "feat(soundbank): cache rebuilt streams and expose them to events

SoundBankManager cachea de forma perezosa los AudioStreamWAV reconstruidos, y
purga la cache del banco al descargarlo para no seguir devolviendo streams de un
banco cerrado. AudioEventManager expone get_bank_stream().

La asercion que cierra el pipeline: se compila un banco con un tono, se carga, su
stream se usa como base_stream de un evento, se postea y se mide el pico en el bus
de sonda. El pipeline ODBK produce audio."
```

---
## Task 4: Desaparecen el ring buffer y `BankStreamPlayback`

**Resuelve las observaciones 13 y 14, por eliminación.**

**Files:**
- **Delete:** `addons/opendou/runtime/audio_ring_buffer.gd` (+ `.uid`)
- **Delete:** `addons/opendou/runtime/bank_stream_playback.gd` (+ `.uid`)
- **Delete:** `tests/test_ringbuffer.gd` (+ `.uid`)
- Modify: `tests/test_all.gd`
- Modify: `scenes/demos/06_soundbank_streaming/demo_soundbank_streaming.gd`
- Modify: `README.md:25`
- Modify: `docs/tasks/roadmap.md:34-37`
- Modify: `tests/test_no_unfulfilled_claims.gd`

**Interfaces:**
- Consumes: `AudioEventManager.get_bank_stream()` de la Tarea 3, que es lo que sustituye al `mix()` de la demo 06.
- Desaparecen: `AudioRingBuffer` y `BankStreamPlayback` con toda su API.

La observación nº13 era un búfer circular copiando byte a byte en un bucle interpretado, y la nº14 era afirmar que ese búfer es "SPSC lock-free" cuando GDScript no tiene atómicos y nada corría en otro hilo. Las dos se resuelven porque **desaparece aquello de lo que hablaban**: su único consumidor era un `mix()` que no llegaba a ninguna salida de audio.

- [ ] **Step 1: Escribe la vigilancia de las afirmaciones**

Añade a `tests/test_no_unfulfilled_claims.gd`, dentro de `run_all()`, antes del `return a`:

```gdscript
	# El streaming asincrono desde disco se retiro: GDScript no puede sostenerlo.
	# Los bancos se precargan como AudioStreamWAV.
	var readme := FileAccess.open("res://README.md", FileAccess.READ)
	if readme != null:
		var rtext: String = readme.get_as_text().to_lower()
		readme.close()
		a.ok(not rtext.contains("asynchronous background disk streaming"),
			"el README no promete streaming asincrono desde disco")

	# Y las clases que lo implementaban no deben volver.
	for path in ["res://addons/opendou/runtime/audio_ring_buffer.gd",
			"res://addons/opendou/runtime/bank_stream_playback.gd"]:
		a.ok(not FileAccess.file_exists(path), "%s no existe" % path)
```

**Solo estas dos rutas.** `hdr_audio_manager.gd` lo elimina la Tarea 6, así que afirmarlo aquí dejaría la Tarea 4 en rojo hasta que la 6 estuviera hecha, y cada tarea tiene que acabar en verde por sí sola.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en las cuatro aserciones nuevas: el README aún lo promete y los tres archivos aún existen.

- [ ] **Step 3: Haz que la demo 06 use la precarga**

En `scenes/demos/06_soundbank_streaming/demo_soundbank_streaming.gd`:

Borra el preload y la variable:

```gdscript
const BankStreamPlaybackClass = preload("res://addons/opendou/runtime/bank_stream_playback.gd")
var playback: BankStreamPlayback
```

Sustituye la instanciación (líneas 60-63) por la precarga:

```gdscript
	# El banco se precarga como AudioStreamWAV en lugar de reproducirse por
	# streaming: GDScript no puede sostener un mezclador en el hilo de audio.
	preloaded_stream = bank.build_stream(1)
	is_stream_ready = (preloaded_stream != null)
```

Declara `var preloaded_stream: AudioStreamWAV = null` junto a las demás variables, y **borra el bloque que llamaba a `playback.mix(bytes_to_mix)`** (alrededor de la línea 93-96) junto con la variable `bytes_to_mix` si queda sin uso.

**Lee la función completa antes de editar.** Si la demo mostraba en pantalla los bytes mezclados, sustituye ese indicador por la longitud del stream precargado (`preloaded_stream.get_length()`); no inventes métricas que ya no existen. Esta escena se borra en la Fase 5, así que no inviertas más de lo que haga falta para que compile y siga siendo coherente.

- [ ] **Step 4: Elimina los archivos y su suite**

```bash
git rm addons/opendou/runtime/audio_ring_buffer.gd addons/opendou/runtime/audio_ring_buffer.gd.uid
git rm addons/opendou/runtime/bank_stream_playback.gd addons/opendou/runtime/bank_stream_playback.gd.uid
git rm tests/test_ringbuffer.gd tests/test_ringbuffer.gd.uid
```

En `tests/test_all.gd`, borra el `preload` de `TestRingBufferClass` y las tres líneas que ejecutaban su suite (`var r15 = TestRingBufferClass.run_all()`, el `total_tests += ...` y el `all_failures.append_array(...)`). **El total baja y es correcto**: esas aserciones cubrían código que ya no existe.

- [ ] **Step 5: Corrige las afirmaciones de la documentación**

En `README.md`, sustituye la línea 25:

```
   * Fixed-memory RAM prefetch buffers (64–128 KB) for instantaneous audio triggering paired with asynchronous background disk streaming.
```

por:

```
   * Monolithic `.bank` packaging with a contiguous RAM prefetch block, preloaded on demand as playable `AudioStreamWAV` resources (one file, deterministic packaging, per-stream lazy load).
```

En `docs/tasks/roadmap.md`, la Fase 3 se titula "Pipeline de SoundBanks, Prefetching y Streaming" y su tercera viñeta describe el búfer circular y el empalme prefetch-a-disco. Sustituye el título por "Pipeline de SoundBanks y Precarga" y esa viñeta por:

```
* [x] Precarga perezosa de cada stream del banco como `AudioStreamWAV` reproducible (`TASK-009`). El streaming asíncrono desde disco se retiró: exige un mezclador en el hilo de audio, y GDScript no puede sostenerlo.
```

- [ ] **Step 6: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK, con un total **menor** que antes de esta tarea. Comprueba que no quedan referencias:

```bash
grep -rn "AudioRingBuffer\|BankStreamPlayback\|audio_ring_buffer\|bank_stream_playback" addons/ tests/ scenes/
```

Expected: sin resultados.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "perf(soundbank): delete the byte-by-byte ring buffer and its dead playback

Resuelve las observaciones 13 y 14 por eliminacion, no por optimizacion.

La nº13 era un buffer circular copiando byte a byte en un bucle interpretado, y
la nº14 era afirmar que ese buffer es SPSC lock-free cuando GDScript no tiene
atomicos y nada corria en otro hilo. Su unico consumidor era un mix() que no
llegaba a ninguna salida de audio: se comprobo antes de disenar la fase.

Con la precarga a AudioStreamWAV ya en pie, ambos desaparecen. El README y el
roadmap dejan de prometer streaming asincrono desde disco, y un test vigila que
ni la promesa ni las clases vuelvan.

El numero de aserciones baja al borrar test_ringbuffer.gd, y es correcto: cubrian
codigo que ya no existe."
```

---

## Task 5: El inspector deja de leer disco en cada refresco

**Resuelve la observación 15.**

**Files:**
- Modify: `addons/opendou/runtime/synth/synth_preset_registry.gd`
- Modify: `addons/opendou/nodes/opendou_event_player.gd:29-46`
- Modify: `addons/opendou/nodes/opendou_event_player_2d.gd:29-46`
- Modify: `addons/opendou/nodes/opendou_event_player_3d.gd:29-46`
- Create: `tests/test_preset_hint_cache.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `SynthPresetRegistry.get_preset_hint_string() -> String` con caché, y `invalidate_hint_cache() -> void`.
- La caché se invalida **sola** desde `set_preset()`, `delete_preset()` y `load_presets()`.

Los tres emisores llaman `load()` desde `_get_property_list()`, y el inspector invoca ese método en cada refresco: una lectura de disco más una enumeración del registro cada vez.

**Mejora sobre lo que esbozó la spec.** La spec proponía una caché estática en cada nodo más un `refresh_preset_hints()` que alguien tuviera que acordarse de llamar. Es mejor poner la caché **en el registro**, que es quien sabe cuándo cambian los presets, e invalidarla desde sus propios mutadores. Así hay un solo punto de verdad y nadie tiene que acordarse de nada.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_preset_hint_cache.gd`:

```gdscript
class_name TestPresetHintCache
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const SynthPresetRegistryClass = preload("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
const OpenDouEventPlayer3DClass = preload("res://addons/opendou/nodes/opendou_event_player_3d.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("preset_hint_cache")

	var reg = SynthPresetRegistryClass.get_singleton()
	a.ok(reg != null, "el registro de presets existe")
	if reg == null:
		return a

	# El hint empieza por "None" y lista los presets.
	var hint: String = reg.get_preset_hint_string()
	a.ok(hint.begins_with("None"), "el hint empieza por None")

	# Dos llamadas devuelven exactamente lo mismo: la cache funciona.
	a.eq(reg.get_preset_hint_string(), hint, "dos llamadas devuelven el mismo hint")

	# Un preset nuevo APARECE sin que nadie invalide a mano: el registro se
	# invalida solo desde sus mutadores. Sin eso, la cache seria un defecto peor
	# que el que arregla.
	var probe_name := &"__ProbePresetParaCache__"
	reg.set_preset(probe_name, {"type": "Single_Generator", "generator_type": "Sine", "duration": 0.1})
	var hint_after: String = reg.get_preset_hint_string()
	a.ok(hint_after.contains(String(probe_name)), "un preset nuevo aparece en el hint")
	a.ok(hint_after != hint, "el hint cambio al anadir el preset")

	# Y desaparece al borrarlo.
	reg.delete_preset(probe_name)
	a.ok(not reg.get_preset_hint_string().contains(String(probe_name)),
		"el preset borrado desaparece del hint")

	# La propiedad synth_preset sigue existiendo en los tres emisores, con su
	# desplegable: la cache no puede romper la persistencia en escena.
	var emitter = OpenDouEventPlayer3DClass.new()
	var found := false
	for p in emitter.get_property_list():
		if String(p["name"]) == "synth_preset":
			found = true
			a.eq(int(p["hint"]), PROPERTY_HINT_ENUM, "synth_preset sigue siendo un desplegable")
			a.ok(String(p["hint_string"]).begins_with("None"), "el desplegable arranca en None")
			break
	a.ok(found, "synth_preset sigue expuesta en el inspector")
	emitter.free()

	return a
```

Registra la suite en `run_suite()` con su `preload`.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO con `SCRIPT ERROR` por `get_preset_hint_string` inexistente.

- [ ] **Step 3: Pon la caché en el registro**

En `addons/opendou/runtime/synth/synth_preset_registry.gd`, añade el estado junto a `presets`:

```gdscript
## Cache del hint_string del desplegable de presets del inspector.
##
## _get_property_list() de los emisores lo pedia en CADA refresco del inspector, y
## antes hacia un load() desde disco y enumeraba el registro entero cada vez.
##
## La cache vive aqui, y no en cada nodo, porque este es quien sabe cuando cambian
## los presets: se invalida desde los propios mutadores y nadie tiene que
## acordarse de llamar a nada.
var _hint_cache: String = ""
```

Y los dos métodos:

```gdscript
## hint_string del desplegable de presets: "None" seguido de los nombres.
func get_preset_hint_string() -> String:
	if not _hint_cache.is_empty():
		return _hint_cache
	var names: Array[String] = ["None"]
	for p_name in get_preset_names():
		names.append(str(p_name))
	_hint_cache = ",".join(names)
	return _hint_cache

## Invalida la cache del desplegable.
##
## La llaman los mutadores de este registro. Es publica por si alguien modifica el
## diccionario de presets por fuera.
func invalidate_hint_cache() -> void:
	_hint_cache = ""
```

Añade `invalidate_hint_cache()` como **primera línea** del cuerpo de `set_preset()`, `delete_preset()` y `load_presets()`. **Lee cada función antes de editar** y confirma que no hay otro mutador de `presets`; si lo hay, invalida ahí también.

- [ ] **Step 4: Los tres emisores usan la caché**

En `opendou_event_player.gd`, `opendou_event_player_2d.gd` y `opendou_event_player_3d.gd`, sustituye el cuerpo de `_get_property_list()`:

```gdscript
func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	var presets: Array[String] = ["None"]
	var reg = load("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
	if reg != null:
		var singleton = reg.get_singleton()
		if singleton != null:
			for p_name in singleton.get_preset_names():
				presets.append(str(p_name))
	var hint_str = ",".join(presets)
	properties.append({
		"name": "synth_preset",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_str,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	return properties
```

por:

```gdscript
func _get_property_list() -> Array[Dictionary]:
	# El inspector invoca este metodo en CADA refresco. Antes hacia aqui un
	# load() desde disco y enumeraba el registro de presets entero cada vez; el
	# hint viene ahora de una cache que el propio registro invalida al cambiar.
	var hint_str: String = "None"
	var singleton = SynthPresetRegistryClass.get_singleton()
	if singleton != null:
		hint_str = singleton.get_preset_hint_string()
	return [{
		"name": "synth_preset",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_str,
		"usage": PROPERTY_USAGE_DEFAULT
	}]
```

Y añade a la cabecera de cada uno, si no está:

```gdscript
const SynthPresetRegistryClass = preload("res://addons/opendou/runtime/synth/synth_preset_registry.gd")
```

El `const preload` sustituye al `load()` en runtime: se resuelve una vez al compilar el script, no en cada llamada.

- [ ] **Step 5: Comprueba que no queda ningún `load()` en esos métodos**

```bash
grep -n -A6 "func _get_property_list" addons/opendou/nodes/opendou_event_player*.gd | grep "load("
```

Expected: sin resultados.

- [ ] **Step 6: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Si `tests/test_synth_preset_registry.gd` falla, comprueba si afirmaba algo sobre el número de presets: el test nuevo añade y borra uno de sonda, y si otro test cuenta presets sin aislarse podría verse afectado por el orden de ejecución.

- [ ] **Step 7: Commit**

```bash
git add addons/opendou/runtime/synth/synth_preset_registry.gd addons/opendou/nodes/opendou_event_player.gd addons/opendou/nodes/opendou_event_player_2d.gd addons/opendou/nodes/opendou_event_player_3d.gd tests/test_preset_hint_cache.gd tests/test_all.gd
git commit -m "perf(nodes): cache the preset dropdown instead of reading disk per refresh

_get_property_list() hacia un load() desde disco y enumeraba el registro de
presets entero, y el inspector invoca ese metodo en CADA refresco.

La cache vive en el registro y no en cada nodo, porque el registro es quien sabe
cuando cambian los presets: se invalida desde set_preset(), delete_preset() y
load_presets(), asi que nadie tiene que acordarse de llamar a nada. Sin esa
invalidacion un preset nuevo no apareceria en el desplegable, que es un defecto
peor que el que se arregla, y el test lo comprueba explicitamente.

Resuelve la observacion 15."
```

---

## Task 6: HDR consolidado y cableado por voz

**Cierra la huérfana que la Fase 1 dejó diferida.**

**Files:**
- Modify: `addons/opendou/resources/audio_event_def.gd`
- Modify: `addons/opendou/runtime/audio_event_manager.gd`
- Modify: `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd`
- **Delete:** `addons/opendou/runtime/spatial/hdr_audio_manager.gd` (+ `.uid`)
- Modify: `scenes/demos/08_tactical_canyon/demo_tactical_canyon.gd`
- Modify: `tests/test_tactical_canyon_demo.gd`
- Create: `tests/test_hdr_voice_gain.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `AudioEventDef.hdr_loudness_db: float = 0.0` (export).
- Produces: `AudioEventManager.hdr_engine: AudioHDREngine` (creado en `_init()`), `hdr_enabled: bool = true`, y `_update_hdr(delta: float) -> void` (privado, invocado desde `_process`).
- Desaparece: `HDRAudioManager` y `SpatialAcousticsManager.hdr_manager`.
- Consumes: `AudioHDREngine.push_event_loudness()`, `update()`, `calculate_voice_gain_db()`, `get_window_bounds()`, ya existentes.

**Los dos detalles que hay que respetar.** `calculate_voice_gain_db()` devuelve el **nivel de salida absoluto**, no una ganancia que sumar: su cuerpo es `clampf(loudness - window_top, -80.0, 0.0)`, siempre ≤ 0, así que funciona como atenuación al sumarse. Y su entrada es la **sonoridad de diseño del evento**, no el nivel de mezcla: son magnitudes distintas y conflacionarlas daría un resultado sin sentido.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_hdr_voice_gain.gd`:

```gdscript
class_name TestHDRVoiceGain
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const AudioHDREngineClass = preload("res://addons/opendou/core/audio_hdr_engine.gd")
const AudioEventDefClass = preload("res://addons/opendou/resources/audio_event_def.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("hdr_voice_gain")

	# La sonoridad es una propiedad de DISENO del evento: cuanto suena esa cosa en
	# el mundo. Explosion +18, pisada -20. No es el nivel de mezcla.
	var def = AudioEventDefClass.new(&"Explosion")
	a.approx(def.hdr_loudness_db, 0.0, "la sonoridad por defecto es 0 dB", 0.001)

	var engine = AudioHDREngineClass.new()

	# Con todo a 0.0, la contribucion es EXACTAMENTE 0 dB. Es lo que hace seguro
	# activar HDR por defecto sin alterar ninguna mezcla existente.
	engine.push_event_loudness(0.0)
	engine.update(0.016)
	a.approx(engine.calculate_voice_gain_db(0.0), 0.0, "con sonoridad 0 la contribucion es nula", 0.01)

	# Con una explosion de +18 sonando, la ventana sube. Su suelo queda en
	# 18 - 40 = -22, asi que una voz de -50 cae por debajo y se atenua al minimo.
	var loud = AudioHDREngineClass.new()
	for _f in range(40):
		loud.push_event_loudness(18.0)
		loud.update(0.05)
	var bounds: Vector2 = loud.get_window_bounds()
	a.gt(bounds.x, 10.0, "la ventana sube con una voz fuerte")
	a.lt(loud.calculate_voice_gain_db(-50.0), -70.0, "una voz muy por debajo del suelo se atenua al minimo")

	# Y una voz en el techo de la ventana no se atenua.
	a.approx(loud.calculate_voice_gain_db(bounds.x), 0.0, "una voz en el techo no se atenua", 0.01)

	# La contribucion nunca es positiva: se suma como atenuacion.
	for loudness in [-80.0, -20.0, 0.0, 18.0, 40.0]:
		a.ok(loud.calculate_voice_gain_db(loudness) <= 0.001,
			"la contribucion con sonoridad %.0f no es positiva" % loudness)

	return a
```

Y la aserción de integración en `tests/test_audio_output.gd`, cableada con `a.absorb(await run_hdr_ducking_async(tree))`:

```gdscript
## HDR debe atenuar de verdad una voz debil cuando suena una fuerte, y no hacer
## nada cuando todas tienen la sonoridad por defecto.
static func run_hdr_ducking_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("hdr_ducking")

	var probe = OpenDouAudioProbeClass.new()
	probe.setup(2.0)
	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	var tone := AudioSynthesizerClass.create_tone(440.0, 4.0, 0.6, false)

	# Control: una voz debil sola, con HDR activo y sonoridad por defecto.
	var quiet_def = AudioEventDefClass.new(&"VozDebil", tone)
	quiet_def.target_bus = probe.bus_name()
	quiet_def.stream_length = float(tone.get_length())
	quiet_def.is_looping = true
	quiet_def.hdr_loudness_db = -50.0
	manager.register_event_definition(quiet_def)

	manager.post_event(&"VozDebil", null)
	probe.drain()
	var alone: float = await probe.measure_peak_over_frames(tree, 30)
	a.gt(alone, 0.001, "la voz debil suena cuando esta sola")

	# Ahora entra una voz fuerte, enrutada a Master y NO al bus de sonda.
	#
	# Ese enrutado es lo que hace valida la medida: la voz fuerte sube la ventana
	# HDR pero no aporta senal al bus que se mide, asi que el pico del bus sigue
	# siendo el de la voz debil y solo. Si las dos fueran al mismo bus, la senal de
	# la fuerte enmascararia la atenuacion de la debil y la asercion no probaria
	# nada.
	var loud_def = AudioEventDefClass.new(&"VozFuerte", tone)
	loud_def.target_bus = &"Master"
	loud_def.stream_length = float(tone.get_length())
	loud_def.is_looping = true
	loud_def.hdr_loudness_db = 18.0
	manager.register_event_definition(loud_def)
	manager.post_event(&"VozFuerte", null)

	# La ventana sube con el ataque del motor; se le dan frames para llegar.
	for _f in range(40):
		await tree.process_frame
	probe.drain()
	var with_loud: float = await probe.measure_peak_over_frames(tree, 30)
	a.lt(with_loud, alone * 0.5, "la voz debil se atenua cuando suena la fuerte")

	# Con HDR desactivado la contribucion desaparece.
	manager.hdr_enabled = false
	for _f in range(20):
		await tree.process_frame
	a.ok(not manager.hdr_enabled, "hdr_enabled se puede desactivar")

	manager.stop_all()
	probe.teardown()
	manager.free()
	return a
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO por `hdr_loudness_db` y `hdr_enabled` inexistentes.

- [ ] **Step 3: Añade la sonoridad de diseño al evento**

En `addons/opendou/resources/audio_event_def.gd`, junto a `base_volume_db`:

```gdscript
## Sonoridad de diseno del evento en dB HDR: cuanto suena esta cosa EN EL MUNDO,
## no en la mezcla. Explosion +18, disparo +6, pisada -20.
##
## Es la entrada del motor HDR, que la compara con la ventana de sonoridad activa
## para decidir cuanto se atenua esta voz. No confundir con base_volume_db, que es
## nivel de mezcla: son magnitudes distintas.
##
## El valor por defecto de 0.0 hace que la contribucion del HDR sea exactamente
## 0 dB, asi que activarlo no altera ninguna mezcla existente.
@export var hdr_loudness_db: float = 0.0
```

- [ ] **Step 4: Cablea el motor en el ciclo por frame**

En `addons/opendou/runtime/audio_event_manager.gd`, añade el preload, el estado y el método:

```gdscript
const AudioHDREngineClass = preload("res://addons/opendou/core/audio_hdr_engine.gd")
```

```gdscript
## Motor de ventana de sonoridad HDR.
##
## Estaba huerfano: solo lo usaba el mixer del editor. Existia ademas un segundo
## motor duplicado, HDRAudioManager, que solo accionaba una demo. Se consolido en
## este, que tiene ataque y liberacion separados, limites de ventana y senal de
## cambio.
var hdr_engine: AudioHDREngine = null

## Si el HDR contribuye a la mezcla.
##
## Va activado porque con la sonoridad por defecto de los eventos su contribucion
## es exactamente 0 dB: dejarlo apagado habria movido el huerfano del editor al
## runtime en lugar de arreglarlo.
var hdr_enabled: bool = true
```

En `_init()`: `hdr_engine = AudioHDREngineClass.new()`

Y el método:

```gdscript
## Alimenta la ventana HDR con la sonoridad de las voces activas y la avanza.
##
## Tiene que ocurrir ANTES de aplicar, porque la ganancia de cada voz depende de
## donde quede la ventana este frame.
func _update_hdr(delta: float) -> void:
	if hdr_engine == null or not hdr_enabled:
		return
	for instance in active_instances:
		if instance == null or instance.definition == null:
			continue
		hdr_engine.push_event_loudness(instance.definition.hdr_loudness_db)
	hdr_engine.update(delta)
```

En `_process()`, insértalo entre el paso de parámetros de instancia y la asignación de permiso:

```gdscript
	# 5b. Ventana HDR: se alimenta con la sonoridad de las voces activas y avanza
	# antes de aplicar, porque la ganancia de cada voz depende de donde quede.
	_update_hdr(delta)
```

Y en `_apply_voices()`, suma la contribución al volumen:

```gdscript
		var volume_db: float = instance.calculated_volume_db
		# calculate_voice_gain_db() devuelve el nivel de salida relativo a la
		# ventana, siempre <= 0, asi que funciona como atenuacion. Su entrada es la
		# sonoridad de DISENO del evento, no el nivel de mezcla.
		if hdr_enabled and hdr_engine != null and instance.definition != null:
			volume_db += hdr_engine.calculate_voice_gain_db(instance.definition.hdr_loudness_db)
		var cutoff: float = float(instance.calculated_properties.get(&"cutoff_hz", 20000.0))
		ch.apply(volume_db, instance.calculated_pitch_scale, cutoff, instance.emitter_position)
```

**Lee `_apply_voices()` antes de editar** y adapta la sustitución a su forma actual: la llamada a `ch.apply()` pasa hoy `instance.calculated_volume_db` directamente.

- [ ] **Step 5: Elimina el motor duplicado**

En `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd`, borra el preload de `HDRAudioManagerClass`, la variable `hdr_manager` y su creación en `_init()`.

```bash
git rm addons/opendou/runtime/spatial/hdr_audio_manager.gd addons/opendou/runtime/spatial/hdr_audio_manager.gd.uid
```

En `scenes/demos/08_tactical_canyon/demo_tactical_canyon.gd`, los cuatro usos de `spatial_acoustics.hdr_manager` pasan al motor consolidado. La demo tiene acceso al autoload, así que:

- `spatial_acoustics.hdr_manager.register_loudness_event(3.0)` → `OpenDou.hdr_engine.push_event_loudness(3.0)`
- `spatial_acoustics.hdr_manager.process_decay(delta)` → **se borra**: el manager ya avanza la ventana cada frame en `_update_hdr()`, y avanzarla dos veces la haría caer al doble de velocidad.
- `current_window_top_db` y `current_floor_db` → `OpenDou.hdr_engine.get_window_bounds()`, cuyo `.x` es el techo y `.y` el suelo.

En `tests/test_tactical_canyon_demo.gd`, adapta las dos lecturas de la ventana a `get_window_bounds()`. **Cambio mínimo**: la escena se borra en la Fase 5.

- [ ] **Step 5b: Añade el motor eliminado a la lista de vigilancia**

En `tests/test_no_unfulfilled_claims.gd`, añade `hdr_audio_manager.gd` a la lista de
rutas que no deben volver, junto a las dos que ya vigila la Tarea 4:

```gdscript
	for path in ["res://addons/opendou/runtime/audio_ring_buffer.gd",
			"res://addons/opendou/runtime/bank_stream_playback.gd",
			"res://addons/opendou/runtime/spatial/hdr_audio_manager.gd"]:
		a.ok(not FileAccess.file_exists(path), "%s no existe" % path)
```

- [ ] **Step 6: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Presta atención a los tests de audio existentes: si alguno baja su pico, comprueba que su `AudioEventDef` tiene `hdr_loudness_db = 0.0` (el valor por defecto), porque con eso la contribución debe ser nula. Si baja de todas formas, el cableado está sumando algo que no debe.

Comprueba también que `tests/test_hdr_snapshots.gd`, que ya cubría `AudioHDREngine`, sigue en verde: esta tarea no cambia el motor, solo lo conecta.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(mix): consolidate HDR into one engine wired per voice

Habia DOS implementaciones de HDR duplicadas: AudioHDREngine, que solo usaba el
mixer del editor, y HDRAudioManager, que solo accionaba la demo 08 y habria
quedado huerfana tras la Fase 5. Se consolida en la primera, que tiene ataque y
liberacion separados, limites de ventana y senal de cambio.

El cableado es POR VOZ, no por bus como esbozaba la spec de la Fase 1: la API
real del motor es por voz, y por voz es lo que HDR significa. Encaja en el paso
aplicar que la Fase 1 construyo. Se descarta el AudioEffectLimiter por YAGNI.

Dos detalles que habria sido facil hacer mal: calculate_voice_gain_db() devuelve
el nivel de salida absoluto y no una ganancia, aunque al ser siempre <= 0 funciona
como atenuacion al sumarse; y su entrada es la sonoridad de DISENO del evento y
no el nivel de mezcla. De ahi el campo nuevo hdr_loudness_db, cuyo valor por
defecto de 0.0 hace que la contribucion sea exactamente 0 dB y permite activar
HDR de serie sin alterar ninguna mezcla existente."
```

---

## Notas para quien ejecute el plan

**Orden.** La Tarea 1 va primera obligatoriamente: la Tarea 2 reconstruye streams de disco y no funcionaría con los offsets desplazados. Las tareas 2 y 3 son una cadena. La 4 depende de que la 3 esté hecha, porque la demo 06 necesita la precarga para sustituir al `mix()`. Las tareas 5 y 6 son independientes del bloque de bancos y entre sí.

**El total de aserciones baja en la Tarea 4** al borrar `test_ringbuffer.gd`, y sube en las demás. No intentes que cuadre con ningún número anterior.

**Si un test existente empieza a fallar**, comprueba qué afirmaba antes de tocar el código nuevo. En este proyecto ya han aparecido tres tests que comprobaban la forma y no la sustancia; el de `read_stream_chunk` es uno de ellos y lo arregla la Tarea 1.

**No inviertas en las demos** más allá de lo que exija el runner: la 06 y la 08 se borran en la Fase 5.

**Al terminar la fase**, ejecuta `./run_tests.sh` en limpio y confirma: `RESULTADO: OK`, sin `SCRIPT ERROR`, fugas no superiores al techo, y `git status --porcelain` vacío.
