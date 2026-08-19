/*
 * 音频引擎实现
 */

#include "audio_engine.h"
#include <hilog/log.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <ohaudio/native_audiostreambuilder.h>

#undef LOG_TAG
#define LOG_TAG "StarTunerNative"
#define LOGD(...) OH_LOG_DEBUG(LOG_APP, __VA_ARGS__)
#define LOGI(...) OH_LOG_INFO(LOG_APP, __VA_ARGS__)
#define LOGE(...) OH_LOG_ERROR(LOG_APP, __VA_ARGS__)

namespace {
constexpr int kFrameSize = 480;      // 10ms @ 48kHz（fast 模式建议 5~20ms）
constexpr int kChannelCount = 1;
constexpr int kBytesPerSample = 2;   // S16LE
}  // namespace

AudioEngine& AudioEngine::instance() {
    static AudioEngine engine;
    return engine;
}

AudioEngine::AudioEngine()
    : detector_(new PitchDetector(kDefaultSampleRate / 2, kAnalysisWindow / 2, 20.0f, 4500.0f)),
      highDetector_(new PitchDetector(kDefaultSampleRate, kAnalysisWindow, 1500.0f, 5000.0f)) {}

AudioEngine::~AudioEngine() {
    stopCapture();
    stopMetronome();
}

// ==================== 采集回调 ====================

void AudioEngine::OnReadData(OH_AudioCapturer* capturer, void* userData,
                             void* audioData, int32_t audioDataSize) {
    AudioEngine* self = static_cast<AudioEngine*>(userData);
    if (!self || !audioData || audioDataSize <= 0) {
        return;
    }
    int32_t frames = audioDataSize / kBytesPerSample;
    self->processPcm(static_cast<const int16_t*>(audioData), frames);
}

