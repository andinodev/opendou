Es la decisión arquitectónica más sólida comenzar por los contenedores lógicos. Utilizar un enfoque *bottom-up* te permite validar el comportamiento en el editor de Godot inmediatamente con archivos `.wav` sueltos, mucho antes de programar la complejidad de los SoundBanks, la memoria virtual o el servidor TCP.

Estos contenedores forman el **Árbol de Decisión del Audio**. El Gestor de Eventos simplemente le preguntará al contenedor raíz: *"Dadas las variables actuales del juego, ¿qué archivos físicos de audio debo reproducir y con qué volumen/tono?"*

Aquí tienes el diseño en C++ (GDExtension) basado en el **Patrón Composite**, lo que permite anidar contenedores infinitamente (ej. un `Switch` que contiene varios `Random`, que a su vez contienen `Blend`).

### 1. La Interfaz Base y el Contexto

Todos los contenedores y los archivos de audio finales heredarán de una clase base abstracta. Para resolverse, necesitan un "Contexto" (las variables RTPC y Switches activos en ese fotograma).

```cpp
// Contexto inyectado por el EventManager en el momento del disparo
struct AudioPlaybackContext {
    HashMap<StringName, float> rtpc_values;
    HashMap<StringName, StringName> switch_states; 
};

// Resultado de la resolución (Lo que realmente irá al AudioServer)
struct ResolvedVoice {
    Ref<AudioStream> stream;
    float volume_offset_db = 0.0f;
    float pitch_modifier = 1.0f;
};

// Clase Base para todo el grafo (Hereda de Resource para verse en el Inspector)
class AudioLogicNode : public Resource {
    GDCLASS(AudioLogicNode, Resource)
public:
    // Retorna true si resolvió algo, llenando el array out_voices
    virtual bool resolve(const AudioPlaybackContext& context, Vector<ResolvedVoice>& out_voices) = 0;
};

// Nodo Hoja (El archivo físico final)
class AudioPhysicalNode : public AudioLogicNode {
    GDCLASS(AudioPhysicalNode, AudioLogicNode)
public:
    Ref<AudioStream> stream;
    
    bool resolve(const AudioPlaybackContext& context, Vector<ResolvedVoice>& out_voices) override {
        if (stream.is_valid()) {
            out_voices.push_back({stream, 0.0f, 1.0f});
            return true;
        }
        return false;
    }
};

```

### 2. Random Container (Selección Estocástica)

Su objetivo es evitar la fatiga auditiva (efecto ametralladora) al repetir el mismo sonido. Implementa un sistema *Shuffle* (como una bolsa de piezas de Tetris) o ponderación.

```cpp
class AudioRandomContainer : public AudioLogicNode {
    GDCLASS(AudioRandomContainer, AudioLogicNode)
private:
    TypedArray<AudioLogicNode> children;
    
    // Configuración
    bool use_shuffle = true;
    int no_repeat_count = 1; // Cuántos turnos antes de repetir un sonido
    
    // Estado en tiempo de ejecución (Debe separarse si múltiples entidades lo usan)
    Vector<int> play_history; 

public:
    bool resolve(const AudioPlaybackContext& context, Vector<ResolvedVoice>& out_voices) override {
        if (children.is_empty()) return false;
        
        int selected_index = -1;
        // Lógica de Shuffle: Elegir un random, verificar play_history
        // Si el índice está en el historial, tirar los dados de nuevo
        selected_index = pick_random_with_rules(); 
        
        // Modulación aleatoria por disparo (Jitter)
        float random_pitch = Math::random(-0.1f, 0.1f);
        float random_vol = Math::random(-2.0f, 0.0f);
        
        Ref<AudioLogicNode> child = children[selected_index];
        
        // Recursividad: Le pedimos al hijo que se resuelva
        Vector<ResolvedVoice> temp_voices;
        if (child->resolve(context, temp_voices)) {
            for (ResolvedVoice& v : temp_voices) {
                v.pitch_modifier *= (1.0f + random_pitch);
                v.volume_offset_db += random_vol;
                out_voices.push_back(v);
            }
            return true;
        }
        return false;
    }
};

```

### 3. Switch Container (Decisión por Estado)

Evalúa una variable de estado (Switch) discreta del juego y elige un único camino. Ideal para los pasos según el material (Tierra, Metal, Agua) en *Daddy Dummie*.

```cpp
class AudioSwitchContainer : public AudioLogicNode {
    GDCLASS(AudioSwitchContainer, AudioLogicNode)
private:
    StringName switch_group_name; // ej. "Surface_Type"
    StringName default_state;     // ej. "Concrete"
    
    // Diccionario de Estado -> Nodo
    Dictionary state_mappings; 

public:
    bool resolve(const AudioPlaybackContext& context, Vector<ResolvedVoice>& out_voices) override {
        StringName current_state = default_state;
        
        // Buscar el estado actual en el contexto inyectado
        if (context.switch_states.has(switch_group_name)) {
            current_state = context.switch_states[switch_group_name];
        }
        
        if (state_mappings.has(current_state)) {
            Ref<AudioLogicNode> child = state_mappings[current_state];
            return child->resolve(context, out_voices);
        }
        return false;
    }
};

```

### 4. Blend Container (Mezcla Multicapa Simultánea)

A diferencia de los anteriores que eligen **un** camino, el Blend Container ejecuta **múltiples** hijos simultáneamente y realiza un *crossfade* (fundido cruzado) volumétrico entre ellos basándose en una variable continua (RTPC).

```cpp
// Estructura interna para mapear una capa
struct BlendLayer {
    Ref<AudioLogicNode> node;
    Ref<Curve> volume_curve; // Eje X: RTPC, Eje Y: Volumen en dB
};

class AudioBlendContainer : public AudioLogicNode {
    GDCLASS(AudioBlendContainer, AudioLogicNode)
private:
    StringName rtpc_parameter; // ej. "Engine_RPM"
    TypedArray<BlendLayer> layers; // En C++ nativo usarías un Vector<BlendLayer>

public:
    bool resolve(const AudioPlaybackContext& context, Vector<ResolvedVoice>& out_voices) override {
        float current_rtpc_value = 0.0f;
        
        if (context.rtpc_values.has(rtpc_parameter)) {
            current_rtpc_value = context.rtpc_values[rtpc_parameter];
        }
        
        bool resolved_any = false;
        
        for (int i = 0; i < layers.size(); i++) {
            BlendLayer layer = layers[i];
            
            // Evaluar la curva Spline para esta capa en base a los RPM actuales
            float calculated_volume_db = layer.volume_curve->sample_baked(current_rtpc_value);
            
            // Optimización: Si la capa está en absoluto silencio (-80dB), no la instanciamos
            if (calculated_volume_db <= -80.0f) continue;
            
            Vector<ResolvedVoice> layer_voices;
            if (layer.node->resolve(context, layer_voices)) {
                for (ResolvedVoice& v : layer_voices) {
                    v.volume_offset_db += calculated_volume_db;
                    out_voices.push_back(v);
                }
                resolved_any = true;
            }
        }
        return resolved_any;
    }
};

```