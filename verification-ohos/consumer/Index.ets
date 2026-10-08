import { SystemActions, GycSystemActionsModule, ActionResult, WindowPolicyController, window } from '@gycrosskit/system-actions-native';
import { common } from '@kit.AbilityKit';
export function actions(context: common.UIAbilityContext): SystemActions { return new SystemActions(context); }
export function module(actions: SystemActions, owner: WindowPolicyController): GycSystemActionsModule { return new GycSystemActionsModule(actions, owner); }
export async function probe(actions: SystemActions, url: string): Promise<ActionResult[]> {
  return [await actions.dial('123'), await actions.openExternalUrl(url), await actions.openAppSettings(),
    await actions.openNativeAppStore(), await actions.openNativeAppStore("consumer.example"),
    await actions.openLocationSettings(), await actions.openAppStore(url)];
}

export async function cancelledStore(actions: SystemActions): Promise<ActionResult> {
  const request = actions.requestNativeAppStore();
  request.cancel();
  return request.result;
}

export async function windowPolicy(owner: WindowPolicyController, resolveWindow: () => Promise<window.Window>): Promise<void> {
  const lease = owner.createLease(resolveWindow, true);
  await lease.update(false);
  await lease.update(true);
  await lease.release();
}

export async function fullscreenPolicy(owner: WindowPolicyController, resolveWindow: () => Promise<window.Window>): Promise<void> {
  const lease = owner.createFullscreenLease(resolveWindow, {
    enterOrientation: window.Orientation.AUTO_ROTATION_LANDSCAPE,
    unspecifiedExitOrientation: window.Orientation.PORTRAIT,
    enterSystemBars: [], exitSystemBarsWhenFullscreen: [],
    exitSystemBarsWhenNotFullscreen: ['status', 'navigation']
  });
  await lease.enter();
  await lease.exit();
  await lease.release();
}

export async function files(actions: SystemActions, path: string): Promise<ActionResult[]> {
  return [await actions.copyText('consumer'), await actions.shareFile(path, 'Share')];
}
