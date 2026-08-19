# the minimum version of CMake.
cmake_minimum_required(VERSION 3.5.0)
project(StarTuner)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

add_library(entry SHARED
    napi_init.cpp
    audio/audio_engine.cpp
    dsp/pitch_detector.cpp
    dsp/click_synth.cpp
    dsp/tempo_engine.cpp
)

target_link_libraries(entry PUBLIC
    libace_napi.z.so
    libohaudio.so
    libhilog_ndk.z.so
)

# Native regression executable. It is excluded from normal app builds and can be
# built explicitly with: ninja pitch_detector_regression
add_executable(pitch_detector_regression EXCLUDE_FROM_ALL
    ../../../../tests/pitch_detector_regression.cpp
    dsp/pitch_detector.cpp
)
target_compile_features(pitch_detector_regression PRIVATE cxx_std_17)

# Spectral/energy regression for the metronome's instrument-cutting click.
add_executable(metronome_audio_regression EXCLUDE_FROM_ALL
    ../../../../tests/metronome_audio_regression.cpp
    dsp/click_synth.cpp
    dsp/tempo_engine.cpp
)
target_compile_features(metronome_audio_regression PRIVATE cxx_std_17)
