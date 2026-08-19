/**
 * StarTuner 原生模块类型声明
 * 对应 cpp/napi_init.cpp 导出的方法
 */

export interface StarTunerNative {
  /**
   * 开始麦克风采集（调音器）
   * @returns 是否成功
   */
  startCapture(): boolean;
  /** 停止麦克风采集 */
  stopCapture(): boolean;
  /**
   * 启动节拍器
   * @param bpm 拍速
   * @param beatsPerBar 每小节拍数
   */
  startMetronome(bpm: number, beatsPerBar: number): boolean;
  /** 停止节拍器 */
  stopMetronome(): boolean;
  /** 设置 BPM */
  setBpm(bpm: number): void;
  /** 设置每小节拍数 */
  setTimeSignature(beatsPerBar: number): void;
  /** 设置每拍细分 */
  setSubdivide(subdivide: number): void;
  /** 设置 click 频率 (Hz) */
  setClickFrequency(freq: number): void;
  /** 设置 click 音色索引（0~5） */
  setClickTimbre(timbre: number): void;
  /** 设置 click 音量 0~1 */
  setClickGain(gain: number): void;
  /** 设置某一拍强度：0 静音，1 弱，2 中，3 强 */
  setBeatLevel(beatIndex: number, level: number): void;
  /** 设置重音开关 */
  setAccentEnabled(on: boolean): void;
  /** 设置每拍振动开关 */
  setVibrateOnBeat(on: boolean): void;
  /** 获取当前拍 */
  getCurrentBeat(): number;
  /**
   * 注册音高检测回调
   * @param cb 回调，参数为频率 Hz
   */
  registerPitchCallback(cb: (freq: number) => void): void;
  /**
   * 注册节拍回调
   * @param cb 回调，参数 (beat, beatsPerBar, bar)
   */
  registerBeatCallback(cb: (beat: number, beatsPerBar: number, bar: number) => void): void;
}
