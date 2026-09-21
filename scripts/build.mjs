import { existsSync, copyFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { toolchain } from './toolchain.mjs';
const project = fileURLToPath(new URL('../', import.meta.url));
const tc = toolchain();
const profile = path.join(project, 'build-profile.json5');
if (!existsSync(profile)) copyFileSync(path.join(project, 'build-profile.example.json5'), profile);
function run(binary, args) {
  const result = spawnSync(binary, args, { cwd: project, env: tc.env, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) process.exit(result.status ?? 1);
}
run(tc.ohpm, ['install', '--all']);
run(tc.hvigor, ['--mode', 'module', '-p', 'product=default', '-p', 'module=entry@default', '-p', 'buildMode=debug', 'assembleHap', '--no-daemon']);
const folder = path.join(project, 'entry/build/default/outputs/default');
const packages = readdirSync(folder).filter(file => file.endsWith('.hap'));
if (!packages.length) throw new Error('未生成 HAP');
for (const file of packages) console.log(path.join(folder, file));
if (!packages.some(file => file.endsWith('-signed.hap') || file === 'AirBrowser.hap')) console.log('已生成未签名 HAP；真机安装前需要为 com.adam.airbrowser 单独配置调试签名。');
