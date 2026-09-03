# Fase 16 — «La presa»: la escena grande

**Fecha:** 2026-09-03
**Estado:** Diseñado sin intervención del usuario (flujo acordado); correcciones en §12.
**Rama:** `main`
**Godot verificado:** 4.7.2 · **Steam Audio:** 4.8.1
**Fase anterior:** [15](2026-09-03-fase15-deudas-design.md)

---

## 1. Análisis: qué hay que exhibir y qué escena lo pide

### 1.1 Inventario de lo construido (Fases 1–15)

| Familia | Capacidad | Qué escena natural la luce |
|---|---|---|
| Grafo de salas | `OpenDouRoom3D`/`OpenDouPortal3D`, origen aparente en el portal, filtro por apertura, caché por celda | Un edificio con ventanas y puertas que se abren, y un exterior que también es sala |
| Reflectores | `OpenDouReflector3D` como ajuste artístico (Sabine) | Fachadas y muros de hormigón al aire libre |
| Escena de Steam Audio | `OpenDouAcousticGeometryBake` → `IPLScene`, materiales por banda, efecto directo (oclusión volumétrica, transmisión por material, aire, directividad) | Muros gruesos de hormigón, un cristal, distancias largas |
| Reflexiones reales | `reverb_mode = CONVOLUTION`, IR trazada centrada en el oyente, RT60 real | Una nave de metal enorme y una galería de hormigón |
| Envío propio (F15) | La voz vuelve a su `target_bus` dentro de salas: ducking, instantáneas y mezcla por buses alcanzan a todo | Diálogo que hace ducking de la música dentro de una sala |
| Propagación | Sondas + caminos: origen aparente rodeando esquinas **sin portales autorados**, EQ y ganancia del camino | Un túnel en L |
| Geometría dinámica | `AcousticObstacleDynamic` como `IPLInstancedMesh` con umbral | Una compuerta que baja y sube |
| Camas ambisónicas | `OpenDouAmbisonicBed3D` girando con el oyente | Lluvia y viento del valle |
| Emisores geométricos (F15) | Spline (río con flujo → doppler), multiposición (cascada, multitud) | Río, aliviadero |
| Emisor granular | `OpenDouGranularEmitter3D` | Insectos, ranas |
| Física | `OpenDouPhysicsImpact3D` con material y fuerza | Cascotes que caen en la nave |
| Diálogo | `OpenDouDialogueEmitter3D`: idioma, subtítulos, ducking | Un vigilante que avisa |
| Áreas | `OpenDouParameterArea3D` (RTPC por posición, disparadores, instantáneas) | Profundidad del agua, zona de saludo |
| Volúmenes de entorno (F10) | `OpenDouAcousticVolume3D`: medio (subacuático), viento, ocluidor parcial (niebla, follaje), descarte, superficie | Galería inundada, valle ventoso, bosque de ribera |
| Oyente (F10) | `OpenDouListener3D`: radio de cabeza, HRTF, salida | El jugador |
| Accesibilidad (F10) | `OpenDouSoundIndicator` (anillo), `OpenDouAudibleMonitor` | HUD |
| IA (F10) | `OpenDouAIHearing3D`: `sound_heard` por umbral con oclusión | Vigilantes que oyen las pisadas |
| Emisor completo (F9) | Doppler, retardo por distancia, campo cercano, spread, directividad, curva | Un camión en ronda, un trueno lejano, un altavoz de megafonía |
| Altavoz de mundo (F11) | `source = BUS_CAPTURE`: lo que suena en un bus sale por un objeto | Megafonía de la presa (107 ms medidos) |
| Música adaptativa | `OpenDouMusicPlayer` con intensidad, stingers | Tormenta que sube la intensidad |
| Mezcla | HDR, LUFS, instantáneas, ducking, buses por categoría | Todo lo anterior junto |
| Depuración | `OpenDouAcousticDebugger3D` con caminos reales | F9 |

