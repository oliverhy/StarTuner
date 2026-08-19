/*
 * 节拍引擎实现
 */

#include "tempo_engine.h"
#include "click_synth.h"
#include <algorithm>
#include <cmath>

namespace {
constexpr int kAccentClickMs = 50;
constexpr int kNormalClickMs = 42;
constexpr int kProfessionalAccentClickMs = 118;
constexpr int kProfessionalNormalClickMs = 40;
constexpr float kAccentGainRatio = 1.18f;
constexpr float kSubdivisionGainRatio = 0.62f;
constexpr float kBeatLevelGain[] = {0.0f, 0.72f, 0.88f, 1.0f};
}  // namespace

TempoEngine::TempoEngine()
    : running_(false),
      bpm_(100.0f),
      beatsPerBar_(4),
      subdivide_(1),
      accentEnabled_(true),
      accentGain_(1.0f),
      clickGain_(0.8f),
      vibrateOnBeat_(true),
      clickFreq_(2200.0f),
      clickTimbre_(static_cast<int>(ClickTimbre::kProfessional)),
      currentBeat_(0),
      currentBar_(0),
      subdivisionIndex_(0),
      samplesPerBeat_(0.0),
      samplePos_(0.0),
      beatStartSample_(0.0),
      clickCursor_(-1),
      currentClickGain_(0.0f),
      currentClickIsAccent_(false),
      beatEventPending_(false) {
    clickSampleRate_ = 48000;
    beatLevels_.fill(1);
    beatLevels_[0] = 3;
}

TempoEngine::~TempoEngine() {}

void TempoEngine::setBpm(float bpm) {
    bpm_ = std::max(30.0f, std::min(300.0f, bpm));
    if (clickSampleRate_ > 0) {
        samplesPerBeat_ = (60.0 * clickSampleRate_) / bpm_;
    }
}

void TempoEngine::setTimeSignature(int beatsPerBar) {
    beatsPerBar_ = std::max(1, std::min(12, beatsPerBar));
}

void TempoEngine::setSubdivide(int subdivide) {
    subdivide_ = std::max(1, std::min(6, subdivide));
    subdivisionIndex_ = 0;
    samplePos_ = 0.0;
}

void TempoEngine::setClickGain(float gain) {
    clickGain_ = std::max(0.0f, std::min(1.0f, gain));
    // 重音跟随总音量，避免用户调到静音后首拍仍然响。
    accentGain_ = std::min(1.0f, clickGain_ * kAccentGainRatio);
}

void TempoEngine::setClickFrequency(float freq) {
    clickFreq_ = std::max(500.0f, std::min(4000.0f, freq));
    if (running_) {
        rebuildClicks();
    }
}

void TempoEngine::setClickTimbre(int timbre) {
    clickTimbre_ = std::max(0, std::min(5, timbre));
    if (running_) {
        rebuildClicks();
    }
}

void TempoEngine::setBeatLevel(int beatIndex, int level) {
    if (beatIndex < 0 || beatIndex >= static_cast<int>(beatLevels_.size())) {
        return;
    }
    beatLevels_[beatIndex] = std::max(0, std::min(3, level));
}

void TempoEngine::rebuildClicks() {
    ClickSynth synth;
    const ClickTimbre timbre = static_cast<ClickTimbre>(clickTimbre_);
    if (timbre == ClickTimbre::kProfessional) {
        const float pitchRatio = std::max(0.45f, std::min(1.8f, clickFreq_ / 2200.0f));
        const float normalFreq = std::max(500.0f, std::min(1300.0f, 720.0f * pitchRatio));
        const float accentFreq = std::max(1600.0f, std::min(4000.0f, 2385.0f * pitchRatio));
        accentClick_ = synth.synthBuffer(timbre, accentFreq,
                                         kProfessionalAccentClickMs, 1.0f, clickSampleRate_);
        normalClick_ = synth.synthBuffer(timbre, normalFreq,
                                         kProfessionalNormalClickMs, 1.0f, clickSampleRate_);
    } else {
        const float accentFreq = std::min(4000.0f, clickFreq_ * 1.28f);
        accentClick_ = synth.synthBuffer(timbre, accentFreq,
                                         kAccentClickMs, 1.0f, clickSampleRate_);
        normalClick_ = synth.synthBuffer(timbre, clickFreq_,
                                         kNormalClickMs, 1.0f, clickSampleRate_);
    }
}

