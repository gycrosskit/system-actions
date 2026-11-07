const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript');
const source = fs.readFileSync(__dirname + '/../system-actions-native/src/main/ets/SystemActions.ets', 'utf8');
let calls = [], complete, failed = false;
let clipboardRecords = [], clipboardError;
const pasteboard = {
  MIMETYPE_TEXT_PLAIN: 'text/plain',
  getSystemPasteboard: () => ({ getData: async () => {
    if (clipboardError) throw clipboardError;
    return {getRecordCount: () => clipboardRecords.length, getRecord: i => clipboardRecords[i]};
  }})
};
const exportsObject = {};
const context = {
  abilityInfo: {bundleName: 'test.brand'},
  openLink: async value => { calls.push(value); if (failed) throw Error('unavailable'); },
  startAbility: async want => { calls.push(want); },
};
vm.runInNewContext(ts.transpileModule(source, {compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020}}).outputText,
  {exports: exportsObject, require: name => name === '@kit.BasicServicesKit' ? {pasteboard} : name === '@kit.ArkTS' ? {url: {URL}} : {call: {makeCall: (_, phone) => {calls.push(phone); return new Promise(resolve => {complete = resolve;});}}}});
(async () => {
  const actions = new exportsObject.SystemActions(context);
  assert.equal((await actions.readClipboardText()).status, 'no_text');
  for (const value of ['', ' ', 'a\0b', '长'.repeat(20000)]) {
    clipboardRecords = [{mimeType: 'text/plain', plainText: value}, {mimeType: 'text/plain', plainText: 'ignored'}];
    const result = await actions.readClipboardText();
    assert.equal(result.status, 'text'); assert.equal(result.value, value);
  }
  clipboardRecords = [{mimeType: 'text/uri', plainText: 'https://example.com'}];
  assert.equal((await actions.readClipboardText()).status, 'no_text');
  clipboardError = {code: 201}; assert.equal((await actions.readClipboardText()).status, 'denied');
  clipboardError = {code: 27787277}; assert.equal((await actions.readClipboardText()).status, 'failed');
  clipboardError = undefined;
  for (const value of ['*123#', '123;456', 'tel:123', '']) assert.equal(await actions.dial(value), 'invalid_input');
  for (const value of ['javascript:alert(1)', 'https://', 'http:///x', 'https://@host.com', 'https://a.com/%ZZ', 'https://a.com:99999', 'https://a.com/ x']) {
    assert.equal(await actions.openExternalUrl(value), 'invalid_input', value);
  }
  assert.equal(await actions.openLocationSettings(), 'unavailable');
  assert.equal(calls.length, 0);
  let settled = false;
  const request = actions.dial('+86 138-1234-5678').then(value => {settled = true; return value;});
  await Promise.resolve(); assert.equal(settled, false); complete();
  assert.equal(await request, 'requested'); assert.equal(calls[0], '+8613812345678');
  assert.equal(await actions.openAppStore('https://store.example.com/app'), 'requested');
  failed = true; assert.equal(await actions.openExternalUrl('https://example.com'), 'unavailable');
  assert.equal(await actions.openAppSettings(), 'requested');
  assert.equal(calls.at(-1).parameters.pushParams, 'test.brand');
  console.log('system-actions HAR contract checks passed');
})().catch(error => {console.error(error); process.exitCode = 1;});
