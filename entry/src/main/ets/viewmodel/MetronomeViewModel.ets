/*
 * 节拍器 ViewModel：封装节拍器业务逻辑
 *
 * 职责：
 *  - 管理节拍启停（调用 native）
 *  - 同步 BPM / 拍号 / 细分 / click 频率 / 音量 / 重音 / 振动 到 native
 *  - 接收节拍事件回调，触发 UI 闪烁 + 振动
 */

import { vibrator } from '@kit.SensorServiceKit';
import { common } from '@kit.AbilityKit';
import { getNativeAudio } from '../common/NativeBridge';
import { startMetronomeBackground, stopMetronomeBackground } from '../common/BackgroundManager';
import { METRONOME_BPM_MIN, METRONOME_BPM_MAX } from '../common/Constants';

// 节拍事件回调
type BeatListener = (beat: number, beatsPerBar: number, bar: number) => void;

// 节奏型定义
export interface RhythmPattern {
  name: string;
  subdivide: number;
}

// click 音色定义
export interface ClickTimbre {
  name: string;
  freq: number;
}

// 常用拍号
export const TIME_SIGNATURES: number[][] = [
  [1, 4], [2, 4], [3, 4], [4, 4], [5, 4], [6, 4],
  [3, 8], [6, 8], [9, 8], [12, 8], [5, 8], [7, 8]
];

// 节奏型（细分）
export const RHYTHM_PATTERNS: RhythmPattern[] = [
  { name: '直线', subdivide: 1 },
  { name: '八分', subdivide: 2 },
  { name: '三连音', subdivide: 3 },
  { name: '十六分', subdivide: 4 }
];

// click 音色
export const CLICK_TIMBRES: ClickTimbre[] = [
  { name: '专业', freq: 2200 },
  { name: '木鱼', freq: 2200 },
  { name: '滴答', freq: 3200 },
  { name: '电子', freq: 1800 },
  { name: '牛铃', freq: 2600 },
  { name: '木击', freq: 1400 }
];

