/*
 * 调音器设置持久化
 *
 * 设置写入 Preferences 后，即使应用进程被系统回收或用户关闭应用，
 * 下次启动仍可以恢复上一次的调音参数。
 */

import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  TUNER_A4_MAX,
  TUNER_A4_MIN,
  TUNER_DEFAULT_A4,
  TUNER_FREQ_MAX,
  TUNER_FREQ_MIN
} from './Constants';

export interface TunerSettings {
  targetMode: string;
  instrumentId: string;
  selectedInstrumentCategory: string;
  selectedNoteIdx: number;
  targetFreqHz: number;
  a4Ref: number;
}

export const DEFAULT_TUNER_SETTINGS: TunerSettings = {
  targetMode: 'instrument',
  instrumentId: 'guitar',
  selectedInstrumentCategory: 'common',
  selectedNoteIdx: 9,
  targetFreqHz: 440,
  a4Ref: TUNER_DEFAULT_A4
};

const PREFERENCES_NAME: string = 'tuner_settings';

function defaultSettings(): TunerSettings {
  return {
    targetMode: DEFAULT_TUNER_SETTINGS.targetMode,
    instrumentId: DEFAULT_TUNER_SETTINGS.instrumentId,
    selectedInstrumentCategory: DEFAULT_TUNER_SETTINGS.selectedInstrumentCategory,
    selectedNoteIdx: DEFAULT_TUNER_SETTINGS.selectedNoteIdx,
    targetFreqHz: DEFAULT_TUNER_SETTINGS.targetFreqHz,
    a4Ref: DEFAULT_TUNER_SETTINGS.a4Ref
  };
}

function copySettings(settings: TunerSettings): TunerSettings {
  return {
    targetMode: settings.targetMode,
    instrumentId: settings.instrumentId,
    selectedInstrumentCategory: settings.selectedInstrumentCategory,
    selectedNoteIdx: settings.selectedNoteIdx,
    targetFreqHz: settings.targetFreqHz,
    a4Ref: settings.a4Ref
  };
}

function clamp(value: number, min: number, max: number, fallback: number): number {
  // NaN 与边界比较均为 false，因此该判断也能过滤损坏的旧值。
  if (!(value >= min && value <= max)) {
    return fallback;
  }
  return value;
}

function readNumber(value: preferences.ValueType, fallback: number): number {
  const numberValue = value as number;
  return typeof numberValue === 'number' ? numberValue : fallback;
}

function readString(value: preferences.ValueType, fallback: string): string {
  const stringValue = value as string;
  return typeof stringValue === 'string' ? stringValue : fallback;
}

export class TunerSettingsStore {
  private prefs: preferences.Preferences | null = null;
  private writeQueue: Promise<void> = Promise.resolve();

  async load(context: common.UIAbilityContext): Promise<TunerSettings> {
    try {
      this.prefs = await preferences.getPreferences(context, PREFERENCES_NAME);
      const prefs = this.prefs;
      if (prefs === null) {
        return defaultSettings();
      }

      const targetMode = readString(
        await prefs.get('targetMode', DEFAULT_TUNER_SETTINGS.targetMode),
        DEFAULT_TUNER_SETTINGS.targetMode
      );
      const instrumentId = readString(
        await prefs.get('instrumentId', DEFAULT_TUNER_SETTINGS.instrumentId),
        DEFAULT_TUNER_SETTINGS.instrumentId
      );
      const selectedInstrumentCategory = readString(
        await prefs.get('selectedInstrumentCategory', DEFAULT_TUNER_SETTINGS.selectedInstrumentCategory),
        DEFAULT_TUNER_SETTINGS.selectedInstrumentCategory
      );
      const selectedNoteIdx = clamp(
        readNumber(await prefs.get('selectedNoteIdx', DEFAULT_TUNER_SETTINGS.selectedNoteIdx),
          DEFAULT_TUNER_SETTINGS.selectedNoteIdx),
        0,
        11,
        DEFAULT_TUNER_SETTINGS.selectedNoteIdx
      );
      const targetFreqHz = clamp(
        readNumber(await prefs.get('targetFreqHz', DEFAULT_TUNER_SETTINGS.targetFreqHz),
          DEFAULT_TUNER_SETTINGS.targetFreqHz),
        TUNER_FREQ_MIN,
        TUNER_FREQ_MAX,
        DEFAULT_TUNER_SETTINGS.targetFreqHz
      );
      const a4Ref = clamp(
        readNumber(await prefs.get('a4Ref', DEFAULT_TUNER_SETTINGS.a4Ref), DEFAULT_TUNER_SETTINGS.a4Ref),
        TUNER_A4_MIN,
        TUNER_A4_MAX,
        DEFAULT_TUNER_SETTINGS.a4Ref
      );

      return {
        targetMode,
        instrumentId,
        selectedInstrumentCategory,
        selectedNoteIdx: Math.round(selectedNoteIdx),
        targetFreqHz,
        a4Ref
      };
    } catch (err) {
      console.error(`Load tuner settings failed: ${JSON.stringify(err)}`);
      this.prefs = null;
      return defaultSettings();
    }
  }

  save(settings: TunerSettings): void {
    const prefs = this.prefs;
    if (prefs === null) {
      return;
    }

    // 快速拖动 A4 滑块时串行写入，避免多个异步 flush 乱序覆盖最新值。
    const snapshot: TunerSettings = copySettings(settings);
    this.writeQueue = this.writeQueue
      .then(async () => {
        await prefs.put('targetMode', snapshot.targetMode);
        await prefs.put('instrumentId', snapshot.instrumentId);
        await prefs.put('selectedInstrumentCategory', snapshot.selectedInstrumentCategory);
        await prefs.put('selectedNoteIdx', snapshot.selectedNoteIdx);
        await prefs.put('targetFreqHz', snapshot.targetFreqHz);
        await prefs.put('a4Ref', snapshot.a4Ref);
        await prefs.flush();
      })
      .catch((err: Error) => {
        console.error(`Save tuner settings failed: ${JSON.stringify(err)}`);
      });
  }
}
