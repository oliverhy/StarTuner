/*
 * N-API 桥接层：暴露 AudioEngine 能力给 ArkTS
 *
 * 导出的方法：
 *  - startCapture() / stopCapture()
 *  - startMetronome(bpm, beatsPerBar) / stopMetronome()
 *  - setBpm / setTimeSignature / setSubdivide / setClickFrequency / setClickTimbre / setClickGain
 *  - setAccentEnabled / setVibrateOnBeat
 *  - 回调注册：registerPitchCallback(cb) / registerBeatCallback(cb)
 *
 * 说明：
 *  - 音频回调在 native 音频线程，不能直接调用 JS
 *  - 用 napi_threadsafe_function 把结果投递到 ArkTS 主线程
 */

#include <napi/native_api.h>
#include <string>
#include <mutex>

#include "audio/audio_engine.h"

namespace {

// 线程安全函数（投递到 JS 主线程）
napi_threadsafe_function g_pitchTsFn = nullptr;
napi_threadsafe_function g_beatTsFn = nullptr;

// 注册时记录的回调类型标记
bool g_pitchRegistered = false;
bool g_beatRegistered = false;

// ---- 线程安全函数调用（音频线程 -> JS 主线程）----

void PitchTsCall(napi_env env, napi_value js_cb, void* context, void* data) {
    // 在 JS 主线程执行
    if (env && js_cb) {
        float* freqPtr = static_cast<float*>(data);
        float freq = *freqPtr;
        delete freqPtr;
        napi_value argv[1];
        napi_create_double(env, static_cast<double>(freq), &argv[0]);
        napi_value global;
        napi_get_global(env, &global);
        napi_call_function(env, global, js_cb, 1, argv, nullptr);
    }
}

void BeatTsCall(napi_env env, napi_value js_cb, void* context, void* data) {
    if (env && js_cb) {
        int* beatPtr = static_cast<int*>(data);
        int beat = beatPtr[0];
        int beatsPerBar = beatPtr[1];
        int bar = beatPtr[2];
        delete[] beatPtr;
        napi_value argv[3];
        napi_create_int32(env, beat, &argv[0]);
        napi_create_int32(env, beatsPerBar, &argv[1]);
        napi_create_int32(env, bar, &argv[2]);
        napi_value global;
        napi_get_global(env, &global);
        napi_call_function(env, global, js_cb, 3, argv, nullptr);
    }
}

// ---- 原生侧回调：音频线程调用，投递到 JS ----

void OnPitchResult(float freqHz) {
    if (!g_pitchTsFn) {
        return;
    }
    float* freqPtr = new float(freqHz);
    napi_call_threadsafe_function(g_pitchTsFn, freqPtr,
                                  napi_tsfn_nonblocking);
}

void OnBeatEvent(int beat, int beatsPerBar, int bar) {
    if (!g_beatTsFn) {
        return;
    }
    int* data = new int[3];
    data[0] = beat;
    data[1] = beatsPerBar;
    data[2] = bar;
    napi_call_threadsafe_function(g_beatTsFn, data,
                                  napi_tsfn_nonblocking);
}

// ---- N-API 方法实现 ----

napi_value StartCapture(napi_env env, napi_callback_info info) {
    bool ok = AudioEngine::instance().startCapture();
    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

napi_value StopCapture(napi_env env, napi_callback_info info) {
    AudioEngine::instance().stopCapture();
    napi_value result;
    napi_get_boolean(env, true, &result);
    return result;
}

napi_value StartMetronome(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    double bpm = 100.0;
    int beats = 4;
    if (argc > 0) {
        napi_get_value_double(env, args[0], &bpm);
    }
    if (argc > 1) {
        napi_get_value_int32(env, args[1], &beats);
    }
    bool ok = AudioEngine::instance().startMetronome(static_cast<float>(bpm), beats);
    napi_value result;
    napi_get_boolean(env, ok, &result);
    return result;
}

napi_value StopMetronome(napi_env env, napi_callback_info info) {
    AudioEngine::instance().stopMetronome();
    napi_value result;
    napi_get_boolean(env, true, &result);
    return result;
}

napi_value SetBpm(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    double bpm = 100.0;
    if (argc > 0) {
        napi_get_value_double(env, args[0], &bpm);
    }
    AudioEngine::instance().setBpm(static_cast<float>(bpm));
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value SetTimeSignature(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int beats = 4;
    if (argc > 0) {
        napi_get_value_int32(env, args[0], &beats);
    }
    AudioEngine::instance().setTimeSignature(beats);
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value SetSubdivide(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int sub = 1;
    if (argc > 0) {
        napi_get_value_int32(env, args[0], &sub);
    }
    AudioEngine::instance().setSubdivide(sub);
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value SetClickFrequency(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    double freq = 1000.0;
    if (argc > 0) {
        napi_get_value_double(env, args[0], &freq);
    }
    AudioEngine::instance().setClickFrequency(static_cast<float>(freq));
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value SetClickTimbre(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int timbre = 0;
    if (argc > 0) {
        napi_get_value_int32(env, args[0], &timbre);
    }
    AudioEngine::instance().setClickTimbre(timbre);
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value SetClickGain(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    double gain = 0.7;
    if (argc > 0) {
        napi_get_value_double(env, args[0], &gain);
    }
    AudioEngine::instance().setClickGain(static_cast<float>(gain));
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value SetBeatLevel(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int beatIndex = 0;
    int level = 1;
    if (argc > 0) {
        napi_get_value_int32(env, args[0], &beatIndex);
    }
    if (argc > 1) {
        napi_get_value_int32(env, args[1], &level);
    }
    AudioEngine::instance().setBeatLevel(beatIndex, level);
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value SetAccentEnabled(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    bool on = true;
    if (argc > 0) {
        napi_get_value_bool(env, args[0], &on);
    }
    AudioEngine::instance().setAccentEnabled(on);
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value SetVibrateOnBeat(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    bool on = true;
    if (argc > 0) {
        napi_get_value_bool(env, args[0], &on);
    }
    AudioEngine::instance().setVibrateOnBeat(on);
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value GetCurrentBeat(napi_env env, napi_callback_info info) {
    int beat = AudioEngine::instance().currentBeat();
    napi_value result;
    napi_create_int32(env, beat, &result);
    return result;
}

// 注册回调（ArkTS 传入 JS 回调）
napi_value RegisterPitchCallback(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (g_pitchTsFn) {
        napi_release_threadsafe_function(g_pitchTsFn, napi_tsfn_abort);
        g_pitchTsFn = nullptr;
    }

    napi_value cb = args[0];
    napi_value asyncResourceName;
    napi_create_string_utf8(env, "PitchCallback", NAPI_AUTO_LENGTH, &asyncResourceName);

    napi_create_threadsafe_function(env, cb, nullptr, asyncResourceName, 0,
                                    1, nullptr, nullptr, nullptr, PitchTsCall,
                                    &g_pitchTsFn);
    g_pitchRegistered = true;

    // 绑定原生回调
    AudioEngine::instance().setPitchCallback(OnPitchResult);
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

napi_value RegisterBeatCallback(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (g_beatTsFn) {
        napi_release_threadsafe_function(g_beatTsFn, napi_tsfn_abort);
        g_beatTsFn = nullptr;
    }

    napi_value cb = args[0];
    napi_value asyncResourceName;
    napi_create_string_utf8(env, "BeatCallback", NAPI_AUTO_LENGTH, &asyncResourceName);

    napi_create_threadsafe_function(env, cb, nullptr, asyncResourceName, 0,
                                    1, nullptr, nullptr, nullptr, BeatTsCall,
                                    &g_beatTsFn);
    g_beatRegistered = true;

    AudioEngine::instance().setBeatEventCallback(OnBeatEvent);
    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

// 注册 N-API 方法
napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"startCapture", nullptr, StartCapture, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stopCapture", nullptr, StopCapture, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"startMetronome", nullptr, StartMetronome, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stopMetronome", nullptr, StopMetronome, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setBpm", nullptr, SetBpm, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setTimeSignature", nullptr, SetTimeSignature, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setSubdivide", nullptr, SetSubdivide, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setClickFrequency", nullptr, SetClickFrequency, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setClickTimbre", nullptr, SetClickTimbre, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setClickGain", nullptr, SetClickGain, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setBeatLevel", nullptr, SetBeatLevel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setAccentEnabled", nullptr, SetAccentEnabled, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setVibrateOnBeat", nullptr, SetVibrateOnBeat, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getCurrentBeat", nullptr, GetCurrentBeat, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"registerPitchCallback", nullptr, RegisterPitchCallback, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"registerBeatCallback", nullptr, RegisterBeatCallback, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

}  // namespace

static napi_module starTunerModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "entry",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterStarTunerModule(void) {
    napi_module_register(&starTunerModule);
}
