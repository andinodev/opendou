# Propuesta de Evolución: Motor Acústico AAA, Reflexiones Tempranas e Inmersión Inteligente

**Documento de Idea:** `021-aaa-spatial-acoustics-and-immersion.md`  
**Módulo:** `addons/opendou/runtime/spatial`, `addons/opendou/core`, `addons/opendou/nodes`  
**Estado:** Análisis & Brainstorming de Próxima Generación

---

## 🎯 Visión: Elevando OpenDou al Estándar Wwise / FMOD / Metasound

Para que los sonidos dentro del juego trasciendan de simples reproducciones estáticas a una **experiencia acústica viva, orgánica e hiperrealista**, OpenDou debe simular la física con la que el sonido interactúa con los materiales, el aire, las esquinas y los volúmenes arquitectónicos.

A continuación se detallan las tecnologías y módulos inteligentes que llevarán la espacialización y la inmersión al siguiente nivel:

---

## 🚀 1. Reflexiones Tempranas Dinámicas y Ecos por Material (Early Reflections & Slapback Echoes)

* **El Concepto:** En el mundo real, no solo escuchamos el sonido directo y la cola difusa de reverb; escuchamos los primeros rebotes rápidos ($10\text{ms} - 80\text{ms}$) contra el suelo, techo y paredes cercanas.
* **Mecánica Inteligente:**
  * **Image-Source Acoustic Raytracer:** Cada emisor lanza rayos sonda primarios hacia las 6 superficies más cercanas.
  * **Respuesta según Material:**
    * *Metal / Vidrio:* Ecos brillantes y nítidos con muy poca amortiguación en altas frecuencias.
    * *Hormigón / Ladrillo:* Slapback seco, duro e inmediato.
    * *Madera:* Reflejos cálidos con atenuación suave de agudos.
    * *Follaje / Alfombras / Cortinas:* Absorción casi total (silencio de reflexiones).
  * **Espacio Libre:** En habitaciones estrechas (ej. pasillos de metal), los ecos se agrupan creando un efecto de *Flanging / Comb Filtering* metálico natural; en grandes hangares o azoteas, el eco se retrasa convirtiéndose en un slapback cinematográfico.

---

## 🌫️ 2. Difracción Dinámica en Esquinas y Bordes (Obstacle Edge Diffraction)

* **El Concepto:** Cuando un enemigo o fuente de sonido está detrás de una columna o esquina sin puerta, el sonido no se corta bruscamente: "se dobla" alrededor del borde geométrico (Principio de Huygens-Fresnel).
* **Mecánica Inteligente:**
  * Detecta el borde más cercano del colisionador y calcula el ángulo de sombra acústica.
  * **Desplazamiento de Fuente Virtual:** El sonido no se percibe detrás del muro macizo, sino que el paneo 3D se desplaza visual y acústicamente hacia la esquina libre, filtrando las frecuencias altas con una curva de difracción suave.

---

## 🧱 3. Transmisión a través de Muros por Grosor y Densidad (Wall Penetration & Mass Law)

* **El Concepto:** Un muro de tabique fino o una ventana de cristal dejan pasar frecuencias medias y agudas, mientras que un búnker de hormigón de 1 metro solo deja pasar sub-graves amortiguados.
* **Mecánica Inteligente:**
  * **Raycast de Doble Penetración:** Mide el punto de entrada y el punto de salida en la geometría para calcular el espesor real del obstáculo ($\Delta x$).
  * Aplica la **Ley de Masas Acústica**:
    $$\text{Atenuación}_{\text{dB}} = 20 \log_{10}(f \cdot \rho \cdot \Delta x) - K$$
  * Permite escuchar conversaciones amortiguadas (*muffled voices*) o pasos en la habitación contigua según el grosor y material de la pared que los separa.

---

## 💨 4. Damping Atmosférico y Absorción del Aire por Distancia (Air Absorption)

* **El Concepto:** Las moléculas de aire absorben la energía de las frecuencias altas mucho más rápido que las graves a medida que la onda viaja en la distancia.
* **Mecánica Inteligente:**
  * Curva de filtrado LPF dinámico dependiente de la distancia física ($d$):
    $$f_{\text{cutoff}}(d) = \text{clamp}\left(20000 \cdot e^{-0.015 \cdot d}, 800.0, 20000.0\right)$$
  * Los disparos y explosiones lejanas pierden su chasquido inicial agudo y se convierten en retumbos graves y pesados de forma automática y físicamente precisa.

---

## 🏎️ 5. Efecto Doppler Dinámico y Compresión de Onda por Velocidad (Doppler Shift)

* **El Concepto:** Objetos en movimiento rápido (vehículos, drones, abejas cibernéticas, proyectiles rozando al jugador) deben comprimir y descomprimir la longitud de onda.
* **Mecánica Inteligente:**
  * Modulación de pitch basada en la velocidad relativa vectorial $\vec{v}_{\text{rel}}$ entre emisor y oyente:
    $$f' = f \cdot \frac{c + \vec{v}_{\text{listener}} \cdot \hat{u}}{c - \vec{v}_{\text{emitter}} \cdot \hat{u}}$$
  * Genera el auténtico efecto *whiz-by / fly-by* cinemático sin necesidad de trucos de audio pregrabados.

---

## 🚪 6. Apertura Angular Progresiva en Portales (Portal Sound Spread)

* **El Concepto:** Al escuchar una sala a través de una puerta lejana, el sonido parece provenir de un punto estrecho ($Spread \approx 15^\circ$). Al acercarte a la puerta y cruzarla, el sonido debe envolver progresivamente tu campo auditivo ($Spread \to 180^\circ \to 360^\circ$).
* **Mecánica Inteligente:**
  * Modulación automática del ancho estéreo / surround del emisor virtual del portal en función de la distancia y el ángulo del jugador con el marco del portal.

---

## 🎧 7. Percepción de Altura y Sombra de Cabeza (Head Shadow Effect / HRTF Pinna Notches)

* **El Concepto:** Distinguir si un sonido viene exactamente de arriba (dron o francotirador en tejado) o de abajo (enemigo en el sótano) requiere emular cómo las orejas (pabellón auricular / *pinna*) filtran ciertas bandas de frecuencia ($6\text{kHz} - 10\text{kHz}$).
* **Mecánica Inteligente:**
  * Aplicación de muescas de ecualización dinámicas (*pinna spectral notches*) según el ángulo de elevación vertical $\theta_{\text{elev}}$.

---

## 🧠 8. Integración Global y Cohesión del Middleware

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OPENDOU AAA SPATIAL ACOUSTIC PIPELINE                    │
├───────────────────────┬───────────────────────────┬─────────────────────────┤
│ 1. PROPAGACIÓN DIRECTA│ 2. REFLEXIÓN TEMPRANA     │ 3. REVERBERACIÓN TARDÍA │
│  • Air Damping        │  • Early Reflections (6x) │  • Volume Sabine RT60   │
│  • Doppler Shift      │  • Slapback por Material  │  • Damping por Sala     │
│  • Edge Diffraction   │  • Material Absorption    │  • Portal Bleed Flow    │
│  • Wall Thickness     │  • Comb Filter Pasillos   │  • FDN Spatial Matrix   │
└───────────────────────┴───────────────────────────┴─────────────────────────┘
```

Este pipeline completo garantiza que cada sala, pasillo, muro o exterior reaccione con inteligencia física en tiempo real, ofreciendo una experiencia auditiva indistinguible de los motores de middleware más avanzados del mercado.
