/*
 * 节拍器：高对比玻璃控制台
 */

import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import {
  getMetronomeViewModel, MetronomeViewModel,
  TIME_SIGNATURES, RHYTHM_PATTERNS, CLICK_TIMBRES,
  RhythmPattern, ClickTimbre
} from '../viewmodel/MetronomeViewModel';
import { METRONOME_BPM_MIN, METRONOME_BPM_MAX } from '../common/Constants';
import { MetronomeSettings, MetronomeSettingsStore } from '../common/MetronomeSettingsStore';

@Entry
@Component
struct MetronomePage {
  @State bpm: number = 100;
  @State isRunning: boolean = false;
  @State timeSignatureIdx: number = 3;
  @State rhythmIdx: number = 0;
  @State accentEnabled: boolean = true;
  @State vibrateEnabled: boolean = true;
  @State volume: number = 100;
  @State currentBeat: number = 0;
  @State clickFreq: number = 2200;
  @State timbreIdx: number = 0;
  @State tapTimes: number[] = [];
  @State beatLevels: number[] = [3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
  @State stopAfterMinutes: number = 0;
  @State metronomeAngle: number = 0;
  @State settingsReady: boolean = false;

  private vm: MetronomeViewModel = getMetronomeViewModel();
  private settingsStore: MetronomeSettingsStore = new MetronomeSettingsStore();
  private swingDirection: number = 1;
  private stopTimer: number = -1;
  private timerOptions: number[] = [0, 5, 10, 20, 30];
  private context = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.settingsReady = false;
    this.bpm = this.vm.getBpm();
    this.timeSignatureIdx = this.vm.getTimeSignatureIdx();
    this.rhythmIdx = this.vm.getRhythmIdx();
    this.volume = this.vm.getVolume();
    this.clickFreq = this.vm.getClickFreq();
    this.timbreIdx = this.vm.getTimbreIdx();
    this.beatLevels = this.vm.getBeatLevels();
    this.vm.setBeatListener((beat: number, beatsPerBar: number, bar: number) => {
      this.currentBeat = beat;
      this.swingDirection = -this.swingDirection;
      this.metronomeAngle = this.swingDirection * 18;
    });
    void this.restoreSettings();
  }

  aboutToDisappear(): void {
    this.persistSettings();
    this.vm.stop(this.context);
    this.clearStopTimer();
  }

  private async restoreSettings(): Promise<void> {
    const settings: MetronomeSettings = await this.settingsStore.load(this.context);
    this.bpm = settings.bpm;
    this.timeSignatureIdx = settings.timeSignatureIdx;
    this.rhythmIdx = settings.rhythmIdx;
    this.accentEnabled = settings.accentEnabled;
    this.vibrateEnabled = settings.vibrateEnabled;
    this.volume = settings.volume;
    this.clickFreq = settings.clickFreq;
    this.timbreIdx = settings.timbreIdx;
    this.beatLevels = settings.beatLevels;
    this.stopAfterMinutes = this.timerOptions.indexOf(settings.stopAfterMinutes) >= 0 ?
      settings.stopAfterMinutes : 0;
    this.syncParamsToViewModel();
    this.settingsReady = true;
  }

  private syncParamsToViewModel(): void {
    this.vm.setBpm(this.bpm);
    this.vm.setTimeSignatureIdx(this.timeSignatureIdx);
    this.vm.setRhythmIdx(this.rhythmIdx);
    this.vm.setAccentEnabled(this.accentEnabled);
    this.vm.setVibrateEnabled(this.vibrateEnabled);
    this.vm.setVolume(this.volume);
    this.vm.setClickFreq(this.clickFreq);
    this.vm.setClickTimbre(this.timbreIdx);
    for (let i = 0; i < this.beatLevels.length; i++) {
      this.vm.setBeatLevel(i, this.beatLevels[i]);
    }
  }

