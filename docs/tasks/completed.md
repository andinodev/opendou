# ✅ Historial de Tareas Completadas

Este archivo registra todas las tareas terminadas, verificadas y entregadas en el proyecto.

---

## 📑 Registro Histórico

* **`TASK-057` - Sincronización de Audio por Animación (Fase 3)**
  * **Fecha:** 2026-08-31
  * **Resumen:**
    * **Nodo Declarativo `OpenDouAnimationSync` (`addons/opendou/nodes/opendou_animation_sync.gd`):**
      * Puente declarativo entre el subsistema de animación de Godot (`AnimationPlayer`, `AnimationTree`) y el motor de audio OpenDou.
      * Soporte directo para pistas de métodos de animación (`play_audio_event`, `footstep`, `set_rtpc`).
      * Sincronización declarativa basada en marcas de tiempo (`event_bindings` por animación y segundos/frames).
      * Disparo de pasos (`footstep`) con detección contextual automática de superficies mediante `SpatialAcousticsManager.detect_surface_at()` y overrides de material.
      * Extracción y modulación en tiempo real de BlendSpaces 1D/2D de `AnimationTree` hacia parámetros RTPC de OpenDou (`blend_space_rtpc_map`).
      * Enrutamiento flexible a emisores de escena (`OpenDouEventPlayer3D` / `2D` / `OpenDouEventPlayer`) o despacho global a través de `AudioEventManager`.
      * Icono SVG `addons/opendou/icons/icon_animation_sync.svg` y registro en `addons/opendou/plugin.gd`.
    * **Verificación y Pruebas:**
      * Creada suite `tests/test_animation_sync.gd` (+10 tests) verificando instanciación, callbacks directos de métodos, detección de superficies, modulación de RTPCs, vinculación con `AnimationPlayer`/`AnimationTree` y robustez ante desvinculación o nodos destruidos.
      * Total de la suite OpenDou alcanzando **326 pruebas** con **100% de éxito (0 fallos)** en `godot --headless`.
  * **Fecha:** 2026-08-31
  * **Resumen:**
    * **Nodo Declarativo `OpenDouAcousticGeometryBake` (`addons/opendou/nodes/opendou_acoustic_geometry_bake.gd`):**
      * Pre-procesador de geometría estática para oclusión y difracción acústica sin sobrecargar el motor de físicas (`PhysicsRayQueryParameters3D`).
      * Escaneo recursivo por jerarquía de hijos y por grupos de escena (`target_group`, ej. `AcousticObstacle`).
      * Simplificación poligonal por paso de caras (`simplification_step`), cálculo de normales, centros de triángulos y asignación de materiales desde `AcousticMaterialRegistry`.
      * Motor de intersección de rayos en CPU por algoritmo de Möller–Trumbore con evaluación ultra-rápida de oclusión y distancias.
      * Icono SVG `addons/opendou/icons/icon_acoustic_bake.svg` y registro en `addons/opendou/plugin.gd`.
    * **Plugin de Inspector `OpenDouAcousticGeometryBakeInspectorPlugin` (`addons/opendou/editor/opendou_acoustic_geometry_bake_inspector.gd`):**
      * Interfaz de usuario inyectada en el Inspector de Godot con botones interactivos `⚡ Bake Geometry` y `🗑️ Clear`.
      * Panel con telemetría en tiempo real de mallas escaneadas, número de triángulos acústicos horneados y volumen geométrico $m^3$.
    * **Plugin de Gizmos 3D de Viewport `OpenDouGizmoPlugin3D` (`addons/opendou/editor/gizmos/opendou_gizmo_plugin_3d.gd`):**
      * Renderizado 3D de wireframes y vectores de audio en el Viewport del editor de Godot para los 8 nodos espaciales:
        * `OpenDouRoom3D`: Volumen 3D y prismas coloreados por material acústico.
        * `OpenDouPortal3D`: Marco de apertura rectangular y vector normal con arco de *Sound Spread*.
        * `OpenDouReflector3D`: Plano reflector 3D con vectores de rebote especular.
        * `OpenDouSplineEmitter3D`: Trazo de curva spline continuo y punto de proyección del oyente.
        * `OpenDouGranularEmitter3D`: Esferas de radio de emisión y volumen de dispersión de micro-granos.
        * `OpenDouParameterArea3D`: Gradiente radial/cilíndrico y vector de dirección de gradiente de eje.
        * `OpenDouMultiPositionEmitter3D`: Constelación de líneas y cruces de vértices de emisión.
        * `OpenDouAcousticGeometryBake`: Wireframe 3D de triángulos y AABBs acústicos horneados.
    * **Verificación y Pruebas:**
      * Creada suite `tests/test_acoustic_geometry_bake.gd` (+10 tests) verificando extracción de mallas, diezmado, normales, raycasts Möller-Trumbore (hit/miss), limpieza de datos y detección estática en plugins.
      * Total de la suite OpenDou incrementado a **316 pruebas** con **100% de éxito (0 fallos)** en `godot --headless`.
  * **Fecha:** 2026-08-31
  * **Resumen:**
    * **Nodo Declarativo `OpenDouParameterArea3D` (`addons/opendou/nodes/opendou_parameter_area_3d.gd`):**
      * Volumen de modulación dinámica para parámetros de juego RTPC, snapshots globales de mezcla y envíos auxiliares.
      * Modos de penetración matemática: Radial Esférica, Cilíndrica 2D (`ignore_y_axis = true`), Gradiente por Eje Arbitrario y Disparador Binario.
      * Resolución robusta de solapamiento de áreas: Operaciones de mezcla `MAX`, `ADD` (clamped) y `REPLACE` por prioridad (`rtpc_priority`).
      * Integración de snapshots globales de mezcla (`target_snapshot`) con empuje y pop automático al entrar/salir del volumen.
      * Prevención de jitter en límites de colisión con histéresis temporal (`edge_hysteresis_ms = 150.0`).
      * Manejo seguro de ciclo de vida (`tree_exited`) para liberar parámetros y snapshots si un nodo es destruido dentro del volumen.
      * Icono SVG `addons/opendou/icons/icon_parameter_area_3d.svg` y registro en `addons/opendou/plugin.gd`.
    * **Nodo Declarativo `OpenDouMultiPositionEmitter3D` (`addons/opendou/nodes/opendou_multi_position_emitter_3d.gd`):**
      * Emisor para objetos acústicos masivos o distribuidos (ríos, cascadas, tuberías, vallas perimetrales).
      * Modos de renderizado espacial: Tracking al vértice más cercano (`CLOSEST_POINT_TRACKING`) y centroid blended ponderado (`MULTI_POINT_BLENDED`).
      * Supresión determinista de filtro de peine (*comb filtering*) mediante micro-desfases acústicos $\Delta t_i \in [0.1, 2.5]\text{ ms}$ por vértice.
      * Transición continua a envolvente 2D difuso (`spread = 180^\circ`) al penetrar en el volumen AABB de emisión (`envelopment_on_inside`).
      * Oclusión discreta con origen de raycast trazado desde el vértice activo hacia el oyente (no desde el centroide del nodo).
      * API pública dinámica para vértices: `add_emission_point`, `remove_emission_point`, `clear_emission_points`, `set_emission_points` y extracción automática desde geometrías `MeshInstance3D` (`update_points_from_mesh`).
      * Icono SVG `addons/opendou/icons/icon_multi_position_emitter_3d.svg` y registro en `addons/opendou/plugin.gd`.
    * **Verificación y Pruebas:**
      * Creadas suites `tests/test_parameter_area_3d.gd` (10 tests) y `tests/test_multi_position_emitter_3d.gd` (8 tests).
      * Total de la suite OpenDou incrementado a **306 pruebas** con **100% de éxito (0 fallos)** en `godot --headless`.
  * **Fecha:** 2026-08-31
  * **Resumen:**
    * **Nodo Declarativo `OpenDouGranularEmitter3D` (`addons/opendou/nodes/opendou_granular_emitter_3d.gd`):**
      * Generador 3D espacial de micro-granos asíncronos en tiempo real con ventana de Hanning, jitter de posición y modulación estocástica de tono.
      * Registrado en `plugin.gd` con icono SVG `icon_granular_emitter.svg`.
    * **Convolución Acústica por Respuesta de Impulso (IR) en `OpenDouRoom3D`:**
      * Soporte de modos `ReverbMode.ALGORITHMIC`, `ReverbMode.CONVOLUTION_IR` y `HYBRID` con kernel FIR de 512 taps en `addons/opendou/core/dsp/convolution_reverb_node.gd`.
      * Alternancia en caliente A/B y crossfade suave de 50 ms.
    * **Empaquetador y Runtime de SoundBanks Monolíticos (`SoundBankBuilder` / `tactical_canyon.bnk`):**
      * Serializador binario `addons/opendou/runtime/soundbank_builder.gd` (`ODBK` v1).
      * Acceso a tabla de Prefetch RAM (latencia 0 ms) y streaming directo a disco por chunks (`BankStreamPlayback`).
      * Telemetría de memoria RAM y descriptores de archivo en `SoundBankManager.get_bank_telemetry()`.
    * **Integración y PBR en Demo 08 (Tactical Canyon):**
      * Emisor granular en Sector 1 (`CliffsideGranularEmitter`), búnker con convolución IR en Sector 2, streaming binario en Sector 5.
      * Materiales PBR `StandardMaterial3D` dedicados para cañón, grava, hormigón, acero balístico y rejillas industriales.
      * Controles tácticos en HUD y atajos de teclado (`C` para convolución A/B, `V` para modo granular, `B` para telemetría SoundBank).
    * **Verificación:**
      * Nuevas suites: `tests/test_granular_emitter_3d.gd`, `tests/test_room_convolution.gd`, `tests/test_soundbank_packaging_and_streaming.gd` e integración en `tests/test_tactical_canyon_demo.gd`.
      * 288 pruebas ejecutadas y pasando al 100% de los nuevos componentes con `godot.cmd` (código de salida 0).

