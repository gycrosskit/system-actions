const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript');
function load(resolveWindow) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(__dirname + '/../system-actions-native/src/main/ets/SystemObservations.ets', 'utf8'),
    { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText,
    { exports, require: name => name === '@kit.ArkUI' ? { window: { getLastWindow: resolveWindow } } :
      name === '@kit.AbilityKit' ? { ConfigurationConstant: { ColorMode: { COLOR_MODE_DARK: 1 } } } :
      { resourceManager: { ColorMode: { DARK: 1 } } } });
  return exports.SystemObservations;
}
const flush = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  const windows = [], replies = [], listeners = [], removed = [];
  const app = { on: (_event, listener) => { listeners.push(listener); return listeners.length; },
    off: (_event, id) => removed.push(id) };
  const context = { resourceManager: { getConfigurationSync: () => ({ colorMode: 1 }) }, getApplicationContext: () => app };
  const Observations = load(() => new Promise((resolve, reject) => windows.push({ resolve, reject })));
  const observations = new Observations(() => context);
  const target = { callbacks: [], offCalls: [], getUIContext: () => ({ px2vp: height => height / 2 }),
    on(_event, callback) { this.callbacks.push(callback); }, off(_event, callback) { this.offCalls.push(callback); } };
  const old = observations.observeKeyboardHeight('old', value => replies.push(['old', value]));
  const current = observations.observeKeyboardHeight('new', value => replies.push(['new', value]));
  windows[0].resolve(target); await old; assert.equal(target.callbacks.length, 0, 'late replaced window is untouched');
  observations.stopKeyboardHeight('old');
  windows[1].resolve(target); await current;
  assert.deepEqual(replies, [['new', 0]]);
  target.callbacks[0](100); assert.deepEqual(replies.at(-1), ['new', 50], 'Window px2vp conversion');
  observations.stopKeyboardHeight('new'); target.callbacks[0](500);
  assert.equal(replies.length, 2); assert.equal(target.offCalls.length, 1);
  const failedOld = observations.observeKeyboardHeight('failure-old', value => replies.push(value));
  const pendingNew = observations.observeKeyboardHeight('failure-new', value => replies.push(value));
  windows[2].reject(Error('late failure')); await failedOld; assert.equal(replies.length, 2);
  observations.dispose(); windows[3].resolve(target); await pendingNew;
  assert.equal(target.callbacks.length, 1); assert.equal(replies.length, 2);

  const environment = new Observations(() => context), dark = [];
  environment.observeDarkMode('first', value => dark.push(['first', value]));
  environment.observeDarkMode('second', value => dark.push(['second', value]));
  environment.stopDarkMode('first');
  listeners[0].onConfigurationUpdated({ colorMode: 0 });
  listeners[1].onConfigurationUpdated({ colorMode: 0 });
  assert.deepEqual(dark, [['first', true], ['second', true], ['second', false]]);
  environment.dispose(); listeners[1].onConfigurationUpdated({ colorMode: 1 });
  assert.equal(dark.length, 3); assert.deepEqual(removed, [1, 2]);
  const reentrant = new Observations(() => context);
  reentrant.observeDarkMode('reentrant', () => reentrant.dispose());
  assert.equal(listeners.length, 2, 'dispose in initial callback must not register listener');
  console.log('System observation checks passed: vp, generation, replacement, old stop, late failure, environment and dispose.');
})().catch(error => { console.error(error); process.exitCode = 1; });