### 1.2 Lo que las demos existentes ya cubren y lo que no

Quilla (salas/portal/reflector/área/bake), Monzón (200 emisores, granular, spline, multiposición,
monitor), Cabina (música, radio), Calle (grafo con cuatro salas, seis portales, bake con cientos
de triángulos), Taller (física, diálogo, altavoz, motor). **Ninguna** instancia los cuatro nodos
de la Fase 10 (oyente, volumen, indicador, oído), ninguna usa `CONVOLUTION`, sondas, ocluidores
dinámicos ni camas ambisónicas, y ninguna junta agua, interior y exterior a escala.

### 1.3 Criterios para elegir el lugar

1. **Agua de tres formas**: corriente (spline con flujo), caída (multiposición), inmersión
   (volumen con medio). 2. **Interiores contrastados**: metal enorme (RT60 largo) y hormigón
   estrecho (galería); un cristal entre dos salas (transmisión por material). 3. **Un túnel con
   codo** sin portal: solo las sondas lo resuelven. 4. **Algo que se abre y cierra** y es
   geometría, no portal: una compuerta. 5. **Distancias largas** para el retardo (un trueno a
   340 m tarda un segundo). 6. **Vehículo en movimiento** (doppler). 7. **Vida**: patrullas,
   animales, un ciclo de tormenta, megafonía con programa, cascotes que caen. 8. **Un lazo de
   juego audible**: los vigilantes oyen tus pisadas según la superficie y la geometría.

Tres candidatos: un puerto de noche (bar con música, grúas, sirenas), una estación de montaña
(tren, túnel, valle) y **una presa hidroeléctrica en un valle**. La presa gana: es el único que
trae de forma natural los tres estados del agua, una nave de máquinas, un túnel de servicio, una
compuerta, una carretera de servicio para el camión, una megafonía, tormentas, y fauna de ribera
(ranas, grillos, pájaros); y el sintetizador ya tiene agua, lluvia, trueno, ranas, cigarras,
gotas, motor, zumbido de máquinas y música.

## 2. La escena: «La presa»

Un valle de unos 140 × 90 m al anochecer, con la presa cortando el valle. El jugador empieza en
el mirador del muro. El plugin se demuestra caminando: cada zona tiene una **tesis medible**.

### 2.1 Zonas y tesis

| # | Zona | Qué hay | Tesis (lo que se afirma) |
|---|---|---|---|
| Z1 | **Coronación del muro** | Mirador, megafonía (bocina con directividad), viento del valle (cama ambisónica + volumen de viento), el río abajo | La bocina se oye de frente y cae al ponerse detrás; el viento gira con la cabeza |
| Z2 | **Nave de turbinas** (Metal, 36 × 14 × 18 m, `CONVOLUTION`) | Dos turbinas (zumbido + capa por RTPC de carga), cascotes que caen desde una pasarela (física), vigilante que patrulla y avisa | La cola del zumbido es larga y real (RT60 trazado > 1 s); la voz del vigilante hace ducking de la música **dentro** de la sala (envío propio); los cascotes suenan a Metal o Concrete según dónde caen |
| Z3 | **Sala de control** (Glass hacia la nave) | Ventana de cristal fija (geometría, no portal), radio de la sala (fuente del altavoz de megafonía), música | Desde la sala de control, la nave se oye a través del cristal con más agudos que a través del hormigón de la pared contigua |
| Z4 | **Galería de servicio en L** (Concrete, sin portal) | Túnel de 3 × 2.5 m con codo de 90°, goteo al fondo | Con el goteo tras el codo, el origen aparente apunta al codo y no atraviesa el hormigón (sondas + caminos) |
| Z5 | **Compuerta del aliviadero** | Compuerta metálica que baja/sube con la tecla G (`AcousticObstacleDynamic`), aliviadero rugiendo detrás (multiposición) | Cerrada, el aliviadero cae ≥ 8 dB en agudos sin rehacer el bake |
| Z6 | **Galería inundada** | Volumen `AcousticVolume3D` con medio (agua: c = 1480 m/s, paso-bajo 600 Hz, instantánea `Underwater`), `WaterDepth` RTPC por profundidad | Al sumergirse, la banda alta de todo baja (medida en Master) y el tono del zumbido cambia |
| Z7 | **Río y ribera** | Río (spline con flujo 2 m/s), ranas y grillos (granular), pájaros (eventos aleatorios), bosque de ribera (volumen ocluidor parcial) | El río sigue al oyente a lo largo de la orilla; con flujo hacia el oyente el tono sube (doppler de la voz) |
| Z8 | **Carretera de servicio** | Camión en ronda (motor `BlendContainer` por RPM, doppler, retardo) | Se acerca: tono sube; se aleja: baja |
| Z9 | **Tormenta** | Ciclo de 90 s: calma → nubes → tormenta (rayos con trueno a 300–400 m con retardo por distancia, lluvia como cama, música que sube de intensidad) → calma | El trueno llega ≥ 0.85 s después del rayo; la música sube de intensidad con la tormenta |
| Z10 | **Vigilancia** | Dos vigilantes con `OpenDouAIHearing3D` (umbral −30 dB) en ronda; pisadas del jugador por superficie (Metal en pasarelas, Concrete, Stone, Water, Foliage) | Un vigilante te oye a 6 m sobre metal y no a 25 m tras un muro |
| HUD | Cartel, monitor audible, **indicador de sonidos** (anillo), depurador con caminos (F9) | El indicador lista lo que suena |