  private persistSettings(): void {
    if (!this.settingsReady) {
      return;
    }
    const settings: MetronomeSettings = {
      bpm: this.bpm,
      timeSignatureIdx: this.timeSignatureIdx,
      rhythmIdx: this.rhythmIdx,
      accentEnabled: this.accentEnabled,
      vibrateEnabled: this.vibrateEnabled,
      volume: this.volume,
      clickFreq: this.clickFreq,
      timbreIdx: this.timbreIdx,
      beatLevels: this.beatLevels.slice(),
      stopAfterMinutes: this.stopAfterMinutes
    };
    this.settingsStore.save(settings);
  }

  private toggleRun(): void {
    if (!this.settingsReady) {
      return;
    }
    if (this.isRunning) {
      this.vm.stop(this.context);
      this.isRunning = false;
      this.metronomeAngle = 0;
      this.swingDirection = 1;
      this.clearStopTimer();
    } else {
      this.syncParamsToViewModel();
      this.persistSettings();
      this.isRunning = this.vm.start(this.context);
      if (this.isRunning) {
        this.scheduleStopTimer();
      }
    }
  }

  private changeBpm(delta: number): void {
    if (!this.settingsReady) {
      return;
    }
    this.bpm = Math.max(METRONOME_BPM_MIN, Math.min(METRONOME_BPM_MAX, this.bpm + delta));
    this.vm.setBpm(this.bpm);
    this.persistSettings();
  }

  private swingDuration(): number {
    return Math.max(120, Math.round(60000 / this.bpm));
  }

  private handleTap(): void {
    if (!this.settingsReady) {
      return;
    }
    const now = Date.now();
    this.tapTimes.push(now);
    while (this.tapTimes.length > 0 && now - this.tapTimes[0] > 2000) {
      this.tapTimes.shift();
    }
    if (this.tapTimes.length >= 2) {
      const intervals: number[] = [];
      for (let i = 1; i < this.tapTimes.length; i++) {
        intervals.push(this.tapTimes[i] - this.tapTimes[i - 1]);
      }
      const avg = intervals.reduce((a, b) => a + b, 0) / intervals.length;
      const bpmVal = Math.round(60000 / avg);
      if (bpmVal >= METRONOME_BPM_MIN && bpmVal <= METRONOME_BPM_MAX) {
        this.bpm = bpmVal;
        this.vm.setBpm(bpmVal);
        this.persistSettings();
      }
    }
  }

  private onTimbreChange(idx: number): void {
    if (!this.settingsReady) {
      return;
    }
    this.timbreIdx = idx;
    this.clickFreq = CLICK_TIMBRES[idx].freq;
    this.vm.setClickTimbre(idx);
    this.vm.setClickFreq(this.clickFreq);
    this.persistSettings();
  }

  private beatIndices(): number[] {
    const result: number[] = [];
    const count = TIME_SIGNATURES[this.timeSignatureIdx][0];
    for (let i = 0; i < count; i++) {
      result.push(i);
    }
    return result;
  }

  private cycleBeatLevel(beatIndex: number): void {
    if (!this.settingsReady) {
      return;
    }
    const nextLevels = this.beatLevels.slice();
    nextLevels[beatIndex] = (nextLevels[beatIndex] + 1) % 4;
    this.beatLevels = nextLevels;
    this.vm.setBeatLevel(beatIndex, nextLevels[beatIndex]);
    this.persistSettings();
  }

  private beatLevelName(level: number): string {
    return ['静', '弱', '中', '强'][level];
  }

  private beatLevelHeight(level: number): number {
    // 强拍填满柱体，弱拍和中拍按等级递增，静音不显示填充。
    if (level <= 0) {
      return 0;
    }
    return Math.min(42, level * 14);
  }

  private beatLevelColor(level: number, active: boolean): string {
    if (level === 0) {
      return active ? '#66718A' : '#343C51';
    }
    if (level === 3) {
      return active ? '#FFE08A' : '#FFB35C';
    }
    return active ? '#FF9F72' : '#B9675B';
  }

