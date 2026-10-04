const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript');
const exportsObject = {};
const observations = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(__dirname + '/../system-actions-native/src/main/ets/SystemObservations.ets', 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText, { exports: observations, require: () => ({}) });
const source = fs.readFileSync(__dirname + '/../system-actions-native/src/main/ets/GycSystemActionsModule.ets', 'utf8');
vm.runInNewContext(ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText,
  { exports: exportsObject, require: name => name === '@kuikly-open/render' ? { KuiklyRenderBaseModule: class { onDestroy() {} } } : name === './SystemObservations' ? observations : {} });

(async () => {
  const calls = [], completions = [], replies = [];
  const actions = {
    dial: value => { calls.push(['dial', value]); return new Promise((resolve, reject) => completions.push({ resolve, reject })); },
    openExternalUrl: async value => { calls.push(['url', value]); return 'invalid_input'; },
    openAppSettings: async () => { calls.push(['settings']); return 'requested'; },
    openAppStore: async value => { calls.push(['store', value]); return 'requested'; },
    openLocationSettings: async () => { calls.push(['location']); return 'unavailable'; },
  };
  const module = new exportsObject.GycSystemActionsModule(actions);
  const invoke = (method, id, value, callback = result => replies.push(result.status)) =>
    module.call(method, JSON.stringify({ requestId: id, value }), callback);
  const flush = () => new Promise(resolve => setImmediate(resolve));
  invoke('dial', '1', '+86 123');
  await flush(); assert.equal(replies.length, 0, 'must wait for system Promise');
  completions.shift().resolve('requested'); await flush(); assert.deepEqual(replies, ['requested']);
  invoke('openExternalUrl', '2', 'invalid');
  invoke('openAppSettings', '3'); invoke('openAppStore', '4', 'https://store.example.com');
  invoke('openLocationSettings', '5'); await flush();
  assert.deepEqual(replies.slice(1), ['invalid_input', 'requested', 'requested', 'unavailable']);
  assert.deepEqual(calls.slice(1), [['url', 'invalid'], ['settings'], ['store', 'https://store.example.com'], ['location']]);
  invoke('dial', 'reject', '123'); completions.shift().reject(Error('system rejected')); await flush();
  assert.equal(replies.at(-1), 'unavailable');

  const reusedCallback = result => replies.push(result.status);
  const beforeCancel = replies.length;
  invoke('dial', 'reuse', '123', reusedCallback);
  const old = completions.shift();
  invoke('cancel', 'reuse');
  invoke('dial', 'reuse', '456', reusedCallback);
  const current = completions.shift();
  old.resolve('requested'); await flush(); assert.equal(replies.length, beforeCancel, 'old request must not deliver to reused id/callback');
  current.resolve('requested'); await flush(); assert.equal(replies.length, beforeCancel + 1);

  const beforeInvalid = calls.length;
  for (const params of ['null', '[]', '{', '{}', '{"requestId":3}']) {
    module.call('dial', params, result => assert.equal(result.status, 'invalid_input'));
  }
  assert.equal(calls.length, beforeInvalid);
  invoke('unknown', 'unknown'); await flush(); assert.equal(replies.at(-1), 'unavailable');
  invoke('dial', 'destroy', '123'); const delayed = completions.shift();
  const beforeDestroy = replies.length;
  module.onDestroy(); delayed.resolve('requested'); await flush();
  invoke('openAppSettings', 'after-destroy'); await flush();
  assert.equal(replies.length, beforeDestroy);
  assert.equal(calls.length, beforeInvalid + 1, 'destroyed module must not dispatch');
  console.log('system-actions Kuikly wait/cancel/dispose checks passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
