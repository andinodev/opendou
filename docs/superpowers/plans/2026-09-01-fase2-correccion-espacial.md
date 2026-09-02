# Fase 2 — Corrección espacial: plan de implementación

> **Para trabajadores agénticos:** SUB-SKILL REQUERIDA: usa superpowers:subagent-driven-development (recomendado) o superpowers:executing-plans para implementar este plan tarea a tarea. Los pasos usan sintaxis de checkbox (`- [ ]`) para seguimiento.

**Goal:** Que la geometría sea correcta: que el spline no derive, que los transforms respeten rotación y escala, que el portal reaccione a lo que se le asigna, que el audio se decodifique sin producir basura, y que las salas suenen con reverb nativo real en lugar de convolución desconectada.

**Architecture:** Cuatro correcciones acotadas sobre código existente más un subsistema nuevo: un pool que agrupa salas por perfil acústico y les asigna buses de reverb nativos de Godot, creados una vez y compartidos. `Area3D` ya tiene el reverb por zona; lo que faltaba era crear los buses, mapear el RT60 y verificar que la asignación pegó.

**Tech Stack:** Godot 4.7.2, GDScript. Sin GDExtension. Sin dependencias externas.

**Spec:** `docs/superpowers/specs/2026-09-01-fase2-correccion-espacial-design.md`

## Global Constraints

- **Godot 4.7.2** exactamente. El binario está en `/Users/Daniel/Downloads/Godot.app/Contents/MacOS/Godot`.
- **Rama `main`.** Este proyecto trabaja en una sola rama, por indicación explícita del usuario. No crees ramas.
- **Ejecuta siempre `./run_tests.sh`**, nunca Godot a mano. Hace tres comprobaciones que la suite no hace: `SCRIPT ERROR`/`Parse Error` fatales, trinquete de fugas de ObjectDB y regeneración de la caché de clases.
- **Comentarios y docstrings en español**, identificadores en inglés, **indentación con tabuladores**. Como todo el proyecto.
- **`AudioServer.remove_bus(i)` desplaza los índices posteriores.** Los buses de reverb se crean una vez y **no se destruyen** durante la sesión.
- **`Area3D.reverb_bus_name` no falla con un bus inexistente: lo coacciona a `"Master"`.** Releer el valor tras asignarlo es obligatorio.
- **El formato de 8 bits de `AudioStreamWAV` es CON SIGNO.** El byte 128 vale −1.0, no silencio. Verificado midiendo el pico de un WAV con todos los bytes a 128: dio 1.0000.
- **Las funciones estáticas con `await` y tipo de retorno propio funcionan** entre scripts. Si una falla al compilar, la causa es la caché de clases, no la corrutina.
- **No cuentes frames fijos para afirmar silencio.** Usa `OpenDouAudioProbe.await_silence()`.
- **Prohibido tocar** lo que pertenece a fases posteriores: ring buffer, `_get_property_list()`, `AudioHDREngine`, empaquetado, rutas `res://`, doble registro de tipos, `class_name` globales, main screen, `.gitignore`, y las demos salvo lo que exija el runner.
- **Cada tarea acaba en commit** con el estilo del repo (`feat(scope):`, `fix(scope):`, `perf(scope):`).

## Notas de arranque

El baseline al empezar esta fase es `417/417 PASSED`, cero `SCRIPT ERROR`, fugas **593** (techo en `tests/leak_budget.txt`), árbol de git limpio. Si al empezar no es eso, para y averigua por qué antes de tocar nada.

Aviso sobre el conteo: los tests nuevos usan `OpenDouAssert`, que cuenta aserciones reales. El total subirá y eso es correcto.

Aviso sobre las demos: `demo_tactical_canyon.gd` y `test_tactical_canyon_demo.gd` usan `reverb_mode = 1` (el `CONVOLUTION_IR` que desaparece). Actualízalos al enum nuevo con el cambio mínimo; la demo se borra en la Fase 5, así que no inviertas en su cobertura.

Aviso sobre fugas: si el trinquete sube, **investiga antes de tocar el número**. En la Fase 1, cada subida delató fugas preexistentes: 399 objetos en total.

---

## File Structure

### Archivos nuevos

| Archivo | Responsabilidad |
|---|---|
| `addons/opendou/runtime/spatial/transform_utils.gd` | Transform mundial de un `Node3D` respetando rotación y escala, dentro y fuera del árbol, y AABB que envuelve una caja transformada. Sustituye al `_get_world_position_fallback()` duplicado en tres archivos. |
| `addons/opendou/runtime/wav_decoder.gd` | Decodifica `AudioStreamWAV` a muestras float mono normalizadas, respetando formato y estéreo. Rechaza con aviso lo que GDScript no puede decodificar. |
| `addons/opendou/runtime/spatial/reverb_bus_pool.gd` | Agrupa salas por RT60 en escalones y les asigna buses de reverb nativos, creados una vez y compartidos. |
| `addons/opendou/runtime/spatial/ir_rt60_analyzer.gd` | Deriva el RT60 de una respuesta al impulso por integración de Schroeder y extrapolación T20. |
| `tests/test_transform_utils.gd` | Rotación, escala, jerarquía fuera del árbol, AABB envolvente. |
| `tests/test_wav_decoder.gd` | Los cuatro formatos, mono y estéreo, y el rechazo con aviso. |
| `tests/test_spline_anchor.gd` | Que la curva no derive al moverse la cabeza de reproducción. |
| `tests/test_portal_diffraction.gd` | Propagación de `open_factor` y efecto de `portal_size`. |
| `tests/test_reverb_bus_pool.gd` | Compartición por escalón, techo de buses, efecto insertado. |
| `tests/test_ir_rt60.gd` | RT60 de un decaimiento exponencial conocido. |

### Archivos modificados

| Archivo | Cambio |
|---|---|
| `addons/opendou/nodes/opendou_spline_emitter_3d.gd` | Ancla la curva en `_ready()`; `reanchor()` público. |
| `addons/opendou/nodes/opendou_room_3d.gd` | Usa el helper de transforms, AABB envolvente, bus de reverb nativo con verificación, `ReverbMode` a dos valores, RT60 desde IR. |
| `addons/opendou/nodes/opendou_portal_3d.gd` | `open_factor` con setter, `portal_size` en la difracción, helper de transforms. |
| `addons/opendou/nodes/opendou_multi_position_emitter_3d.gd` | Helper de transforms. |
| `addons/opendou/nodes/opendou_granular_emitter_3d.gd` | Usa el decodificador WAV en sus dos sitios. |
| `addons/opendou/runtime/spatial/audio_room.gd` | Retira los campos de convolución; `reverb_mode` documenta los dos valores nuevos. |
| `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd` | Expone el pool de buses de reverb. |
| `tests/test_room_convolution.gd` | Se reorienta al enum nuevo y al RT60 desde IR. |
| `scenes/demos/08_tactical_canyon/demo_tactical_canyon.gd`, `tests/test_tactical_canyon_demo.gd` | Cambio mínimo al enum nuevo. |
| **Eliminado:** `addons/opendou/core/dsp/convolution_reverb_node.gd` | Sus 512 taps en GDScript quedan sin consumidor. |

---

## Task 1: Helper de transforms compartido

**Resuelve la primera mitad de la observación 9.**

**Files:**
- Create: `addons/opendou/runtime/spatial/transform_utils.gd`
- Create: `tests/test_transform_utils.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouTransformUtils.world_transform_of(node: Node3D) -> Transform3D`, `world_position_of(node: Node3D) -> Vector3`, `enclosing_aabb(xform: Transform3D, box_size: Vector3) -> AABB`. Las tres son `static`.
- Consumes: `OpenDouAssert` de la Fase 1.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_transform_utils.gd`:

```gdscript
class_name TestTransformUtils
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const TransformUtilsClass = preload("res://addons/opendou/runtime/spatial/transform_utils.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("transform_utils")

	# Fuera del arbol, un hijo bajo un padre ROTADO 90 grados en Y.
	# Sumar posiciones daria (1,0,0)+(5,0,0) = (6,0,0); lo correcto es que la
	# rotacion del padre gire el offset del hijo hasta (5,0,-1).
	var parent := Node3D.new()
	parent.position = Vector3(5.0, 0.0, 0.0)
	parent.rotation = Vector3(0.0, PI * 0.5, 0.0)
	var child := Node3D.new()
	child.position = Vector3(1.0, 0.0, 0.0)
	parent.add_child(child)

	var pos: Vector3 = TransformUtilsClass.world_position_of(child)
	a.approx(pos.x, 5.0, "la rotacion del padre no desplaza X", 0.001)
	a.approx(pos.z, -1.0, "la rotacion del padre gira el offset a Z", 0.001)

	# Escala del padre: un offset de 1 bajo escala 3 son 3 unidades.
	var scaler := Node3D.new()
	scaler.scale = Vector3(3.0, 3.0, 3.0)
	var kid := Node3D.new()
	kid.position = Vector3(2.0, 0.0, 0.0)
	scaler.add_child(kid)
	a.approx(TransformUtilsClass.world_position_of(kid).x, 6.0, "la escala del padre multiplica el offset", 0.001)

	# Un nodo sin padre devuelve su propia posicion.
	var lonely := Node3D.new()
	lonely.position = Vector3(7.0, 8.0, 9.0)
	a.approx(TransformUtilsClass.world_position_of(lonely).y, 8.0, "sin padre devuelve su propia posicion", 0.001)

	# null no revienta.
	a.eq(TransformUtilsClass.world_position_of(null), Vector3.ZERO, "null devuelve el origen")

	# AABB envolvente de una caja unitaria rotada 45 grados en Y: su extension
	# en X y Z pasa de 1 a sqrt(2), porque un AABB no puede representar una caja
	# rotada y tiene que envolverla.
	var rot := Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3.ZERO)
	var box := TransformUtilsClass.enclosing_aabb(rot, Vector3.ONE)
	a.approx(box.size.x, sqrt(2.0), "el AABB envuelve la caja rotada en X", 0.01)
	a.approx(box.size.z, sqrt(2.0), "el AABB envuelve la caja rotada en Z", 0.01)
	a.approx(box.size.y, 1.0, "el eje sin rotar no crece", 0.01)
	a.approx(box.get_center().length(), 0.0, "el AABB queda centrado en el origen", 0.01)

	# Con traslacion, el AABB se mueve con ella.
	var moved := Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	a.approx(TransformUtilsClass.enclosing_aabb(moved, Vector3.ONE).get_center().x, 10.0,
		"el AABB sigue la traslacion", 0.001)

	kid.free(); scaler.free()
	child.free(); parent.free()
	lonely.free()
	return a
