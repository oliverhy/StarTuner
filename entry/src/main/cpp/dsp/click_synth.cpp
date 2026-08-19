/*
 * click 声音合成器实现
 */

#include "click_synth.h"
#include <cmath>
#include <algorithm>
#include <cstdint>

const char* const kClickTimbreNames[] = {
    "专业", "木鱼", "滴答", "电子", "牛铃", "木击"
};

namespace {
constexpr float kPi = 3.14159265358979323846f;
}  // namespace

ClickSynth::ClickSynth() {}

ClickSynth::~ClickSynth() {}

float ClickSynth::envelope(int n, int total, float decay) {
    // 双阶段衰减：保留清晰起音，同时给手机扬声器足够长的可听尾音。
    // 单指数包络在前几毫秒后能量下降过快，容易被小提琴的持续音遮蔽。
    if (total <= 0) {
        return 0.0f;
    }
    float t = static_cast<float>(n) / static_cast<float>(total);
    const float fast = std::exp(-decay * t);
    const float tailDecay = std::max(2.2f, decay * 0.42f);
    const float tail = std::exp(-tailDecay * t);
    return (fast * 0.64f + tail * 0.36f) * (1.0f - t);
}

void ClickSynth::synth(ClickTimbre timbre, float freq, float durationMs,
                       float amplitude, int sampleRate, std::vector<int16_t>& out) {
    int total = static_cast<int>(sampleRate * durationMs / 1000.0f);
    if (total <= 0) {
        total = 1;
    }
    float amp = std::max(0.0f, std::min(1.0f, amplitude));
    float f = std::max(100.0f, std::min(8000.0f, freq));
    constexpr float maxInt = 32767.0f;

    // 参考视频的节拍不是同一声响简单升降音量：弱拍是约 720Hz 的短促木质
    // "嗒"，强拍则是约 2.4kHz、带 6kHz 泛音的较长金属提示音。这里单独
    // 建模，避免通用的高频增强层改变它的辨识特征。TempoEngine 通过频率区分
    // 两种拍声（弱拍 < 1.5kHz，强拍 > 1.5kHz）。
    if (timbre == ClickTimbre::kProfessional) {
        const bool accent = f >= 1500.0f;
        uint32_t noiseState = 0xA341316Cu ^ static_cast<uint32_t>(total) ^
            static_cast<uint32_t>(f * 10.0f);
        for (int i = 0; i < total; ++i) {
            const float seconds = static_cast<float>(i) / static_cast<float>(sampleRate);
            noiseState = noiseState * 1664525u + 1013904223u;
            const float noise = static_cast<float>((noiseState >> 8) & 0x00FFFFFFu) /
                8388607.5f - 1.0f;
            float mixed = 0.0f;
            if (accent) {
                const float ring = std::exp(-seconds / 0.039f) *
                    std::max(0.0f, 1.0f - seconds / (durationMs / 1000.0f));
                mixed = ring * (0.68f * std::sin(2.0f * kPi * f * seconds) +
                    0.13f * std::sin(2.0f * kPi * f * 1.034f * seconds) +
                    0.10f * std::sin(2.0f * kPi * f * 0.961f * seconds) +
                    0.17f * std::sin(2.0f * kPi * f * 2.50f * seconds));
                mixed += noise * std::exp(-seconds / 0.0018f) * 0.34f;
            } else {
                const float ring = std::exp(-seconds / 0.0125f) *
                    std::max(0.0f, 1.0f - seconds / (durationMs / 1000.0f));
                mixed = ring * (0.63f * std::sin(2.0f * kPi * f * seconds) +
                    0.18f * std::sin(2.0f * kPi * f * 0.88f * seconds) +
                    0.13f * std::sin(2.0f * kPi * f * 2.72f * seconds) +
                    0.08f * std::sin(2.0f * kPi * f * 3.14f * seconds));
                // 约 9ms 的第二次轻敲，是参考视频普通拍声音厚度的主要来源。
                const float secondTime = seconds - 0.009f;
                if (secondTime >= 0.0f) {
                    mixed += std::sin(2.0f * kPi * f * secondTime) *
                        std::exp(-secondTime / 0.008f) * 0.24f;
                }
                mixed += noise * std::exp(-seconds / 0.0015f) * 0.30f;
            }
            const float limited = std::tanh(mixed * (accent ? 1.72f : 1.82f));
            const float value = limited * amp * maxInt;
            out.push_back(static_cast<int16_t>(
                std::max(-32768.0f, std::min(32767.0f, value))));
        }
        return;
    }

    // 预计算相位增量
    float phaseInc = 2.0f * kPi * f / static_cast<float>(sampleRate);
    float phase = 0.0f;

    // 固定的高频穿透层避开小提琴最强的 2~4kHz 主体，同时仍处于手机扬声器
    // 能有效回放的范围。低中频主体则保证在高频衰减明显的设备上仍可听见。
    const float presenceFreq = std::max(5400.0f, std::min(7000.0f, 5000.0f + f * 0.55f));
    const float bodyFreq = std::max(820.0f, std::min(1250.0f, f * 0.48f));
    float presencePhase = 0.0f;
    float bodyPhase = 0.0f;
    const float presencePhaseInc = 2.0f * kPi * presenceFreq / static_cast<float>(sampleRate);
    const float bodyPhaseInc = 2.0f * kPi * bodyFreq / static_cast<float>(sampleRate);

    // 各音色参数
    float decay = 6.0f;       // 指数衰减速率
    float modFreq = 0.0f;     // 调制频率（牛铃/木鱼用）
    float modDepth = 0.0f;

    switch (timbre) {
        case ClickTimbre::kProfessional:
            break;
        case ClickTimbre::kTick:
            decay = 12.0f;
            break;
        case ClickTimbre::kWoodblock:
            decay = 5.5f;
            modFreq = f * 1.4f;
            modDepth = 0.5f;
            break;
        case ClickTimbre::kBeep:
            decay = 4.5f;
            break;
        case ClickTimbre::kCowbell:
            decay = 4.0f;
            modFreq = f * 0.5f;
            modDepth = 0.7f;
            break;
        case ClickTimbre::kClick:
            decay = 10.0f;
            break;
    }

    float modPhase = 0.0f;
    float modPhaseInc = 2.0f * kPi * modFreq / static_cast<float>(sampleRate);

    // 使用局部确定性噪声，避免全局 rand() 状态影响实时音频线程。
    uint32_t noiseState = 0x9E3779B9u ^ static_cast<uint32_t>(total) ^
        static_cast<uint32_t>(f * 10.0f);

    for (int i = 0; i < total; ++i) {
        float gain = envelope(i, total, decay);
        float sample = 0.0f;
        noiseState = noiseState * 1664525u + 1013904223u;
        const float noise = static_cast<float>((noiseState >> 8) & 0x00FFFFFFu) /
            8388607.5f - 1.0f;

        switch (timbre) {
            case ClickTimbre::kProfessional:
                break;
            case ClickTimbre::kTick: {
                // 短促噪声尖峰（滴答）
                sample = noise * 0.55f + std::sin(phase) * 0.45f;
                break;
            }
            case ClickTimbre::kWoodblock: {
                // 基频 + 高次泛音（木鱼感）
                float m = 1.0f + modDepth * std::sin(modPhase);
                sample = 0.42f * std::sin(phase) + 0.34f * std::sin(phase * 2.3f) +
                    0.24f * std::sin(phase * 4.1f);
                sample *= m;
                break;
            }
            case ClickTimbre::kBeep: {
                sample = 0.78f * std::sin(phase) + 0.22f * std::sin(phase * 2.0f);
                break;
            }
            case ClickTimbre::kCowbell: {
                // 两个近失谐正弦（牛铃）
                sample = 0.6f * std::sin(phase) + 0.4f * std::sin(phase * 1.18f);
                float m = 1.0f + modDepth * std::sin(modPhase);
                sample *= m;
                break;
            }
            case ClickTimbre::kClick: {
                // 低频木击：低频正弦 + 噪声
                sample = 0.7f * std::sin(phase) + 0.3f * noise;
                break;
            }
        }

        const float seconds = static_cast<float>(i) / static_cast<float>(sampleRate);
        const float transientEnv = std::exp(-seconds / 0.0022f);
        const float presenceEnv = std::exp(-seconds / 0.013f);
        const float bodyEnv = std::exp(-seconds / 0.024f);

        // 三层节拍：原音色、固定高频穿透层、低中频敲击主体；最前端再加入宽频瞬态。
        // 软限幅提高平均响度而不产生整数削波爆音。
        float mixed = sample * gain * 0.72f;
        mixed += std::sin(presencePhase) * presenceEnv * 0.34f;
        mixed += std::sin(bodyPhase) * bodyEnv * 0.18f;
        mixed += noise * transientEnv * 0.42f;
        constexpr float drive = 1.55f;
        const float limited = std::tanh(mixed * drive);

        float val = limited * amp * maxInt;
        int16_t s = static_cast<int16_t>(std::max(-32768.0f, std::min(32767.0f, val)));
        out.push_back(s);
        phase += phaseInc;
        presencePhase += presencePhaseInc;
        bodyPhase += bodyPhaseInc;
        if (modPhaseInc > 0) {
            modPhase += modPhaseInc;
        }
    }
}

std::vector<int16_t> ClickSynth::synthBuffer(ClickTimbre timbre, float freq,
                                             float durationMs, float amplitude,
                                             int sampleRate) {
    std::vector<int16_t> out;
    synth(timbre, freq, durationMs, amplitude, sampleRate, out);
    return out;
}
