#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <random>
#include <string>
#include <utility>
#include <vector>

#include "../entry/src/main/cpp/dsp/pitch_detector.h"

namespace {
constexpr int kSampleRate = 24000;
constexpr int kFrameCount = 2048;
constexpr double kPi = 3.14159265358979323846;

double midiToFreq(int midi) {
    return 440.0 * std::pow(2.0, (midi - 69) / 12.0);
}

double centsBetween(double actual, double expected) {
    return 1200.0 * std::log2(actual / expected);
}

std::vector<int16_t> synth(double fundamental, bool overtoneDominant, bool decaying,
                           uint32_t seed) {
    std::vector<int16_t> samples(kFrameCount);
    std::mt19937 rng(seed);
    std::normal_distribution<double> noise(0.0, overtoneDominant ? 45.0 : 25.0);
    for (int i = 0; i < kFrameCount; ++i) {
        const double t = static_cast<double>(i) / kSampleRate;
        const double envelope = decaying ? std::exp(-t * 8.0) : 1.0;
        double value = 0.0;
        if (overtoneDominant) {
            value += 500.0 * std::sin(2.0 * kPi * fundamental * t + 0.3);
            value += 3600.0 * std::sin(2.0 * kPi * fundamental * 2.0 * t);
            value += 1900.0 * std::sin(2.0 * kPi * fundamental * 3.01 * t + 0.5);
            value += 800.0 * std::sin(2.0 * kPi * fundamental * 4.02 * t + 1.0);
        } else {
            value += 4200.0 * std::sin(2.0 * kPi * fundamental * t);
            value += 900.0 * std::sin(2.0 * kPi * fundamental * 2.0 * t + 0.4);
            value += 450.0 * std::sin(2.0 * kPi * fundamental * 3.0 * t + 0.8);
        }
        value = value * envelope + noise(rng);
        samples[i] = static_cast<int16_t>(std::clamp(value, -32767.0, 32767.0));
    }
    return samples;
}

struct Match {
    int midi = -1;
    double frequency = 0.0;
    double cents = 9999.0;
};

Match matchInstrumentPitch(double detected, const std::vector<int>& strings) {
    Match best;
    double bestScore = 9999.0;
    for (int midi : strings) {
        const double target = midiToFreq(midi);
        for (int harmonic = 1; harmonic <= 6; ++harmonic) {
            const double fundamental = detected / harmonic;
            const double cents = centsBetween(fundamental, target);
            const double score = std::abs(cents) + (harmonic - 1) * 3.0;
            if (score < bestScore) {
                bestScore = score;
                best = {midi, fundamental, cents};
            }
        }
    }
    if (std::abs(best.cents) > 90.0) {
        return {};
    }
    return best;
}

}  // namespace

int main() {
    PitchDetector detector(kSampleRate, kFrameCount, 20.0f, 4500.0f);
    int pureFailures = 0;
    for (int midi = 21; midi <= 108; ++midi) {
        const double expected = midiToFreq(midi);
        const auto samples = synth(expected, false, false, static_cast<uint32_t>(midi));
        const double detected = detector.detect(samples.data(), static_cast<int>(samples.size()));
        const double error = detected > 0.0 ? std::abs(centsBetween(detected, expected)) : 9999.0;
        if (detected <= 0.0 || error > 25.0) {
            ++pureFailures;
            std::cout << "PURE_FAIL midi=" << midi << " expected=" << expected
                      << " detected=" << detected << " cents=" << error << '\n';
        }
    }

    const std::vector<std::pair<std::string, std::vector<int>>> instruments = {
        {"guitar", {64, 59, 55, 50, 45, 40}},
        {"bass", {43, 38, 33, 28}},
        {"ukulele", {69, 67, 64, 60}},
        {"banjo", {67, 62, 59, 55, 50}},
        {"mandolin", {76, 69, 62, 55}},
        {"guqin", {50, 48, 45, 43, 41, 38, 36}},
        {"violin", {76, 69, 64, 55}},
        {"viola", {69, 62, 55, 48}},
        {"cello", {57, 50, 43, 36}},
        {"double-bass", {43, 38, 33, 28}},
        {"erhu", {69, 62}},
        {"pipa", {57, 52, 50, 45}},
        {"sanxian", {55, 50, 43}},
        {"ruan", {62, 55, 50, 43}},
    };

    int overtoneFailures = 0;
    int overtoneCases = 0;
    for (const auto& instrument : instruments) {
        for (int midi : instrument.second) {
            ++overtoneCases;
            const double expected = midiToFreq(midi);
            const auto samples = synth(expected, true, true,
                                       static_cast<uint32_t>(midi * 31 + instrument.first.size()));
            const double detected = detector.detect(samples.data(), static_cast<int>(samples.size()));
            const Match match = detected > 0.0
                ? matchInstrumentPitch(detected, instrument.second)
                : Match{};
            if (match.midi != midi || std::abs(match.cents) > 90.0) {
                ++overtoneFailures;
                std::cout << "OVERTONE_FAIL instrument=" << instrument.first << " midi=" << midi
                          << " detected=" << detected << " matchedMidi=" << match.midi
                          << " cents=" << match.cents << '\n';
            }
        }
    }

    std::vector<int16_t> silence(kFrameCount, 0);
    const double silenceResult = detector.detect(silence.data(), static_cast<int>(silence.size()));
    std::mt19937 rng(1234);
    std::normal_distribution<double> roomNoise(0.0, 180.0);
    std::vector<int16_t> noise(kFrameCount);
    for (auto& sample : noise) {
        sample = static_cast<int16_t>(roomNoise(rng));
    }
    const double noiseResult = detector.detect(noise.data(), static_cast<int>(noise.size()));

    std::cout << "SUMMARY pure=" << (88 - pureFailures) << "/88 overtone="
              << (overtoneCases - overtoneFailures) << "/" << overtoneCases
              << " silenceRejected=" << (silenceResult < 0.0)
              << " noiseRejected=" << (noiseResult < 0.0) << '\n';
    return (pureFailures == 0 && overtoneFailures == 0 && silenceResult < 0.0 && noiseResult < 0.0)
        ? 0
        : 1;
}