void TempoEngine::start() {
    if (running_) {
        return;
    }
    running_ = true;
    currentBeat_ = 0;
    currentBar_ = 0;
    subdivisionIndex_ = 0;
    samplePos_ = 0.0;
    beatStartSample_ = 0.0;
    clickCursor_ = 0;
    const int firstLevel = beatLevels_[0];
    currentClickIsAccent_ = accentEnabled_ && firstLevel == 3;
    currentClickGain_ = clickGain_ * kBeatLevelGain[firstLevel];
    if (currentClickIsAccent_) {
        currentClickGain_ = accentGain_;
    }
    if (firstLevel == 0) {
        clickCursor_ = -1;
    }
    beatEventPending_ = true;  // 启动即第一拍

    rebuildClicks();
}

void TempoEngine::stop() {
    running_ = false;
    clickCursor_ = -1;
    currentBeat_ = 0;
    currentBar_ = 0;
    subdivisionIndex_ = 0;
    samplePos_ = 0.0;
    beatStartSample_ = 0.0;
}

bool TempoEngine::fillBuffer(int16_t* out, int frames, int sampleRate) {
    // 初始化采样率（首次）
    if (clickSampleRate_ != sampleRate) {
        clickSampleRate_ = sampleRate;
        samplesPerBeat_ = (60.0 * sampleRate) / bpm_;
    }

    bool eventFired = beatEventPending_;
    beatEventPending_ = false;
    const double samplesPerSubdivision = samplesPerBeat_ / static_cast<double>(subdivide_);

    for (int i = 0; i < frames; ++i) {
        if (running_) {
            // 检查是否到达下一细分；主拍更新 UI/振动，细分只发较轻的 click。
            if (samplePos_ >= samplesPerSubdivision) {
                samplePos_ -= samplesPerSubdivision;
                subdivisionIndex_++;
                bool isMainBeat = false;
                if (subdivisionIndex_ >= subdivide_) {
                    subdivisionIndex_ = 0;
                    currentBeat_ = (currentBeat_ + 1) % beatsPerBar_;
                    if (currentBeat_ == 0) {
                        currentBar_++;
                    }
                    isMainBeat = true;
                }
                const int beatLevel = beatLevels_[currentBeat_];
                const bool isAccent = isMainBeat && accentEnabled_ && beatLevel == 3;
                currentClickIsAccent_ = isAccent;
                if (isMainBeat) {
                    currentClickGain_ = isAccent ? accentGain_
                        : clickGain_ * kBeatLevelGain[beatLevel];
                } else {
                    currentClickGain_ = beatLevel == 0 ? 0.0f
                        : clickGain_ * kSubdivisionGainRatio;
                }
                clickCursor_ = currentClickGain_ > 0.0f ? 0 : -1;
                if (isMainBeat) {
                    eventFired = true;
                }
            }

            // 混入 click
            const std::vector<int16_t>& click = currentClickIsAccent_ ? accentClick_ : normalClick_;
            if (clickCursor_ >= 0 && clickCursor_ < static_cast<int>(click.size())) {
                const int mixed = static_cast<int>(out[i]) +
                    static_cast<int>(click[clickCursor_] * currentClickGain_);
                out[i] = static_cast<int16_t>(std::max(-32768, std::min(32767, mixed)));
                clickCursor_++;
                if (clickCursor_ >= static_cast<int>(click.size())) {
                    clickCursor_ = -1;
                }
            }
            samplePos_ += 1.0;
        }
    }
    return eventFired;
}

bool TempoEngine::consumeBeatEvent() {
    bool had = beatEventPending_;
    beatEventPending_ = false;
    return had;
}
