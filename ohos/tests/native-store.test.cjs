const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript');
const timers = new Map(), listeners = [], calls = [];
let nextTimer = 0, throws = false;
const context = { abilityInfo: { bundleName: 'test.brand' } };
const cache = new Map();
function load(name) {
  if (cache.has(name)) return cache.get(name);
  const exports = {};
  cache.set(name, exports);
  const source = fs.readFileSync(path.join(__dirname, '../system-actions-native/src/main/ets', name + '.ets'), 'utf8');
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText, {
    exports,
    setTimeout: (fn, delay) => { assert.equal(delay, 20_000); timers.set(++nextTimer, fn); return nextTimer; },
    clearTimeout: id => timers.delete(id),
    require: name => {
      if (name === '@kit.AppGalleryKit') return { productViewManager: { loadProduct: (ctx, args, listener) => {
        assert.equal(ctx, context); calls.push(args); listeners.push(listener);
        if (throws) throw Error('SDK refused');
      } } };
      if (name === '@kuikly-open/render') return { KuiklyRenderBaseModule: class { onDestroy() {} } };
      if (name.startsWith('.')) return load(name.slice(2));
      return {};
    },
  });
  return exports;
}
const flush = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  const { SystemActions } = load('SystemActions');
  const { GycSystemActionsModule } = load('GycSystemActionsModule');
  const actions = new SystemActions(context);
  for (const id of ['', 'test', 'test.brand&bad=x', 'test.brand/path', 'a.' + 'b'.repeat(254)]) {
    assert.equal(await actions.openNativeAppStore(id), 'invalid_input');
  }
  assert.equal(calls.length, 0);
  let delivered = false;
  const appeared = actions.openNativeAppStore().then(result => { delivered = true; return result; });
  await flush(); assert.equal(delivered, false, 'void SDK return is not a receipt');
  assert.equal(calls.at(-1).parameters.bundleName, 'test.brand');
  const first = listeners.at(-1);
  first.onAppear(); first.onError(); first.onDisappear();
  assert.equal(await appeared, 'requested'); assert.equal(timers.size, 0);
  for (const event of ['onError', 'onDisappear']) {
    const rejected = actions.openNativeAppStore('other.brand');
    assert.equal(calls.at(-1).parameters.bundleName, 'other.brand');
    listeners.at(-1)[event](); listeners.at(-1).onAppear();
    assert.equal(await rejected, 'unavailable'); assert.equal(timers.size, 0);
  }
  throws = true;
  assert.equal(await actions.openNativeAppStore(), 'unavailable'); assert.equal(timers.size, 0);
  throws = false;
  const cancelled = actions.requestNativeAppStore();
  const cancelledListener = listeners.at(-1);
  cancelled.cancel(); cancelled.cancel(); cancelledListener.onAppear();
  assert.equal(await cancelled.result, 'unavailable'); assert.equal(timers.size, 0);
  const timedOut = actions.openNativeAppStore();
  const lateTimeout = listeners.at(-1);
  [...timers.values()][0]();
  assert.equal(await timedOut, 'unavailable'); lateTimeout.onAppear(); assert.equal(timers.size, 0);

  const module = new GycSystemActionsModule(actions), replies = [];
  const invoke = (method, id, value) => module.call(method, JSON.stringify({requestId: id, value}), result => replies.push(result.status));
  invoke('openNativeAppStore', 'reused'); const old = listeners.at(-1);
  invoke('openNativeAppStore', 'reused'); assert.deepEqual(replies, ['invalid_input']);
  invoke('cancel', 'reused'); assert.equal(timers.size, 0, 'cancel clears actual native timer');
  invoke('openNativeAppStore', 'reused', 'other.brand'); const current = listeners.at(-1);
  await flush(); assert.equal(replies.length, 1, 'cancelled Promise does not resolve successor callback');
  old.onAppear(); await flush(); assert.equal(replies.length, 1);
  current.onAppear(); await flush(); assert.deepEqual(replies, ['invalid_input', 'requested']);
  assert.equal(timers.size, 0);
  invoke('openNativeAppStore', 'timeout'); const timeoutListener = listeners.at(-1);
  [...timers.values()][0](); await flush(); assert.equal(replies.at(-1), 'unavailable');
  timeoutListener.onAppear(); await flush(); assert.equal(replies.length, 3);
  invoke('openNativeAppStore', 'invalid', 3); assert.equal(replies.at(-1), 'invalid_input');

  const otherOwner = actions.requestNativeAppStore(); const externalListener = listeners.at(-1);
  invoke('openNativeAppStore', 'destroy'); const destroyedListener = listeners.at(-1);
  assert.equal(timers.size, 2);
  const count = replies.length;
  module.onDestroy(); await flush(); assert.equal(timers.size, 1, 'only module-owned request is cancelled');
  destroyedListener.onAppear(); await flush(); assert.equal(replies.length, count);
  externalListener.onAppear(); assert.equal(await otherOwner.result, 'requested'); assert.equal(timers.size, 0);
  const afterDestroy = actions.openNativeAppStore(); listeners.at(-1).onAppear();
  assert.equal(await afterDestroy, 'requested', 'shared SystemActions remains usable');
  console.log('Native store real-source checks passed: appearance, rejection, timeout, cancellation, reused ID, late callbacks and shared ownership.');
})().catch(error => {console.error(error); process.exitCode = 1;});
