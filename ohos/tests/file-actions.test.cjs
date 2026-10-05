const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH || '/Applications/DevEco-Studio.app/Contents/tools/ohpm/node_modules/typescript');
const output = {};
let copyResolve, shared, statResolve, deferStat = false, fail = false, directory = false, link = '', shown = 0;
const context = { filesDir: '/private/files', cacheDir: '/private/cache', tempDir: '/private/temp' };
const kits = {
  '@kit.BasicServicesKit': { pasteboard: {
    createPlainTextData: value => ({ value }), getSystemPasteboard: () => ({ setData: value => new Promise(resolve => { copyResolve = () => { assert.equal(value.value, ''); resolve(); }; }) })
  } },
  '@kit.ArkData': { uniformTypeDescriptor: { UniformDataType: { FILE: 'general.file' }, getUniformDataTypeByFilenameExtension: (ext, parent) => { assert.equal(parent, 'general.file'); return ext === '.zip' ? 'general.zip-archive' : 'general.file'; } } },
  '@kit.CoreFileKit': { fileIo: { lstat: async path => ({ isSymbolicLink: () => path === link }), stat: () => deferStat ? new Promise(resolve => { statResolve = resolve; }) : Promise.resolve({ isFile: () => !directory }) }, fileUri: { getUriFromPath: path => 'file://' + path } },
  '@kit.ShareKit': { systemShare: {
    SharePreviewMode: { DEFAULT: 0 }, SelectionMode: { SINGLE: 0 }, SharedData: class { constructor(value) { shared = value; } },
    ShareController: class { async show(target) { assert.equal(target, context); shown++; if (fail) throw Error('rejected'); } }
  } }
};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(__dirname + '/../system-actions-native/src/main/ets/SystemActions.ets', 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText, { exports: output, require: name => kits[name] || {} });
(async () => {
  const actions = new output.SystemActions(context);
  let settled = false;
  const copy = actions.copyText('').then(result => { settled = true; return result; });
  await Promise.resolve(); assert.equal(settled, false); copyResolve(); assert.equal(await copy, 'requested');
  for (const path of ['', 'file:///private/files/a.zip', '/other/a.zip', '/private/files/../a.zip', '/private/files/a\0.zip']) {
    assert.equal(await actions.shareFile(path, 'Share'), 'invalid_input', path);
  }
  link = '/private/files/link';
  assert.equal(await actions.shareFile('/private/files/link/a.zip', 'Share'), 'invalid_input');
  link = ''; directory = true;
  assert.equal(await actions.shareFile('/private/files/a.zip', 'Share'), 'unavailable');
  assert.equal(shown, 0);
  directory = false;
  assert.equal(await actions.shareFile('/private/files/a.zip', 'Share'), 'requested');
  assert.deepEqual(JSON.parse(JSON.stringify(shared)), { utd: 'general.zip-archive', uri: 'file:///private/files/a.zip', title: 'Share' });
  assert.equal(await actions.shareFile('/private/cache/plain', ''), 'requested');
  assert.equal(shared.utd, 'general.file');
  fail = true;
  assert.equal(await actions.shareFile('/private/files/a.zip', 'Share'), 'unavailable');
  fail = false; deferStat = true;
  const modules = {};
  vm.runInNewContext(ts.transpileModule(fs.readFileSync(__dirname + '/../system-actions-native/src/main/ets/GycSystemActionsModule.ets', 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText, {
    exports: modules, require: name => name === './SystemActions' ? output :
      name === './SystemObservations' ? { SystemObservations: class { dispose() {} } } :
      name === '@kuikly-open/render' ? { KuiklyRenderBaseModule: class { onDestroy() {} } } : {}
  });
  for (const cancel of ['cancel', 'destroy']) {
    const module = new modules.GycSystemActionsModule(actions), before = shown;
    module.call('shareFile', JSON.stringify({ requestId: cancel, value: '/private/files/a.zip', title: 'Share' }), () => assert.fail('cancelled owner delivered'));
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(typeof statResolve, 'function', 'real share reached delayed stat');
    if (cancel === 'cancel') module.call('cancel', JSON.stringify({ requestId: cancel }), null);
    else module.onDestroy();
    statResolve({ isFile: () => true });
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(shown, before, 'cancelled owner cannot show after delayed stat');
    module.onDestroy();
  }
  console.log('OHOS file action checks passed: clipboard completion, private roots, traversal, symlink, regular file, UTD, URI, system rejection and cancellation before delayed share panel.');
})().catch(error => { console.error(error); process.exitCode = 1; });
