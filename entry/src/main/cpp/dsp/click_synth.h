/*
 * click 声音合成器
 *
 * 在内存中合成各种节拍器音色（PCM S16LE）：
 *  - 专业（参考机械节拍器：低音弱拍 + 高音强拍）
 *  - 木鱼 (woodblock)
 *  - 滴答 (tick)
 *  - 电子 beep
 *  - 牛铃 (cowbell)
 *  - 木击 (click)
 *
 * 每种音色支持：
 *  - 频率（音高）可调：500~4000Hz
 *  - 音量 0~1
 *  - 时长（默认很短，适合节拍）
 */

#ifndef CLICK_SYNTH_H
#define CLICK_SYNTH_H

#include <cstdint>
#include <string>
#include <vector>

enum class ClickTimbre {
    kProfessional = 0, // 专业：由 TempoEngine 分别传入弱拍/强拍频率
    kWoodblock = 1,    // 木鱼（与 ArkTS 列表顺序保持一致）
    kTick = 2,         // 滴答（清脆短音）
    kBeep = 3,         // 电子 beep（正弦）
    kCowbell = 4,      // 牛铃
    kClick = 5         // 木击（低频）
};

// 音色列表（UI 显示顺序）
extern const char* const kClickTimbreNames[];

class ClickSynth {
public:
    ClickSynth();
    ~ClickSynth();

    /**
     * 合成一段 click 声音（mono, S16LE）
     * @param timbre 音色
     * @param freq 频率（Hz），默认 1000
     * @param durationMs 时长（ms）
     * @param amplitude 振幅 0~1
     * @param sampleRate 采样率
     * @param out 输出缓冲区（push 填充）
     */
    void synth(ClickTimbre timbre, float freq, float durationMs,
               float amplitude, int sampleRate, std::vector<int16_t>& out);

    /**
     * 为指定参数生成整段 PCM（含持续 + 尾部静音），返回字节数组（S16LE）
     */
    std::vector<int16_t> synthBuffer(ClickTimbre timbre, float freq,
                                     float durationMs, float amplitude,
                                     int sampleRate);

private:
    // 包络：指数衰减，返回第 n 个样本的增益
    float envelope(int n, int total, float decay);
};

#endif // CLICK_SYNTH_H