void AudioEngine::processPcm(const int16_t* data, int32_t frames) {
    if (!capturing_.load() || !detector_) {
        return;
    }
    // 累积到环形缓冲
    captureBuffer_.write(data, frames);
    captureSampleCount_ += frames;

    // 古琴起音短、衰减快；40ms 滑动检测能更早抓住稳定振动段。
    const int64_t detectInterval = (kDefaultSampleRate * 40) / 1000;
    if (captureSampleCount_ - lastDetectSample_ < detectInterval) {
        return;
    }
    lastDetectSample_ = captureSampleCount_;

    // 取最近的完整分析窗口。
    if (analysisWindow_.empty()) {
        analysisWindow_.resize(kMaxAnalysisWindow);
    }
    size_t available = captureBuffer_.size();
    size_t win = available > kAnalysisWindow ? kAnalysisWindow : available;
    if (win < kAnalysisWindow) {
        return; // 窗口太小，不足检测
    }
    captureBuffer_.peekLatest(analysisWindow_.data(), win);

    // 两点平均后降采样到 24kHz，保留调音所需频段并把 YIN 计算量降到约四分之一。
    if (downsampleWindow_.size() != win / 2) {
        downsampleWindow_.resize(win / 2);
    }
    for (size_t i = 0; i < win / 2; ++i) {
        const int sample = static_cast<int>(analysisWindow_[i * 2]) +
            static_cast<int>(analysisWindow_[i * 2 + 1]);
        downsampleWindow_[i] = static_cast<int16_t>(sample / 2);
    }

    // 计算当前窗口能量，供自适应底噪门限使用。
    double sumSq = 0.0;
    for (size_t i = 0; i < win; ++i) {
        double s = static_cast<double>(analysisWindow_[i]);
        sumSq += s * s;
    }
    double rms = std::sqrt(sumSq / win);

    // 自适应环境底噪门限：既挡住空调/远处说话等底噪，又不使用过高固定门限吞掉弱乐器音。
    const float signalGate = std::max(12.0f, noiseFloorRms_ * 1.15f);
    float rawFreq = detector_->detect(downsampleWindow_.data(),
                                      static_cast<int>(downsampleWindow_.size()));
    float confidence = detector_->confidence();
    // Above roughly 4 kHz the 24 kHz analysis stream has too few samples per
    // period. Retry failed frames at the original 48 kHz rate so C8 remains
    // detectable even when A4 is calibrated as high as 466 Hz.
    if (rawFreq <= 0 && highDetector_) {
        const float highFreq = highDetector_->detect(analysisWindow_.data(), static_cast<int>(win));
        if (highFreq > 0) {
            rawFreq = highFreq;
            confidence = highDetector_->confidence();
        }
    }
    // 弱但周期清晰的乐器音允许越过能量门限，避免原始麦克风源下的轻奏被吞掉。
    float freq = rawFreq;
    if (freq > 0 && rms < signalGate && confidence < 0.88f) {
        freq = -1.0f;
    }
    // Throttle diagnostics so a real instrument test can reveal input level and
    // pitch confidence without flooding the device log.
    diagnosticCounter_++;
    if (diagnosticCounter_ % 10 == 0) {
        LOGI("Detect rms=%{public}.1f gate=%{public}.1f raw=%{public}.2f accepted=%{public}.2f conf=%{public}.2f",
             rms, signalGate, rawFreq, freq, confidence);
    }
    if (freq > 0 && pitchCb_) {
        // 用音分比较而非固定 Hz：低音不会过松，高音也不会过严。
        const float deltaCents = lastFreq_ > 0
            ? std::fabs(1200.0f * std::log2(freq / lastFreq_))
            : 9999.0f;
        if (lastFreq_ > 0 && dropCount_ <= 4 && deltaCents < kFreqToleranceCents) {
            stableCount_++;
            smoothedFreq_ = smoothedFreq_ > 0 ? smoothedFreq_ * 0.55f + freq * 0.45f : freq;
        } else {
            stableCount_ = 1;
            smoothedFreq_ = freq;
        }
        lastFreq_ = freq;
        dropCount_ = 0;
        // 高置信度拨弦首帧直接锁定；普通信号仍需两帧一致，避免把环境声当音高。
        // Plucked strings often expose a strong overtone for only one analysis frame.
        // Let a clearly periodic frame through immediately; the instrument-aware layer
        // will fold harmonics back to the selected string and reject unrelated pitches.
        const bool strongPeriodicOnset = confidence >= 0.80f && rms >= noiseFloorRms_ * 1.05f;
        if (strongPeriodicOnset || stableCount_ >= kStableThreshold) {
            LOGI("Push pitch=%{public}.2f conf=%{public}.2f rms=%{public}.1f",
                 smoothedFreq_, confidence, rms);
            pitchCb_(smoothedFreq_);
        }
    } else {
        // 只缓慢抬升底噪估计，避免一次拨弦瞬态把后续衰减音全部挡住。
        if (rawFreq <= 0 && rms < noiseFloorRms_ * 3.0f) {
            const float alpha = rms > noiseFloorRms_ ? 0.005f : 0.08f;
            noiseFloorRms_ += (static_cast<float>(rms) - noiseFloorRms_) * alpha;
            noiseFloorRms_ = std::max(8.0f, std::min(600.0f, noiseFloorRms_));
        }
        // 短暂失败时保留候选音高，允许拨弦衰减过程中的间歇有效帧继续确认。
        dropCount_++;
        if (dropCount_ >= kMaxDropCount) {
            // 通知 UI 清空（传 0 表示无音高）
            if (pitchCb_) {
                pitchCb_(-1.0f);
            }
            dropCount_ = 0;
            lastFreq_ = -1.0f;
            smoothedFreq_ = -1.0f;
            stableCount_ = 0;
        }
    }
}

// ==================== 渲染回调 ====================

OH_AudioData_Callback_Result AudioEngine::OnWriteData(OH_AudioRenderer* renderer, void* userData,
                                                      void* audioData, int32_t audioDataSize) {
    AudioEngine* self = static_cast<AudioEngine*>(userData);
    if (!self || !audioData || audioDataSize <= 0) {
        return AUDIO_DATA_CALLBACK_RESULT_INVALID;
    }
    // 清零输出（未填充部分是静音）
    std::memset(audioData, 0, audioDataSize);
    self->processRender(static_cast<int16_t*>(audioData),
                        audioDataSize / kBytesPerSample);
    return AUDIO_DATA_CALLBACK_RESULT_VALID;
}

