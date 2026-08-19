/*
 * 音频引擎：封装 OHAudio 采集（调音器）与渲染（节拍器）
 *
 * 设计：
 *  - AudioEngine 单例，管理两个 OHAudio 流
 *  - 采集回调线程内做 YIN 音高检测，通过回调把结果推到 ArkTS
 *  - 渲染回调线程内用 TempoEngine 做节拍调度，混入合成 click
 *  - 回调线程不调用 UI；通过 std::function 回调 + N-API 线程安全函数投递到主线程
 */

#ifndef AUDIO_ENGINE_H
#define AUDIO_ENGINE_H

#include <ohaudio/native_audiocapturer.h>
#include <ohaudio/native_audiorenderer.h>
#include <functional>
#include <memory>
#include <mutex>
#include <atomic>

#include "dsp/pitch_detector.h"
#include "dsp/tempo_engine.h"
#include "dsp/ring_buffer.h"

// 音频引擎回调类型
using PitchResultCallback = std::function<void(float freqHz)>;
using BeatEventCallback = std::function<void(int beatIndex, int beatsPerBar, int bar)>;

class AudioEngine {
public:
    static AudioEngine& instance();

    AudioEngine(const AudioEngine&) = delete;
    AudioEngine& operator=(const AudioEngine&) = delete;

    // ===== 调音器（采集） =====
    bool startCapture();
    void stopCapture();
    bool isCapturing() const { return capturing_.load(); }

    // 采集参数
    void setCaptureSampleRate(int sr) { captureSampleRate_ = sr; }
    void setPitchCallback(PitchResultCallback cb) { pitchCb_ = std::move(cb); }

    // ===== 节拍器（渲染） =====
    bool startMetronome(float bpm, int beatsPerBar);
    void stopMetronome();
    bool isMetronomeRunning() const { return metronomeRunning_.load(); }

    // 节拍参数（可在运行中调整）
    void setBpm(float bpm);
    void setTimeSignature(int beatsPerBar);
    void setSubdivide(int subdivide);
    void setClickFrequency(float freq);
    void setClickTimbre(int timbre);
    void setClickGain(float gain);
    void setBeatLevel(int beatIndex, int level);
    void setAccentEnabled(bool on);
    void setVibrateOnBeat(bool on);
    void setBeatEventCallback(BeatEventCallback cb) { beatCb_ = std::move(cb); }

    // 当前拍信息（UI 轮询）
    int currentBeat() const { return tempo_.currentBeat(); }
    int currentBar() const { return tempo_.currentBar(); }

    // 采样率
    static constexpr int kDefaultSampleRate = 48000;

private:
    AudioEngine();
    ~AudioEngine();

    // OHAudio 回调
    static void OnReadData(OH_AudioCapturer* capturer, void* userData,
                           void* audioData, int32_t audioDataSize);
    static OH_AudioData_Callback_Result OnWriteData(OH_AudioRenderer* renderer, void* userData,
                                                    void* audioData, int32_t audioDataSize);

    // 内部处理
    void processPcm(const int16_t* data, int32_t frames);
    void processRender(int16_t* data, int32_t frames);

    // OHAudio 对象
    OH_AudioCapturer* capturer_ = nullptr;
    OH_AudioStreamBuilder* capturerBuilder_ = nullptr;
    OH_AudioRenderer* renderer_ = nullptr;
    OH_AudioStreamBuilder* rendererBuilder_ = nullptr;

    // 采集配置
    int captureSampleRate_ = kDefaultSampleRate;
    std::atomic<bool> capturing_{false};
    std::unique_ptr<PitchDetector> detector_;
    std::unique_ptr<PitchDetector> highDetector_;

    // 采集累积缓冲（攒够分析窗口再做音高检测）
    RingBuffer captureBuffer_{kMaxAnalysisWindow};
    // 85ms @48kHz，可覆盖吉他/贝斯/古琴低音，同时保留滑动检测响应速度
    static constexpr int kAnalysisWindow = 4096;
    static constexpr int kMaxAnalysisWindow = 8192;
    std::vector<int16_t> analysisWindow_;
    std::vector<int16_t> downsampleWindow_;
    int64_t lastDetectSample_ = 0;   // 上一次检测时的全局采样计数
    int64_t captureSampleCount_ = 0; // 全局采样计数

    // 音高稳定性过滤：记录最近几次检测，只推送稳定的音高
    float lastFreq_ = -1.0f;
    float smoothedFreq_ = -1.0f;
    float noiseFloorRms_ = 20.0f;
    int stableCount_ = 0;          // 连续命中同一频率的次数
    int dropCount_ = 0;            // 连续检测失败次数
    int diagnosticCounter_ = 0;
    static constexpr int kStableThreshold = 2;
    static constexpr float kFreqToleranceCents = 28.0f;
    static constexpr int kMaxDropCount = 40; // 约 1.6 秒保持，避免古琴短音刚出现就被清空

    // 渲染配置
    std::atomic<bool> metronomeRunning_{false};
    TempoEngine tempo_;
    std::mutex tempoMutex_;

    // 回调
    PitchResultCallback pitchCb_;
    BeatEventCallback beatCb_;
};

#endif // AUDIO_ENGINE_H
