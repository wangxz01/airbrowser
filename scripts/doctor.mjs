import { toolchain } from './toolchain.mjs';
import { execFileSync } from 'node:child_process';
const tc = toolchain();
console.log(`DevEco: ${tc.ide}`);
console.log(`Node: ${process.version}`);
console.log(`Bundle: com.adam.airbrowser`);
console.log('构建：npm run build；检查：npm run check');
console.log(execFileSync(tc.hvigor, ['--version'], { env: tc.env, encoding: 'utf8' }).trim());
