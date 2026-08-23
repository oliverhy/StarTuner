/*
 * 调音器：玻璃仪表盘 + 44 种乐器图形选择器
 */

import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { getTunerViewModel, TunerViewModel, TunerTargetMode } from '../viewmodel/TunerViewModel';
import { INSTRUMENTS, InstrumentCategory, InstrumentSpec } from '../model/Instruments';
import { displayFromFreq, freqFromMidi } from '../common/MusicTheory';
import { requestMicrophonePermission, checkMicrophonePermission } from '../common/Permissions';
import { TUNER_A4_MIN, TUNER_A4_MAX, TUNER_FREQ_MIN, TUNER_FREQ_MAX } from '../common/Constants';
import { DEFAULT_TUNER_SETTINGS, TunerSettings, TunerSettingsStore } from '../common/TunerSettingsStore';

interface ModeOption {
  key: TunerTargetMode;
  label: string;
}

interface InstrumentCategoryOption {
  key: string;
  label: string;
}

const MODE_OPTIONS: ModeOption[] = [
  { key: TunerTargetMode.INSTRUMENT, label: '乐器定弦' },
  { key: TunerTargetMode.NOTE, label: '通用音名' },
  { key: TunerTargetMode.HZ, label: '自定频率' }
];

const INSTRUMENT_CATEGORY_OPTIONS: InstrumentCategoryOption[] = [
  { key: 'common', label: '常用' },
  { key: InstrumentCategory.PLUCKED, label: '西洋拨弦' },
  { key: InstrumentCategory.CHINESE_PLUCKED, label: '民族弹拨' },
  { key: InstrumentCategory.BOWED, label: '西洋弓弦' },
  { key: InstrumentCategory.CHINESE_BOWED, label: '民族拉弦' },
  { key: InstrumentCategory.KEYBOARD, label: '键盘' },
  { key: InstrumentCategory.WOODWIND, label: '木管' },
  { key: InstrumentCategory.BRASS, label: '铜管' },
  { key: InstrumentCategory.CHINESE_BLOWN, label: '民族吹奏' },
  { key: InstrumentCategory.PERCUSSION, label: '定音打击' }
];

const COMMON_INSTRUMENT_IDS: string[] = [
  'guitar', 'violin', 'guqin', 'guzheng', 'erhu',
  'ukulele', 'piano', 'dizi', 'saxophone-alto'
];

@Entry
@Component
struct TunerPage {
  @State currentNote: string = '--';
  @State currentCents: number = 0;
  @State currentFreq: number = 0;
  @State targetName: string = '--';
  @State isListening: boolean = false;
  @State a4Ref: number = 440;
  @State selectedInstrumentId: string = 'guitar';
  @State targetMode: string = 'instrument';
  @State targetFreqHz: number = 440;
  @State micReady: boolean = false;
  @State instName: string = '吉他';
  @State selectedNoteIdx: number = 9;
  @State selectedInstrumentCategory: string = 'common';
  @State settingsReady: boolean = false;

  private vm: TunerViewModel = getTunerViewModel();
  private settingsStore: TunerSettingsStore = new TunerSettingsStore();
  private context = getContext(this) as common.UIAbilityContext;

  aboutToAppear(): void {
    this.settingsReady = false;
    this.vm.setA4Ref(this.a4Ref);
    this.vm.setInstrumentId(this.selectedInstrumentId);
    this.vm.setTargetMode(this.targetMode as TunerTargetMode);
    this.vm.setTargetMidi(this.midiFromNoteIdx(this.selectedNoteIdx));
    this.vm.setTargetFreqHz(this.targetFreqHz);
    this.micReady = checkMicrophonePermission();
    this.vm.setPitchListener((freq: number, note: string, cents: number, target: string) => {
      this.currentFreq = freq;
      this.currentNote = note;
      this.currentCents = cents;
      this.targetName = target;
    });
    this.vm.setStatusListener((listening: boolean) => {
      this.isListening = listening;
    });
    void this.restoreSettings();
  }

  aboutToDisappear(): void {
    this.vm.stop();
    this.persistSettings();
  }

