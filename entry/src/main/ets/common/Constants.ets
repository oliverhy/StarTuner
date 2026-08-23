/*
 * 全局常量
 */

// 应用相关
export const APP_NAME: string = '星辰调音节拍器';
export const APP_VERSION: string = '1.0.1';
export const BUNDLE_NAME: string = 'com.yinhe.startuner';

// 页面路由路径
export const ROUTE_INDEX: string = 'pages/Index';
export const ROUTE_TUNER: string = 'pages/TunerPage';
export const ROUTE_METRONOME: string = 'pages/MetronomePage';

// 权限
export const PERMISSION_MICROPHONE: string = 'ohos.permission.MICROPHONE';
export const PERMISSION_VIBRATE: string = 'ohos.permission.VIBRATE';

// 调音器默认参数
export const TUNER_DEFAULT_A4: number = 440.0;
export const TUNER_A4_MIN: number = 415.0;
export const TUNER_A4_MAX: number = 466.0;
export const TUNER_FREQ_MIN: number = 20.0;   // 检测下限 Hz
export const TUNER_FREQ_MAX: number = 4500.0; // 检测上限 Hz（覆盖高基准音下的 C8）

// 采样参数（与 native 层保持一致）
export const SAMPLE_RATE: number = 48000;
export const CHANNELS: number = 1;
export const SAMPLE_FORMAT: string = 'S16LE';

// 节拍器默认参数
export const METRONOME_BPM_MIN: number = 30;
export const METRONOME_BPM_MAX: number = 300;
export const METRONOME_BPM_DEFAULT: number = 100;
export const METRONOME_BEATS_MAX: number = 12;   // 每小节最多拍数
export const METRONOME_SUBDIVIDE_MAX: number = 6; // 每拍最大细分（6 = 十六分三连音）