  private tempoName(): string {
    if (this.bpm < 45) return 'Grave · 庄板';
    if (this.bpm < 60) return 'Largo · 广板';
    if (this.bpm < 76) return 'Adagio · 柔板';
    if (this.bpm < 108) return 'Andante · 行板';
    if (this.bpm < 120) return 'Moderato · 中板';
    if (this.bpm < 168) return 'Allegro · 快板';
    if (this.bpm < 200) return 'Presto · 急板';
    return 'Prestissimo · 最急板';
  }

  private clearStopTimer(): void {
    if (this.stopTimer >= 0) {
      clearTimeout(this.stopTimer);
      this.stopTimer = -1;
    }
  }

  private scheduleStopTimer(): void {
    this.clearStopTimer();
    if (!this.isRunning || this.stopAfterMinutes <= 0) {
      return;
    }
    this.stopTimer = setTimeout(() => {
      this.vm.stop(this.context);
      this.isRunning = false;
      this.currentBeat = 0;
      this.metronomeAngle = 0;
      this.swingDirection = 1;
      this.stopTimer = -1;
    }, this.stopAfterMinutes * 60 * 1000);
  }

  private selectStopTimer(minutes: number): void {
    if (!this.settingsReady) {
      return;
    }
    this.stopAfterMinutes = minutes;
    this.scheduleStopTimer();
    this.persistSettings();
  }

  @Builder
  private AuroraBackground() {
    Column()
    .width('100%')
    .height('100%')
    .backgroundColor('#080A19')
    .linearGradient({
      angle: 145,
      colors: [['#302718', 0.0], ['#141228', 0.3], ['#0A1730', 0.58], ['#101122', 0.78], ['#241519', 1.0]]
    })
  }