  private async restoreSettings(): Promise<void> {
    const settings: TunerSettings = await this.settingsStore.load(this.context);
    let restoredMode: string = settings.targetMode;
    if (!this.isValidTargetMode(restoredMode)) {
      restoredMode = DEFAULT_TUNER_SETTINGS.targetMode;
    }

    let restoredInstrumentId: string = settings.instrumentId;
    const restoredInstrument = INSTRUMENTS.find((inst: InstrumentSpec) => inst.id === restoredInstrumentId);
    if (!restoredInstrument) {
      restoredInstrumentId = DEFAULT_TUNER_SETTINGS.instrumentId;
    }

    let restoredCategory: string = settings.selectedInstrumentCategory;
    if (!this.isValidInstrumentCategory(restoredCategory)) {
      restoredCategory = DEFAULT_TUNER_SETTINGS.selectedInstrumentCategory;
    }

    this.targetMode = restoredMode;
    this.selectedInstrumentId = restoredInstrumentId;
    this.selectedInstrumentCategory = restoredCategory;
    this.selectedNoteIdx = Math.max(0, Math.min(11, Math.round(settings.selectedNoteIdx)));
    this.targetFreqHz = settings.targetFreqHz;
    this.a4Ref = settings.a4Ref;

    const activeInstrument = INSTRUMENTS.find((inst: InstrumentSpec) => inst.id === this.selectedInstrumentId);
    this.instName = activeInstrument ? activeInstrument.name : '吉他';

    this.vm.setTargetMode(this.targetMode as TunerTargetMode);
    this.vm.setInstrumentId(this.selectedInstrumentId);
    this.vm.setTargetMidi(this.midiFromNoteIdx(this.selectedNoteIdx));
    this.vm.setTargetFreqHz(this.targetFreqHz);
    this.vm.setA4Ref(this.a4Ref);
    this.settingsReady = true;
  }

  private isValidTargetMode(mode: string): boolean {
    return mode === TunerTargetMode.INSTRUMENT ||
      mode === TunerTargetMode.NOTE ||
      mode === TunerTargetMode.HZ;
  }

  private isValidInstrumentCategory(category: string): boolean {
    for (let i = 0; i < INSTRUMENT_CATEGORY_OPTIONS.length; i++) {
      if (INSTRUMENT_CATEGORY_OPTIONS[i].key === category) {
        return true;
      }
    }
    return false;
  }

  private persistSettings(): void {
    if (!this.settingsReady) {
      return;
    }
    const settings: TunerSettings = {
      targetMode: this.targetMode,
      instrumentId: this.selectedInstrumentId,
      selectedInstrumentCategory: this.selectedInstrumentCategory,
      selectedNoteIdx: this.selectedNoteIdx,
      targetFreqHz: this.targetFreqHz,
      a4Ref: this.a4Ref
    };
    this.settingsStore.save(settings);
  }

  private toggleCapture(): void {
    if (!this.settingsReady) {
      return;
    }
    if (!this.isListening) {
      if (!this.micReady) {
        requestMicrophonePermission(this.context).then((granted: boolean) => {
          this.micReady = granted;
          if (granted) {
            this.syncParamsAndStart();
          }
        });
        return;
      }
      this.syncParamsAndStart();
    } else {
      this.vm.stop();
    }
  }

  private syncParamsAndStart(): void {
    this.vm.setA4Ref(this.a4Ref);
    this.vm.setInstrumentId(this.selectedInstrumentId);
    this.vm.setTargetMode(this.targetMode as TunerTargetMode);
    this.vm.setTargetMidi(this.midiFromNoteIdx(this.selectedNoteIdx));
    this.vm.setTargetFreqHz(this.targetFreqHz);
    this.persistSettings();
    this.vm.start();
  }

  private onInstrumentChange(inst: InstrumentSpec): void {
    if (!this.settingsReady) {
      return;
    }
    this.selectedInstrumentId = inst.id;
    this.instName = inst.name;
    this.vm.setInstrumentId(inst.id);
    this.persistSettings();
  }

  private getFilteredInstruments(): InstrumentSpec[] {
    if (this.selectedInstrumentCategory === 'common') {
      return INSTRUMENTS.filter((inst: InstrumentSpec) =>
        COMMON_INSTRUMENT_IDS.indexOf(inst.id) >= 0);
    }
    return INSTRUMENTS.filter((inst: InstrumentSpec) =>
      inst.category === this.selectedInstrumentCategory);
  }

  private onA4Change(v: number): void {
    if (!this.settingsReady) {
      return;
    }
    this.a4Ref = v;
    this.vm.setA4Ref(v);
    this.persistSettings();
  }