```

Registra la suite en `run_suite()` de `tests/test_all.gd`, junto a las demás suites nuevas:

```gdscript
	var xform_res = TestTransformUtilsClass.run_all()
	total_tests += xform_res.assertions_run
	all_failures.append_array(xform_res.failures)
```

Y el `preload` correspondiente en la cabecera:

```gdscript
const TestTransformUtilsClass = preload("res://tests/test_transform_utils.gd")
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO con `Parse Error: Preload file ... transform_utils.gd does not exist`. El runner lo marca como fatal.

- [ ] **Step 3: Implementa el helper**

Crea `addons/opendou/runtime/spatial/transform_utils.gd`:

```gdscript
class_name OpenDouTransformUtils
extends RefCounted

## Utilidades de transform para los nodos espaciales de OpenDou.
##
## Existe porque `_get_world_position_fallback()` estaba duplicado en tres
## archivos (room, portal y multi-position) y en los tres sumaba los `position`
## de los nodos padres ignorando rotacion y escala: un nodo bajo un padre rotado
## 90 grados reportaba una posicion mundial equivocada, y con ella limites
## acusticos equivocados.

## Transform mundial de un Node3D, tambien cuando esta fuera del arbol.
##
## Dentro del arbol delega en global_transform. Fuera, compone los transform de
## la jerarquia de verdad en lugar de sumar posiciones.
static func world_transform_of(node: Node3D) -> Transform3D:
	if node == null:
		return Transform3D()
	if node.is_inside_tree():
		return node.global_transform
	var xform: Transform3D = node.transform
	var cur: Node = node.get_parent()
	while cur != null and cur is Node3D:
		xform = (cur as Node3D).transform * xform
		cur = cur.get_parent()
	return xform

## Posicion mundial de un Node3D, tambien fuera del arbol.
static func world_position_of(node: Node3D) -> Vector3:
	return world_transform_of(node).origin

## AABB que envuelve las ocho esquinas de una caja local tras aplicarle un
## transform.
##
## Un AABB no puede representar exactamente una caja rotada, asi que el resultado
## es conservador: mas grande que la caja real. Es la unica opcion mientras
## AudioRoom guarde un AABB y no un Transform3D.
static func enclosing_aabb(xform: Transform3D, box_size: Vector3) -> AABB:
	var half: Vector3 = box_size * 0.5
	var result := AABB()
	var first := true
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var corner: Vector3 = xform * Vector3(half.x * sx, half.y * sy, half.z * sz)
				if first:
					result = AABB(corner, Vector3.ZERO)
					first = false
				else:
					result = result.expand(corner)
	return result
```

- [ ] **Step 4: Sustituye las tres copias del helper roto**

En `addons/opendou/nodes/opendou_room_3d.gd`, `opendou_portal_3d.gd` y `opendou_multi_position_emitter_3d.gd`:

1. Añade el preload a la cabecera:

```gdscript
const TransformUtilsClass = preload("res://addons/opendou/runtime/spatial/transform_utils.gd")
```

2. Borra la función `_get_world_position_fallback()` completa de cada archivo.

3. Sustituye cada uso. El patrón que aparece es
   `global_position if is_inside_tree() else _get_world_position_fallback()`,
   y pasa a ser simplemente:

```gdscript
	TransformUtilsClass.world_position_of(self)
```

`world_position_of()` ya distingue dentro y fuera del árbol, así que el
condicional desaparece. **Lee cada archivo antes de editar** y confirma cuántos
usos hay: en el momento de escribir este plan son 2 en `room_3d`, 1 en
`portal_3d` y 5 en `multi_position_emitter_3d`.

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Si algún test de `multi_position_emitter` falla, compara qué
posición esperaba: es posible que afirmara el resultado del helper roto.

- [ ] **Step 6: Verifica que no quedan copias**

```bash
grep -rn "_get_world_position_fallback" addons/ tests/ scenes/
```

Expected: sin resultados.

- [ ] **Step 7: Commit**

```bash
git add addons/opendou/runtime/spatial/transform_utils.gd tests/test_transform_utils.gd tests/test_all.gd addons/opendou/nodes/opendou_room_3d.gd addons/opendou/nodes/opendou_portal_3d.gd addons/opendou/nodes/opendou_multi_position_emitter_3d.gd
git commit -m "fix(spatial): compose transforms instead of summing positions

_get_world_position_fallback() estaba duplicado en tres archivos y en los tres
sumaba los position de los padres ignorando rotacion y escala: un nodo bajo un
padre rotado 90 grados reportaba una posicion mundial equivocada.

Pasa a haber un unico helper que compone Transform3D de verdad, y que ademas
sabe envolver una caja transformada en un AABB."
```

---

## Task 2: El AABB de la sala envuelve la caja rotada

**Resuelve la segunda mitad de la observación 9.**

**Files:**
- Modify: `addons/opendou/nodes/opendou_room_3d.gd`
- Modify: `tests/test_transform_utils.gd`

**Interfaces:**
- Consumes: `OpenDouTransformUtils.world_transform_of()` y `enclosing_aabb()` de la Tarea 1.
- `OpenDouRoom3D.register_in_manager()` conserva su firma.

`Room3D` construye hoy su AABB como `AABB(center - _dimensions * 0.5, _dimensions)`, que es correcto solo si la sala no está rotada ni escalada.

- [ ] **Step 1: Escribe el test que falla**

Añade al final de `run_all()` de `tests/test_transform_utils.gd`, antes de los `free()`:

```gdscript
	# Una sala rotada 45 grados debe reportar un AABB que la envuelva. Con el
	# calculo axis-aligned anterior, una sala de 10x4x10 rotada seguia diciendo
	# que medía 10 en X, cuando su envolvente real es 10*sqrt(2).
	var RoomClass = load("res://addons/opendou/nodes/opendou_room_3d.gd")
	var room = RoomClass.new()
	room.room_name = &"SalaRotada"
	room.rotation = Vector3(0.0, PI * 0.25, 0.0)
	var shape := CollisionShape3D.new()
	var rbox := BoxShape3D.new()
	rbox.size = Vector3(10.0, 4.0, 10.0)
	shape.shape = rbox
	room.add_child(shape)

	var runtime = room.register_in_manager()
	a.ok(runtime != null, "la sala rotada se registra")
	if runtime != null and runtime.has_bounds:
		a.gt(runtime.bounds.size.x, 10.5, "el AABB de la sala rotada envuelve mas de 10 en X")
		a.approx(runtime.bounds.size.y, 4.0, "el eje sin rotar mantiene su tamano", 0.1)
	else:
		a.ok(false, "la sala rotada no publico limites")
	room.free()
```

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `el AABB de la sala rotada envuelve mas de 10 en X`, reportando 10.0: el cálculo axis-aligned ignora la rotación.

- [ ] **Step 3: Corrige el cálculo del AABB**

En `addons/opendou/nodes/opendou_room_3d.gd`, dentro de `register_in_manager()`, sustituye:

```gdscript
	if _dimensions != Vector3.ZERO:
		var center_pos: Vector3 = TransformUtilsClass.world_position_of(self)
		runtime_room.set_bounds(AABB(center_pos - _dimensions * 0.5, _dimensions))
```

por:

```gdscript
	if _dimensions != Vector3.ZERO:
		# El AABB envuelve las ocho esquinas transformadas, asi que respeta
		# rotacion y escala. Antes se construia como centro +- tamano/2, que solo
		# es correcto si la sala no esta rotada ni escalada.
		runtime_room.set_bounds(
			TransformUtilsClass.enclosing_aabb(TransformUtilsClass.world_transform_of(self), _dimensions)
		)
```

Y en `calculate_sabine_reverb()` haz la misma sustitución, donde hoy pone
`runtime_room.set_bounds(AABB(center_pos - _dimensions * 0.5, _dimensions))`.
**Lee el archivo antes de editar** para confirmar los dos sitios.

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK, con el AABB de la sala rotada por encima de 10.5 en X (el valor teórico es 10·√2 ≈ 14.14).

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/nodes/opendou_room_3d.gd tests/test_transform_utils.gd
git commit -m "fix(spatial): room AABB encloses the rotated and scaled box

Los limites se construian como centro +- tamano/2, correcto solo para una sala
sin rotar ni escalar: una sala de 10x4x10 rotada 45 grados seguia diciendo que
medía 10 en X cuando su envolvente real es 14.14.

Un AABB no puede representar exactamente una caja rotada, asi que el resultado
es conservador. Hacerlo exacto exigiria que AudioRoom guardara un Transform3D, y
eso cambia su interfaz: queda fuera de esta fase."
```

---

## Task 3: Decodificador WAV compartido

**Resuelve la observación 11.**

**Files:**
- Create: `addons/opendou/runtime/wav_decoder.gd`
- Create: `tests/test_wav_decoder.gd`
- Modify: `addons/opendou/nodes/opendou_granular_emitter_3d.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouWavDecoder.to_mono_floats(wav: AudioStreamWAV) -> PackedFloat32Array` (static). Devuelve muestras en `[-1, 1]`; array vacío si el formato no se puede decodificar.
- Consumes: `OpenDouAssert`.

**El dato que hace o rompe esta tarea:** el formato de 8 bits de `AudioStreamWAV` es **con signo**. Verificado midiendo el pico de un WAV con todos los bytes a 128: dio **1.0000**, o sea −1.0 de amplitud plena, no silencio. Tratarlo como sin signo mete un offset de DC del 100 %.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_wav_decoder.gd`:

