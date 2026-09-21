import path from 'node:path';
import { existsSync } from 'node:fs';
export function toolchain() {
  const ide = process.env.AIR_BROWSER_DEVECO_PATH || '/Applications/DevEco-Studio.app';
  const contents = path.join(ide, 'Contents');
  const nodeHome = path.join(contents, 'tools/node');
  const ohpm = path.join(contents, 'tools/ohpm/bin/ohpm');
  const hvigor = path.join(contents, 'tools/hvigor/bin/hvigorw');
  const sdk = path.join(contents, 'sdk');
  const javaHome = path.join(contents, 'jbr/Contents/Home');
  for (const item of [nodeHome, ohpm, hvigor, sdk, javaHome]) {
    if (!existsSync(item)) throw new Error(`缺少 DevEco 组件：${item}。可用 AIR_BROWSER_DEVECO_PATH 指定 IDE。`);
  }
  return { ide, ohpm, hvigor, env: { ...process.env,
    PATH: `${nodeHome}/bin:${path.dirname(ohpm)}:${process.env.PATH || ''}`,
    NODE_HOME: nodeHome, DEVECO_SDK_HOME: sdk, JAVA_HOME: javaHome
  } };
}