void AudioEngine::processRender(int16_t* data, int32_t frames) {
    if (!metronomeRunning_.load()) {
        return;
    }
    std::lock_guard<std::mutex> lock(tempoMutex_);
    bool fired = tempo_.fillBuffer(data, frames, kDefaultSampleRate);
    if (fired && beatCb_) {
        beatCb_(tempo_.currentBeat(), tempo_.beatsPerBar(), tempo_.currentBar());
    }
}

// ==================== 调音器采集 ====================

bool AudioEngine::startCapture() {
    if (capturing_.load()) {
        return true;
    }
    if (capturer_) {
        OH_AudioCapturer_Release(capturer_);
        capturer_ = nullptr;
    }
    if (capturerBuilder_) {
        OH_AudioStreamBuilder_Destroy(capturerBuilder_);
        capturerBuilder_ = nullptr;
    }

    OH_AudioStreamBuilder_Create(&capturerBuilder_, AUDIOSTREAM_TYPE_CAPTURER);
    OH_AudioStreamBuilder_SetSamplingRate(capturerBuilder_, captureSampleRate_);
    OH_AudioStreamBuilder_SetChannelCount(capturerBuilder_, kChannelCount);
    OH_AudioStreamBuilder_SetSampleFormat(capturerBuilder_, AUDIOSTREAM_SAMPLE_S16LE);
    OH_AudioStreamBuilder_SetEncodingType(capturerBuilder_, AUDIOSTREAM_ENCODING_TYPE_RAW);
    OH_AudioStreamBuilder_SetLatencyMode(capturerBuilder_, AUDIOSTREAM_LATENCY_MODE_FAST);
    OH_AudioStreamBuilder_SetCapturerInfo(capturerBuilder_,
                                          AUDIOSTREAM_SOURCE_TYPE_UNPROCESSED);

    // 注册读取回调（API 20+ 独立回调，void 返回）
    OH_AudioStreamBuilder_SetCapturerReadDataCallback(capturerBuilder_, OnReadData, this);
    // FAST 模式建议设置回调帧大小（10ms @48kHz = 480 样本）
    OH_AudioStreamBuilder_SetFrameSizeInCallback(capturerBuilder_, 480);

    OH_AudioStream_Result res = OH_AudioStreamBuilder_GenerateCapturer(capturerBuilder_, &capturer_);
    if (res != AUDIOSTREAM_SUCCESS || !capturer_) {
        LOGE("GenerateCapturer failed: %{public}d", res);
        return false;
    }
    res = OH_AudioCapturer_Start(capturer_);
    if (res != AUDIOSTREAM_SUCCESS) {
        LOGE("Capturer start failed: %{public}d", res);
        OH_AudioCapturer_Release(capturer_);
        capturer_ = nullptr;
        return false;
    }
    capturing_.store(true);
    LOGI("Capture started, sampleRate=%{public}d", captureSampleRate_);
    return true;
}

void AudioEngine::stopCapture() {
    if (capturer_) {
        OH_AudioCapturer_Stop(capturer_);
        OH_AudioCapturer_Release(capturer_);
        capturer_ = nullptr;
    }
    if (capturerBuilder_) {
        OH_AudioStreamBuilder_Destroy(capturerBuilder_);
        capturerBuilder_ = nullptr;
    }
    capturing_.store(false);
    // 清空累积缓冲，重新开始不残留旧数据
    captureBuffer_.clear();
    captureSampleCount_ = 0;
    lastDetectSample_ = 0;
    lastFreq_ = -1.0f;
    smoothedFreq_ = -1.0f;
    stableCount_ = 0;
    dropCount_ = 0;
    noiseFloorRms_ = 20.0f;
}

// ==================== 节拍器渲染 ====================

