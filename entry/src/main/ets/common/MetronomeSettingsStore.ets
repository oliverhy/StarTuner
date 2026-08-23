/*
 * 节拍器设置持久化
 *
 * 节拍器页面的状态原本只存在内存中。这里使用 Preferences 保存用户的
 * 播放参数和每一拍强弱，应用进程结束后仍可以恢复上次设置。
 */

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { METRONOME_BPM_MAX, METRONOME_BPM_MIN } from './Constants';

export interface MetronomeSettings {
  bpm: number;
  timeSignatureIdx: number;
  rhythmIdx: number;
  accentEnabled: boolean;
  vibrateEnabled: boolean;
  volume: number;
  clickFreq: number;
  timbreIdx: number;
  beatLevels: number[];
  stopAfterMinutes: number;
}

const PREFERENCES_NAME: string = 'metronome_settings';
const BEAT_COUNT: number = 12;
const TIME_SIGNATURE_COUNT: number = 12;
const RHYTHM_COUNT: number = 4;
const TIMBRE_COUNT: number = 6;
const CLICK_FREQ_MIN: number = 500;
const CLICK_FREQ_MAX: number = 4000;

function defaultBeatLevel(index: number): number {
  return index === 0 ? 3 : 1;
}

function defaultSettings(): MetronomeSettings {
  const beatLevels: number[] = [];
  for (let i = 0; i < BEAT_COUNT; i++) {
    beatLevels.push(defaultBeatLevel(i));
  }
  return {
    bpm: 100,
    timeSignatureIdx: 3,
    rhythmIdx: 0,
    accentEnabled: true,
    vibrateEnabled: true,
    volume: 100,
    clickFreq: 2200,
    timbreIdx: 0,
    beatLevels,
    stopAfterMinutes: 0
  };
}

function copySettings(settings: MetronomeSettings): MetronomeSettings {
  const beatLevels: number[] = [];
  for (let i = 0; i < BEAT_COUNT; i++) {
    beatLevels.push(settings.beatLevels[i]);
  }
  return {
    bpm: settings.bpm,
    timeSignatureIdx: settings.timeSignatureIdx,
    rhythmIdx: settings.rhythmIdx,
    accentEnabled: settings.accentEnabled,
    vibrateEnabled: settings.vibrateEnabled,
    volume: settings.volume,
    clickFreq: settings.clickFreq,
    timbreIdx: settings.timbreIdx,
    beatLevels,
    stopAfterMinutes: settings.stopAfterMinutes
  };
}

function clamp(value: number, min: number, max: number, fallback: number): number {
  if (!(value >= min && value <= max)) {
    return fallback;
  }
  return value;
}

function readNumber(value: preferences.ValueType, fallback: number): number {
  const numberValue = value as number;
  return typeof numberValue === 'number' ? numberValue : fallback;
}

function readBoolean(value: preferences.ValueType, fallback: boolean): boolean {
  const booleanValue = value as boolean;
  return typeof booleanValue === 'boolean' ? booleanValue : fallback;
}

export class MetronomeSettingsStore {
  private prefs: preferences.Preferences | null = null;
  private writeQueue: Promise<void> = Promise.resolve();

  async load(context: common.UIAbilityContext): Promise<MetronomeSettings> {
    try {
      this.prefs = await preferences.getPreferences(context, PREFERENCES_NAME);
      const prefs = this.prefs;
      if (prefs === null) {
        return defaultSettings();
      }

      const defaults = defaultSettings();
      const beatLevels: number[] = [];
      for (let i = 0; i < BEAT_COUNT; i++) {
        const level = clamp(
          readNumber(await prefs.get(`beatLevel${i}`, defaultBeatLevel(i)), defaultBeatLevel(i)),
          0,
          3,
          defaultBeatLevel(i)
        );
        beatLevels.push(Math.round(level));
      }

      return {
        bpm: clamp(
          readNumber(await prefs.get('bpm', defaults.bpm), defaults.bpm),
          METRONOME_BPM_MIN,
          METRONOME_BPM_MAX,
          defaults.bpm
        ),
        timeSignatureIdx: Math.round(clamp(
          readNumber(await prefs.get('timeSignatureIdx', defaults.timeSignatureIdx), defaults.timeSignatureIdx),
          0,
          TIME_SIGNATURE_COUNT - 1,
          defaults.timeSignatureIdx
        )),
        rhythmIdx: Math.round(clamp(
          readNumber(await prefs.get('rhythmIdx', defaults.rhythmIdx), defaults.rhythmIdx),
          0,
          RHYTHM_COUNT - 1,
          defaults.rhythmIdx
        )),
        accentEnabled: readBoolean(
          await prefs.get('accentEnabled', defaults.accentEnabled),
          defaults.accentEnabled
        ),
        vibrateEnabled: readBoolean(
          await prefs.get('vibrateEnabled', defaults.vibrateEnabled),
          defaults.vibrateEnabled
        ),
        volume: clamp(
          readNumber(await prefs.get('volume', defaults.volume), defaults.volume),
          0,
          100,
          defaults.volume
        ),
        clickFreq: clamp(
          readNumber(await prefs.get('clickFreq', defaults.clickFreq), defaults.clickFreq),
          CLICK_FREQ_MIN,
          CLICK_FREQ_MAX,
          defaults.clickFreq
        ),
        timbreIdx: Math.round(clamp(
          readNumber(await prefs.get('timbreIdx', defaults.timbreIdx), defaults.timbreIdx),
          0,
          TIMBRE_COUNT - 1,
          defaults.timbreIdx
        )),
        beatLevels,
        stopAfterMinutes: clamp(
          readNumber(await prefs.get('stopAfterMinutes', defaults.stopAfterMinutes), defaults.stopAfterMinutes),
          0,
          30,
          defaults.stopAfterMinutes
        )
      };
    } catch (err) {
      console.error(`Load metronome settings failed: ${JSON.stringify(err)}`);
      this.prefs = null;
      return defaultSettings();
    }
  }

  save(settings: MetronomeSettings): void {
    const prefs = this.prefs;
    if (prefs === null) {
      return;
    }

    const snapshot: MetronomeSettings = copySettings(settings);
    this.writeQueue = this.writeQueue
      .then(async () => {
        await prefs.put('bpm', snapshot.bpm);
        await prefs.put('timeSignatureIdx', snapshot.timeSignatureIdx);
        await prefs.put('rhythmIdx', snapshot.rhythmIdx);
        await prefs.put('accentEnabled', snapshot.accentEnabled);
        await prefs.put('vibrateEnabled', snapshot.vibrateEnabled);
        await prefs.put('volume', snapshot.volume);
        await prefs.put('clickFreq', snapshot.clickFreq);
        await prefs.put('timbreIdx', snapshot.timbreIdx);
        for (let i = 0; i < BEAT_COUNT; i++) {
          await prefs.put(`beatLevel${i}`, snapshot.beatLevels[i]);
        }
        await prefs.put('stopAfterMinutes', snapshot.stopAfterMinutes);
        await prefs.flush();
      })
      .catch((err: Error) => {
        console.error(`Save metronome settings failed: ${JSON.stringify(err)}`);
      });
  }
}