### 2.2 Nodos (todos los del plugin salvo el 2D)

`OpenDouListener3D` (hijo del jugador, radio de cabeza 0.09), `OpenDouRoom3D` ×5 (Nave
`CONVOLUTION`/Metal, Control/Glass, Galería/Concrete, Inundada/Water, Valle/Outdoor),
`OpenDouPortal3D` ×4 (puerta nave–control, puerta nave–galería, boca galería–valle, escotilla
inundada), `OpenDouReflector3D` ×3 (muro de la presa, dos laderas), `OpenDouAcousticGeometryBake`
(con `probe_spacing_m = 2`, `probes_path` junto a la escena, `dynamic_group`),
`OpenDouAcousticDebugger3D` (`show_paths`), `OpenDouEventPlayer3D` (turbinas ×2, bocina de
megafonía con `source = BUS_CAPTURE`, goteo, pájaros, trueno, camión), `OpenDouEventPlayer`
(radio de la sala de control, fuente del altavoz), `OpenDouMusicPlayer`, `OpenDouAmbisonicBed3D`
×2 (viento, lluvia), `OpenDouSplineEmitter3D` (río), `OpenDouMultiPositionEmitter3D`
(aliviadero), `OpenDouGranularEmitter3D` ×2 (ranas, grillos), `OpenDouPhysicsImpact3D` ×3
(cascotes), `OpenDouDialogueEmitter3D` ×2 (vigilantes), `OpenDouParameterArea3D` ×3
(`WaterDepth`, zona de aviso del vigilante, `StormIntensity`), `OpenDouAcousticVolume3D` ×3
(agua, viento del valle, bosque ocluidor), `OpenDouAIHearing3D` ×2, `OpenDouSoundIndicator`,
`OpenDouAudibleMonitor`, `OpenDouAnimationSync` (en cada rig). Geometría: `StaticBody3D` con
`MeshInstance3D` en `AcousticObstacle` y metadata `acoustic_material`/`surface_type`; la
compuerta en `AcousticObstacleDynamic`. **≥ 300 nodos declarados.**

### 2.3 Vida (lo dinámico, en el script de la escena)

- **Ciclo de tormenta** (máquina de estados por tiempo, 90 s, acelerable con T): controla lluvia
  (cama), rayos (evento `Thunder` en posiciones aleatorias a 300–400 m con `propagation_delay`),
  RTPC `StormIntensity` → música (`set_combat_intensity`) y ranas/grillos (menos con lluvia).