  build() {
    Stack() {
      this.AuroraBackground()

      Column() {
        Row() {
          Row() {
            Text('‹')
              .fontSize(30)
              .fontColor('#FFFFFF')
          }
            .width(44)
            .height(44)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .borderRadius(22)
            .backgroundColor('#241F3150')
            .border({ width: 1, color: '#355F779E' })
            .onClick(() => router.back())
          Column({ space: 2 }) {
            Text('强力节拍')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F6F9FF')
            Text('高穿透练习模式')
              .fontSize(12)
              .fontColor('#FFBD68')
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          Blank()
          Row({ space: 6 }) {
            Circle().width(7).height(7).fill(this.isRunning ? '#FFB35C' : '#63749A')
            Text(this.isRunning ? '播放中' : '已停止')
              .fontSize(11)
              .fontColor(this.isRunning ? '#FFD39B' : '#91A1C1')
          }
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .borderRadius(16)
          .backgroundColor('#251C2A42')
        }
        .width('100%')
        .height(64)
        .padding({ left: 16, right: 16 })

        Scroll() {
          Column({ space: 14 }) {
            Stack() {
              Image($r('app.media.metronome_body'))
                .width(145)
                .height(145)
                .objectFit(ImageFit.Contain)
                .position({ x: 9, y: 16 })

              Image($r('app.media.metronome_pendulum'))
                .width(95)
                .height(95)
                .objectFit(ImageFit.Contain)
                .position({ x: 37, y: 24 })
                .rotate({ angle: this.metronomeAngle, centerX: '50%', centerY: '97.5%' })
                .animation({
                  duration: this.swingDuration(),
                  curve: Curve.EaseInOut,
                  iterations: 1,
                  playMode: PlayMode.Normal
                })
              Column({ space: 0 }) {
                Text(`${this.bpm}`)
                  .fontSize(80)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                Text('BPM')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .letterSpacing(3)
                  .fontColor('#FFBD68')
                Text(this.tempoName())
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFE1B7')
                  .margin({ top: 5 })
                Text(`${TIME_SIGNATURES[this.timeSignatureIdx][0]}/${TIME_SIGNATURES[this.timeSignatureIdx][1]}  ·  ${RHYTHM_PATTERNS[this.rhythmIdx].name}`)
                  .fontSize(12)
                  .fontColor('#A9B7D4')
                  .margin({ top: 9 })
              }
              .width('100%')
              .height(184)
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .padding({ left: 120 })
            }
            .width('92%')
            .height(190)
            .borderRadius(28)
            .backgroundColor('#2A201C3A')
            .backgroundBlurStyle(BlurStyle.Regular, { colorMode: ThemeColorMode.DARK })
            .border({ width: 1, color: '#48B77AFF' })
            .shadow({ radius: 25, color: '#35D27846', offsetY: 12 })

            Column({ space: 10 }) {
              Row({ space: 6 }) {
                ForEach(this.beatIndices(), (i: number) => {
                  Column({ space: 3 }) {
                    Stack({ alignContent: Alignment.Bottom }) {
                      Rect()
                        .width(24)
                        .height(42)
                        .radius(8)
                        .fill('#22192134')
                        .stroke(i === this.currentBeat && this.isRunning ? '#FFFFD28A' : '#315B6888')
                        .strokeWidth(1)
                      Rect()
                        .width(20)
                        .height(this.beatLevelHeight(this.beatLevels[i]))
                        .radius(6)
                        .fill(this.beatLevelColor(this.beatLevels[i], i === this.currentBeat && this.isRunning))
                    }
                    .width(28)
                    .height(42)
                    Text(`${i + 1} · ${this.beatLevelName(this.beatLevels[i])}`)
                      .fontSize(9)
                      .fontColor(i === this.currentBeat && this.isRunning ? '#FFE4B6' : '#8FA0BF')
                  }
                  .width(44)
                  .height(61)
                  .alignItems(HorizontalAlign.Center)
                  .justifyContent(FlexAlign.End)
                  .onClick(() => this.cycleBeatLevel(i))
                }, (i: number) => i.toString())
              }
              .width('100%')
              .height(62)
              .justifyContent(FlexAlign.SpaceEvenly)

              Text('点击每一拍切换：静音 / 弱 / 中 / 强')
                .fontSize(10)
                .fontColor('#7F90AF')

              Slider({ value: this.bpm, min: METRONOME_BPM_MIN, max: METRONOME_BPM_MAX, step: 1 })
                .width('100%')
                .selectedColor('#FF9F5C')
                .trackColor('#3D4A4260')
                .blockColor('#FFF1D9')
                .onChange((value: number) => {
                  if (!this.settingsReady) {
                    return;
                  }
                  this.bpm = value;
                  this.vm.setBpm(value);
                  this.persistSettings();
                })

              Row({ space: 10 }) {
                Row() {
                  Text('-')
                    .fontSize(23)
                    .fontColor('#ECF2FF')
                }
                  .width(52)
                  .height(46)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .borderRadius(23)
                  .backgroundColor('#30172036')
                  .border({ width: 1, color: '#3C63728F' })
                  .onClick(() => this.changeBpm(-1))
                Row() {
                  Text('TAP')
                    .fontSize(13)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#241005')
                }
                  .layoutWeight(1)
                  .height(46)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .borderRadius(23)
                  .backgroundColor('#FFB35C')
                  .shadow({ radius: 14, color: '#55FF9148' })
                  .onClick(() => this.handleTap())
                Row() {
                  Text('+')
                    .fontSize(23)
                    .fontColor('#ECF2FF')
                }
                  .width(52)
                  .height(46)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .borderRadius(23)
                  .backgroundColor('#30172036')
                  .border({ width: 1, color: '#3C63728F' })
                  .onClick(() => this.changeBpm(1))
              }
              .width('100%')
            }
            .width('92%')
            .padding(15)
            .borderRadius(23)
            .backgroundColor('#25182136')
            .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.DARK })
            .border({ width: 1, color: '#326B7390' })

            Column({ space: 12 }) {
              Row() {
                Text('节奏设置')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F5F8FF')
                Blank()
                Text('拍号 / 细分')
                  .fontSize(11)
                  .fontColor('#8E9FBE')
              }

              Scroll() {
                Row({ space: 7 }) {
                  ForEach(TIME_SIGNATURES, (ts: number[], idx: number) => {
                    Row() {
                      Text(`${ts[0]}/${ts[1]}`)
                        .fontSize(11)
                        .fontWeight(this.timeSignatureIdx === idx ? FontWeight.Bold : FontWeight.Normal)
                        .fontColor(this.timeSignatureIdx === idx ? '#251005' : '#B3C0D9')
                    }
                      .width(52)
                      .height(34)
                      .justifyContent(FlexAlign.Center)
                      .alignItems(VerticalAlign.Center)
                      .borderRadius(14)
                      .backgroundColor(this.timeSignatureIdx === idx ? '#FFB35C' : '#24172034')
                      .onClick(() => {
                        if (!this.settingsReady) {
                          return;
                        }
                        this.timeSignatureIdx = idx;
                        this.currentBeat = 0;
                        this.vm.setTimeSignatureIdx(idx);
                        this.persistSettings();
                      })
                  }, (ts: number[], idx: number) => `${ts[0]}-${ts[1]}-${idx}`)
                }
              }
              .width('100%')
              .height(38)
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)

              Row({ space: 7 }) {
                ForEach(RHYTHM_PATTERNS, (p: RhythmPattern, idx: number) => {
                  Row() {
                    Text(p.name)
                      .fontSize(11)
                      .fontColor(this.rhythmIdx === idx ? '#251005' : '#B3C0D9')
                  }
                    .layoutWeight(1)
                    .height(35)
                    .justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Center)
                    .borderRadius(14)
                    .backgroundColor(this.rhythmIdx === idx ? '#FFB35C' : '#24172034')
                    .onClick(() => {
                      if (!this.settingsReady) {
                        return;
                      }
                      this.rhythmIdx = idx;
                      this.vm.setRhythmIdx(idx);
                      this.persistSettings();
                    })
                }, (p: RhythmPattern) => p.name)
              }
              .width('100%')
            }
            .width('92%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .borderRadius(24)
            .backgroundColor('#25182136')
            .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.DARK })
            .border({ width: 1, color: '#326B7390' })

            Column({ space: 12 }) {
              Row() {
                Text('声音')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F5F8FF')
                Blank()
                Text(`${CLICK_TIMBRES[this.timbreIdx].name}  ·  ${this.clickFreq} Hz`)
                  .fontSize(11)
                  .fontColor('#FFBD68')
              }

              Row({ space: 7 }) {
                ForEach(CLICK_TIMBRES, (t: ClickTimbre, idx: number) => {
                  Row() {
                    Text(t.name)
                      .fontSize(11)
                      .fontColor(this.timbreIdx === idx ? '#251005' : '#B3C0D9')
                  }
                    .layoutWeight(1)
                    .height(34)
                    .justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Center)
                    .borderRadius(14)
                    .backgroundColor(this.timbreIdx === idx ? '#FFB35C' : '#24172034')
                    .onClick(() => this.onTimbreChange(idx))
                }, (t: ClickTimbre) => t.name)
              }
              .width('100%')

              Row() {
                Text('音高')
                  .width(42)
                  .fontSize(12)
                  .fontColor('#AEBBD3')
                Slider({ value: this.clickFreq, min: 500, max: 4000, step: 10 })
                  .layoutWeight(1)
                  .selectedColor('#FF9F5C')
                  .trackColor('#3D4A4260')
                  .blockColor('#FFF1D9')
                  .onChange((value: number) => {
                    if (!this.settingsReady) {
                      return;
                    }
                    this.clickFreq = value;
                    this.vm.setClickFreq(value);
                    this.persistSettings();
                  })
              }
              .width('100%')

              Row() {
                Text('音量')
                  .width(42)
                  .fontSize(12)
                  .fontColor('#AEBBD3')
                Slider({ value: this.volume, min: 0, max: 100, step: 1 })
                  .layoutWeight(1)
                  .selectedColor('#FF9F5C')
                  .trackColor('#3D4A4260')
                  .blockColor('#FFF1D9')
                  .onChange((value: number) => {
                    if (!this.settingsReady) {
                      return;
                    }
                    this.volume = value;
                    this.vm.setVolume(value);
                    this.persistSettings();
                  })
                Text(`${this.volume}%`)
                  .width(42)
                  .fontSize(11)
                  .fontColor('#FFBD68')
                  .textAlign(TextAlign.End)
              }
              .width('100%')
            }
            .width('92%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .borderRadius(24)
            .backgroundColor('#25182136')
            .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.DARK })
            .border({ width: 1, color: '#326B7390' })

            Column({ space: 10 }) {
              Row() {
                Text('定时停止')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F5F8FF')
                Blank()
                Text(this.stopAfterMinutes === 0 ? '持续播放' : `${this.stopAfterMinutes} 分钟后停止`)
                  .fontSize(11)
                  .fontColor('#FFBD68')
              }
              Row({ space: 7 }) {
                ForEach(this.timerOptions, (minutes: number) => {
                  Row() {
                    Text(minutes === 0 ? '关闭' : `${minutes}分`)
                      .fontSize(11)
                      .fontColor(this.stopAfterMinutes === minutes ? '#251005' : '#B3C0D9')
                  }
                  .layoutWeight(1)
                  .height(34)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .borderRadius(14)
                  .backgroundColor(this.stopAfterMinutes === minutes ? '#FFB35C' : '#24172034')
                  .onClick(() => this.selectStopTimer(minutes))
                }, (minutes: number) => minutes.toString())
              }
              .width('100%')
            }
            .width('92%')
            .padding(16)
            .alignItems(HorizontalAlign.Start)
            .borderRadius(24)
            .backgroundColor('#25182136')
            .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.DARK })
            .border({ width: 1, color: '#326B7390' })

            Row({ space: 10 }) {
              Row() {
                Column({ space: 2 }) {
                  Text('强拍音色')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#F0F4FF')
                  Text('等级为强时使用高音')
                    .fontSize(10)
                    .fontColor('#8293B3')
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.accentEnabled })
                  .selectedColor('#FF9F5C')
                  .onChange((on: boolean) => {
                    if (!this.settingsReady) {
                      return;
                    }
                    this.accentEnabled = on;
                    this.vm.setAccentEnabled(on);
                    this.persistSettings();
                  })
              }
              .layoutWeight(1)
              .height(70)
              .padding({ left: 13, right: 10 })
              .borderRadius(20)
              .backgroundColor('#25182136')
              .border({ width: 1, color: '#326B7390' })

              Row() {
                Column({ space: 2 }) {
                  Text('节拍振动')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#F0F4FF')
                  Text('嘈杂环境辅助感知')
                    .fontSize(10)
                    .fontColor('#8293B3')
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.vibrateEnabled })
                  .selectedColor('#FF9F5C')
                  .onChange((on: boolean) => {
                    if (!this.settingsReady) {
                      return;
                    }
                    this.vibrateEnabled = on;
                    this.vm.setVibrateEnabled(on);
                    this.persistSettings();
                  })
              }
              .layoutWeight(1)
              .height(70)
              .padding({ left: 13, right: 10 })
              .borderRadius(20)
              .backgroundColor('#25182136')
              .border({ width: 1, color: '#326B7390' })
            }
            .width('92%')
          }
          .padding({ top: 4, bottom: 18 })
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)

        Row() {
          Text(this.settingsReady ? (this.isRunning ? '停止节拍' : '开始节拍') : '加载设置…')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isRunning ? '#FFE9ED' : '#251005')
        }
          .width('88%')
          .height(56)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .borderRadius(28)
          .backgroundColor(this.isRunning ? '#D9506880' : '#FFB35C')
          .border({ width: 1, color: this.isRunning ? '#FFFF8495' : '#D4FFE0A6' })
          .shadow({ radius: 18, color: this.isRunning ? '#50FF5B70' : '#55FF9148', offsetY: 8 })
          .opacity(this.settingsReady ? 1 : 0.55)
          .margin({ top: 8, bottom: 18 })
          .onClick(() => this.toggleRun())
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
