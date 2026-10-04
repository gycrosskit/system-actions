const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript');
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(__dirname + '/../system-actions-native/src/main/ets/WindowPolicy.ets', 'utf8'),
 { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText,
 { exports: exportsObject, require: () => ({ window: { Orientation: { UNSPECIFIED: 0 } } }) });
const flush = () => new Promise(resolve => setImmediate(resolve));
function target() {
 return { calls: [], orientation: 1, full: false, layout: false, privacy: false,
  getPreferredOrientation() { return this.orientation; },
  getWindowProperties() { return { isFullScreen: this.full, isLayoutFullScreen: this.layout, isPrivacyMode: this.privacy }; },
  async setPreferredOrientation(value) { this.calls.push(['orientation', value]); this.orientation = value; },
  async setWindowSystemBarEnable(value) { this.calls.push(['bars', Array.from(value)]); },
  async setWindowLayoutFullScreen(value) { this.calls.push(['layout', value]); this.layout = value; },
  async setWindowPrivacyMode(value) { this.calls.push(['privacy', value]); this.privacy = value; }
 };
}
const policy = { enterOrientation: 2, exitOrientation: 1, enterSystemBars: [], exitSystemBars: ['status', 'navigation'] };
(async () => {
 const controller = new exportsObject.WindowPolicyController(), window = target();
 const lease = controller.createFullscreenLease(async () => window, policy);
 assert.equal(await lease.enter(), true); await lease.exit();
 assert.deepEqual(window.calls, [['orientation', 2], ['bars', []], ['bars', ['status', 'navigation']], ['orientation', 1]]);
 await lease.release(); const count = window.calls.length; assert.equal(await lease.enter(), false); assert.equal(window.calls.length, count);

 let finishWindow; const late = target(), pending = controller.createFullscreenLease(() => new Promise(resolve => { finishWindow = resolve; }), policy);
 const enter = pending.enter(); await flush(); const release = pending.release(); finishWindow(late);
 assert.equal(await enter, false); await release; assert.deepEqual(late.calls, []);

 let replaced = 0; const first = controller.createFullscreenLease(async () => window, policy, () => { replaced++; });
 await first.enter(); const second = controller.createFullscreenLease(async () => window, policy);
 const takeover = second.enter(); await first.release(); await takeover;
 assert.equal(replaced, 1); assert.equal(window.orientation, 2, 'old owner cannot restore newer owner');
 await second.release(); assert.equal(window.orientation, 1);

 let unblock; const asyncWindow = target();
 asyncWindow.setPreferredOrientation = async function(value) { this.calls.push(['orientation', value]); if (value === 2) await new Promise(resolve => { unblock = resolve; }); this.orientation = value; };
 const delayed = controller.createFullscreenLease(async () => asyncWindow, policy);
 const delayedEnter = delayed.enter(); await flush(); const delayedExit = delayed.exit(); unblock();
 assert.equal(await delayedEnter, false); await delayedExit;
 assert.deepEqual(asyncWindow.calls, [['orientation', 2], ['bars', ['status', 'navigation']], ['orientation', 1]], 'late entry must skip bars and restore');

 const sameLeaseWindow = target(); let resolveSame;
 const same = controller.createFullscreenLease(() => new Promise(resolve => { resolveSame = resolve; }), policy);
 const oldEnter = same.enter(); await flush(); const oldExit = same.exit(); const newEnter = same.enter();
 resolveSame(sameLeaseWindow); assert.equal(await oldEnter, false); await oldExit; await flush(); resolveSame(sameLeaseWindow);
 assert.equal(await newEnter, true); assert.equal(sameLeaseWindow.calls.length, 2, 'old same-lease generation cannot execute'); await same.release();

 const failWindow = target(), failing = controller.createFullscreenLease(async () => failWindow, { ...policy, enterLayoutFullscreen: true });
 await failing.enter(); const setBars = failWindow.setWindowSystemBarEnable;
 failWindow.setWindowSystemBarEnable = async function() { throw Error('restore bars'); };
 await assert.rejects(failing.release()); assert.equal(failWindow.orientation, 1, 'orientation restores despite bars failure'); assert.equal(failWindow.layout, false);
 failWindow.setWindowSystemBarEnable = setBars; await failing.release();

 const other = target(), move = controller.createFullscreenLease(async () => window, policy), replacement = controller.createFullscreenLease(async () => other, policy);
 await move.enter(); await replacement.enter(); assert.equal(window.orientation, 1, 'window transfer restores old target'); await replacement.release();

 const shared = target(), privacy = controller.createLease(async () => shared), full = controller.createFullscreenLease(async () => shared, policy);
 await privacy.update(false); await full.enter(); await full.release(); assert.equal(shared.privacy, true); await privacy.release(); assert.equal(shared.privacy, false);
 const hostPolicy = { enterOrientation: 2, unspecifiedExitOrientation: 1, enterSystemBars: [],
   exitSystemBarsWhenFullscreen: [], exitSystemBarsWhenNotFullscreen: ['status', 'navigation'] };
 for (const orientation of [0, 1, 3]) {
   for (const wasFullscreen of [false, true]) {
     const original = target(); original.orientation = orientation; original.full = wasFullscreen;
     const hostLease = controller.createFullscreenLease(async () => original, hostPolicy);
     await hostLease.enter(); await hostLease.release();
     assert.equal(original.orientation, orientation === 0 ? 1 : orientation, 'host fallback applies only to original UNSPECIFIED');
     assert.deepEqual(original.calls.findLast(call => call[0] === 'bars')[1], wasFullscreen ? [] : ['status', 'navigation']);
   }
 }
 const explicitTarget = target(); explicitTarget.orientation = 0; explicitTarget.full = true;
 const explicitLease = controller.createFullscreenLease(async () => explicitTarget, { ...hostPolicy, exitOrientation: 3, exitSystemBars: ['status'] });
 await explicitLease.enter(); await explicitLease.release();
 assert.equal(explicitTarget.orientation, 3); assert.deepEqual(explicitTarget.calls.findLast(call => call[0] === 'bars')[1], ['status']);
 for (const originalLayout of [false, true]) {
   const original = target(); original.layout = originalLayout; original.full = !originalLayout;
   const defaultWebPolicy = { enterOrientation: 2, enterLayoutFullscreen: true };
   const webLease = controller.createFullscreenLease(async () => original, defaultWebPolicy);
   await webLease.enter(); await webLease.release();
   assert.equal(original.layout, originalLayout, 'layout fullscreen has its own snapshot, distinct from isFullScreen');
   assert.equal(original.full, !originalLayout);
   assert.equal(original.calls.some(call => call[0] === 'bars'), false, 'layout-only policy does not change system bars');
 }
 const mixed = target();
 const layoutOwner = controller.createFullscreenLease(async () => mixed, { enterLayoutFullscreen: true });
 const barsOwner = controller.createFullscreenLease(async () => mixed, { enterSystemBars: [] });
 await layoutOwner.enter(); await barsOwner.enter(); await layoutOwner.release();
 assert.equal(mixed.layout, true, 'old layout owner cannot restore during handoff');
 await barsOwner.release();
 assert.equal(mixed.layout, false, 'replacement with another policy still restores prior layout mutation');
 assert.deepEqual(mixed.calls.findLast(call => call[0] === 'bars')[1], ['status', 'navigation']);
 const layoutOnly = target();
 const layoutOnlyLease = controller.createFullscreenLease(async () => layoutOnly, { enterLayoutFullscreen: true });
 await layoutOnlyLease.enter(); layoutOnly.orientation = 3; await layoutOnlyLease.release();
 assert.equal(layoutOnly.orientation, 3, 'layout-only exit cannot overwrite host orientation changes');
 assert.equal(layoutOnly.calls.some(call => call[0] === 'orientation'), false);
 const changedOrientation = target();
 const orientationOwner = controller.createFullscreenLease(async () => changedOrientation, { enterOrientation: 2 });
 const onlyLayoutOwner = controller.createFullscreenLease(async () => changedOrientation, { enterLayoutFullscreen: true });
 await orientationOwner.enter(); await onlyLayoutOwner.enter(); await orientationOwner.release();
 assert.equal(changedOrientation.orientation, 2);
 await onlyLayoutOwner.release(); assert.equal(changedOrientation.orientation, 1, 'orientation touched survives takeover by layout-only policy');
 const explicitOnly = target();
 const explicitOnlyLease = controller.createFullscreenLease(async () => explicitOnly, { exitOrientation: 3 });
 await explicitOnlyLease.enter(); await explicitOnlyLease.release(); assert.equal(explicitOnly.orientation, 3);
 const fallbackOnly = target(); fallbackOnly.orientation = 0;
 const fallbackOnlyLease = controller.createFullscreenLease(async () => fallbackOnly, { unspecifiedExitOrientation: 1 });
 await fallbackOnlyLease.enter(); await fallbackOnlyLease.release(); assert.equal(fallbackOnly.orientation, 1);
 const rejectedOrientation = target();
 rejectedOrientation.setPreferredOrientation = async function(value) {
   this.calls.push(['orientation', value]); this.orientation = value;
   if (value === 2) throw Error('enter orientation rejected after mutation');
 };
 const rejectedLease = controller.createFullscreenLease(async () => rejectedOrientation, { enterOrientation: 2 });
 await assert.rejects(rejectedLease.enter(), /enter orientation rejected/);
 assert.equal(rejectedOrientation.orientation, 1, 'failed enter still restores its touched orientation');
 const delayedHandoff = target(); let finishOrientation;
 delayedHandoff.setPreferredOrientation = async function(value) {
   this.calls.push(['orientation', value]);
   if (value === 2) await new Promise(resolve => { finishOrientation = resolve; });
   this.orientation = value;
 };
 const delayedOld = controller.createFullscreenLease(async () => delayedHandoff, { enterOrientation: 2 });
 const delayedNew = controller.createFullscreenLease(async () => delayedHandoff, { enterLayoutFullscreen: true });
 const delayedOldEnter = delayedOld.enter(); await flush();
 const delayedOldClose = delayedOld.release(); const delayedNewEnter = delayedNew.enter();
 finishOrientation(); assert.equal(await delayedOldEnter, false); await delayedOldClose; await delayedNewEnter;
 assert.equal(delayedHandoff.orientation, 2, 'old close during native await cannot restore before replacement');
 await delayedNew.release(); assert.equal(delayedHandoff.orientation, 1);
 console.log('Fullscreen checks passed: restore, late Window, replacement, async exit, same-lease generation, retry, window transfer and privacy compatibility.');
})().catch(error => { console.error(error); process.exitCode = 1; });