bool AudioEngine::startMetronome(float bpm, int beatsPerBar) {
    if (metronomeRunning_.load()) {
        // 已在运行，更新参数
        setBpm(bpm);
        setTimeSignature(beatsPerBar);
        return true;
    }
    if (renderer_) {
        OH_AudioRenderer_Release(renderer_);
        renderer_ = nullptr;
    }
    if (rendererBuilder_) {
        OH_AudioStreamBuilder_Destroy(rendererBuilder_);
        rendererBuilder_ = nullptr;
    }

    // 按正确顺序创建：Create → Set 参数 → Set 回调 → Generate
    OH_AudioStreamBuilder_Create(&rendererBuilder_, AUDIOSTREAM_TYPE_RENDERER);
    OH_AudioStreamBuilder_SetSamplingRate(rendererBuilder_, kDefaultSampleRate);
    OH_AudioStreamBuilder_SetChannelCount(rendererBuilder_, kChannelCount);
    OH_AudioStreamBuilder_SetSampleFormat(rendererBuilder_, AUDIOSTREAM_SAMPLE_S16LE);
    OH_AudioStreamBuilder_SetEncodingType(rendererBuilder_, AUDIOSTREAM_ENCODING_TYPE_RAW);
    OH_AudioStreamBuilder_SetLatencyMode(rendererBuilder_, AUDIOSTREAM_LATENCY_MODE_FAST);
    OH_AudioStreamBuilder_SetRendererInfo(rendererBuilder_, AUDIOSTREAM_USAGE_GAME);
    OH_AudioStreamBuilder_SetRendererWriteDataCallback(rendererBuilder_, OnWriteData, this);

    OH_AudioStream_Result res = OH_AudioStreamBuilder_GenerateRenderer(rendererBuilder_, &renderer_);
    if (res != AUDIOSTREAM_SUCCESS || !renderer_) {
        LOGE("GenerateRenderer failed: %{public}d", res);
        return false;
    }

    {
        std::lock_guard<std::mutex> lock(tempoMutex_);
        tempo_.setBpm(bpm);
        tempo_.setTimeSignature(beatsPerBar);
        tempo_.start();
    }

    res = OH_AudioRenderer_Start(renderer_);
    if (res != AUDIOSTREAM_SUCCESS) {
        LOGE("Renderer start failed: %{public}d", res);
        return false;
    }
    OH_AudioRenderer_SetVolume(renderer_, 1.0f);
    metronomeRunning_.store(true);
    LOGI("Metronome started, bpm=%{public}f beats=%{public}d", bpm, beatsPerBar);
    return true;
}

void AudioEngine::stopMetronome() {
    metronomeRunning_.store(false);
    if (renderer_) {
        OH_AudioRenderer_Stop(renderer_);
        OH_AudioRenderer_Release(renderer_);
        renderer_ = nullptr;
    }
    if (rendererBuilder_) {
        OH_AudioStreamBuilder_Destroy(rendererBuilder_);
        rendererBuilder_ = nullptr;
    }
    {
        std::lock_guard<std::mutex> lock(tempoMutex_);
        tempo_.stop();
    }
}

// ==================== 节拍参数 ====================

void AudioEngine::setBpm(float bpm) {
    std::lock_guard<std::mutex> lock(tempoMutex_);
    tempo_.setBpm(bpm);
}

void AudioEngine::setTimeSignature(int beatsPerBar) {
    std::lock_guard<std::mutex> lock(tempoMutex_);
    tempo_.setTimeSignature(beatsPerBar);
}

void AudioEngine::setSubdivide(int subdivide) {
    std::lock_guard<std::mutex> lock(tempoMutex_);
    tempo_.setSubdivide(subdivide);
}

void AudioEngine::setClickFrequency(float freq) {
    std::lock_guard<std::mutex> lock(tempoMutex_);
    tempo_.setClickFrequency(freq);
}

void AudioEngine::setClickTimbre(int timbre) {
    std::lock_guard<std::mutex> lock(tempoMutex_);
    tempo_.setClickTimbre(timbre);
}

void AudioEngine::setClickGain(float gain) {
    std::lock_guard<std::mutex> lock(tempoMutex_);
    tempo_.setClickGain(gain);
}

void AudioEngine::setBeatLevel(int beatIndex, int level) {
    std::lock_guard<std::mutex> lock(tempoMutex_);
    tempo_.setBeatLevel(beatIndex, level);
}

void AudioEngine::setAccentEnabled(bool on) {
    std::lock_guard<std::mutex> lock(tempoMutex_);
    tempo_.setAccentEnabled(on);
}

void AudioEngine::setVibrateOnBeat(bool on) {
    std::lock_guard<std::mutex> lock(tempoMutex_);
    tempo_.setVibrateOnBeat(on);
}
