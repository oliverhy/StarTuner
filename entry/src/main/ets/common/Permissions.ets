/*
 * 权限请求工具
 */

import { abilityAccessCtrl, common, bundleManager, Permissions } from '@kit.AbilityKit';

/**
 * 检查麦克风权限是否已授权
 */
export function checkMicrophonePermission(): boolean {
  const atManager = abilityAccessCtrl.createAtManager();
  const bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
  const tokenID = bundleInfo.appInfo.accessTokenId;
  const micPermission: Permissions = 'ohos.permission.MICROPHONE';
  const status = atManager.checkAccessTokenSync(tokenID, micPermission);
  return status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
}

/**
 * 请求麦克风权限（弹窗）
 * @returns true=已授权
 */
export async function requestMicrophonePermission(context: common.UIAbilityContext): Promise<boolean> {
  if (checkMicrophonePermission()) {
    return true;
  }
  const atManager = abilityAccessCtrl.createAtManager();
  const micPermission: Permissions = 'ohos.permission.MICROPHONE';
  try {
    const data = await atManager.requestPermissionsFromUser(context, [micPermission]);
    const authResults: number[] = data.authResults;
    return authResults.length > 0 && authResults[0] === 0;
  } catch (err) {
    console.error(`Request mic permission failed: ${JSON.stringify(err)}`);
    return false;
  }
}
