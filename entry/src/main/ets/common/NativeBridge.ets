/*
 * 原生桥接：封装对 libentry.so 的 N-API 调用
 *
 * 说明：
 *  - libentry.so 由 entry/src/main/cpp 编译产物提供
 *  - 通过静态 import 引用，native 方法由 napi_init.cpp 注册
 */

import native from 'libentry.so';

/**
 * 原生音频能力接口（与 cpp/types/libentry/Index.d.ts 对齐）
 */
export interface NativeAudio {
  startCapture(): boolean;
  stopCapture(): boolean;
  startMetronome(bpm: number, beatsPerBar: number): boolean;
  stopMetronome(): boolean;
  setBpm(bpm: number): void;
  setTimeSignature(beatsPerBar: number): void;
  setSubdivide(subdivide: number): void;
  setClickFrequency(freq: number): void;
  setClickTimbre(timbre: number): void;
  setClickGain(gain: number): void;
  setBeatLevel(beatIndex: number, level: number): void;
  setAccentEnabled(on: boolean): void;
  setVibrateOnBeat(on: boolean): void;
  getCurrentBeat(): number;
  registerPitchCallback(cb: (freq: number) => void): void;
  registerBeatCallback(cb: (beat: number, beatsPerBar: number, bar: number) => void): void;
}

// 懒加载 native（避免冷启动阻塞）
let nativeAudio: NativeAudio | null = null;

/**
 * 获取原生音频模块
 */
export function getNativeAudio(): NativeAudio {
  if (nativeAudio === null) {
    nativeAudio = native as NativeAudio;
  }
  return nativeAudio;
}

/**
 * 是否已加载原生模块
 */
export function isNativeAvailable(): boolean {
  try {
    getNativeAudio();
    return true;
  } catch (e) {
    console.error(`Native module load failed: ${JSON.stringify(e)}`);
    return false;
  }
}
