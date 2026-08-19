/*
 * YIN 音高检测算法实现
 */

#include "pitch_detector.h"
#include <cmath>
#include <algorithm>
#include <cstring>

namespace {
constexpr int kMaxCandidates = 8;
constexpr float kPi = 3.14159265358979323846f;
}  // namespace

PitchDetector::PitchDetector(int sampleRate, int bufferSize,
                             float minFreq, float maxFreq)
    : sampleRate_(sampleRate),
      bufferSize_(bufferSize),
      minFreq_(minFreq),
      maxFreq_(maxFreq),
      threshold_(0.25f),
      noiseGate_(8.0f),
      confidence_(0.0f),
      rms_(0.0f),
      initialized_(false),
      difference_(nullptr),
      cmnd_(nullptr),
      dInts_(nullptr),
      dIntsTmp_(nullptr),
      nCandidates_(0) {
    // 帧长至少 1024，最多 4096（48kHz 下约 85ms，足够低音检测）
    maxBufferSize_ = std::max(1024, std::min(bufferSize, 4096));
    difference_ = new float[maxBufferSize_];
    cmnd_ = new float[maxBufferSize_];
    dInts_ = new int[kMaxCandidates];
    dIntsTmp_ = new int[kMaxCandidates];
    std::memset(difference_, 0, sizeof(float) * maxBufferSize_);
    std::memset(cmnd_, 0, sizeof(float) * maxBufferSize_);
    initialized_ = true;
}

PitchDetector::~PitchDetector() {
    delete[] difference_;
    delete[] cmnd_;
    delete[] dInts_;
    delete[] dIntsTmp_;
    difference_ = nullptr;
    cmnd_ = nullptr;
    dInts_ = nullptr;
    dIntsTmp_ = nullptr;
    initialized_ = false;
}

void PitchDetector::setThreshold(float threshold) {
    threshold_ = std::max(0.05f, std::min(0.3f, threshold));
}

void PitchDetector::setNoiseGate(float rms) {
    noiseGate_ = rms;
}

void PitchDetector::computeDifference(const int16_t* data, int frameCount) {
    const int W = frameCount;
    int tauMax = std::min(W - 1, sampleRate_ / static_cast<int>(minFreq_));
    difference_[0] = 0.0f;

    // CMND 的累计均值必须包含 tau=1 起的完整差分；跳过高频区会污染归一化结果。
    for (int tau = 1; tau <= tauMax; ++tau) {
        float sum = 0.0f;
        for (int i = 0; i + tau < W; ++i) {
            float diff = static_cast<float>(data[i]) - static_cast<float>(data[i + tau]);
            sum += diff * diff;
        }
        difference_[tau] = sum;
    }
    for (int tau = tauMax + 1; tau < bufferSize_; ++tau) {
        difference_[tau] = 1.0e9f;
    }
}

void PitchDetector::cumulativeMeanNormalizedDifference() {
    cmnd_[0] = 1.0f;
    float runningSum = 0.0f;
    for (int tau = 1; tau < bufferSize_; ++tau) {
        runningSum += difference_[tau];
        cmnd_[tau] = (runningSum > 0.0f) ? difference_[tau] * tau / runningSum : 1.0f;
    }
}

int PitchDetector::absoluteThreshold() {
    nCandidates_ = 0;
    int tauMin = std::max(1, sampleRate_ / static_cast<int>(maxFreq_));
    int tauMax = std::min(bufferSize_ - 1, sampleRate_ / static_cast<int>(minFreq_));
    if (tauMin >= tauMax) {
        return -1;
    }
    for (int tau = tauMin; tau <= tauMax; ++tau) {
        if (cmnd_[tau] < threshold_) {
            // YIN 应选择第一个越过阈值后的局部最小值，继续向后会误选倍周期/低八度。
            while (tau + 1 <= tauMax && cmnd_[tau + 1] < cmnd_[tau]) {
                tau++;
            }
            if (nCandidates_ < kMaxCandidates) {
                dInts_[nCandidates_] = tau;
                dIntsTmp_[nCandidates_] = tau;
                nCandidates_++;
            }
            return tau;
        }
    }
    return -1;
}

float PitchDetector::parabolicInterpolation(int tau) {
    if (tau < 1 || tau + 1 >= bufferSize_) {
        return static_cast<float>(tau);
    }
    float s0 = cmnd_[tau - 1];
    float s1 = cmnd_[tau];
    float s2 = cmnd_[tau + 1];
    float denom = s0 - 2.0f * s1 + s2;
    if (std::fabs(denom) < 1e-6f) {
        return static_cast<float>(tau);
    }
    // 抛物线顶点偏移：0.5 * (左值 - 右值) / (左值 - 2*中值 + 右值)
    float adjustment = (s0 - s2) / (2.0f * denom);
    return static_cast<float>(tau) + adjustment;
}

float PitchDetector::detect(const int16_t* data, int frameCount) {
    confidence_ = 0.0f;
    rms_ = 0.0f;
    if (!initialized_ || !data || frameCount < 128) {
        return -1.0f;
    }
    const int W = std::min(frameCount, maxBufferSize_);
    // 关键：先限定 bufferSize_ = W，保证 computeDifference 和 CMND 都只用实际窗口
    bufferSize_ = W;

    // 噪声门限：计算 RMS（S16 域），过低视为静音
    double sumSq = 0.0;
    for (int i = 0; i < W; ++i) {
        double s = static_cast<double>(data[i]);
        sumSq += s * s;
    }
    rms_ = static_cast<float>(std::sqrt(sumSq / W));
    if (rms_ < noiseGate_) {
        return -1.0f;
    }

    computeDifference(data, W);
    cumulativeMeanNormalizedDifference();

    int tau = absoluteThreshold();
    if (tau <= 0) {
        return -1.0f;
    }
    confidence_ = std::max(0.0f, std::min(1.0f, 1.0f - cmnd_[tau]));
    if (confidence_ < 0.70f) {
        confidence_ = 0.0f;
        return -1.0f;
    }
    float bestTau = parabolicInterpolation(tau);
    if (bestTau <= 0) {
        return -1.0f;
    }
    float freq = static_cast<float>(sampleRate_) / bestTau;
    if (freq < minFreq_ || freq > maxFreq_) {
        return -1.0f;
    }
    return freq;
}
