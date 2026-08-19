/*
 * 后台长时任务管理（节拍器锁屏继续）
 *
 * 说明：
 *  - 仅在节拍器真正播放音频时申请 AUDIO_PLAYBACK 长时任务
 *  - API 20+ 申请成功后系统自动在通知栏显示常驻通知
 *  - 停止节拍时同步释放，避免"申请了不播放"被系统挂起
 */

import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, WantAgent, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BUNDLE_NAME } from './Constants';

let cachedWantAgent: WantAgent | null = null;
let isRunning: boolean = false;

/**
 * 申请节拍器后台长时任务
 */
export async function startMetronomeBackground(context: common.UIAbilityContext): Promise<boolean> {
  if (isRunning) {
    return true;
  }
  try {
    const agent = await getWantAgent(context);
    const modes: string[] = ['audioPlayback'];
    await backgroundTaskManager.startBackgroundRunning(context, modes, agent);
    isRunning = true;
    console.info('Metronome background task started');
    return true;
  } catch (err) {
    const e = err as BusinessError;
    console.error(`startBackgroundRunning failed: ${e.code} ${e.message}`);
    return false;
  }
}

/**
 * 释放节拍器后台长时任务
 */
export async function stopMetronomeBackground(context: common.UIAbilityContext): Promise<void> {
  if (!isRunning) {
    return;
  }
  try {
    await backgroundTaskManager.stopBackgroundRunning(context);
    isRunning = false;
    console.info('Metronome background task stopped');
  } catch (err) {
    const e = err as BusinessError;
    console.error(`stopBackgroundRunning failed: ${e.code} ${e.message}`);
  }
}

/**
 * 当前是否持有长时任务
 */
export function isMetronomeBackgroundRunning(): boolean {
  return isRunning;
}

/**
 * 获取（或缓存）wantAgent：点击通知后回到本应用
 */
async function getWantAgent(context: common.UIAbilityContext): Promise<WantAgent> {
  if (cachedWantAgent) {
    return cachedWantAgent;
  }
  const wantAgentInfo: wantAgent.WantAgentInfo = {
    wants: [
      {
        bundleName: BUNDLE_NAME,
        abilityName: 'EntryAbility'
      }
    ],
    actionType: wantAgent.OperationType.START_ABILITY,
    requestCode: 0,
    actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
  };
  const agent = await wantAgent.getWantAgent(wantAgentInfo);
  cachedWantAgent = agent;
  return agent;
}
