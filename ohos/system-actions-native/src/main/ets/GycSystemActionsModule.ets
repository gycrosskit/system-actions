import { KRAny, KuiklyRenderBaseModule, KuiklyRenderCallback } from '@kuikly-open/render';
import { ActionResult, SystemActions } from './SystemActions';

interface ActionParams { requestId?: string; value?: string; }
class PendingAction {
  callback: KuiklyRenderCallback | null;
  cancel: (() => void) | null = null;
  constructor(callback: KuiklyRenderCallback) { this.callback = callback; }
}

/** 由页面注入同一 SystemActions；取消只抑制回执，不能撤回系统已受理的动作。 */
export class GycSystemActionsModule extends KuiklyRenderBaseModule {
  static readonly MODULE_NAME: string = 'GycSystemActionsModule';
  private actions: SystemActions | null;
  private readonly pending: Map<string, PendingAction> = new Map();
  private destroyed: boolean = false;

  constructor(actions: SystemActions) { super(); this.actions = actions; }
  syncMode(): boolean { return false; }

  call(method: string, params: KRAny, callback: KuiklyRenderCallback | null): KRAny {
    if (this.destroyed) { return null; }
    let args: ActionParams;
    try {
      args = JSON.parse(typeof params === 'string' ? params : '{}') as ActionParams;
      if (!args || typeof args !== 'object' || typeof args.requestId !== 'string' || !args.requestId) {
        callback?.({ status: 'invalid_input' }); return null;
      }
    } catch (_) { callback?.({ status: 'invalid_input' }); return null; }
    const id = args.requestId;
    if (method === 'cancel') {
      const pending = this.pending.get(id);
      if (pending) { pending.callback = null; pending.cancel?.(); pending.cancel = null; }
      this.pending.delete(id); return null;
    }
    const actions = this.actions;
    if (!actions) { callback?.({ status: 'unavailable' }); return null; }
    if (!callback) { return null; }
    if (this.pending.has(id)) { callback({ status: 'invalid_input' }); return null; }
    if (args.value !== undefined && typeof args.value !== 'string') {
      callback({ status: 'invalid_input' }); return null;
    }
    const pending = new PendingAction(callback);
    this.pending.set(id, pending);
    const result = method === 'openNativeAppStore' ? this.openNativeStore(actions, args.value, pending) :
      this.perform(actions, method, args.value ?? '');
    result.then((status: ActionResult) => {
      this.deliver(id, pending, status);
    }).catch(() => { this.deliver(id, pending, 'unavailable'); });
    return null;
  }

  private async openNativeStore(actions: SystemActions, value: string | undefined, pending: PendingAction): Promise<ActionResult> {
    const request = actions.requestNativeAppStore(value);
    pending.cancel = request.cancel;
    return request.result;
  }

  private async perform(actions: SystemActions, method: string, value: string): Promise<ActionResult> {
    switch (method) {
      case 'dial': return actions.dial(value);
      case 'openExternalUrl': return actions.openExternalUrl(value);
      case 'openAppSettings': return actions.openAppSettings();
      case 'openLocationSettings': return actions.openLocationSettings();
      case 'openAppStore': return actions.openAppStore(value);
      default: return Promise.resolve('unavailable');
    }
  }

  private deliver(id: string, pending: PendingAction, status: ActionResult): void {
    if (this.destroyed || this.pending.get(id) !== pending) { return; }
    this.pending.delete(id);
    const callback = pending.callback;
    pending.callback = null;
    pending.cancel = null;
    callback?.({ status });
  }

  onDestroy(): void {
    this.destroyed = true;
    this.pending.forEach((pending: PendingAction) => {
      pending.callback = null;
      pending.cancel?.();
      pending.cancel = null;
    });
    this.pending.clear();
    this.actions = null;
    super.onDestroy();
  }
}
