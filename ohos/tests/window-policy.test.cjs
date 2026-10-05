const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript');
const source = fs.readFileSync(path.join(__dirname, '../system-actions-native/src/main/ets/WindowPolicy.ets'), 'utf8');
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText,
  { exports: exportsObject, require: () => ({}) });
const { WindowPolicyController } = exportsObject;
const flush = () => new Promise(resolve => setImmediate(resolve));
function target(initial = false) {
  return { current: initial, calls: [], fail: false,
    getWindowProperties() { return { isPrivacyMode: this.current, isKeepScreenOn: this.keep || false }; },
    async setWindowKeepScreenOn(value) { this.keep = value; },
    async setWindowPrivacyMode(value) { this.calls.push(value); if (this.fail) throw Error('rejected'); this.current = value; }
  };
}
(async () => {
  const controller = new WindowPolicyController(), window = target();
  const first = controller.createLease(async () => window), second = controller.createLease(async () => window);
  await first.update(false); await second.update(true);
  assert.equal(window.current, true);
  await first.release(); assert.equal(window.current, false, 'remaining permissive owner can release secure');
  await second.update(false); assert.equal(window.current, true);
  await second.release(); await second.release(); assert.equal(window.current, false);
  const callCount = window.calls.length;
  await second.update(false); assert.equal(window.calls.length, callCount, 'ended owner cannot reacquire');

  const protectedWindow = target(true), original = controller.createLease(async () => protectedWindow);
  await original.update(true); await original.release(); assert.equal(protectedWindow.current, true);

  let resolveLate;
  const lateWindow = target(), late = controller.createLease(() => new Promise(resolve => { resolveLate = resolve; }));
  const pending = late.update(false); await flush();
  const release = late.release(); resolveLate(lateWindow); await pending; await release;
  assert.deepEqual(lateWindow.calls, [], 'release during getLastWindow cannot touch late Window');

  const failingWindow = target(), failing = controller.createLease(async () => failingWindow);
  await failing.update(false);
  failingWindow.fail = true;
  await assert.rejects(failing.release());
  failingWindow.fail = false; await failing.release(); assert.equal(failingWindow.current, false);
  const next = controller.createLease(async () => lateWindow);
  await next.update(false); assert.equal(lateWindow.current, true); await next.release();
  assert.equal(lateWindow.current, false, 'failed restore retains initial value and later retry clears cached target');

  let finishSet;
  const asyncWindow = target();
  asyncWindow.setWindowPrivacyMode = async function(value) {
    this.calls.push(value);
    if (this.calls.length === 1) await new Promise(resolve => { finishSet = resolve; });
    this.current = value;
  };
  const asyncLease = controller.createLease(async () => asyncWindow);
  const update = asyncLease.update(false); await flush();
  const released = asyncLease.release(); finishSet(); await update; await released;
  assert.deepEqual(asyncWindow.calls, [true, false]); assert.equal(asyncWindow.current, false);
  const brightWindow = target(), brightOne = controller.createLease(async () => brightWindow, true);
  const brightTwo = controller.createLease(async () => brightWindow, true);
  await brightOne.update(true); await brightTwo.update(true);
  assert.equal(brightWindow.keep, true);
  await brightOne.release(); assert.equal(brightWindow.keep, true);
  await brightTwo.release(); assert.equal(brightWindow.keep, false);
  brightWindow.keep = true;
  const baseline = controller.createLease(async () => brightWindow, false);
  await baseline.update(true); await baseline.release(); assert.equal(brightWindow.keep, true);

  console.log('Window policy checks passed: owners, initial privacy, late window, failed restore retry and asynchronous release.');
})().catch(error => { console.error(error); process.exitCode = 1; });