  private onFreqHzChange(v: number): void {
    if (!this.settingsReady) {
      return;
    }
    this.targetFreqHz = v;
    this.vm.setTargetFreqHz(v);
    this.persistSettings();
  }

  private midiFromNoteIdx(idx: number): number {
    return 60 + idx;
  }

  private centsColor(): string {
    if (this.currentNote === '--') {
      return '#88A0CA';
    }
    return Math.abs(this.currentCents) <= 5 ? '#58F0C2' : '#FFB45D';
  }

  private centsMessage(): string {
    if (this.currentNote === '--') {
      return this.isListening ? '请弹奏一个稳定的音' : '准备开始检测';
    }
    if (Math.abs(this.currentCents) <= 5) {
      return '音准正确';
    }
    return this.currentCents < 0 ? '偏低，继续升高' : '偏高，稍微降低';
  }

  private getTuningDisplay(): string {
    const inst = INSTRUMENTS.find((i) => i.id === this.selectedInstrumentId);
    if (!inst || inst.strings.length === 0) {
      return '自由音域调音 · 自动识别最接近音名';
    }
    const parts: string[] = [];
    for (let i = 0; i < inst.strings.length; i++) {
      const f = freqFromMidi(inst.strings[i], this.a4Ref);
      parts.push(`${displayFromFreq(f, this.a4Ref).name} ${f.toFixed(0)}`);
    }
    return `标准定弦  ${parts.join('  ·  ')}`;
  }

  private getInstrumentImage(id: string): Resource {
    switch (id) {
      case 'guitar': return $r('app.media.inst_guitar');
      case 'electric-guitar': return $r('app.media.inst_electric_guitar');
      case 'bass-guitar': return $r('app.media.inst_bass_guitar');
      case 'ukulele': return $r('app.media.inst_ukulele');
      case 'banjo': return $r('app.media.inst_banjo');
      case 'mandolin': return $r('app.media.inst_mandolin');
      case 'harp': return $r('app.media.inst_harp');
      case 'guqin': return $r('app.media.inst_guqin');
      case 'guzheng': return $r('app.media.inst_guzheng');
      case 'violin': return $r('app.media.inst_violin');
      case 'viola': return $r('app.media.inst_viola');
      case 'cello': return $r('app.media.inst_cello');
      case 'double-bass': return $r('app.media.inst_double_bass');
      case 'erhu': return $r('app.media.inst_erhu');
      case 'piano': return $r('app.media.inst_piano');
      case 'electronic-piano': return $r('app.media.inst_electronic_piano');
      case 'accordion': return $r('app.media.inst_accordion');
      case 'organ': return $r('app.media.inst_organ');
      case 'trumpet': return $r('app.media.inst_trumpet');
      case 'trombone': return $r('app.media.inst_trombone');
      case 'french-horn': return $r('app.media.inst_french_horn');
      case 'tuba': return $r('app.media.inst_tuba');
      case 'saxophone-alto': return $r('app.media.inst_saxophone_alto');
      case 'saxophone-tenor': return $r('app.media.inst_saxophone_tenor');
      case 'saxophone-soprano': return $r('app.media.inst_saxophone_soprano');
      case 'flute': return $r('app.media.inst_flute');
      case 'piccolo': return $r('app.media.inst_piccolo');
      case 'oboe': return $r('app.media.inst_oboe');
      case 'clarinet': return $r('app.media.inst_clarinet');
      case 'bassoon': return $r('app.media.inst_bassoon');
      case 'recorder': return $r('app.media.inst_recorder');
      case 'pipa': return $r('app.media.inst_pipa');
      case 'sanxian': return $r('app.media.inst_sanxian');
      case 'ruan': return $r('app.media.inst_ruan');
      case 'dizi': return $r('app.media.inst_dizi');
      case 'xiao': return $r('app.media.inst_xiao');
      case 'suona': return $r('app.media.inst_suona');
      case 'hulusi': return $r('app.media.inst_hulusi');
      case 'sheng': return $r('app.media.inst_sheng');
      case 'timpani': return $r('app.media.inst_timpani');
      case 'marimba': return $r('app.media.inst_marimba');
      case 'xylophone': return $r('app.media.inst_xylophone');
      case 'vibraphone': return $r('app.media.inst_vibraphone');
      case 'glockenspiel': return $r('app.media.inst_glockenspiel');
      default: return $r('app.media.tuner_hero');
    }
  }

