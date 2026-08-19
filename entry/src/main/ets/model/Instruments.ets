/*
 * 乐器数据库
 *
 * 数据结构：InstrumentSpec
 *  - id: 唯一标识
 *  - name: 中文名
 *  - nameEn: 英文名
 *  - category: 乐器类别
 *  - strings: 定弦列表（弦名 + MIDI 编号），从最高音弦到最低音弦（吉他 1弦(E4) 到 6弦(E2)）
 *            用 MIDI 编号表示，可随 A4 基准偏移换算频率
 *  - rangeLow/rangeHigh: 音域（MIDI 编号，近似）
 *  - transposition: 移调半音数（记谱音高 - 实际音高，如中音萨克斯记谱比实际高 2 个半音，实际低，这里存 0 表示 C 调）
 *  - alternateTunings: 备选定弦
 *  - noteCount: 弦数（对定音乐器如钢琴无意义则为 0）
 */

export enum InstrumentCategory {
  PLUCKED = '拨弦',      // 拨弦
  BOWED = '拉弦',        // 拉弦
  KEYBOARD = '键盘',     // 键盘
  BRASS = '铜管',        // 铜管
  WOODWIND = '木管',     // 木管
  CHINESE_PLUCKED = '民族弹拨',  // 民族弹拨
  CHINESE_BOWED = '民族拉弦',    // 民族拉弦
  CHINESE_BLOWN = '民族吹奏',    // 民族吹奏
  PERCUSSION = '打击',   // 打击(定音乐器)
  OTHER = '其他'
}

export interface AlternateTuning {
  name: string;
  strings: number[]; // MIDI 编号，从高到低
}

export interface InstrumentSpec {
  id: string;
  name: string;
  nameEn: string;
  category: InstrumentCategory;
  // 定弦：从最高音弦到最低音弦的 MIDI 编号
  strings: number[];
  rangeLow: number;   // 音域下限 MIDI
  rangeHigh: number;  // 音域上限 MIDI
  transposition: number; // 移调（半音，正=乐器实际音高比记谱高；通常 0）
  alternateTunings: AlternateTuning[];
  noteCount: number;
}

// MIDI 常量辅助（C4 = 60）
// 常用参考：
//  E2=40 A2=45 D3=50 G3=55 B3=59 E4=64 （吉他）
//  G2=43 D3=50 A3=57 E4=64 （贝斯）
//  G3=55 C4=60 E4=64 A4=69 （小提琴）
//  C4=60 E4=64 G4=67 C5=72 （尤克里里）
//  A4=69

