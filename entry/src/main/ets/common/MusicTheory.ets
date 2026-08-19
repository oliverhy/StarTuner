/*
 * 音乐理论工具：音名 <-> 频率 换算、音分计算、A4 基准偏移
 *
 * 约定：
 *  - 使用十二平均律（equal temperament）
 *  - 音名从 C 起，MIDI 编号 0 = C-1（频率 8.1758Hz）
 *  - 频率公式：f = A4_REF * 2^((midi - 69) / 12)
 *  - A4 基准可在 415~466Hz 范围调节（默认 440）
 */

// 音名列表（十二平均律，含升号，C 起始）
export const NOTE_NAMES_SHARP: string[] = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
];

// 音名列表（降号表示，用于显示偏降的乐器如圆号）
export const NOTE_NAMES_FLAT: string[] = [
  'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
];

export const A4_REF_DEFAULT: number = 440.0;
export const A4_REF_MIN: number = 415.0;
export const A4_REF_MAX: number = 466.0;

// 音分偏差范围（调音器表盘显示范围）
export const CENTS_RANGE: number = 50;

/**
 * 计算某个 MIDI 编号的频率
 * @param midi MIDI 编号（0~127）
 * @param a4Ref A4 基准频率（Hz）
 */
export function freqFromMidi(midi: number, a4Ref: number = A4_REF_DEFAULT): number {
  return a4Ref * Math.pow(2, (midi - 69) / 12);
}

/**
 * 由频率反推最近的 MIDI 编号（不四舍五入，返回浮点）
 * @param freq 频率（Hz）
 * @param a4Ref A4 基准频率（Hz）
 */
export function midiFromFreq(freq: number, a4Ref: number = A4_REF_DEFAULT): number {
  if (freq <= 0) {
    return -1;
  }
  return 69 + 12 * Math.log2(freq / a4Ref);
}

// 频率分析结果
export interface FreqAnalysis {
  noteIndex: number; // 0=C 起，-1=无效
  octave: number;
  cents: number;
}

// 显示结果
export interface NoteDisplay {
  name: string;
  cents: number;
}

/**
 * 由频率得到最近音名索引（0=C 起）和八度
 * @param freq 频率（Hz）
 * @param a4Ref A4 基准频率（Hz）
 * @returns {noteIndex, octave, cents} noteIndex 0~11，octave 八度，cents 相对最近音高的音分偏差(-50~+50)
 */
export function analyzeFreq(freq: number, a4Ref: number = A4_REF_DEFAULT): FreqAnalysis {
  const invalid: FreqAnalysis = { noteIndex: -1, octave: 0, cents: 0 };
  if (freq <= 0) {
    return invalid;
  }
  const midiFloat = midiFromFreq(freq, a4Ref);
  const midiRounded = Math.round(midiFloat);
  const cents = Math.round((midiFloat - midiRounded) * 100);
  // 处理整八度边界：若 cents 到 ±50 边界，会四舍五入到相邻八度
  let noteIndex = ((midiRounded % 12) + 12) % 12;
  let octave = Math.floor(midiRounded / 12) - 1; // MIDI 0 = C-1
  const result: FreqAnalysis = { noteIndex, octave, cents };
  return result;
}

/**
 * 由音名索引 + 八度得到 MIDI 编号
 * @param noteIndex 0=C, 1=C#... 11=B
 * @param octave 八度（C4 的 octave=4）
 */
export function midiFromNote(noteIndex: number, octave: number): number {
  return (octave + 1) * 12 + noteIndex;
}

/**
 * 由 MIDI 编号得到音名 + 八度字符串，如 "A4"
 */
export function noteNameFromMidi(midi: number, useFlat: boolean = false): string {
  const names = useFlat ? NOTE_NAMES_FLAT : NOTE_NAMES_SHARP;
  const noteIndex = ((midi % 12) + 12) % 12;
  const octave = Math.floor(midi / 12) - 1;
  return `${names[noteIndex]}${octave}`;
}

/**
 * 由频率得到显示用音名 + 八度 + 音分，如 "A4 +3"
 */
export function displayFromFreq(freq: number, a4Ref: number = A4_REF_DEFAULT, useFlat: boolean = false): NoteDisplay {
  const analysis = analyzeFreq(freq, a4Ref);
  const noteIndex = analysis.noteIndex;
  const octave = analysis.octave;
  const cents = analysis.cents;
  const invalid: NoteDisplay = { name: '--', cents: 0 };
  if (noteIndex < 0) {
    return invalid;
  }
  const names = useFlat ? NOTE_NAMES_FLAT : NOTE_NAMES_SHARP;
  const result: NoteDisplay = { name: `${names[noteIndex]}${octave}`, cents };
  return result;
}

/**
 * 音分换算：频率比 -> 音分
 */
export function centsBetween(freqA: number, freqB: number): number {
  if (freqA <= 0 || freqB <= 0) {
    return 0;
  }
  return 1200 * Math.log2(freqB / freqA);
}

/**
 * 把音分加到频率上：freq * 2^(cents/1200)
 */
export function applyCents(freq: number, cents: number): number {
  return freq * Math.pow(2, cents / 1200);
}

/**
 * 格式化频率，保留 2 位小数，如 "196.00 Hz"
 */
export function formatFreq(freq: number): string {
  return `${freq.toFixed(2)} Hz`;
}