```gdscript
class_name TestWavDecoder
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")

static func _make_wav(fmt: int, stereo: bool, bytes: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = fmt
	w.stereo = stereo
	w.mix_rate = 44100
	w.data = bytes
	return w

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("wav_decoder")

	# 16 bits mono, little-endian con signo. 0x7FFF ~ +1.0, 0x8000 = -1.0.
	var b16 := PackedByteArray([0x00, 0x00, 0xFF, 0x7F, 0x00, 0x80])
	var s16 := WavDecoderClass.to_mono_floats(_make_wav(AudioStreamWAV.FORMAT_16_BITS, false, b16))
	a.eq(s16.size(), 3, "16 bits mono: tres muestras")
	a.approx(s16[0], 0.0, "16 bits: 0x0000 es silencio", 0.001)
	a.approx(s16[1], 1.0, "16 bits: 0x7FFF es +1.0", 0.001)
	a.approx(s16[2], -1.0, "16 bits: 0x8000 es -1.0", 0.001)

	# 8 bits mono CON SIGNO: el byte 128 vale -1.0, no silencio. Verificado
	# empiricamente midiendo el pico de un WAV con todos los bytes a 128.
	var b8 := PackedByteArray([0, 127, 128])
	var s8 := WavDecoderClass.to_mono_floats(_make_wav(AudioStreamWAV.FORMAT_8_BITS, false, b8))
	a.eq(s8.size(), 3, "8 bits mono: tres muestras")
	a.approx(s8[0], 0.0, "8 bits: 0 es silencio", 0.001)
	a.approx(s8[1], 127.0 / 128.0, "8 bits: 127 es casi +1.0", 0.001)
	a.approx(s8[2], -1.0, "8 bits: 128 es -1.0 porque el formato es con signo", 0.001)

	# 16 bits estereo: los canales se promedian a mono. L=+1.0, R=-1.0 -> 0.0.
	var b16s := PackedByteArray([0xFF, 0x7F, 0x00, 0x80, 0xFF, 0x7F, 0xFF, 0x7F])
	var s16s := WavDecoderClass.to_mono_floats(_make_wav(AudioStreamWAV.FORMAT_16_BITS, true, b16s))
	a.eq(s16s.size(), 2, "16 bits estereo: dos frames")
	a.approx(s16s[0], 0.0, "estereo: +1.0 y -1.0 promedian a 0", 0.001)
	a.approx(s16s[1], 1.0, "estereo: +1.0 en ambos canales da +1.0", 0.001)

	# 8 bits estereo.
	var b8s := PackedByteArray([127, 128, 0, 0])
	var s8s := WavDecoderClass.to_mono_floats(_make_wav(AudioStreamWAV.FORMAT_8_BITS, true, b8s))
	a.eq(s8s.size(), 2, "8 bits estereo: dos frames")
	a.lt(absf(s8s[0]), 0.01, "8 bits estereo: 127 y 128 casi se cancelan")

	# Formatos que GDScript no puede decodificar: vacio, no basura.
	for fmt in [AudioStreamWAV.FORMAT_IMA_ADPCM, AudioStreamWAV.FORMAT_QOA]:
		var comp := WavDecoderClass.to_mono_floats(_make_wav(fmt, false, PackedByteArray([1, 2, 3, 4])))
		a.eq(comp.size(), 0, "formato comprimido %d devuelve vacio" % fmt)

	# Entradas degeneradas.
	a.eq(WavDecoderClass.to_mono_floats(null).size(), 0, "null devuelve vacio")
	a.eq(WavDecoderClass.to_mono_floats(_make_wav(AudioStreamWAV.FORMAT_16_BITS, false, PackedByteArray())).size(),
		0, "datos vacios devuelven vacio")

	return a
```

Registra la suite en `run_suite()` de `tests/test_all.gd` con su `preload`, igual que en la Tarea 1.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO con `Parse Error: Preload file ... wav_decoder.gd does not exist`.

- [ ] **Step 3: Implementa el decodificador**

Crea `addons/opendou/runtime/wav_decoder.gd`:

```gdscript
class_name OpenDouWavDecoder
extends RefCounted

## Decodifica un AudioStreamWAV a muestras float mono normalizadas en [-1, 1].
##
## Existe porque tres sitios del proyecto decodificaban a mano asumiendo 16 bits
## mono, y el formato POR DEFECTO de AudioStreamWAV es de 8 bits: con un WAV
## estereo, de 8 bits, IMA-ADPCM o QOA se leia basura.
##
## El formato de 8 bits de Godot es CON SIGNO. Verificado midiendo el pico de un
## WAV con todos los bytes a 128: da 1.0, o sea -1.0 de amplitud plena, no
## silencio. Tratarlo como sin signo mete un offset de DC del 100 %.

## Decodifica a mono en [-1, 1]. Devuelve un array vacio si el formato no se
## puede decodificar desde GDScript, avisando de cual era.
static func to_mono_floats(wav: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if wav == null:
		return out
	var data: PackedByteArray = wav.data
	if data.is_empty():
		return out

	match wav.format:
		AudioStreamWAV.FORMAT_8_BITS:
			return _decode_8_bits(data, wav.stereo)
		AudioStreamWAV.FORMAT_16_BITS:
			return _decode_16_bits(data, wav.stereo)
		AudioStreamWAV.FORMAT_IMA_ADPCM:
			push_warning("[OpenDou] AudioStreamWAV en IMA-ADPCM: GDScript no puede decodificarlo. Reimporta el WAV sin compresion si necesitas sus muestras.")
			return out
		AudioStreamWAV.FORMAT_QOA:
			push_warning("[OpenDou] AudioStreamWAV en QOA: GDScript no puede decodificarlo. Reimporta el WAV sin compresion si necesitas sus muestras.")
			return out
		_:
			push_warning("[OpenDou] formato de AudioStreamWAV no reconocido: %d" % wav.format)
			return out

static func _decode_8_bits(data: PackedByteArray, stereo: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var step: int = 2 if stereo else 1
	var frames: int = data.size() / step
	out.resize(frames)
	for i in range(frames):
		var base: int = i * step
		var value: float = _signed_8(data[base])
		if stereo:
			value = (value + _signed_8(data[base + 1])) * 0.5
		out[i] = value
	return out

static func _decode_16_bits(data: PackedByteArray, stereo: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var bytes_per_frame: int = 4 if stereo else 2
	var frames: int = data.size() / bytes_per_frame
	out.resize(frames)
	for i in range(frames):
		var base: int = i * bytes_per_frame
		var value: float = _signed_16(data[base], data[base + 1])
		if stereo:
			value = (value + _signed_16(data[base + 2], data[base + 3])) * 0.5
		out[i] = value
	return out

## Un byte de 8 bits con signo, normalizado a [-1, 1].
static func _signed_8(b: int) -> float:
	var v: int = b - 256 if b >= 128 else b
	return float(v) / 128.0

## Dos bytes little-endian de 16 bits con signo, normalizados a [-1, 1].
static func _signed_16(lo: int, hi: int) -> float:
	var v: int = lo | (hi << 8)
	if v >= 32768:
		v -= 65536
	return float(v) / 32768.0
```

- [ ] **Step 4: Sustituye los bucles a mano del emisor granular**

En `addons/opendou/nodes/opendou_granular_emitter_3d.gd`, añade el preload:

```gdscript
const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")
```

En `_rebuild_synthesizer()` hay **dos** bloques de decodificación a mano (uno para
`source_stream` y otro para el WAV de relleno que devuelve `ModularSynthEngine`).
Sustituye cada bloque completo por una sola línea:

```gdscript
		samples = WavDecoderClass.to_mono_floats(source_stream)
```

y respectivamente:

```gdscript
			samples = WavDecoderClass.to_mono_floats(synth_wav)
```

Borra las variables `raw_data`, `b0`, `b1` y `val16` que quedan sin uso. **Lee la
función completa antes de editar** para no dejar restos.

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. `tests/test_granular_emitter_3d.gd` debe seguir en verde: el
emisor produce las mismas muestras para el caso de 16 bits mono que ya usaba.

- [ ] **Step 6: Verifica que no quedan decodificaciones a mano**

```bash
grep -rn "val16\|>> 8) & 0xFF" addons/
```

Expected: solo dentro de `wav_decoder.gd` y de `audio_synthesizer.gd` (que
**codifica**, no decodifica, y no entra en esta tarea).

- [ ] **Step 7: Commit**

```bash
git add addons/opendou/runtime/wav_decoder.gd tests/test_wav_decoder.gd tests/test_all.gd addons/opendou/nodes/opendou_granular_emitter_3d.gd
git commit -m "fix(dsp): decode WAV honoring format and channel count

Tres sitios decodificaban a mano asumiendo 16 bits mono, y el formato por
defecto de AudioStreamWAV es de 8 bits: con un WAV estereo, de 8 bits,
IMA-ADPCM o QOA se leia basura.

El formato de 8 bits de Godot es CON SIGNO, verificado midiendo el pico de un
WAV con todos los bytes a 128: da 1.0, no silencio. Tratarlo como sin signo
metia un offset de DC del 100 %.

IMA-ADPCM y QOA devuelven vacio con un aviso que nombra el formato: no hay
decodificador en GDScript y fingir que si es peor que decir que no."
```

---

## Task 4: El spline emitter deja de derivar

**Resuelve la observación 7.**

**Files:**
- Modify: `addons/opendou/nodes/opendou_spline_emitter_3d.gd`
- Create: `tests/test_spline_anchor.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouSplineEmitter3D.reanchor() -> void`, `get_curve_anchor() -> Transform3D`. `get_closest_virtual_point(listener_pos)` y `update_spline_acoustics(...)` conservan sus firmas.
- Consumes: nada de tareas anteriores.

**La causa.** `get_closest_virtual_point()` hace `to_local(listener_pos)`, o sea que
interpreta la curva en el espacio local **vivo** del nodo. Y
`update_spline_acoustics()` mueve `global_position` del propio nodo. Al moverse el
nodo, la curva se mueve con él: bucle de realimentación, y el río entero migra hacia
el jugador.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_spline_anchor.gd`:

```gdscript
class_name TestSplineAnchor
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const SplineEmitterClass = preload("res://addons/opendou/nodes/opendou_spline_emitter_3d.gd")

