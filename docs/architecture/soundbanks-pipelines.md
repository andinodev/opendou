En proyectos móviles con alta densidad de assets como *Daddy Dummie* o *Crónicas de Jesika*, cargar todos los efectos musicales y sonoros en memoria RAM colapsa el dispositivo, pero leerlos bajo demanda desde el almacenamiento introduce latencia (*input lag*).

El pipeline de SoundBanks resuelve esto mediante el **Prefetching**: se extraen los primeros milisegundos de cada pista y se guardan permanentemente en RAM. Cuando se dispara el evento, el sonido comienza a reproducirse instantáneamente desde la memoria mientras un hilo secundario lee el resto de la pista desde el disco y los une sin interrupciones.

### 1. El Formato Binario Personalizado (`.sbk`)

Necesitamos diseñar un empaquetado binario monolítico. Al compilar el juego, el editor escaneará todos los `AudioEventDef` y escribirá un archivo `.sbk` (SoundBank) estructurado en cuatro bloques:

```text
[ BLOCK 1: HEADER ] (Firma mágica, versión, tamaño total)
[ BLOCK 2: INDEX / TOC ] (Tabla de contenidos: ID de Stream -> Offsets)
[ BLOCK 3: PREFETCH DATA ] (Bloque contiguo cargado íntegramente en RAM)
[ BLOCK 4: STREAM DATA ] (Cuerpo principal, permanece en disco)

```

En C++ (GDExtension), las estructuras de lectura serían:

```cpp
struct SoundBankHeader {
    char magic[4] = {'G','S','B','K'}; // Identificador
    uint32_t version = 1;
    uint32_t total_entries;
    uint32_t prefetch_block_size; // Tamaño a reservar en RAM
};

struct StreamEntry {
    uint32_t stream_id;           // Hash del nombre del archivo
    uint16_t channels;            // 1 Mono, 2 Estéreo
    uint32_t sample_rate;         // ej. 44100
    
    // Punteros al bloque de RAM (Prefetch)
    uint32_t prefetch_offset;
    uint32_t prefetch_length;     // Típicamente ~64 KB (aprox. 350 ms)
    
    // Punteros al archivo en disco (Stream)
    uint64_t disk_stream_offset;
    uint64_t disk_stream_length;
};

```

### 2. El Pipeline de Compilación (Godot Editor Tool)

Crearemos un `EditorPlugin` que recorra nuestra jerarquía de audio al exportar el juego.

1. **Recolección:** Busca todos los recursos `.wav` u `.ogg` referenciados por los eventos del SoundBank específico (ej. `Armas.sbk`, `Musica_Jefe.sbk`).
2. **Corte (Slicing):** Lee los primeros `N` bytes (el prefetch) de cada decodificador PCM y los apila en un único gran bloque binario (Block 3).
3. **Escritura:** Apila el audio restante de todos los archivos secuencialmente en el Block 4 y calcula los offsets exactos (Block 2).

### 3. El Gestor de Streaming (Runtime C++)

Durante el juego, necesitamos un hilo de lectura asíncrono para no congelar los fotogramas gráficos mientras el disco gira o la memoria flash responde.

```cpp
class SoundBankManager : public Node {
    GDCLASS(SoundBankManager, Node)
private:
    // La RAM pre-cargada: Un solo bloque de memoria contiguo por banco para evitar fragmentación
    HashMap<StringName, PackedByteArray> bank_prefetch_memory;
    HashMap<uint32_t, StreamEntry> stream_registry;
    
    // Cola de peticiones para el hilo de disco
    SafeQueue<StreamRequest> disk_read_queue;
    Thread async_io_thread;

public:
    void load_bank(String bank_path) {
        Ref<FileAccess> file = FileAccess::open(bank_path, FileAccess::READ);
        // 1. Leer Header y TOC
        // 2. Extraer Block 3 completo y guardarlo en bank_prefetch_memory
        // 3. Dejar el archivo abierto (o su descriptor) para lecturas asíncronas del Block 4
    }
};

```

### 4. Fusión de Búferes: El `PrefetchAudioStreamPlayback`

Para que Godot reproduzca esto, debemos crear una clase que herede de `AudioStreamPlayback` (la interfaz nativa de Godot que alimenta el hilo de mezcla del `AudioServer`). Esta es la pieza maestra de la ingeniería de audio.

```cpp
class PrefetchAudioStreamPlayback : public AudioStreamPlayback {
    GDCLASS(PrefetchAudioStreamPlayback, AudioStreamPlayback)
private:
    StreamEntry metadata;
    const uint8_t* prefetch_ptr; // Puntero directo a la RAM precargada
    
    // Búfer circular que el hilo asíncrono llenará desde el disco
    RingBuffer<AudioFrame> stream_ring_buffer;
    
    bool is_reading_prefetch = true;
    uint32_t prefetch_cursor = 0;

public:
    virtual void start(double from_pos) override {
        is_reading_prefetch = true;
        prefetch_cursor = 0;
        
        // ¡Alerta al hilo de IO para que empiece a llenar el RingBuffer inmediatamente!
        SoundBankManager::get_singleton()->queue_disk_read(
            metadata.disk_stream_offset, 
            &stream_ring_buffer
        );
    }

    // Esta función es llamada por el hilo de Audio de Godot 100+ veces por segundo
    virtual int mix(AudioFrame *p_buffer, float p_rate_scale, int p_frames) override {
        int frames_mixed = 0;

        // Fase 1: Consumir la RAM instantánea (Prefetch)
        if (is_reading_prefetch) {
            int frames_to_read = MIN(p_frames, (metadata.prefetch_length - prefetch_cursor) / sizeof(AudioFrame));
            
            memcpy(p_buffer, prefetch_ptr + prefetch_cursor, frames_to_read * sizeof(AudioFrame));
            prefetch_cursor += frames_to_read * sizeof(AudioFrame);
            frames_mixed += frames_to_read;

            if (prefetch_cursor >= metadata.prefetch_length) {
                is_reading_prefetch = false; // Transición perfecta (Stitching)
            }
        }

        // Fase 2: Consumir el búfer circular que viene del hilo de disco
        if (!is_reading_prefetch && frames_mixed < p_frames) {
            int remaining_frames = p_frames - frames_mixed;
            int frames_from_disk = stream_ring_buffer.read(p_buffer + frames_mixed, remaining_frames);
            frames_mixed += frames_from_disk;
        }

        return frames_mixed;
    }
};

```

Con este sistema, cuando se dispara un arma, la lectura inicial de `mix()` toma los datos directamente de la memoria local, obteniendo latencia cero. Mientras esos 350 milisegundos se están escuchando, el `async_io_thread` tiene tiempo de sobra para despertar, buscar en el disco sólido, llenar el `stream_ring_buffer` y estar listo para que el `mix()` empalme el resto de la pista sin interrupción, manteniendo un consumo general de memoria RAM mínimo.