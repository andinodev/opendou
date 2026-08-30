# Propuesta de Evolución: Motor Acústico AAA, Reflexiones Tempranas e Inmersión Inteligente

**Documento de Idea:** `021-aaa-spatial-acoustics-and-immersion.md`  
**Módulo:** `addons/opendou/runtime/spatial`, `addons/opendou/core`, `addons/opendou/nodes`  
**Estado:** Análisis & Brainstorming de Próxima Generación

---

## 🎯 Visión: Elevando OpenDou al Estándar Wwise / FMOD / Metasound

Para que los sonidos dentro del juego trasciendan de simples reproducciones estáticas a una **experiencia acústica viva, orgánica e hiperrealista**, OpenDou debe simular la física con la que el sonido interactúa con los materiales, el aire, las esquinas, los volúmenes arquitectónicos y la psicoacústica del oído humano.

A continuación se detallan las tecnologías y módulos inteligentes que llevarán la espacialización y la inmersión de OpenDou a la vanguardia de la industria:

---

## 🚀 1. Diferenciación Rigurosa entre Obstrucción y Oclusión (Obstruction vs. Occlusion)

* **El Concepto:** En el estándar AAA, no toda barrera física tiene el mismo impacto acústico:
  * **Obstrucción (Obstruction):** La línea de visión directa está bloqueada por un obstáculo parcial dentro de la misma sala (ej. una columna, un vehículo o un sofá). Las reflexiones tempranas y la reverberación de la sala circundante viajan libres sin atenuarse. **Solo se filtra el sonido directo.**
  * **Oclusión (Occlusion):** La fuente de sonido está completamente sellada en otra sala o detrás de un muro macizo (ej. una puerta blindada cerrada). Se aplica la **Ley de Masas** y se atenúan severamente tanto el sonido directo como la reverberación tardía de la sala emisora.

```text
  [ OBSTRUCCIÓN ] (Misma Sala)                 [ OCLUSIÓN ] (Entre Salas)
  🔊 Emisor ──(Pared/Sofá)──► 👂 Directo LPF   🔊 Emisor (Sala A: Reverb Baño)
      │                           ▲                 │
      └───(Reverb Sala Libre)─────┘                 ▼ (Puerta cerrada / Muro)
      (Reflexiones y Reverb intactas)          👂 Oyente (Sala B: Todo atenuado)
```

---

## 🌊 2. Emisores Volumétricos en Curvas Spline y Geometrías (Volumetric Spline Emitters)

* **El Problema:** Tratar cada sonido como un "punto" exacto ($x, y, z$) falla rotundamente en ríos, cascadas anchas, tendidos de alta tensión, multitudes, muros de fuego o carreteras.
* **La Solución:**
  * **Nodo `OpenDouSplineEmitter3D`:** Permite trazar una curva *Spline 3D* o volumen rectangular a lo largo del cuerpo del sonido.
  * **Cálculo del Punto Más Cercano:** En cada fotograma, el emisor proyecta la posición auditiva hacia el punto más próximo de la curva respecto al jugador:
    $$P_{\text{closest}} = \arg\min_{P \in \text{Spline}} \|P - \text{Listener}\|$$
  * A medida que el jugador camina paralelo a la orilla del río o autopista, el paneo y la distancia se desplazan suave y dinámicamente con él, en lugar de centrarse en un origen fijo.

---

## 💥 3. Mezcla Psicoacústica HDR Audio (High Dynamic Range Sound Window)

* **El Problema:** La compresión estática tradicional en buses aplasta los sonidos o genera bombeo audible (*pumping*) cuando ocurren eventos de alta energía.
* **La Solución:**
  * **Ventana Dinámica de Sonoridad:** Inspirado en el modelo HDR Audio de *Battlefield / Frostbite*.
  * Si detona una granada a 3 metros (sonoridad de $+115\text{dB}$), el umbral inferior de escucha de la escena se eleva bruscamente:
    * Los disparos y estruendos cercanos se escuchan con total claridad y pegada.
    * Los pasos tenues, el viento ambiental y la música de fondo caen por debajo de la ventana audible y desaparecen instantáneamente devorados por el rango dinámico del estruendo.
    * A medida que la onda de choque se disipa, la ventana desciende con una curva de liberación suave, revelando gradualmente el ambiente y los pasos.

---

## 🏛️ 4. Reflexiones Tempranas Dinámicas y Ecos por Material (Early Reflections & Slapback Echoes)

* **El Concepto:** En el mundo real, escuchamos los primeros rebotes rápidos ($10\text{ms} - 80\text{ms}$) contra el suelo, techo y paredes cercanas.
* **Mecánica Inteligente:**
  * **Image-Source Acoustic Raytracer:** Cada emisor lanza rayos sonda primarios hacia las 6 superficies más cercanas.
  * **Respuesta según Material:**
    * *Metal / Vidrio:* Ecos brillantes y nítidos con muy poca amortiguación en altas frecuencias.
    * *Hormigón / Ladrillo:* Slapback seco, duro e inmediato.
    * *Madera:* Reflejos cálidos con atenuación suave de agudos.
    * *Follaje / Alfombras / Cortinas:* Absorción casi total (silencio de reflexiones).
  * **Espacio Libre:** En pasillos estrechos de metal, los ecos generan *Flanging / Comb Filtering* metálico natural; en grandes hangares o azoteas, el eco se retrasa convirtiéndose en un slapback cinematográfico.