export const INSTRUMENTS: InstrumentSpec[] = [
  // ============ 拨弦 ============
  {
    id: 'guitar',
    name: '吉他',
    nameEn: 'Guitar',
    category: InstrumentCategory.PLUCKED,
    strings: [64, 59, 55, 50, 45, 40], // E4 B3 G3 D3 A2 E2
    rangeLow: 40,
    rangeHigh: 96,
    transposition: 0,
    noteCount: 6,
    alternateTunings: [
      { name: '降半音 (Eb)', strings: [63, 58, 54, 49, 44, 39] },
      { name: '降全音 (D)', strings: [62, 57, 53, 48, 43, 38] },
      { name: 'Open D', strings: [62, 57, 53, 50, 45, 38] },
      { name: 'Open G', strings: [67, 62, 55, 50, 45, 43] },
      { name: 'DADGAD', strings: [62, 57, 55, 50, 45, 38] }
    ]
  },
  {
    id: 'electric-guitar',
    name: '电吉他',
    nameEn: 'Electric Guitar',
    category: InstrumentCategory.PLUCKED,
    strings: [64, 59, 55, 50, 45, 40],
    rangeLow: 40,
    rangeHigh: 96,
    transposition: 0,
    noteCount: 6,
    alternateTunings: [
      { name: '降半音 (Eb)', strings: [63, 58, 54, 49, 44, 39] },
      { name: '降全音 (D)', strings: [62, 57, 53, 48, 43, 38] }
    ]
  },
  {
    id: 'bass-guitar',
    name: '电贝斯',
    nameEn: 'Bass Guitar',
    category: InstrumentCategory.PLUCKED,
    strings: [43, 38, 33, 28], // G2 D2 A1 E1
    rangeLow: 23,
    rangeHigh: 88,
    transposition: 0,
    noteCount: 4,
    alternateTunings: [
      { name: '五弦 (B0)', strings: [43, 38, 33, 28, 23] },
      { name: '五弦 (低C1)', strings: [43, 38, 33, 28, 24] },
      { name: '降全音 (D)', strings: [41, 36, 31, 26] },
      { name: 'Drop D', strings: [43, 38, 33, 26] }
    ]
  },
  {
    id: 'ukulele',
    name: '尤克里里',
    nameEn: 'Ukulele',
    category: InstrumentCategory.PLUCKED,
    strings: [69, 67, 64, 60], // A4 G4 E4 C4 (标准高音 G，按音高从高到低)
    rangeLow: 60,
    rangeHigh: 88,
    transposition: 0,
    noteCount: 4,
    alternateTunings: [
      { name: '低G', strings: [69, 64, 60, 55] },
      { name: 'D调 (ADF#B)', strings: [71, 69, 66, 62] }
    ]
  },
  {
    id: 'banjo',
    name: '班卓琴',
    nameEn: 'Banjo',
    category: InstrumentCategory.PLUCKED,
    strings: [67, 62, 59, 55, 50], // G4 D4 B3 G3 D3（开放 G，按音高从高到低）
    rangeLow: 43,
    rangeHigh: 96,
    transposition: 0,
    noteCount: 5,
    alternateTunings: [
      { name: '标准 (GDGBD)', strings: [67, 62, 59, 55, 50] },
      { name: '双C (GCGCD)', strings: [67, 62, 60, 55, 48] }
    ]
  },
  {
    id: 'mandolin',
    name: '曼陀林',
    nameEn: 'Mandolin',
    category: InstrumentCategory.PLUCKED,
    strings: [76, 69, 62, 55], // E5 A4 D4 G3
    rangeLow: 55,
    rangeHigh: 96,
    transposition: 0,
    noteCount: 4,
    alternateTunings: []
  },
  {
    id: 'harp',
    name: '竖琴',
    nameEn: 'Harp',
    category: InstrumentCategory.PLUCKED,
    strings: [], // 竖琴每半音一弦，不适合弦式调音
    rangeLow: 28, // C1
    rangeHigh: 100, // G7
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'guqin',
    name: '古琴',
    nameEn: 'Guqin',
    category: InstrumentCategory.CHINESE_PLUCKED,
    // 常用正调，从一弦到七弦实际音高为 C2 D2 F2 G2 A2 C3 D3；按项目约定从高到低存储。
    strings: [50, 48, 45, 43, 41, 38, 36],
    rangeLow: 36,
    rangeHigh: 72,
    transposition: 0,
    noteCount: 7,
    alternateTunings: []
  },
  {
    id: 'guzheng',
    name: '古筝',
    nameEn: 'Guzheng',
    category: InstrumentCategory.CHINESE_PLUCKED,
    strings: [], // 21弦，D宫调定弦复杂
    rangeLow: 29, // D1
    rangeHigh: 91, // D7
    transposition: 0,
    noteCount: 21,
    alternateTunings: []
  },

  // ============ 拉弦 ============
  {
    id: 'violin',
    name: '小提琴',
    nameEn: 'Violin',
    category: InstrumentCategory.BOWED,
    strings: [76, 69, 64, 55], // E5 A4 D4 G3
    rangeLow: 55,
    rangeHigh: 103,
    transposition: 0,
    noteCount: 4,
    alternateTunings: [
      { name: '苏格兰 (AEAE)', strings: [76, 69, 64, 55] },
      { name: '交叉 (GDAE→CGDA)', strings: [74, 67, 62, 53] }
    ]
  },
  {
    id: 'viola',
    name: '中提琴',
    nameEn: 'Viola',
    category: InstrumentCategory.BOWED,
    strings: [69, 62, 55, 48], // A4 D4 G3 C3
    rangeLow: 48,
    rangeHigh: 93,
    transposition: 0,
    noteCount: 4,
    alternateTunings: []
  },
  {
    id: 'cello',
    name: '大提琴',
    nameEn: 'Cello',
    category: InstrumentCategory.BOWED,
    strings: [57, 50, 43, 36], // A3 D3 G2 C2
    rangeLow: 36,
    rangeHigh: 88,
    transposition: 0,
    noteCount: 4,
    alternateTunings: [
      { name: '巴洛克 (GDAF)', strings: [57, 50, 43, 41] }
    ]
  },
  {
    id: 'double-bass',
    name: '低音提琴',
    nameEn: 'Double Bass',
    category: InstrumentCategory.BOWED,
    strings: [43, 38, 33, 28], // G2 D2 A1 E1
    rangeLow: 23,
    rangeHigh: 74,
    transposition: 0,
    noteCount: 4,
    alternateTunings: [
      { name: '五弦', strings: [43, 38, 33, 28, 23] },
      { name: '低C', strings: [43, 38, 33, 28, 24] }
    ]
  },
  {
    id: 'erhu',
    name: '二胡',
    nameEn: 'Erhu',
    category: InstrumentCategory.CHINESE_BOWED,
    strings: [69, 62], // A4 D4
    rangeLow: 62,
    rangeHigh: 89,
    transposition: 0,
    noteCount: 2,
    alternateTunings: [
      { name: '高定弦', strings: [74, 67] },
      { name: '低定弦', strings: [67, 60] }
    ]
  },

  // ============ 键盘 ============
  {
    id: 'piano',
    name: '钢琴',
    nameEn: 'Piano',
    category: InstrumentCategory.KEYBOARD,
    strings: [],
    rangeLow: 21, // A0
    rangeHigh: 108, // C8
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'electronic-piano',
    name: '电子琴',
    nameEn: 'Electronic Keyboard',
    category: InstrumentCategory.KEYBOARD,
    strings: [],
    rangeLow: 36,
    rangeHigh: 96,
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'accordion',
    name: '手风琴',
    nameEn: 'Accordion',
    category: InstrumentCategory.KEYBOARD,
    strings: [],
    rangeLow: 41, // F2
    rangeHigh: 96,
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'organ',
    name: '管风琴',
    nameEn: 'Organ',
    category: InstrumentCategory.KEYBOARD,
    strings: [],
    rangeLow: 12, // C-1
    rangeHigh: 108,
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },

  // ============ 铜管 ============
  {
    id: 'trumpet',
    name: '小号',
    nameEn: 'Trumpet',
    category: InstrumentCategory.BRASS,
    strings: [],
    rangeLow: 60, // C4
    rangeHigh: 88, // E6
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'trombone',
    name: '长号',
    nameEn: 'Trombone',
    category: InstrumentCategory.BRASS,
    strings: [],
    rangeLow: 40, // E2
    rangeHigh: 76, // E5
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'french-horn',
    name: '圆号',
    nameEn: 'French Horn',
    category: InstrumentCategory.BRASS,
    strings: [],
    rangeLow: 43, // G2
    rangeHigh: 79, // G5
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'tuba',
    name: '大号',
    nameEn: 'Tuba',
    category: InstrumentCategory.BRASS,
    strings: [],
    rangeLow: 26, // D1
    rangeHigh: 67, // G4
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'saxophone-alto',
    name: '中音萨克斯',
    nameEn: 'Alto Saxophone',
    category: InstrumentCategory.WOODWIND,
    strings: [],
    rangeLow: 49, // Db3 实际
    rangeHigh: 85, // Ab5 实际
    transposition: 2, // Eb 调（记谱高 大3度）
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'saxophone-tenor',
    name: '次中音萨克斯',
    nameEn: 'Tenor Saxophone',
    category: InstrumentCategory.WOODWIND,
    strings: [],
    rangeLow: 45, // A2 实际
    rangeHigh: 81, // E5 实际
    transposition: 2, // Bb 调
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'saxophone-soprano',
    name: '高音萨克斯',
    nameEn: 'Soprano Saxophone',
    category: InstrumentCategory.WOODWIND,
    strings: [],
    rangeLow: 54, // F#3 实际
    rangeHigh: 90, // F#6 实际
    transposition: 2, // Bb 调
    noteCount: 0,
    alternateTunings: []
  },

  // ============ 木管 ============
  {
    id: 'flute',
    name: '长笛',
    nameEn: 'Flute',
    category: InstrumentCategory.WOODWIND,
    strings: [],
    rangeLow: 60, // C4
    rangeHigh: 96, // C7
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'piccolo',
    name: '短笛',
    nameEn: 'Piccolo',
    category: InstrumentCategory.WOODWIND,
    strings: [],
    rangeLow: 74, // D5
    rangeHigh: 104, // C8
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'oboe',
    name: '双簧管',
    nameEn: 'Oboe',
    category: InstrumentCategory.WOODWIND,
    strings: [],
    rangeLow: 57, // A3
    rangeHigh: 93, // A6
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'clarinet',
    name: '单簧管',
    nameEn: 'Clarinet',
    category: InstrumentCategory.WOODWIND,
    strings: [],
    rangeLow: 50, // D3
    rangeHigh: 91, // G6
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'bassoon',
    name: '巴松管',
    nameEn: 'Bassoon',
    category: InstrumentCategory.WOODWIND,
    strings: [],
    rangeLow: 36, // C2
    rangeHigh: 81, // E5
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'recorder',
    name: '竖笛',
    nameEn: 'Recorder',
    category: InstrumentCategory.WOODWIND,
    strings: [],
    rangeLow: 62, // D4
    rangeHigh: 90, // F#6
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },

  // ============ 民族弹拨 ============
  {
    id: 'pipa',
    name: '琵琶',
    nameEn: 'Pipa',
    category: InstrumentCategory.CHINESE_PLUCKED,
    strings: [57, 52, 50, 45], // A3 E3 D3 A2
    rangeLow: 45,
    rangeHigh: 96,
    transposition: 0,
    noteCount: 4,
    alternateTunings: []
  },
  {
    id: 'sanxian',
    name: '三弦',
    nameEn: 'Sanxian',
    category: InstrumentCategory.CHINESE_PLUCKED,
    strings: [55, 50, 43], // G3 D3 G2（大三弦常用定弦）
    rangeLow: 43,
    rangeHigh: 84,
    transposition: 0,
    noteCount: 3,
    alternateTunings: []
  },
  {
    id: 'ruan',
    name: '阮',
    nameEn: 'Ruan',
    category: InstrumentCategory.CHINESE_PLUCKED,
    strings: [62, 55, 50, 43], // D4 G3 D3 G2（中阮 GDGD）
    rangeLow: 43,
    rangeHigh: 88,
    transposition: 0,
    noteCount: 4,
    alternateTunings: [
      { name: '低阮', strings: [50, 43, 38, 31] }
    ]
  },

  // ============ 民族吹奏 ============
  {
    id: 'dizi',
    name: '笛子',
    nameEn: 'Dizi',
    category: InstrumentCategory.CHINESE_BLOWN,
    strings: [],
    rangeLow: 64, // E4
    rangeHigh: 100, // G7
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'xiao',
    name: '箫',
    nameEn: 'Xiao',
    category: InstrumentCategory.CHINESE_BLOWN,
    strings: [],
    rangeLow: 55, // G3
    rangeHigh: 91, // G6
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'suona',
    name: '唢呐',
    nameEn: 'Suona',
    category: InstrumentCategory.CHINESE_BLOWN,
    strings: [],
    rangeLow: 62, // D4
    rangeHigh: 100, // G7
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'hulusi',
    name: '葫芦丝',
    nameEn: 'Hulusi',
    category: InstrumentCategory.CHINESE_BLOWN,
    strings: [],
    rangeLow: 60, // C4
    rangeHigh: 90, // F#6
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'sheng',
    name: '笙',
    nameEn: 'Sheng',
    category: InstrumentCategory.CHINESE_BLOWN,
    strings: [],
    rangeLow: 55, // G3
    rangeHigh: 91, // G6
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },

  // ============ 打击（定音乐器） ============
  {
    id: 'timpani',
    name: '定音鼓',
    nameEn: 'Timpani',
    category: InstrumentCategory.PERCUSSION,
    strings: [],
    rangeLow: 45, // A2
    rangeHigh: 60, // C4
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'marimba',
    name: '马林巴',
    nameEn: 'Marimba',
    category: InstrumentCategory.PERCUSSION,
    strings: [],
    rangeLow: 40, // E2
    rangeHigh: 92, // G#6
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'xylophone',
    name: '木琴',
    nameEn: 'Xylophone',
    category: InstrumentCategory.PERCUSSION,
    strings: [],
    rangeLow: 72, // C5
    rangeHigh: 100, // G7
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'vibraphone',
    name: '颤音琴',
    nameEn: 'Vibraphone',
    category: InstrumentCategory.PERCUSSION,
    strings: [],
    rangeLow: 65, // F4
    rangeHigh: 96, // C7
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  },
  {
    id: 'glockenspiel',
    name: '钢片琴',
    nameEn: 'Glockenspiel',
    category: InstrumentCategory.PERCUSSION,
    strings: [],
    rangeLow: 79, // G5
    rangeHigh: 108, // C8
    transposition: 0,
    noteCount: 0,
    alternateTunings: []
  }
];

/**
 * 按类别分组乐器（供 UI 分类展示）
 */
export function getInstrumentsByCategory(): Map<InstrumentCategory, InstrumentSpec[]> {
  const map = new Map<InstrumentCategory, InstrumentSpec[]>();
  for (const inst of INSTRUMENTS) {
    const list = map.get(inst.category);
    if (list) {
      list.push(inst);
    } else {
      map.set(inst.category, [inst]);
    }
  }
  return map;
}

/**
 * 根据 id 查找乐器
 */
export function findInstrument(id: string): InstrumentSpec | undefined {
  return INSTRUMENTS.find((inst) => inst.id === id);
}
