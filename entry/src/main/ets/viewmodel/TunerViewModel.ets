/*
 * 调音器 ViewModel：封装音高检测业务逻辑
 *
 * 职责：
 *  - 管理采集启停（调用 native）
 *  - 接收音高回调，计算音名/音分/频率
 *  - 管理目标模式（乐器定弦 / 通用音名 / Hz 自定义）
 *  - 管理 A4 基准校准
 *  - 向 UI 推送状态（通过回调，UI 用 @State 同步）
 */

import { analyzeFreq, displayFromFreq, freqFromMidi, midiFromFreq } from '../common/MusicTheory';
import { getNativeAudio } from '../common/NativeBridge';
import { findInstrument, InstrumentSpec } from '../model/Instruments';
import { TUNER_A4_MIN, TUNER_A4_MAX, TUNER_FREQ_MIN, TUNER_FREQ_MAX } from '../common/Constants';

// 目标模式
export enum TunerTargetMode {
  INSTRUMENT = 'instrument', // 乐器定弦
  NOTE = 'note',             // 通用音名
  HZ = 'hz'                  // Hz 自定义
}

// 调音结果回调类型
type PitchListener = (freq: number, noteName: string, cents: number, targetName: string) => void;
type StatusListener = (isListening: boolean) => void;

interface InstrumentPitchMatch {
  frequency: number;
  cents: number;
}

export class TunerViewModel {
  private isListening: boolean = false;
  private a4Ref: number = 440;
  private targetMode: TunerTargetMode = TunerTargetMode.INSTRUMENT;
  private instrumentId: string = 'guitar';
  private targetMidi: number = 64;      // 通用模式目标音（E4）
  private targetFreqHz: number = 440;   // Hz 模式目标频率
  private pitchListener: PitchListener | null = null;
  private statusListener: StatusListener | null = null;

  constructor() {
    // 注册原生音高回调
    const native = getNativeAudio();
    native.registerPitchCallback((freq: number) => {
      this.onNativePitch(freq);
    });
  }

  setPitchListener(listener: PitchListener): void {
    this.pitchListener = listener;
  }

  setStatusListener(listener: StatusListener): void {
    this.statusListener = listener;
  }

  // ===== 采集控制 =====
  start(): boolean {
    if (this.isListening) {
      return true;
    }
    const ok = getNativeAudio().startCapture();
    if (ok) {
      this.isListening = true;
      if (this.statusListener) {
        this.statusListener(true);
      }
    }
    return ok;
  }

  stop(): void {
    getNativeAudio().stopCapture();
    this.isListening = false;
    if (this.statusListener) {
      this.statusListener(false);
    }
  }

  toggle(): boolean {
    if (this.isListening) {
      this.stop();
      return false;
    }
    return this.start();
  }

  isActive(): boolean {
    return this.isListening;
  }

  // ===== 参数 =====
  setA4Ref(ref: number): void {
    this.a4Ref = Math.max(TUNER_A4_MIN, Math.min(TUNER_A4_MAX, ref));
  }

  getA4Ref(): number {
    return this.a4Ref;
  }

  setTargetMode(mode: TunerTargetMode): void {
    this.targetMode = mode;
  }

  getTargetMode(): TunerTargetMode {
    return this.targetMode;
  }

  setInstrumentId(id: string): void {
    this.instrumentId = id;
  }

  getInstrumentId(): string {
    return this.instrumentId;
  }

  setTargetMidi(midi: number): void {
    this.targetMidi = midi;
  }

  setTargetFreqHz(freq: number): void {
    this.targetFreqHz = Math.max(TUNER_FREQ_MIN, Math.min(TUNER_FREQ_MAX, freq));
  }

  getTargetFreqHz(): number {
    return this.targetFreqHz;
  }

  // ===== 目标信息 =====
  /**
   * 获取当前目标音名（供 UI 显示）
   */
  getTargetName(): string {
    if (this.targetMode === TunerTargetMode.HZ) {
      return `${this.targetFreqHz.toFixed(2)} Hz`;
    }
    if (this.targetMode === TunerTargetMode.INSTRUMENT) {
      const inst = findInstrument(this.instrumentId);
      if (inst && inst.strings.length > 0) {
        // 显示第一根弦（最高音）作为代表
        return this.midiToName(inst.strings[0]);
      }
      return '任意音';
    }
    return this.midiToName(this.targetMidi);
  }