static func run_all_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("spline_anchor")

	var emitter = SplineEmitterClass.new()
	var curve := Curve3D.new()
	# Una recta de 40 m sobre el eje X, como un rio.
	curve.add_point(Vector3(-20.0, 0.0, 0.0))
	curve.add_point(Vector3(20.0, 0.0, 0.0))
	emitter.curve = curve
	emitter.max_virtual_distance = 100.0
	tree.root.add_child(emitter)
	await tree.process_frame

	# El oyente esta a 10 m de la recta, frente a su punto medio.
	var listener := Vector3(0.0, 0.0, 10.0)
	var first: Vector3 = emitter.get_closest_virtual_point(listener)
	a.approx(first.z, 0.0, "el punto mas cercano esta sobre la curva, no en el oyente", 0.01)

	# Se simulan 60 frames de acustica. El nodo se movera como cabeza de
	# reproduccion, pero la CURVA debe quedarse donde se autoro.
	for _f in range(60):
		emitter.update_spline_acoustics(listener, Vector3.ZERO, 0.016)
		await tree.process_frame

	var after: Vector3 = emitter.get_closest_virtual_point(listener)
	a.lt(absf(after.z - first.z), 0.5, "la curva no deriva hacia el oyente")
	a.lt(absf(after.x - first.x), 0.5, "la curva no se desplaza en X")

	# Con el oyente en otro sitio, el punto mas cercano cambia como debe: el
	# emisor sigue reaccionando, lo que no hace es arrastrar la geometria.
	var moved_listener := Vector3(15.0, 0.0, 10.0)
	var at_moved: Vector3 = emitter.get_closest_virtual_point(moved_listener)
	a.gt(at_moved.x, first.x + 5.0, "el punto mas cercano sigue al oyente a lo largo de la curva")

	# reanchor() reubica el marco a proposito, para un rio sobre un vehiculo.
	emitter.global_position = Vector3(0.0, 0.0, 100.0)
	emitter.reanchor()
	var anchored: Vector3 = emitter.get_closest_virtual_point(Vector3(0.0, 0.0, 110.0))
	a.gt(anchored.z, 90.0, "tras reanchor la curva vive en el sitio nuevo")

	tree.root.remove_child(emitter)
	emitter.free()
	return a
```

Cablea la suite en `run_async_suite()` de `tests/test_all.gd`:

```gdscript
	acc.absorb(await TestSplineAnchorClass.run_all_async(tree))
```

con su `preload` en la cabecera.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO en `la curva no deriva hacia el oyente`. La derivación es real y
acumulativa: 60 frames de `lerp` con factor `delta * 20` acercan el nodo casi por
completo, y con él la curva.

- [ ] **Step 3: Ancla el marco de la curva**

En `addons/opendou/nodes/opendou_spline_emitter_3d.gd`, añade el estado del ancla
junto a las demás variables de runtime:

```gdscript
## Transform que define el espacio en el que vive la curva.
##
## Se captura en _ready() y NO sigue al nodo. El nodo se mueve como cabeza de
## reproduccion virtual, y si la curva se interpretara en su espacio vivo se
## moveria con el: bucle de realimentacion, y la curva entera derivando hacia el
## oyente frame a frame.
var _curve_anchor: Transform3D = Transform3D()
var _anchor_captured: bool = false
```

En `_ready()`, captura el ancla **antes** de tocar posiciones:

```gdscript
func _ready() -> void:
	reanchor()
	_virtual_target_pos = global_position
	_prev_emitter_pos = global_position
```

Añade los dos métodos públicos:

```gdscript
## Fija el espacio de la curva a la posicion actual del nodo.
##
## Llamalo cuando reubiques el emisor a proposito, por ejemplo un rio o una
## cinta transportadora montados sobre un vehiculo en marcha.
func reanchor() -> void:
	_curve_anchor = global_transform if is_inside_tree() else transform
	_anchor_captured = true

## Transform que define el espacio en el que vive la curva.
func get_curve_anchor() -> Transform3D:
	if not _anchor_captured:
		return global_transform if is_inside_tree() else transform
	return _curve_anchor
```

Y sustituye `get_closest_virtual_point()` para que use el ancla en lugar del
transform vivo:

```gdscript
## Calcula la coordenada mundial mas cercana sobre el spline para un oyente dado.
func get_closest_virtual_point(listener_pos: Vector3) -> Vector3:
	if curve == null or curve.point_count < 2:
		return global_position if is_inside_tree() else position
	var anchor: Transform3D = get_curve_anchor()
	# El oyente se lleva al espacio del ANCLA, no al del nodo: el nodo se mueve
	# cada frame como cabeza de reproduccion y usar su transform vivo arrastraria
	# la curva con el.
	var local_listener: Vector3 = anchor.affine_inverse() * listener_pos
	var closest_local: Vector3 = curve.get_closest_point(local_listener)
	return anchor * closest_local
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Las cinco aserciones del test en verde, incluida la de que el punto
más cercano **sigue** reaccionando al oyente: el emisor no queda congelado, lo que
deja de hacer es arrastrar la geometría.

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/nodes/opendou_spline_emitter_3d.gd tests/test_spline_anchor.gd tests/test_all.gd
git commit -m "fix(spatial): anchor the spline curve so it stops drifting

get_closest_virtual_point() interpretaba la curva en el espacio local VIVO del
nodo, y update_spline_acoustics() mueve el global_position de ese mismo nodo cada
frame. El resultado era un bucle de realimentacion: la curva se movia con el nodo
y el rio entero migraba hacia el jugador.

El marco de la curva y la cabeza de reproduccion pasan a ser cosas distintas. El
nodo captura su transform en _ready() como ancla y calcula el punto mas cercano
contra ella, asi que puede seguir moviendose sin arrastrar la geometria.
reanchor() cubre el caso de reubicar el emisor a proposito."
```

---
## Task 5: El portal reacciona a lo que se le asigna

**Resuelve la observación 10.**

**Files:**
- Modify: `addons/opendou/nodes/opendou_portal_3d.gd`
- Create: `tests/test_portal_diffraction.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouPortal3D.open_factor` como export con setter que sincroniza con `runtime_portal`. `get_diffraction_lpf() -> float` pasa a considerar `portal_size`. `set_open_factor()` se conserva por compatibilidad y delega en el setter.
- Constantes nuevas: `MIN_DIFFRACTION_LPF_HZ := 300.0`, `MAX_DIFFRACTION_LPF_HZ := 20000.0`, `REFERENCE_APERTURE_AREA_M2 := 6.0`.

Dos defectos de la misma familia. `open_factor` es un export plano: asignarlo —lo natural desde un tween o un `AnimationPlayer`— no actualiza `runtime_portal`, mientras que `Room3D` sí usa setters para sus propiedades. Y `portal_size` está expuesto y **no se lee en ninguna parte**: una gatera y un portón abierto difractan igual.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_portal_diffraction.gd`:

```gdscript
class_name TestPortalDiffraction
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const PortalClass = preload("res://addons/opendou/nodes/opendou_portal_3d.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("portal_diffraction")

	# Asignar open_factor directamente debe propagarse al portal en runtime, sin
	# tener que acordarse de llamar set_open_factor().
	var portal = PortalClass.new()
	portal.portal_name = &"PuertaBlindada"
	portal.room_a_name = &"Pasillo"
	portal.room_b_name = &"Bunker"
	var runtime = portal.register_in_manager()
	a.ok(runtime != null, "el portal se registra")

	portal.open_factor = 0.25
	a.approx(runtime.open_factor, 0.25, "asignar open_factor sincroniza el portal", 0.001)
	portal.open_factor = 1.0
	a.approx(runtime.open_factor, 1.0, "y vuelve a sincronizar al reabrir", 0.001)

	# Fuera de rango se recorta, igual que hacia set_open_factor().
	portal.open_factor = 5.0
	a.approx(portal.open_factor, 1.0, "open_factor se recorta por arriba", 0.001)
	portal.open_factor = -3.0
	a.approx(portal.open_factor, 0.0, "open_factor se recorta por abajo", 0.001)

	# set_open_factor() sigue funcionando: es API publica que no se rompe.
	portal.set_open_factor(0.5)
	a.approx(runtime.open_factor, 0.5, "set_open_factor sigue sincronizando", 0.001)

	# El tamano de la apertura importa. Dos portales igual de abiertos pero de
	# tamano muy distinto no pueden difractar igual.
	var gatera = PortalClass.new()
	gatera.portal_size = Vector2(0.3, 0.3)
	gatera.open_factor = 1.0
	var porton = PortalClass.new()
	porton.portal_size = Vector2(3.0, 4.0)
	porton.open_factor = 1.0

	var lpf_gatera: float = gatera.get_diffraction_lpf()
	var lpf_porton: float = porton.get_diffraction_lpf()
	a.gt(lpf_porton, lpf_gatera, "el porton difracta menos que la gatera")
	a.lt(lpf_gatera, 5000.0, "una gatera abierta sigue filtrando mucho")

	# Cerrar reduce el cutoff aunque la apertura sea grande.
	porton.open_factor = 0.05
	a.lt(porton.get_diffraction_lpf(), lpf_porton, "cerrar el porton baja el cutoff")

	# El cutoff nunca sale del rango declarado.
	for f in [0.0, 0.5, 1.0]:
		porton.open_factor = f
		var v: float = porton.get_diffraction_lpf()
		a.ok(v >= PortalClass.MIN_DIFFRACTION_LPF_HZ and v <= PortalClass.MAX_DIFFRACTION_LPF_HZ,
			"el cutoff se queda en rango con open_factor %.1f" % f)

	gatera.free(); porton.free(); portal.free()
	return a
```

Registra la suite en `run_suite()` de `tests/test_all.gd` con su `preload`.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO. Aparecerá un `SCRIPT ERROR` por `MIN_DIFFRACTION_LPF_HZ` inexistente —que el runner marca como fatal— y, al resolverlo, fallarán `asignar open_factor sincroniza el portal` y `el porton difracta menos que la gatera`.

- [ ] **Step 3: Convierte `open_factor` en export con setter**

En `addons/opendou/nodes/opendou_portal_3d.gd`, sustituye la declaración plana:

