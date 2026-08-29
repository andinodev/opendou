Para evitar saturar la CPU en plataformas móviles durante escenas de alta acústica (como múltiples ráfagas y colisiones simultáneas en entornos como *Daddy Dummie*), el sistema de virtualización separa la lógica del evento de su decodificación en hardware.

Un sonido "virtual" sigue avanzando en el tiempo matemáticamente, pero libera su canal del `AudioServer` para dárselo a un sonido más importante.

### 1. Estados de Voz y Modos de Retorno

Primero, definimos cómo se comporta un evento cuando pierde su canal físico y pasa a ser virtual.

```cpp
enum VoiceState {
    STATE_PHYSICAL, // Consumiendo CPU/DSP (Se escucha)
    STATE_VIRTUAL,  // Mudo, pero avanzando lógicamente
    STATE_KILLED    // Destruido por falta de recursos
};

enum VirtualizationMode {
    VIRTUAL_PLAY_FROM_START, // Al recuperar el canal, reinicia el audio
    VIRTUAL_ELAPSED_TIME,    // Adelanta el cabezal (seek) al tiempo que debería ir
    VIRTUAL_RESUME,          // Quita la pausa desde donde se quedó
    VIRTUAL_KILL_VOICE       // Si no hay canal físico, destruye la instancia
};

```

### 2. Cálculo de Relevancia (Audibilidad Acumulada)

El corazón del *voice stealing* es la métrica de prioridad dinámica. No basta con la prioridad base del diseñador; un sonido muy importante pero que está a 5 kilómetros no debe robarle el canal a un sonido secundario que está a 1 metro del jugador.

Dentro de nuestra clase `EventInstance` (diseñada en el paso anterior), agregamos la evaluación de su peso actual:

```cpp
float EventInstance::calculate_dynamic_weight(const Vector3& listener_position) {
    // 1. Prioridad base definida en el Inspector (ej. 0 a 100)
    float weight = definition->base_priority;
    
    // 2. Multiplicar por el volumen final resultante (RTPCs + Atenuación)
    // Convertimos dB a amplitud lineal (0.0 a 1.0) para cálculos proporcionales
    float linear_volume = db_to_linear(this->current_volume_db);
    weight *= linear_volume;
    
    // 3. Modificador opcional por distancia (priorizar sonidos cercanos)
    float distance = this->position.distance_to(listener_position);
    if (distance > definition->max_distance) {
        weight = 0.0f; // Fuera de rango, peso nulo
    }
    
    return weight;
}

```

### 3. El Pool Manager (Gestor de Canales)

Esta clase administra una matriz fija de decodificadores físicos (ej. 64 voces máximas). Se ejecuta al final del proceso de audio, evaluando a todos los candidatos y decidiendo quién vive y quién se virtualiza.

```cpp
class VoicePoolManager : public RefCounted {
    GDCLASS(VoicePoolManager, RefCounted)
private:
    int max_physical_voices = 64;
    
    // Nodos físicos reales (AudioStreamPlayer o buffers GDExtension)
    Vector<Ref<AudioPhysicalChannel>> hardware_channels;

public:
    // Se invoca cada frame desde el AudioEventManager
    void resolve_voice_stealing(Vector<Ref<EventInstance>>& active_instances, Vector3 listener_pos) {
        
        // 1. Actualizar el peso de todas las instancias vivas
        for (Ref<EventInstance>& instance : active_instances) {
            instance->current_weight = instance->calculate_dynamic_weight(listener_pos);
            
            // Avanzar reloj interno si es virtual (VIRTUAL_ELAPSED_TIME)
            if (instance->state == STATE_VIRTUAL) {
                instance->logical_playback_position += get_process_delta_time();
            }
        }

        // 2. Ordenar todas las instancias de MAYOR a MENOR peso
        active_instances.sort_custom<WeightComparator>();

        // 3. Asignar canales físicos a los ganadores (Top 64)
        for (int i = 0; i < active_instances.size(); i++) {
            Ref<EventInstance>& instance = active_instances[i];
            
            if (i < max_physical_voices && instance->current_weight > 0.01f) {
                if (instance->state == STATE_VIRTUAL) {
                    devirtualize(instance); // Devuelve el canal físico y hace 'seek'
                }
            } else {
                // Perdedores o inaudibles
                if (instance->state == STATE_PHYSICAL) {
                    virtualize(instance); // Libera el canal hardware
                }
            }
        }
    }

private:
    struct WeightComparator {
        bool operator()(const Ref<EventInstance>& a, const Ref<EventInstance>& b) const {
            return a->current_weight > b->current_weight;
        }
    };
    
    void virtualize(Ref<EventInstance>& instance) {
        if (instance->definition->virtualization_mode == VIRTUAL_KILL_VOICE) {
            instance->state = STATE_KILLED;
            instance->stop_logical_timer();
        } else {
            instance->state = STATE_VIRTUAL;
            // Liberamos el nodo del motor
            hardware_channels[instance->assigned_channel_id]->stop(); 
            instance->assigned_channel_id = -1;
        }
    }

    void devirtualize(Ref<EventInstance>& instance) {
        int free_channel = find_free_channel();
        instance->assigned_channel_id = free_channel;
        instance->state = STATE_PHYSICAL;
        
        Ref<AudioPhysicalChannel> channel = hardware_channels[free_channel];
        channel->set_stream(instance->definition->base_stream);
        
        if (instance->definition->virtualization_mode == VIRTUAL_ELAPSED_TIME) {
            channel->play(instance->logical_playback_position); // Seek al tiempo exacto
        } else {
            channel->play(0.0f);
        }
    }
};

```

### Reglas de Prevención de Artefactos

Para que este robo masivo de canales no suene como un "clic" o un corte brusco (*glitching*) en los altavoces:

* **Micro-Fades:** La función `virtualize()` no debe llamar a `stop()` instantáneamente. Debe inyectar un *fade-out* ultracorto (ej. 10 ms) al buffer PCM antes de liberar el canal.
* **Histéresis:** Si un sonido está en el límite (oscilando entre el puesto 64 y 65 de prioridad), saltará entre virtual y físico en cada *frame*. Se añade una penalización del 5% al peso de los sonidos virtuales para que necesiten "ganar por un margen claro" antes de recuperar un canal.