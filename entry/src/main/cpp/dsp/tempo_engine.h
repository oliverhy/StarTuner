/*
 * 节拍引擎：在 OHAudio 渲染回调中做样本级精度的节拍调度
 *
 * 职责：
 *  - 维护 BPM、拍号（每小节拍数）、重音配置
 *  - 根据采样位置计算当前拍、当前小节
 *  - 在需要发声的采样位置把 click 声音混入输出缓冲
 *  - 输出每拍事件（用于 UI 闪烁 + 振动）
 *
 * 使用方式（配合 AudioEngine）：
 *  1. 启动前配置 setBpm / setTimeSignature / setSubdivide
 *  2. render 回调每帧调用 fillBuffer(int16_t* out, int frames, int sampleRate)
 *  3. 每帧回调后检查 hasBeatEvent()，有则取当前拍号（用于 UI 更新）
 */

#ifndef TEMPO_ENGINE_H
#define TEMPO_ENGINE_H

#include <cstdint>
#include <array>
#include <vector>

class TempoEngine {
public:
    TempoEngine();
    ~TempoEngine();

    // 状态控制
    void start();
    void stop();
    bool isRunning() const { return running_; }

    // 配置
    void setBpm(float bpm);
    void setTimeSignature(int beatsPerBar);  // 每小节拍数（2~12）
    void setSubdivide(int subdivide);        // 每拍细分（1=直线,2=八分,3=三连,4=十六分）
    void setAccentEnabled(bool enabled) { accentEnabled_ = enabled; }
    void setAccentGain(float gain) { accentGain_ = gain; }
    void setClickGain(float gain);
    void setVibrateOnBeat(bool on) { vibrateOnBeat_ = on; }
    void setClickFrequency(float freq);
    void setClickTimbre(int timbre);
    void setBeatLevel(int beatIndex, int level); // 0=静音，1=弱，2=中，3=强

    // 参数
    float bpm() const { return bpm_; }
    int beatsPerBar() const { return beatsPerBar_; }
    int subdivide() const { return subdivide_; }
    int currentBeat() const { return currentBeat_; }
    int currentBar() const { return currentBar_; }
    float clickFrequency() const { return clickFreq_; }

    // 渲染：填充一帧输出。返回是否有节拍事件（UI 需要更新）
    bool fillBuffer(int16_t* out, int frames, int sampleRate);

    // 消费一个节拍事件（供 UI/振动使用）
    bool consumeBeatEvent();

private:
    void rebuildClicks();

    bool running_;
    float bpm_;             // 当前 BPM
    int beatsPerBar_;       // 每小节拍数
    int subdivide_;         // 每拍细分
    bool accentEnabled_;
    float accentGain_;      // 重音增益
    float clickGain_;       // 弱音增益
    bool vibrateOnBeat_;
    float clickFreq_;       // click 频率（Hz）
    int clickTimbre_;
    std::array<int, 12> beatLevels_;

    // 节拍状态
    int currentBeat_;       // 当前拍（0 起）
    int currentBar_;        // 当前小节
    int subdivisionIndex_;  // 当前拍内细分位置
    double samplesPerBeat_; // 每拍采样数
    double samplePos_;      // 当前采样位置（相对拍起点）
    double beatStartSample_; // 本拍起始采样（全局计数）

    // click 缓存（预合成）
    std::vector<int16_t> accentClick_;
    std::vector<int16_t> normalClick_;
    int clickSampleRate_;
    int clickCursor_;       // 当前正在播放的 click 采样位置（-1=不在播放）
    float currentClickGain_;
    bool currentClickIsAccent_;

    // 事件
    bool beatEventPending_;
};

#endif // TEMPO_ENGINE_H