```gdscript
@export_range(0.0, 1.0, 0.01) var open_factor: float = 1.0
```

por:

```gdscript
## Apertura del portal, de 0 (cerrado) a 1 (completamente abierto).
##
## Va con setter porque asignarlo es la forma natural de animarlo desde un tween
## o un AnimationPlayer, y antes ese camino no actualizaba el portal en runtime:
## habia que acordarse de llamar set_open_factor(). Room3D ya usaba setters para
## sus propiedades, asi que los dos nodos hermanos se comportaban distinto ante
## la misma operacion.
@export_range(0.0, 1.0, 0.01) var open_factor: float = 1.0:
	set(val):
		open_factor = clampf(val, 0.0, 1.0)
		if runtime_portal != null:
			runtime_portal.open_factor = open_factor
```

Y simplifica `set_open_factor()` para que delegue, en lugar de duplicar la lógica:

```gdscript
## Actualiza la apertura del portal. Se conserva como API publica; asignar
## open_factor directamente hace lo mismo.
func set_open_factor(p_factor: float) -> void:
	open_factor = p_factor
```

- [ ] **Step 4: Haz que `portal_size` influya en la difracción**

Añade las constantes junto a la cabecera del archivo:

```gdscript
## Corte del filtro con el portal cerrado, en Hz.
const MIN_DIFFRACTION_LPF_HZ: float = 300.0

## Corte del filtro con una apertura de referencia completamente abierta, en Hz.
const MAX_DIFFRACTION_LPF_HZ: float = 20000.0

## Area de apertura de referencia, en metros cuadrados: una puerta de 2 x 3 m.
## Una apertura de este tamano abierta del todo no filtra nada.
const REFERENCE_APERTURE_AREA_M2: float = 6.0
```

Y sustituye `get_diffraction_lpf()`:

```gdscript
## Corte del filtro paso-bajo de difraccion, en Hz.
##
## Depende de la apertura EFECTIVA, no solo de open_factor: portal_size estaba
## expuesto y no se leia en ninguna parte, asi que una gatera y un porton abierto
## difractaban igual. Fisicamente, cuanto menor es la apertura frente a la
## longitud de onda, mas difracta y mas agudos pierde.
func get_diffraction_lpf() -> float:
	var area: float = maxf(0.0, portal_size.x) * maxf(0.0, portal_size.y)
	var effective: float = clampf(open_factor, 0.0, 1.0) * (area / REFERENCE_APERTURE_AREA_M2)
	return lerpf(MIN_DIFFRACTION_LPF_HZ, MAX_DIFFRACTION_LPF_HZ, clampf(effective, 0.0, 1.0))
```

- [ ] **Step 5: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Si `tests/test_spatial_acoustics.gd` falla afirmando un cutoff concreto, comprueba qué valor esperaba: si asumía que `open_factor = 1` da 20000 Hz con el `portal_size` por defecto de 2x3, eso sigue siendo cierto porque 2x3 es exactamente el área de referencia.

- [ ] **Step 6: Commit**

```bash
git add addons/opendou/nodes/opendou_portal_3d.gd tests/test_portal_diffraction.gd tests/test_all.gd
git commit -m "fix(spatial): portal reacts to open_factor and portal_size

open_factor era un export plano: asignarlo, que es la forma natural de animarlo
desde un tween o un AnimationPlayer, no actualizaba el portal en runtime. Habia
que acordarse de llamar set_open_factor(), mientras que Room3D si usaba setters:
los dos nodos hermanos se comportaban distinto ante la misma operacion.

Y portal_size estaba expuesto sin leerse en ninguna parte, asi que una gatera y
un porton abierto difractaban igual. Ahora el cutoff depende de la apertura
efectiva, con el area de referencia en una constante nombrada."
```

---

## Task 6: Pool de buses de reverb

**Files:**
- Create: `addons/opendou/runtime/spatial/reverb_bus_pool.gd`
- Create: `tests/test_reverb_bus_pool.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouReverbBusPool` con `configure(max_buses := 8, rt60_step_sec := 0.3) -> void`, `bus_for_rt60(rt60: float, absorption: float) -> StringName`, `tier_for_rt60(rt60: float) -> int`, `managed_bus_count() -> int`, `release_all() -> void`, y las constantes `BUS_NAME_PREFIX`, `RT60_REFERENCE_SEC`.
- Consumes: `OpenDouAssert`.

**Restricción que define el diseño:** `AudioServer.remove_bus(i)` desplaza los índices de los buses posteriores, así que los buses se crean una vez y **no se destruyen** durante la sesión. `release_all()` existe solo para los tests y quita los buses **desde el final hacia atrás**, que es el único orden seguro.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_reverb_bus_pool.gd`:

```gdscript
class_name TestReverbBusPool
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const ReverbBusPoolClass = preload("res://addons/opendou/runtime/spatial/reverb_bus_pool.gd")

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("reverb_bus_pool")
	var buses_before: int = AudioServer.bus_count

	var pool = ReverbBusPoolClass.new()
	pool.configure(3, 0.3)

	# Dos salas con RT60 dentro del mismo escalon comparten bus: con 100 salas
	# siguen siendo unos pocos buses, y Godot procesa cada bus cada frame.
	var bus_a: StringName = pool.bus_for_rt60(1.20, 0.1)
	var bus_b: StringName = pool.bus_for_rt60(1.28, 0.1)
	a.eq(bus_a, bus_b, "RT60 del mismo escalon comparten bus")
	a.eq(pool.managed_bus_count(), 1, "solo se creo un bus")

	# RT60 de escalones distintos no comparten.
	var bus_c: StringName = pool.bus_for_rt60(3.0, 0.1)
	a.ok(bus_c != bus_a, "RT60 de escalones distintos usan buses distintos")
	a.eq(pool.managed_bus_count(), 2, "ya hay dos buses")

	# El bus existe de verdad en el AudioServer y lleva un reverb insertado.
	var idx: int = AudioServer.get_bus_index(String(bus_a))
	a.gt(float(idx), 0.0, "el bus existe en el AudioServer")
	if idx >= 0:
		a.gt(float(AudioServer.get_bus_effect_count(idx)), 0.0, "el bus lleva al menos un efecto")
		a.ok(AudioServer.get_bus_effect(idx, 0) is AudioEffectReverb, "el efecto es un AudioEffectReverb")

	# Superado el techo, una sala nueva reutiliza el escalon mas proximo en lugar
	# de crear buses sin limite.
	pool.bus_for_rt60(0.3, 0.5)
	a.eq(pool.managed_bus_count(), 3, "se alcanza el techo de 3 buses")
	var overflow: StringName = pool.bus_for_rt60(9.0, 0.02)
	a.eq(pool.managed_bus_count(), 3, "el techo no se supera")
	a.ok(not String(overflow).is_empty(), "aun asi devuelve un bus utilizable")
	a.ok(AudioServer.get_bus_index(String(overflow)) != -1, "el bus de desborde existe")

	# El escalon se calcula por redondeo sobre el paso configurado.
	a.eq(pool.tier_for_rt60(1.20), 4, "1.20 s con paso 0.3 cae en el escalon 4")
	a.eq(pool.tier_for_rt60(0.0), 0, "un RT60 nulo cae en el escalon 0")

	pool.release_all()
	a.eq(AudioServer.bus_count, buses_before, "release_all deja el AudioServer como estaba")
	return a
```

Registra la suite en `run_suite()` con su `preload`.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO con `Parse Error: Preload file ... reverb_bus_pool.gd does not exist`.

- [ ] **Step 3: Implementa el pool**

Crea `addons/opendou/runtime/spatial/reverb_bus_pool.gd`:

```gdscript
class_name OpenDouReverbBusPool
extends RefCounted

## Agrupa salas por perfil acustico y les asigna buses de reverb nativos de Godot.
##
## Se comparten los buses en lugar de dar uno a cada sala porque Godot procesa
## TODOS los buses cada frame: con un bus por sala, cien salas cuestan cien
## reverbs. Agrupando por RT60 en escalones, cien salas siguen costando ocho.
##
## Los buses se crean una vez y NO se destruyen durante la sesion:
## AudioServer.remove_bus() desplaza los indices de los buses posteriores, y eso
## corrompe cualquier referencia por indice que haya viva en el motor.
## release_all() existe solo para los tests, y quita los buses desde el final.

const BUS_NAME_PREFIX: String = "OpenDouReverb_"

## RT60 que satura room_size a 1.0.
##
## calculate_sabine_reverb() ya limita el RT60 a 12 s y los interiores habituales
## caen entre 0,3 y 3 s: 6 s deja margen para naves y cuevas sin aplastar el
## rango util.
const RT60_REFERENCE_SEC: float = 6.0

## Numero maximo de buses de reverb gestionados.
var max_buses: int = 8

## Ancho de cada escalon de RT60, en segundos.
var rt60_step_sec: float = 0.3

var _tier_to_bus: Dictionary = {}

## Ajusta el techo de buses y la resolucion de los escalones.
func configure(p_max_buses: int = 8, p_rt60_step_sec: float = 0.3) -> void:
	max_buses = maxi(1, p_max_buses)
	rt60_step_sec = maxf(0.05, p_rt60_step_sec)

## Escalon al que pertenece un RT60.
func tier_for_rt60(rt60: float) -> int:
	return int(round(maxf(0.0, rt60) / rt60_step_sec))

## Numero de buses que este pool ha creado.
func managed_bus_count() -> int:
	return _tier_to_bus.size()

## Nombre del bus de reverb que corresponde a un RT60, creandolo si hace falta.
##
## Alcanzado el techo, devuelve el bus del escalon existente mas proximo: es
## preferible un reverb ligeramente distinto a un bus mas que procesar cada frame.
func bus_for_rt60(rt60: float, absorption: float) -> StringName:
	var tier: int = tier_for_rt60(rt60)
	if _tier_to_bus.has(tier):
		return _tier_to_bus[tier]

	if _tier_to_bus.size() >= max_buses:
		return _nearest_existing_bus(tier)

	var bus_name: StringName = _create_bus(tier, rt60, absorption)
	if bus_name.is_empty():
		push_error("[OpenDou] no se pudo crear el bus de reverb del escalon %d" % tier)
		return &"Master"
	_tier_to_bus[tier] = bus_name
	return bus_name

