const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript');
const source = fs.readFileSync(__dirname + '/../system-actions-native/src/main/ets/SystemActions.ets', 'utf8');
let calls = [], complete, failed = false;
let clipboardRecords = [], clipboardError;
function record(mimeType, entries) {
  return {mimeType, plainText: entries['text/plain'],
    getValidTypes: types => types.filter(type => Object.hasOwn(entries, type)),
    getData: async type => entries[type]};
}
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
    clipboardRecords = [record('text/plain', {'text/plain': value}), record('text/plain', {'text/plain': 'ignored'})];
    const result = await actions.readClipboardText();
    assert.equal(result.status, 'text'); assert.equal(result.value, value);
  }
  for (const value of ['', ' ', 'a\0b', '长'.repeat(20000)]) {
    clipboardRecords = [record('text/html', {'text/html': '<b>different</b>', 'text/plain': value})];
    assert.deepEqual(JSON.parse(JSON.stringify(await actions.readClipboardText())), {status: 'text', value});
  }
  for (const first of [record('text/uri', {'text/uri': 'https://example.com'}),
    record('text/html', {'text/html': '<b>no plain representation</b>'}),
    record('text/plain', {'text/plain': new Uint8Array([65])})]) {
    clipboardRecords = [first, record('text/plain', {'text/plain': 'ignored'})];
    assert.equal((await actions.readClipboardText()).status, 'no_text');
  }
  for (const code of [201, 27787277]) {
    clipboardRecords = [{getValidTypes: () => ['text/plain'], getData: async () => {throw {code};}}];
    assert.equal((await actions.readClipboardText()).status, code === 201 ? 'denied' : 'failed');
  }
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