---

## 🌫️ 5. Difracción Dinámica en Esquinas y Bordes (Obstacle Edge Diffraction)

* **El Concepto:** Cuando un sonido está detrás de una columna o esquina sin puerta, el sonido no se corta: "se dobla" alrededor del borde geométrico (Principio de Huygens-Fresnel).
* **Mecánica Inteligente:**
  * Detecta el borde más cercano del colisionador y calcula el ángulo de sombra acústica.
  * **Desplazamiento de Fuente Virtual:** El sonido no se percibe detrás del muro macizo, sino que el paneo 3D se desplaza hacia la esquina libre, filtrando las frecuencias altas con una curva de difracción suave.

---

## 🧱 6. Transmisión a través de Muros por Grosor y Densidad (Wall Mass Law Penetration)

* **El Concepto:** Un muro de tabique fino o una ventana de cristal dejan pasar frecuencias medias y agudas; un búnker de hormigón de 1 metro solo deja pasar sub-graves amortiguados.
* **Mecánica Inteligente:**
  * **Raycast de Doble Penetración:** Mide el espesor real del muro ($\Delta x$) aplicando la **Ley de Masas Acústica**:
    $$\text{Atenuación}_{\text{dB}} = 20 \log_{10}(f \cdot \rho \cdot \Delta x) - K$$
  * Permite escuchar conversaciones amortiguadas (*muffled voices*) o pasos en la habitación contigua según el grosor y material de la pared que los separa.

---

## 🚪 7. Acoplamiento Acústico de Salas y Portales (Room Coupling)

* **El Concepto:** Conectar la acústica de múltiples volúmenes arquitectónicos interconectados.
* **Mecánica Inteligente:**
  * Si ocurre un disparo en una sala reverberante de azulejos (baño o almacén), el portal de la puerta actúa como un micrófono y emisor acústico virtual que captura la respuesta a impulsos de esa sala y la inyecta como energía incidente en la sala contigua (un pasillo alfombrado), sumando y acoplando ambas reverbs de forma continua.
  * **Apertura Angular Progresiva (Sound Spread):** A distancia, la sala vecina se percibe como una fuente puntual en la puerta ($Spread \approx 15^\circ$), expandiéndose a $180^\circ \to 360^\circ$ envolvente conforme el jugador cruza el umbral.

---

## ⚡ 8. LOD Acústico y Culling Espacial Inteligente (Acoustic Level of Detail & Scalability)

* **El Problema:** Ejecutar raytracing acústico completo de 6 rebotes, difracción y Doppler para cada bala o enemigo activo saturará la CPU, especialmente en arquitecturas móviles o consolas portátiles (Steam Deck, Nintendo Switch).
* **La Solución (4 Niveles de LOD):**
  * **LOD 0 ($0 - 10\text{m}$):** Raytracing acústico completo (Reflexiones 6x, grosor de muro, difracción en esquinas, Doppler y HRTF pinna notch).
  * **LOD 1 ($10 - 25\text{m}$):** Oclusión básica por raycast único + difracción simplificada y atenuación de aire.
  * **LOD 2 ($25 - 50\text{m}$):** Paneo 3D y atenuación por distancia sin trazado de rayos físicos.
  * **LOD 3 ($> 50\text{m}$):** Virtualización total (Voice Culling / 0% uso de CPU en hilos de física).

---

## 💨 9. Damping Atmosférico y Efecto Doppler Dinámico

* **Damping del Aire:** Filtrado LPF dinámico dependiente de la distancia ($f_{\text{cutoff}}(d) = \text{clamp}(20000 \cdot e^{-0.015 \cdot d}, 800.0, 20000.0)$), convirtiendo disparos lejanos en retumbos graves de forma física.
* **Efecto Doppler:** Modulación continua de pitch por velocidad relativa vectorial para proyectiles rozando al jugador, vehículos o drones (*whiz-by / fly-by* cinemático).

---

## 🎧 10. Percepción de Elevación Vertical y Sombra de Cabeza (Pinna Spectral Notches)

* Muescas espectrales en bandas de $6\text{kHz} - 10\text{kHz}$ según la elevación vertical $\theta_{\text{elev}}$ para distinguir con claridad si un dron vuela por encima o si un enemigo corre en el piso inferior.

---

## 🧠 11. Pipeline Global de Inmersión AAA

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OPENDOU AAA SPATIAL ACOUSTIC PIPELINE                    │
├───────────────────────┬───────────────────────────┬─────────────────────────┤
│ 1. PROPAGACIÓN DIRECTA│ 2. REFLEXIÓN TEMPRANA     │ 3. REVERBERACIÓN TARDÍA │
│  • Air Damping        │  • Early Reflections (6x) │  • Room Volume RT60     │
│  • Doppler Shift      │  • Slapback por Material  │  • Room Coupling Portal │
│  • Obstrucción 3D     │  • Comb Filter Pasillos   │  • Oclusión Ley Masas   │
│  • Edge Diffraction   │  • Material Absorption    │  • FDN Spatial Matrix   │
│  • Spline Emitters    │  • Acoustic LOD (0-3)     │  • HDR Loudness Window  │
└───────────────────────┴───────────────────────────┴─────────────────────────┘
```