## Quita los buses gestionados. Solo para tests.
##
## Va desde el final hacia atras porque remove_bus() desplaza los indices
## posteriores: quitar de delante hacia atras invalidaria los indices restantes.
func release_all() -> void:
	var names: Array = _tier_to_bus.values()
	var indices: Array[int] = []
	for n in names:
		var idx: int = AudioServer.get_bus_index(String(n))
		if idx > 0:
			indices.append(idx)
	indices.sort()
	indices.reverse()
	for idx in indices:
		if idx > 0 and idx < AudioServer.bus_count:
			AudioServer.remove_bus(idx)
	_tier_to_bus.clear()

func _nearest_existing_bus(tier: int) -> StringName:
	var best_tier: int = -1
	var best_distance: int = 1 << 30
	for existing in _tier_to_bus.keys():
		var d: int = absi(int(existing) - tier)
		if d < best_distance:
			best_distance = d
			best_tier = int(existing)
	if best_tier < 0:
		return &"Master"
	return _tier_to_bus[best_tier]

func _create_bus(tier: int, rt60: float, absorption: float) -> StringName:
	var bus_name: String = "%s%d" % [BUS_NAME_PREFIX, tier]

	# Si ya existe con ese nombre (por ejemplo tras recargar), se reutiliza en
	# lugar de duplicarlo.
	var existing: int = AudioServer.get_bus_index(bus_name)
	if existing != -1:
		return StringName(bus_name)

	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	AudioServer.add_bus_effect(idx, _make_reverb(rt60, absorption), 0)
	return StringName(bus_name)

## Configura un AudioEffectReverb a partir del RT60 y la absorcion.
##
## AudioEffectReverb NO expone RT60: solo room_size, damping, spread, hipass,
## predelay y las mezclas seca y humeda. El mapeo es una APROXIMACION CALIBRADA,
## no una derivacion fisica, y los coeficientes estan en constantes para que se
## puedan ajustar de oido sin tocar la logica.
func _make_reverb(rt60: float, absorption: float) -> AudioEffectReverb:
	var reverb := AudioEffectReverb.new()
	reverb.room_size = clampf(rt60 / RT60_REFERENCE_SEC, 0.05, 1.0)
	reverb.damping = clampf(absorption, 0.0, 1.0)
	# El bus es exclusivamente de reverb: la senal directa llega por el bus del
	# propio emisor, asi que aqui no hay componente seca que mezclar.
	reverb.wet = 1.0
	reverb.dry = 0.0
	return reverb
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK, con las trece aserciones del pool en verde.

- [ ] **Step 5: Commit**

```bash
git add addons/opendou/runtime/spatial/reverb_bus_pool.gd tests/test_reverb_bus_pool.gd tests/test_all.gd
git commit -m "feat(spatial): add a shared reverb bus pool grouped by RT60

Godot procesa TODOS los buses cada frame, asi que un bus por sala cuesta cien
reverbs con cien salas. Agrupando por RT60 en escalones configurables con techo
fijo, cien salas siguen costando ocho.

Los buses se crean una vez y no se destruyen: remove_bus() desplaza los indices
de los posteriores y corromperia referencias vivas. release_all(), que solo usan
los tests, los quita desde el final, que es el unico orden seguro.

El mapeo RT60 -> AudioEffectReverb queda documentado como aproximacion calibrada
y no como derivacion fisica, porque el efecto no expone RT60."
```

---

## Task 7: `Room3D` suena por su bus de reverb nativo

**Files:**
- Modify: `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd`
- Modify: `addons/opendou/nodes/opendou_room_3d.gd`
- Modify: `tests/support/audio_probe.gd`
- Modify: `tests/test_audio_output.gd`
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `SpatialAcousticsManager.reverb_bus_pool: OpenDouReverbBusPool` (creado en `_init()`).
- Produces: `OpenDouRoom3D.reverb_send_amount: float` (export, 0..1, defecto 0.5), `reverb_uniformity: float` (export, 0..1, defecto 0.5), `get_assigned_reverb_bus() -> StringName`.
- Produces: `OpenDouAudioProbe.attach_to_existing_bus(bus_name: StringName, buffer_length_sec := 2.0) -> bool`. `teardown()` distingue si el bus lo creó la sonda o solo se enganchó a él.
- Consumes: `OpenDouReverbBusPool.bus_for_rt60()` de la Tarea 6.

**La trampa que hay que cubrir:** `Area3D.reverb_bus_name` **no falla** si el bus no existe. Lo coacciona silenciosamente a `"Master"` y el reverb de la sala entera se va al bus maestro sin que nadie se entere. Releer el valor tras asignarlo es obligatorio.

- [ ] **Step 1: Amplía la sonda para engancharse a un bus existente**

En `tests/support/audio_probe.gd`, añade el estado y el método. `setup()` no cambia:

```gdscript
## Verdadero si el bus lo creo esta sonda; falso si solo se engancho a uno ajeno.
var _owns_bus: bool = false
```

En `setup()`, tras crear el bus, añade `_owns_bus = true`.

Y añade:

```gdscript
## Inserta una captura en un bus que YA existe, sin crear ninguno.
##
## Sirve para medir cuanta energia llega a un bus que gestiona otro (por ejemplo
## el bus de reverb que el pool asigno a una sala). Devuelve false si el bus no
## existe.
func attach_to_existing_bus(target_bus: StringName, buffer_length_sec: float = 2.0) -> bool:
	teardown()
	var idx: int = AudioServer.get_bus_index(String(target_bus))
	if idx == -1:
		return false
	bus_index = idx
	_owns_bus = false
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = buffer_length_sec
	# Al final de la cadena: interesa medir la salida del bus, ya procesada por
	# el reverb, no su entrada.
	AudioServer.add_bus_effect(idx, _capture, AudioServer.get_bus_effect_count(idx))
	return true
```

Y sustituye `teardown()` para que respete la propiedad del bus:

```gdscript
## Elimina la captura, y el bus solo si lo creo esta sonda.
func teardown() -> void:
	if bus_index >= 0 and bus_index < AudioServer.bus_count:
		if _owns_bus:
			AudioServer.remove_bus(bus_index)
		elif _capture != null:
			# Quitar solo nuestra captura: el bus es de otro.
			for i in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
				if AudioServer.get_bus_effect(bus_index, i) == _capture:
					AudioServer.remove_bus_effect(bus_index, i)
					break
	bus_index = -1
	_owns_bus = false
	_capture = null
```

Y en `bus_name()`, devuelve el nombre real del bus enganchado en lugar de la constante:

```gdscript
## Nombre del bus al que deben enrutarse los reproductores bajo prueba.
func bus_name() -> StringName:
	if not _owns_bus and bus_index >= 0 and bus_index < AudioServer.bus_count:
		return StringName(AudioServer.get_bus_name(bus_index))
	return BUS_NAME
```

- [ ] **Step 2: Escribe el test que falla**

Añade a `tests/test_audio_output.gd` y cablea la llamada en `run_all_async` con `a.absorb(await run_room_reverb_async(tree))`:

```gdscript
## Una voz dentro de una sala debe producir energia medible en el bus de reverb
## de esa sala. Es la asercion que demuestra que el reverb por sala existe de
## verdad, en lugar de ser un ConvolutionReverbNode desconectado.
static func run_room_reverb_async(tree: SceneTree) -> OpenDouAssert:
	var a := OpenDouAssertClass.new("room_reverb")

	var manager = AudioEventManagerClass.new()
	tree.root.add_child(manager)
	await tree.process_frame

	# Una sala grande y reflectante, con su colisionador para que se detecten
	# sus dimensiones.
	var room = OpenDouRoom3DClass.new()
	room.room_name = &"NaveIndustrial"
	room.material_preset = "Metal"
	room.reverb_send_amount = 1.0
	room.reverb_uniformity = 1.0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 12.0, 30.0)
	shape.shape = box
	room.add_child(shape)
	tree.root.add_child(room)
	await tree.process_frame
	await tree.physics_frame

	var bus: StringName = room.get_assigned_reverb_bus()
	a.ok(not String(bus).is_empty(), "la sala tiene un bus de reverb asignado")
	# La trampa: si el bus no existiera, Godot habria coaccionado el nombre a
	# Master sin avisar y el reverb de la sala se iria al bus maestro.
	a.ok(String(bus) != "Master", "el nombre del bus no quedo coaccionado a Master")
	a.ok(room.reverb_bus_enabled, "el reverb del Area3D quedo activado")
	a.eq(String(room.reverb_bus_name), String(bus), "Area3D conserva el nombre asignado")

	# Sonda enganchada al bus de reverb de la sala.
	var probe = OpenDouAudioProbeClass.new()
	a.ok(probe.attach_to_existing_bus(bus, 2.0), "la sonda se engancha al bus de reverb")

	# Un emisor dentro de la sala, con area_mask 1 para que el reverb nativo de
	# Area3D lo alcance.
	var emitter := AudioStreamPlayer3D.new()
	emitter.stream = AudioSynthesizerClass.create_tone(440.0, 4.0, 0.9, false)
	emitter.area_mask = 1
	emitter.unit_size = 60.0
	tree.root.add_child(emitter)
	await tree.process_frame
	emitter.global_position = Vector3.ZERO
	await tree.physics_frame
	await tree.physics_frame
	emitter.play()

	probe.drain()
	var peak: float = await probe.measure_peak_over_frames(tree, 60)
	a.gt(peak, 0.001, "la voz dentro de la sala produce energia en su bus de reverb")

	emitter.stop()
	emitter.stream = null
	probe.teardown()
	tree.root.remove_child(emitter)
	emitter.free()
	tree.root.remove_child(room)
	room.free()
	manager.free()
	return a
```

Añade el `preload` de `OpenDouRoom3DClass` a la cabecera del archivo:

```gdscript
const OpenDouRoom3DClass = preload("res://addons/opendou/nodes/opendou_room_3d.gd")
```

- [ ] **Step 3: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO por `get_assigned_reverb_bus` y `reverb_send_amount` inexistentes, que el runner marca como `SCRIPT ERROR` fatal.

