# Extension nativa de OpenDou: el DSP que GDScript no puede hacer.
#
# Fase 7B. La forma normal de compilar es `./build.sh` (fija dependencias, compila
# godot-cpp y esto, y firma). Este CMake reutiliza el godot-cpp ya compilado en
# build/godot-cpp para no recompilarlo con cada cambio de la extension.
cmake_minimum_required(VERSION 3.22)
project(opendou_native LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(OPENDOU_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/..")
set(GODOTCPP_SRC "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/godot-cpp")
set(GODOTCPP_BUILD "${CMAKE_CURRENT_SOURCE_DIR}/build/godot-cpp")
set(STEAMAUDIO_DIR "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/steamaudio")
set(OUTPUT_DIR "${OPENDOU_ROOT}/addons/opendou/bin")

# godot-cpp precompilado.
file(GLOB GODOTCPP_LIB "${GODOTCPP_BUILD}/bin/libgodot-cpp*.a")
if(NOT GODOTCPP_LIB)
    message(FATAL_ERROR "No se encontro godot-cpp compilado en ${GODOTCPP_BUILD}/bin. Ver el comentario de cabecera.")
endif()
list(GET GODOTCPP_LIB 0 GODOTCPP_LIB)
add_library(godot-cpp STATIC IMPORTED)
set_target_properties(godot-cpp PROPERTIES
    IMPORTED_LOCATION "${GODOTCPP_LIB}"
    INTERFACE_INCLUDE_DIRECTORIES "${GODOTCPP_SRC}/include;${GODOTCPP_BUILD}/gen/include"
)

# Steam Audio (binaria, 4.8.1).
if(APPLE)
    set(PHONON_LIB "${STEAMAUDIO_DIR}/lib/osx/libphonon.dylib")
elseif(WIN32)
    set(PHONON_LIB "${STEAMAUDIO_DIR}/lib/windows-x64/phonon.lib")
else()
    set(PHONON_LIB "${STEAMAUDIO_DIR}/lib/linux-x64/libphonon.so")
endif()
if(NOT EXISTS "${PHONON_LIB}")
    message(FATAL_ERROR "No se encontro Steam Audio en ${PHONON_LIB}. Ver thirdparty/README.md.")
endif()

add_library(opendou_native SHARED
    src/register_types.cpp
    src/steam_audio_context.cpp
    src/spatial_stream.cpp
    src/acoustic_scene.cpp
    src/simulator.cpp
    src/gain_effect.cpp
)
target_include_directories(opendou_native PRIVATE "${STEAMAUDIO_DIR}/include")
target_link_libraries(opendou_native PRIVATE godot-cpp "${PHONON_LIB}")

# Godot elige la libreria por plataforma y configuracion desde el .gdextension. El spike
# compila una sola (release) que sirve tambien al editor.
set(LIB_NAME "opendou_native.macos.template_release")
if(WIN32)
    set(LIB_NAME "opendou_native.windows.template_release.x86_64")
elseif(NOT APPLE)
    set(LIB_NAME "opendou_native.linux.template_release.x86_64")
endif()
set_target_properties(opendou_native PROPERTIES
    OUTPUT_NAME "${LIB_NAME}"
    PREFIX "lib"
    LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_DIR}"
    POSITION_INDEPENDENT_CODE ON
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
    # libphonon se busca como @rpath/libphonon.dylib: junto a nuestra libreria.
    BUILD_WITH_INSTALL_RPATH ON
    INSTALL_RPATH "@loader_path"
    MACOSX_RPATH ON
)
if(APPLE)
    set_target_properties(opendou_native PROPERTIES OSX_DEPLOYMENT_TARGET "11.0")
    # La copia de libphonon y la firma AD HOC de ambas librerias. Sin firma, macOS se niega a
    # cargar una dylib que venga marcada en cuarentena por la descarga -y el SDK de Steam
    # Audio viene asi-: dlopen falla con "Library not loaded: @rpath/libphonon.dylib" aunque
    # la libreria este justo al lado. Para distribuir hara falta firma real y notarizacion;
    # para desarrollar, esto basta.
    add_custom_command(TARGET opendou_native POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${PHONON_LIB}" "${OUTPUT_DIR}/libphonon.dylib"
        COMMAND xattr -d com.apple.quarantine "${OUTPUT_DIR}/libphonon.dylib" 2>/dev/null || true
        COMMAND codesign --force -s - "${OUTPUT_DIR}/libphonon.dylib"
        COMMAND codesign --force -s - "$<TARGET_FILE:opendou_native>"
        COMMENT "Copiando libphonon.dylib junto a la extension y firmando ad hoc"
    )
endif()