  @Builder
  private AuroraBackground() {
    Column()
    .width('100%')
    .height('100%')
    .backgroundColor('#060B1B')
    .linearGradient({
      angle: 150,
      colors: [['#123D51', 0.0], ['#09172C', 0.28], ['#17143A', 0.56], ['#07101F', 0.78], ['#10233B', 1.0]]
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
            Text('精准调音')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F6F9FF')
            Text(this.instName)
              .fontSize(12)
              .fontColor('#7FEAFF')
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          Blank()
          Row({ space: 6 }) {
            Circle()
              .width(7)
              .height(7)
              .fill(this.isListening ? '#58F0C2' : '#63749A')
            Text(this.isListening ? '检测中' : '待机')
              .fontSize(11)
              .fontColor(this.isListening ? '#85F5D2' : '#91A1C1')
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
              Image(this.getInstrumentImage(this.selectedInstrumentId))
                .width(102)
                .height(102)
                .objectFit(ImageFit.Contain)
                .opacity(0.92)
                .position({ x: 12, y: 14 })

              Column({ space: 3 }) {
                Text(this.currentNote)
                  .fontSize(76)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.centsColor())
                  .textAlign(TextAlign.Center)
                Text(`${this.currentFreq.toFixed(2)} Hz`)
                  .fontSize(15)
                  .fontColor('#B0BFDE')
                Text(this.centsMessage())
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.centsColor())
                  .margin({ top: 4 })
              }
              .width('100%')
              .height(180)
              .justifyContent(FlexAlign.Center)

              Text(this.targetName.length > 0 && this.targetName !== '--' ? `目标  ${this.targetName}` : `目标  ${this.instName}`)
                .fontSize(11)
                .fontColor('#A8B8D8')
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor('#2A304363')
                .position({ x: 214, y: 18 })
            }
            .width('92%')
            .height(188)
            .borderRadius(28)
            .backgroundColor('#2B182943')
            .backgroundBlurStyle(BlurStyle.Regular, { colorMode: ThemeColorMode.DARK })
            .border({ width: 1, color: '#407CEBFF' })
            .shadow({ radius: 24, color: '#2E28BEE8', offsetY: 12 })

            Column({ space: 8 }) {
              Row() {
                Text('-50')
                  .fontSize(10)
                  .fontColor('#7588AE')
                Blank()
                Text('0')
                  .fontSize(10)
                  .fontColor('#7FEFD0')
                Blank()
                Text('+50')
                  .fontSize(10)
                  .fontColor('#7588AE')
              }
              .width('100%')

              Stack({ alignContent: Alignment.Center }) {
                Row() {
                  Blank().backgroundColor('#46A5D9FF')
                  Blank().backgroundColor('#4B58F0C2')
                  Blank().backgroundColor('#46FFB35C')
                }
                .width('100%')
                .height(7)
                .borderRadius(4)
                Row() {
                  Rect()
                    .width(4)
                    .height(31)
                    .radius(2)
                    .fill(this.centsColor())
                    .shadow({ radius: 10, color: this.centsColor() })
                    .offset({ x: Math.max(-142, Math.min(142, this.currentCents * 2.84)) })
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
              .height(34)

              Text(`${this.currentCents >= 0 ? '+' : ''}${this.currentCents} cents`)
                .fontSize(12)
                .fontColor('#93A7CD')
            }
            .width('92%')
            .padding({ left: 18, right: 18, top: 12, bottom: 12 })
            .borderRadius(22)
            .backgroundColor('#2419243A')
            .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.DARK })
            .border({ width: 1, color: '#2E7195C7' })

            Row({ space: 4 }) {
              ForEach(MODE_OPTIONS, (m: ModeOption) => {
                Row() {
                  Text(m.label)
                    .fontSize(12)
                    .fontWeight(this.targetMode === m.key ? FontWeight.Bold : FontWeight.Normal)
                    .fontColor(this.targetMode === m.key ? '#071321' : '#9DADCD')
                }
                  .layoutWeight(1)
                  .height(38)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                  .borderRadius(17)
                  .backgroundColor(this.targetMode === m.key ? '#72E8FF' : '#00101729')
                  .onClick(() => {
                    if (!this.settingsReady) {
                      return;
                    }
                    this.targetMode = m.key;
                    this.vm.setTargetMode(m.key);
                    this.persistSettings();
                  })
              }, (m: ModeOption) => m.key)
            }
            .width('92%')
            .padding(4)
            .borderRadius(21)
            .backgroundColor('#30152339')
            .border({ width: 1, color: '#2E647B9E' })

            if (this.targetMode === 'instrument') {
              Column({ space: 10 }) {
                Row() {
                  Text('选择乐器')
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#F5F8FF')
                  Blank()
                  Text(`${this.getFilteredInstruments().length} 种 · 共 ${INSTRUMENTS.length} 种`)
                    .fontSize(11)
                    .fontColor('#7FEAFF')
                }
                .width('100%')

                Scroll() {
                  Row({ space: 7 }) {
                    ForEach(INSTRUMENT_CATEGORY_OPTIONS, (category: InstrumentCategoryOption) => {
                      Row() {
                        Text(category.label)
                          .fontSize(11)
                          .fontWeight(this.selectedInstrumentCategory === category.key ?
                            FontWeight.Bold : FontWeight.Normal)
                          .fontColor(this.selectedInstrumentCategory === category.key ? '#071321' : '#AAB9D5')
                      }
                      .height(34)
                      .padding({ left: 14, right: 14 })
                      .justifyContent(FlexAlign.Center)
                      .alignItems(VerticalAlign.Center)
                      .borderRadius(15)
                      .backgroundColor(this.selectedInstrumentCategory === category.key ? '#72E8FF' : '#251A2B42')
                      .border({
                        width: 1,
                        color: this.selectedInstrumentCategory === category.key ? '#A9F4FF' : '#315E7694'
                      })
                      .onClick(() => {
                        if (!this.settingsReady) {
                          return;
                        }
                        this.selectedInstrumentCategory = category.key;
                        this.persistSettings();
                      })
                    }, (category: InstrumentCategoryOption) => category.key)
                  }
                }
                .width('100%')
                .height(38)
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)

                Scroll() {
                  Row({ space: 8 }) {
                    ForEach(this.getFilteredInstruments(), (inst: InstrumentSpec) => {
                      Column({ space: 2 }) {
                        Image(this.getInstrumentImage(inst.id))
                          .width(64)
                          .height(64)
                          .objectFit(ImageFit.Contain)
                        Text(inst.name)
                          .width(80)
                          .fontSize(11)
                          .fontWeight(inst.id === this.selectedInstrumentId ? FontWeight.Bold : FontWeight.Normal)
                          .fontColor(inst.id === this.selectedInstrumentId ? '#77EBFF' : '#B1BED8')
                          .textAlign(TextAlign.Center)
                          .maxLines(1)
                      }
                      .width(88)
                      .height(94)
                      .justifyContent(FlexAlign.Center)
                      .borderRadius(18)
                      .backgroundColor(inst.id === this.selectedInstrumentId ? '#36304E73' : '#17162234')
                      .border({ width: 1, color: inst.id === this.selectedInstrumentId ? '#8871E8FF' : '#28617899' })
                      .onClick(() => this.onInstrumentChange(inst))
                    }, (inst: InstrumentSpec) => inst.id)
                  }
                }
                .width('100%')
                .height(98)
                .scrollable(ScrollDirection.Horizontal)
                .scrollBar(BarState.Off)

                Text(this.getTuningDisplay())
                  .fontSize(11)
                  .lineHeight(18)
                  .fontColor('#8FA3C9')
              }
              .width('92%')
              .padding(16)
              .alignItems(HorizontalAlign.Start)
              .borderRadius(24)
              .backgroundColor('#25172239')
              .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.DARK })
              .border({ width: 1, color: '#2F647DA2' })
            }

            if (this.targetMode === 'note') {
              Column({ space: 12 }) {
                Text('选择目标音')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F5F8FF')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'], (n: string, i: number) => {
                    Row() {
                      Text(n)
                        .fontSize(12)
                        .fontColor(this.selectedNoteIdx === i ? '#071321' : '#B5C2DD')
                    }
                      .width(48)
                      .height(36)
                      .justifyContent(FlexAlign.Center)
                      .alignItems(VerticalAlign.Center)
                      .borderRadius(15)
                      .backgroundColor(this.selectedNoteIdx === i ? '#72E8FF' : '#251B2B44')
                      .margin(4)
                      .onClick(() => {
                        if (!this.settingsReady) {
                          return;
                        }
                        this.selectedNoteIdx = i;
                        this.vm.setTargetMidi(this.midiFromNoteIdx(i));
                        this.persistSettings();
                      })
                  }, (n: string) => n)
                }
              }
              .width('92%')
              .padding(16)
              .alignItems(HorizontalAlign.Start)
              .borderRadius(24)
              .backgroundColor('#25172239')
              .border({ width: 1, color: '#2F647DA2' })
            }

            if (this.targetMode === 'hz') {
              Column({ space: 12 }) {
                Text('自定义目标频率')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F5F8FF')
                Row() {
                  TextInput({ placeholder: '输入 20 - 5000 Hz' })
                    .type(InputType.Number)
                    .fontColor('#FFFFFF')
                    .placeholderColor('#66799F')
                    .backgroundColor('#35101829')
                    .borderRadius(16)
                    .layoutWeight(1)
                    .onChange((v: string) => {
                      const f = parseFloat(v);
                      if (f >= TUNER_FREQ_MIN && f <= TUNER_FREQ_MAX) {
                        this.onFreqHzChange(f);
                      }
                    })
                  Text(`${this.targetFreqHz.toFixed(2)} Hz`)
                    .fontSize(13)
                    .fontColor('#72E8FF')
                    .margin({ left: 10 })
                }
                Row({ space: 7 }) {
                  ForEach([110, 196, 220, 440, 880], (f: number) => {
                    Row() {
                      Text(`${f}`)
                        .fontSize(11)
                        .fontColor(this.targetFreqHz === f ? '#071321' : '#AAB8D4')
                    }
                      .layoutWeight(1)
                      .height(32)
                      .justifyContent(FlexAlign.Center)
                      .alignItems(VerticalAlign.Center)
                      .borderRadius(14)
                      .backgroundColor(this.targetFreqHz === f ? '#72E8FF' : '#24172238')
                      .onClick(() => this.onFreqHzChange(f))
                  }, (f: number) => f.toString())
                }
              }
              .width('92%')
              .padding(16)
              .alignItems(HorizontalAlign.Start)
              .borderRadius(24)
              .backgroundColor('#25172239')
              .border({ width: 1, color: '#2F647DA2' })
            }

            Column({ space: 8 }) {
              Row() {
                Text('A4 基准')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#EFF4FF')
                Blank()
                Text(`${this.a4Ref.toFixed(1)} Hz`)
                  .fontSize(13)
                  .fontColor('#72E8FF')
              }
              Slider({ value: this.a4Ref, min: TUNER_A4_MIN, max: TUNER_A4_MAX, step: 0.1 })
                .width('100%')
                .selectedColor('#55DFF6')
                .trackColor('#34435C78')
                .blockColor('#E5FBFF')
                .onChange((value: number) => this.onA4Change(value))
              Row({ space: 7 }) {
                ForEach([415, 440, 442, 443], (v: number) => {
                  Row() {
                    Text(`${v}`)
                      .fontSize(11)
                      .fontColor(Math.abs(this.a4Ref - v) < 0.05 ? '#071321' : '#A8B7D2')
                  }
                    .layoutWeight(1)
                    .height(31)
                    .justifyContent(FlexAlign.Center)
                    .alignItems(VerticalAlign.Center)
                    .borderRadius(14)
                    .backgroundColor(Math.abs(this.a4Ref - v) < 0.05 ? '#72E8FF' : '#24172238')
                    .onClick(() => this.onA4Change(v))
                }, (v: number) => v.toString())
              }
            }
            .width('92%')
            .padding(16)
            .borderRadius(24)
            .backgroundColor('#25172239')
            .backgroundBlurStyle(BlurStyle.Thin, { colorMode: ThemeColorMode.DARK })
            .border({ width: 1, color: '#2F647DA2' })
            .alignItems(HorizontalAlign.Start)
          }
          .padding({ top: 4, bottom: 18 })
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.Top)

        Row() {
          Text(this.settingsReady ? (this.isListening ? '停止检测' : '开始检测') : '加载设置…')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.isListening ? '#FFE7EA' : '#06131D')
        }
          .width('88%')
          .height(56)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .borderRadius(28)
          .backgroundColor(this.isListening ? '#D9506880' : '#6DE8FF')
          .border({ width: 1, color: this.isListening ? '#FFFF8495' : '#CCB6F6FF' })
          .shadow({ radius: 18, color: this.isListening ? '#50FF5B70' : '#5557DFF6', offsetY: 8 })
          .opacity(this.settingsReady ? 1 : 0.55)
          .margin({ top: 8, bottom: 18 })
          .onClick(() => this.toggleCapture())
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
