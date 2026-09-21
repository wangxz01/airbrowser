import { readFileSync, existsSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';
const root = fileURLToPath(new URL('../', import.meta.url));
const read = file => JSON.parse(readFileSync(path.join(root, file), 'utf8'));
assert.equal(read('AppScope/app.json5').app.bundleName, 'com.adam.airbrowser');
const mod = read('entry/src/main/module.json5').module;
assert.deepEqual(mod.requestPermissions.map(p => p.name), ['ohos.permission.INTERNET']);
assert.equal(mod.mainElement, 'EntryAbility');
assert.deepEqual(mod.deviceTypes, ['tablet'], 'Air Browser distribution is tablet-only');
assert.ok(existsSync(path.join(root, 'entry/src/main/ets/entryability/EntryAbility.ets')));
assert.equal(read('build-profile.example.json5').app.signingConfigs.length, 0);
for (const theme of ['base', 'dark']) read(`entry/src/main/resources/${theme}/element/color.json`);
const resources = new Set(readdirSync(path.join(root, 'entry/src/main/resources/base/media')).map(p => path.parse(p).name));
const colors = new Set(read('entry/src/main/resources/base/element/color.json').color.map(p => p.name));
function check(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) check(file);
    else if (file.endsWith('.ets')) {
      const text = readFileSync(file, 'utf8');
      for (const [, type, name] of text.matchAll(/\$r\('app\.(media|color)\.([^']+)'\)/g)) {
        assert.ok((type === 'media' ? resources : colors).has(name), `Missing ${type}: ${name}`);
      }
      assert.ok(!text.includes('javaScriptProxy('), 'Browser must not expose a native JS proxy to arbitrary pages');
    }
  }
}
check(path.join(root, 'entry/src/main/ets'));
console.log('独立包名、资源引用和工程配置检查通过。');
