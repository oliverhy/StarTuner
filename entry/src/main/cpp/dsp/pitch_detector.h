/*
 * YIN 音高检测算法
 *
 * 参考：De Cheveigné & Kawahara (2002), "YIN, a fundamental frequency estimator
 * for speech and music", JASA 111(4).
 *
 * 设计要点：
 *  - 基于自相关（差方和）的时域算法，对单音（乐器单弦/单音）检测准确
 *  - 阈值 0.1，绝对阈值 0.1，滞后窗口 60，可调
 *  - 输出：基频 Hz 或 -1（无有效音高）
 *  - 线程安全：所有状态都在实例内，不同实例独立
 */

#ifndef PITCH_DETECTOR_H
#define PITCH_DETECTOR_H

#include <cstdint>

class PitchDetector {
public:
    /**
     * @param sampleRate 采样率（Hz）
     * @param bufferSize 期望的处理帧长度（样本数）。实际按 min(给定, 最大) 处理
     * @param minFreq 检测下限（Hz），默认 20Hz
     * @param maxFreq 检测上限（Hz），默认 4500Hz（覆盖高基准音下的 C8）
     */
    PitchDetector(int sampleRate, int bufferSize,
                  float minFreq = 20.0f, float maxFreq = 4500.0f);
    ~PitchDetector();

    // 禁用拷贝
    PitchDetector(const PitchDetector&) = delete;
    PitchDetector& operator=(const PitchDetector&) = delete;

    /**
     * 对输入的 PCM 帧做音高检测
     * @param data 输入的 S16LE 样本（长度为 frameCount）
     * @param frameCount 输入样本数
     * @return 基频（Hz），无有效音高返回 -1
     */
    float detect(const int16_t* data, int frameCount);

    // 最近一次有效检测的周期性置信度（0~1，越大越可信）
    float confidence() const { return confidence_; }

    // 最近一次输入窗口的 RMS（S16 域）
    float rms() const { return rms_; }

    /**
     * 设置检测灵敏度（YIN 阈值，0.05~0.3，越小越严格）
     */
    void setThreshold(float threshold);

    /**
     * 设置噪声门限：低于该 RMS 的帧视为静音，返回 -1
     */
    void setNoiseGate(float rms);

private:
    // 计算差方和函数（差分序列）
    void computeDifference(const int16_t* data, int frameCount);
    // 累积均值归一化差分（CMND）
    void cumulativeMeanNormalizedDifference();
    // 绝对阈值法找基音
    int absoluteThreshold();
    // 抛物线插值精化
    float parabolicInterpolation(int tau);

    int sampleRate_;
    int bufferSize_;
    int maxBufferSize_;
    float minFreq_;
    float maxFreq_;
    float threshold_;
    float noiseGate_;
    float confidence_;
    float rms_;
    bool initialized_;

    // 工作缓冲
    float* difference_;   // d(tau)
    float* cmnd_;         // d'(tau)
    int* dInts_;          // 候选 tau
    int* dIntsTmp_;
    int nCandidates_;
};

#endif // PITCH_DETECTOR_H