- **Camión**: `Path3D` de ronda; posición y RPM por velocidad; doppler y retardo activos.
- **Vigilantes**: `NpcController` con waypoints; su `OpenDouAIHearing3D` conecta `sound_heard` →
  si el evento es `Footstep` del jugador, gira hacia él y dice una frase (ducking sobre `Music`).
- **Cascotes**: cada 12 s se suelta un cascote de la pasarela (freeze = false).
- **Compuerta**: tecla G anima la altura (Tween 2 s); el bake la sigue como ocluidor dinámico.
- **Megafonía**: la radio de control alterna música y avisos (eventos) cada 30 s; el altavoz de
  la coronación los reproduce por `BUS_CAPTURE`.
- **Teclas**: T (avanzar tormenta), G (compuerta), E (puerta más cercana), F9 (depurador),
  F8 (monitor), F1 (cartel), Esc (pausa).

### 2.4 Buses

`Music`, `SFX`, `Voice`, `Ambience`, `Radio` (fuente del altavoz, a −80), `Turbines`, `Water`,
`Wildlife`, `Vehicle`. El presupuesto de sonoridad de la escena entra en `loudness_budget.txt`
con su primera medida ±6 LU.

## 3. Composición

La escena se **declara** en `scenes/demos/presa/presa_demo.tscn` (regla 04). Por su tamaño, el
`.tscn` se genera **una vez** con `tools/gen_presa_tscn.py` (documentado en cabecera: escribe el
archivo y no vuelve a intervenir; el `.tscn` es la fuente de verdad y se edita en el editor).
Los `AudioStream` se sintetizan en `presa_demo.gd` (la excepción legítima). Las sondas se
precocinan con `tools/bake_presa_probes.gd` (headless) y el `.probes` se versiona.

## 4. Tests (`tests/test_demo_scenes.gd::run_presa_async`, y guardas)

Solo lo medible, con controles, en el orden de las zonas: Z2 (RT60 trazado > 1 s, el zumbido
llega a su bus `Turbines` dentro de la nave, la voz del vigilante duckea `Music` ≥ 6 dB), Z3
(agudos a través del cristal ≥ 6 dB sobre el hormigón: dos posiciones del oyente), Z4 (camino
válido y origen aparente a < 25° del codo), Z5 (compuerta cerrada: banda alta del aliviadero
cae ≥ 8 dB), Z6 (con el oyente sumergido, la banda 2–8 kHz de Master cae ≥ 10 dB frente a fuera),
Z7 (el emisor del río sigue al oyente; `doppler_pitch` > 1.01 con flujo a favor), Z8 (camión:
`doppler_pitch` > 1.02 acercándose y < 0.98 alejándose), Z9 (trueno: onset ≥ 0.85 s tras el
rayo a 343 m; intensidad musical sube), Z10 (`sound_heard` a 6 m sobre metal, no a 25 m tras el
muro), HUD (`get_indicators().size() ≥ 1`), altavoz (voz activa, `Radio` a −80), composición
(≥ 300 nodos, todos los scripts requeridos), LUFS dentro del presupuesto, sin instancias huérfanas
al liberar. `EXPECTED_UNCOVERED` queda en `opendou_event_player_2d.gd`.

## 5. Riesgos

Tiempo de la suite (+15–25 s): la demo se prueba con el ciclo de tormenta acelerado y menos
cascotes. Sondas: bake de ~140 × 90 m a 2 m ≈ 3000 sondas → el bake de caminos puede tardar
segundos; se limita `probe_bounds` a la galería y la nave (donde hacen falta) y se guarda en el
`.probes`. Voces: ~45 emisores con presupuesto 32; los animales van con prioridad baja.

## 6–11. (Reservados: no aplican.)

## 12. Correcciones que la ejecución obligue a hacer

Se anotan aquí, numeradas.