* **`TASK-053` - AAA Spatial Acoustics Phase 3: Tactical Canyon Showcase Demo (`demo_tactical_canyon.tscn`)**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Escena Demo Showcase Táctica 3D Declarativa (`scenes/demos/08_tactical_canyon/demo_tactical_canyon.tscn`):**
      * **Sector 1 (River Gorge):** Emisor continuo volumétrico a lo largo de un `Curve3D` con [`OpenDouSplineEmitter3D`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/nodes/opendou_spline_emitter_3d.gd) proyectando el flujo de agua al punto más cercano al oyente en tiempo real.
      * **Sector 2 (Bunker & Portal Airlock):** Búnker de hormigón reforzado conectado por [`OpenDouPortal3D`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/nodes/opendou_portal_3d.gd) interactivo; apertura/cierre de compuerta modula el acoplamiento de reverberación RT60 y el *Sound Spread* angular ($15^\circ \to 180^\circ$).
      * **Sector 3 (Material Mass-Law Lab):** Laboratorio de pruebas acústicas con 4 particiones físicas (`Concrete`, `Metal`, `Wood`, `Foliage`) demostrando las pérdidas de transmisión espectral ($\text{TL}_{\text{dB}}$) y filtrado de frecuencias paso-bajo.
      * **Sector 4 (Drone Patrol Range):** Dron de combate orbitando a alta velocidad ($25\text{ m/s}$) demostrando el desplazamiento de tono por efecto Doppler cinemático ($[0.5, 2.0]$) y la transición continua entre los 4 niveles de LOD acústico (LOD 0 a LOD 3).
      * **Sector 5 (HDR Firing Range):** Detonaciones explosivas de alta energía (+3 dB FS) que elevan dinámicamente el piso de la ventana HDR y comprimen (*ducking*) el ambiente del cañón con decaimiento natural.
      * **Visualización Acústica & Monitor:** Integración de [`OpenDouAcousticDebugger3D`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/nodes/opendou_acoustic_debugger_3d.gd) (rayos de difracción y burbujas iso-acústicas) y [`OpenDouAudibleMonitor`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/addons/opendou/nodes/opendou_audible_monitor.gd).
    * **Integración en Hub:** Registro interactivo de Demo 8 en [`scenes/demos/demo_hub.gd`](file:///c:/Users/Danielillo/projects/godot%20plugins/opendou/scenes/demos/demo_hub.gd).
    * **Verificación:**
      * Suite `tests/test_tactical_canyon_demo.gd` con 8 pruebas de integración.
      * 270 pruebas unitarias y de integración pasando al 100% con `godot.cmd` (código de salida 0, 0 fallos).

* **`TASK-052` - AAA Spatial Acoustics Phase 2: Early Reflections 6x, Edge Diffraction, Room Coupling, Acoustic LOD & HDR Audio**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Trazador 6x de Reflexiones Tempranas (`AcousticReflectorEngine`):**
      * Raytracing ortogonal en 6 ejes ($\pm X, \pm Y, \pm Z$) para calcular retardos físicos de eco ($t_i = (d_1+d_2)/c$), fuentes espejo virtuales ($E' = E - 2(\vec{n}\cdot\vec{v})\vec{n}$) y absorción espectral de materiales (`Metal`, `Concrete`, `Wood`, `Foliage`).
    * **Difracción en Bordes y Esquinas Huygens-Fresnel (`EdgeDiffractionEngine`):**
      * Búsqueda de aristas silueta perimetrales de obstáculos, cálculo de ángulo de sombra acústica $\theta \in [0, \pi]$ y curvatura espectral paso-bajo ($f(\theta) = 20000 \cdot \cos^2(\theta/2)$) con atenuación suave de ganancia.
    * **Acoplamiento de Reverberación Inter-Habitaciones (`RoomCouplingEngine`):**
      * Transmisión de colas de decaimiento RT60 entre volúmenes arquitectónicos conectados por portales según el área de apertura, y apertura angular (*Sound Spread*) dinámica ($15^\circ \to 180^\circ$) según la proximidad del oyente.
    * **Gobernador de Rendimiento Acústico en 4 Niveles (`AcousticLODController`):**
      * Culling y escalabilidad de CPU para consolas y móviles: LOD 0 ($0-10\text{m}$, física completa), LOD 1 ($10-25\text{m}$, oclusión simple), LOD 2 ($25-50\text{m}$, paneo 3D estándar), LOD 3 ($>50\text{m}$, virtualización total).
    * **Ventana de Rango Dinámico HDR (`HDRAudioManager`):**
      * Seguimiento en tiempo real de niveles pico dB FS, elevación de piso dinámico ante transientes de alta energía (explosiones/disparos) y compresión/ducking suave del fondo ambiental con recuperación exponencial configurable.
    * **Verificación:**
      * Suite `tests/test_spatial_acoustics_phase2.gd` con 10 pruebas unitarias y de integración.
      * 262 pruebas pasando al 100% con `godot.cmd` (código de salida 0, 0 fallos).

* **`TASK-051` - AAA Spatial Acoustics Phase 1: Physical Propagation, Material Mass Law, Obstruction/Occlusion & Volumetric Splines**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Matriz de Materiales Físicos y Atenuación por Ley de Masas (`AcousticMaterialRegistry`):**
      * Registro canónico físico inmutable para 8 materiales estándar: `Concrete` ($2400\text{ kg/m}^3, 350\text{ Hz}$), `Stone` ($2400\text{ kg/m}^3, 350\text{ Hz}$), `Metal` ($7800\text{ kg/m}^3, 1200\text{ Hz}$), `Glass` ($2500\text{ kg/m}^3, 800\text{ Hz}$), `Wood` ($700\text{ kg/m}^3, 2000\text{ Hz}$), `Foliage` ($150\text{ kg/m}^3, 4500\text{ Hz}$), `Water` ($1000\text{ kg/m}^3, 600\text{ Hz}$), `Asphalt` ($2100\text{ kg/m}^3, 400\text{ Hz}$).
      * Cálculo determinista de pérdidas de transmisión: $\text{TL}_{\text{dB}} = 20 \cdot \log_{10}(1.0 + \frac{\rho}{500} \cdot \Delta x \cdot \sqrt{\frac{f}{1000}})$, interpolación del corte LPF y soporte de sobreescrituras en `opendou_acoustic_materials.json`.
    * **Separación de Obstrucción vs. Oclusión (`SpatialAcousticsManager` / `evaluate_acoustic_path`):**
      * Obstrucción (misma sala): Bloqueo parcial en línea de visión directa aplica LPF solo a la señal directa manteniendo el envío de reverberación al 100% (`reverb_send_factor = 1.0`).
      * Oclusión (entre salas / muros): Atenuación por ley de masas aplicada tanto a la señal directa como a los envíos de reverberación (`reverb_send_factor < 1.0`).
      * Amortiguación atmosférica por distancia: $f_{\text{cutoff}} = \text{clamp}(20000 \cdot e^{-0.015 \cdot d}, 800, 20000)$.
      * Efecto Doppler cinemático estabilizado: $f' = f \cdot \frac{c - \vec{v}_l \cdot \hat{u}}{c - \vec{v}_e \cdot \hat{u}}$, acotado de forma segura entre $[0.5, 2.0]$.
    * **Emisor Volumétrico 3D por Splines (`OpenDouSplineEmitter3D`):**
      * Proyección acústica continua a lo largo de un `Curve3D` proyectando la posición virtual en el punto más cercano al oyente en tiempo real.
      * Culling de distancia al cuadrado ($d > \text{max\_virtual\_distance} + 10\text{m}$) para omitir cálculo de splines fuera de rango.
      * Icono SVG personalizado `icon_spline_emitter_3d.svg` y registro en `plugin.gd`.
    * **Verificación:**
      * Suite `tests/test_spatial_acoustics_phase1.gd` con 8 pruebas exhaustivas.
      * 252 pruebas unitarias y de integración pasando al 100% con `godot.cmd` (código de salida 0, 0 fallos).

* **`TASK-050 (Task 2)` - Rediseño del Diálogo Add Track en Music DAW Timeline con Navegador de Sintetizadores, Audición y Auto-relleno Predictivo**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Diseño del Modal Add Track en 3 Tarjetas (`opendou_music_timeline.gd`):**
      * Tamaño base expandido a 800x550px con arquitectura visual de 3 tarjetas (*Track Identity*, *Audio Source Engine*, *Dynamic Automation & Routing*).
      * Selector segmentado de fuente de audio entre Sintetizador Procedural (`btn_toggle_source_synth`) y Archivo de Audio (`btn_toggle_source_file`).
      * Navegador de sintes con filtrado dinámico por categoría (`All`, `Pads`, `Leads`, `Bass`, `Percussion`, `Nature/Ambience`, `SFX`) y búsqueda reactiva en tiempo real.
      * Tarjeta de previsualización con etiquetas de metadatos, controles de audición (`Play`/`Stop`), visor de forma de onda proxy debounced a 150ms y auto-relleno predictivo de color, bus y rango de intensidad.
      * Activación por doble click o [Enter] para creación instantánea y asignación del `synth_preset` en `OpenDouTrackLaneData`.
    * **Persistencia y Reproducción:**
      * Serialización y deserialización completa de `synth_preset` en formato JSON (`save_to_disk` y `load_from_disk`).
      * Integración de `SynthPresetRegistry` en `_assign_default_or_file_stream` y en variaciones aleatorias (`_pick_random_variations_on_loop`).
    * **Suite de Pruebas Automatizadas:**
      * Test 12 en `tests/test_studio_advanced_ui.gd` cubriendo dimensionamiento, conmutación de fuentes, filtrado, auto-relleno predictivo, audición, debouncing y creación por doble click.
      * 244 pruebas unitarias y de integración pasando al 100% (código de salida 0, 0 fallos).

* **`TASK-049` - 3D Volumetric Acoustic Iso-Bubble & Multi-Selection Debugger (Depurador Volumétrico 3D de Burbujas Acústicas Iso-Superficie y Selección Múltiple)**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Algoritmo de Burbuja Geodésica 3D (`calculate_spherical_bubble_mesh` en `opendou_acoustic_debugger_3d.gd`):**
      * Generación procedural de distribución esférica de vectores sonda de rayos 3D (`generate_sphere_probe_directions`) con muestreo de polos norte/sur y anillos de latitud y longitud (`sphere_rings`, `sphere_segments`).
      * Trazado de rayos físicos contra `PhysicsDirectSpaceState3D` adaptando la superficie 3D de la malla (`ImmediateMesh`) a la geometría y obstáculos colindantes en tiempo real.
      * Coloración de vértices adaptativa por punto de colisión (Cian para propagación libre sin impedimento, Naranja/Rojo con colisión de pared o geometría ocluida).
      * Generación de índices triangulares cerrada e indexada para renderizado continuo y eficiente.
    * **Soporte de Modos de Visualización y Selección Múltiple (`display_mode`):**
      * `DisplayMode.ONLY_SELECTED` (0): Muestra la burbuja 3D enfocada en emisores seleccionados (`selected_emitters`), selección activa en el árbol de escenas del editor (`EditorInterface.get_selection()`) o el emisor activo más próximo al oyente en tiempo de ejecución.
      * `DisplayMode.ACTIVE_AUDIBLE_ONLY` (1): Renderiza las burbujas 3D de todos los emisores activos que se encuentren reproduciendo audio audible.
      * `DisplayMode.ALL_EMITTERS` (2): Renderiza todos los emisores presentes en la escena.
    * **Integración de Ciclo de 3 Estados en Cyberpunk Demo (`demo_cyberpunk_infiltration.gd` y `.tscn`):**
      * Conmutación cíclica al presionar botón o tecla `[G]`: `OFF` ➔ `Focused (3D Iso-Bubble)` ➔ `All Active (3D)` ➔ `OFF`.
      * Actualización reactiva del texto del botón táctico: `"👁️ 3D Bubble: OFF (G)"`, `"👁️ 3D Bubble: FOCUSED (G)"`, `"👁️ 3D Bubble: ALL ACTIVE (G)"`.
      * Actualización de la etiqueta HUD `LblSoundField`: `"Sound Field: Focused (3D Iso-Bubble)"`, `"Sound Field: All Active (3D)"`, `"Sound Field: OFF"`.
    * **Suite de Pruebas Automatizadas:**
      * Tests unitarios en `test_acoustic_debugger.gd` y Test 27 en `tests/test_cyberpunk_demo.gd` verificando la generación esférica geodésica, el mallado iso-superficial 3D, el filtrado de emisores seleccionados/activos y el ciclo de 3 estados del HUD.
      * 240 pruebas unitarias y de integración pasando al 100% (código de salida 0, 0 fallos).

* **`TASK-048` - Depurador Volumétrico de Campos Acústicos 3D en Tiempo Real (OpenDou Acoustic Sound Field Debugger 3D)**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Shader Visualizador Volumétrico (`acoustic_sound_field.gdshader`):**
      * Shader 3D translucido sin sombreado (`unshaded`, `cull_disabled`, `blend_mix`, `depth_draw_opaque`).
      * Gradiente radial procedural con efecto sonar pulsante en tiempo real (`sin(TIME * 2.5)`), borde de atenuación Fresnel y coloración adaptativa (Cyan para propagación directa despejada, Naranja/Rojo para colisiones u oclusiones).
    * **Nodo Declarativo `OpenDouAcousticDebugger3D` (`opendou_acoustic_debugger_3d.gd`):**
      * Nodo 3D de depuración volumétrica en tiempo real registrado en el editor con icono SVG nativo (`icon_acoustic_debugger.svg`).
      * Muestreo radial configurativo (*starburst probing*) de 8 a 64 rayos (`probe_ray_count`, por defecto 24) para proyectar y adaptar la malla volumétrica del campo acústico (`ImmediateMesh`) contra la geometría circundante.
      * Renderizado de anillo de radio crítico de proximidad 0 dB (`unit_size`) en alambre dorado.
      * Trazado dinámico de rayos directos emisor-oyente con evaluación de oclusión multirrayo (Verde = despejado, Amarillo = difractado, Rojo = ocluido totalmente).
      * Función `toggle_debug()` para conmutación inmediata en runtime.
    * **Integración en Showcase AAA Cyberpunk Infiltration (`demo_cyberpunk_infiltration.tscn` y `.gd`):**
      * Instancia declarativa de `AcousticDebugger` bajo `LevelGeometry` configurada con 24 sondas de muestreo acústico.
      * Botón interactivo `BtnToggleAcoustics` (`"👁️ Sound Field: ON (G)"` / `"👁️ Sound Field: OFF (G)"`) en la barra inferior del Tactical HUD.
      * Etiqueta de telemetría `LblSoundField` en el panel de métricas tácticas (`"Sound Field: ON (24 Probes)"`).
      * Atajo de teclado interactivo `[G]` en `_unhandled_input()` para conmutación instantánea.
    * **Suite de Pruebas Automatizadas:**
      * Test 27 en `tests/test_cyberpunk_demo.gd` y suite completa de pruebas unitarias en `test_acoustic_debugger.gd`.
      * 240 pruebas unitarias y de integración pasando al 100% (código de salida 0, 0 fallos).

* **`TASK-047` - Motor de Detección Inteligente de Superficies en 3 Niveles & Integración Demo Cyberpunk (Dynamic Surface & Room Acoustic Harmonization)**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **`detect_surface_at()` en `SpatialAcousticsManager` (3-Tier Hierarchy):**
      * **Prioridad 1 (Physics Raycast):** Lanzamiento de rayo físico hacia abajo desde `pos + (0, 0.5, 0)` hasta `pos + (0, -1.5, 0)` con detección de superficie por metadato `surface_type`, nombre de `physics_material_override` o palabras clave en el nombre del colisionador.
      * **Prioridad 2 (AudioRoom.floor_surface):** Consulta de la sala acústica que contiene la posición mediante `get_room_at_position()` y retorno de su propiedad `floor_surface`.
      * **Prioridad 3 (Fallback):** Retorno del valor predeterminado `&"Concrete"` cuando ningún sistema superior resuelve la superficie.
    * **Salas acústicas en `demo_cyberpunk_infiltration.gd` con `floor_surface` correcto:**
      * `room_rooftop.floor_surface = &"Metal"`, `room_server.floor_surface = &"Tile"`, `room_drainage.floor_surface = &"Water"`, `room_extraction.floor_surface = &"Concrete"`, `room_biosphere.floor_surface = &"Foliage"`.
    * **Delegación en `detect_footstep_surface()` del demo:**
      * Reemplazo de la cadena if/elif posicional por llamada a `spatial_acoustics.detect_surface_at(pos, get_world_3d())`, con la cadena posicional como fallback cuando `spatial_acoustics` es nulo.
    * **Propiedades `floor_surface` en `demo_cyberpunk_infiltration.tscn`:**
      * Configuración declarativa de `floor_surface` en los 5 nodos de sala: `RooftopRoom (&"Metal")`, `ServerRoomArea (&"Metal")`, `DrainageRoom (&"Water")`, `ExtractionArenaRoom (&"Tile")`, `BiosphereRoom (&"Foliage")`.
    * **Suite de Pruebas Automatizadas:**
      * Tests 4a, 5a, 6a en `test_spatial_acoustics.gd` verificando `detect_surface_at()` con sala registrada, punto exterior (fallback Concrete) y world_3d nulo (fallback Concrete).
      * 237 pruebas unitarias e integración pasando al 100% (código de salida 0, 0 fallos).

* **`TASK-046` - OpenDou VST Modular Synth Rack Workstation (Mode 3: Synth Studio)**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Integración del Espacio de Trabajo Modo 3 en OpenDouStudioMain (`opendou_studio_main.gd`):**
      * Registro de `WorkspaceMode.MODE_SYNTH_RACK` (Modo 3) y botón selector de radio `"⚡ Synth"` en la barra de herramientas principal.
      * Instanciación declarativa y gestión de visibilidad de `synth_workspace` (`OpenDouSynthRackWorkspace`) como hijo del contenedor central `center_workspace_box`.
      * Conmutación reactiva y exclusiva entre los 4 modos de estudio (Grafo SFX, Música DAW, Diálogos/Voces y Synth Workstation), colapsando paneles laterales y selectores contextuales irrelevantes para maximizar el espacio útil en pantalla.
      * Soporte de guardado en caliente (`Ctrl+S` / `btn_save`) conectado al flujo de serialización de presets sintéticos (`synth_workspace._on_save_all_pressed()`).
    * **Adaptación Contextual de la Barra de Transporte Inferior (`opendou_transport_bar.gd`):**
      * Insignia reactiva de evento objetivo `"Audition: [⚡ Synth Preset Studio]"`.
      * Faders de precisión contextuales para modulación de octava (`Octave`), desafinación (`Detune`) y ganancia maestra (`Master Gain`).
      * Integración de botones de audición en bucle y disparo directo.
    * **Suite de Pruebas Automatizadas:**
      * Test 11 en `tests/test_studio_advanced_ui.gd` verificando la inicialización, conmutación bidireccional de visibilidad de los 4 espacios de trabajo, actualización contextual de la barra de transporte y 234 pruebas unitarias pasando al 100% (código de salida 0, 0 fallos).

* **`TASK-046-PREV` - Script PowerShell Autónomo de Pruebas, Logging en Tiempo Real y Shim de Godot Steam**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Script de Ejecución Automatizada PowerShell (`run_tests.ps1`):**
      * Detección y resolución automática del ejecutable de Godot Steam (`godot.windows.opt.tools.64.exe`), variables de entorno (`GODOT_PATH`, `GodotSteamPath`, `GODOT_BIN`) y directorios de librerías Steam (`libraryfolders.vdf`).
      * Invocación en modo `--headless --path . -s tests/test_runner_cli.gd` con streaming en vivo a consola y captura en `test_console.log`.
      * Medición precisa de tiempo de ejecución (duración en segundos), timestamps de inicio/fin y retorno estricto de exit code (`0` éxito, `1` fallo).
    * **Generación y Verificación de `test_results.log`:**
      * Estandarización de `tests/test_runner_cli.gd` para escribir el resumen de pruebas en `res://test_results.log`, `user://test_results.log` y ruta globalizada de proyecto con flush inmediato.
      * Doble comprobación y validación parseada (`STATUS`, `TOTAL`, `PASSED`, `FAILURES`) en el script de PowerShell con reporte visual en verde/rojo.
    * **Shim de Comando para Windows (`godot.cmd`):**
      * Wrapper por lotes en la raíz del repositorio para invocar comandos directos de Godot contra la instalación de Steam sin depender de `$PROFILE`.
    * **Actualización de Directrices y Workflow (`AGENTS.md`, `03_workflow.md`):**
      * Estandarización de `powershell -ExecutionPolicy Bypass -File .\run_tests.ps1` como el comando mandatorio de verificación.
    * **Suite de Pruebas Automatizadas:** 224 pruebas unitarias y de integración pasando al 100% (código de salida 0, 0 fallos).

* **`TASK-045` - Integración de Motor de Síntesis Modular Procedimental & Preset Studio en Nodos Declarativos y Showcase AAA**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Integración Dinámica de Presets Sintéticos en Nodos Declarativos (`OpenDouEventPlayer3D`, `OpenDouEventPlayer2D`, `OpenDouEventPlayer`):**
      * Sustitución de enumeraciones estáticas por exportación dinámica de propiedades mediante `_get_property_list()`, consultando en caliente `SynthPresetRegistry` para poblar el Inspector de Godot con todos los presets nativos y de usuario registrados en `opendou_synth_presets.json`.
      * Pipeline de síntesis procedural desacoplado: `_apply_synth_preset()` consulta prioritariamente `SynthPresetRegistry.get_singleton().get_preset_stream()` para hornear flujos `AudioStreamWAV` multicapa mediante `ModularSynthEngine`, con fallback elegante a la síntesis algorítmica de `AudioSynthesizer`.
      * Auto-inferencia reactiva de presets (`_auto_infer_synth_preset`): resolución por coincidencia de subcadena sobre el registro de presets dinámicos.
    * **Verificación y Sincronización del Showcase AAA Cyberpunk (`demo_cyberpunk_infiltration.tscn`):**
      * Sincronización de los 9 emisores 7.1 del Sector 5 (Biosfera) con sus presets canónicos en el archivo JSON (`"Wind_Canopy"`, `"Waterfall_Stream"`, `"Bird_Chirp"`, `"Thunder_Rumble"`, `"Cicada_Swarm"`, `"Frog_Croak"`, `"Rain_Atmosphere"`, `"Water_Droplet"`, `"Cyber_Hornet"`).
      * Comprobación de generación de audio procedural 100% en tiempo real sin requerir archivos de audio WAV/OGG pregrabados en disco.
    * **Suite de Pruebas Automatizadas:** 215 pruebas unitarias e integración en `test_runner_cli.gd` pasando al 100% (código de salida 0, sin errores ni advertencias).

* **`TASK-044` - Sector 5: Biosfera 7.1 Surround Showcase (Cyberpunk Infiltration Demo)**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Síntesis Procedimental de Audio de Naturaleza 7.1 (`AudioSynthesizer`):**
      * Generadores procedurales puros de audio sintético: brisa en el dosel forestal (`create_canopy_wind_loop`), cascada/río continuo (`create_waterfall_loop`), lluvia vegetal y gotas aisladas (`create_rain_foliage_loop`, `create_water_droplet`), truenos subgraves LFE (`create_distant_thunder`), cantos de aves procedimentales con chirp modulado en frecuencia (`create_bird_chirp`), estridulación de cigarras con modulación de amplitud a 28 Hz (`create_cicada_stridulation`), croar de ranas polifónicas (`create_frog_croak`) y zumbido de avispón bio-mecánico (`create_nature_foley_loop`).
    * **Geometría y Acústica Espacial 7.1 del Sector 5 (`Sector5_Biosphere`):**
      * Cúpula geodésica translúcida en `demo_cyberpunk_infiltration.tscn` en coordenadas $(80, 1.5, 0)$ conectada mediante portal acústico (`Arena_To_Biosphere_Portal`) al Sector 4.
      * Sala acústica Sabine declarativa `OpenDouRoom3D` (`Biosphere_Sanctuary`) con $RT_{60} = 0.38\text{s}$ y absorción $\alpha = 0.60$.
      * Disposición envolvente 7.1 completa con 8 emisores periféricos fijos (`CanopyWind_FL`, `Waterfall_FR`, `Bird_C`, `Thunder_LFE`, `Cicada_SL`, `Frog_SR`, `Rain_RL`, `Droplet_RR`) más emisor en órbita continua de 360 grados (`OrbitingBeeEmitter`).
    * **Integración en Gameplay Coordinator y Telemetría (`demo_cyberpunk_infiltration.gd`):**
      * Posición de teletransporte para el Sector 5 en $(80, 1.5, 0)$ y cableado de botones de HUD `BtnSector5`.
      * Detección de superficie física `&"Foliage"` para pisadas en $x \ge 65.0$.
      * Animación de órbita 360° en `_process(delta)` para `OrbitingBeeEmitter` alrededor del centro de la biosfera a radio de 5 metros.
      * Registro del emisor orbitante en el radar acústico táctico 2D (`OpenDouRadarView`).
    * **Suite de Pruebas Automatizadas:** 191 pruebas unitarias y de integración pasando al 100% (código de salida 0).

* **`TASK-043` - Monitor de Voces Audibles e Inspector de Intensidad Sonora (OpenDou Audible Monitor)**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Motor de Telemetría de Percepción Sonora (`AudibleVoiceMonitor`):**
      * Algoritmo de cálculo de sonoridad efectiva en dB ($dB_{\text{eff}} = \text{base\_db} + \text{attenuation\_db} + \text{occlusion\_db} + \text{ducking\_db}$) para cualquier emisor 2D/3D o instancia virtualizada.
      * Soporte de modelos de atenuación espacial inversa, lineal y logarítmica con umbral mínimo de corte (por defecto $-55\text{ dB}$).
      * Clasificación dinámica por categorías de bus (`Voice`, `SFX`, `Music`, `Ambience`).
    * **Overlay HUD In-Game Declarativo (`OpenDouAudibleMonitor`):**
      * CanvasLayer desacoplado con UI cyberpunk flotante en esquina superior derecha.
      * Lista reactiva ordenada por intensidad sonora con barras VU coloreadas por nivel (Rojo > -6dB, Amarillo > -18dB, Verde > -36dB, Cyan <= -36dB).
      * Insignias de metadatos espaciales: distancia en metros, oclusión acústica (`[🛡️ Occl]`) y atenuación por ducking (`[🦆 Duck -XdB]`).
      * Atajo configurable (`F8`) y botón táctil interactivo en HUD.
    * **Integración en Editor Profiler Studio (`OpenDouProfilerPanel`):**
      * Pestaña `🔊 Audible & Loudness` en el Live Profiler con ranking en tiempo real de emisores activos, filtrado por umbral de dB y vúmetros por voz.
    * **Integración en Showcase AAA Cyberpunk (`demo_cyberpunk_infiltration.tscn`):**
      * Nodo declarativo `AudibleMonitor` integrado y botón `🔊 Monitor (F8)` en la barra de control táctica.
    * **Suite de Pruebas Automatizadas:** 183 pruebas unitarias e integración en `test_runner_cli.gd` pasando al 100% (código de salida 0).

* **`TASK-042` - Suite de Nodos Declarativos de Audio (OpenDou Declarative Nodes)**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Jerarquía de Emisores Declarativos:**
      * **`OpenDouEventPlayer3D` (`AudioStreamPlayer3D`):** Emisor espacial 3D con integración automática a `SpatialAcousticsManager`, soporte para reverberación de salas de Sabine, portales con difracción, reflectores de primer orden, oclusión dinámica por raycasting multi-rayo, virtualización de voces y filtrado binaural HRTF.
      * **`OpenDouEventPlayer2D` (`AudioStreamPlayer2D`):** Emisor espacial 2D con enlace declarativo a eventos de audio, modulación por RTPCs, Switches, Estados y gestión de prioridades de voz.
      * **`OpenDouEventPlayer` (`AudioStreamPlayer`):** Emisor estéreo global/UI no posicional con parada segura al salir del árbol de escena y enlace a Game Syncs.
    * **Macro-Acústica Espacial Declarativa:**
      * **`OpenDouRoom3D` (`Area3D`):** Recinto acústico con auto-detección de volúmenes geométricos (`BoxShape3D`), cálculo analítico de $RT_{60}$ por fórmula de Sabine ($RT_{60} = 0.161 V / (S \alpha)$), presets de absorción (Concreto, Madera, Vidrio, Cortinas) y activación automática de snapshots de mezcla al entrar el oyente.
      * **`OpenDouPortal3D` (`Node3D`):** Aberturas arquitectónicas con cálculo dinámico de difracción LPF ($300\text{ Hz} \le \text{LPF} \le 20,000\text{ Hz}$) y redirección del origen aparente del sonido a través de rutas acústicas.
      * **`OpenDouReflector3D` (`Node3D`):** Superficies reflectantes con cálculo de fuentes imagen virtuales para reflexiones acústicas tempranas de primer orden.
    * **Música Interactiva Declarativa (`OpenDouMusicPlayer`):**
      * Reproductor musical de alto nivel basado en suites (`.tres` / `.json`), modulación continua de intensidad de combate con crossfades automáticos de stems, control de reproducción/pausa/bucle y disparo de stingers rítmicos.
    * **Integración en EditorPlugin e Iconografía Vectorial:**
      * Registro completo de los 7 tipos personalizados mediante `add_custom_type` y `remove_custom_type` en `plugin.gd`.
      * Iconografía vectorial SVG limpia para todos los nodos en `addons/opendou/icons/`.
    * **Suite de Pruebas Automatizadas:** 16 pruebas unitarias e integración en `test_declarative_nodes.gd` pasando al 100% (código de salida 0).

* **`TASK-041` - Demo 07: Cyberpunk Infiltration AAA Showcase Demo**
  * **Fecha:** 2026-08-30
  * **Resumen:**
    * **Entorno 3D Declarativo Multizona (`demo_cyberpunk_infiltration.tscn`):** Vertical slice jugable con 4 sectores arquitectónicos continuos:
      * **Sector 1 (Azotea Exterior):** Lluvia volumétrica, pasarelas metálicas con síntesis de pisadas en metal y reverberación exterior abierta ($RT_{60} = 0.4\text{s}$).
      * **Sector 2 (Bóveda de Servidores):** Suelo de baldosas sintéticas, zumbido de racks e interfaz de esclusa de aire con compuerta física y difracción acústica por portal (`Server_Airlock`).
      * **Sector 3 (Drenaje Inundado):** Conducción subterránea con agua y lodo, síntesis de pisadas acuáticas, acústica de reverberación húmeda ($RT_{60} = 1.2\text{s}$) y snapshot subacuático.
      * **Sector 4 (Helipuerto / Extraction Arena):** Plataforma de hormigón armado, baliza de radio, torreta perimetral con oclusión geométrica dinámica por pilares y zona de estrés masivo.
    * **Simulación de Asedio con 250 Voces y Virtualización a Coste Cero:**
      * Disparo de 250 proyectiles y explosiones continuas gestionadas por el pool de 16 canales físicos (`VoicePoolManager`), con seguimiento virtual continuo y cero clicks de audio.
    * **Diálogos Tácticos Localizados y Ducking Automático:**
      * Transmisiones de radio multilingüe (`EN`, `ES`, `JA`, `ZH`) con `AudioDialogueManager` y `AudioDialogueTable`.
      * Atenuación continua de sidechain por matriz de ducking (`AudioDuckingMatrix`) reduciendo el bus `Music` (-14 dB) en tiempo real al hablar por radio o emitir ráfagas de artillería.
    * **Música Interactiva Adaptativa y Telemetría en HUD:**
      * Progresión de intensidad de combate con el secuenciador de playlists `MusicPlaylistManager` (`Intro_Theme` $\to$ `Stealth_Loop` $\to$ `Combat_Alert` $\to$ `Extraction_Outro`).
      * HUD táctico con radar acústico 2D (`OpenDouRadarView`), monitor de telemetría de voces (físicas vs virtuales), oclusión geométrica, estado de esclusa y subtítulos.
    * **Integración en DemoHub:** Registro en `DEMO_SCENES[7]` y Hero Showcase Card en el lanzador central interactivo.
    * **Suite de Pruebas Automatizadas:** 163 pruebas unitarias pasando al 100% (código de salida 0).

* **`TASK-040` - Arquitectura de Ventana Flotante Maximizada, Modales Independientes y Barra de Transporte Contextual**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Apertura Auto-Maximizada y Desacople de Ventana (`Window.MODE_MAXIMIZED`):** Al activar o abrir el dock de OpenDou Studio, se despliega automáticamente en una ventana flotante maximizada a pantalla completa sin desperdicio de espacio vertical/horizontal (`Control.PRESET_FULL_RECT` y `SIZE_EXPAND_FILL`).
    * **Modales Flotantes Arrastrables e Independientes:**
      * Consola de Mezcla HDR y Matriz de Ducking (`mixer_dialog`, 780x460) accesible mediante el botón `[ 🎚️ HDR ]` en la barra superior.
      * Gestor de Game Syncs y Simulación (`syncs_dialog`, 460x480) accesible con el botón `[ 🎮 Syncs ]`.
      * Live Profiler, Telemetría y SoundBanks (`profiler_dialog`, 840x540) accesible con `[ 📊 Profiler ]` y `[ 📦 Banks ]`.
    * **Eliminación de Splitter Vertical Central:** El lienzo central (`center_workspace_box` para Grafo, Music DAW y Voice Localization) ocupa ahora el 100% de la altura útil de la pantalla entre la cabecera superior y la barra de transporte inferior.
    * **Barra de Transporte Inferior Reactiva y Contextual:**
      * **Modo Grafo (`0`):** Transporte de audición (`▶/⏸/⏹`), insignia de evento activo y faders compuestos de precisión con sincronización bidireccional de slider y spinbox (`Distance`, `RPM`, `Pitch Jitter`).
      * **Modo Music DAW (`1`):** Contador de compás y tiempo en tiempo real (`⏱️ Bar 1 : Beat 1.0`), spinbox de tempo (120 BPM), selector de cuantización de transición (`Next Bar`, `Next Beat`, `Immediate`) y marcador de cambios sin guardar (`*`).
      * **Modo Voice (`2`):** Audición instantánea de líneas vocales, toggle de preescucha directa 2D (`🎧 Raw 2D`), medidor RMS vocal (`🎙️ RMS`), selector de idioma rápido (`EN/ES/JA/ZH`) e indicador de estado de ducking.
      * **Sección Master:** Fader master permanente (-60 dB a +6 dB) con spinbox y vúmetro estéreo de alta resolución.
    * **Pulido de Lienzos de Trabajo:** Cabeceras de pistas de 280px fijos en la DAW musical, marcadores triangulares sólidos (▼) para cues de entrada/salida y cuadrícula de 6 columnas expandida al 100% en la tabla de localización de diálogos.
    * **Suite de Pruebas:** 142 pruebas unitarias pasando al 100% (código de salida 0).

* **`TASK-039` - Depurador Visual de Zonas Acústicas, Portales y Oclusión (Spatial Radar & Portals Viewer)**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Pestaña "📡 Spatial Radar" en el Live Profiler:** Visualizador 2D interactivo con coordenadas relativas al oyente y escala de rango ajustable (`10m a 100m`).
    * **Salas Acústicas (`AudioRoom`) y Portales (`AudioPortal`):** Renderizado de recintos cerrados y aperturas de puertas/ventanas con estado abierto/cerrado y atenuación de oclusión.
    * **Rayos de Difracción y Reflexión Acústica:** Trazado de rayos de difracción en esquinas/portales y reflexiones de primer orden en paredes (`AcousticReflector`).
    * **Suite de Pruebas:** 135+ pruebas unitarias pasando al 100% en `test_runner_cli.gd`.

* **`TASK-038` - Diseñador Paramétrico de Salas Acústicas en Convolución (Sabine Room Acoustics Designer)**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Diseño Paramétrico en `OpenDouConvolutionGraphNode`:** Modo interactivo para definir largo, ancho y alto de la sala en metros.
    * **Materiales y Coeficientes de Absorción ($\alpha$):** Selección de materiales acústicos (Concreto, Madera, Yeso, Cortinas) con cálculo automático de volumen ($V$), área superficial ($S$) y tiempo de reverberación de Sabine ($RT_{60}$).
    * **Forma de Onda de IR Sintética:** Visualización en tiempo real de la respuesta al impulso calculada con reflexiones tempranas y cola exponencial.
    * **Suite de Pruebas:** 135+ pruebas unitarias pasando al 100% en `test_runner_cli.gd`.

* **`TASK-037` - Grabador y Reproductor de Sesiones en el Live Profiler (Session Recorder & Time-Travel)**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Grabación de Telemetría (`🔴 Record` / `⏹ Stop`):** Captura continua de cuadros de rendimiento en un búfer circular con contador de tiempo y fotogramas en vivo.
    * **Exportación e Importación de Sesiones JSON:** Guardado y carga de sesiones completas de perfiles de juego (`.json`) para análisis offline.
    * **Barra de Rebobinado Temporal (*Time-Travel Scrubbing*):** Inspección segundo a segundo del estado del ledger de voces, picos de CPU y memoria histórica.
    * **Suite de Pruebas:** 135+ pruebas unitarias pasando al 100% en `test_runner_cli.gd`.

* **`TASK-036` - Nodo Visual de Secuencia Cronológica (Sequence Container Graph Node)**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Nodo `OpenDouSequenceGraphNode` en Graph Editor:** Integración visual con `AudioSequenceContainer`.
    * **Modos de Secuenciación:** Soporte para `Sequential (1→2→3)` y `Ping-Pong (1→2→3→2→1)` con opción de repetición en bucle (`Loop`).
    * **Control de Retardo por Paso (*Step Delay*):** Ajuste de intervalos de espera entre eventos y botón de audición con resaltado de paso activo.
    * **Suite de Pruebas:** 135+ pruebas unitarias pasando al 100% en `test_runner_cli.gd`.

* **`TASK-035` - Nodos Visuales de Modulación AHDSR y LFOs en Graph Editor**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Nodo de Envolvente AHDSR (`OpenDouAHDSRGraphNode`):** Visualizador de curva con ajuste de tiempos de ataque, hold, caída, sustain y liberación, mapeado a volumen, tono o frecuencia de corte de filtros con botón de disparo de prueba.
    * **Nodo de Oscilador LFO (`OpenDouLFOGraphNode`):** Generador de formas de onda periódicas (`Sine`, `Triangle`, `Square`, `Sawtooth`) con visualizador animado, control de frecuencia en Hz y profundidad de modulación.
    * **Suite de Pruebas:** 135+ pruebas unitarias pasando al 100% en `test_runner_cli.gd`.

* **`TASK-034` - Matriz Visual de Audio Ducking en el HDR Mixer Drawer**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Pestaña "🦆 Ducking Matrix" en `OpenDouMixerDrawer`:** Matriz de cuadrícula interactiva de buses emisores vs buses receptores (`Voice`, `SFX`, `Music`, `Ambient`).
    * **Editor de Reglas de Ducking:** Parámetros de atenuación en dB (`-1 dB a -48 dB`), tiempos de ataque y liberación en segundos, sincronizados en caliente con `AudioDuckingMatrix`.
    * **Medidores de Reducción de Ganancia en Vivo (*GR Meters*):** Indicadores visuales en los faders de canal para monitorear en tiempo real la atenuación aplicada por sidechain.
    * **Suite de Pruebas:** 135+ pruebas unitarias pasando al 100% en `test_runner_cli.gd`.

* **`TASK-033` - Gestor de Playlists Musicales y Jerarquía de Estados (Music Playlist Manager)**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Motor de Playlists No Lineales (`MusicPlaylistManager`):** Estructura jerárquica de secuencias (`Intro` $\rightarrow$ `Loop A (2-4x)` $\rightarrow$ `Bridge` $\rightarrow$ `Loop B` $\rightarrow$ `Outro`) con conteo de loops configurables por paso.
    * **Pestaña "🎼 Playlist" en el DAW:** Inspector integrado para añadir, reordenar (`⬆️`/`⬇️`), eliminar segmentos y alternar el bucle global de playlist.
    * **Avance y Transición Automática:** El secuenciador evalúa los ciclos completados en tiempo real y conmuta al siguiente segmento automáticamente sin romper el pulso rítmico ni la cuantización.
    * **Persistencia Completa:** Guardado y recarga de listas de reproducción en `res://opendou_music_suites.json`.
    * **Suite de Pruebas:** 135 / 135 pruebas unitarias pasando al 100% en `test_runner_cli.gd`.

* **`TASK-032` - Automatizaciones RTPC en Línea de Tiempo y Ruteo de Buses**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Carriles de Automatización Desplegables (`Automation Sub-Lanes` 📈):** Botón `[ 📈 ]` en la cabecera para desplegar un carril interactivo donde añadir, arrastrar y eliminar puntos de control de curva.
    * **Modulación Interpolada en Tiempo Real:** Evaluación continua de la envolvente de volumen, filtro LPF o RTPC `CombatIntensity` sincronizada con el cabezal de lectura.
    * **Ruteo de Sub-Buses de Godot por Pista:** Selector en cabecera de pista (`Master`, `Music`, `Music_Percussion`, `Music_Pads`, `Music_Leads`) asignado en caliente al `AudioStreamPlayer.bus`.
    * **Persistencia Completa:** Guardado y recarga en disco de puntos de automatización, parámetro activo y bus por pista.
    * **Suite de Pruebas:** 135 / 135 pruebas unitarias pasando al 100% en `test_runner_cli.gd`.

* **`TASK-031` - Marcadores Estructurales (Pre-Entry / Exit Cues), Colas Post-Exit Tails y Sub-Pistas Aleatorias**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Marcadores Rítmicos en la Regla (`Entry` 🟢 / `Exit` 🔴):** Marcadores arrastrables en la regla con ajuste magnético, soportando anacrusas (*pre-entry pickups*) antes del compás 1.
    * **Colas de Desbordamiento (`Post-Exit Tails` 🟣):** Zona de cola sombreada en la regla y búfer de decaimiento natural (`tail_decay_players`) durante las transiciones para evitar cortes abruptos en reverberaciones y platillos.
    * **Sub-Pistas Aleatorias (`Random Multi-Tracks` 🎲):** Gestión de múltiples variaciones por pista (`[ 🎲 Var: N ]`) con conmutación aleatoria en cada ciclo de bucle rítmico para evitar la fatiga auditiva.
    * **Persistencia Completa:** Guardado y recarga en disco de marcadores, colas y variaciones en `res://opendou_music_suites.json`.
    * **Suite de Pruebas:** 135 / 135 pruebas unitarias pasando al 100% en `test_runner_cli.gd`.

* **`TASK-030` - Persistencia Real, CRUD de Pistas, Selector de Audio y Tiradores de Recorte del Music DAW**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Indicador de Estado Modificado (`Dirty State *`):** Detección en tiempo real de cambios en faders, mute, solo, BPM, intensidad y trim handles, actualizando el selector con `*` y resaltando el botón `[ 💾 Save ]`.
    * **Guardado en Disco (`Ctrl+S` / Botón 💾):** Serialización persistente en `res://opendou_music_suites.json` (y recursos `.tres`), restaurando suites y capas al reiniciar el editor.
    * **Caché y Restauración Visual de Pestañas:** Retención en memoria de la posición de zoom, scroll horizontal/vertical, volumen y cabezal al alternar entre *Graph*, *Music DAW* y *Dialogues*.
    * **CRUD Dinámico de Pistas (`[ ➕ Add Track ]` / `[ 🗑️ Delete Track ]`):** Creación y eliminación de pistas/stems en caliente, adaptando los reproductores de audio procedurales y sincronizados en tiempo real.
    * **Selector de Archivos de Audio (`Audio File Picker`):** Diálogo de archivos (`.wav`/`.ogg`) por pista para asignar clips personalizados y refrescar sus formas de onda.
    * **Tiradores de Recorte Interactivos (`Clip Trim Handles`):** Tiradores izquierdo/derecho en cada carril para acortar o recortar el punto de entrada y salida del bucle musical con arrastre de ratón.
    * **Suite de Pruebas:** 135 / 135 pruebas unitarias pasando al 100% en `test_runner_cli.gd`.
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * **Espacios de Trabajo Dedicados:** Alternador superior entre `🌐 Graph`, `🎼 Music DAW` y `🗣️ Dialogues` con el 100% de elasticidad de lienzo.
    * **Consola de Mezcla HDR Deslizante:** Faders de canal, visualizador dinámico HDR, banco de Snapshots con blend time y monitor de sidechain ducking.
    * **Persistencia en Disco de Game Syncs:** Guardado/recarga automático en `res://opendou_syncs.json` de RTPCs, Estados y Switches, sincronizados en tiempo real con los faders de simulación del Transport Bar.
    * **Compilador Bidireccional de Grafos y Audición Real:** `OpenDouGraphSerializer.build_composite_from_graph` compila los nodos del canvas en un árbol `AudioLogicNode` ejecutable, evaluando en tiempo real las variaciones de tono, volumen, ramas de switch y cadenas DSP en el reproductor de audición.
    * **Audición Interactiva de Música y Diálogos:** Sintetizadores procedurales de prueba para stems de música multicapa, stingers cuantizados y voces con fonética localizada.
    * **Suite de Pruebas:** 135 / 135 pruebas unitarias pasando al 100% en `test_runner_cli.gd`.

* **`TASK-029` - Empaquetado Final, Iconografía Vectorial y Asset Library**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * Iconos SVG vectoriales (`icon_event_player_3d.svg`, `icon_room.svg`, `icon_portal.svg`, `icon_studio.svg`).
    * Manifiesto `plugin.cfg` v1.0.0 listo para Godot Asset Library.

* **`TASK-028` - Grabación Histórica de Sesión y Time-Travel Rewind en el Profiler**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * Implementado `ProfilerSessionRecorder` con búfer circular para telemetría continua (DSP $\mu s$, voces, eventos, RTPCs).
    * Línea de tiempo de Scrubbing y Rebobinado (`OpenDouProfilerPanel`) para depurar robos de voz congelando el tiempo.
    * Métodos de exportación/importación JSON de sesiones `.douprof`.
    * Suite de pruebas en `test_profiler_rewind.gd`.

* **`TASK-027` - Procesamiento DSP Avanzado (Convolution Reverb & Síntesis Granular)**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * Motor `ConvolutionReverbNode` para procesamiento FIR de respuestas a impulsos reales (.wav IR).
    * Motor `AudioGranularSynthesizer` para micro-granos, ventanas Hanning, time-stretching y pitch modulation.
    * Suite de pruebas en `test_dsp_advanced.gd`.

* **`TASK-026` - Reflexiones Tempranas 3D y Audio Inmersivo HRTF**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * `AcousticReflector` para trazado de rayos especulares de 1er/2do orden y coeficientes de absorción de superficies.
    * `AudioSpatialBinaural` con fórmula Woodworth para retardo interaural temporal (ITD), diferencia de nivel (ILD) y filtrado espectral pinna.
    * Suite de pruebas en `test_early_reflections_hrtf.gd`.

* **`TASK-025` - Gestión y Localización de Diálogos Multi-Idioma**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * `AudioDialogueTable` para mapeo de claves de diálogo a streams por código de idioma (`es`, `en`, `ja`, etc.).
    * `AudioDialogueManager` con intercambio de idioma en caliente sin reconstrucción de eventos y auto-ducking del bus `Voice`.
    * Suite de pruebas en `test_dialogue_localization.gd`.

* **`TASK-024` - Jerarquía de Música Interactiva (Interactive Music Engine)**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * `MusicClock` de alta precisión (BPM, compases, tiempos, eventos de cuantización).
    * `MusicSegment` y `MusicTrack` con capas instrumentales dinámicas por intensidad.
    * `MusicTransitionMatrix` para crossfades cuantizados (*Immediate*, *Next Beat*, *Next Bar*).
    * `MusicStingerQueue` para inyección de stingers rítmicos con atenuación de bus base.
    * Suite de pruebas en `test_interactive_music.gd`.

* **`TASK-023` - Audio HDR y Snapshots de Mezcla Global**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * `AudioMixSnapshot` y `AudioMixSnapshotManager` con interpolación de curvas suave multi-bus.
    * `AudioHDREngine` con ventana dinámica de sonoridad para prevenir clipping balístico.
    * `AudioDuckingMatrix` para atenuación de sidechain multi-bus continua y click-free.
    * Selector de snapshots en `OpenDouStudioMain` y suite de pruebas en `test_hdr_snapshots.gd`.

* **`TASK-022` - Rediseño y Construcción de la Suite de Editor de Audio AAA**
  * **Fecha:** 2026-08-29
  * **Resumen:**
    * Reestructuración de `OpenDouStudioMain` con layout de 3 columnas redimensionable, paneles colapsables, ventana flotante elástica, mini-waveforms PCM, panel de Game Syncs y transporte con vúmetro estéreo.

* **`TASK-020` - Escenas de Demostración AAA y Sandbox (Divididas por Capacidades y .tscn Declarativo)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Diseñadas y construidas 7 escenas completamente declarativas (`.tscn`) con mallas 3D, geometrías CSG, cámaras, luces, materiales emisivos e interfaces de usuario CanvasLayer completas visibles y editables en el editor de Godot 4.7+:
      * **Demo 01 (`01_spatial_rooms_portals.tscn`):** Macro-acústica espacial, difracción de sonido por puertas/ventanas y modulación dinámica de LPF y origen aparente al abrir/cerrar portales.
      * **Demo 02 (`02_massive_voice_stress.tscn`):** Estrés con 250 emisores 3D activos sobre un pool de hardware limitado a 16 canales físicos, validando robo de voz por prioridad ($W$), micro-fades de 15ms y seguimiento virtual escalado por tono.
      * **Demo 03 (`03_surface_switches_3d.tscn`):** Pisadas de personaje 3D sobre Madera, Concreto, Metal y Agua utilizando `AudioSwitchContainer` y `AudioRandomContainer` con bolsa shuffle anti-repetición.
      * **Demo 04 (`04_vehicle_blend_rpm.tscn`):** Motor de vehículo con tacómetro y acelerador interactivo (0 a 8000 RPM) evaluando `AudioBlendContainer` con curvas pre-horneadas LUT $O(1)$ y descarte de silencio ($\le -80\text{ dB}$).
      * **Demo 05 (`05_dynamic_occlusion_ray.tscn`):** Oclusión física por raycasting multi-rayo con obstáculo móvil y suavizado temporal por *slew-rate* ($\kappa = 8.0\text{ s}^{-1}$).
      * **Demo 06 (`06_soundbank_streaming.tscn`):** Demostración de reproducción de SoundBanks monolíticos `.bank` con arranque instantáneo en RAM prefetch y empalme transparente a streaming de disco.
      * **Demo 07 (`demo_hub.tscn`):** Lanzador y centro de navegación maestro con selección de escenas, explicaciones técnicas y telemetría en vivo.
    * Incorporada la regla de desarrollo de construcción declarativa de escenas en `AGENTS.md` y `.agents/rules/02_architecture.md`.
    * Creada y validada la suite de tests unitarios en `test_demo_suite.gd` (90/90 pruebas pasando con código de salida 0 en `godot --headless -s tests/test_runner_cli.gd`).

* **`TASK-019` - Contenedor Maestro Multi-Modo (Dock Inferior, Main Screen & Ventana Flotante `Window`)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementado `OpenDouStudioMain` como el espacio de trabajo maestro de OpenDou dentro de Godot 4.7+.
    * Integradas las 3 vistas especializadas: `🌐 Audio Logic Graph`, `📡 3D Acoustic Radar & Telemetry` y `📦 SoundBanks`, junto con la barra inferior fija de transporte `OpenDouTransportBar`.
    * Implementado el sistema de desacople a ventana flotante nativa del sistema operativo (`Window` multi-monitor) con botón `🗗 Detach Window`.
    * Registrado `OpenDou` en `plugin.gd` como dock inferior ("Audio Logic") y como pantalla principal de Godot (`_has_main_screen`).
    * Creada la suite de tests unitarios en `test_studio_main.gd`.

* **`TASK-018` - Panel de Compilación de SoundBanks (`OpenDouBankPanel`)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementado `OpenDouBankPanel` como interfaz de usuario para empaquetado de SoundBanks.
    * Soporte para selección de nombres de banco, rutas de archivo destino, ajuste de tamaño de búfer prefetch en RAM por flujo y lista interactiva de streams de audio.
    * Integración directa con `SoundBankCompiler` para compilar archivos binarios `.bank` en un solo clic.
    * Creada la suite de tests unitarios en `test_bank_panel.gd`.

* **`TASK-017` - Radar Acústico 3D & Telemetría en Tiempo Real (`OpenDouRadarView`)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementado el control visual `OpenDouRadarView` con dibujo procedural en 2D de la posición central del oyente, anillos concéntricos de rango de distancia y atenuación.
    * Añadida la proyección matemática de coordenadas del mundo 3D $(x, y, z) \to (x, z)$ con representación diferenciada por color de voces físicas (con rayos acústicos) y voces virtuales.
    * Integrado overlay HUD de telemetría de rendimiento (canales físicos activos, seguimiento virtual, tiempo de CPU DSP en ms y memoria RAM de SoundBanks).
    * Creada la suite de tests unitarios en `test_radar_view.gd`.

* **`TASK-016` - Barra de Transporte, Audición en Vivo y Faders RTPC (`OpenDouTransportBar`)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementada la barra de transporte `OpenDouTransportBar` con controles de reproducción interactiva (*Play, Pause, Stop Esc*), visualización del evento activo y control maestro de volumen de audición.
    * Añadida la generación dinámica de faders de prueba de RTPCs y selectores desplegables de Switches para iteración instantánea sin salir del editor.
    * Creada la suite de tests unitarios en `test_transport_bar.gd`.

* **`TASK-015` - Lienzo de Grafo Visual & Serialización (`GraphEdit` & Composite Converter)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementado `OpenDouGraphSerializer` para convertir recursivamente árboles lógicos `AudioLogicNode` (Blend, Random, Switch, WAV) en topologías visuales con conexiones automáticas de cables.
    * Implementado `OpenDouGraphEditor` (`GraphEdit`) con soporte completo para zoom, arrastre de lienzo, menú contextual emergente por clic derecho y callbacks para conexión/desconexión de cables.
    * Implementado el sistema de animación e iluminación de ramas activas (`highlight_active_branch`) durante la preescucha.
    * Creada la suite de tests unitarios en `test_graph_serializer.gd`.

* **`TASK-014` - Nodos de Grafo Visual de Audio (`GraphNode` Custom Widgets)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Creada la jerarquía de widgets visuales para el editor de grafos en `addons/opendou/editor/nodes/`.
    * Implementado `OpenDouBaseGraphNode` con soporte para iluminación LED activa de audición y puertos codificados por color (Señal de Audio Dorada, Lógica Cian).
    * Implementado `OpenDouBlendGraphNode` con selector de RTPC, mini-canvas con curva spline interactiva y cursor en vivo de posición.
    * Implementado `OpenDouRandomGraphNode` con toggle de bolsa shuffle y spinners de jitter estocástico de pitch y volumen en dB.
    * Implementado `OpenDouSwitchGraphNode` con selector de grupo de switch y generación dinámica de puertos de salida por estado.
    * Implementado `OpenDouAudioFileGraphNode` con vista previa de forma de onda (*waveform*), indicador de duración y botón de reproducción directa.
    * Implementado `OpenDouOutputGraphNode` como terminal maestro de salida de la señal.
    * Creada la suite de tests unitarios en `test_editor_nodes.gd`.

* **`TASK-013` - Telemetría de Voces y Profiling en Tiempo Real (Voice Telemetry & Radar 3D)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementada la estructura `AudioTelemetrySnapshot` y `VoiceTelemetryData` para recopilación de métricas de rendimiento en tiempo real (voces físicas, voces virtuales, tiempo de CPU DSP, consumo de memoria RAM de SoundBanks).
    * Implementada la extracción de coordenadas 3D $(x, y, z)$, volumen en dB, peso dinámico y estado de virtualización de las voces vivas para permitir la renderización de un radar acústico 3D en la herramienta de autoría/editor.
    * Implementada la serialización binaria ultracompacta en `LiveUpdateProtocol` (`encode_detailed_telemetry` / `decode_detailed_telemetry`).
    * Implementado `AudioTelemetryCollector` para recopilar datos de frame sin asignaciones en caliente.
    * Creada la suite de tests unitarios en `test_voice_telemetry.gd`.

* **`TASK-012` - Live Update & Profiler (Servidor TCP, Protocolo TLV y Modificación en Caliente)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Diseñado e implementado el protocolo binario TLV (*Type-Length-Value*) con cabecera de 8 bytes (Magic `OD`, `message_type`, `payload_length`).
    * Implementado `LiveUpdateServer` para aceptar conexiones de herramientas de edición externas vía TCP, encolando comandos de forma segura para modificar recursos `AudioEventDef`, `RTPCBinding` y `GameSyncManager` en caliente en RAM sin reiniciar el juego.
    * Implementada emisión de telemetría de rendimiento y métricas del profiler (voces físicas activas, voces virtuales, instancias vivas).
    * Creada la suite de tests unitarios en `test_live_update.gd`.

* **`TASK-011` - Micro-Acústica Dinámica (Raycasting Asíncrono y Suavizado de Oclusión / LPF)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementado `OcclusionManager` con soporte para consultas de oclusión geométrica multi-rayo (cálculo de factor de oclusión $\Omega \in [0.0, 1.0]$, target LPF de 1,500Hz a 20,000Hz y atenuación de volumen).
    * Implementada interpolación temporal por *slew-rate* ($\kappa = 8.0\text{ s}^{-1}$) en `EventInstance` para evitar saltos bruscos (*zipper noise* y *fluttering*) cuando emisores se mueven detrás de obstáculos delgados.
    * Inyección de `cutoff_hz` y atenuación en decibelios en el pipeline final de mezcla.
    * Creada la suite de tests unitarios en `test_micro_acoustics.gd`.

* **`TASK-010` - Macro-Acústica Espacial (Rooms, Portals y Acoustic Pathfinding)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementada la estructura `AcousticPath` para transportar la distancia virtual zig-zag, el origen de emisión aparente difractado y el filtro pasabajo LPF acumulado.
    * Implementado `AudioRoom` para recintos acústicos con reverberación, absorción y enlaces a portales.
    * Implementado `AudioPortal` para aberturas arquitectónicas (puertas, ventanas) con factor de apertura dinámico (`open_factor`) y atenuación de frecuencias altas ($200\text{ Hz} \le \text{LPF} \le 20000\text{ Hz}$).
    * Implementado `SpatialAcousticsManager` con algoritmo de búsqueda de caminos acústicos a través del grafo espacial.
    * Creada la suite de tests unitarios en `test_spatial_acoustics.gd`.

* **`TASK-009` - Búfer Circular (RingBuffer) y Empalme Prefetch-to-Disk (Stitching)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementada la estructura `AudioRingBuffer` (SPSC) con punteros de lectura y escritura cíclicos sobre capacidad en memoria fija sin asignaciones dinámicas en caliente.
    * Implementado `BankStreamPlayback` con máquina de estados de dos fases: Fase 1 (lectura instantánea de ataque desde slice de Prefetch RAM) y Fase 2 (lectura fluida desde `AudioRingBuffer` alimentado por streaming de disco).
    * Implementada protección activa contra *Buffer Underrun* mediante inyección de silencio digital (zero-fill) para evitar chasquidos o ruidos estáticos si el disco sufre contención temporal.
    * Creada la suite de tests unitarios en `test_ringbuffer.gd`.

* **`TASK-008` - SoundBanks Monolíticos (.bank) y Arquitectura Prefetch + Streaming**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Diseñado e implementado el formato binario monolítico `ODBK` estructurado en 4 bloques: Block 1 (Header de 24 bytes), Block 2 (TOC de metadatos), Block 3 (Prefetch de RAM contigua) y Block 4 (Streaming de disco).
    * Creado `SoundBankCompiler` para empaquetar flujos de audio cortando slices de prefetch (~64 KB o longitud configurada) y cuerpos de streaming con offsets binarios alineados.
    * Creado `SoundBank` para carga en un único bloque contiguo de RAM sin fragmentación de memoria ni múltiples *file handles*, con lectura instantánea de prefetch y streaming por chunks.
    * Creado `SoundBankManager` integrado en el singleton `OpenDou.load_bank()` y `OpenDou.unload_bank()`.
    * Creada la suite de tests unitarios en `test_soundbanks.gd`.

* **`TASK-007` - Moduladores Automáticos Nativos (AHDSR y LFO)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Creada la jerarquía de recursos `AudioModulator`, `AHDSRModulator` y `LFOModulator`.
    * Implementado el generador de envolvente `AHDSRState` con máquina de estados completa (`ATTACK`, `HOLD`, `DECAY`, `SUSTAIN`, `RELEASE`, `IDLE`) y fase de liberación conectada a `stop()`.
    * Implementado el oscilador `LFOState` con soporte para formas de onda Seno, Triángulo, Cuadrada y Diente de sierra con frecuencia en Hz y fase normalizada.
    * Integrados los moduladores autónomos en el pipeline de evaluación acumulada de `EventInstance` ($V_{\text{final}} = V_{\text{base}} + \sum \text{RTPC} + \sum \text{Modulador}$).
    * Creada la suite de tests unitarios en `test_modulators.gd`.

* **`TASK-006` - Gestor Central de RTPC, States y Switches (Game Syncs)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementada aceleración de curvas mediante horneado de tablas LUT (*Lookup Tables*) en `RTPCBinding` para evaluación en tiempo constante $O(1)$.
    * Creado `GameSyncManager` como gestor unificado de sincronización de juego para RTPCs globales con *slew-rates*, Estados globales con transiciones suaves de crossfade (`transition_weight`), Switches aislados por entidad y Triggers musicales con callbacks.
    * Integrado `GameSyncManager` en el singleton `OpenDou` (`AudioEventManager`) exponiendo una API de alto nivel: `OpenDou.set_state()`, `OpenDou.set_switch()`, `OpenDou.set_rtpc()`, `OpenDou.post_trigger()`.
    * Creada la suite de tests unitarios en `test_game_syncs.gd`.

* **`TASK-005` - Seguimiento Virtual a Coste Cero y Enrutamiento a Buses**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementado avance del cabezal virtual escalado por tono ($\Delta t \times \text{pitch}$) y envoltorio en bucle modulo `stream_length`.
    * Implementada auto-expiración natural de sonidos virtuales no bucleables al concluir su duración sin revivir tardíamente.
    * Implementados los 4 modos de reactivación (`VIRTUAL_ELAPSED_TIME`, `VIRTUAL_PLAY_FROM_START`, `VIRTUAL_RESUME`, `VIRTUAL_KILL_VOICE`).
    * Implementado el patrón de canales físicos mercenarios en `PhysicalVoiceChannel` con reconfiguración dinámica de `target_bus` y micro-fades de entrada/salida (10-15ms) para transiciones sin chasquidos.
    * Creada la suite de tests unitarios en `test_virtual_tracking.gd`.

* **`TASK-004` - Gestor de Pool de Voces y Robo Dinámico (`VoicePoolManager`)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementado `PhysicalVoiceChannel` con soporte para micro-fades de 15ms anti-clics de audio.
    * Añadidos en `EventInstance` los estados `VoiceState` (`PHYSICAL`, `VIRTUAL`, `KILLED`, `STOPPED`) y modos `VirtualizationMode` (`ELAPSED_TIME`, `PLAY_FROM_START`, `RESUME`, `KILL_VOICE`).
    * Implementado el cálculo de peso dinámico $W = \text{BasePriority} \times \text{LinearVolume} \times \text{DistanceFactor}$ con corte automático a distancia máxima.
    * Implementado `VoicePoolManager` con capacidad física fija (ej. 64 voces), algoritmo de ordenación por peso con margen de histéresis anti-thrashing (+5%) y robo dinámico de voz.
    * Integrado `VoicePoolManager` en el ciclo principal `_process(delta)` de `AudioEventManager`.
    * Creada la suite de tests unitarios en `test_voice_pool.gd`.

* **`TASK-003` - Contenedores Lógicos de Audio (Random, Switch, Blend, Sequence)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementado el **Patrón Composite** para el árbol de decisiones de audio.
    * Creados `AudioPlaybackContext` y `ResolvedVoice` para inyección de parámetros y retorno de streams físicos calculados.
    * Implementado `AudioLogicNode` (base abstracta) y `AudioPhysicalNode` (nodo hoja con stream de audio).
    * Implementado `AudioRandomContainer` con selección estocástica, bolsa *shuffle*, conteo anti-repetición y modulación aleatoria de tono/volumen (*jitter*).
    * Implementado `AudioSwitchContainer` para enrutamiento por variables de estado discretas (ej. superficies).
    * Implementado `AudioBlendContainer` y `BlendLayer` para crossfading simultáneo multicapa con curvas spline y optimización de descarte de silencio (*silence culling* $\le -80\text{ dB}$).
    * Implementado `AudioSequenceContainer` para reproducción en cadena.
    * Actualizado `AudioEventDef` para resolver árboles de contenedores mediante `resolve_voices(context)`.
    * Creada la suite de tests (`test_random_container.gd`, `test_switch_container.gd`, `test_blend_container.gd`, `test_composite_tree.gd`).

* **`TASK-002` - Despachador de Eventos y Sistema RTPC (`EventDispatcher` & `RTPCBinding`)**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Implementado `RTPCValue` con suavizado (*slew-rate*) de ataque/caída para eliminar ruidos digitales (*zipper noise*).
    * Implementado `RTPCBinding` con soporte para curvas spline de Godot (`Curve`) y operaciones matemáticas (`ADD`, `MULTIPLY`, `OVERRIDE`).
    * Implementado `AudioEventDef` como recurso data-driven configurable en el Inspector.
    * Implementado `EventInstance` para manejo de ciclo de vida en tiempo de ejecución (`play`, `pause`, `stop`) y precedencia de parámetros locales vs globales.
    * Implementado `AudioEventManager` como Autoload Singleton (`OpenDou`) con registro automático en `plugin.gd`.
    * Creada la suite de pruebas unitarias (`test_rtpc_value.gd`, `test_rtpc_binding.gd`, `test_event_instance.gd`, `test_event_manager.gd`, `test_all.gd`).

* **`TASK-001` - Estructura Base de Gobernanza, Reglas y Arquitectura de OpenDou Audio Engine**
  * **Fecha:** 2026-08-29
  * **Responsable:** Danielillo & Antigravity
  * **Resumen:**
    * Creadas las directrices maestras para IA en `AGENTS.md` y `GEMINI.md`.
    * Creadas las reglas modulares en `.agents/rules/` (estilo de código, arquitectura por capas y flujo de tareas).
    * Establecido el centro de documentación en `docs/` con análisis técnicos comparativos de motores de audio (`audio-engine_godot.md`, `audio-engine_wwise.md`, `audio-engine_fmod.md`, `audio-engine-comparison.md`, `event-dispatcher.md`, `logic-container.md`, `voice-pooling.md`, `soundbanks-pipelines.md`, `005-seguimiento-virtual.md`, `006-gestor-central.md`, `007.md`, `008.md`, `009.md`, `010.md`, `011.md`, `012.md`, `013.md`, `014.md`, `015.md`, `016.md`, `017.md`, `018.md`, `019.md`).
    * Creados los ADRs `0001-init-architecture.md` y `0002-audio-middleware-architecture.md`.
    * Configurado el manifiesto del plugin de Godot 4.7+ en `addons/opendou/` y `project.godot`.