  private midiToName(midi: number): string {
    const freq = freqFromMidi(midi, this.a4Ref);
    return displayFromFreq(freq, this.a4Ref).name;
  }

  // ===== 原生回调处理 =====
  private onNativePitch(freq: number): void {
    if (!this.isListening || !this.pitchListener) {
      return;
    }
    // 无音高（静音/噪声）：通知 UI 清空
    if (freq <= 0) {
      this.pitchListener(0, '--', 0, '');
      return;
    }
    // 计算目标名称
    let targetName = '';
    if (this.targetMode === TunerTargetMode.HZ) {
      // Hz 模式：计算与目标频率的音分差
      const midiTarget = midiFromFreq(this.targetFreqHz, this.a4Ref);
      const midiCurrent = midiFromFreq(freq, this.a4Ref);
      const hzCents = Math.round((midiCurrent - midiTarget) * 100);
      const display = displayFromFreq(freq, this.a4Ref);
      targetName = `${this.targetFreqHz.toFixed(2)} Hz`;
      this.pitchListener(freq, display.name, hzCents, targetName);
      return;
    }

    if (this.targetMode === TunerTargetMode.INSTRUMENT) {
      const inst = findInstrument(this.instrumentId);
      if (inst && inst.strings.length > 0) {
        const match = this.matchInstrumentPitch(freq, inst);
        if (match === null) {
          return;
        }
        const display = displayFromFreq(match.frequency, this.a4Ref);
        targetName = inst.name;
        this.pitchListener(match.frequency, display.name, match.cents, targetName);
        return;
      }
      if (inst) {
        // Piano, winds and pitched percussion have no fixed open-string targets.
        // In instrument mode they should still behave as a chromatic tuner instead
        // of incorrectly comparing every note with the default E4 target.
        const display = displayFromFreq(freq, this.a4Ref);
        const analysis = analyzeFreq(freq, this.a4Ref);
        this.pitchListener(freq, display.name, analysis.cents, inst.name);
        return;
      }
    }

    // 通用音名模式：直接显示相对最近音名的音分
    const display = displayFromFreq(freq, this.a4Ref);
    const analysis = analyzeFreq(freq, this.a4Ref);
    targetName = this.midiToName(this.targetMidi);
    this.pitchListener(freq, display.name, analysis.cents, targetName);
  }

  /**
   * Plucked instruments can have a weak fundamental and a much stronger 2nd/3rd
   * harmonic. Match both the detected pitch and its first few subharmonics against
   * the selected instrument's open strings, then report the inferred fundamental.
   */
  private matchInstrumentPitch(freq: number, inst: InstrumentSpec): InstrumentPitchMatch | null {
    let bestFrequency = 0;
    let bestCents = 9999;
    let bestScore = 9999;
    for (let i = 0; i < inst.strings.length; i++) {
      const targetFreq = freqFromMidi(inst.strings[i], this.a4Ref);
      for (let harmonic = 1; harmonic <= 6; harmonic++) {
        const fundamental = freq / harmonic;
        const cents = Math.round(1200 * Math.log2(fundamental / targetFreq));
        // Prefer the actual fundamental when two candidates are similarly close.
        const score = Math.abs(cents) + (harmonic - 1) * 3;
        if (score < bestScore) {
          bestScore = score;
          bestCents = cents;
          bestFrequency = fundamental;
        }
      }
    }
    // A wide enough capture range for a noticeably mistuned string, while rejecting
    // most speech and room noise that does not belong to the selected tuning.
    if (Math.abs(bestCents) > 90 || bestFrequency <= 0) {
      return null;
    }
    return { frequency: bestFrequency, cents: bestCents };
  }
}

// 单例
let instance: TunerViewModel | null = null;

export function getTunerViewModel(): TunerViewModel {
  if (instance === null) {
    instance = new TunerViewModel();
  }
  return instance;
}