- [ ] **Step 4: Da un pool de buses al manager espacial**

En `addons/opendou/runtime/spatial/spatial_acoustics_manager.gd`, añade el preload, la propiedad y su creación en `_init()`:

```gdscript
const ReverbBusPoolClass = preload("res://addons/opendou/runtime/spatial/reverb_bus_pool.gd")

## Pool compartido de buses de reverb, agrupados por RT60.
var reverb_bus_pool: OpenDouReverbBusPool = null
```

En `_init()`: `reverb_bus_pool = ReverbBusPoolClass.new()`.

**Lee el archivo antes de editar**: si no tiene `_init()`, créalo respetando lo que ya inicialice el resto de la clase.

- [ ] **Step 5: Conecta `Room3D` al bus nativo**

En `addons/opendou/nodes/opendou_room_3d.gd`, añade el preload del pool y los dos exports nuevos:

```gdscript
const ReverbBusPoolClass = preload("res://addons/opendou/runtime/spatial/reverb_bus_pool.gd")
```

En el grupo `@export_group("Reverb & Convolution IR")`:

```gdscript
## Cuanta senal de los emisores de dentro se envia al bus de reverb de la sala.
@export_range(0.0, 1.0, 0.01) var reverb_send_amount: float = 0.5:
	set(val):
		reverb_send_amount = clampf(val, 0.0, 1.0)
		reverb_bus_amount = reverb_send_amount

## Uniformidad del reverb dentro del volumen de la sala.
@export_range(0.0, 1.0, 0.01) var reverb_uniformity: float = 0.5:
	set(val):
		reverb_uniformity = clampf(val, 0.0, 1.0)
		reverb_bus_uniformity = reverb_uniformity
```

Añade el estado y el accesor:

```gdscript
var _assigned_reverb_bus: StringName = &""

## Bus de reverb que el pool asigno a esta sala.
func get_assigned_reverb_bus() -> StringName:
	return _assigned_reverb_bus
```

Y el método que hace el enrutado, llamado al final de `register_in_manager()`:

```gdscript
## Pide su bus de reverb al pool y enruta el reverb nativo del Area3D hacia el.
##
## Sustituye a la convolucion en GDScript, que calculaba 512 taps que nadie
## reproducia. Aqui el reverb lo aplica Godot en C++ sobre un bus compartido.
func _route_native_reverb(mgr: SpatialAcousticsManager) -> void:
	if mgr == null or mgr.reverb_bus_pool == null:
		return

	var bus: StringName = mgr.reverb_bus_pool.bus_for_rt60(get_effective_reverb_time(), get_absorption())
	if bus.is_empty():
		return
	_assigned_reverb_bus = bus

	reverb_bus_enabled = true
	reverb_bus_name = String(bus)
	reverb_bus_amount = reverb_send_amount
	reverb_bus_uniformity = reverb_uniformity

	# Godot NO da error si el bus no existe: coacciona el nombre a "Master" y el
	# reverb de la sala entera se va al bus maestro sin que nadie se entere. Hay
	# que releer el valor para saber si la asignacion pego.
	if String(reverb_bus_name) != String(bus):
		push_error("[OpenDou] la sala '%s' no pudo enrutar su reverb al bus '%s': Godot lo coacciono a '%s'." % [
			str(room_name), String(bus), String(reverb_bus_name)])
		_assigned_reverb_bus = StringName(reverb_bus_name)

	# El reverb nativo solo alcanza a los reproductores cuyo area_mask corte la
	# capa de este Area3D. Las voces del pool nacen con area_mask = 1.
	if (collision_layer & 1) == 0:
		push_warning("[OpenDou] la sala '%s' no esta en la capa fisica 1, asi que el reverb nativo no alcanzara a las voces del pool de OpenDou." % str(room_name))
```

Al final de `register_in_manager()`, justo antes del `return runtime_room`:

```gdscript
	_route_native_reverb(mgr)
```

- [ ] **Step 6: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK, con `la voz dentro de la sala produce energia en su bus de reverb` en verde. Verificado de antemano que este mecanismo funciona en headless: un emisor dentro de un `Area3D` con `reverb_bus_enabled` dio pico 3,55 en el bus de reverb.

Si el pico sale 0, comprueba en este orden: que `room.reverb_bus_name` no acabó en `"Master"`, que el emisor tiene `area_mask = 1`, que está **dentro** del volumen del colisionador, y que pasaron al menos dos `physics_frame` antes del `play()`.

- [ ] **Step 7: Commit**

```bash
git add addons/opendou/runtime/spatial/spatial_acoustics_manager.gd addons/opendou/nodes/opendou_room_3d.gd tests/support/audio_probe.gd tests/test_audio_output.gd tests/test_all.gd
git commit -m "feat(spatial): route room reverb through a native Godot bus

Room3D pide su bus al pool compartido y enruta hacia el el reverb nativo del
Area3D que ya heredaba. El reverb lo aplica Godot en C++ en lugar de calcularse
como 512 taps en GDScript que nadie reproducia.

Se cubre la trampa que la verificacion destapo: Godot NO da error si el bus no
existe, coacciona reverb_bus_name a Master y el reverb de la sala entera se va al
bus maestro sin avisar. Ahora se relee el valor y se emite push_error si no pego.

Y se avisa si la sala no esta en la capa fisica 1: el reverb nativo solo alcanza
a los reproductores cuyo area_mask corte la capa del area, y las voces del pool
nacen con area_mask 1.

La sonda de audio gana attach_to_existing_bus() para poder medir un bus ajeno."
```

---

## Task 8: El IR pasa a ser fuente de RT60 y desaparece la convolución

**Files:**
- Create: `addons/opendou/runtime/spatial/ir_rt60_analyzer.gd`
- Create: `tests/test_ir_rt60.gd`
- Modify: `addons/opendou/nodes/opendou_room_3d.gd`
- Modify: `addons/opendou/runtime/spatial/audio_room.gd`
- Modify: `tests/test_room_convolution.gd`
- Modify: `scenes/demos/08_tactical_canyon/demo_tactical_canyon.gd`, `tests/test_tactical_canyon_demo.gd`
- **Delete:** `addons/opendou/core/dsp/convolution_reverb_node.gd` (y su `.uid`)
- Modify: `tests/test_all.gd`

**Interfaces:**
- Produces: `OpenDouIRRT60Analyzer.rt60_from_ir(wav: AudioStreamWAV) -> float` (static). Devuelve 0.0 si no se puede medir.
- Produces: `OpenDouRoom3D.ReverbMode` con dos valores: `SABINE_RT60 = 0`, `IR_DERIVED_RT60 = 1`.
- Consumes: `OpenDouWavDecoder.to_mono_floats()` de la Tarea 3.

**El método.** Integración de Schroeder más extrapolación T20: se integra la energía desde el final hacia el principio, se miden los tiempos en que la curva cruza −5 dB y −25 dB, y se extrapola la pendiente a −60 dB (`RT60 = 3 · (t25 − t5)`). Buscar ingenuamente la caída de 60 dB no funciona: el ruido de fondo de cualquier IR medido la enmascara.

- [ ] **Step 1: Escribe el test que falla**

Crea `tests/test_ir_rt60.gd`:

```gdscript
class_name TestIRRT60
extends RefCounted

const OpenDouAssertClass = preload("res://tests/support/opendou_assert.gd")
const IRAnalyzerClass = preload("res://addons/opendou/runtime/spatial/ir_rt60_analyzer.gd")

## Construye un IR sintetico cuyo nivel cae exactamente 60 dB en rt60 segundos.
##
## El nivel en dB es 20*log10(amplitud), asi que caer 60 dB es multiplicar la
## amplitud por 0.001: a = ln(1000) / rt60.
## El rate es bajo a proposito: el metodo es independiente de la frecuencia de
## muestreo, y con 44100 las tres mediciones suman medio millon de iteraciones de
## GDScript sin aportar nada a la prueba.
static func _make_ir(rt60: float, rate: int = 11025) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = false
	w.mix_rate = rate
	var n: int = int(rt60 * 1.5 * float(rate))
	var decay: float = log(1000.0) / rt60
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	# Generador congruencial lineal: ruido determinista y bien condicionado para
	# cualquier n. Un fract(sin(i)*K) degrada su distribucion con i grande, y aqui
	# n llega a decenas de miles.
	var seed_state: int = 12345
	for i in range(n):
		var t: float = float(i) / float(rate)
		seed_state = (seed_state * 1103515245 + 12345) & 0x7FFFFFFF
		var noise: float = (float(seed_state) / float(0x7FFFFFFF)) * 2.0 - 1.0
		# Un IR real es ruidoso, no una sinusoide limpia.
		var amp: float = exp(-decay * t) * noise
		var v: int = clampi(int(amp * 32767.0), -32768, 32767)
		if v < 0:
			v += 65536
		bytes[i * 2] = v & 0xFF
		bytes[i * 2 + 1] = (v >> 8) & 0xFF
	w.data = bytes
	return w

static func run_all() -> OpenDouAssert:
	var a := OpenDouAssertClass.new("ir_rt60")

	# Tolerancia del +-15 %: la extrapolacion T20 mide una pendiente sobre 20 dB
	# y la proyecta a 60, asi que triplica cualquier error de la medida. Exigir
	# mas precision seria afirmar algo que el metodo no da.
	for target in [0.5, 1.0, 2.5]:
		var measured: float = IRAnalyzerClass.rt60_from_ir(_make_ir(target))
		a.gt(measured, target * 0.85, "RT60 de %.1f s medido por encima del -15%%" % target)
		a.lt(measured, target * 1.15, "RT60 de %.1f s medido por debajo del +15%%" % target)

	# Entradas que no se pueden medir devuelven 0.0 en lugar de un numero
	# inventado.
	a.eq(IRAnalyzerClass.rt60_from_ir(null), 0.0, "null devuelve 0.0")
	var empty := AudioStreamWAV.new()
	empty.format = AudioStreamWAV.FORMAT_16_BITS
	empty.data = PackedByteArray()
	a.eq(IRAnalyzerClass.rt60_from_ir(empty), 0.0, "un IR vacio devuelve 0.0")

	# Silencio absoluto tampoco se puede medir.
	var silent := AudioStreamWAV.new()
	silent.format = AudioStreamWAV.FORMAT_16_BITS
	silent.stereo = false
	silent.mix_rate = 44100
	var zeros := PackedByteArray()
	zeros.resize(4096)
	silent.data = zeros
	a.eq(IRAnalyzerClass.rt60_from_ir(silent), 0.0, "un IR en silencio devuelve 0.0")

	return a
```