export class MetronomeViewModel {
  private isRunning: boolean = false;
  private bpm: number = 100;
  private timeSignatureIdx: number = 3;   // 4/4
  private rhythmIdx: number = 0;          // 直线
  private accentEnabled: boolean = true;
  private vibrateEnabled: boolean = true;
  private volume: number = 100;           // 0~100，演奏场景默认使用完整动态范围
  private clickFreq: number = 2200;       // Hz
  private timbreIdx: number = 0;
  private beatLevels: number[] = [3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
  private beatListener: BeatListener | null = null;

  constructor() {
    // 注册原生节拍回调
    const native = getNativeAudio();
    native.registerBeatCallback((beat: number, beatsPerBar: number, bar: number) => {
      this.onNativeBeat(beat, beatsPerBar, bar);
    });
  }

  setBeatListener(listener: BeatListener): void {
    this.beatListener = listener;
  }

  // ===== 控制 =====
  start(context: common.UIAbilityContext): boolean {
    if (this.isRunning) {
      return true;
    }
    // 启动前先写入全部参数，保证首拍就是用户当前选择的音色与音量。
    this.pushParams();
    const beatsPerBar = TIME_SIGNATURES[this.timeSignatureIdx][0];
    const ok = getNativeAudio().startMetronome(this.bpm, beatsPerBar);
    if (ok) {
      this.isRunning = true;
      // 申请后台长时任务（锁屏继续播放）
      startMetronomeBackground(context);
    }
    return ok;
  }

  stop(context: common.UIAbilityContext): void {
    getNativeAudio().stopMetronome();
    this.isRunning = false;
    // 释放后台长时任务
    stopMetronomeBackground(context);
  }

  toggle(context: common.UIAbilityContext): boolean {
    if (this.isRunning) {
      this.stop(context);
      return false;
    }
    return this.start(context);
  }

  isActive(): boolean {
    return this.isRunning;
  }

  // ===== 参数设置（实时同步到 native） =====
  setBpm(bpm: number): void {
    this.bpm = Math.max(METRONOME_BPM_MIN, Math.min(METRONOME_BPM_MAX, bpm));
    if (this.isRunning) {
      getNativeAudio().setBpm(this.bpm);
    }
  }

  setTimeSignatureIdx(idx: number): void {
    this.timeSignatureIdx = idx;
    if (this.isRunning) {
      getNativeAudio().setTimeSignature(TIME_SIGNATURES[idx][0]);
    }
  }

  setRhythmIdx(idx: number): void {
    this.rhythmIdx = idx;
    if (this.isRunning) {
      getNativeAudio().setSubdivide(RHYTHM_PATTERNS[idx].subdivide);
    }
  }

  setAccentEnabled(on: boolean): void {
    this.accentEnabled = on;
    if (this.isRunning) {
      getNativeAudio().setAccentEnabled(on);
    }
  }

  setVibrateEnabled(on: boolean): void {
    this.vibrateEnabled = on;
    if (this.isRunning) {
      getNativeAudio().setVibrateOnBeat(on);
    }
  }

  setVolume(v: number): void {
    this.volume = v;
    if (this.isRunning) {
      getNativeAudio().setClickGain(v / 100);
    }
  }

  setClickFreq(freq: number): void {
    this.clickFreq = freq;
    if (this.isRunning) {
      getNativeAudio().setClickFrequency(freq);
    }
  }

  setClickTimbre(idx: number): void {
    this.timbreIdx = Math.max(0, Math.min(CLICK_TIMBRES.length - 1, idx));
    if (this.isRunning) {
      getNativeAudio().setClickTimbre(this.timbreIdx);
    }
  }

  setBeatLevel(beatIndex: number, level: number): void {
    if (beatIndex < 0 || beatIndex >= this.beatLevels.length) {
      return;
    }
    this.beatLevels[beatIndex] = Math.max(0, Math.min(3, level));
    if (this.isRunning) {
      getNativeAudio().setBeatLevel(beatIndex, this.beatLevels[beatIndex]);
    }
  }

  // ===== 读值 =====
  getBpm(): number {
    return this.bpm;
  }

  getTimeSignatureIdx(): number {
    return this.timeSignatureIdx;
  }

  getRhythmIdx(): number {
    return this.rhythmIdx;
  }

  getVolume(): number {
    return this.volume;
  }

  getClickFreq(): number {
    return this.clickFreq;
  }

  getTimbreIdx(): number {
    return this.timbreIdx;
  }

  getBeatLevels(): number[] {
    return this.beatLevels.slice();
  }

  // ===== 推送全部参数（启动时） =====
  private pushParams(): void {
    const native = getNativeAudio();
    native.setBpm(this.bpm);
    native.setTimeSignature(TIME_SIGNATURES[this.timeSignatureIdx][0]);
    native.setSubdivide(RHYTHM_PATTERNS[this.rhythmIdx].subdivide);
    native.setAccentEnabled(this.accentEnabled);
    native.setVibrateOnBeat(this.vibrateEnabled);
    native.setClickGain(this.volume / 100);
    native.setClickFrequency(this.clickFreq);
    native.setClickTimbre(this.timbreIdx);
    for (let i = 0; i < this.beatLevels.length; i++) {
      native.setBeatLevel(i, this.beatLevels[i]);
    }
  }

  // ===== 原生节拍事件 =====
  private onNativeBeat(beat: number, beatsPerBar: number, bar: number): void {
    // 振动反馈（每拍；重拍振动更强）
    if (this.vibrateEnabled) {
      const isAccent = beat === 0;
      const duration = isAccent ? 25 : 12;
      try {
        vibrator.startVibration(
          { type: 'time', duration: duration },
          { id: 0, usage: 'touch' }
        ).catch(() => {});
      } catch (e) {
        // 振动失败忽略
      }
    }
    if (this.beatListener) {
      this.beatListener(beat, beatsPerBar, bar);
    }
  }
}

// 单例
let instance: MetronomeViewModel | null = null;

export function getMetronomeViewModel(): MetronomeViewModel {
  if (instance === null) {
    instance = new MetronomeViewModel();
  }
  return instance;
}
