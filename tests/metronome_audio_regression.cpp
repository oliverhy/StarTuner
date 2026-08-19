#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <vector>

#include "dsp/click_synth.h"
#include "dsp/tempo_engine.h"

namespace {
constexpr int kSampleRate = 48000;
constexpr double kPi = 3.14159265358979323846;

double rms(const std::vector<int16_t>& data, int begin, int end) {
    begin = std::max(0, begin);
    end = std::min(static_cast<int>(data.size()), end);
    if (end <= begin) {
        return 0.0;
    }
    double sum = 0.0;
    for (int i = begin; i < end; ++i) {
        const double value = static_cast<double>(data[i]) / 32768.0;
        sum += value * value;
    }
    return std::sqrt(sum / static_cast<double>(end - begin));
}

double toneMagnitude(const std::vector<int16_t>& data, double freq, int samples) {
    samples = std::min(samples, static_cast<int>(data.size()));
    double real = 0.0;
    double imag = 0.0;
    for (int i = 0; i < samples; ++i) {
        const double sample = static_cast<double>(data[i]) / 32768.0;
        const double phase = 2.0 * kPi * freq * static_cast<double>(i) / kSampleRate;
        real += sample * std::cos(phase);
        imag -= sample * std::sin(phase);
    }
    return 2.0 * std::sqrt(real * real + imag * imag) / static_cast<double>(samples);
}

void require(bool condition, const char* message) {
    if (!condition) {
        std::cerr << "FAIL: " << message << std::endl;
        std::exit(1);
    }
}
}  // namespace

int main() {
    ClickSynth synth;
    // The reference-derived professional sound has two deliberately different voices.
    const auto professionalNormal = synth.synthBuffer(ClickTimbre::kProfessional,
                                                       720.0f, 40.0f, 1.0f, kSampleRate);
    const auto professionalAccent = synth.synthBuffer(ClickTimbre::kProfessional,
                                                       2385.0f, 118.0f, 1.0f, kSampleRate);
    require(professionalNormal.size() == static_cast<size_t>(kSampleRate * 40 / 1000),
            "professional normal duration mismatch");
    require(professionalAccent.size() == static_cast<size_t>(kSampleRate * 118 / 1000),
            "professional accent duration mismatch");
    require(toneMagnitude(professionalNormal, 720.0, kSampleRate * 25 / 1000) >= 0.18,
            "professional normal is missing its 720Hz body");
    require(toneMagnitude(professionalAccent, 2385.0, kSampleRate * 50 / 1000) >= 0.24,
            "professional accent is missing its 2.4kHz ring");
    require(rms(professionalAccent, kSampleRate * 45 / 1000,
                kSampleRate * 100 / 1000) >= 0.045,
            "professional accent tail is too short");

    for (int timbre = 1; timbre <= 5; ++timbre) {
        const auto click = synth.synthBuffer(static_cast<ClickTimbre>(timbre),
                                             2200.0f, 42.0f, 1.0f, kSampleRate);
        const double onsetRms = rms(click, 0, kSampleRate * 15 / 1000);
        const double tailRms = rms(click, kSampleRate * 15 / 1000,
                                  kSampleRate * 35 / 1000);
        const double presence = toneMagnitude(click, 6210.0, kSampleRate * 20 / 1000);
        const int peak = std::max(std::abs(static_cast<int>(*std::min_element(click.begin(), click.end()))),
                                  std::abs(static_cast<int>(*std::max_element(click.begin(), click.end()))));
        require(click.size() == static_cast<size_t>(kSampleRate * 42 / 1000),
                "click duration mismatch");
        require(peak >= 24000, "click peak is too low");
        require(onsetRms >= 0.28, "click onset lacks energy");
        require(tailRms >= 0.07, "click tail decays too quickly");
        require(presence >= 0.10, "high-frequency presence layer is missing");
        std::cout << "timbre=" << timbre << " onset=" << onsetRms
                  << " tail=" << tailRms << " presence=" << presence
                  << " peak=" << peak << std::endl;
    }

    // The user volume must mute every beat, including the accented first beat.
    TempoEngine tempo;
    tempo.setBpm(120.0f);
    tempo.setTimeSignature(4);
    tempo.setSubdivide(1);
    tempo.setClickGain(0.0f);
    tempo.start();
    std::vector<int16_t> muted(kSampleRate / 2, 0);
    tempo.fillBuffer(muted.data(), static_cast<int>(muted.size()), kSampleRate);
    require(std::all_of(muted.begin(), muted.end(), [](int16_t value) { return value == 0; }),
            "zero volume does not mute accented beat");

    TempoEngine perBeatMute;
    perBeatMute.setBpm(120.0f);
    perBeatMute.setTimeSignature(4);
    perBeatMute.setSubdivide(1);
    perBeatMute.setClickGain(1.0f);
    perBeatMute.setBeatLevel(0, 0);
    perBeatMute.start();
    std::vector<int16_t> mutedFirstBeat(kSampleRate / 2, 0);
    perBeatMute.fillBuffer(mutedFirstBeat.data(), static_cast<int>(mutedFirstBeat.size()), kSampleRate);
    require(std::all_of(mutedFirstBeat.begin(), mutedFirstBeat.end(),
                        [](int16_t value) { return value == 0; }),
            "per-beat mute does not silence the selected beat");

    std::cout << "PASS: metronome click audibility regression" << std::endl;
    return 0;
}