Registra la suite en `run_suite()` con su `preload`.

- [ ] **Step 2: Ejecuta y verifica que falla**

Run: `./run_tests.sh`

Expected: FALLO con `Parse Error: Preload file ... ir_rt60_analyzer.gd does not exist`.

- [ ] **Step 3: Implementa el analizador**

Crea `addons/opendou/runtime/spatial/ir_rt60_analyzer.gd`:

```gdscript
class_name OpenDouIRRT60Analyzer
extends RefCounted

## Deriva el RT60 de una respuesta al impulso medida.
##
## Existe porque la convolucion en GDScript no era viable: 512 taps por muestra
## es DSP interpretado, justo lo que la arquitectura evita. Pero un IR medido
## sigue siendo informacion valiosa, y de el se puede sacar el RT60 que alimenta
## el reverb nativo. Eso es lo que hace un disenador de audio con una medicion
## real de sala.
##
## Metodo: integracion de Schroeder mas extrapolacion T20. Buscar ingenuamente
## la caida de 60 dB no funciona, porque el ruido de fondo de cualquier IR medido
## la enmascara mucho antes de llegar.

const WavDecoderClass = preload("res://addons/opendou/runtime/wav_decoder.gd")

## Nivel al que empieza el tramo que se ajusta, en dB bajo el maximo.
const T20_START_DB: float = -5.0

## Nivel al que acaba el tramo que se ajusta, en dB bajo el maximo.
const T20_END_DB: float = -25.0

## Muestras minimas para intentar una medida.
const MIN_SAMPLES: int = 64

## RT60 de una respuesta al impulso, en segundos. Devuelve 0.0 si no se puede
## medir.
static func rt60_from_ir(wav: AudioStreamWAV) -> float:
	if wav == null:
		return 0.0
	var samples: PackedFloat32Array = WavDecoderClass.to_mono_floats(wav)
	if samples.size() < MIN_SAMPLES:
		return 0.0
	var rate: float = float(wav.mix_rate)
	if rate <= 0.0:
		return 0.0

	# Curva de decaimiento de energia por integracion de Schroeder: se acumula la
	# energia desde el final hacia el principio. Es el metodo estandar; medir el
	# envolvente instantaneo daria una curva demasiado ruidosa para ajustar.
	var n: int = samples.size()
	var edc := PackedFloat64Array()
	edc.resize(n)
	var acc: float = 0.0
	for i in range(n - 1, -1, -1):
		var s: float = samples[i]
		acc += s * s
		edc[i] = acc

	var total: float = edc[0]
	if total <= 0.0:
		return 0.0

	var t_start: float = -1.0
	var t_end: float = -1.0
	for i in range(n):
		var ratio: float = edc[i] / total
		if ratio <= 0.0:
			break
		var db: float = 10.0 * (log(ratio) / log(10.0))
		if t_start < 0.0 and db <= T20_START_DB:
			t_start = float(i) / rate
		if db <= T20_END_DB:
			t_end = float(i) / rate
			break

	if t_start < 0.0 or t_end < 0.0 or t_end <= t_start:
		return 0.0

	# La pendiente se mide sobre el tramo de 20 dB y se extrapola a 60: de ahi el
	# factor 3.
	var span_db: float = absf(T20_END_DB - T20_START_DB)
	return 60.0 * (t_end - t_start) / span_db
```

- [ ] **Step 4: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK, con los tres RT60 dentro del ±15 %.

- [ ] **Step 5: Reduce `ReverbMode` a dos valores y usa el IR como fuente de RT60**

En `addons/opendou/nodes/opendou_room_3d.gd`:

Sustituye el enum:

```gdscript
enum ReverbMode {
	SABINE_RT60,     ## RT60 calculado geometricamente con la formula de Sabine
	IR_DERIVED_RT60, ## RT60 derivado de una respuesta al impulso medida
}
```

Añade el preload del analizador y borra el de `ConvolutionReverbNodeClass`:

```gdscript
const IRAnalyzerClass = preload("res://addons/opendou/runtime/spatial/ir_rt60_analyzer.gd")
```

Borra la variable `_convolution_node`, la función `_update_ir_kernel()` completa, y los exports `convolution_wet_db` y `convolution_dry_db`.

Sustituye el setter de `impulse_response_stream`:

```gdscript
## Respuesta al impulso medida de la sala.
##
## Ya no se convoluciona: se analiza para derivar su RT60, que es el que alimenta
## el reverb nativo cuando reverb_mode es IR_DERIVED_RT60.
@export var impulse_response_stream: AudioStreamWAV = null:
	set(val):
		impulse_response_stream = val
		_ir_derived_rt60 = IRAnalyzerClass.rt60_from_ir(val)
```

Añade el estado:

```gdscript
## RT60 derivado del ultimo IR asignado, en segundos. 0.0 si no hay o no se pudo medir.
var _ir_derived_rt60: float = 0.0

## RT60 derivado del IR asignado.
func get_ir_derived_rt60() -> float:
	return _ir_derived_rt60
```

Y amplía `get_effective_reverb_time()` para que respete el modo:

```gdscript
## RT60 efectivo de la sala, en segundos.
##
## Prioridad: el valor manual si se fijo, luego el derivado del IR si el modo lo
## pide y se pudo medir, y por ultimo el calculo de Sabine.
func get_effective_reverb_time() -> float:
	if custom_reverb_time > 0.0:
		return custom_reverb_time
	if reverb_mode == ReverbMode.IR_DERIVED_RT60 and _ir_derived_rt60 > 0.0:
		return _ir_derived_rt60
	return calculated_rt60
```

- [ ] **Step 6: Limpia `audio_room.gd` y elimina el nodo de convolución**

En `addons/opendou/runtime/spatial/audio_room.gd`, borra `convolution_wet_db`, `convolution_dry_db` e `ir_kernel`, y actualiza el comentario de `reverb_mode`:

```gdscript
var reverb_mode: int = 0 # 0 = SABINE_RT60, 1 = IR_DERIVED_RT60
```

Elimina el archivo y su `.uid`:

```bash
git rm addons/opendou/core/dsp/convolution_reverb_node.gd addons/opendou/core/dsp/convolution_reverb_node.gd.uid
```

- [ ] **Step 7: Actualiza los consumidores del enum antiguo**

`tests/test_room_convolution.gd` prueba `ALGORITHMIC` y `CONVOLUTION_IR`. Reorientalo al enum nuevo y al RT60 desde IR: comprueba que el modo por defecto es `SABINE_RT60`, que asignar `IR_DERIVED_RT60` con un IR medible cambia `get_effective_reverb_time()`, y que sin IR se cae de vuelta al cálculo de Sabine. Renómbralo a `tests/test_room_reverb_modes.gd` y actualiza su `class_name` y su `preload` en `tests/test_all.gd`.

En `scenes/demos/08_tactical_canyon/demo_tactical_canyon.gd` y `tests/test_tactical_canyon_demo.gd`, los `reverb_mode = 1` y las comparaciones con `1` siguen siendo válidos numéricamente porque `IR_DERIVED_RT60` también vale 1. **Cambio mínimo:** sustituye los literales por el nombre del enum y ajusta los comentarios que digan «convolución». No inviertas más: la demo se borra en la Fase 5.

- [ ] **Step 8: Ejecuta y verifica que pasa**

Run: `./run_tests.sh`

Expected: OK. Comprueba además que no queda ninguna referencia:

```bash
grep -rn "ConvolutionReverbNode\|convolution_wet_db\|convolution_dry_db\|ir_kernel\|CONVOLUTION_IR\|HYBRID" addons/ tests/ scenes/
```

Expected: sin resultados.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat(spatial): derive RT60 from measured IRs and drop GDScript convolution

La convolucion en GDScript calculaba 512 taps por muestra que nadie reproducia:
DSP interpretado, justo lo que la arquitectura evita. Pero un IR medido sigue
siendo informacion valiosa, asi que pasa a ser la FUENTE del RT60 que alimenta
el reverb nativo. Es lo que hace un disenador de audio con una medicion de sala.

El metodo es integracion de Schroeder mas extrapolacion T20: se mide la pendiente
del decaimiento entre -5 y -25 dB y se proyecta a -60. Buscar ingenuamente la
caida de 60 dB no funciona porque el ruido de fondo de cualquier IR medido la
enmascara mucho antes.

ReverbMode queda en SABINE_RT60 e IR_DERIVED_RT60. HYBRID desaparece: no
significaba nada sin convolucion. convolution_reverb_node.gd se elimina."
```

---

## Notas para quien ejecute el plan

**Orden.** Las tareas 1 a 3 son independientes entre sí, pero la 2 consume el helper de la 1 y la 8 consume el decodificador de la 3. Las tareas 6, 7 y 8 son una cadena: el pool, su uso y el IR. No reordenes 1→2, 3→8 ni 6→7→8.

**Si un test existente empieza a fallar**, comprueba qué afirmaba antes de cambiar el código nuevo. Varios tests de esta zona afirman resultados del helper de transforms roto o del cutoff de difracción que ignoraba `portal_size`. Actualizarlos es trabajo esperado.

**No toques los tests de demos** más allá de lo que exija el runner. Las escenas se borran en la Fase 5.

**Si el trinquete de fugas sube, investiga antes de tocar el número.** En la Fase 1, cada subida delató fugas preexistentes: 399 objetos en total. Los buses de reverb no son objetos de ObjectDB, pero los nodos de sala y portal de los tests sí, y hay que liberarlos.

**Al terminar la fase**, ejecuta `./run_tests.sh` en limpio y confirma: `RESULTADO: OK`, sin `SCRIPT ERROR`, fugas no superiores al techo, y `git status --porcelain` vacío.
