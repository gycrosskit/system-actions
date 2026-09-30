import { SystemActions, GycSystemActionsModule, ActionResult } from '@gycrosskit/system-actions-native';
import { common } from '@kit.AbilityKit';
export function actions(context: common.UIAbilityContext): SystemActions { return new SystemActions(context); }
export function module(actions: SystemActions): GycSystemActionsModule { return new GycSystemActionsModule(actions); }
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
